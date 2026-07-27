from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import os

# In a real app, this comes from a .env file
DATABASE_URL = "postgresql://postgres:root@localhost/pol_db"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
