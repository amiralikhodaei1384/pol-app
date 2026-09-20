from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from ..models.models import UserRole

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

class MatchingWeights(BaseModel):
    university_weight: float = Field(default=0.25, ge=0.0, le=1.0)
    major_weight: float = Field(default=0.25, ge=0.0, le=1.0)
    skills_weight: float = Field(default=0.25, ge=0.0, le=1.0)
    degree_weight: float = Field(default=0.10, ge=0.0, le=1.0)
    # How much the student's overall profile-completion percentage counts.
    # Project-independent: a fuller profile helps on every project.
    profile_weight: float = Field(default=0.15, ge=0.0, le=1.0)

class ProjectCreate(BaseModel):
    title: str = Field(..., min_length=3, max_length=150)
    description: str
    required_skills: List[str]
    deadline: str
    # Checked against options_project_types when a project is created.
    project_type: str
    city: Optional[str] = None
    category: Optional[str] = None
    target_universities: Optional[List[str]] = []
    target_majors: Optional[List[str]] = []
    target_degrees: Optional[List[str]] = []
    weights: Optional[MatchingWeights] = Field(default_factory=MatchingWeights)

class ProjectOut(ProjectCreate):
    id: UUID
    company_id: UUID
    created_at: datetime
    is_active: bool = True
    company: Optional[CompanyOut] = None

    class Config:
        from_attributes = True

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

class ScheduleInterviewSchema(BaseModel):
    interview_date: str
    interview_address: str
    interview_note: Optional[str] = ""

class SendMessageSchema(BaseModel):
    thread_id: UUID
    text: Optional[str] = ""
    file_url: Optional[str] = None
    file_type: Optional[str] = None
    file_name: Optional[str] = None

class NotificationOut(BaseModel):
    id: UUID
    title: str
    message: str
    type: str
    is_read: bool
    created_at: datetime
    class Config:
        from_attributes = True

class EditMessageSchema(BaseModel):
    message_id: UUID
    text: str

class ApplyProjectSchema(BaseModel):
    message: Optional[str] = None