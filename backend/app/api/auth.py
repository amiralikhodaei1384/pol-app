from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from ..db.session import get_db
from ..models import models
from ..schemas import schemas
from ..core import security

router = APIRouter()

@router.post("/register", response_model=schemas.UserOut)
def register(user_in: schemas.UserCreate, db: Session = Depends(get_db)):
    # 1. Check if user already exists
    user = db.query(models.User).filter(models.User.email == user_in.email).first()
    if user:
        raise HTTPException(status_code=400, detail="این ایمیل قبلاً ثبت شده است.")

    # 2. Hash password
    hashed_pw = security.get_password_hash(user_in.password)

    # 3. Create User object
    db_user = models.User(
        email=user_in.email,
        password_hash=hashed_pw,
        role=user_in.role
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)

    # 4. Create Profile (Student or Company)
    if user_in.role == models.UserRole.STUDENT:
        profile = models.StudentProfile(
            user_id=db_user.id,
            full_name=user_in.full_name or "کاربر جدید"
        )
        db.add(profile)
    elif user_in.role == models.UserRole.COMPANY_REP:
        # Check if company exists or create new
        company = db.query(models.Company).filter(models.Company.national_id == user_in.national_id).first()
        if not company:
            company = models.Company(
                name=user_in.company_name,
                national_id=user_in.national_id,
                address=user_in.company_address # ذخیره آدرس جدید شرکت در دیتابیس
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
    # 1. Find user by email (username)
    user = db.query(models.User).filter(models.User.email == login_data.username).first()
    if not user or not security.verify_password(login_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="ایمیل یا رمز عبور اشتباه است.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # 2. Create JWT Token
    access_token = security.create_access_token(
        data={"sub": user.email, "role": user.role}
    )
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "role": user.role
    }