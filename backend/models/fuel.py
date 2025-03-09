from bson import ObjectId
from datetime import datetime
from typing import Dict, Optional

class FuelStation:
    def __init__(
        self,
        id: str = None,
        user_id: ObjectId = None,
        name: str = "",
        brand: str = "",
        latitude: float = 0.0,
        longitude: float = 0.0,
        address: str = "",
        city: str = "",
        province: str = "",
        postal_code: str = "",
        prices: Dict[str, float] = None,
        schedule: str = "",
        is_favorite: bool = False,
        last_updated: datetime = None,
        distance: Optional[float] = None,
    ):
        self._id = ObjectId() if id is None else ObjectId(id)
        self.user_id = user_id
        self.name = name
        self.brand = brand
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.city = city
        self.province = province
        self.postal_code = postal_code
        self.prices = prices or {}
        self.schedule = schedule
        self.is_favorite = is_favorite
        self.last_updated = last_updated or datetime.utcnow()
        self.distance = distance

    def to_dict(self):
        return {
            "_id": self._id,
            "user_id": self.user_id,
            "name": self.name,
            "brand": self.brand,
            "latitude": self.latitude,
            "longitude": self.longitude,
            "address": self.address,
            "city": self.city,
            "province": self.province,
            "postal_code": self.postal_code,
            "prices": self.prices,
            "schedule": self.schedule,
            "is_favorite": self.is_favorite,
            "last_updated": self.last_updated,
            "distance": self.distance
        }

    @staticmethod
    def from_dict(data: dict):
        return FuelStation(
            id=str(data["_id"]),
            user_id=data.get("user_id"),
            name=data.get("name", ""),
            brand=data.get("brand", ""),
            latitude=data.get("latitude", 0.0),
            longitude=data.get("longitude", 0.0),
            address=data.get("address", ""),
            city=data.get("city", ""),
            province=data.get("province", ""),
            postal_code=data.get("postal_code", ""),
            prices=data.get("prices", {}),
            schedule=data.get("schedule", ""),
            is_favorite=data.get("is_favorite", False),
            last_updated=data.get("last_updated", datetime.utcnow()),
            distance=data.get("distance")
        ) 