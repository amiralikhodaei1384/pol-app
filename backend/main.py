from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware # ۱. این خط اضافه شد
from app.api import auth
from app.db.base import Base
from app.db.session import engine

# ساخت جداول در دیتابیس
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Pol Platform API")

# ۲. این بخش برای اجازه دادن به مرورگر کروم (CORS) اضافه شد
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # به تمام مرورگرها اجازه دسترسی می‌دهد
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# اضافه کردن مسیرهای احراز هویت
app.include_router(auth.router, prefix="/auth", tags=["Authentication"])

@app.get("/")
def read_root():
    return {"message": "Welcome to Pol Platform API"}