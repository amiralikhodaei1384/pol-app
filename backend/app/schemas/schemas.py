from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from enum import Enum
from ..models.models import UserRole

# ----------------------------------------------------
# 1. Schemas کاربر (User Schemas)
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
# 2. Schemas شرکت (Company Schemas)
# ----------------------------------------------------
class CompanyOut(BaseModel):
    id: UUID
    name: str
    about: Optional[str] = None
    website: Optional[str] = None
    address: Optional[str] = None
    class Config:
        from_attributes = True

class CompanyProfileUpdate(BaseModel):
    name: Optional[str] = None
    about: Optional[str] = None
    website: Optional[str] = None
    address: Optional[str] = None

# ----------------------------------------------------
# 3. Schemas پروژه (Project Schemas)
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
    title: str = Field(..., min_length=3, max_length=150)
    description: str
    required_skills: List[str]
    deadline: str  # <--- تغییر از datetime به str جهت پذیرش تاریخ شمسی
    project_type: ProjectType = Field(default=ProjectType.PROJECT)
    city: Optional[str] = "تهران"
    category: Optional[str] = "عمومی"
    related_major: Optional[str] = "سایر"
    target_universities: Optional[List[str]] = []
    target_majors: Optional[List[str]] = []
    requires_interview: bool = Field(default=True)
    weights: Optional[MatchingWeights] = Field(default_factory=MatchingWeights)

class ProjectOut(ProjectCreate):
    id: UUID
    company_id: UUID
    created_at: datetime
    is_active: bool = True
    company: Optional[CompanyOut] = None

    class Config:
        from_attributes = True

# ----------------------------------------------------
# 4. Schemas دانشجو (Student Schemas)
# ----------------------------------------------------
class CourseGrade(BaseModel):
    course_name: str
    grade: float = Field(..., ge=0, le=20)

class StudentProfileCreate(BaseModel):
    full_name: str
    phone: Optional[str] = None
    birth_date: Optional[str] = None
    residence: Optional[str] = None
    birth_place: Optional[str] = None
    university: Optional[str] = None
    major: Optional[str] = None
    entrance_year: Optional[int] = None
    skills: List[str] = []
    courses: List[CourseGrade] = []
    educations: Optional[List[dict]] = None
    work_experiences: Optional[List[dict]] = None
    github_link: Optional[str] = None
    figma_link: Optional[str] = None
    resume_file: Optional[str] = None

class StudentProfileOut(StudentProfileCreate):
    id: UUID
    user_id: UUID
    completion_percentage: int

    class Config:
        from_attributes = True

# ----------------------------------------------------
# 5. Schemas چت و مصاحبه (Chat & Interview Schemas)
# ----------------------------------------------------
class ScheduleInterviewSchema(BaseModel):
    interview_date: str
    interview_address: str
    interview_note: Optional[str] = ""

class SendMessageSchema(BaseModel):
    thread_id: UUID
    text: str