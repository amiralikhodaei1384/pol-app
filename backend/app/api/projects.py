from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
import math

from ..db.session import get_db
from ..models import models
from ..schemas import schemas
from .auth import get_current_user

router = APIRouter()

# تابع محاسبه درصد تطابق هوشمند (بخش ۳ داک)
def calculate_match_score(student_profile: models.StudentProfile, project: models.Project) -> int:
    if not student_profile:
        return 60  # درصد پایه

    # ۱. محاسبه تطابق مهارت‌ها
    student_skills = set(student_profile.skills or [])
    required_skills = set(project.required_skills or [])
    skills_score = 0
    if required_skills:
        matched = student_skills.intersection(required_skills)
        skills_score = (len(matched) / len(required_skills)) * 100

    # ۲. محاسبه تطابق نمرات و دروس گذرانده‌شده
    courses = student_profile.courses or []
    courses_score = 70
    if courses:
        avg_grade = sum(c.get('grade', 15) for c in courses) / len(courses)
        courses_score = min(100, (avg_grade / 20.0) * 100)

    # ۳. اعمال وزن‌های تعیین‌شده توسط کارفرما
    weights = project.weights or {
        "university_weight": 0.25,
        "major_weight": 0.25,
        "skills_weight": 0.30,
        "courses_weight": 0.20
    }

    univ_score = 90 if student_profile.university else 60
    major_score = 85 if student_profile.major else 60

    final_score = (
            univ_score * weights.get("university_weight", 0.25) +
            major_score * weights.get("major_weight", 0.25) +
            skills_score * weights.get("skills_weight", 0.30) +
            courses_score * weights.get("courses_weight", 0.20)
    )

    return max(45, min(98, round(final_score)))


# ثبت پروژه جدید توسط کارفرما
@router.post("/", response_model=schemas.ProjectOut, status_code=status.HTTP_201_CREATED)
def create_project(
        project_in: schemas.ProjectCreate,
        db: Session = Depends(get_db),
        current_user: models.User = Depends(get_current_user)
):
    if current_user.role != models.UserRole.COMPANY_REP:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="تنها نمایندگان شرکت‌ها مجاز به ثبت پروژه هستند.")

    if not current_user.company_rep_profile or not current_user.company_rep_profile.company_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="اطلاعات شرکت یافت نشد.")

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


# دریافت همه پروژه‌ها به همراه درصد تطابق دانشجو
@router.get("/")
def get_all_projects(
        db: Session = Depends(get_db),
        current_user: models.User = Depends(get_current_user)
):
    projects = db.query(models.Project).filter(models.Project.is_active == True).order_by(models.Project.created_at.desc()).all()

    student_profile = None
    if current_user.role == models.UserRole.STUDENT:
        student_profile = db.query(models.StudentProfile).filter(models.StudentProfile.user_id == current_user.id).first()

    result = []
    for p in projects:
        match_score = calculate_match_score(student_profile, p) if student_profile else 75
        p_dict = {
            "id": str(p.id),
            "title": p.title,
            "description": p.description,
            "required_skills": p.required_skills,
            "deadline": p.deadline.isoformat() if p.deadline else None,
            "project_type": p.project_type,
            "requires_interview": p.requires_interview,
            "company_name": p.company.name if p.company else "شرکت فناوری",
            "match_score": match_score,
            "is_applied": False
        }

        # بررسی اینکه آیا دانشجو قبلا درخواست داده است یا خیر
        if current_user.role == models.UserRole.STUDENT:
            app = db.query(models.Application).filter(
                models.Application.student_id == current_user.id,
                models.Application.project_id == p.id
            ).first()
            if app:
                p_dict["is_applied"] = True
                p_dict["application_status"] = app.status.value if hasattr(app.status, 'value') else str(app.status)

        result.append(p_dict)

    return result


# دریافت پروژه‌های خود کارفرما
@router.get("/my-projects", response_model=List[schemas.ProjectOut])
def get_my_projects(
        db: Session = Depends(get_db),
        current_user: models.User = Depends(get_current_user)
):
    if current_user.role != models.UserRole.COMPANY_REP or not current_user.company_rep_profile:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="دسترسی غیرمجاز")

    company_id = current_user.company_rep_profile.company_id
    return db.query(models.Project).filter(models.Project.company_id == company_id).order_by(models.Project.created_at.desc()).all()


# ثبت درخواست پروژه توسط دانشجو (بخش ۴.۲ داک)
@router.post("/{project_id}/apply")
def apply_for_project(
        project_id: str,
        db: Session = Depends(get_db),
        current_user: models.User = Depends(get_current_user)
):
    if current_user.role != models.UserRole.STUDENT:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="تنها دانشجویان مجاز به ارسال درخواست هستند.")

    project = db.query(models.Project).filter(models.Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=404, detail="پروژه یافت نشد.")

    # بررسی تکراری نبودن درخواست
    existing_app = db.query(models.Application).filter(
        models.Application.student_id == current_user.id,
        models.Application.project_id == project_id
    ).first()

    if existing_app:
        raise HTTPException(status_code=400, detail="شما قبلاً برای این پروژه درخواست ارسال کرده‌اید.")

    new_application = models.Application(
        student_id=current_user.id,
        project_id=project_id,
        status=models.ApplicationStatus.APPLIED
    )

    db.add(new_application)
    db.commit()

    return {"message": "درخواست شما با موفقیت ثبت شد و در انتظار بررسی کارفرما است."}