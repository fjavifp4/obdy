from pydantic import BaseModel, EmailStr
from typing import Optional
from .user import UserCreate, UserResponse, UserLogin, UserUpdate, VehicleResponse
from .vehicle import (
    VehicleCreate, 
    VehicleResponse, 
    VehicleUpdate,
    MaintenanceRecordCreate,
    MaintenanceRecordResponse
)
from .chat import (
    ChatBase,
    ChatResponse,
    MessageBase,
    MessageResponse
)
from .trip import (
    TripBase,
    TripCreate,
    TripUpdate,
    TripResponse,
    GpsPointBase,
    GpsPointResponse
) 