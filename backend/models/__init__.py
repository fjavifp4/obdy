from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime
from .user import User
from .vehicle import Vehicle, MaintenanceRecord
from .chat import Chat, Message
from .trip import Trip, GpsPoint

class UserBase(BaseModel):
    email: EmailStr
    username: str 