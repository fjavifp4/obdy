from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

class GpsPointBase(BaseModel):
    latitude: float
    longitude: float
    timestamp: datetime

class GpsPointResponse(GpsPointBase):
    pass

class TripBase(BaseModel):
    vehicle_id: str = Field(..., description="ID del vehículo asociado al viaje")
    distance_in_km: float = Field(0.0, ge=0, description="Distancia recorrida en kilómetros")
    fuel_consumption_liters: float = Field(0.0, ge=0, description="Consumo de combustible en litros")
    average_speed_kmh: float = Field(0.0, ge=0, description="Velocidad media en km/h")
    duration_seconds: int = Field(0, ge=0, description="Duración del viaje en segundos")

class TripCreate(TripBase):
    pass

class TripUpdate(BaseModel):
    distance_in_km: Optional[float] = Field(None, ge=0)
    fuel_consumption_liters: Optional[float] = Field(None, ge=0)
    average_speed_kmh: Optional[float] = Field(None, ge=0)
    duration_seconds: Optional[int] = Field(None, ge=0)
    is_active: Optional[bool] = None
    end_time: Optional[datetime] = None
    gps_points: Optional[List[GpsPointBase]] = None

class TripResponse(TripBase):
    id: str
    user_id: str
    start_time: datetime
    end_time: Optional[datetime] = None
    is_active: bool
    gps_points: List[GpsPointResponse] = []
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
        populate_by_name = True 