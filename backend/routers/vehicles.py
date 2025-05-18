from fastapi import APIRouter, HTTPException, Depends, status, UploadFile, File, Response
from bson import ObjectId
from typing import List
from datetime import datetime, timedelta
from gridfs import GridFS
from motor.motor_asyncio import AsyncIOMotorGridFSBucket
from fastapi.responses import Response
from pydantic import ValidationError
import logging

import pymupdf as fitz
import os
import requests
import json
import re
from config.llm_config import SYSTEM_PROMPT
from database import db
from schemas.vehicle import (
    VehicleCreate, 
    VehicleResponse, 
    VehicleUpdate,
    MaintenanceRecordCreate,
    MaintenanceRecordResponse,
    ITVUpdate,
    ITVResponse
)
from routers.auth import get_current_user_data
from models.vehicle import Vehicle, MaintenanceRecord
from utils.car_logo_scraper import get_car_logo
from deep_translator import GoogleTranslator
import time

logger = logging.getLogger(__name__)

router = APIRouter()

@router.post("", response_model=VehicleResponse, status_code=status.HTTP_201_CREATED)
async def create_vehicle(
    vehicle_data: VehicleCreate,
    current_user: dict = Depends(get_current_user_data)
):
    """Crear un nuevo vehículo"""
    try:
        user_object_id = ObjectId(current_user["id"])
    except Exception:
         raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="ID de usuario inválido")

    existing_vehicle = await db.db.vehicles.find_one({
        "licensePlate": vehicle_data.licensePlate,
        "user_id": user_object_id
    })
    
    if existing_vehicle:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ya existe un vehículo con esa matrícula para este usuario"
        )
    
    try:
        logo = None
        try:
            logo = get_car_logo(vehicle_data.brand)
        except Exception as e:
            logger.warning(f"Error al obtener el logo para {vehicle_data.brand}: {str(e)}")
        
        # Crear vehículo SIN el logo en el constructor
        new_vehicle = Vehicle(
            user_id=user_object_id,
            brand=vehicle_data.brand,
            model=vehicle_data.model,
            year=vehicle_data.year,
            licensePlate=vehicle_data.licensePlate,
            current_kilometers=vehicle_data.current_kilometers
        )
        
        # Convertir a diccionario y AÑADIR el logo
        vehicle_dict = new_vehicle.model_dump() if hasattr(new_vehicle, 'model_dump') else new_vehicle.__dict__
        vehicle_dict["logo"] = logo # Añadir/sobrescribir logo aquí
        
        vehicle_dict["maintenance_records"] = [] 
        vehicle_dict["pdf_manual_grid_fs_id"] = None

        result = await db.db.vehicles.insert_one(vehicle_dict)
        created_vehicle = await db.db.vehicles.find_one({"_id": result.inserted_id})
        
        if not created_vehicle:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Error al recuperar el vehículo creado"
            )
        
        # Usar **created_vehicle para poblar el modelo de respuesta
        # Esto es más robusto si VehicleResponse tiene los campos adecuados
        try:
            response_data = VehicleResponse(**{**created_vehicle, "id": str(created_vehicle["_id"]), "userId": str(created_vehicle["user_id"])})
        except ValidationError as val_err:
            logger.error(f"Error al validar VehicleResponse: {val_err}")
            raise HTTPException(status_code=500, detail="Error al formatear la respuesta del vehículo creado")

        return response_data
        
    except ValidationError as e: 
        logger.error(f"Error de validación al crear vehículo: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Datos del vehículo inválidos: {str(e)}"
        )
    except Exception as e:
        logger.error(f"Error inesperado al crear/insertar el vehículo: {str(e)}", exc_info=True) # Log con traceback
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error interno al crear el vehículo"
        )

@router.get("", response_model=List[VehicleResponse])
async def get_user_vehicles(current_user: dict = Depends(get_current_user_data)):
    """Obtener todos los vehículos del usuario"""
    vehicles = await db.db.vehicles.find({"user_id": ObjectId(current_user["id"])}).to_list(None)
    
    # Formatear los vehículos para la respuesta
    formatted_vehicles = []
    for vehicle in vehicles:
        formatted_vehicle = {
            "id": str(vehicle["_id"]),
            "userId": str(vehicle["user_id"]),
            "brand": vehicle["brand"],
            "model": vehicle["model"],
            "year": vehicle["year"],
            "licensePlate": vehicle["licensePlate"],
            "current_kilometers": vehicle.get("current_kilometers", 0.0),
            "maintenance_records": [],
            "pdf_manual_grid_fs_id": str(vehicle["pdf_manual_grid_fs_id"]) if vehicle.get("pdf_manual_grid_fs_id") else None,
            "logo": vehicle.get("logo"),  # Incluir el logo si existe
            "last_itv_date": vehicle.get("last_itv_date"),  # Incluir fecha de última ITV
            "next_itv_date": vehicle.get("next_itv_date"),  # Incluir fecha de próxima ITV
            "created_at": vehicle["created_at"],
            "updated_at": vehicle["updated_at"]
        }
        
        # Formatear registros de mantenimiento si existen
        if "maintenance_records" in vehicle:
            formatted_vehicle["maintenance_records"] = [
                {
                    "id": str(record["_id"]),
                    "type": record["type"],
                    "last_change_km": record["last_change_km"],
                    "recommended_interval_km": record["recommended_interval_km"],
                    "next_change_km": record["next_change_km"],
                    "last_change_date": record["last_change_date"],
                    "notes": record.get("notes"),
                    "km_since_last_change": record.get("km_since_last_change", 0.0)
                }
                for record in vehicle["maintenance_records"]
            ]
        
        formatted_vehicles.append(formatted_vehicle)
    
    return formatted_vehicles

@router.post("/{vehicle_id}/manual", status_code=status.HTTP_201_CREATED)
async def upload_vehicle_manual(
    vehicle_id: str,
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user_data)
):
    """Subir manual del vehículo en PDF"""
    vehicle = await db.db.vehicles.find_one({
        "_id": ObjectId(vehicle_id),
        "user_id": ObjectId(current_user["id"])
    })
    
    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehículo no encontrado"
        )
    
    if not file.content_type == "application/pdf":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El archivo debe ser un PDF"
        )
    
    # Crear GridFS bucket
    fs = AsyncIOMotorGridFSBucket(db.db)
    
    # Si ya existe un manual, eliminarlo
    if "pdf_manual_grid_fs_id" in vehicle:
        try:
            await fs.delete(ObjectId(vehicle["pdf_manual_grid_fs_id"]))
        except Exception:
            pass
    
    try:
        # Leer el contenido del archivo
        contents = await file.read()
        
        # Subir nuevo archivo
        file_id = await fs.upload_from_stream(
            file.filename,
            contents,
            metadata={"vehicle_id": vehicle_id}
        )
        
        # Actualizar referencia en el vehículo
        result = await db.db.vehicles.update_one(
            {"_id": ObjectId(vehicle_id)},
            {
                "$set": {
                    "pdf_manual_grid_fs_id": str(file_id),
                    "updated_at": datetime.utcnow()
                }
            }
        )
        
        if result.modified_count == 0:
            # Si no se pudo actualizar el vehículo, eliminar el archivo subido
            await fs.delete(file_id)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="No se pudo actualizar el vehículo con el nuevo manual"
            )
        
        # Verificar que el archivo se guardó correctamente
        vehicle_updated = await db.db.vehicles.find_one({"_id": ObjectId(vehicle_id)})
        if not vehicle_updated or "pdf_manual_grid_fs_id" not in vehicle_updated:
            await fs.delete(file_id)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Error al guardar la referencia del manual"
            )
        
        return {"message": "Manual subido correctamente", "pdf_manual_grid_fs_id": str(file_id)}
        
    except Exception as e:
        # Si ocurre algún error, intentar limpiar el archivo si se subió
        if 'file_id' in locals():
            try:
                await fs.delete(file_id)
            except Exception:
                pass
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al subir el manual: {str(e)}"
        )

@router.post("/{vehicle_id}/maintenance", response_model=MaintenanceRecordResponse, status_code=status.HTTP_201_CREATED)
async def add_maintenance_record(
    vehicle_id: str,
    maintenance_data: MaintenanceRecordCreate,
    current_user: dict = Depends(get_current_user_data)
):
    """Añadir un nuevo registro de mantenimiento"""
    vehicle = await db.db.vehicles.find_one({
        "_id": ObjectId(vehicle_id),
        "user_id": ObjectId(current_user["id"])
    })
    
    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehículo no encontrado"
        )
        
    current_kilometers = vehicle.get("current_kilometers", 0.0)
    
    # Usar el kilometraje actual si last_change_km no se proporciona
    last_change_km = maintenance_data.last_change_km if maintenance_data.last_change_km is not None else current_kilometers
    last_change_date = maintenance_data.last_change_date if maintenance_data.last_change_date is not None else datetime.utcnow()
    
    # Validar que los kilómetros del último cambio no sean mayores que los actuales
    if last_change_km > current_kilometers:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Los kilómetros del último cambio no pueden ser mayores que los kilómetros actuales del vehículo"
        )
    
    # Calcular los kilómetros desde el último cambio
    km_since_last_change = current_kilometers - last_change_km
    
    # Crear registro de mantenimiento usando el modelo
    new_record = MaintenanceRecord(
        type=maintenance_data.type,
        last_change_km=last_change_km,
        recommended_interval_km=maintenance_data.recommended_interval_km,
        next_change_km=last_change_km + maintenance_data.recommended_interval_km, # Cálculo correcto
        last_change_date=last_change_date,
        notes=maintenance_data.notes,
        km_since_last_change=km_since_last_change
    )
    
    result = await db.db.vehicles.update_one(
        {"_id": ObjectId(vehicle_id)},
        {
            "$push": {"maintenance_records": new_record.__dict__},
            "$set": {"updated_at": datetime.utcnow()}
        }
    )
    
    if result.modified_count == 0:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error al añadir el registro de mantenimiento al vehículo"
        )
    
    # Devolver el registro creado formateado
    # Usar __dict__ ya que new_record no parece ser un modelo Pydantic
    record_dict = new_record.__dict__ 
    return MaintenanceRecordResponse(**record_dict, id=str(new_record._id))

@router.get("/{vehicle_id}", response_model=VehicleResponse)
async def get_vehicle(
    vehicle_id: str,
    current_user: dict = Depends(get_current_user_data)
):
    """Obtener un vehículo específico"""
    vehicle = await db.db.vehicles.find_one({
        "_id": ObjectId(vehicle_id),
        "user_id": ObjectId(current_user["id"])
    })
    
    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehículo no encontrado"
        )
    
    # Formatear registros de mantenimiento
    maintenance_records = []
    if "maintenance_records" in vehicle:
        maintenance_records = [
            {
                "id": str(record["_id"]),
                "type": record["type"],
                "last_change_km": record["last_change_km"],
                "recommended_interval_km": record["recommended_interval_km"],
                "next_change_km": record["next_change_km"],
                "last_change_date": record["last_change_date"],
                "notes": record.get("notes"),
                "km_since_last_change": record.get("km_since_last_change", 0.0)
            }
            for record in vehicle["maintenance_records"]
        ]
    
    return {
        "id": str(vehicle["_id"]),
        "userId": str(vehicle["user_id"]),
        "brand": vehicle["brand"],
        "model": vehicle["model"],
        "year": vehicle["year"],
        "licensePlate": vehicle["licensePlate"],
        "current_kilometers": vehicle.get("current_kilometers", 0.0),
        "maintenance_records": maintenance_records,
        "pdf_manual_grid_fs_id": str(vehicle["pdf_manual_grid_fs_id"]) if vehicle.get("pdf_manual_grid_fs_id") else None,
        "logo": vehicle.get("logo"),
        "last_itv_date": vehicle.get("last_itv_date"),
        "next_itv_date": vehicle.get("next_itv_date"),
        "created_at": vehicle["created_at"],
        "updated_at": vehicle["updated_at"]
    }

@router.put("/{vehicle_id}", response_model=VehicleResponse)
async def update_vehicle(
    vehicle_id: str,
    vehicle_update: VehicleUpdate,
    current_user: dict = Depends(get_current_user_data)
):
    """Actualizar un vehículo"""
    vehicle = await db.db.vehicles.find_one({
        "_id": ObjectId(vehicle_id),
        "user_id": ObjectId(current_user["id"])
    })
    
    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehículo no encontrado"
        )
    
    # Crear un diccionario con los campos a actualizar
    update_data = {}
    
    # Verificar cada campo opcional
    if vehicle_update.brand is not None:
        update_data["brand"] = vehicle_update.brand
        
        # Si la marca cambia, actualizar el logo
        if vehicle_update.brand != vehicle["brand"]:
            # Obtener el nuevo logo
            new_logo = get_car_logo(vehicle_update.brand)
            if new_logo:
                update_data["logo"] = new_logo
    
    if vehicle_update.model is not None:
        update_data["model"] = vehicle_update.model
    
    if vehicle_update.year is not None:
        update_data["year"] = vehicle_update.year
    
    if vehicle_update.licensePlate is not None:
        # Verificar que no exista otro vehículo con esa matrícula
        if vehicle_update.licensePlate != vehicle["licensePlate"]:
            existing_vehicle = await db.db.vehicles.find_one({
                "licensePlate": vehicle_update.licensePlate,
                "user_id": ObjectId(current_user["id"]),
                "_id": {"$ne": ObjectId(vehicle_id)}
            })
            
            if existing_vehicle:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Ya existe un vehículo con esa matrícula para este usuario"
                )
        
        update_data["licensePlate"] = vehicle_update.licensePlate
    
    if vehicle_update.current_kilometers is not None:
        update_data["current_kilometers"] = vehicle_update.current_kilometers
    
    # Si se proporcionó el logo manualmente, actualizarlo
    if vehicle_update.logo is not None:
        update_data["logo"] = vehicle_update.logo
    
    if update_data:
        # Actualizar también la fecha de última actualización
        update_data["updated_at"] = datetime.utcnow()
        
        # Actualizar el vehículo
        result = await db.db.vehicles.update_one(
            {"_id": ObjectId(vehicle_id)},
            {"$set": update_data}
        )
        
        if result.modified_count == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No se ha modificado el vehículo"
            )
    
    # Obtener el vehículo actualizado
    updated_vehicle = await db.db.vehicles.find_one({"_id": ObjectId(vehicle_id)})
    
    # Transformar los registros de mantenimiento para incluir el id
    maintenance_records = []
    for record in updated_vehicle.get("maintenance_records", []):
        maintenance_record = {
            "id": str(record["_id"]),
            "type": record["type"],
            "last_change_km": record["last_change_km"],
            "recommended_interval_km": record["recommended_interval_km"],
            "next_change_km": record["next_change_km"],
            "last_change_date": record["last_change_date"],
            "notes": record.get("notes", ""),
            "km_since_last_change": record.get("km_since_last_change", 0.0)
        }
        maintenance_records.append(maintenance_record)
    
    return {
        "id": str(updated_vehicle["_id"]),
        "userId": str(updated_vehicle["user_id"]),
        "brand": updated_vehicle["brand"],
        "model": updated_vehicle["model"],
        "year": updated_vehicle["year"],
        "licensePlate": updated_vehicle["licensePlate"],
        "current_kilometers": updated_vehicle.get("current_kilometers", 0.0),
        "maintenance_records": maintenance_records,
        "pdf_manual_grid_fs_id": updated_vehicle.get("pdf_manual_grid_fs_id"),
        "logo": updated_vehicle.get("logo"),
        "last_itv_date": updated_vehicle.get("last_itv_date"),
        "next_itv_date": updated_vehicle.get("next_itv_date"),
        "created_at": updated_vehicle["created_at"],
        "updated_at": updated_vehicle["updated_at"]
    }

@router.delete("/{vehicle_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_vehicle(
    vehicle_id: str,
    current_user: dict = Depends(get_current_user_data)
):
    """Eliminar un vehículo"""
    vehicle = await db.db.vehicles.find_one({
        "_id": ObjectId(vehicle_id),
        "user_id": ObjectId(current_user["id"])
    })
    
    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehículo no encontrado"
        )
    
    # Si tiene manual PDF, eliminarlo de GridFS
    if "pdf_manual_grid_fs_id" in vehicle:
        fs = AsyncIOMotorGridFSBucket(db.db)
        try:
            await fs.delete(ObjectId(vehicle["pdf_manual_grid_fs_id"]))
        except Exception:
            pass
    
    result = await db.db.vehicles.delete_one({"_id": ObjectId(vehicle_id)})
    
    if result.deleted_count == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Error al eliminar el vehículo"
        )

@router.get("/{vehicle_id}/manual", response_class=Response)
async def get_vehicle_manual(
    vehicle_id: str,
    current_user: dict = Depends(get_current_user_data)
):
    """Obtener manual del vehículo en PDF"""
    vehicle = await db.db.vehicles.find_one({
        "_id": ObjectId(vehicle_id),
        "user_id": ObjectId(current_user["id"])
    })
    
    if not vehicle or "pdf_manual_grid_fs_id" not in vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Manual no encontrado"
        )
    
    fs = AsyncIOMotorGridFSBucket(db.db)
    try:
        file_data = await fs.open_download_stream(ObjectId(vehicle["pdf_manual_grid_fs_id"]))
        contents = await file_data.read()
        return Response(
            content=contents,
            media_type="application/pdf"
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Error al obtener el manual: {str(e)}"
        )

@router.get("/{vehicle_id}/maintenance", response_model=List[MaintenanceRecordResponse])
async def get_vehicle_maintenance(
    vehicle_id: str, 
    current_user: dict = Depends(get_current_user_data)
):
    """Obtener registros de mantenimiento"""
    vehicle = await db.db.vehicles.find_one({
        "_id": ObjectId(vehicle_id),
        "user_id": ObjectId(current_user["id"])
    })
    
    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehículo no encontrado"
        )
        
    maintenance_records = vehicle.get("maintenance_records", [])
    formatted_records = []
    
    for record in maintenance_records:
        formatted_record = {
            "id": str(record["_id"]),
            "type": record["type"],
            "last_change_km": record["last_change_km"],
            "recommended_interval_km": record["recommended_interval_km"],
            "next_change_km": record["next_change_km"],
            "last_change_date": record["last_change_date"],
            "notes": record.get("notes"),
            "km_since_last_change": record.get("km_since_last_change", 0.0)
        }
        formatted_records.append(formatted_record)
            
    return formatted_records

@router.put("/{vehicle_id}/maintenance/{maintenance_id}", response_model=MaintenanceRecordResponse)
async def update_maintenance_record(
    vehicle_id: str,
    maintenance_id: str,
    maintenance_data: MaintenanceRecordCreate,
    current_user: dict = Depends(get_current_user_data)
):
    """Actualizar un registro de mantenimiento existente"""
    try:
        # Verificar que el vehículo existe y pertenece al usuario
        vehicle = await db.db.vehicles.find_one({
            "_id": ObjectId(vehicle_id),
            "user_id": ObjectId(current_user["id"])
        })
        
        if not vehicle:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Vehículo no encontrado"
            )

        # Buscar y actualizar el registro de mantenimiento específico
        maintenance_record = None
        updated_records = []
        
        for record in vehicle.get("maintenance_records", []):
            if str(record["_id"]) == maintenance_id:
                # Calcular next_change_km basado en los datos del modelo
                next_change_km = maintenance_data.last_change_km + maintenance_data.recommended_interval_km
                
                # Crear el registro actualizado con todos los campos requeridos
                maintenance_record = {
                    "_id": ObjectId(maintenance_id),
                    "type": maintenance_data.type,
                    "last_change_km": maintenance_data.last_change_km,
                    "recommended_interval_km": maintenance_data.recommended_interval_km,
                    "next_change_km": next_change_km,
                    "last_change_date": maintenance_data.last_change_date,
                    "notes": maintenance_data.notes if maintenance_data.notes is not None else "",
                    "km_since_last_change": maintenance_data.km_since_last_change
                }
                updated_records.append(maintenance_record)
            else:
                updated_records.append(record)

        if not maintenance_record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Registro de mantenimiento no encontrado"
            )

        # Actualizar el documento del vehículo con los registros actualizados
        result = await db.db.vehicles.update_one(
            {"_id": ObjectId(vehicle_id)},
            {
                "$set": {
                    "maintenance_records": updated_records,
                    "updated_at": datetime.utcnow()
                }
            }
        )

        if result.modified_count == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No se pudo actualizar el registro de mantenimiento"
            )

        # Preparar la respuesta
        response_record = {
            "id": str(maintenance_record["_id"]),
            "type": maintenance_record["type"],
            "last_change_km": maintenance_record["last_change_km"],
            "recommended_interval_km": maintenance_record["recommended_interval_km"],
            "next_change_km": maintenance_record["next_change_km"],
            "last_change_date": maintenance_record["last_change_date"],
            "notes": maintenance_record["notes"],
            "km_since_last_change": maintenance_record["km_since_last_change"]
        }

        return response_record

    except ValidationError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al actualizar el registro de mantenimiento: {str(e)}"
        )

@router.delete("/{vehicle_id}/maintenance/{maintenance_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_maintenance_record(
    vehicle_id: str,
    maintenance_id: str,
    current_user: dict = Depends(get_current_user_data)
):
    """Eliminar un registro de mantenimiento específico"""
    try:
        # Verificar que el vehículo existe y pertenece al usuario
        vehicle = await db.db.vehicles.find_one({
            "_id": ObjectId(vehicle_id),
            "user_id": ObjectId(current_user["id"])
        })
        
        if not vehicle:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Vehículo no encontrado"
            )

        # Buscar y eliminar el registro de mantenimiento específico
        result = await db.db.vehicles.update_one(
            {"_id": ObjectId(vehicle_id)},
            {
                "$pull": {
                    "maintenance_records": {
                        "_id": ObjectId(maintenance_id)
                    }
                },
                "$set": {"updated_at": datetime.utcnow()}
            }
        )

        if result.modified_count == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Registro de mantenimiento no encontrado"
            )

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al eliminar el registro de mantenimiento: {str(e)}"
        )

@router.delete("/{vehicle_id}/manual", status_code=status.HTTP_204_NO_CONTENT)
async def delete_manual(
    vehicle_id: str,
    current_user: dict = Depends(get_current_user_data)
):
    """Eliminar el manual de taller de un vehículo"""
    try:
        # Verificar que el vehículo existe y pertenece al usuario
        vehicle = await db.db.vehicles.find_one({
            "_id": ObjectId(vehicle_id),
            "user_id": ObjectId(current_user["id"])
        })
        
        if not vehicle:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Vehículo no encontrado"
            )

        if "pdf_manual_grid_fs_id" not in vehicle:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No se encontró un manual para este vehículo"
            )

        # Eliminar el archivo de GridFS
        fs = AsyncIOMotorGridFSBucket(db.db)
        await fs.delete(ObjectId(vehicle["pdf_manual_grid_fs_id"]))

        # Actualizar el documento del vehículo
        result = await db.db.vehicles.update_one(
            {"_id": ObjectId(vehicle_id)},
            {
                "$unset": {"pdf_manual_grid_fs_id": ""},
                "$set": {"updated_at": datetime.utcnow()}
            }
        )

        if result.modified_count == 0:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="No se pudo actualizar el vehículo"
            )

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al eliminar el manual: {str(e)}"
        )

@router.post("/{vehicle_id}/manual/update", status_code=status.HTTP_200_OK)
async def update_manual(
    vehicle_id: str,
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user_data)
):
    """Actualizar el manual de taller de un vehículo"""
    try:
        # Verificar que el vehículo existe y pertenece al usuario
        vehicle = await db.db.vehicles.find_one({
            "_id": ObjectId(vehicle_id),
            "user_id": ObjectId(current_user["id"])
        })
        
        if not vehicle:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Vehículo no encontrado"
            )

        # Verificar que el archivo es un PDF
        if not file.filename.endswith('.pdf'):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="El archivo debe ser un PDF"
            )

        # Leer el contenido del archivo
        contents = await file.read()

        # Si existe un manual previo, eliminarlo
        if "pdf_manual_grid_fs_id" in vehicle:
            fs = AsyncIOMotorGridFSBucket(db.db)
            try:
                await fs.delete(ObjectId(vehicle["pdf_manual_grid_fs_id"]))
            except Exception:
                # Si falla la eliminación del archivo anterior, continuamos
                pass

        # Guardar el nuevo archivo en GridFS
        fs = AsyncIOMotorGridFSBucket(db.db)
        grid_fs_file_id = await fs.upload_from_stream(
            file.filename,
            contents,
            metadata={"vehicle_id": vehicle_id}
        )

        # Actualizar el documento del vehículo con el nuevo ID del archivo
        result = await db.db.vehicles.update_one(
            {"_id": ObjectId(vehicle_id)},
            {
                "$set": {
                    "pdf_manual_grid_fs_id": str(grid_fs_file_id),
                    "updated_at": datetime.utcnow()
                }
            }
        )

        if result.modified_count == 0:
            # Si no se pudo actualizar el vehículo, eliminar el archivo subido
            await fs.delete(grid_fs_file_id)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="No se pudo actualizar el vehículo"
            )

        return {"message": "Manual actualizado correctamente"}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al actualizar el manual: {str(e)}"
        )

def build_openrouter_headers():
    return {
        "Authorization": f"Bearer {os.getenv('OPENROUTER_API_KEY')}",
        "HTTP-Referer": os.getenv('HTTP_REFERER'),
        "X-Title": os.getenv('X_TITLE'),
        "Content-Type": "application/json",
    }

def _is_maintenance_section_header(text: str) -> bool:
    """Detecta si una línea es un encabezado de sección de mantenimiento"""
    keywords = [
        'programa de mantenimiento', 'maintenance schedule',
        'tabla de mantenimiento', 'maintenance chart',
        'mantenimiento periódico', 'periodic maintenance',
        'intervalos de servicio', 'service intervals',
        'plan de mantenimiento', 'maintenance plan'
    ]
    
    text_lower = text.lower()
    return any(keyword in text_lower for keyword in keywords)

def _is_maintenance_related(text: str) -> bool:
    """Determina si una línea de texto está relacionada con mantenimiento"""
    keywords = [
        # Términos generales de mantenimiento
        'mantenimiento', 'maintenance', 'servicio', 'service',
        'revisión', 'inspection', 'inspección', 'check',
        'intervalo', 'interval', 'periódico', 'periodic',
        'programa', 'schedule', 'tabla', 'chart',
        
        # Componentes específicos
        'aceite', 'oil', 'filtro', 'filter', 'frenos', 'brake',
        'neumáticos', 'tires', 'batería', 'battery',
        'correa', 'belt', 'líquido', 'fluid',
        'bujía', 'spark plug', 'embrague', 'clutch',
        'válvula', 'valve', 'cadena', 'chain',
        'tubo de escape', 'exhaust', 'silenciador', 'muffler',
        'dirección', 'steering', 'suspensión', 'suspension',
        'chasis', 'chassis', 'tuercas', 'nuts', 'tornillos', 'bolts',
        'horquilla', 'fork',
        
        # Intervalos y medidas
        'cada', 'every', 'km', 'kilómetros', 'kilometers',
        'meses', 'months', 'años', 'years',
        
        # Acciones de mantenimiento
        'cambiar', 'change', 'reemplazar', 'replace',
        'ajustar', 'adjust', 'lubricar', 'lubricate',
        'limpiar', 'clean', 'apretar', 'tighten',
        'inspeccionar', 'inspect', 'comprobar', 'check'
    ]
    
    # Patrones numéricos seguidos de km o similares
    number_patterns = [
        r'\d+\s*(?:km|kilómetros|kilometers|miles)',
        r'cada\s+\d+',
        r'every\s+\d+',
        r'\d+\s*000\s*km',
        r'\d+\s*(?:meses|months|años|years)'
    ]
    
    text_lower = text.lower()
    
    # Verificar palabras clave
    if any(keyword in text_lower for keyword in keywords):
        return True
        
    # Verificar patrones numéricos
    if any(re.search(pattern, text_lower) for pattern in number_patterns):
        return True
        
    return False

def _extract_maintenance_sections(text: str) -> str:
    """Extrae solo las secciones relacionadas con mantenimiento"""
    lines = text.split('\n')
    maintenance_lines = []
    in_maintenance_section = False
    section_content = []
    context_lines = []  # Para mantener algunas líneas de contexto
    
    print("\nBuscando secciones de mantenimiento...")
    
    for i, line in enumerate(lines):
        current_line = line.strip()
        
        # Si la línea está vacía, mantenerla como separador
        if not current_line:
            if section_content:
                section_content.append("")
            continue
            
        # Si encontramos un encabezado de sección de mantenimiento
        if _is_maintenance_section_header(current_line):
            print(f"Encontrada sección de mantenimiento en línea {i+1}: {current_line[:50]}...")
            in_maintenance_section = True
            if context_lines:  # Incluir líneas de contexto previas
                section_content.extend(context_lines)
            section_content = [current_line]
            context_lines = []
            continue
            
        # Si estamos en una sección de mantenimiento
        if in_maintenance_section:
            # Si la línea tiene contenido relacionado con mantenimiento o es una tabla
            if _is_maintenance_related(current_line) or re.search(r'[|\t]', current_line):
                section_content.append(current_line)
            # Si encontramos una línea que parece ser un nuevo encabezado no relacionado
            elif current_line.isupper() and len(current_line.split()) > 3:
                if section_content:
                    maintenance_lines.extend(section_content)
                    section_content = []
                in_maintenance_section = False
            # Si la línea parece ser parte del contenido actual
            else:
                section_content.append(current_line)
        # Si no estamos en una sección pero la línea tiene información de mantenimiento
        elif _is_maintenance_related(current_line):
            print(f"Encontrada línea de mantenimiento fuera de sección en línea {i+1}: {current_line[:50]}...")
            maintenance_lines.append(current_line)
        else:
            # Mantener algunas líneas de contexto
            context_lines.append(current_line)
            if len(context_lines) > 3:  # Mantener solo las últimas 3 líneas de contexto
                context_lines.pop(0)
    
    # Añadir la última sección si existe
    if section_content:
        maintenance_lines.extend(section_content)
    
    result = '\n'.join(maintenance_lines)
    print(f"\nEncontradas {len(maintenance_lines)} líneas relacionadas con mantenimiento")
    return result

def _clean_json_string(text: str) -> str:
    """Limpia una cadena JSON malformada"""
    # Eliminar caracteres de escape innecesarios
    text = text.replace('\\\"', '"')
    text = text.replace('\\"', '"')
    
    # Eliminar comillas simples si existen
    text = text.replace("'", '"')
    
    # Eliminar espacios en blanco en nombres de propiedades
    text = re.sub(r'"(\w+)\s*":', r'"\1":', text)
    
    # Corregir espacios en valores numéricos
    text = re.sub(r':\s*(\d+)\s*,', r': \1,', text)
    
    # Eliminar caracteres no válidos
    text = re.sub(r'[^\x20-\x7E]', '', text)
    
    return text

def _call_openrouter_with_retry(data: dict, max_retries: int = 3) -> dict:
    """Llama a OpenRouter con reintentos"""
    headers = build_openrouter_headers()
    attempt = 0
    last_error = None
    
    while attempt < max_retries:
        try:
            print(f"\nIntento {attempt + 1} de {max_retries}...")
            response = requests.post(
                os.getenv('OPENROUTER_URL'),
                headers=headers,
                json=data,
                timeout=90  # Aumentar el timeout a 90 segundos
            )
            
            # Verificar si hay error en la respuesta
            result = response.json()
            if "error" in result:
                error_msg = result["error"].get("message", "Error desconocido de OpenRouter")
                print(f"Error de OpenRouter: {error_msg}")
                last_error = error_msg
                # Si es un error de timeout o del proveedor, reintentar
                if result["error"].get("code") in [524, 500, 502, 503, 504]:
                    attempt += 1
                    if attempt < max_retries:
                        print("Reintentando en 5 segundos...")
                        time.sleep(5)
                        continue
                else:
                    # Si es otro tipo de error, fallar inmediatamente
                    raise Exception(error_msg)
            else:
                return result
                
        except requests.exceptions.Timeout:
            print("Timeout en la solicitud")
            last_error = "Timeout en la solicitud"
            attempt += 1
            if attempt < max_retries:
                print("Reintentando en 5 segundos...")
                time.sleep(5)
                continue
        except Exception as e:
            print(f"Error inesperado: {str(e)}")
            last_error = str(e)
            attempt += 1
            if attempt < max_retries:
                print("Reintentando en 5 segundos...")
                time.sleep(5)
                continue
    
    # Si llegamos aquí, todos los intentos fallaron
    raise Exception(f"Todos los intentos fallaron. Último error: {last_error}")

@router.post("/{vehicle_id}/maintenance-ai")
async def analyze_maintenance_pdf(
    vehicle_id: str,
    current_user: dict = Depends(get_current_user_data)
):
    try:
        # Verificar que el vehículo existe y pertenece al usuario
        vehicle = await db.db.vehicles.find_one({
            "_id": ObjectId(vehicle_id),
            "user_id": ObjectId(current_user["id"])
        })
        
        if not vehicle:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Vehículo no encontrado"
            )

        # Verificar que el vehículo tiene un manual PDF
        if not vehicle.get("pdf_manual_grid_fs_id"):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No se encontró el manual del vehículo"
            )

        print("Vehículo y manual verificados")

        # Recuperar y procesar el PDF
        try:
            fs = AsyncIOMotorGridFSBucket(db.db)
            file_data = await fs.open_download_stream(ObjectId(vehicle["pdf_manual_grid_fs_id"]))
            pdf_bytes = await file_data.read()
            print("PDF recuperado de GridFS")
        except Exception as e:
            print("Error al recuperar el PDF:", str(e))
            raise HTTPException(
                status_code=500,
                detail=f"Error al recuperar el PDF: {str(e)}"
            )

        # Extraer y limpiar texto del PDF
        try:
            extracted_text = ""
            with fitz.open(stream=pdf_bytes, filetype="pdf") as doc:
                print(f"Procesando PDF de {len(doc)} páginas")
                for page in doc:
                    extracted_text += page.get_text() + "\n"
            print("Texto extraído del PDF")
        except Exception as e:
            print("Error al extraer texto del PDF:", str(e))
            raise HTTPException(
                status_code=500,
                detail=f"Error al extraer texto del PDF: {str(e)}"
            )
        
        # Limpiar el texto
        cleaned_text = _extract_maintenance_sections(extracted_text)

        # Configurar la solicitud a OpenRouter
        print("\nPreparando solicitud a OpenRouter")
        data = {
            "model": os.getenv('OPENROUTER_MODEL'),
            "messages": [
                {
                    "role": "system",
                    "content": (
                        "Eres un experto en mantenimiento de vehículos. "
                        "DEBES responder ÚNICAMENTE con un array JSON que contenga los mantenimientos con intervalos en kilómetros. "
                        "NO incluyas explicaciones adicionales ni texto fuera del JSON. "
                        "Formato OBLIGATORIO: [{\"type\": \"tipo de mantenimiento\", \"recommended_interval_km\": numero, \"notes\": \"notas adicionales\"}]. "
                        "Reglas ESTRICTAS:\n"
                        "1. SOLO devuelve el array JSON, nada más\n"
                        "2. El campo type debe estar en español\n"
                        "3. recommended_interval_km debe ser un número entero\n"
                        "4. El campo notes debe ser un string con información relevante\n"
                        "5. Si no hay intervalos en km, devuelve []\n"
                        "6. NO uses comillas simples, SOLO dobles\n"
                        "7. NO incluyas espacios entre los dos puntos\n"
                        "Ejemplo correcto: [{\"type\":\"cambio de aceite\",\"recommended_interval_km\":10000,\"notes\":\"Cambiar el aceite del motor y el filtro\"}]"
                    )
                },
                {
                    "role": "user",
                    "content": f"Extrae y devuelve SOLO el array JSON con los mantenimientos que tienen intervalos en kilómetros:\n\n{cleaned_text}"
                }
            ],
            "temperature": 0.1,
            "top_p": 0.9,
            "frequency_penalty": 0.0,
            "presence_penalty": 0.0
        }

        # Llamar a OpenRouter con reintentos
        try:
            result = _call_openrouter_with_retry(data)
            print("\nRespuesta de OpenRouter:")
            print(result)
        except Exception as e:
            print(f"Error final en OpenRouter: {str(e)}")
            return {
                "vehicleId": vehicle_id,
                "maintenance_recommendations": [],
                "error": str(e)
            }

        # Procesar la respuesta
        try:
            if "choices" not in result or not result["choices"]:
                print("Respuesta no contiene 'choices' o está vacía")
                return {
                    "vehicleId": vehicle_id,
                    "maintenance_recommendations": [],
                    "error": "Formato de respuesta inválido"
                }
            
            # Obtener el contenido de la respuesta
            content = result["choices"][0]["message"].get("content", "").strip()
            print("\nContenido de la respuesta:")
            print(content)
            
            # Intentar encontrar el JSON en la respuesta
            try:
                # Primero intentar parsear directamente
                ai_response = json.loads(content)
            except json.JSONDecodeError:
                # Si falla, buscar el array JSON usando regex
                json_match = re.search(r'\[(.*?)\]', content, re.DOTALL)
                if json_match:
                    json_str = f"[{json_match.group(1)}]"
                    cleaned_json = _clean_json_string(json_str)
                    print("\nJSON encontrado y limpiado:")
                    print(cleaned_json)
                    try:
                        ai_response = json.loads(cleaned_json)
                    except json.JSONDecodeError as e:
                        print(f"Error al parsear JSON limpio: {str(e)}")
                        ai_response = []
                else:
                    print("No se encontró JSON en la respuesta")
                    ai_response = []
            
            # Verificar y limpiar la respuesta
            cleaned_response = []
            for item in ai_response:
                if isinstance(item, dict) and "type" in item and "recommended_interval_km" in item:
                    try:
                        interval = int(float(str(item["recommended_interval_km"]).replace(',', '')))
                        # Capitalizar la primera letra del tipo de mantenimiento
                        maintenance_type = item["type"].strip()
                        maintenance_type = maintenance_type[0].upper() + maintenance_type[1:] if maintenance_type else ""
                        
                        cleaned_response.append({
                            "type": maintenance_type,
                            "recommended_interval_km": interval,
                            "notes": item.get("notes", "").strip()  # Incluir las notas si existen
                        })
                    except (ValueError, TypeError):
                        print(f"Valor inválido para recommended_interval_km: {item['recommended_interval_km']}")
                        continue
            
            print("\nRespuesta final procesada:")
            print(json.dumps(cleaned_response, indent=2, ensure_ascii=False))
            
            return {
                "vehicleId": vehicle_id,
                "maintenance_recommendations": cleaned_response
            }
            
        except Exception as e:
            print("Error al procesar la respuesta:", str(e))
            return {
                "vehicleId": vehicle_id,
                "maintenance_recommendations": [],
                "error": f"Error al procesar la respuesta: {str(e)}"
            }

    except HTTPException:
        raise
    except Exception as e:
        print("Error inesperado:", str(e))
        return {
            "vehicleId": vehicle_id,
            "maintenance_recommendations": [],
            "error": f"Error inesperado: {str(e)}"
        }

@router.post("/{vehicle_id}/maintenance/{maintenance_id}/complete", response_model=MaintenanceRecordResponse)
async def complete_maintenance(
    vehicle_id: str,
    maintenance_id: str,
    current_user: dict = Depends(get_current_user_data)
):
    """Marcar un mantenimiento como completado"""
    try:
        # Verificar que el vehículo existe y pertenece al usuario
        vehicle = await db.db.vehicles.find_one({
            "_id": ObjectId(vehicle_id),
            "user_id": ObjectId(current_user["id"])
        })
        
        if not vehicle:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Vehículo no encontrado"
            )

        # Buscar el registro de mantenimiento específico
        maintenance_record = None
        updated_records = []
        now = datetime.utcnow()
        
        for record in vehicle.get("maintenance_records", []):
            if str(record["_id"]) == maintenance_id:
                # Calcular el nuevo last_change_km basado en el último cambio más los kilómetros recorridos
                km_since_last_change = record.get("km_since_last_change", 0.0)
                last_change_km = record["last_change_km"] + km_since_last_change
                recommended_interval_km = record["recommended_interval_km"]
                next_change_km = last_change_km + recommended_interval_km
                
                # Actualizar el registro de mantenimiento
                maintenance_record = {
                    "_id": ObjectId(maintenance_id),
                    "type": record["type"],
                    "last_change_km": last_change_km,
                    "recommended_interval_km": recommended_interval_km,
                    "next_change_km": next_change_km,
                    "last_change_date": now,  # Actualizar la fecha a hoy
                    "notes": record.get("notes", ""),
                    "km_since_last_change": 0.0  # Resetear los kilómetros desde el último cambio
                }
                updated_records.append(maintenance_record)
            else:
                updated_records.append(record)

        if not maintenance_record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Registro de mantenimiento no encontrado"
            )

        # Actualizar el documento del vehículo con los registros actualizados
        result = await db.db.vehicles.update_one(
            {"_id": ObjectId(vehicle_id)},
            {
                "$set": {
                    "maintenance_records": updated_records,
                    "updated_at": now
                }
            }
        )

        if result.modified_count == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No se pudo actualizar el registro de mantenimiento"
            )

        # Preparar la respuesta
        response_record = {
            "id": str(maintenance_record["_id"]),
            "type": maintenance_record["type"],
            "last_change_km": maintenance_record["last_change_km"],
            "recommended_interval_km": maintenance_record["recommended_interval_km"],
            "next_change_km": maintenance_record["next_change_km"],
            "last_change_date": maintenance_record["last_change_date"],
            "notes": maintenance_record["notes"],
            "km_since_last_change": maintenance_record["km_since_last_change"]
        }

        return response_record

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al completar el registro de mantenimiento: {str(e)}"
        )

@router.post("/{vehicle_id}/itv", response_model=ITVResponse)
async def update_itv(
    vehicle_id: str,
    itv_data: ITVUpdate,
    current_user: dict = Depends(get_current_user_data)
):
    """Actualizar la información de ITV de un vehículo"""
    vehicle = await db.db.vehicles.find_one({
        "_id": ObjectId(vehicle_id),
        "user_id": ObjectId(current_user["id"])
    })
    
    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehículo no encontrado"
        )
    
    # Obtener la fecha actual
    current_date = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    
    # Determinar si la fecha proporcionada es para la última ITV o la próxima
    is_past_date = itv_data.itv_date.replace(tzinfo=None) <= current_date
    
    update_data = {}
    
    if is_past_date:
        # Si es una fecha pasada o actual, se considera como la última ITV
        update_data["last_itv_date"] = itv_data.itv_date
        
        # Calcular la próxima fecha de ITV basada en la edad del vehículo
        vehicle_age = current_date.year - vehicle["year"]
        
        if vehicle_age < 4:
            # Primera ITV a los 4 años
            next_itv_date = datetime(vehicle["year"] + 4, 1, 1)
        elif 4 <= vehicle_age <= 10:
            # ITV cada 2 años
            next_itv_date = itv_data.itv_date + timedelta(days=365*2)
        else:
            # ITV anual
            next_itv_date = itv_data.itv_date + timedelta(days=365)
        
        update_data["next_itv_date"] = next_itv_date
    else:
        # Si es una fecha futura, se considera como la próxima ITV
        update_data["next_itv_date"] = itv_data.itv_date
    
    # Actualizar el vehículo
    update_data["updated_at"] = datetime.utcnow()
    
    result = await db.db.vehicles.update_one(
        {"_id": ObjectId(vehicle_id)},
        {"$set": update_data}
    )
    
    if result.modified_count == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No se ha podido actualizar la información de ITV"
        )
    
    # Obtener el vehículo actualizado
    updated_vehicle = await db.db.vehicles.find_one({"_id": ObjectId(vehicle_id)})
    
    return {
        "id": str(updated_vehicle["_id"]),
        "last_itv_date": updated_vehicle.get("last_itv_date"),
        "next_itv_date": updated_vehicle.get("next_itv_date")
    }

@router.post("/{vehicle_id}/itv/complete", response_model=ITVResponse)
async def complete_itv(
    vehicle_id: str,
    current_user: dict = Depends(get_current_user_data)
):
    """Marcar la ITV como completada (la próxima se convierte en la última)"""
    vehicle = await db.db.vehicles.find_one({
        "_id": ObjectId(vehicle_id),
        "user_id": ObjectId(current_user["id"])
    })
    
    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehículo no encontrado"
        )
    
    # Obtener la fecha actual
    current_date = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    
    update_data = {}
    
    # Actualizar la última fecha de ITV
    update_data["last_itv_date"] = current_date
    
    # Calcular la próxima fecha de ITV basada en la edad del vehículo
    vehicle_age = current_date.year - vehicle["year"]
    
    if vehicle_age < 4:
        # Primera ITV a los 4 años
        next_itv_date = datetime(vehicle["year"] + 4, 1, 1)
    elif 4 <= vehicle_age <= 10:
        # ITV cada 2 años
        next_itv_date = current_date + timedelta(days=365*2)
    else:
        # ITV anual
        next_itv_date = current_date + timedelta(days=365)
    
    update_data["next_itv_date"] = next_itv_date
    update_data["updated_at"] = datetime.utcnow()
    
    result = await db.db.vehicles.update_one(
        {"_id": ObjectId(vehicle_id)},
        {"$set": update_data}
    )
    
    if result.modified_count == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No se ha podido actualizar la información de ITV"
        )
    
    # Obtener el vehículo actualizado
    updated_vehicle = await db.db.vehicles.find_one({"_id": ObjectId(vehicle_id)})
    
    return {
        "id": str(updated_vehicle["_id"]),
        "last_itv_date": updated_vehicle.get("last_itv_date"),
        "next_itv_date": updated_vehicle.get("next_itv_date")
    }