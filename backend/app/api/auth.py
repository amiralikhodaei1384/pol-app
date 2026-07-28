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
        company = db.query(models.Company).filter(models.Company.national_id == user_in.national_id).first()
        if not company:
            company = models.Company(
                name=user_in.company_name,
                national_id=user_in.national_id,
                address=user_in.company_address
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

    access_token = security.create_access_token(
        data={"sub": user.email, "role": user.role}
    )
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "role": user.role
    }