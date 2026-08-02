import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from jose import jwt, JWTError

from ..db.session import get_db
from ..models import models
from ..schemas import schemas
from ..core import security

router = APIRouter()

# تعریف ساختار خواندن توکن از هدر Authorization
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

# تابع احراز هویت کاربر جاری بر اساس توکن JWT ارسال شده
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
    # ۱. بررسی تکراری نبودن ایمیل
    user = db.query(models.User).filter(models.User.email == user_in.email).first()
    if user:
        raise HTTPException(status_code=400, detail="این ایمیل قبلاً ثبت شده است.")

    # ۲. هش کردن رمز عبور
    hashed_pw = security.get_password_hash(user_in.password)

    # ۳. ساخت شیء کاربر
    db_user = models.User(
        email=user_in.email,
        password_hash=hashed_pw,
        role=user_in.role
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)

    # ۴. ساخت پروفایل اولیه (دانشجو یا نماینده شرکت)
    if user_in.role == models.UserRole.STUDENT:
        profile = models.StudentProfile(
            user_id=db_user.id,
            full_name=user_in.full_name or "دانشجوی جدید",
            university="دانشگاه تهران",
            major="مهندسی کامپیوتر",
            completion_percentage=50
        )
        db.add(profile)

    elif user_in.role == models.UserRole.COMPANY_REP:
        # برای تست راحت‌تر، اگر شناسه ملی وارد نشده بود یک مقدار تصادفی تست تولید می‌شود
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

    # تبدیل Enum نقش کاربر به رشته
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
    """دریافت اطلاعات کامل کاربر جاری به همراه نقش و پروفایل"""
    role_str = current_user.role.value if hasattr(current_user.role, 'value') else str(current_user.role)

    response = {
        "id": str(current_user.id),
        "email": current_user.email,
        "role": role_str,
    }

    if current_user.role == models.UserRole.STUDENT and current_user.student_profile:
        response["profile"] = {
            "full_name": current_user.student_profile.full_name,
            "university": current_user.student_profile.university,
            "major": current_user.student_profile.major,
            "skills": current_user.student_profile.skills,
            "courses": current_user.student_profile.courses,
        }
    elif current_user.role == models.UserRole.COMPANY_REP and current_user.company_rep_profile:
        company = current_user.company_rep_profile.company
        response["company"] = {
            "name": company.name if company else None,
            "address": company.address if company else None,
        }

    return response


@router.post("/student-profile")
def update_student_profile(
        profile_in: schemas.StudentProfileCreate,
        db: Session = Depends(get_db),
        current_user: models.User = Depends(get_current_user)
):
    """ذخیره و به‌روزرسانی فرم ۳ مرحله‌ای پروفایل دانشجو (دروس، نمرات، مهارت‌ها)"""
    if current_user.role != models.UserRole.STUDENT:
        raise HTTPException(status_code=403, detail="تنها دانشجویان مجاز به ثبت و ویرایش این پروفایل هستند.")

    profile = db.query(models.StudentProfile).filter(models.StudentProfile.user_id == current_user.id).first()

    if not profile:
        profile = models.StudentProfile(user_id=current_user.id)
        db.add(profile)

    profile.full_name = profile_in.full_name
    profile.university = profile_in.university
    profile.major = profile_in.major
    profile.entrance_year = profile_in.entrance_year
    profile.skills = profile_in.skills
    profile.courses = [c.model_dump() for c in profile_in.courses]
    profile.portfolio_links = {
        "github": profile_in.github_link,
        "figma": profile_in.figma_link
    }
    profile.completion_percentage = 100

    db.commit()
    db.refresh(profile)
    return {"message": "پروفایل دانشجو با موفقیت به‌روزرسانی شد.", "profile_id": str(profile.id)}