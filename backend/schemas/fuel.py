from pydantic import BaseModel, Field
from typing import Dict, Optional, List
from datetime import datetime

class FuelPrices(BaseModel):
    prices: Dict[str, float] = Field(..., description="Diccionario de precios de combustible")

class FuelStationBase(BaseModel):
    id: str
    name: str
    brand: str
    latitude: float
    longitude: float
    address: str
    city: str
    province: str
    postal_code: str
    prices: Dict[str, float]
    schedule: str

class FuelStationCreate(FuelStationBase):
    pass

class FuelStationResponse(FuelStationBase):
    id: str = Field(..., description="ID de la estación")
    is_favorite: bool = Field(False, description="Si es favorita para el usuario")
    last_updated: datetime = Field(..., description="Fecha de última actualización")
    distance: Optional[float] = Field(None, description="Distancia en km desde la ubicación actual")

    class Config:
        orm_mode = True

class FuelStationList(BaseModel):
    stations: List[FuelStationResponse]

class FavoriteStationAdd(BaseModel):
    station_id: str = Field(..., description="ID de la estación a marcar como favorita")

class NearbyStationsParams(BaseModel):
    lat: float = Field(..., description="Latitud de la ubicación")
    lng: float = Field(..., description="Longitud de la ubicación")
    radius: float = Field(5.0, description="Radio de búsqueda en km")
    fuel_type: Optional[str] = Field(None, description="Tipo de combustible para filtrar") 