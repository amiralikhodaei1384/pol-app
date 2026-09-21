import os
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from ..db.session import get_db
from ..models import models
from .auth import get_current_admin
from .projects import send_notification, to_shamsi

router = APIRouter()

# Option tables the admin can edit, keyed by the name the app uses for them.
OPTION_MODELS = {
    "universities": models.University,
    "majors": models.Major,
    "degrees": models.Degree,
    "cities": models.City,
    "categories": models.Category,
    "skills": models.Skill,
    "project_types": models.ProjectTypeOption,
}


class ActiveStatus(BaseModel):
    is_active: bool


class OptionIn(BaseModel):
    name: str = Field(..., min_length=1, max_length=150)


class BroadcastIn(BaseModel):
    title: str = Field(..., min_length=2, max_length=150)
    message: str = Field(..., min_length=2)
    # all | students | companies
    audience: str = "all"


def _uuid(value: str):
    try:
        return uuid.UUID(value)
    except ValueError:
        raise HTTPException(status_code=404, detail="مورد درخواستی یافت نشد.")


def _role(user: models.User) -> str:
    return user.role.value if hasattr(user.role, "value") else str(user.role)


# ---------- cascading deletes ----------
# The foreign keys have no ON DELETE rules, so children are removed explicitly, deepest first.

def _delete_threads(db: Session, thread_ids):
    if not thread_ids:
        return
    db.query(models.ChatMessage).filter(models.ChatMessage.thread_id.in_(thread_ids)).delete(synchronize_session=False)
    db.query(models.ChatThread).filter(models.ChatThread.id.in_(thread_ids)).delete(synchronize_session=False)


def _delete_applications(db: Session, app_ids):
    if not app_ids:
        return
    thread_ids = [t.id for t in db.query(models.ChatThread.id).filter(models.ChatThread.application_id.in_(app_ids))]
    _delete_threads(db, thread_ids)
    db.query(models.Application).filter(models.Application.id.in_(app_ids)).delete(synchronize_session=False)


def _delete_project(db: Session, project: models.Project):
    app_ids = [a.id for a in db.query(models.Application.id).filter(models.Application.project_id == project.id)]
    _delete_applications(db, app_ids)
    db.delete(project)


def _remove_resume_file(resume_path: Optional[str]):
    # resume_file is stored as a URL path like /uploads/resumes/<name>.pdf
    if not resume_path or not resume_path.startswith("/uploads/resumes/"):
        return
    local = os.path.join("uploads", "resumes", os.path.basename(resume_path))
    try:
        if os.path.isfile(local):
            os.remove(local)
    except OSError:
        pass


# ---------- statistics ----------

@router.get("/stats")
def get_stats(db: Session = Depends(get_db), admin: models.User = Depends(get_current_admin)):
    def count_users(*criteria):
        return db.query(func.count(models.User.id)).filter(*criteria).scalar() or 0

    def count_apps(status):
        return db.query(func.count(models.Application.id)).filter(models.Application.status == status).scalar() or 0

    now = datetime.now(timezone.utc)
    week_start = (now - timedelta(days=6)).replace(hour=0, minute=0, second=0, microsecond=0)

    recent = db.query(models.User.created_at).filter(models.User.created_at >= week_start).all()
    per_day = {}
    for (created,) in recent:
        if created:
            # Bucket by UTC day, the same clock week_start was computed on.
            day = (created.astimezone(timezone.utc) if created.tzinfo else created).date()
            per_day[day] = per_day.get(day, 0) + 1
    signups = []
    for i in range(7):
        day = (week_start + timedelta(days=i)).date()
        signups.append({"date_fa": to_shamsi(day), "count": per_day.get(day, 0)})

    top = (
        db.query(models.Project, func.count(models.Application.id).label("n"))
        .outerjoin(models.Application, models.Application.project_id == models.Project.id)
        .group_by(models.Project.id)
        .order_by(func.count(models.Application.id).desc())
        .limit(5)
        .all()
    )

    latest_users = db.query(models.User).order_by(models.User.created_at.desc()).limit(5).all()

    return {
        "users": {
            "total": count_users(),
            "students": count_users(models.User.role == models.UserRole.STUDENT),
            "companies": count_users(models.User.role == models.UserRole.COMPANY_REP),
            "admins": count_users(models.User.role == models.UserRole.ADMIN),
            "blocked": count_users(models.User.is_active == False),
            "new_this_week": len(recent),
        },
        "companies": db.query(func.count(models.Company.id)).scalar() or 0,
        "projects": {
            "total": db.query(func.count(models.Project.id)).scalar() or 0,
            "active": db.query(func.count(models.Project.id)).filter(models.Project.is_active == True).scalar() or 0,
        },
        "applications": {
            "total": db.query(func.count(models.Application.id)).scalar() or 0,
            "applied": count_apps(models.ApplicationStatus.APPLIED),
            "shortlisted": count_apps(models.ApplicationStatus.SHORTLISTED),
            "accepted": count_apps(models.ApplicationStatus.ACCEPTED),
            "rejected": count_apps(models.ApplicationStatus.REJECTED),
        },
        "chats": {
            "threads": db.query(func.count(models.ChatThread.id)).scalar() or 0,
            "messages": db.query(func.count(models.ChatMessage.id)).scalar() or 0,
        },
        "signups_last_7_days": signups,
        "top_projects": [
            {
                "id": str(p.id),
                "title": p.title,
                "company_name": p.company.name if p.company else "",
                "applications": n,
            }
            for p, n in top
        ],
        "latest_users": [_user_row(db, u) for u in latest_users],
    }


# ---------- users ----------

def _user_row(db: Session, u: models.User) -> dict:
    role = _role(u)
    name, detail, activity = "", "", 0
    if u.role == models.UserRole.STUDENT and u.student_profile:
        sp = u.student_profile
        name = sp.full_name or ""
        detail = " • ".join(x for x in [sp.university, sp.major] if x)
        activity = db.query(func.count(models.Application.id)).filter(models.Application.student_id == u.id).scalar() or 0
    elif u.role == models.UserRole.COMPANY_REP and u.company_rep_profile and u.company_rep_profile.company:
        c = u.company_rep_profile.company
        name = c.name or ""
        detail = c.address or ""
        activity = db.query(func.count(models.Project.id)).filter(models.Project.company_id == c.id).scalar() or 0
    elif u.role == models.UserRole.ADMIN:
        name = "مدیر سامانه"

    return {
        "id": str(u.id),
        "email": u.email,
        "role": role,
        "name": name,
        "detail": detail,
        # applications sent (student) or projects posted (company)
        "activity_count": activity,
        "is_active": bool(u.is_active),
        "created_at_fa": to_shamsi(u.created_at),
    }


@router.get("/users")
def list_users(
        role: Optional[str] = None,
        search: Optional[str] = None,
        db: Session = Depends(get_db),
        admin: models.User = Depends(get_current_admin),
):
    query = db.query(models.User)
    if role and role != "all":
        try:
            query = query.filter(models.User.role == models.UserRole(role))
        except ValueError:
            raise HTTPException(status_code=400, detail="نقش نامعتبر است.")

    if search and search.strip():
        sf = f"%{search.strip()}%"
        query = (
            query.outerjoin(models.StudentProfile, models.StudentProfile.user_id == models.User.id)
            .outerjoin(models.CompanyRepresentative, models.CompanyRepresentative.user_id == models.User.id)
            .outerjoin(models.Company, models.Company.id == models.CompanyRepresentative.company_id)
            .filter(or_(
                models.User.email.ilike(sf),
                models.StudentProfile.full_name.ilike(sf),
                models.Company.name.ilike(sf),
            ))
        )

    users = query.order_by(models.User.created_at.desc()).all()
    return [_user_row(db, u) for u in users]


def _managed_user(db: Session, user_id: str, admin: models.User) -> models.User:
    user = db.query(models.User).filter(models.User.id == _uuid(user_id)).first()
    if not user:
        raise HTTPException(status_code=404, detail="کاربر یافت نشد.")
    # Admin accounts are managed outside the panel so the last admin can never lock everyone out.
    if user.id == admin.id or user.role == models.UserRole.ADMIN:
        raise HTTPException(status_code=400, detail="حساب‌های مدیر از این بخش قابل تغییر نیستند.")
    return user


@router.patch("/users/{user_id}/status")
def set_user_status(user_id: str, body: ActiveStatus, db: Session = Depends(get_db), admin: models.User = Depends(get_current_admin)):
    user = _managed_user(db, user_id, admin)
    user.is_active = body.is_active
    db.commit()
    return {"message": "وضعیت کاربر به‌روزرسانی شد.", "is_active": user.is_active}


@router.delete("/users/{user_id}")
def delete_user(user_id: str, db: Session = Depends(get_db), admin: models.User = Depends(get_current_admin)):
    user = _managed_user(db, user_id, admin)

    # Their own applications (as a student) and every chat they took part in.
    app_ids = [a.id for a in db.query(models.Application.id).filter(models.Application.student_id == user.id)]
    _delete_applications(db, app_ids)
    thread_ids = [
        t.id for t in db.query(models.ChatThread.id).filter(
            or_(models.ChatThread.student_id == user.id, models.ChatThread.employer_id == user.id)
        )
    ]
    _delete_threads(db, thread_ids)
    db.query(models.ChatMessage).filter(models.ChatMessage.sender_id == user.id).delete(synchronize_session=False)
    db.query(models.Notification).filter(models.Notification.user_id == user.id).delete(synchronize_session=False)

    if user.student_profile:
        _remove_resume_file(user.student_profile.resume_file)
        db.delete(user.student_profile)

    rep = user.company_rep_profile
    if rep:
        company = rep.company
        db.delete(rep)
        db.flush()
        # A company nobody can log into any more takes its projects with it.
        if company and not db.query(models.CompanyRepresentative).filter(models.CompanyRepresentative.company_id == company.id).first():
            for project in db.query(models.Project).filter(models.Project.company_id == company.id).all():
                _delete_project(db, project)
            db.delete(company)

    db.delete(user)
    db.commit()
    return {"message": "کاربر و تمام اطلاعات وابسته به او حذف شد."}


# ---------- projects ----------

def _notify_company(db: Session, project: models.Project, title: str, message: str):
    for rep in db.query(models.CompanyRepresentative).filter(models.CompanyRepresentative.company_id == project.company_id).all():
        send_notification(db, rep.user_id, title, message, "admin", str(project.id))


@router.get("/projects")
def list_projects(
        search: Optional[str] = None,
        status: Optional[str] = None,
        db: Session = Depends(get_db),
        admin: models.User = Depends(get_current_admin),
):
    query = db.query(models.Project)
    if status == "active":
        query = query.filter(models.Project.is_active == True)
    elif status == "inactive":
        query = query.filter(models.Project.is_active == False)
    if search and search.strip():
        sf = f"%{search.strip()}%"
        query = query.outerjoin(models.Company, models.Company.id == models.Project.company_id).filter(
            or_(models.Project.title.ilike(sf), models.Company.name.ilike(sf))
        )

    counts = dict(
        db.query(models.Application.project_id, func.count(models.Application.id))
        .group_by(models.Application.project_id).all()
    )

    return [
        {
            "id": str(p.id),
            "title": p.title,
            "company_name": p.company.name if p.company else "",
            "project_type": p.project_type,
            "city": p.city or "",
            "category": p.category or "",
            "deadline": p.deadline or "",
            "applications": counts.get(p.id, 0),
            "is_active": bool(p.is_active),
            "created_at_fa": to_shamsi(p.created_at),
        }
        for p in query.order_by(models.Project.created_at.desc()).all()
    ]


@router.patch("/projects/{project_id}/status")
def set_project_status(project_id: str, body: ActiveStatus, db: Session = Depends(get_db), admin: models.User = Depends(get_current_admin)):
    project = db.query(models.Project).filter(models.Project.id == _uuid(project_id)).first()
    if not project:
        raise HTTPException(status_code=404, detail="پروژه یافت نشد.")
    if project.is_active != body.is_active:
        project.is_active = body.is_active
        if body.is_active:
            _notify_company(db, project, "فعال‌سازی مجدد پروژه", f"پروژه «{project.title}» توسط مدیر سامانه دوباره فعال شد.")
        else:
            _notify_company(db, project, "غیرفعال شدن پروژه", f"پروژه «{project.title}» توسط مدیر سامانه غیرفعال شد و به دانشجویان نمایش داده نمی‌شود.")
    db.commit()
    return {"message": "وضعیت پروژه به‌روزرسانی شد.", "is_active": project.is_active}


@router.delete("/projects/{project_id}")
def delete_project(project_id: str, db: Session = Depends(get_db), admin: models.User = Depends(get_current_admin)):
    project = db.query(models.Project).filter(models.Project.id == _uuid(project_id)).first()
    if not project:
        raise HTTPException(status_code=404, detail="پروژه یافت نشد.")
    _notify_company(db, project, "حذف پروژه", f"پروژه «{project.title}» توسط مدیر سامانه حذف شد.")
    _delete_project(db, project)
    db.commit()
    return {"message": "پروژه و درخواست‌های مرتبط حذف شد."}


# ---------- option lists ----------

def _option_model(kind: str):
    model = OPTION_MODELS.get(kind)
    if not model:
        raise HTTPException(status_code=404, detail="دسته‌بندی نامعتبر است.")
    return model


@router.get("/options")
def list_options(db: Session = Depends(get_db), admin: models.User = Depends(get_current_admin)):
    return {
        kind: [{"id": str(o.id), "name": o.name} for o in db.query(model).order_by(model.name).all()]
        for kind, model in OPTION_MODELS.items()
    }


@router.post("/options/{kind}")
def add_option(kind: str, body: OptionIn, db: Session = Depends(get_db), admin: models.User = Depends(get_current_admin)):
    model = _option_model(kind)
    name = body.name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="نام نمی‌تواند خالی باشد.")
    if db.query(model).filter(model.name == name).first():
        raise HTTPException(status_code=400, detail="این گزینه از قبل وجود دارد.")
    option = model(name=name)
    db.add(option)
    db.commit()
    return {"id": str(option.id), "name": option.name}


@router.delete("/options/{kind}/{option_id}")
def delete_option(kind: str, option_id: str, db: Session = Depends(get_db), admin: models.User = Depends(get_current_admin)):
    model = _option_model(kind)
    option = db.query(model).filter(model.id == _uuid(option_id)).first()
    if not option:
        raise HTTPException(status_code=404, detail="گزینه یافت نشد.")
    # Profiles and projects store the name as text, so existing data keeps its value.
    db.delete(option)
    db.commit()
    return {"message": "گزینه حذف شد."}


# ---------- announcements ----------

@router.post("/broadcast")
def broadcast(body: BroadcastIn, db: Session = Depends(get_db), admin: models.User = Depends(get_current_admin)):
    query = db.query(models.User.id).filter(models.User.is_active == True, models.User.role != models.UserRole.ADMIN)
    if body.audience == "students":
        query = query.filter(models.User.role == models.UserRole.STUDENT)
    elif body.audience == "companies":
        query = query.filter(models.User.role == models.UserRole.COMPANY_REP)
    elif body.audience != "all":
        raise HTTPException(status_code=400, detail="گروه مخاطب نامعتبر است.")

    recipients = [row.id for row in query.all()]
    for user_id in recipients:
        send_notification(db, user_id, body.title.strip(), body.message.strip(), "admin")
    db.commit()
    return {"message": "اعلان ارسال شد.", "recipients": len(recipients)}
