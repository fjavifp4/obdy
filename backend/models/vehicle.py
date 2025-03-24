from datetime import datetime
from bson import ObjectId
from typing import List, Optional

class MaintenanceRecord:
    def __init__(
        self,
        type: str,
        last_change_km: int,
        recommended_interval_km: int,
        next_change_km: int,
        last_change_date: datetime,
        notes: Optional[str] = None,
        km_since_last_change: float = 0.0
    ):
        self._id = ObjectId()
        self.type = type
        self.last_change_km = last_change_km
        self.recommended_interval_km = recommended_interval_km
        self.next_change_km = next_change_km
        self.last_change_date = last_change_date
        self.notes = notes
        self.km_since_last_change = km_since_last_change

class Vehicle:
    def __init__(
        self,
        user_id: ObjectId,
        brand: str,
        model: str,
        year: int,
        licensePlate: str,
        current_kilometers: float = 0.0,
    ):
        self._id = ObjectId()
        self.user_id = user_id
        self.brand = brand
        self.model = model
        self.year = year
        self.licensePlate = licensePlate
        self.current_kilometers = current_kilometers
        self.maintenance_records = []
        self.pdf_manual_grid_fs_id = None
        self.logo = None  # Campo para almacenar la imagen del logo
        self.last_itv_date = None  # Fecha de la última ITV
        self.next_itv_date = None  # Fecha de la próxima ITV
        self.created_at = datetime.utcnow()
        self.updated_at = datetime.utcnow() 