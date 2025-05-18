from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

class MaintenanceRecordBase(BaseModel):
    type: str = Field(..., min_length=1, description="Tipo de mantenimiento")
    last_change_km: int = Field(0, ge=0, description="Km en el último cambio")
    recommended_interval_km: int = Field(..., gt=0, description="Intervalo recomendado en km")
    last_change_date: Optional[datetime] = Field(None, description="Fecha del último cambio (opcional)")
    notes: Optional[str] = Field(None, description="Notas adicionales")
    km_since_last_change: float = Field(0.0, ge=0, description="Kilómetros recorridos desde el último cambio")
    # Los siguientes campos se calculan o no se reciben en la creación
    # next_change_km: int = Field(..., ge=0)

class MaintenanceRecordCreate(MaintenanceRecordBase):
    # Hereda los campos opcionales de Base
    # Sobreescribir si se necesita una validación diferente para la creación
    pass

class MaintenanceRecordResponse(BaseModel):
    id: str
    type: str
    last_change_km: int
    recommended_interval_km: int
    next_change_km: int # Este sí se devuelve
    last_change_date: Optional[datetime] # Puede ser None si no se proporcionó
    notes: Optional[str] = None
    km_since_last_change: float = 0.0

    class Config:
        from_attributes = True
        populate_by_name = True
        # Permitir None para campos Optional en V1 (si aplica)
        # orm_mode = True # Necesario en Pydantic V1 para from_orm
        # En V2, from_attributes = True es suficiente normalmente

class VehicleBase(BaseModel):
    brand: str = Field(..., min_length=1, max_length=50)
    model: str = Field(..., min_length=1, max_length=50)
    year: int = Field(..., ge=1900, le=datetime.now().year)
    licensePlate: str = Field(..., min_length=1, max_length=10)
    current_kilometers: float = Field(..., ge=0, description="Kilometraje actual del vehículo")

class VehicleCreate(VehicleBase):
    pass

class VehicleResponse(BaseModel):
    id: str
    userId: str
    brand: str
    model: str
    year: int
    licensePlate: str
    current_kilometers: float
    maintenance_records: List[MaintenanceRecordResponse] = []
    pdf_manual_grid_fs_id: Optional[str] = None
    logo: Optional[str] = None
    last_itv_date: Optional[datetime] = None
    next_itv_date: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
        populate_by_name = True

class VehicleUpdate(BaseModel):
    brand: Optional[str] = Field(None, min_length=1, max_length=50)
    model: Optional[str] = Field(None, min_length=1, max_length=50)
    year: Optional[int] = Field(None, ge=1900, le=datetime.now().year)
    licensePlate: Optional[str] = Field(None, min_length=1, max_length=10)
    current_kilometers: Optional[float] = Field(None, ge=0)
    logo: Optional[str] = None
    last_itv_date: Optional[datetime] = None
    next_itv_date: Optional[datetime] = None

class ITVUpdate(BaseModel):
    itv_date: datetime = Field(..., description="Fecha de la ITV (última o próxima)")

class ITVResponse(BaseModel):
    id: str
    last_itv_date: Optional[datetime] = None
    next_itv_date: Optional[datetime] = None 