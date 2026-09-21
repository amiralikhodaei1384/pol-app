import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.db.session import engine, SessionLocal
from app.db.base import Base
from app.models import models

# Initial rows for the options_* tables. Edit the tables directly afterwards; the app reads only the database.
OPTIONS = {
    models.University: [
        "دانشگاه تهران", "دانشگاه صنعتی شریف", "دانشگاه صنعتی امیرکبیر",
        "دانشگاه علم و صنعت", "دانشگاه شهید بهشتی", "دانشگاه خواجه نصیر",
        "دانشگاه علامه طباطبایی", "دانشگاه اصفهان", "دانشگاه شیراز", "سایر"
    ],
    models.Degree: ["کاردانی", "کارشناسی", "کارشناسی ارشد", "دکتری"],
    models.City: ["تهران", "اصفهان", "شیراز", "مشهد", "تبریز", "کرج", "اهواز", "قم", "رشت", "دورکاری"],
    models.Category: ["توسعه نرم‌افزار", "طراحی UI/UX", "دیجیتال مارکتینگ", "هوش مصنوعی و داده", "شبکه و امنیت", "مدیریت و صنایع"],
    models.Skill: [
        "Flutter", "Dart", "Python", "React", "JavaScript", "SQL", "Figma",
        "UI/UX", "Django", "FastAPI", "Node.js", "C++", "Java", "Git", "Docker"
    ],
    models.ProjectTypeOption: ["پروژه", "کارآموزی", "امریه"],
}

# Majors differ by degree: undergraduate majors are broad fields, graduate ones are
# specializations written as "field - specialization". A name listed under several
# degrees is stored once with all of them.
MAJORS_BY_DEGREE = {
    "کاردانی": [
        "کاردانی فناوری اطلاعات", "کاردانی نرم‌افزار کامپیوتر", "کاردانی الکترونیک",
        "کاردانی برق", "کاردانی مکانیک", "کاردانی عمران", "کاردانی معماری",
        "کاردانی حسابداری", "کاردانی گرافیک",
    ],
    "کارشناسی": [
        "مهندسی کامپیوتر", "علوم کامپیوتر", "مهندسی فناوری اطلاعات", "مهندسی برق",
        "مهندسی مکانیک", "مهندسی عمران", "مهندسی صنایع", "مهندسی شیمی",
        "مهندسی مواد و متالورژی", "مهندسی معماری", "ریاضیات و کاربردها", "آمار و کاربردها",
        "فیزیک", "مدیریت بازرگانی", "مدیریت صنعتی", "حسابداری", "اقتصاد",
        "طراحی صنعتی", "گرافیک",
    ],
    "کارشناسی ارشد": [
        "مهندسی کامپیوتر - نرم‌افزار", "مهندسی کامپیوتر - هوش مصنوعی و رباتیکز",
        "مهندسی کامپیوتر - شبکه‌های کامپیوتری", "مهندسی کامپیوتر - معماری سیستم‌های کامپیوتری",
        "مهندسی کامپیوتر - امنیت اطلاعات", "علوم کامپیوتر - علوم داده",
        "مهندسی فناوری اطلاعات - تجارت الکترونیک", "مهندسی فناوری اطلاعات - مدیریت سیستم‌های اطلاعاتی",
        "مهندسی برق - الکترونیک", "مهندسی برق - مخابرات", "مهندسی برق - قدرت", "مهندسی برق - کنترل",
        "مهندسی مکانیک - طراحی کاربردی", "مهندسی مکانیک - تبدیل انرژی", "مهندسی مکانیک - ساخت و تولید",
        "مهندسی عمران - سازه", "مهندسی عمران - مدیریت ساخت",
        "مهندسی صنایع - بهینه‌سازی سیستم‌ها", "مهندسی صنایع - مدیریت پروژه",
        "مهندسی شیمی - فرایند", "ریاضی کاربردی - تحقیق در عملیات", "آمار ریاضی",
        "مدیریت / MBA", "مدیریت فناوری اطلاعات",
    ],
    "دکتری": [
        "مهندسی کامپیوتر - نرم‌افزار", "مهندسی کامپیوتر - هوش مصنوعی و رباتیکز",
        "مهندسی کامپیوتر - شبکه‌های کامپیوتری", "مهندسی کامپیوتر - معماری سیستم‌های کامپیوتری",
        "علوم کامپیوتر - علوم داده", "مهندسی برق - الکترونیک", "مهندسی برق - مخابرات",
        "مهندسی برق - قدرت", "مهندسی برق - کنترل", "مهندسی مکانیک - طراحی کاربردی",
        "مهندسی مکانیک - تبدیل انرژی", "مهندسی عمران - سازه", "مهندسی صنایع - بهینه‌سازی سیستم‌ها",
        "مهندسی شیمی - فرایند", "ریاضی کاربردی - تحقیق در عملیات", "مدیریت کسب‌وکار (DBA)",
    ],
}

# Offered at every degree.
MAJORS_FOR_ALL_DEGREES = ["سایر"]

# Scoring only compares bachelor majors, so every major that isn't a bachelor major names
# the one it builds on. "field - specialization" names default to their field; this lists
# the ones that don't follow that pattern, plus the associate (کاردانی) majors.
BACHELOR_MAJOR_OF = {
    "ریاضی کاربردی - تحقیق در عملیات": "ریاضیات و کاربردها",
    "آمار ریاضی": "آمار و کاربردها",
    "مدیریت / MBA": "مدیریت بازرگانی",
    "مدیریت فناوری اطلاعات": "مدیریت بازرگانی",
    "مدیریت کسب‌وکار (DBA)": "مدیریت بازرگانی",
    "کاردانی فناوری اطلاعات": "مهندسی فناوری اطلاعات",
    "کاردانی نرم‌افزار کامپیوتر": "مهندسی کامپیوتر",
    "کاردانی الکترونیک": "مهندسی برق",
    "کاردانی برق": "مهندسی برق",
    "کاردانی مکانیک": "مهندسی مکانیک",
    "کاردانی عمران": "مهندسی عمران",
    "کاردانی معماری": "مهندسی معماری",
    "کاردانی حسابداری": "حسابداری",
    "کاردانی گرافیک": "گرافیک",
}


def default_bachelor_major(name: str, degrees):
    """The bachelor major a non-bachelor major builds on (None for bachelor majors)."""
    if not degrees or "کارشناسی" in degrees:
        return None
    return BACHELOR_MAJOR_OF.get(name) or name.split(" - ")[0].strip()


def seed_majors(db):
    """Adds missing majors with their degrees. Existing majors only get degrees filled in
    when they have none yet, so choices made later in the admin panel are never overwritten."""
    wanted = {}
    for degree, names in MAJORS_BY_DEGREE.items():
        for name in names:
            wanted.setdefault(name, []).append(degree)
    for name in MAJORS_FOR_ALL_DEGREES:
        wanted.setdefault(name, None)

    existing = {row.name: row for row in db.query(models.Major).all()}
    for name, degrees in wanted.items():
        row = existing.get(name)
        if row is None:
            db.add(models.Major(name=name, degrees=degrees, bachelor_major=default_bachelor_major(name, degrees)))
            continue
        if not row.degrees and degrees:
            row.degrees = degrees
        if not row.bachelor_major:
            row.bachelor_major = default_bachelor_major(name, row.degrees)


def seed_options(db):
    """Inserts any missing option rows; safe to run on a database that already has data."""
    for model, names in OPTIONS.items():
        existing = {row.name for row in db.query(model).all()}
        for name in names:
            if name not in existing:
                db.add(model(name=name))
    # Majors are added after degrees so both land in the same commit.
    seed_majors(db)

if __name__ == "__main__":
    # Creates only tables that don't exist yet (e.g. options_project_types); nothing is dropped.
    Base.metadata.create_all(bind=engine)
    # create_all never adds columns to existing tables, so bring an older database up to date
    # here. Every statement is idempotent: running this again changes nothing.
    with engine.begin() as conn:
        for statement in [
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE",
            "ALTER TABLE applications ADD COLUMN IF NOT EXISTS decision_note TEXT",
            "ALTER TABLE applications ADD COLUMN IF NOT EXISTS decided_at TIMESTAMPTZ",
            "ALTER TABLE options_majors ADD COLUMN IF NOT EXISTS degrees JSON",
            "ALTER TABLE options_majors ADD COLUMN IF NOT EXISTS bachelor_major VARCHAR",
            "ALTER TABLE chat_threads ADD COLUMN IF NOT EXISTS admin_id UUID REFERENCES users(id)",
        ]:
            conn.exec_driver_sql(statement)
    db = SessionLocal()
    try:
        seed_options(db)
        db.commit()
    finally:
        db.close()
