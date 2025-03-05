from datetime import datetime
from bson import ObjectId
from typing import List, Optional

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
        user_id: ObjectId,
        vehicle_id: ObjectId,
        start_time: datetime,
        distance_in_km: float = 0.0,
        fuel_consumption_liters: float = 0.0,
        average_speed_kmh: float = 0.0,
        duration_seconds: int = 0,
        end_time: Optional[datetime] = None,
        is_active: bool = True
    ):
        self._id = ObjectId()
        self.user_id = user_id
        self.vehicle_id = vehicle_id
        self.start_time = start_time
        self.end_time = end_time
        self.distance_in_km = distance_in_km
        self.fuel_consumption_liters = fuel_consumption_liters
        self.average_speed_kmh = average_speed_kmh
        self.duration_seconds = duration_seconds
        self.is_active = is_active
        self.gps_points = []
        self.created_at = datetime.utcnow()
        self.updated_at = datetime.utcnow() 