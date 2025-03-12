from pydantic import BaseModel, Field, validator
from typing import Dict, Optional, List, Any
from datetime import datetime
from bson import ObjectId

class FuelPrices(BaseModel):
    prices: Dict[str, float] = Field(..., description="Diccionario de precios de combustible")

class FuelStationBase(BaseModel):
    id: str
    name: str = ""
    brand: str = ""
    latitude: float = 0.0
    longitude: float = 0.0
    address: str = ""
    city: str = ""
    province: str = ""
    postal_code: str = ""
    prices: Dict[str, float] = {}
    schedule: str = ""
    
    @validator('prices', pre=True, always=True)
    def validate_prices(cls, v):
        if v is None:
            return {}
        return v

class FuelStationCreate(FuelStationBase):
    pass

class FuelStationResponse(FuelStationBase):
    id: str = Field(..., description="ID de la estación")
    is_favorite: bool = Field(False, description="Si es favorita para el usuario")
    last_updated: datetime = Field(..., description="Fecha de última actualización")
    distance: Optional[float] = Field(None, description="Distancia en km desde la ubicación actual")

    @validator('last_updated', pre=True)
    def validate_last_updated(cls, v):
        if v is None:
            return datetime.utcnow()
        return v
        
    @validator('prices', pre=True)
    def validate_prices(cls, v):
        if v is None:
            return {}
        # Si no es un diccionario, intentar convertirlo
        if not isinstance(v, dict):
            try:
                return dict(v)
            except:
                return {}
        return v
        
    @validator('id', pre=True)
    def validate_id(cls, v):
        if v is None:
            return str(ObjectId())
        return str(v)
        
    @validator('distance', pre=True)
    def validate_distance(cls, v):
        if v is None:
            return None
        try:
            return float(v)
        except:
            return None

    class Config:
        orm_mode = True
        # Esta opción permite adaptar nombres de campos
        alias_generator = lambda string: string.replace('_', '')
        populate_by_name = True  # Para compatibilidad con nombres originales también
        # Permitir valores adicionales que no están en el modelo
        extra = "ignore"
        # Validación arbitraria
        arbitrary_types_allowed = True

class FuelStationList(BaseModel):
    stations: List[FuelStationResponse] = []

class FavoriteStationAdd(BaseModel):
    station_id: str = Field(..., description="ID de la estación a marcar como favorita")

class NearbyStationsParams(BaseModel):
    lat: float = Field(..., description="Latitud de la ubicación")
    lng: float = Field(..., description="Longitud de la ubicación")
    radius: float = Field(5.0, description="Radio de búsqueda en km")
    fuel_type: Optional[str] = Field(None, description="Tipo de combustible para filtrar") 