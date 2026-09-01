import os
import re
import uuid
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from jose import jwt, JWTError

from ..db.session import get_db
from ..models import models
from ..schemas import schemas
from ..core import security

router = APIRouter()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

UPLOAD_DIR = "uploads/resumes"

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> models.User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="اعتبارسنجی ناپایدار/توکن نامعتبر است یا منقضی شده.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        if hasattr(security, 'decode_token'):
            payload = security.decode_token(token)
        else:
            SECRET_KEY = getattr(security, 'SECRET_KEY', 'SECRET_KEY')
            ALGORITHM = getattr(security, 'ALGORITHM', 'HS256')
            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])

        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
    except Exception:
        raise credentials_exception

    user = db.query(models.User).filter(models.User.email == email).first()
    if user is None:
        raise credentials_exception
    return user


@router.post("/register", response_model=schemas.UserOut)
def register(user_in: schemas.UserCreate, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == user_in.email).first()
    if user:
        raise HTTPException(status_code=400, detail="این ایمیل قبلاً ثبت شده است.")

    hashed_pw = security.get_password_hash(user_in.password)

    db_user = models.User(
        email=user_in.email,
        password_hash=hashed_pw,
        role=user_in.role
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)

    if user_in.role == models.UserRole.STUDENT:
        profile = models.StudentProfile(
            user_id=db_user.id,
            full_name="",  # <--- پاک شدن اسم دیفالت "دانشجوی جدید"
            completion_percentage=0
        )
        db.add(profile)

    elif user_in.role == models.UserRole.COMPANY_REP:
        national_id = user_in.national_id or f"1010{uuid.uuid4().hex[:6]}"
        company_name = user_in.company_name or "شرکت جدید"

        company = db.query(models.Company).filter(models.Company.national_id == national_id).first()
        if not company:
            company = models.Company(
                name=company_name,
                national_id=national_id,
                address=user_in.company_address or "تهران"
            )
            db.add(company)
            db.commit()
            db.refresh(company)

        rep = models.CompanyRepresentative(
            user_id=db_user.id,
            company_id=company.id
        )
        db.add(rep)

    db.commit()
    return db_user


@router.post("/login", response_model=schemas.Token)
def login(login_data: schemas.UserLogin, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == login_data.username).first()
    if not user or not security.verify_password(login_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="ایمیل یا رمز عبور اشتباه است.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    role_str = user.role.value if hasattr(user.role, 'value') else str(user.role)

    access_token = security.create_access_token(
        data={"sub": user.email, "role": role_str}
    )
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "role": role_str
    }


@router.get("/me")
def get_me(current_user: models.User = Depends(get_current_user)):
    role_str = current_user.role.value if hasattr(current_user.role, 'value') else str(current_user.role)

    response = {
        "id": str(current_user.id),
        "email": current_user.email,
        "role": role_str,
    }

    if current_user.role == models.UserRole.STUDENT and current_user.student_profile:
        p = current_user.student_profile
        response["profile"] = {
            "full_name": p.full_name,
            "phone": p.phone,
            "birth_date": p.birth_date,
            "residence": p.residence,
            "birth_place": p.birth_place,
            "university": p.university,
            "major": p.major,
            "skills": p.skills,
            "courses": p.courses,
            "educations": p.educations,
            "work_experiences": p.work_experiences,
            "resume_file": p.resume_file,
            "portfolio_links": p.portfolio_links,
        }
    elif current_user.role == models.UserRole.COMPANY_REP and current_user.company_rep_profile:
        c = current_user.company_rep_profile.company
        response["company"] = {
            "name": c.name if c else "",
            "about": c.about if c else "",
            "website": c.website if c else "",
            "address": c.address if c else "",
        }

    return response


# روتر جدید: ثبت و ویرایش اطلاعات شرکت (درباره شرکت، آدرس، وب‌سایت)
@router.post("/company-profile")
def update_company_profile(
        body: schemas.CompanyProfileUpdate,
        db: Session = Depends(get_db),
        current_user: models.User = Depends(get_current_user)
):
    if current_user.role != models.UserRole.COMPANY_REP or not current_user.company_rep_profile:
        raise HTTPException(status_code=403, detail="تنها نمایندگان شرکت مجاز به ویرایش هستند.")

    company = current_user.company_rep_profile.company
    if company:
        if body.name: company.name = body.name
        if body.about: company.about = body.about
        if body.website: company.website = body.website
        if body.address: company.address = body.address
        db.commit()

    return {"message": "اطلاعات شرکت با موفقیت بروزرسانی شد."}


# روتر جدید: دریافت فایل رزومه واقعی و ذخیره با اسم دانشجو روی سرور
# روتر آپلود فایل رزومه (فقط PDF)
@router.post("/upload-resume")
async def upload_resume(
        file: UploadFile = File(...),
        db: Session = Depends(get_db),
        current_user: models.User = Depends(get_current_user)
):
    if current_user.role != models.UserRole.STUDENT:
        raise HTTPException(status_code=403, detail="تنها دانشجویان مجاز به آپلود رزومه هستند.")

    # ۱. فیلتر امنیتی: تنها پسوند PDF مجاز است
    if not file.filename.lower().endswith(".pdf"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="لطفاً تنها فایل با فرمت PDF آپلود کنید."
        )

    profile = db.query(models.StudentProfile).filter(models.StudentProfile.user_id == current_user.id).first()

    # ساخت نام فایل بر اساس نام واقعی دانشجو برای ذخیره در هارد سرور
    raw_name = profile.full_name.strip() if (profile and profile.full_name and profile.full_name.strip()) else current_user.email.split('@')[0]
    safe_name = re.sub(r'[^\w\s-]', '', raw_name).strip().replace(' ', '_')
    if not safe_name:
        safe_name = "Student"

    new_filename = f"Resume_{safe_name}_{current_user.id.hex[:6]}.pdf"
    file_path = os.path.join(UPLOAD_DIR, new_filename)

    with open(file_path, "wb") as f:
        content = await file.read()
        f.write(content)

    relative_url = f"/uploads/resumes/{new_filename}"
    if profile:
        profile.resume_file = relative_url
        db.commit()

    return {
        "message": "فایل رزومه با موفقیت ذخیره شد.",
        "file_url": relative_url
    }


@router.post("/student-profile")
def update_student_profile(
        profile_in: schemas.StudentProfileCreate,
        db: Session = Depends(get_db),
        current_user: models.User = Depends(get_current_user)
):
    if current_user.role != models.UserRole.STUDENT:
        raise HTTPException(status_code=403, detail="تنها دانشجویان مجاز به ویرایش هستند.")

    profile = db.query(models.StudentProfile).filter(models.StudentProfile.user_id == current_user.id).first()

    if not profile:
        profile = models.StudentProfile(user_id=current_user.id)
        db.add(profile)

    profile.full_name = profile_in.full_name
    profile.phone = profile_in.phone
    profile.birth_date = profile_in.birth_date
    profile.residence = profile_in.residence
    profile.birth_place = profile_in.birth_place
    profile.university = profile_in.university
    profile.major = profile_in.major
    profile.entrance_year = profile_in.entrance_year
    profile.skills = profile_in.skills
    profile.courses = [c.model_dump() for c in profile_in.courses]
    profile.educations = profile_in.educations
    profile.work_experiences = profile_in.work_experiences
    if profile_in.resume_file:
        profile.resume_file = profile_in.resume_file
    profile.portfolio_links = {
        "github": profile_in.github_link,
        "figma": profile_in.figma_link
    }
    profile.completion_percentage = 100

    db.commit()
    db.refresh(profile)
    return {"message": "پروفایل دانشجو با موفقیت ذخیره شد."}