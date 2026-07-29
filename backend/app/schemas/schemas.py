from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from enum import Enum
from ..models.models import UserRole

# ----------------------------------------------------
# 1. Schemas قبلی شما (User)
# ----------------------------------------------------
class UserBase(BaseModel):
    email: EmailStr
    phone: Optional[str] = None

class UserCreate(UserBase):
    password: str
    role: UserRole = UserRole.STUDENT
    full_name: Optional[str] = None
    company_name: Optional[str] = None
    national_id: Optional[str] = None
    company_address: Optional[str] = None

class UserLogin(BaseModel):
    username: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str
    role: str

class UserOut(UserBase):
    id: UUID
    role: UserRole
    is_verified: bool
    created_at: datetime

    class Config:
        from_attributes = True

# ----------------------------------------------------
# 2. Schemas جدید: تعریف پروژه (بخش ۵.۲ سند UX)
# ----------------------------------------------------
class ProjectType(str, Enum):
    INTERNSHIP = "کارآموزی"
    MILITARY = "امریه"
    PROJECT = "پروژه"

class MatchingWeights(BaseModel):
    university_weight: float = Field(default=0.25, ge=0.0, le=1.0)
    major_weight: float = Field(default=0.25, ge=0.0, le=1.0)
    skills_weight: float = Field(default=0.30, ge=0.0, le=1.0)
    courses_weight: float = Field(default=0.20, ge=0.0, le=1.0)

class ProjectCreate(BaseModel):
    title: str = Field(..., min_length=3, max_length=150, description="عنوان پروژه")
    description: str = Field(..., description="شرح وظایف و خروجی مورد انتظار")
    required_skills: List[str] = Field(..., description="مهارت‌های مورد نیاز")
    deadline: datetime = Field(..., description="مهلت پیشنهادی")
    project_type: ProjectType = Field(default=ProjectType.PROJECT, description="نوع همکاری")
    requires_interview: bool = Field(default=True, description="گزینه نیاز به مصاحبه/ملاقات حضوری")
    weights: Optional[MatchingWeights] = Field(default_factory=MatchingWeights, description="وزن‌دهی تطبیق (اختیاری)")

class CompanyOut(BaseModel):
    id: UUID
    name: str
    class Config:
        from_attributes = True

class ProjectOut(ProjectCreate):
    id: UUID
    company_id: UUID
    created_at: datetime
    is_active: bool = True
    company: Optional[CompanyOut] = None  # اضافه شدن اطلاعات شرکت

    class Config:
        from_attributes = True