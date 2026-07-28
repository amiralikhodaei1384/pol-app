import os
import sys

# افزودن مسیر اصلی برنامه برای ایمپورت‌ها
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.db.session import engine, SessionLocal
from app.db.base import Base
from app.models import models
from app.core import security

def reset_and_seed_db():
    print("🔄 در حال پاک‌سازی جداول قدیمی...")
    Base.metadata.drop_all(bind=engine)
    print("✅ تمامی جداول قدیمی پاک شدند.")

    print("🏗️ در حال ساخت جداول جدید...")
    Base.metadata.create_all(bind=engine)
    print("✅ جداول جدید دیتابیس ساخته شدند.")

    db = SessionLocal()
    try:
        # هش کردن رمز عبور مشترک برای تست
        common_password = security.get_password_hash("password123")

        # -----------------------------------------------
        # ۱. ساخت کاربر دانشجو
        # -----------------------------------------------
        print("👤 در حال ساخت کاربر دانشجو...")
        student_user = models.User(
            email="student@test.com",
            password_hash=common_password,
            role=models.UserRole.STUDENT
        )
        db.add(student_user)
        db.commit()
        db.refresh(student_user)

        student_profile = models.StudentProfile(
            user_id=student_user.id,
            full_name="علی محمدی"
        )
        db.add(student_profile)

        # -----------------------------------------------
        # ۲. ساخت کاربر کارفرما و شرکت
        # -----------------------------------------------
        print("🏢 در حال ساخت کاربر کارفرما و شرکت...")
        company_user = models.User(
            email="company@test.com",
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

        db.commit()
        print("\n🎉 دیتابیس با موفقیت ریست شد و کاربران اولیه ساخته شدند!")
        print("==================================================")
        print("🎓 اکانت دانشجو:   student@test.com | رمز: password123")
        print("🏢 اکانت کارفرما:  company@test.com | رمز: password123")
        print("==================================================\n")

    except Exception as e:
        db.rollback()
        print(f"❌ خطا در ساخت داده‌های اولیه: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    reset_and_seed_db()