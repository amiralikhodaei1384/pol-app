import os
import sys
from datetime import datetime, timedelta

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.db.session import engine, SessionLocal
from app.db.base import Base
from app.models import models
from app.core import security

def reset_and_seed_db():
    print("🔄 در حال پاک‌سازی جداول قدیمی...")
    Base.metadata.drop_all(bind=engine)

    print("🏗️ در حال ساخت جداول جدید...")
    Base.metadata.create_all(bind=engine)

    db = SessionLocal()
    try:
        common_password = security.get_password_hash("amir")

        # ۱. ساخت کاربر دانشجو
        student_user = models.User(
            email="amir@gmail.com",
            password_hash=common_password,
            role=models.UserRole.STUDENT
        )
        db.add(student_user)
        db.commit()
        db.refresh(student_user)

        student_profile = models.StudentProfile(
            user_id=student_user.id,
            full_name="علی محمدی",
            university="دانشگاه تهران",
            major="مهندسی کامپیوتر",
            entrance_year=1401,
            skills=["Flutter", "Python", "SQL", "React"],
            courses=[
                {"course_name": "برنامه‌نویسی پیشرفته", "grade": 19.5},
                {"course_name": "پایگاه داده", "grade": 18.0}
            ],
            completion_percentage=100
        )
        db.add(student_profile)

        # ۲. ساخت کاربر کارفرما و شرکت
        company_user = models.User(
            email="psp@gmail.com",
            password_hash=common_password,
            role=models.UserRole.COMPANY_REP
        )
        db.add(company_user)
        db.commit()
        db.refresh(company_user)

        company = models.Company(
            name="شرکت تکنولوژی داده‌پردازان",
            national_id="1010389400",
            address="تهران، خیابان آزادی، پلاک ۱۲"
        )
        db.add(company)
        db.commit()
        db.refresh(company)

        rep = models.CompanyRepresentative(
            user_id=company_user.id,
            company_id=company.id
        )
        db.add(rep)

        # ۳. ساخت ۲ پروژه نمونه اولیه برای تست
        project1 = models.Project(
            company_id=company.id,
            title="توسعه اپلیکیشن موبایل با فلاتر (Flutter)",
            description="پیاده‌سازی رابط کاربری داشبورد و اتصال به APIهای FastAPI. نیازمند تسلط بر فلاتر و مدیریت استیت.",
            required_skills=["Flutter", "Dart", "REST API"],
            deadline=datetime.utcnow() + timedelta(days=30),
            project_type="کارآموزی",
            requires_interview=True,
            weights={
                "university_weight": 0.25,
                "major_weight": 0.25,
                "skills_weight": 0.30,
                "courses_weight": 0.20
            }
        )

        project2 = models.Project(
            company_id=company.id,
            title="تحلیل داده و طراحی الگوریتم با پایتون",
            description="تحلیل داده‌های مشتریان و بهینه‌سازی کوئری‌های SQL به همراه ساخت داشبورد مدیریت نمرات.",
            required_skills=["Python", "SQL", "Pandas"],
            deadline=datetime.utcnow() + timedelta(days=45),
            project_type="پروژه",
            requires_interview=True,
            weights={
                "university_weight": 0.20,
                "major_weight": 0.20,
                "skills_weight": 0.40,
                "courses_weight": 0.20
            }
        )

        db.add(project1)
        db.add(project2)
        db.commit()

        print("\n🎉 دیتابیس ریست شد و ۲ پروژه نمونه اولیه ثبت گردید!")
        print("==================================================")
        print("🎓 اکانت دانشجو:   amir@gmail.com | رمز: amir")
        print("🏢 اکانت کارفرما:  psp@gmail.com  | رمز: amir")
        print("==================================================\n")

    except Exception as e:
        db.rollback()
        print(f"❌ خطا: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    reset_and_seed_db()