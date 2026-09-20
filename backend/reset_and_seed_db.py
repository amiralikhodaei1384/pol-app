import os
import sys
from datetime import datetime, timedelta

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.db.session import engine, SessionLocal
from app.db.base import Base
from app.models import models
from app.core import security
from app.api.auth import calculate_profile_completion
from seed_options import seed_options

def reset_and_seed_db():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)

    db = SessionLocal()
    try:
        common_password = security.get_password_hash("amir")

        seed_options(db)

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
            phone="09121234567",
            birth_date="1381/05/12",
            residence="تهران",
            birth_place="اصفهان",
            university="دانشگاه تهران",
            major="مهندسی کامپیوتر",
            entrance_year=1401,
            skills=["Flutter", "Python", "SQL", "React"],
            courses=[
                {"course_name": "برنامه‌نویسی پیشرفته", "grade": 19.5},
                {"course_name": "پایگاه داده", "grade": 18.0}
            ],
            educations=[
                {
                    "degree": "کارشناسی",
                    "university": "دانشگاه تهران",
                    "major": "مهندسی کامپیوتر",
                    "start_year": "1401",
                    "end_year": "در حال تحصیل",
                    "gpa": "17.8"
                }
            ],
            work_experiences=[
                {
                    "company": "استارتاپ آرمان",
                    "position": "کارآموز توسعه موبایل",
                    "from_year": "1403",
                    "to_year": "1404",
                    "description": "توسعه اپلیکیشن فروشگاهی با Flutter"
                }
            ],
            portfolio_links={"github": "https://github.com/alimohammadi", "figma": ""},
        )
        # resume_file is left empty on purpose: the demo account lands just short of
        # 100% so the dashboard still has something to nudge the student about.
        student_profile.completion_percentage = calculate_profile_completion(student_profile)
        db.add(student_profile)

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
            address="تهران، خیابان آزادی، پلاک ۱۲",
            about="شرکت پیشرو در زمینه تولید نرم‌افزارهای مالی و اتوماسیون اداری."
        )
        db.add(company)
        db.commit()
        db.refresh(company)

        rep = models.CompanyRepresentative(
            user_id=company_user.id,
            company_id=company.id
        )
        db.add(rep)

        project1 = models.Project(
            company_id=company.id,
            title="توسعه اپلیکیشن موبایل با فلاتر (Flutter)",
            description="پیاده‌سازی رابط کاربری داشبورد و اتصال به APIهای FastAPI جابینجایی.",
            required_skills=["Flutter", "Dart", "REST API"],
            deadline="1405/05/20",
            project_type="کارآموزی",
            city="تهران",
            category="توسعه نرم‌افزار",
            target_universities=["دانشگاه تهران", "دانشگاه صنعتی شریف"],
            target_majors=["مهندسی کامپیوتر"],
            # An internship, so undergraduates are ranked ahead of postgraduates.
            target_degrees=["کارشناسی", "کارشناسی ارشد"],
            weights={
                "university_weight": 0.25,
                "major_weight": 0.25,
                "skills_weight": 0.25,
                "degree_weight": 0.10,
                "profile_weight": 0.15
            }
        )

        db.add(project1)
        db.commit()

    except Exception as e:
        db.rollback()
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    reset_and_seed_db()