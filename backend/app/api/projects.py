from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional

from ..db.session import get_db
from ..models import models
from ..schemas import schemas
from .auth import get_current_user

router = APIRouter()

UNIVERSITIES = [
    "دانشگاه تهران", "دانشگاه صنعتی شریف", "دانشگاه صنعتی امیرکبیر",
    "دانشگاه علم و صنعت", "دانشگاه شهید بهشتی", "دانشگاه خواجه نصیر",
    "دانشگاه علامه طباطبایی", "دانشگاه اصفهان", "دانشگاه شیراز", "سایر"
]
MAJORS = [
    "مهندسی کامپیوتر", "مهندسی برق", "مهندسی صنایع", "مهندسی مکانیک",
    "علوم کامپیوتر", "مدیریت / MBA", "مهندسی عمران", "سایر"
]
CITIES = ["تهران", "اصفهان", "شیراز", "مشهد", "تبریز", "کرج", "اهواز", "قم", "رشت", "دورکاری"]
CATEGORIES = ["توسعه نرم‌افزار", "طراحی UI/UX", "دیجیتال مارکتینگ", "هوش مصنوعی و داده", "شبکه و امنیت", "مدیریت و صنایع"]

def calculate_match_score(student_profile: models.StudentProfile, project: models.Project) -> int:
    if not student_profile: return 60
    target_univs = project.target_universities or []
    univ_score = 100 if (student_profile.university in target_univs) else (75 if not target_univs else 50)
    target_majors = project.target_majors or []
    major_score = 100 if (student_profile.major in target_majors) else (75 if not target_majors else 50)

    student_skills = set(student_profile.skills or [])
    project_skills = set(project.required_skills or [])
    skills_score = (len(student_skills.intersection(project_skills)) / len(project_skills) * 100) if project_skills else 70

    courses = student_profile.courses or []
    courses_score = (sum(c.get('grade', 15) for c in courses) / len(courses) / 20.0 * 100) if courses else 70

    weights = project.weights or {"university_weight": 0.25, "major_weight": 0.25, "skills_weight": 0.30, "courses_weight": 0.20}
    final_score = (
            univ_score * weights.get("university_weight", 0.25) +
            major_score * weights.get("major_weight", 0.25) +
            skills_score * weights.get("skills_weight", 0.30) +
            courses_score * weights.get("courses_weight", 0.20)
    )
    return max(40, min(98, round(final_score)))

# ۱. دریافت گزینه‌های فرم‌ها
@router.get("/options")
def get_options():
    return {"universities": UNIVERSITIES, "majors": MAJORS, "cities": CITIES, "categories": CATEGORIES}

# ۲. پروژه‌های پیشنهادی دانشجو
@router.get("/recommended")
def get_recommended_projects(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != models.UserRole.STUDENT or not current_user.student_profile: return []
    p_profile = current_user.student_profile
    all_p = db.query(models.Project).filter(models.Project.is_active == True).all()

    recommended = []
    for p in all_p:
        score = calculate_match_score(p_profile, p)
        if score >= 60:
            is_applied = db.query(models.Application).filter(models.Application.student_id == current_user.id, models.Application.project_id == p.id).first() is not None
            recommended.append({
                "id": str(p.id), "title": p.title, "description": p.description, "required_skills": p.required_skills,
                "deadline": p.deadline.isoformat() if p.deadline else None, "project_type": p.project_type, "city": getattr(p, 'city', 'تهران'),
                "company_name": p.company.name if p.company else "شرکت فناوری", "match_score": score, "is_applied": is_applied
            })
    recommended.sort(key=lambda x: x["match_score"], reverse=True)
    return recommended

# ۳. پروژه‌های ثبت‌شده توسط کارفرما
@router.get("/my-projects", response_model=List[schemas.ProjectOut])
def get_my_projects(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != models.UserRole.COMPANY_REP or not current_user.company_rep_profile:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="دسترسی غیرمجاز")
    company_id = current_user.company_rep_profile.company_id
    projects = db.query(models.Project).filter(models.Project.company_id == company_id).order_by(models.Project.created_at.desc()).all()
    for p in projects:
        if not getattr(p, 'city', None): p.city = "تهران"
        if not getattr(p, 'category', None): p.category = "توسعه نرم‌افزار"
    return projects

# ۴. لیست درخواست‌های اپلای‌شده دانشجو
# لیست درخواست‌های اپلای‌شده دانشجو به همراه اطلاعات کامل مصاحبه
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
                "company_name": project.company.name if project.company else "شرکت فناوری",
                "city": getattr(project, 'city', 'تهران') or "تهران",
                "project_type": project.project_type,
                "interview_date": app.interview_date,       # <--- ارسال تاریخ مصاحبه به دانشجو
                "interview_address": app.interview_address, # <--- ارسال آدرس محل مراجعه به دانشجو
                "interview_note": app.interview_note,       # <--- ارسال یادداشت کارفرما
            })
    return result
# ۵. بورد مدیریت رزومه‌ها و متقاضیان برای کارفرما
# بورد رزومه‌ها و متقاضیان دریافت شده برای کارفرما
# بورد رزومه‌ها و متقاضیان دریافت شده برای کارفرما (با قابلیت فیلتر بر اساس یک پروژه خاص)
@router.get("/company-applications")
def get_company_applications(
        project_id: Optional[str] = None, # <--- فیلتر اختیاری بر اساس پروژه
        db: Session = Depends(get_db),
        current_user: models.User = Depends(get_current_user)
):
    if current_user.role != models.UserRole.COMPANY_REP or not current_user.company_rep_profile:
        raise HTTPException(status_code=403, detail="دسترسی غیرمجاز")

    company_id = current_user.company_rep_profile.company_id
    company_projects = db.query(models.Project).filter(models.Project.company_id == company_id).all()
    project_ids = [p.id for p in company_projects]

    query = db.query(models.Application).filter(models.Application.project_id.in_(project_ids))

    # اگر آیدی پروژه ارسال شده باشد، فقط متقاضیان همان پروژه فیلتر می‌شوند
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
            "student_name": sp.full_name if (sp and sp.full_name) else "دانشجوی جدید",
            "student_phone": sp.phone if sp else "نامشخص",
            "student_university": sp.university if (sp and sp.university) else "نامشخص",
            "student_major": sp.major if (sp and sp.major) else "نامشخص",
            "student_skills": sp.skills if sp else [],
            "student_educations": sp.educations if sp else [],
            "student_work_experiences": sp.work_experiences if sp else [],
            "student_courses": sp.courses if sp else [],
            "student_resume": sp.resume_file if sp else None,
            "match_score": calculate_match_score(sp, a.project) if (sp and a.project) else 75,
            "status": a.status.value if hasattr(a.status, 'value') else str(a.status),
            "interview_date": a.interview_date,
            "interview_address": a.interview_address,
            "interview_note": a.interview_note,
            "has_chat": chat is not None,
            "chat_thread_id": str(chat.id) if chat else None,
        })
    return res

# ۶. لیست کل پروژه‌ها با فیلترها
# ۱. دریافت پروژه‌ها با فیلترهای چندتایی (Multi-Select)
@router.get("/")
def get_all_projects(
        project_type: Optional[str] = None,
        cities: Optional[str] = None,        # لیست شهرها جداشده با کاما: "تهران,اصفهان"
        categories: Optional[str] = None,    # لیست دسته‌بندی‌ها: "توسعه نرم‌افزار,طراحی UI/UX"
        majors: Optional[str] = None,        # لیست رشته‌ها: "مهندسی کامپیوتر,علوم کامپیوتر"
        universities: Optional[str] = None,  # لیست دانشگاه‌ها: "دانشگاه تهران,دانشگاه شریف"
        search: Optional[str] = None,
        db: Session = Depends(get_db),
        current_user: models.User = Depends(get_current_user)
):
    query = db.query(models.Project).filter(models.Project.is_active == True)

    if project_type and project_type != "همه":
        query = query.filter(models.Project.project_type == project_type)

    # تبدیل رشته‌های کامادار به لیست در پایتون
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
        # فیلتر چندتایی دانشگاه‌های مورد قبول کارفرما
        if univ_list and "همه" not in univ_list:
            p_target_univs = p.target_universities or []
            if p_target_univs and not any(u in p_target_univs for u in univ_list):
                continue

        # فیلتر چندتایی رشته‌های تحصیلی مرتبط
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
            "deadline": str(p.deadline) if p.deadline else "نامشخص",
            "project_type": p.project_type,
            "city": getattr(p, 'city', 'تهران') or "تهران",
            "category": getattr(p, 'category', 'توسعه نرم‌افزار') or "توسعه نرم‌افزار",
            "target_universities": p.target_universities or [],
            "target_majors": p.target_majors or [],
            "requires_interview": p.requires_interview,
            "company_name": p.company.name if p.company else "شرکت فناوری",
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

    return result

# ۷. ثبت پروژه جدید کارفرما
@router.post("/", response_model=schemas.ProjectOut, status_code=status.HTTP_201_CREATED)
def create_project(project_in: schemas.ProjectCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != models.UserRole.COMPANY_REP: raise HTTPException(status_code=403, detail="تنها کارفرما مجاز است.")
    if not current_user.company_rep_profile or not current_user.company_rep_profile.company_id: raise HTTPException(status_code=400, detail="اطلاعات شرکت یافت نشد.")
    company_id = current_user.company_rep_profile.company_id
    new_project = models.Project(
        company_id=company_id, title=project_in.title, description=project_in.description,
        required_skills=project_in.required_skills, deadline=project_in.deadline, project_type=project_in.project_type.value if hasattr(project_in.project_type, 'value') else project_in.project_type,
        city=project_in.city, category=project_in.category, target_universities=project_in.target_universities,
        target_majors=project_in.target_majors, requires_interview=project_in.requires_interview,
        weights=project_in.weights.model_dump() if project_in.weights else None
    )
    db.add(new_project)
    db.commit()
    db.refresh(new_project)
    return new_project

# ۸. دعوت به مصاحبه حضوری
@router.post("/applications/{app_id}/schedule-interview")
def schedule_interview(app_id: str, body: schemas.ScheduleInterviewSchema, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    app_obj = db.query(models.Application).filter(models.Application.id == app_id).first()
    if not app_obj: raise HTTPException(status_code=404, detail="درخواست یافت نشد.")

    app_obj.status = models.ApplicationStatus.SHORTLISTED
    app_obj.interview_date = body.interview_date
    app_obj.interview_address = body.interview_address
    app_obj.interview_note = body.interview_note

    # 🔔 ثبت نوتیفیکیشن خودکار برای دانشجو
    notif = models.Notification(
        user_id=app_obj.student_id,
        title="دعوت به مصاحبه حضوری",
        message=f"شما برای پروژه «{app_obj.project.title if app_obj.project else ''}» به مصاحبه حضوری دعوت شدید. تاریخ: {body.interview_date}",
        type="interview",
        link_id=str(app_obj.project_id)
    )
    db.add(notif)

    db.commit()
    return {"message": "دعوت به مصاحبه ثبت شد."}

# ۹. چت
@router.post("/chat/start")
def start_chat(app_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != models.UserRole.COMPANY_REP: raise HTTPException(status_code=403, detail="تنها کارفرما مجاز به شروع چت است.")
    app_obj = db.query(models.Application).filter(models.Application.id == app_id).first()
    if not app_obj: raise HTTPException(status_code=404, detail="درخواست یافت نشد.")
    existing_thread = db.query(models.ChatThread).filter(models.ChatThread.application_id == app_obj.id).first()
    if existing_thread: return {"thread_id": str(existing_thread.id)}
    new_thread = models.ChatThread(application_id=app_obj.id, employer_id=current_user.id, student_id=app_obj.student_id)
    db.add(new_thread)
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
    msgs = db.query(models.ChatMessage).filter(models.ChatMessage.thread_id == thread_id).order_by(models.ChatMessage.created_at.asc()).all()
    return [{"id": str(m.id), "sender_id": str(m.sender_id), "is_me": m.sender_id == current_user.id, "text": m.text, "created_at": m.created_at.strftime("%H:%M") if m.created_at else ""} for m in msgs]

@router.post("/chat/send")
def send_message(body: schemas.SendMessageSchema, db: Session = Depends(get_db), user: models.User = Depends(get_current_user)):
    msg = models.ChatMessage(thread_id=body.thread_id, sender_id=user.id, text=body.text)
    db.add(msg)

    # 🔔 ثبت نوتیفیکیشن پیام جدید برای طرف مقابل
    thread = db.query(models.ChatThread).filter(models.ChatThread.id == body.thread_id).first()
    if thread:
        recipient_id = thread.student_id if user.id == thread.employer_id else thread.employer_id
        sender_name = "کارفرما" if user.role == models.UserRole.COMPANY_REP else (user.student_profile.full_name if (user.student_profile and user.student_profile.full_name) else "دانشجو")
        notif = models.Notification(
            user_id=recipient_id,
            title="پیام جدید در چت",
            message=f"پیام جدید از طرف {sender_name}: {body.text[:35]}...",
            type="chat",
            link_id=str(thread.id)
        )
        db.add(notif)

    db.commit()
    return {"message": "پیام ارسال شد."}

# ۱۰. ثبت درخواست پروژه توسط دانشجو (حتماً باید انتهای فایل باشد)
@router.post("/{project_id}/apply")
def apply_for_project(project_id: str, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != models.UserRole.STUDENT: raise HTTPException(status_code=403, detail="تنها دانشجویان مجاز به ارسال درخواست هستند.")
    project = db.query(models.Project).filter(models.Project.id == project_id).first()
    if not project: raise HTTPException(status_code=404, detail="پروژه یافت نشد.")
    if db.query(models.Application).filter(models.Application.student_id == current_user.id, models.Application.project_id == project.id).first():
        raise HTTPException(status_code=400, detail="شما قبلاً برای این پروژه درخواست ارسال کرده‌اید.")

    db.add(models.Application(student_id=current_user.id, project_id=project.id, status=models.ApplicationStatus.APPLIED))

    # 🔔 ثبت نوتیفیکیشن خودکار برای کارفرما
    employer_rep = db.query(models.CompanyRepresentative).filter(models.CompanyRepresentative.company_id == project.company_id).first()
    if employer_rep:
        student_name = current_user.student_profile.full_name if (current_user.student_profile and current_user.student_profile.full_name) else "یک دانشجو"
        notif = models.Notification(
            user_id=employer_rep.user_id,
            title="درخواست جدید برای پروژه",
            message=f"{student_name} برای پروژه «{project.title}» درخواست ارسال کرد.",
            type="application",
            link_id=str(project.id)
        )
        db.add(notif)

    db.commit()
    return {"message": "درخواست شما با موفقیت ثبت شد."}







# دریافت تعداد پیام‌ها و نوتیفیکیشن‌های خوانده‌نشده
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

# دریافت لیست همه نوتیفیکیشن‌های کاربر
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
            "is_read": n.is_read,
            "created_at": n.created_at.strftime("%Y/%m/%d - %H:%M") if n.created_at else ""
        })
        # علامت‌گذاری به عنوان خوانده‌شده
        n.is_read = True

    db.commit()
    return res