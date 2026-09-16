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
    models.Major: [
        "مهندسی کامپیوتر", "مهندسی برق", "مهندسی صنایع", "مهندسی مکانیک",
        "علوم کامپیوتر", "مدیریت / MBA", "مهندسی عمران", "سایر"
    ],
    models.City: ["تهران", "اصفهان", "شیراز", "مشهد", "تبریز", "کرج", "اهواز", "قم", "رشت", "دورکاری"],
    models.Category: ["توسعه نرم‌افزار", "طراحی UI/UX", "دیجیتال مارکتینگ", "هوش مصنوعی و داده", "شبکه و امنیت", "مدیریت و صنایع"],
    models.Skill: [
        "Flutter", "Dart", "Python", "React", "JavaScript", "SQL", "Figma",
        "UI/UX", "Django", "FastAPI", "Node.js", "C++", "Java", "Git", "Docker"
    ],
    models.ProjectTypeOption: ["پروژه", "کارآموزی", "امریه"],
}

def seed_options(db):
    """Inserts any missing option rows; safe to run on a database that already has data."""
    for model, names in OPTIONS.items():
        existing = {row.name for row in db.query(model).all()}
        for name in names:
            if name not in existing:
                db.add(model(name=name))

if __name__ == "__main__":
    # Creates only tables that don't exist yet (e.g. options_project_types); nothing is dropped.
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        seed_options(db)
        db.commit()
    finally:
        db.close()
