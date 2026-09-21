import os
import sys
from getpass import getpass

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.db.session import SessionLocal
from app.models import models
from app.core import security

# Creates an admin account, or promotes an existing account to admin.
# Usage: python create_admin.py admin@example.com
if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python create_admin.py <email>")
        sys.exit(1)

    email = sys.argv[1].strip()
    db = SessionLocal()
    try:
        user = db.query(models.User).filter(models.User.email == email).first()
        if user:
            user.role = models.UserRole.ADMIN
            user.is_active = True
            print(f"{email} is now an admin (password unchanged).")
        else:
            password = getpass("Password for the new admin: ")
            if len(password) < 4:
                print("Password is too short.")
                sys.exit(1)
            db.add(models.User(
                email=email,
                password_hash=security.get_password_hash(password),
                role=models.UserRole.ADMIN,
                is_verified=True,
            ))
            print(f"Admin {email} created.")
        db.commit()
    finally:
        db.close()
