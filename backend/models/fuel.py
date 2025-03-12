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
        # Guardamos tanto _id (para bson/mongo) como id (para API)
        self._id = ObjectId() if id is None else ObjectId(id)
        self.id = str(self._id)  # Guardar también como string para la API
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
            "id": self.id,  # Incluir id como string
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
        # Asegurar que existe un _id válido, si no, crear uno a partir del id normal
        if "_id" not in data:
            if "id" in data:
                data["_id"] = data["id"]
            else:
                data["_id"] = str(ObjectId())
        
        # Si _id es ya un string, convertirlo a ObjectId
        if isinstance(data["_id"], str):
            try:
                _id = ObjectId(data["_id"])
            except:
                _id = ObjectId()
        else:
            _id = data["_id"]
        
        # Asegurar que las coordenadas son float válidos
        try:
            latitude = float(data.get("latitude", 0.0))
        except (ValueError, TypeError):
            latitude = 0.0
            
        try:
            longitude = float(data.get("longitude", 0.0))
        except (ValueError, TypeError):
            longitude = 0.0
            
        # Preparar el diccionario de precios
        prices = data.get("prices", {})
        if not isinstance(prices, dict):
            prices = {}
            
        # Preparar distance si existe
        distance = None
        if "distance" in data:
            try:
                distance = float(data["distance"])
            except (ValueError, TypeError):
                distance = None
                
        # Asegurar que last_updated es datetime
        last_updated = data.get("last_updated")
        if not isinstance(last_updated, datetime):
            last_updated = datetime.utcnow()
        
        return FuelStation(
            id=str(_id),
            user_id=data.get("user_id"),
            name=str(data.get("name", "")),
            brand=str(data.get("brand", "")),
            latitude=latitude,
            longitude=longitude,
            address=str(data.get("address", "")),
            city=str(data.get("city", "")),
            province=str(data.get("province", "")),
            postal_code=str(data.get("postal_code", "")),
            prices=prices,
            schedule=str(data.get("schedule", "")),
            is_favorite=bool(data.get("is_favorite", False)),
            last_updated=last_updated,
            distance=distance
        ) 