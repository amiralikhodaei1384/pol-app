from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.orm import Session
from typing import List, Optional
import uuid
import re
import os

from ..db.session import get_db
from ..models import models
from ..schemas import schemas
from .auth import get_current_user, calculate_profile_completion

router = APIRouter()

UPLOAD_DIR = "uploads/resumes"
CHAT_UPLOAD_DIR = "uploads/chat"

# Only adds to the session: the caller's commit saves the notification together with the change it describes.
def send_notification(db: Session, user_id, title: str, message: str, notif_type: str, link_id: str = None):
    target_uuid = uuid.UUID(str(user_id)) if not isinstance(user_id, uuid.UUID) else user_id
    db.add(models.Notification(
        user_id=target_uuid,
        title=title,
        message=message,
        type=notif_type,
        link_id=str(link_id) if link_id else None,
        is_read=False
    ))

@router.get("/options")
def get_options(db: Session = Depends(get_db)):
    return {
        "universities": [u.name for u in db.query(models.University).all()],
        "majors": [m.name for m in db.query(models.Major).all()],
        "degrees": [d.name for d in db.query(models.Degree).all()],
        "cities": [c.name for c in db.query(models.City).all()],
        "categories": [c.name for c in db.query(models.Category).all()],
        "skills": [s.name for s in db.query(models.Skill).all()],
        "project_types": [t.name for t in db.query(models.ProjectTypeOption).all()],
    }

@router.get("/notifications/counts")
def get_notification_counts(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    unread_notifs = db.query(models.Notification).filter(
        models.Notification.user_id == current_user.id,
        models.Notification.is_read == False
    ).count()

    unread_chats = db.query(models.Notification).filter(
        models.Notification.user_id == current_user.id,
        models.Notification.type == "chat",
        models.Notification.is_read == False
    ).count()

    return {
        "unread_notifications": unread_notifs,
        "unread_chats": unread_chats
    }

@router.get("/notifications/")
def get_notifications(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    notifs = db.query(models.Notification).filter(models.Notification.user_id == current_user.id).order_by(models.Notification.created_at.desc()).all()

    res = []
    for n in notifs:
        res.append({
            "id": str(n.id),
            "title": n.title,
            "message": n.message,
            "type": n.type,
            "link_id": n.link_id,
            "is_read": n.is_read,
            "created_at": n.created_at.strftime("%Y/%m/%d - %H:%M") if n.created_at else ""
        })
        n.is_read = True

    db.commit()
    return res

# Fallback weights when a project was created before the employer could tune them.
DEFAULT_MATCH_WEIGHTS = {
    "university_weight": 0.25,
    "major_weight": 0.25,
    "skills_weight": 0.25,
    "degree_weight": 0.10,
    "profile_weight": 0.15,
}


def _ranked_score(candidates: List[str], targets: List[str]) -> Optional[float]:
    """Score the best rank any of the student's entries reaches in the employer's list.

    Returns None when the employer left the list empty. That means "I did not ask
    about this", not "everyone is an 80" - an unscored axis drops out of the average
    entirely, so leaving fields blank cannot inflate what students see.

    Every degree the student has on file is a candidate, so adding a second degree
    can only ever help them - it can never displace a better-matching first one.
    """
    if not targets:
        return None
    ranks = [targets.index(c) for c in candidates if c and c in targets]
    if not ranks:
        return 40.0
    return {0: 100.0, 1: 85.0, 2: 70.0}.get(min(ranks), 60.0)


def calculate_match_score(student_profile: models.StudentProfile, project: models.Project) -> int:
    if not student_profile:
        return 50

    # The profile builder derives the university/major columns from the first
    # education entry, so the columns alone under-report a student with several
    # degrees. Consider the columns and every entry together.
    educations = [e for e in (student_profile.educations or []) if isinstance(e, dict)]
    univ_score = _ranked_score(
        [student_profile.university] + [e.get("university") for e in educations],
        project.target_universities or [],
    )
    major_score = _ranked_score(
        [student_profile.major] + [e.get("major") for e in educations],
        project.target_majors or [],
    )
    # No universal ladder here: a کارآموزی posting may rank کارشناسی top and
    # دکتری last. An employer who leaves the list empty scores no degree at all.
    degree_score = _ranked_score(
        [e.get("degree") for e in educations],
        project.target_degrees or [],
    )

    required_skills = set(project.required_skills or [])
    if required_skills:
        matched = set(student_profile.skills or []).intersection(required_skills)
        skills_score = len(matched) / len(required_skills) * 100
    else:
        skills_score = None

    # Deliberately project-independent: this is the same "تکمیل پروفایل" percentage the
    # student sees on their dashboard. Filling the profile in helps them everywhere,
    # whether or not what they filled in happens to suit this particular project.
    # It is the one axis the employer cannot switch off.
    profile_score = float(calculate_profile_completion(student_profile))

    weights = project.weights or DEFAULT_MATCH_WEIGHTS
    axes = [
        (univ_score, "university_weight"),
        (major_score, "major_weight"),
        (degree_score, "degree_weight"),
        (skills_score, "skills_weight"),
        (profile_score, "profile_weight"),
    ]
    scored = [
        (score, weights.get(key, DEFAULT_MATCH_WEIGHTS[key]))
        for score, key in axes
        if score is not None and weights.get(key, DEFAULT_MATCH_WEIGHTS[key]) > 0
    ]

    total_w = sum(w for _, w in scored)
    if total_w <= 0:
        return 50

    final_score = sum(score * w for score, w in scored) / total_w
    return max(35, min(98, round(final_score)))

@router.get("/recommended")
def get_recommended_projects(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != models.UserRole.STUDENT or not current_user.student_profile:
        return []

    p_profile = current_user.student_profile
    all_p = db.query(models.Project).filter(models.Project.is_active == True).all()

    recommended = []
    for p in all_p:
        score = calculate_match_score(p_profile, p)
        if score >= 60:
            is_applied = db.query(models.Application).filter(
                models.Application.student_id == current_user.id,
                models.Application.project_id == p.id
            ).first() is not None

            recommended.append({
                "id": str(p.id),
                "title": p.title,
                "description": p.description,
                "required_skills": p.required_skills,
                "deadline": str(p.deadline) if p.deadline else "",
                "project_type": p.project_type,
                "city": p.city,
                "company_name": p.company.name if p.company else "",
                "match_score": score,
                "is_applied": is_applied
            })

    recommended.sort(key=lambda x: x["match_score"], reverse=True)
    return recommended

@router.get("/my-projects", response_model=List[schemas.ProjectOut])
def get_my_projects(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != models.UserRole.COMPANY_REP or not current_user.company_rep_profile:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="دسترسی غیرمجاز")

    company_id = current_user.company_rep_profile.company_id
    projects = db.query(models.Project).filter(models.Project.company_id == company_id).order_by(models.Project.created_at.desc()).all()

    return projects

@router.get("/my-applications")
def get_my_applications(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != models.UserRole.STUDENT:
        raise HTTPException(status_code=403, detail="تنها دانشجویان به این بخش دسترسی دارند.")

    applications = db.query(models.Application).filter(models.Application.student_id == current_user.id).order_by(models.Application.created_at.desc()).all()
    result = []
    for app in applications:
        project = app.project
        if project:
            raw_status = app.status.value if hasattr(app.status, 'value') else str(app.status)
            raw_status_clean = str(raw_status).split('.')[-1].lower()

            status_fa = "در انتظار بررسی"
            if raw_status_clean in ["shortlisted", "applicationsstatus.shortlisted"]:
                status_fa = "دعوت به مصاحبه حضوری"
            elif raw_status_clean in ["accepted", "applicationsstatus.accepted"]:
                status_fa = "پذیرفته شده"
            elif raw_status_clean in ["rejected", "applicationsstatus.rejected"]:
                status_fa = "رد شده"

            result.append({
                "id": str(app.id),
                "status": raw_status_clean,
                "status_fa": status_fa,
                "created_at": app.created_at.strftime("%Y/%m/%d") if app.created_at else "",
                "project_id": str(project.id),
                "title": project.title,
                "company_name": project.company.name if project.company else "",
                "city": project.city,
                "project_type": project.project_type,
                "interview_date": app.interview_date,
                "interview_address": app.interview_address,
                "interview_note": app.interview_note,
            })
    return result

@router.get("/company-applications")
def get_company_applications(
        project_id: Optional[str] = None,
        db: Session = Depends(get_db),
        current_user: models.User = Depends(get_current_user)
):
    if current_user.role != models.UserRole.COMPANY_REP or not current_user.company_rep_profile:
        raise HTTPException(status_code=403, detail="دسترسی غیرمجاز")

    company_id = current_user.company_rep_profile.company_id
    company_projects = db.query(models.Project).filter(models.Project.company_id == company_id).all()
    project_ids = [p.id for p in company_projects]

    query = db.query(models.Application).filter(models.Application.project_id.in_(project_ids))

    if project_id and project_id.strip():
        query = query.filter(models.Application.project_id == project_id)

    apps = query.order_by(models.Application.created_at.desc()).all()
    res = []
    for a in apps:
        student_user = db.query(models.User).filter(models.User.id == a.student_id).first()
        sp = student_user.student_profile if student_user else None
        chat = db.query(models.ChatThread).filter(models.ChatThread.application_id == a.id).first()

        res.append({
            "application_id": str(a.id),
            "project_title": a.project.title if a.project else "",
            "student_name": sp.full_name if (sp and sp.full_name) else "",
            "student_phone": sp.phone if sp else "",
            "student_university": sp.university if (sp and sp.university) else "",
            "student_major": sp.major if (sp and sp.major) else "",
            "student_skills": sp.skills if sp else [],
            "student_educations": sp.educations if sp else [],
            "student_work_experiences": sp.work_experiences if sp else [],
            "student_courses": sp.courses if sp else [],
            "student_resume": sp.resume_file if sp else None,
            "student_message": a.message,
            "match_score": calculate_match_score(sp, a.project) if (sp and a.project) else 75,
            "status": a.status.value if hasattr(a.status, 'value') else str(a.status),
            "interview_date": a.interview_date,
            "interview_address": a.interview_address,
            "interview_note": a.interview_note,
            "has_chat": chat is not None,
            "chat_thread_id": str(chat.id) if chat else None,
        })
    return res

@router.get("/")
def get_all_projects(
        project_type: Optional[str] = None,
        cities: Optional[str] = None,
        categories: Optional[str] = None,
        majors: Optional[str] = None,
        universities: Optional[str] = None,
        search: Optional[str] = None,
        db: Session = Depends(get_db),
        current_user: models.User = Depends(get_current_user)
):
    query = db.query(models.Project).filter(models.Project.is_active == True)

    if project_type and project_type != "همه":
        query = query.filter(models.Project.project_type == project_type)

    city_list = [c.strip() for c in cities.split(",")] if cities else []
    cat_list = [c.strip() for c in categories.split(",")] if categories else []
    major_list = [m.strip() for m in majors.split(",")] if majors else []
    univ_list = [u.strip() for u in universities.split(",")] if universities else []

    if city_list and "همه" not in city_list:
        query = query.filter(models.Project.city.in_(city_list))

    if cat_list and "همه" not in cat_list:
        query = query.filter(models.Project.category.in_(cat_list))

    if search and search.strip():
        sf = f"%{search.strip()}%"
        query = query.filter((models.Project.title.ilike(sf)) | (models.Project.description.ilike(sf)))

    projects = query.order_by(models.Project.created_at.desc()).all()

    student_profile = db.query(models.StudentProfile).filter(models.StudentProfile.user_id == current_user.id).first() if current_user.role == models.UserRole.STUDENT else None

    result = []
    for p in projects:
        if univ_list and "همه" not in univ_list:
            p_target_univs = p.target_universities or []
            if p_target_univs and not any(u in p_target_univs for u in univ_list):
                continue

        if major_list and "همه" not in major_list:
            p_target_majors = p.target_majors or []
            if p_target_majors and not any(m in p_target_majors for m in major_list):
                continue

        match_score = calculate_match_score(student_profile, p) if student_profile else 75
        p_dict = {
            "id": str(p.id),
            "title": p.title,
            "description": p.description,
            "required_skills": p.required_skills,
            "deadline": str(p.deadline) if p.deadline else "",
            "project_type": p.project_type,
            "city": p.city,
            "category": p.category,
            "target_universities": p.target_universities or [],
            "target_majors": p.target_majors or [],
            "requires_interview": p.requires_interview,
            "company_name": p.company.name if p.company else "",
            "company_about": p.company.about if (p.company and getattr(p.company, 'about', None)) else "",
            "company_website": p.company.website if (p.company and getattr(p.company, 'website', None)) else "",
            "company_address": p.company.address if (p.company and getattr(p.company, 'address', None)) else "",
            "match_score": match_score,
            "is_applied": False
        }

        if current_user.role == models.UserRole.STUDENT:
            app = db.query(models.Application).filter(
                models.Application.student_id == current_user.id,
                models.Application.project_id == p.id
            ).first()
            if app:
                p_dict["is_applied"] = True

        result.append(p_dict)

    result.sort(key=lambda x: x["match_score"], reverse=True)
    return result

@router.post("/", response_model=schemas.ProjectOut, status_code=status.HTTP_201_CREATED)
def create_project(project_in: schemas.ProjectCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != models.UserRole.COMPANY_REP:
        raise HTTPException(status_code=403, detail="تنها کارفرما مجاز است.")
    if not current_user.company_rep_profile or not current_user.company_rep_profile.company_id:
        raise HTTPException(status_code=400, detail="اطلاعات شرکت یافت نشد.")
    if not db.query(models.ProjectTypeOption).filter(models.ProjectTypeOption.name == project_in.project_type).first():
        raise HTTPException(status_code=400, detail="نوع همکاری انتخاب‌شده معتبر نیست.")

    company_id = current_user.company_rep_profile.company_id
    new_project = models.Project(
        company_id=company_id,
        title=project_in.title,
        description=project_in.description,
        required_skills=project_in.required_skills,
        deadline=project_in.deadline,
        project_type=project_in.project_type,
        city=project_in.city,
        category=project_in.category,
        target_universities=project_in.target_universities,
        target_majors=project_in.target_majors,
        target_degrees=project_in.target_degrees,
        requires_interview=project_in.requires_interview,
        weights=project_in.weights.model_dump() if project_in.weights else None
    )
    db.add(new_project)
    db.commit()
    db.refresh(new_project)
    return new_project

@router.post("/applications/{app_id}/schedule-interview")
def schedule_interview(app_id: str, body: schemas.ScheduleInterviewSchema, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    try:
        a_uuid = uuid.UUID(app_id)
    except ValueError:
        a_uuid = app_id

    app_obj = db.query(models.Application).filter(models.Application.id == a_uuid).first()
    if not app_obj:
        raise HTTPException(status_code=404, detail="درخواست یافت نشد.")

    app_obj.status = models.ApplicationStatus.SHORTLISTED
    app_obj.interview_date = body.interview_date
    app_obj.interview_address = body.interview_address
    app_obj.interview_note = body.interview_note

    send_notification(
        db=db,
        user_id=app_obj.student_id,
        title="دعوت به مصاحبه حضوری",
        message=f"شما برای پروژه «{app_obj.project.title if app_obj.project else ''}» به مصاحبه حضوری دعوت شدید. تاریخ: {body.interview_date}",
        notif_type="interview",
        link_id=str(app_obj.project_id)
    )

    db.commit()
    return {"message": "دعوت به مصاحبه ثبت شد."}

@router.post("/chat/start")
def start_chat(app_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != models.UserRole.COMPANY_REP:
        raise HTTPException(status_code=403, detail="تنها کارفرما مجاز است.")
    app_obj = db.query(models.Application).filter(models.Application.id == app_id).first()
    if not app_obj:
        raise HTTPException(status_code=404, detail="درخواست یافت نشد.")
    existing_thread = db.query(models.ChatThread).filter(models.ChatThread.application_id == app_obj.id).first()
    if existing_thread:
        return {"thread_id": str(existing_thread.id)}
    new_thread = models.ChatThread(application_id=app_obj.id, employer_id=current_user.id, student_id=app_obj.student_id)
    db.add(new_thread)
    db.flush()

    send_notification(
        db=db,
        user_id=app_obj.student_id,
        title="گفتگوی جدید با کارفرما",
        message=f"کارفرما درباره پروژه «{app_obj.project.title if app_obj.project else ''}» یک گفتگو با شما شروع کرد.",
        notif_type="chat",
        link_id=str(new_thread.id)
    )

    db.commit()
    db.refresh(new_thread)
    return {"thread_id": str(new_thread.id)}

@router.get("/chat/threads")
def get_chat_threads(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    threads = db.query(models.ChatThread).filter(models.ChatThread.student_id == current_user.id).all() if current_user.role == models.UserRole.STUDENT else db.query(models.ChatThread).filter(models.ChatThread.employer_id == current_user.id).all()
    res = []
    for t in threads:
        app_obj = db.query(models.Application).filter(models.Application.id == t.application_id).first()
        other_name = "کارفرما"
        if current_user.role == models.UserRole.COMPANY_REP and app_obj and app_obj.student and app_obj.student.student_profile:
            other_name = app_obj.student.student_profile.full_name or "دانشجو"
        res.append({"thread_id": str(t.id), "title": app_obj.project.title if (app_obj and app_obj.project) else "گفتگو", "other_party": other_name})
    return res

@router.get("/chat/messages/{thread_id}")
def get_messages(thread_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    try:
        t_uuid = uuid.UUID(thread_id)
    except ValueError:
        t_uuid = thread_id

    unread_msgs = db.query(models.ChatMessage).filter(
        models.ChatMessage.thread_id == t_uuid,
        models.ChatMessage.sender_id != current_user.id,
        models.ChatMessage.is_read == False
    ).all()

    for msg in unread_msgs:
        msg.is_read = True

    # Opening the conversation clears its chat badge.
    db.query(models.Notification).filter(
        models.Notification.user_id == current_user.id,
        models.Notification.type == "chat",
        models.Notification.link_id == str(t_uuid),
        models.Notification.is_read == False
    ).update({"is_read": True}, synchronize_session=False)
    db.commit()

    msgs = db.query(models.ChatMessage).filter(models.ChatMessage.thread_id == t_uuid).order_by(models.ChatMessage.created_at.asc()).all()

    return [{
        "id": str(m.id),
        "sender_id": str(m.sender_id),
        "is_me": (str(m.sender_id) == str(current_user.id)),
        "text": m.text or "",
        "file_url": m.file_url,
        "file_type": m.file_type,
        "file_name": m.file_name,
        "is_read": bool(m.is_read),
        "is_edited": getattr(m, 'is_edited', False),
        "created_at": m.created_at.strftime("%H:%M") if m.created_at else ""
    } for m in msgs]

@router.post("/chat/send")
def send_message(body: schemas.SendMessageSchema, db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    msg = models.ChatMessage(
        thread_id=body.thread_id,
        sender_id=user.id,
        text=body.text,
        file_url=body.file_url,
        file_type=body.file_type,
        file_name=body.file_name
    )
    db.add(msg)
    thread = db.query(models.ChatThread).filter(models.ChatThread.id == body.thread_id).first()
    if thread:
        recipient_id = thread.student_id if str(user.id) == str(thread.employer_id) else thread.employer_id

        sender_name = "کارفرما" if user.role == models.UserRole.COMPANY_REP else (user.student_profile.full_name if (user.student_profile and user.student_profile.full_name) else "دانشجو")

        msg_preview = f"فایل پیوست: {body.file_name}" if body.file_url else (body.text[:35] if body.text else "پیام جدید")
        send_notification(
            db=db,
            user_id=recipient_id,
            title="پیام جدید در چت",
            message=f"پیام جدید از طرف {sender_name}: {msg_preview}",
            notif_type="chat",
            link_id=str(thread.id)
        )

    db.commit()
    return {"message": "پیام ارسال شد."}

@router.put("/chat/messages/{message_id}")
def edit_chat_message(
        message_id: str,
        body: schemas.EditMessageSchema,
        db: Session = Depends(get_db),
        current_user: models.User = Depends(get_current_user)
):
    try:
        msg_uuid = uuid.UUID(message_id)
    except ValueError:
        msg_uuid = message_id

    msg = db.query(models.ChatMessage).filter(models.ChatMessage.id == msg_uuid).first()
    if not msg:
        raise HTTPException(status_code=404, detail="پیام یافت نشد.")

    if str(msg.sender_id) != str(current_user.id):
        raise HTTPException(status_code=403, detail="تنها مجاز به ویرایش پیام‌های خود هستید.")

    msg.text = body.text
    msg.is_edited = True
    db.commit()
    return {"message": "پیام با موفقیت ویرایش شد."}

@router.delete("/notifications/{notification_id}")
def delete_notification(
        notification_id: str,
        db: Session = Depends(get_db),
        current_user: models.User = Depends(get_current_user)
):
    try:
        n_uuid = uuid.UUID(notification_id)
    except ValueError:
        n_uuid = notification_id

    notif = db.query(models.Notification).filter(
        models.Notification.id == n_uuid,
        models.Notification.user_id == current_user.id
    ).first()

    if notif:
        db.delete(notif)
        db.commit()

    return {"message": "اعلان با موفقیت حذف شد."}

@router.delete("/chat/messages/{message_id}")
def delete_chat_message(
        message_id: str,
        db: Session = Depends(get_db),
        current_user: models.User = Depends(get_current_user)
):
    try:
        msg_uuid = uuid.UUID(message_id)
    except ValueError:
        msg_uuid = message_id

    msg = db.query(models.ChatMessage).filter(models.ChatMessage.id == msg_uuid).first()
    if not msg:
        raise HTTPException(status_code=404, detail="پیام یافت نشد.")

    if str(msg.sender_id) != str(current_user.id):
        raise HTTPException(status_code=403, detail="شما تنها مجاز به حذف پیام‌های خود هستید.")

    db.delete(msg)
    db.commit()
    return {"message": "پیام با موفقیت حذف شد."}

@router.delete("/{project_id}")
def delete_project(
        project_id: str,
        db: Session = Depends(get_db),
        current_user: models.User = Depends(get_current_user)
):
    if current_user.role != models.UserRole.COMPANY_REP or not current_user.company_rep_profile:
        raise HTTPException(status_code=403, detail="تنها کارفرما مجاز است.")

    company_id = current_user.company_rep_profile.company_id
    project = db.query(models.Project).filter(
        models.Project.id == project_id,
        models.Project.company_id == company_id
    ).first()

    if not project:
        raise HTTPException(status_code=404, detail="پروژه یافت نشد یا شما دسترسی حذف آن را ندارید.")

    db.delete(project)
    db.commit()
    return {"message": "پروژه با موفقیت حذف شد."}

@router.post("/{project_id}/apply")
def apply_for_project(
        project_id: str,
        body: Optional[schemas.ApplyProjectSchema] = None,
        db: Session = Depends(get_db),
        current_user: models.User = Depends(get_current_user)
):
    if current_user.role != models.UserRole.STUDENT:
        raise HTTPException(status_code=403, detail="تنها دانشجویان مجاز به ارسال درخواست هستند.")

    project = db.query(models.Project).filter(models.Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=404, detail="پروژه یافت نشد.")

    if db.query(models.Application).filter(models.Application.student_id == current_user.id, models.Application.project_id == project.id).first():
        raise HTTPException(status_code=400, detail="شما قبلاً برای این پروژه درخواست ارسال کرده‌اید.")

    user_msg = body.message if body else None

    new_app = models.Application(
        student_id=current_user.id,
        project_id=project.id,
        message=user_msg,
        status=models.ApplicationStatus.APPLIED
    )
    db.add(new_app)

    employer_rep = db.query(models.CompanyRepresentative).filter(models.CompanyRepresentative.company_id == project.company_id).first()
    if employer_rep:
        student_name = current_user.student_profile.full_name if (current_user.student_profile and current_user.student_profile.full_name) else "یک دانشجو"
        msg_preview = f" با پیام: «{user_msg[:30]}...»" if user_msg else ""
        send_notification(
            db=db,
            user_id=employer_rep.user_id,
            title="درخواست جدید برای پروژه",
            message=f"{student_name} برای پروژه «{project.title}» درخواست فرستاد{msg_preview}.",
            notif_type="application",
            link_id=str(project.id)
        )

    db.commit()
    return {"message": "درخواست شما با موفقیت ثبت شد."}