from datetime import datetime
from bson import ObjectId
from typing import List, Optional
from pydantic import BaseModel, Field

class GpsPoint(BaseModel):
    id: Optional[str] = None
    latitude: float
    longitude: float
    timestamp: Optional[datetime] = None

class GpsPointsBatch(BaseModel):
    points: List[GpsPoint]

# Modelo de viaje para API pydantic
class TripBase(BaseModel):
    vehicle_id: str
    
class TripCreate(TripBase):
    distance_in_km: float = 0.0
    fuel_consumption_liters: float = 0.0
    average_speed_kmh: float = 0.0
    duration_seconds: int = 0

class TripUpdate(BaseModel):
    distance_in_km: Optional[float] = None
    fuel_consumption_liters: Optional[float] = None
    average_speed_kmh: Optional[float] = None
    duration_seconds: Optional[int] = None
    end_time: Optional[datetime] = None
    is_active: Optional[bool] = None

class Trip(TripBase):
    id: str = Field(..., alias="_id")
    start_time: datetime
    end_time: Optional[datetime] = None
    distance_in_km: float = 0.0
    is_active: bool = True
    gps_points: List[GpsPoint] = []
    fuel_consumption_liters: float = 0.0
    average_speed_kmh: float = 0.0
    duration_seconds: int = 0
    created_at: Optional[datetime] = None
    last_updated: Optional[datetime] = None
    
    class Config:
        orm_mode = True
        allow_population_by_field_name = True

# Clase original para compatibilidad con el código existente
class GpsPoint:
    def __init__(
        self,
        latitude: float,
        longitude: float,
        timestamp: datetime
    ):
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp

class Trip:
    def __init__(
        self, 
        id: str, 
        vehicle_id: str, 
        start_time: datetime,
        end_time: Optional[datetime] = None,
        distance_in_km: float = 0.0,
        is_active: bool = True,
        gps_points: Optional[List[GpsPoint]] = None,
        fuel_consumption_liters: float = 0.0,
        average_speed_kmh: float = 0.0,
        duration_seconds: int = 0
    ):
        self.id = id
        self.vehicle_id = vehicle_id
        self.start_time = start_time
        self.end_time = end_time
        self.distance_in_km = distance_in_km
        self.is_active = is_active
        self.gps_points = gps_points if gps_points is not None else []
        self.fuel_consumption_liters = fuel_consumption_liters
        self.average_speed_kmh = average_speed_kmh
        self.duration_seconds = duration_seconds
    
    def to_dict(self):
        return {
            "_id": self.id,
            "vehicle_id": self.vehicle_id,
            "start_time": self.start_time.isoformat(),
            "end_time": self.end_time.isoformat() if self.end_time else None,
            "distance_in_km": self.distance_in_km,
            "is_active": self.is_active,
            "gps_points": [
                {
                    "latitude": point.latitude,
                    "longitude": point.longitude,
                    "timestamp": point.timestamp.isoformat()
                } for point in self.gps_points
            ],
            "fuel_consumption_liters": self.fuel_consumption_liters,
            "average_speed_kmh": self.average_speed_kmh,
            "duration_seconds": self.duration_seconds
        }
    
    @classmethod
    def from_dict(cls, data):
        gps_points = []
        if "gps_points" in data and data["gps_points"]:
            for point_data in data["gps_points"]:
                timestamp = datetime.fromisoformat(point_data["timestamp"]) \
                    if isinstance(point_data["timestamp"], str) else point_data["timestamp"]
                gps_points.append(GpsPoint(
                    latitude=point_data["latitude"],
                    longitude=point_data["longitude"],
                    timestamp=timestamp
                ))
        
        start_time = datetime.fromisoformat(data["start_time"]) \
            if isinstance(data["start_time"], str) else data["start_time"]
        
        end_time = None
        if data.get("end_time"):
            end_time = datetime.fromisoformat(data["end_time"]) \
                if isinstance(data["end_time"], str) else data["end_time"]
        
        return cls(
            id=data["_id"],
            vehicle_id=data["vehicle_id"],
            start_time=start_time,
            end_time=end_time,
            distance_in_km=data.get("distance_in_km", 0.0),
            is_active=data.get("is_active", True),
            gps_points=gps_points,
            fuel_consumption_liters=data.get("fuel_consumption_liters", 0.0),
            average_speed_kmh=data.get("average_speed_kmh", 0.0),
            duration_seconds=data.get("duration_seconds", 0)
        ) 