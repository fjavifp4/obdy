from fastapi import APIRouter, HTTPException, Depends, status
from bson import ObjectId, errors as bson_errors
from typing import List, Optional
from datetime import datetime, timedelta
import math
import logging

from database import db
from schemas.trip import (
    TripCreate,
    TripResponse,
    TripUpdate,
    GpsPointBase
)
from routers.auth import get_current_user_data
from models.trip import Trip, GpsPoint

logger = logging.getLogger(__name__)
router = APIRouter()

# Función para obtener la hora actual en España (GMT+2)
def get_spain_datetime():
    # Obtener hora UTC y añadir offset de España (GMT+2)
    return datetime.utcnow() + timedelta(hours=2)

@router.post("", response_model=TripResponse, status_code=status.HTTP_201_CREATED)
async def create_trip(
    trip_data: TripCreate,
    current_user: dict = Depends(get_current_user_data)
):
    """Crear un nuevo viaje"""
    try:
        # --- CORRECCIÓN: Manejo de IDs y verificación de vehículo --- 
        try:
            vehicle_object_id = ObjectId(trip_data.vehicle_id)
            user_object_id = ObjectId(current_user["id"])
        except (bson_errors.InvalidId, TypeError) as e:
            logger.warning(f"Error de formato de ID al crear viaje: {e}")
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Formato de ID de vehículo o usuario inválido")
            
        # Verificar que el vehículo existe y pertenece al usuario
        vehicle = await db.db.vehicles.find_one({
            "_id": vehicle_object_id,
            "user_id": user_object_id 
        })
        
        if not vehicle:
            # Log específico para depuración
            logger.info(f"Intento de crear viaje fallido: Vehículo {vehicle_object_id} no encontrado para usuario {user_object_id}")
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Vehículo no encontrado o no pertenece al usuario"
            )
        # --- FIN CORRECCIÓN --- 
        
        spain_time = get_spain_datetime()
        
        new_trip = {
            "_id": ObjectId(),
            "user_id": user_object_id, # Usar ObjectId
            "vehicle_id": vehicle_object_id, # Usar ObjectId
            "start_time": spain_time,
            "distance_in_km": trip_data.distance_in_km,
            "fuel_consumption_liters": trip_data.fuel_consumption_liters,
            "average_speed_kmh": trip_data.average_speed_kmh,
            "duration_seconds": trip_data.duration_seconds,
            "is_active": True,
            "gps_points": [],
            "created_at": spain_time,
            "updated_at": spain_time,
        }
        
        await db.db.trips.insert_one(new_trip)
        
        # Actualizaciones de vehículo (simplificado para brevedad)
        if trip_data.distance_in_km > 0:
             await db.db.vehicles.update_one(
                 {"_id": vehicle_object_id},
                 {"$inc": {"current_kilometers": trip_data.distance_in_km}}
             )
             await db.db.vehicles.update_one(
                 {"_id": vehicle_object_id},
                 {"$inc": {"maintenance_records.$[].km_since_last_change": trip_data.distance_in_km}}
             )
        
        # Formatear respuesta
        response_data = {
             **new_trip, # Tomar datos base
             "id": str(new_trip["_id"]),
             "user_id": str(new_trip["user_id"]),
             "vehicle_id": str(new_trip["vehicle_id"]),
             "end_time": None # Asegurar que end_time es None
        }
        # Eliminar _id ya que tenemos id
        del response_data["_id"] 
        return TripResponse(**response_data) # Validar con Pydantic

    except HTTPException as http_exc:
        # Re-lanzar excepciones HTTP específicas (como el 404 de arriba)
        raise http_exc
    except Exception as e:
        # Capturar otros errores inesperados
        logger.error(f"Error inesperado al crear el viaje: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error interno al crear el viaje"
        )

@router.get("", response_model=List[TripResponse])
async def get_user_trips(
    vehicle_id: Optional[str] = None,
    limit: int = 20,
    current_user: dict = Depends(get_current_user_data)
):
    """Obtener todos los viajes del usuario, opcionalmente filtrar por vehículo"""
    try:
        # Filtro base: usuario actual
        filter_query = {"user_id": ObjectId(current_user["id"])}
        
        # Añadir filtro por vehículo si se proporciona
        if vehicle_id:
            filter_query["vehicle_id"] = ObjectId(vehicle_id)
        
        # Consultar viajes
        trips_cursor = db.db.trips.find(filter_query).sort("start_time", -1).limit(limit)
        trips = await trips_cursor.to_list(length=limit)
        
        # Transformar para respuesta
        result = []
        for trip in trips:
            result.append({
                "id": str(trip["_id"]),
                "user_id": str(trip["user_id"]),
                "vehicle_id": str(trip["vehicle_id"]),
                "start_time": trip["start_time"],
                "end_time": trip.get("end_time"),
                "distance_in_km": trip["distance_in_km"],
                "fuel_consumption_liters": trip["fuel_consumption_liters"],
                "average_speed_kmh": trip["average_speed_kmh"],
                "duration_seconds": trip["duration_seconds"],
                "is_active": trip["is_active"],
                "gps_points": trip.get("gps_points", []),
                "created_at": trip["created_at"],
                "updated_at": trip["updated_at"]
            })
        
        return result
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al obtener los viajes: {str(e)}"
        )

@router.get("/active", response_model=TripResponse)
async def get_active_trip(
    current_user: dict = Depends(get_current_user_data)
):
    """Obtener el viaje activo del usuario, si existe"""
    try:
        # Buscar viaje activo
        active_trip = await db.db.trips.find_one({
            "user_id": ObjectId(current_user["id"]),
            "is_active": True
        })
        
        if not active_trip:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No hay viajes activos"
            )
        
        # Transformar para respuesta
        return {
            "id": str(active_trip["_id"]),
            "user_id": str(active_trip["user_id"]),
            "vehicle_id": str(active_trip["vehicle_id"]),
            "start_time": active_trip["start_time"],
            "end_time": active_trip.get("end_time"),
            "distance_in_km": active_trip["distance_in_km"],
            "fuel_consumption_liters": active_trip["fuel_consumption_liters"],
            "average_speed_kmh": active_trip["average_speed_kmh"],
            "duration_seconds": active_trip["duration_seconds"],
            "is_active": active_trip["is_active"],
            "gps_points": active_trip.get("gps_points", []),
            "created_at": active_trip["created_at"],
            "updated_at": active_trip["updated_at"]
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al obtener el viaje activo: {str(e)}"
        )

@router.put("/{trip_id}", response_model=TripResponse)
async def update_trip(
    trip_id: str,
    trip_update: TripUpdate,
    current_user: dict = Depends(get_current_user_data)
):
    """Actualizar un viaje"""
    # Verificar que el viaje existe y pertenece al usuario
    trip = await db.db.trips.find_one({
        "_id": ObjectId(trip_id),
        "user_id": ObjectId(current_user["id"])
    })
    
    if not trip:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Viaje no encontrado"
        )
    
    # Crear diccionario con los campos a actualizar
    update_data = {}
    push_data = {} # Para añadir puntos GPS
    
    # Verificar cada campo opcional
    if trip_update.distance_in_km is not None:
        update_data["distance_in_km"] = trip_update.distance_in_km
        # Calcular la diferencia de kilómetros desde la última actualización
        distance_diff = trip_update.distance_in_km - trip.get("distance_in_km", 0.0)
        if distance_diff > 0:
            # Actualizar los kilómetros actuales del vehículo
            await db.db.vehicles.update_one(
                {"_id": ObjectId(trip["vehicle_id"])},
                {
                    "$inc": {
                        "current_kilometers": distance_diff
                    }
                }
            )
            
            # Actualizar los kilómetros desde el último cambio de cada mantenimiento
            await db.db.vehicles.update_one(
                {"_id": ObjectId(trip["vehicle_id"])},
                {
                    "$inc": {
                        "maintenance_records.$[].km_since_last_change": distance_diff
                    }
                }
            )
    
    if trip_update.fuel_consumption_liters is not None:
        update_data["fuel_consumption_liters"] = trip_update.fuel_consumption_liters
    
    if trip_update.average_speed_kmh is not None:
        update_data["average_speed_kmh"] = trip_update.average_speed_kmh
    
    if trip_update.duration_seconds is not None:
        update_data["duration_seconds"] = trip_update.duration_seconds
    
    if trip_update.end_time is not None:
        update_data["end_time"] = trip_update.end_time
    
    # Añadir puntos GPS si se proporcionan en la actualización
    if trip_update.gps_points is not None and len(trip_update.gps_points) > 0:
        # Convertir los puntos al formato adecuado para MongoDB
        points_data = [
            {
                "latitude": point.latitude,
                "longitude": point.longitude,
                "timestamp": point.timestamp
            }
            for point in trip_update.gps_points
        ]
        push_data["gps_points"] = {"$each": points_data}
        print(f"[Backend] Añadiendo {len(points_data)} puntos GPS en update periódico")
    
    if update_data or push_data:
        # Actualizar también la fecha de última actualización
        update_data["updated_at"] = get_spain_datetime()
        
        # Construir la operación de actualización final
        update_operation = {}
        if update_data:
            update_operation["$set"] = update_data
        if push_data:
            update_operation["$push"] = push_data
            
        # Actualizar el viaje
        result = await db.db.trips.update_one(
            {"_id": ObjectId(trip_id)},
            update_operation
        )
        
        # Verificar si algo se modificó (puede que solo se añadieran puntos)
        if result.modified_count == 0 and not push_data:
             # Si no hubo $set y no hubo $push, no se hizo nada
             # Opcionalmente, podrías devolver 304 Not Modified aquí, pero devolver el actual es más simple
             print(f"[Backend] Update periódico para {trip_id} no resultó en modificaciones.")
             pass # Continuar para devolver el estado actual
    
    # Obtener el viaje actualizado (después de $set y/o $push)
    updated_trip = await db.db.trips.find_one({"_id": ObjectId(trip_id)})
    
    # Transformar para respuesta
    return {
        "id": str(updated_trip["_id"]),
        "user_id": str(updated_trip["user_id"]),
        "vehicle_id": str(updated_trip["vehicle_id"]),
        "start_time": updated_trip["start_time"],
        "end_time": updated_trip.get("end_time"),
        "distance_in_km": updated_trip["distance_in_km"],
        "fuel_consumption_liters": updated_trip["fuel_consumption_liters"],
        "average_speed_kmh": updated_trip["average_speed_kmh"],
        "duration_seconds": updated_trip["duration_seconds"],
        "is_active": updated_trip["is_active"],
        "gps_points": updated_trip.get("gps_points", []),
        "created_at": updated_trip["created_at"],
        "updated_at": updated_trip["updated_at"]
    }

@router.post("/{trip_id}/gps-point")
async def add_gps_point(
    trip_id: str,
    gps_point: GpsPointBase,
    current_user: dict = Depends(get_current_user_data)
):
    """Añadir un punto GPS a un viaje existente"""
    try:
        # Verificar si el viaje existe y pertenece al usuario
        trip = await db.db.trips.find_one({
            "_id": ObjectId(trip_id),
            "user_id": ObjectId(current_user["id"])
        })
        
        if not trip:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Viaje no encontrado o no pertenece al usuario"
            )
        
        if not trip["is_active"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No se pueden añadir puntos GPS a un viaje finalizado"
            )
        
        # Crear punto GPS
        point_data = {
            "latitude": gps_point.latitude,
            "longitude": gps_point.longitude,
            "timestamp": gps_point.timestamp
        }
        
        # Añadir a la lista de puntos GPS
        await db.db.trips.update_one(
            {"_id": ObjectId(trip_id)},
            {
                "$push": {"gps_points": point_data},
                "$set": {"updated_at": get_spain_datetime()}
            }
        )
        
        return {"message": "Punto GPS añadido con éxito"}
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al añadir punto GPS: {str(e)}"
        )

@router.post("/{trip_id}/gps-points/batch", status_code=status.HTTP_200_OK)
async def add_gps_points_batch(
    trip_id: str,
    gps_points: List[GpsPointBase],
    current_user: dict = Depends(get_current_user_data)
):
    """Añadir múltiples puntos GPS a un viaje existente en una sola operación"""
    try:
        # Verificar si el viaje existe y pertenece al usuario
        trip = await db.db.trips.find_one({
            "_id": ObjectId(trip_id),
            "user_id": ObjectId(current_user["id"])
        })
        
        if not trip:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Viaje no encontrado o no pertenece al usuario"
            )
        
        if not trip["is_active"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No se pueden añadir puntos GPS a un viaje finalizado"
            )
        
        if len(gps_points) == 0:
            return {"message": "No se proporcionaron puntos GPS para añadir"}
        
        # Convertir los puntos al formato adecuado para MongoDB
        points_data = [
            {
                "latitude": point.latitude,
                "longitude": point.longitude,
                "timestamp": point.timestamp
            }
            for point in gps_points
        ]
        
        # Añadir todos los puntos a la lista de puntos GPS
        await db.db.trips.update_one(
            {"_id": ObjectId(trip_id)},
            {
                "$push": {"gps_points": {"$each": points_data}},
                "$set": {"updated_at": get_spain_datetime()}
            }
        )
        
        return {"message": f"Se añadieron {len(points_data)} puntos GPS con éxito"}
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al añadir puntos GPS: {str(e)}"
        )

@router.delete("/{trip_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_trip(
    trip_id: str,
    current_user: dict = Depends(get_current_user_data)
):
    """Eliminar un viaje"""
    try:
        # Verificar si el viaje existe y pertenece al usuario
        trip = await db.db.trips.find_one({
            "_id": ObjectId(trip_id),
            "user_id": ObjectId(current_user["id"])
        })
        
        if not trip:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Viaje no encontrado o no pertenece al usuario"
            )
        
        # Eliminar el viaje
        await db.db.trips.delete_one({"_id": ObjectId(trip_id)})
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al eliminar el viaje: {str(e)}"
        )

@router.get("/vehicle/{vehicle_id}/stats")
async def get_vehicle_trip_stats(
    vehicle_id: str,
    current_user: dict = Depends(get_current_user_data)
):
    """Obtener estadísticas de viajes para un vehículo específico"""
    try:
        # Verificar si el vehículo existe y pertenece al usuario
        vehicle = await db.db.vehicles.find_one({
            "_id": ObjectId(vehicle_id),
            "user_id": ObjectId(current_user["id"])
        })
        
        if not vehicle:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Vehículo no encontrado o no pertenece al usuario"
            )
        
        # Obtener todos los viajes para este vehículo (incluyendo activos)
        pipeline = [
            {"$match": {
                "vehicle_id": ObjectId(vehicle_id),
                "user_id": ObjectId(current_user["id"])
            }},
            {"$group": {
                "_id": None,
                "total_trips": {"$sum": 1},
                "total_distance": {"$sum": "$distance_in_km"},
                "total_fuel": {"$sum": "$fuel_consumption_liters"},
                "total_duration": {"$sum": "$duration_seconds"},
                "avg_speed": {"$avg": "$average_speed_kmh"}
            }}
        ]
        
        result = await db.db.trips.aggregate(pipeline).to_list(length=1)
        
        # Si no hay resultados, devolver estadísticas vacías
        if not result:
            return {
                "total_trips": 0,
                "total_distance_km": 0,
                "total_fuel_consumption_liters": 0,
                "total_duration_seconds": 0,
                "average_speed_kmh": 0,
                "average_fuel_economy_km_per_liter": 0
            }
        
        stats = result[0]
        
        # Calcular economía de combustible
        fuel_economy = 0
        if stats.get("total_fuel", 0) > 0:
            fuel_economy = stats.get("total_distance", 0) / stats.get("total_fuel", 1)
        
        return {
            "total_trips": stats.get("total_trips", 0),
            "total_distance_km": stats.get("total_distance", 0),
            "total_fuel_consumption_liters": stats.get("total_fuel", 0),
            "total_duration_seconds": stats.get("total_duration", 0),
            "average_speed_kmh": stats.get("avg_speed", 0),
            "average_fuel_economy_km_per_liter": fuel_economy
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al obtener estadísticas: {str(e)}"
        )

@router.put("/{trip_id}/end", status_code=status.HTTP_200_OK)
async def end_trip(
    trip_id: str,
    current_user: dict = Depends(get_current_user_data)
):
    """Finalizar un viaje específico"""
    try:
        # Verificar si el viaje existe y pertenece al usuario
        trip = await db.db.trips.find_one({
            "_id": ObjectId(trip_id),
            "user_id": ObjectId(current_user["id"])
        })
        
        if not trip:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Viaje no encontrado o no pertenece al usuario"
            )
        
        if not trip["is_active"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="El viaje ya está finalizado"
            )
        
        # Usar la hora de España para el fin del viaje
        end_time = get_spain_datetime()
        start_time = trip["start_time"]
        
        # Calcular duración final (en segundos)
        duration_seconds = int((end_time - start_time).total_seconds())
        
        # Actualizar el viaje
        result = await db.db.trips.update_one(
            {"_id": ObjectId(trip_id)},
            {
                "$set": {
                    "is_active": False,
                    "end_time": end_time,  # Usar hora de España
                    "duration_seconds": duration_seconds,
                    "updated_at": end_time  # Usar hora de España
                }
            }
        )
        
        if result.modified_count == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No se pudo finalizar el viaje"
            )
        
        # Obtener el viaje actualizado
        updated_trip = await db.db.trips.find_one({"_id": ObjectId(trip_id)})
        
        return {
            "id": str(updated_trip["_id"]),
            "user_id": str(updated_trip["user_id"]),
            "vehicle_id": str(updated_trip["vehicle_id"]),
            "start_time": updated_trip["start_time"],
            "end_time": updated_trip["end_time"],
            "distance_in_km": updated_trip["distance_in_km"],
            "fuel_consumption_liters": updated_trip["fuel_consumption_liters"],
            "average_speed_kmh": updated_trip["average_speed_kmh"],
            "duration_seconds": updated_trip["duration_seconds"],
            "is_active": updated_trip["is_active"],
            "gps_points": updated_trip.get("gps_points", []),
            "created_at": updated_trip["created_at"],
            "updated_at": updated_trip["updated_at"]
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al finalizar el viaje: {str(e)}"
        ) 