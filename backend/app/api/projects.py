from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from ..db.session import get_db
from ..models import models
from ..schemas import schemas
from .auth import get_current_user  # گرفتن تابع دریافت کاربر از همین پوشه

router = APIRouter()

@router.post("/", response_model=schemas.ProjectOut, status_code=status.HTTP_201_CREATED)
def create_project(
        project_in: schemas.ProjectCreate,
        db: Session = Depends(get_db),
        current_user: models.User = Depends(get_current_user)
):
    # بررسی نقش کاربر با COMPANY_REP
    if current_user.role != models.UserRole.COMPANY_REP:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="تنها نمایندگان شرکت‌ها مجاز به ثبت پروژه جدید هستند."
        )

    new_project = models.Project(
        company_id=current_user.id,
        title=project_in.title,
        description=project_in.description,
        required_skills=project_in.required_skills,
        deadline=project_in.deadline,
        project_type=project_in.project_type.value if hasattr(project_in.project_type, 'value') else project_in.project_type,
        requires_interview=project_in.requires_interview,
        weights=project_in.weights.model_dump() if project_in.weights else None
    )

    db.add(new_project)
    db.commit()
    db.refresh(new_project)

    return new_project