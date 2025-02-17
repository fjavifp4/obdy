from pydantic import BaseModel, EmailStr, Field
from typing import List, Optional
from datetime import datetime

class VehicleBase(BaseModel):
    brand: str = Field(..., min_length=1, max_length=50, description="Marca del vehículo")
    model: str = Field(..., min_length=1, max_length=50, description="Modelo del vehículo")
    year: int = Field(..., ge=1900, le=2024, description="Año del vehículo")
    plate: str = Field(..., min_length=1, max_length=10, description="Matrícula del vehículo")
    vin: Optional[str] = Field(None, min_length=17, max_length=17, description="Número VIN del vehículo")

class VehicleCreate(VehicleBase):
    pass

class VehicleResponse(VehicleBase):
    id: str

class UserBase(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    email: EmailStr

class UserCreate(UserBase):
    password: str = Field(..., min_length=6)

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserResponse(UserBase):
    id: str
    created_at: datetime = Field(alias="createdAt")
    updated_at: datetime = Field(alias="updatedAt")
    vehicles: List[VehicleResponse] = Field(default_factory=list)

    class Config:
        populate_by_name = True
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }
        allow_population_by_field_name = True

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"

class UserUpdate(BaseModel):
    username: Optional[str] = Field(None, min_length=3, max_length=50)
    email: Optional[EmailStr] = None 