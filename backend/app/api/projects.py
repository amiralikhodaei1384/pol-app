from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from ..db.session import get_db
from ..models import models
from ..schemas import schemas
from .auth import get_current_user

router = APIRouter()

# ۱. ثبت پروژه جدید
@router.post("/", response_model=schemas.ProjectOut, status_code=status.HTTP_201_CREATED)
def create_project(
        project_in: schemas.ProjectCreate,
        db: Session = Depends(get_db),
        current_user: models.User = Depends(get_current_user)
):
    if current_user.role != models.UserRole.COMPANY_REP:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="تنها نمایندگان شرکت‌ها مجاز به ثبت پروژه جدید هستند."
        )

    # گرفتن آیدی واقعی شرکت از روی پروفایل نماینده
    if not current_user.company_rep_profile or not current_user.company_rep_profile.company_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="اطلاعات شرکت مرتبط با این کاربر یافت نشد."
        )

    company_id = current_user.company_rep_profile.company_id

    new_project = models.Project(
        company_id=company_id,
        title=project_in.title,
        description=project_in.description,
        required_skills=project_in.required_skills,
        deadline=project_in.deadline,
        project_type=project_in.project_type.value,
        requires_interview=project_in.requires_interview,
        weights=project_in.weights.model_dump() if project_in.weights else None
    )

    db.add(new_project)
    db.commit()
    db.refresh(new_project)

    return new_project

# ۲. دریافت همه پروژه‌ها (برای نمایش به دانشجویان)
@router.get("/", response_model=List[schemas.ProjectOut])
def get_all_projects(db: Session = Depends(get_db)):
    return db.query(models.Project).filter(models.Project.is_active == True).order_by(models.Project.created_at.desc()).all()

# ۳. دریافت پروژه‌های خود شرکت (برای نمایش در داشبورد کارفرما)
@router.get("/my-projects", response_model=List[schemas.ProjectOut])
def get_my_projects(
        db: Session = Depends(get_db),
        current_user: models.User = Depends(get_current_user)
):
    if current_user.role != models.UserRole.COMPANY_REP or not current_user.company_rep_profile:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="دسترسی غیرمجاز")

    company_id = current_user.company_rep_profile.company_id
    return db.query(models.Project).filter(models.Project.company_id == company_id).order_by(models.Project.created_at.desc()).all()