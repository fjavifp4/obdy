from fastapi import APIRouter, HTTPException, Depends, status, Query
from bson import ObjectId
from typing import List, Optional, Dict
from datetime import datetime
import math
import random
import httpx
import logging
from pydantic import BaseModel
import json
import unicodedata

from database import db
from schemas.fuel import (
    FuelPrices,
    FuelStationResponse,
    FuelStationList,
    FavoriteStationAdd,
    NearbyStationsParams
)
from models.fuel import FuelStation
from routers.auth import get_current_user_data

router = APIRouter()

# URL de la API del Ministerio
MINISTERIO_API_URL = "https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes/EstacionesTerrestres/"

# Configuración del logger
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Mapeo de tipos de combustible de la API del Ministerio a nuestros tipos
FUEL_TYPE_MAPPING = {
    "Precio Gasolina 95 E5": "gasolina95",
    "Precio Gasolina 98 E5": "gasolina98",
    "Precio Gasoleo A": "diesel",
    "Precio Gasoleo Premium": "dieselPlus",
    "Precio Gasoleo B": "gasoleoB",
    "Precio Gasoleo C": "gasoleoC",
    "Precio Bioetanol": "bioetanol",
    "Precio Gases licuados del petróleo": "glp",
    "Precio Gas Natural Comprimido": "gnc",
    "Precio Gas Natural Licuado": "gnl",
    "Precio Hidrogeno": "hidrogeno"
}

# Caché para almacenar datos y reducir llamadas a la API
cache = {
    "all_stations": None,
    "general_prices": None,
    "last_update": None
}

def _normalize_text(text):
    """Normaliza un texto para corregir problemas de codificación de caracteres españoles"""
    if not text:
        return ""
    
    try:
        # Intento de decodificación/codificación
        try:
            text = text.encode('latin1').decode('utf-8')
        except Exception:
            pass
        
        # Normalización unicode - esto maneja la conversión de caracteres compuestos a simples
        text = unicodedata.normalize('NFC', text)
        
        # Reemplazos manuales para casos específicos - usando escape codes Unicode para evitar problemas
        # Ã + ...[combinación] que representan caracteres latinos
        text = text.replace('\u00c3\u0081', 'Á')  # Ã+Á -> Á
        text = text.replace('\u00c3\u0089', 'É')  # Ã+É -> É
        text = text.replace('\u00c3\u008d', 'Í')  # Ã+Í -> Í
        text = text.replace('\u00c3\u0093', 'Ó')  # Ã+Ó -> Ó
        text = text.replace('\u00c3\u00ba', 'ú')  # Ã+ú -> ú
        text = text.replace('\u00c3\u00b3', 'ó')  # Ã+ó -> ó
        text = text.replace('\u00c3\u00a1', 'á')  # Ã+á -> á
        text = text.replace('\u00c3\u00ad', 'í')  # Ã+í -> í
        text = text.replace('\u00c3\u00a9', 'é')  # Ã+é -> é
        text = text.replace('\u00c3\u00b1', 'ñ')  # Ã+ñ -> ñ
        text = text.replace('\u00c3\u0091', 'Ñ')  # Ã+Ñ -> Ñ
        
        # Reemplazar múltiples espacios por uno solo
        text = ' '.join(text.split())
        
    except Exception:
        # En caso de error, devolver el texto original
        pass
    
    return text

async def _fetch_all_stations():
    """Obtiene todas las estaciones de la API del Ministerio"""
    if cache["all_stations"] and cache["last_update"]:
        # Si hay datos en caché y se actualizaron hace menos de 6 horas, usar la caché
        time_diff = (datetime.now() - cache["last_update"]).total_seconds() / 3600
        if time_diff < 6:
            logger.info(f"Usando datos en caché (actualizados hace {time_diff:.1f} horas)")
            return cache["all_stations"]
    
    try:
        logger.info("Obteniendo datos de la API del Ministerio")
        async with httpx.AsyncClient() as client:
            response = await client.get(MINISTERIO_API_URL)
            if response.status_code != 200:
                logger.error(f"Error al obtener datos: {response.status_code}")
                # Si hay error pero tenemos caché, usar la caché aunque esté desactualizada
                if cache["all_stations"]:
                    return cache["all_stations"]
                raise HTTPException(status_code=503, detail="Error al obtener datos de la API del Ministerio")
            
            data = response.json()
            
            # Procesar los datos y convertirlos a nuestro formato
            stations = []
            
            # Verificación básica de la estructura de la respuesta
            if "ListaEESSPrecio" not in data or not data["ListaEESSPrecio"]:
                logger.error("No se encontraron estaciones en la respuesta de la API")
                if cache["all_stations"]:
                    return cache["all_stations"]
                return []
            
            # Contador para estaciones procesadas y errores
            processed = 0
            errors = 0
            
            for item in data.get("ListaEESSPrecio", []):
                try:
                    # Procesar precios
                    prices = {}
                    for key, value in item.items():
                        if key in FUEL_TYPE_MAPPING and value:
                            try:
                                # Convertir de formato español (coma decimal) a float
                                price_str = value.replace(",", ".")
                                prices[FUEL_TYPE_MAPPING[key]] = float(price_str)
                            except (ValueError, AttributeError):
                                continue
                    
                    # Solo incluir estaciones con al menos un precio
                    if prices:
                        # Convertir coordenadas correctamente (en España usan coma como separador decimal)
                        lat_str = item.get("Latitud", "0").replace(",", ".")
                        lng_str = item.get("Longitud (WGS84)", "0").replace(",", ".")
                        
                        # Verificar que tenemos coordenadas válidas
                        if lat_str == "0" or lng_str == "0":
                            errors += 1
                            continue
                        
                        try:
                            latitude = float(lat_str)
                            longitude = float(lng_str)
                        except ValueError:
                            errors += 1
                            continue
                        
                        # Crear un ID único basado en el IDEESS
                        station_id = item.get("IDEESS", "")
                        if not station_id:
                            station_id = str(ObjectId())
                        
                        # Aplicar normalización a todos los campos de texto
                        address = _normalize_text(item.get("Dirección", ""))
                        postal_code = item.get("C.P.", "")
                        city = _normalize_text(item.get("Localidad", ""))
                        province = _normalize_text(item.get("Provincia", ""))
                        brand = _normalize_text(item.get("Rótulo", "Sin marca"))
                        schedule = _normalize_text(item.get("Horario", ""))
                        
                        # Asegurar que el nombre es identificable
                        station_name = _normalize_text(f"{brand} {city}").strip()
                        if not station_name:
                            station_name = "Estación " + station_id
                        
                        # Construir la estación con los campos correctos
                        station = {
                            "id": station_id,
                            "name": station_name,
                            "brand": brand,
                            "latitude": latitude,
                            "longitude": longitude,
                            "address": address,
                            "city": city,
                            "province": province,
                            "postal_code": postal_code,
                            "schedule": schedule,
                            "prices": prices,
                            "last_updated": datetime.now()
                        }
                        
                        # Verificar que las coordenadas sean válidas y estén en un rango razonable
                        if -90 <= latitude <= 90 and -180 <= longitude <= 180 and latitude != 0 and longitude != 0:
                            stations.append(station)
                            processed += 1
                        else:
                            errors += 1
                except Exception:
                    errors += 1
                    continue
            
            logger.info(f"Datos procesados: {processed} estaciones correctas, {errors} ignoradas")
            
            # Guardar en caché
            cache["all_stations"] = stations
            cache["last_update"] = datetime.now()
            
            return stations
    except Exception as e:
        logger.error(f"Error general obteniendo estaciones: {e}")
        if cache["all_stations"]:
            return cache["all_stations"]
        raise HTTPException(status_code=503, detail=f"Error al obtener datos: {str(e)}")

async def _calculate_general_prices():
    """Calcula los precios medios generales"""
    if cache["general_prices"] and cache["last_update"]:
        time_diff = (datetime.now() - cache["last_update"]).total_seconds() / 3600
        if time_diff < 6:
            return cache["general_prices"]
    
    stations = await _fetch_all_stations()
    
    # Calcular precios medios
    price_counts = {}
    price_sums = {}
    
    for station in stations:
        for fuel_type, price in station["prices"].items():
            if fuel_type not in price_sums:
                price_sums[fuel_type] = 0
                price_counts[fuel_type] = 0
            
            price_sums[fuel_type] += price
            price_counts[fuel_type] += 1
    
    # Calcular medias
    general_prices = {}
    for fuel_type in price_sums:
        if price_counts[fuel_type] > 0:
            general_prices[fuel_type] = round(price_sums[fuel_type] / price_counts[fuel_type], 3)
    
    # Actualizar caché
    cache["general_prices"] = general_prices
    
    return general_prices

@router.get("/prices", response_model=FuelPrices)
async def get_fuel_prices(current_user: dict = Depends(get_current_user_data)):
    """Obtiene los precios medios generales de combustible"""
    try:
        prices = await _calculate_general_prices()
        return {"prices": prices}
    except Exception as e:
        logger.error(f"Error al obtener precios generales: {e}")
        raise HTTPException(status_code=503, detail=f"Error al obtener precios generales: {str(e)}")

@router.get("/stations/nearby", response_model=FuelStationList)
async def get_nearby_stations(
    lat: float = Query(..., description="Latitud"),
    lng: float = Query(..., description="Longitud"),
    radius: float = Query(5.0, description="Radio de búsqueda en km"),
    fuel_type: Optional[str] = Query(None, description="Tipo de combustible"),
    current_user: dict = Depends(get_current_user_data)
):
    """Obtiene las estaciones de combustible cercanas a una ubicación"""
    try:
        logger.info(f"Buscando estaciones cercanas en radio {radius}km")
        
        # Obtener todas las estaciones
        all_stations = await _fetch_all_stations()
        
        # Obtener favoritos del usuario
        user_id = ObjectId(current_user["id"])
        user_favorites = await db.db.favorite_stations.find({"user_id": user_id}).to_list(None)
        favorite_ids = [str(fav["station_id"]) for fav in user_favorites]
        
        # Filtrar estaciones dentro del radio
        nearby_stations = []
        for station in all_stations:
            # Verificar que la estación tiene coordenadas válidas
            if (station.get("latitude") is None or station.get("longitude") is None or 
                station["latitude"] == 0.0 or station["longitude"] == 0.0):
                continue
                
            # Calcular distancia
            try:
                distance = _calculate_distance(lat, lng, station["latitude"], station["longitude"])
                
                # Si está dentro del radio, añadir a la lista
                if distance <= radius:
                    # Si se especifica tipo de combustible, verificar que la estación lo tenga
                    if fuel_type and fuel_type not in station.get("prices", {}):
                        continue
                    
                    # Crear copia con información adicional
                    station_copy = station.copy()
                    station_copy["distance"] = round(distance, 2)
                    station_copy["is_favorite"] = station_copy["id"] in favorite_ids
                    
                    nearby_stations.append(station_copy)
            except Exception as e:
                logger.warning(f"Error al calcular distancia: {e}")
                continue
        
        # Ordenar por distancia
        nearby_stations.sort(key=lambda x: x.get("distance", float('inf')))
        
        # Convertir a objetos FuelStationResponse
        try:
            fuel_stations = []
            for station in nearby_stations:
                try:
                    fuel_stations.append(FuelStationResponse(**station))
                except Exception as e:
                    logger.warning(f"Error convirtiendo estación: {e}")
        except Exception as e:
            logger.error(f"Error al convertir estaciones: {e}")
            # Si falla la conversión, devolver directamente la lista de diccionarios
            return {"stations": nearby_stations}
        
        # Devolver el resultado
        return {"stations": fuel_stations}
    except Exception as e:
        logger.error(f"Error al obtener estaciones cercanas: {e}")
        # Incluir más detalles en el log para ayudar a diagnosticar el problema
        import traceback
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=503, detail=f"Error al obtener estaciones cercanas: {e}")

@router.get("/stations/favorites", response_model=FuelStationList)
async def get_favorite_stations(current_user: dict = Depends(get_current_user_data)):
    """Obtiene las estaciones favoritas del usuario"""
    try:
        user_id = ObjectId(current_user["id"])
        
        # Obtener IDs de favoritos
        favorites = await db.db.favorite_stations.find({"user_id": user_id}).to_list(None)
        favorite_ids = [str(fav["station_id"]) for fav in favorites]
        
        if not favorite_ids:
            return {"stations": []}
        
        # Obtener todas las estaciones
        all_stations = await _fetch_all_stations()
        
        # Filtrar las favoritas
        favorite_stations = []
        for station in all_stations:
            if station["id"] in favorite_ids:
                station_copy = dict(station)
                station_copy["is_favorite"] = True
                favorite_stations.append(station_copy)
        
        # Convertir a objetos FuelStationResponse con manejo de errores
        try:
            fuel_stations = []
            for station in favorite_stations:
                try:
                    fuel_stations.append(FuelStationResponse(**station))
                except Exception as e:
                    logger.warning(f"Error convirtiendo estación favorita: {e}")
        except Exception as e:
            logger.error(f"Error al convertir estaciones favoritas: {e}")
            # Si falla la conversión, devolver directamente la lista de diccionarios
            return {"stations": favorite_stations}
        
        return {"stations": fuel_stations}
    except Exception as e:
        logger.error(f"Error al obtener estaciones favoritas: {e}")
        # Incluir más detalles en el log para ayudar a diagnosticar el problema
        import traceback
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=503, detail=f"Error al obtener estaciones favoritas: {e}")

@router.post("/stations/favorites", status_code=status.HTTP_201_CREATED)
async def add_favorite_station(
    favorite: FavoriteStationAdd,
    current_user: dict = Depends(get_current_user_data)
):
    """Añade una estación a favoritos"""
    try:
        user_id = ObjectId(current_user["id"])
        station_id = favorite.station_id
        
        # Verificar si ya es favorita
        existing = await db.db.favorite_stations.find_one({
            "user_id": user_id,
            "station_id": station_id
        })
        
        if existing:
            return {"message": "La estación ya está en favoritos"}
        
        # Añadir a favoritos
        result = await db.db.favorite_stations.insert_one({
            "user_id": user_id,
            "station_id": station_id,
            "created_at": datetime.now()
        })
        
        if not result.inserted_id:
            raise HTTPException(status_code=500, detail="Error al añadir a favoritos")
        
        return {"message": "Estación añadida a favoritos"}
    except Exception as e:
        logger.error(f"Error al añadir favorito: {e}")
        raise HTTPException(status_code=503, detail=f"Error al añadir a favoritos: {str(e)}")

@router.delete("/stations/favorites/{station_id}", status_code=status.HTTP_200_OK)
async def remove_favorite_station(
    station_id: str,
    current_user: dict = Depends(get_current_user_data)
):
    """Elimina una estación de favoritos"""
    try:
        user_id = ObjectId(current_user["id"])
        
        result = await db.db.favorite_stations.delete_one({
            "user_id": user_id,
            "station_id": station_id
        })
        
        if result.deleted_count == 0:
            return {"message": "La estación no estaba en favoritos"}
        
        return {"message": "Estación eliminada de favoritos"}
    except Exception as e:
        logger.error(f"Error al eliminar favorito: {e}")
        raise HTTPException(status_code=503, detail=f"Error al eliminar de favoritos: {str(e)}")

@router.get("/stations/{station_id}", response_model=FuelStationResponse)
async def get_station_details(
    station_id: str,
    current_user: dict = Depends(get_current_user_data)
):
    """Obtiene los detalles de una estación"""
    try:
        # Obtener todas las estaciones
        all_stations = await _fetch_all_stations()
        
        # Buscar la estación por ID
        station = next((s for s in all_stations if s["id"] == station_id), None)
        
        if not station:
            raise HTTPException(status_code=404, detail="Estación no encontrada")
        
        # Verificar si es favorita
        user_id = ObjectId(current_user["id"])
        is_favorite = await db.db.favorite_stations.find_one({
            "user_id": user_id,
            "station_id": station_id
        })
        
        station_copy = dict(station)
        station_copy["is_favorite"] = bool(is_favorite)
        
        # Convertir a objeto FuelStation
        fuel_station = FuelStation.from_dict(station_copy)
        
        return fuel_station
    except Exception as e:
        logger.error(f"Error al obtener detalles de estación: {e}")
        raise HTTPException(status_code=503, detail=f"Error al obtener detalles: {str(e)}")

@router.get("/stations/search", response_model=FuelStationList)
async def search_stations(
    query: str = Query(..., description="Término de búsqueda"),
    current_user: dict = Depends(get_current_user_data)
):
    """Busca estaciones por nombre, marca o dirección"""
    try:
        # Obtener todas las estaciones
        all_stations = await _fetch_all_stations()
        
        # Filtrar por término de búsqueda
        query = query.lower()
        matched_stations = []
        
        # Obtener favoritos del usuario
        user_id = ObjectId(current_user["id"])
        user_favorites = await db.db.favorite_stations.find({"user_id": user_id}).to_list(None)
        favorite_ids = [str(fav["station_id"]) for fav in user_favorites]
        
        for station in all_stations:
            if (query in station["name"].lower() or 
                query in station["brand"].lower() or 
                query in station["address"].lower() or 
                query in station["city"].lower()):
                
                station_copy = dict(station)
                station_copy["is_favorite"] = station["id"] in favorite_ids
                matched_stations.append(station_copy)
        
        # Convertir a objetos FuelStation
        fuel_stations = [
            FuelStation.from_dict(station) for station in matched_stations[:50]  # Limitar a 50 resultados
        ]
        
        return {"stations": fuel_stations}
    except Exception as e:
        logger.error(f"Error en búsqueda de estaciones: {e}")
        raise HTTPException(status_code=503, detail=f"Error en búsqueda: {str(e)}")

def _calculate_distance(lat1, lon1, lat2, lon2):
    """Calcula la distancia en km entre dos coordenadas"""
    R = 6371  # Radio de la Tierra en km
    
    # Convertir a radianes
    lat1_rad = math.radians(lat1)
    lon1_rad = math.radians(lon1)
    lat2_rad = math.radians(lat2)
    lon2_rad = math.radians(lon2)
    
    # Diferencia de coordenadas
    dlon = lon2_rad - lon1_rad
    dlat = lat2_rad - lat1_rad
    
    # Fórmula de Haversine
    a = math.sin(dlat/2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    distance = R * c
    
    return distance 