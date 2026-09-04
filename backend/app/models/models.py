import enum
import uuid
from datetime import datetime
from sqlalchemy import Column, String, Text, Boolean, DateTime, ForeignKey, JSON, Integer, Enum, Float
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from ..db.base import Base

# Enums
class UserRole(str, enum.Enum):
    STUDENT = "student"
    COMPANY_REP = "company_rep"
    ADMIN = "admin"

class ProjectStatus(str, enum.Enum):
    OPEN = "open"
    IN_PROGRESS = "in_progress"
    CLOSED = "closed"

class ApplicationStatus(str, enum.Enum):
    APPLIED = "applied"
    SHORTLISTED = "shortlisted" # دعوت به مصاحبه
    ACCEPTED = "accepted"
    REJECTED = "rejected"

class ContractStatus(str, enum.Enum):
    PENDING_PHYSICAL = "pending_physical"
    SIGNED = "signed"
    CANCELLED = "cancelled"

# Models
class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String, unique=True, index=True, nullable=False)
    phone = Column(String, unique=True, index=True, nullable=True)
    password_hash = Column(String, nullable=False)
    role = Column(Enum(UserRole), default=UserRole.STUDENT)
    is_verified = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    student_profile = relationship("StudentProfile", back_populates="user", uselist=False)
    company_rep_profile = relationship("CompanyRepresentative", back_populates="user", uselist=False)

class Company(Base):
    __tablename__ = "companies"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, nullable=False)
    national_id = Column(String, unique=True, index=True, nullable=False)
    website = Column(String, nullable=True)
    about = Column(Text, nullable=True)        # <--- فیلد جدید: درباره شرکت
    address = Column(String, nullable=True)
    is_active = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    projects = relationship("Project", back_populates="company")
    representatives = relationship("CompanyRepresentative", back_populates="company")

class CompanyRepresentative(Base):
    __tablename__ = "company_representatives"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), unique=True)
    company_id = Column(UUID(as_uuid=True), ForeignKey("companies.id"))

    user = relationship("User", back_populates="company_rep_profile")
    company = relationship("Company", back_populates="representatives")

class StudentProfile(Base):
    __tablename__ = "student_profiles"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), unique=True)
    full_name = Column(String, nullable=False)
    phone = Column(String, nullable=True)
    birth_date = Column(String, nullable=True)
    residence = Column(String, nullable=True)
    birth_place = Column(String, nullable=True)
    bio = Column(Text, nullable=True)
    university = Column(String, nullable=True)
    major = Column(String, nullable=True)
    entrance_year = Column(Integer, nullable=True)
    skills = Column(JSON, nullable=True)
    courses = Column(JSON, nullable=True)
    educations = Column(JSON, nullable=True)
    work_experiences = Column(JSON, nullable=True)
    resume_file = Column(String, nullable=True)
    portfolio_links = Column(JSON, nullable=True)
    completion_percentage = Column(Integer, default=0)

    user = relationship("User", back_populates="student_profile")

class Project(Base):
    __tablename__ = "projects"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    company_id = Column(UUID(as_uuid=True), ForeignKey("companies.id", ondelete="CASCADE"), nullable=False)

    title = Column(String(150), nullable=False)
    description = Column(Text, nullable=False)
    required_skills = Column(JSON, nullable=False)
    deadline = Column(String, nullable=False)
    project_type = Column(String(50), nullable=False)
    city = Column(String(100), nullable=True)             # بدون دیفالت هاردکد
    category = Column(String(100), nullable=True)         # بدون دیفالت هاردکد
    target_universities = Column(JSON, nullable=True)     # لیست دانشگاه‌های اولویت‌دار انتخاب شده توسط کارفرما
    target_majors = Column(JSON, nullable=True)           # لیست رشته‌های مورد نظر کارفرما
    requires_interview = Column(Boolean, default=True)
    weights = Column(JSON, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    company = relationship("Company", back_populates="projects")
    applications = relationship("Application", back_populates="project")

class Application(Base):
    __tablename__ = "applications"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    student_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id"))
    status = Column(Enum(ApplicationStatus), default=ApplicationStatus.APPLIED)
    contract_status = Column(Enum(ContractStatus), default=ContractStatus.PENDING_PHYSICAL)

    # اطلاعات دعوت به مصاحبه حضوری
    interview_date = Column(String, nullable=True)
    interview_address = Column(String, nullable=True)
    interview_note = Column(Text, nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    project = relationship("Project", back_populates="applications")
    student = relationship("User")

# مدل‌های چت اختصاصی (شروع چت فقط توسط کارفرما)
class ChatThread(Base):
    __tablename__ = "chat_threads"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    application_id = Column(UUID(as_uuid=True), ForeignKey("applications.id"), unique=True)
    employer_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    student_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    thread_id = Column(UUID(as_uuid=True), ForeignKey("chat_threads.id"))
    sender_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    text = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())