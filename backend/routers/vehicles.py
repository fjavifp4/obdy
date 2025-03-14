from fastapi import APIRouter, HTTPException, Depends, status, UploadFile, File, Response
from bson import ObjectId
from typing import List
from datetime import datetime
from gridfs import GridFS
from motor.motor_asyncio import AsyncIOMotorGridFSBucket
from fastapi.responses import Response
from pydantic import ValidationError

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
    MaintenanceRecordResponse
)
from routers.auth import get_current_user_data
from models.vehicle import Vehicle, MaintenanceRecord
from utils.car_logo_scraper import get_car_logo

router = APIRouter()

@router.post("", response_model=VehicleResponse, status_code=status.HTTP_201_CREATED)
async def create_vehicle(
    vehicle_data: VehicleCreate,
    current_user: dict = Depends(get_current_user_data)
):
    """Crear un nuevo vehículo"""
    try:
        # Verificar si ya existe un vehículo con esa matrícula
        existing_vehicle = await db.db.vehicles.find_one({
            "licensePlate": vehicle_data.licensePlate,
            "user_id": ObjectId(current_user["id"])
        })
        
        if existing_vehicle:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Ya existe un vehículo con esa matrícula para este usuario"
            )
        
        # Obtener el logo de la marca haciendo scraping
        logo = get_car_logo(vehicle_data.brand)
        
        # Crear vehículo usando el modelo
        new_vehicle = Vehicle(
            user_id=ObjectId(current_user["id"]),
            brand=vehicle_data.brand,
            model=vehicle_data.model,
            year=vehicle_data.year,
            licensePlate=vehicle_data.licensePlate
        )
        
        # Asignar el logo si se encontró
        new_vehicle.logo = logo
        
        # Convertir el objeto Vehicle a diccionario
        vehicle_dict = {
            "_id": new_vehicle._id,
            "user_id": new_vehicle.user_id,
            "brand": new_vehicle.brand,
            "model": new_vehicle.model,
            "year": new_vehicle.year,
            "licensePlate": new_vehicle.licensePlate,
            "maintenance_records": new_vehicle.maintenance_records,
            "pdf_manual_grid_fs_id": new_vehicle.pdf_manual_grid_fs_id,
            "logo": new_vehicle.logo,
            "created_at": new_vehicle.created_at,
            "updated_at": new_vehicle.updated_at
        }
        
        # Insertar en la base de datos
        result = await db.db.vehicles.insert_one(vehicle_dict)
        
        # Obtener el vehículo creado
        created_vehicle = await db.db.vehicles.find_one({"_id": result.inserted_id})
        
        if not created_vehicle:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Error al crear el vehículo"
            )
        
        # Formatear la respuesta según VehicleResponse
        return {
            "id": str(created_vehicle["_id"]),
            "userId": str(created_vehicle["user_id"]),
            "brand": created_vehicle["brand"],
            "model": created_vehicle["model"],
            "year": created_vehicle["year"],
            "licensePlate": created_vehicle["licensePlate"],
            "maintenance_records": created_vehicle.get("maintenance_records", []),
            "pdf_manual_grid_fs_id": created_vehicle.get("pdf_manual_grid_fs_id"),
            "logo": created_vehicle.get("logo"),
            "created_at": created_vehicle["created_at"],
            "updated_at": created_vehicle["updated_at"]
        }
        
    except ValidationError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al crear el vehículo: {str(e)}"
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
            "maintenance_records": [],
            "pdf_manual_grid_fs_id": str(vehicle["pdf_manual_grid_fs_id"]) if vehicle.get("pdf_manual_grid_fs_id") else None,
            "logo": vehicle.get("logo"),
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
    
    # Subir nuevo archivo
    file_id = await fs.upload_from_stream(
        file.filename,
        await file.read(),
        metadata={"vehicleId": vehicle_id}
    )
    
    # Actualizar referencia en el vehículo usando solo pdf_manual_grid_fs_id
    await db.db.vehicles.update_one(
        {"_id": ObjectId(vehicle_id)},
        {
            "$set": {
                "pdf_manual_grid_fs_id": str(file_id),
                "updated_at": datetime.utcnow()
            },
            "$unset": {
                "pdfManualGridFSId": ""  # Eliminar el campo antiguo si existe
            }
        }
    )
    
    return {"message": "Manual subido correctamente"}

@router.post("/{vehicle_id}/maintenance", response_model=MaintenanceRecordResponse)
async def add_maintenance_record(
    vehicle_id: str,
    maintenance_data: MaintenanceRecordCreate,
    current_user: dict = Depends(get_current_user_data)
):
    """Añadir registro de mantenimiento"""
    vehicle = await db.db.vehicles.find_one({
        "_id": ObjectId(vehicle_id),
        "user_id": ObjectId(current_user["id"])
    })
    
    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehículo no encontrado"
        )
    
    # Crear registro de mantenimiento usando el modelo
    new_record = MaintenanceRecord(
        type=maintenance_data.type,
        last_change_km=maintenance_data.last_change_km,
        recommended_interval_km=maintenance_data.recommended_interval_km,
        next_change_km=maintenance_data.next_change_km,
        last_change_date=maintenance_data.last_change_date,
        notes=maintenance_data.notes,
        km_since_last_change=maintenance_data.km_since_last_change
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
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Error al añadir el registro de mantenimiento"
        )
    
    return {**new_record.__dict__, "id": str(new_record._id)}

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
        "maintenance_records": maintenance_records,
        "pdf_manual_grid_fs_id": str(vehicle["pdf_manual_grid_fs_id"]) if vehicle.get("pdf_manual_grid_fs_id") else None,
        "logo": vehicle.get("logo"),  # Incluir el logo si existe
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
    
    return {
        "id": str(updated_vehicle["_id"]),
        "userId": str(updated_vehicle["user_id"]),
        "brand": updated_vehicle["brand"],
        "model": updated_vehicle["model"],
        "year": updated_vehicle["year"],
        "licensePlate": updated_vehicle["licensePlate"],
        "maintenance_records": updated_vehicle.get("maintenance_records", []),
        "pdf_manual_grid_fs_id": updated_vehicle.get("pdf_manual_grid_fs_id"),
        "logo": updated_vehicle.get("logo"),
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
                maintenance_record = {
                    "_id": ObjectId(maintenance_id),
                    "type": maintenance_data.type,
                    "last_change_km": maintenance_data.last_change_km,
                    "recommended_interval_km": maintenance_data.recommended_interval_km,
                    "next_change_km": maintenance_data.next_change_km,
                    "last_change_date": maintenance_data.last_change_date,
                    "notes": maintenance_data.notes,
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
            "km_since_last_change": maintenance_record.get("km_since_last_change", 0.0)
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

@router.post("/{vehicle_id}/maintenance-ai")
async def analyze_maintenance_pdf(
    vehicle_id: str,
    current_user: dict = Depends(get_current_user_data)
):
    """
    1) Recupera el PDF almacenado en GridFS
    2) Extrae texto con PyMuPDF
    3) Imprime un fragmento del texto (debug)
    4) Envía el texto a OpenRouter
    5) Imprime la respuesta cruda de OpenRouter
    6) Busca el bloque JSON y lo devuelve parseado
    """
    try:
        # 1) Verificar que el vehículo pertenece al usuario y tiene un manual
        vehicle = await db.db.vehicles.find_one({
            "_id": ObjectId(vehicle_id),
            "user_id": ObjectId(current_user["id"])
        })
        if not vehicle:
            raise HTTPException(
                status_code=404,
                detail="Vehículo no encontrado o no pertenece al usuario"
            )
        if "pdf_manual_grid_fs_id" not in vehicle:
            raise HTTPException(
                status_code=404,
                detail="No se encontró un manual de taller para este vehículo"
            )

        # 2) Recuperar el PDF de GridFS y extraer texto
        fs = AsyncIOMotorGridFSBucket(db.db)
        file_data = await fs.open_download_stream(ObjectId(vehicle["pdf_manual_grid_fs_id"]))
        pdf_bytes = await file_data.read()

        # Extraer texto del PDF con PyMuPDF
        extracted_text = ""
        with fitz.open(stream=pdf_bytes, filetype="pdf") as doc:
            for page in doc:
                extracted_text += page.get_text() + "\n"

        # 3) Imprimir fragmento del texto (debug)
        print("🔹 Fragmento del texto extraído:\n", extracted_text)

        # 4) Construir la solicitud a OpenRouter
        data = {
            "model": os.getenv('OPENROUTER_MODEL'),
            "messages": [
                {
                    "role": "system",
                    "content": SYSTEM_PROMPT
                },
                {
                    "role": "user",
                    "content": (
                        "Analiza este texto extraído de un manual de taller "
                        "y extrae los mantenimientos recomendados: La respuesta debe estar en ESPAÑOL independientemente del idioma del manual."
                        "Devuelve la respuesta en formato JSON con la estructura:\n"
                        "[{\"type\": \"tipo de mantenimiento\", \"recommended_interval_km\": numero, \"notes\": \"detalles opcionales\"}]. "
                        f"\n\nTexto del manual:\n{extracted_text}"
                    )
                }
            ]
        }

        # 5) Llamar a OpenRouter
        response = requests.post(
            os.getenv('OPENROUTER_URL'),
            headers=build_openrouter_headers(),
            data=json.dumps(data)
        )
        # Lanza excepción si la respuesta HTTP no es 200-299
        response.raise_for_status()

        # 6) Imprimir la respuesta cruda (debug)
        raw_content = response.text
        print("🔹 Respuesta cruda de OpenRouter:\n", raw_content)

        # 7) Procesar la respuesta
        result = response.json()

        # Sacar el content del asistente
        content = result["choices"][0]["message"]["content"]

        # Buscar un bloque de JSON entre ```json y ```
        pattern = r"```json(.*?)```"
        match = re.search(pattern, content, re.DOTALL)
        if match:
            # Extraer el bloque JSON
            json_block = match.group(1).strip()
            ai_response = json.loads(json_block)
        else:
            # Si no se encontró un bloque con triple backtick,
            # intentar parsear el content completo como JSON
            ai_response = json.loads(content)

        return {
            "vehicleId": vehicle_id,
            "maintenance_recommendations": ai_response
        }

    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=500, detail=f"Error en OpenRouter: {str(e)}")
    except json.JSONDecodeError:
        raise HTTPException(status_code=500, detail="Error al procesar la respuesta de OpenRouter: JSON inválido")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error inesperado: {str(e)}")

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
                # Conseguir el kilometraje actual y calcular el próximo cambio
                last_change_km = record["last_change_km"] + record["km_since_last_change"]
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
                    "notes": record.get("notes"),
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