from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from ..models.models import UserRole

# Shared User Properties
class UserBase(BaseModel):
    email: EmailStr
    phone: Optional[str] = None

# Registration Schema (Input)
class UserCreate(UserBase):
    password: str
    role: UserRole = UserRole.STUDENT
    # Fields for Students
    full_name: Optional[str] = None
    # Fields for Companies
    company_name: Optional[str] = None
    national_id: Optional[str] = None
    company_address: Optional[str] = None # اضافه کردن این خط

# Login Schema (Input)
class UserLogin(BaseModel):
    username: str # Can be email or phone
    password: str

# Token Schema (Output after Login)
class Token(BaseModel):
    access_token: str
    token_type: str
    role: str

# User Display Schema (Output)
class UserOut(UserBase):
    id: UUID
    role: UserRole
    is_verified: bool
    created_at: datetime

    class Config:
        from_attributes = True
