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
import asyncio
import subprocess
import sys
import os
import traceback

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

# Ruta al archivo de datos precargados
PRELOADED_DATA_PATH = os.path.join(os.path.dirname(__file__), "../data/estaciones_backup.json")

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

class NearbyStationsParams:
    def __init__(
        self,
        lat: float = Query(..., description="Latitud"),
        lng: float = Query(..., description="Longitud"),
        radius: float = Query(5.0, description="Radio de búsqueda en km"),
        fuel_type: Optional[str] = Query(None, description="Tipo de combustible")
    ):
        self.lat = lat
        self.lng = lng
        self.radius = radius
        self.fuel_type = fuel_type

def _normalize_text(text):
    """Normaliza un texto para corregir problemas de codificación de caracteres españoles"""
    if not text:
        return ""
    
    try:
        # Normalización unicode - esto maneja la conversión de caracteres compuestos a simples
        text = unicodedata.normalize('NFC', text)
        
        # Reemplazar múltiples espacios por uno solo
        text = ' '.join(text.split())
        
    except Exception:
        # En caso de error, devolver el texto original
        pass
    
    return text

def _load_preloaded_data():
    """Carga datos precargados desde un archivo JSON de respaldo"""
    try:
        if os.path.exists(PRELOADED_DATA_PATH):
            logger.info(f"Intentando cargar datos precargados desde {PRELOADED_DATA_PATH}")
            with open(PRELOADED_DATA_PATH, 'rb') as f:
                content = f.read()
                
            # Intentar diferentes codificaciones
            for encoding in ['utf-8', 'latin1', 'iso-8859-15']:
                try:
                    content_text = content.decode(encoding)
                    data = json.loads(content_text)
                    logger.info(f"Datos precargados cargados correctamente con codificación {encoding}")
                    return data
                except (UnicodeDecodeError, json.JSONDecodeError):
                    continue
                    
            logger.error("No se pudieron decodificar los datos precargados con ninguna codificación")
        else:
            logger.error(f"Archivo de datos precargados no encontrado en {PRELOADED_DATA_PATH}")
    except Exception as e:
        logger.error(f"Error al cargar datos precargados: {str(e)}")
    
    return None

def _save_data_backup(data):
    """Guarda los datos obtenidos como respaldo para futuras ejecuciones"""
    try:
        if data and "ListaEESSPrecio" in data and isinstance(data["ListaEESSPrecio"], list):
            logger.info(f"Guardando datos de respaldo con {len(data['ListaEESSPrecio'])} estaciones")
            
            # Asegurar que el directorio existe
            os.makedirs(os.path.dirname(PRELOADED_DATA_PATH), exist_ok=True)
            
            # Guardar datos en formato JSON
            with open(PRELOADED_DATA_PATH, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
                
            logger.info(f"Datos de respaldo guardados en {PRELOADED_DATA_PATH}")
            return True
        else:
            logger.warning("No se pudieron guardar datos de respaldo: estructura de datos inválida")
            return False
    except Exception as e:
        logger.error(f"Error al guardar datos de respaldo: {str(e)}")
        return False

async def _fetch_with_curl():
    """Obtiene datos utilizando curl como sistema alternativo"""
    try:
        logger.info("Intentando obtener datos con curl")
        
        # Usar un archivo temporal para evitar problemas de codificación
        temp_file = "temp_api_response.json"
        
        if sys.platform.startswith('win'):
            # En Windows
            command = f'curl -s -k "{MINISTERIO_API_URL}" -o {temp_file}'
            logger.info(f"Ejecutando comando: {command}")
            result = subprocess.run(command, shell=True, capture_output=True)
        else:
            # En Unix/Linux
            command = ["curl", "-s", "-k", MINISTERIO_API_URL, "-o", temp_file]
            result = subprocess.run(command, capture_output=True)
        
        # Verificar si el comando tuvo éxito
        if result.returncode == 0 and os.path.exists(temp_file):
            # Leer el archivo en modo binario
            with open(temp_file, 'rb') as f:
                content = f.read()
            
            # Limpiar el archivo temporal
            try:
                os.remove(temp_file)
            except Exception:
                pass
            
            # Intentar diferentes codificaciones
            for encoding in ['utf-8', 'latin1', 'iso-8859-15']:
                try:
                    content_text = content.decode(encoding)
                    data = json.loads(content_text)
                    logger.info(f"Datos obtenidos con curl y decodificados con {encoding}")
                    return data
                except UnicodeDecodeError:
                    continue
                except json.JSONDecodeError:
                    continue
            
            logger.error("No se pudo decodificar la respuesta de curl con ninguna codificación")
        else:
            logger.error(f"Error ejecutando curl: {result.stderr}")
    
    except Exception as e:
        logger.error(f"Error al obtener datos con curl: {str(e)}")
    
    return None

async def _fetch_all_stations():
    """Obtiene todas las estaciones de la API del Ministerio"""
    # 1. Verificar caché reciente
    if cache["all_stations"] and cache["last_update"]:
        time_diff = (datetime.now() - cache["last_update"]).total_seconds() / 3600
        if time_diff < 6:
            logger.info(f"Usando datos en caché (actualizados hace {time_diff:.1f} horas)")
            return cache["all_stations"]
    
    # Mantener referencia a datos válidos anteriores
    last_valid_data = cache["all_stations"]
    
    # Definir orden de métodos para obtener datos
    response_data = None
    success = False
    
    try:
        logger.info("Obteniendo datos de la API del Ministerio")
        
        # 2. Intentar con httpx
        try:
            # Configuración para HTTPX
            httpx_config = {
                'timeout': httpx.Timeout(120.0, connect=60.0),
                'verify': False,
                'follow_redirects': True,
                'http2': False
            }
            
            # Headers que simulan un navegador
            headers = {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
                "Accept": "application/json, text/plain, */*",
                "Accept-Language": "es-ES,es;q=0.9,en;q=0.8",
                "Connection": "keep-alive"
            }
            
            logger.info(f"Intentando obtener datos de: {MINISTERIO_API_URL}")
            
            async with httpx.AsyncClient(**httpx_config) as client:
                # Realizar hasta 2 intentos
                for attempt in range(2):
                    try:
                        logger.info(f"Intento {attempt+1}/2 con httpx")
                        response = await client.get(MINISTERIO_API_URL, headers=headers)
                        
                        if response.status_code == 200:
                            try:
                                response_data = response.json()
                                success = True
                                logger.info("Datos obtenidos correctamente con httpx")
                                break
                            except Exception as e:
                                logger.warning(f"Error al procesar JSON con httpx: {str(e)}")
                        else:
                            logger.warning(f"Error de respuesta: {response.status_code}")
                            
                    except Exception as e:
                        logger.warning(f"Error de conexión con httpx: {str(e)}")
                    
                    # Esperar antes del siguiente intento
                    if attempt < 1:
                        await asyncio.sleep(2)
            
        except Exception as e:
            logger.error(f"Error general con httpx: {str(e)}")
            
        # 3. Si httpx falló, intentar con curl
        if not success:
            logger.info("Intentando obtener datos con curl como alternativa")
            response_data = await _fetch_with_curl()
            if response_data:
                success = True
                logger.info("Datos obtenidos correctamente con curl")
        
        # 4. Si curl falló, cargar datos precargados
        if not success:
            logger.info("Intentando cargar datos precargados")
            response_data = _load_preloaded_data()
            if response_data:
                success = True
                logger.info("Datos precargados cargados correctamente")
        
        # 5. Si todo falló, usar caché antigua como último recurso
        if not success:
            if last_valid_data:
                logger.warning("Usando caché antigua como último recurso")
                return last_valid_data
            else:
                raise HTTPException(
                    status_code=503,
                    detail="No se pudieron obtener datos de ninguna fuente"
                )
        
        # Verificar estructura básica
        if not response_data or "ListaEESSPrecio" not in response_data:
            logger.error("Estructura de datos inválida")
            if last_valid_data:
                return last_valid_data
            raise HTTPException(
                status_code=503,
                detail="Estructura de datos inválida"
            )
        
        # Guardar como respaldo para futuros usos
        if success:
            _save_data_backup(response_data)
        
        # Procesar los datos
        stations = []
        lista_estaciones = response_data.get("ListaEESSPrecio", [])
        
        if not lista_estaciones:
            logger.warning("No se encontraron estaciones en la respuesta")
            if last_valid_data:
                return last_valid_data
            return []
        
        # Procesar estaciones
        processed = 0
        errors = 0
        
        for item in lista_estaciones:
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
                    # Convertir coordenadas
                    lat_str = item.get("Latitud", "0").replace(",", ".")
                    
                    # Hay dos formas posibles del campo de longitud
                    if "Longitud (WGS84)" in item:
                        lng_str = item.get("Longitud (WGS84)", "0").replace(",", ".")
                    else:
                        lng_str = item.get("Longitud", "0").replace(",", ".")
                    
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
                    
                    # Normalizar campos de texto
                    address = _normalize_text(item.get("Dirección", ""))
                    postal_code = item.get("C.P.", "")
                    city = _normalize_text(item.get("Localidad", ""))
                    province = _normalize_text(item.get("Provincia", ""))
                    brand = _normalize_text(item.get("Rótulo", "Sin marca"))
                    schedule = _normalize_text(item.get("Horario", ""))
                    
                    # Verificar campos obligatorios
                    if not city and not address:
                        errors += 1
                        continue
                    
                    # Construir nombre de estación
                    station_name = _normalize_text(f"{brand} {city}").strip()
                    if not station_name:
                        station_name = "Estación " + station_id
                    
                    # Construir objeto estación
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
                        "last_updated": datetime.now(),
                        # Campos adicionales para búsquedas
                        "nombre": station_name,
                        "localidad": city,
                        "provincia": province,
                        "municipio": city,
                    }
                    
                    # Verificar coordenadas válidas
                    if -90 <= latitude <= 90 and -180 <= longitude <= 180 and latitude != 0 and longitude != 0:
                        stations.append(station)
                        processed += 1
                    else:
                        errors += 1
                        
            except Exception as e:
                logger.error(f"Error al procesar estación: {str(e)}")
                errors += 1
                continue
        
        logger.info(f"Datos procesados: {processed} estaciones correctas, {errors} ignoradas")
        
        if processed == 0:
            logger.error("No se pudo procesar ninguna estación correctamente")
            if last_valid_data:
                return last_valid_data
            raise HTTPException(
                status_code=503,
                detail="No se pudo procesar ninguna estación correctamente"
            )
        
        # Guardar en caché
        cache["all_stations"] = stations
        cache["last_update"] = datetime.now()
        
        return stations
    except Exception as e:
        logger.error(f"Error general obteniendo estaciones: {str(e)}")
        if last_valid_data:
            logger.warning("Usando datos en caché después de error")
            return last_valid_data
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
    params: NearbyStationsParams = Depends(),
    current_user: dict = Depends(get_current_user_data)
):
    """Obtiene estaciones cercanas a una coordenada"""
    try:
        logger.info(f"Buscando estaciones cercanas en radio {params.radius}km")
        logger.info(f"Coordenadas: {params.lat}, {params.lng}")
        
        # Intentar obtener los datos, respetando errores que puedan ocurrir
        try:
            all_stations = await _fetch_all_stations()
        except HTTPException as e:
            if e.status_code == 503 and cache["all_stations"]:
                # Si hay error de conexión pero tenemos caché, usar la caché
                logger.warning("Usando datos en caché para buscar estaciones cercanas después de error")
                all_stations = cache["all_stations"]
            else:
                # Si no hay caché o es otro tipo de error, propagar la excepción
                logger.error(f"Error al obtener estaciones cercanas: {str(e)}")
                raise HTTPException(status_code=503, detail=f"Error al obtener estaciones cercanas: {str(e)}")
        
        # Verificar que tenemos datos
        if not all_stations:
            logger.error("No hay estaciones disponibles")
            raise HTTPException(status_code=404, detail="No hay estaciones disponibles")
        
        # Registrar cantidad de estaciones totales para diagnóstico
        logger.info(f"Procesando {len(all_stations)} estaciones")
        
        # Procesar las estaciones cercanas
        try:
            nearby_stations_result = _process_nearby_stations(
                all_stations, 
                params.lat, 
                params.lng, 
                params.radius, 
                params.fuel_type
            )
            
            # Verificar que tenemos estaciones
            stations = nearby_stations_result.get("stations", [])
            if not stations:
                logger.info(f"No se encontraron estaciones en radio de {params.radius}km")
                return FuelStationList(stations=[])
            
            # Obtener favoritos del usuario
            user_id = ObjectId(current_user["id"])
            user_favorites = await db.db.favorite_stations.find({"user_id": user_id}).to_list(None)
            favorite_ids = [str(fav["station_id"]) for fav in user_favorites]
            
            logger.info(f"Se encontraron {len(stations)} estaciones cercanas")
            
            # Marcar las estaciones favoritas
            for station in stations:
                try:
                    if not hasattr(station, 'id'):
                        logger.error(f"Estación sin atributo 'id': {station}")
                        continue
                    station.is_favorite = station.id in favorite_ids
                except Exception as e:
                    logger.error(f"Error marcando favorito: {str(e)}")
            
            return FuelStationList(stations=stations)
        except Exception as e:
            logger.error(f"Error procesando estaciones cercanas: {str(e)}", exc_info=True)
            # Si hay error, devolver lista vacía en lugar de error
            return FuelStationList(stations=[])
            
    except HTTPException:
        # Re-lanzar HTTPException para mantener el código y el mensaje
        raise
    except Exception as e:
        logger.error(f"Error general en búsqueda de estaciones cercanas: {str(e)}", exc_info=True)
        # Devolver lista vacía en lugar de error 
        return FuelStationList(stations=[])

@router.get("/stations/favorites", response_model=FuelStationList)
async def get_favorite_stations(
    current_user: dict = Depends(get_current_user_data)
):
    """Obtiene las estaciones favoritas del usuario"""
    try:
        # Intentar obtener los datos, respetando errores que puedan ocurrir
        try:
            all_stations = await _fetch_all_stations()
        except HTTPException as e:
            if e.status_code == 503 and cache["all_stations"]:
                # Si hay error de conexión pero tenemos caché, usar la caché
                logger.warning("Usando datos en caché para buscar favoritos después de error")
                all_stations = cache["all_stations"]
            else:
                # Si no hay caché o es otro tipo de error, propagar la excepción
                logger.error(f"Error al obtener estaciones favoritas: {str(e)}")
                raise HTTPException(status_code=503, detail=f"Error al obtener estaciones favoritas: {str(e)}")
        
        user_id = ObjectId(current_user["id"])
        
        # Obtener IDs de favoritos
        favorites = await db.db.favorite_stations.find({"user_id": user_id}).to_list(None)
        favorite_ids = [str(fav["station_id"]) for fav in favorites]
        
        if not favorite_ids:
            return FuelStationList(stations=[])
        
        # Filtrar las favoritas
        favorite_stations = []
        for station in all_stations:
            if station["id"] in favorite_ids:
                station_copy = dict(station)
                station_copy["is_favorite"] = True
                favorite_stations.append(station_copy)
        
        # Convertir a objetos FuelStationResponse directamente
        response_stations = []
        for station in favorite_stations:
            try:
                # Asegurar que la fecha de actualización es válida
                if "last_updated" not in station or not isinstance(station["last_updated"], datetime):
                    station["last_updated"] = datetime.now()
                
                # Crear directamente un FuelStationResponse
                response_station = FuelStationResponse(
                    id=str(station["id"]),
                    name=str(station.get("name", "")),
                    brand=str(station.get("brand", "")),
                    latitude=float(station.get("latitude", 0.0)),
                    longitude=float(station.get("longitude", 0.0)),
                    address=str(station.get("address", "")),
                    city=str(station.get("city", "")),
                    province=str(station.get("province", "")),
                    postal_code=str(station.get("postal_code", "")),
                    prices=station.get("prices", {}),
                    schedule=str(station.get("schedule", "")),
                    is_favorite=True,  # Siempre true para favoritos
                    last_updated=station["last_updated"],
                    distance=station.get("distance")
                )
                response_stations.append(response_station)
            except Exception as e:
                logger.error(f"Error creando FuelStationResponse para favorito: {str(e)}")
        
        logger.info(f"Favoritos: {len(favorite_stations)} estaciones, {len(response_stations)} convertidas")
        return FuelStationList(stations=response_stations)
    except Exception as e:
        logger.error(f"Error al obtener estaciones favoritas: {str(e)}")
        # En caso de error, devolver lista vacía
        return FuelStationList(stations=[])

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
        # Intentar obtener todas las estaciones
        try:
            all_stations = await _fetch_all_stations()
        except HTTPException as e:
            if e.status_code == 503 and cache["all_stations"]:
                # Si hay error de conexión pero tenemos caché, usar la caché
                logger.warning("Usando datos en caché para detalles de estación después de error")
                all_stations = cache["all_stations"]
            else:
                # Si no hay caché o es otro tipo de error, propagar la excepción
                logger.error(f"Error al obtener detalles de estación: {str(e)}")
                raise HTTPException(
                    status_code=503, 
                    detail=f"Error al obtener detalles de estación: {str(e)}"
                )
        
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
    except HTTPException:
        # Re-lanzar las HTTPException para mantener el status_code y el mensaje
        raise
    except Exception as e:
        logger.error(f"Error al obtener detalles de estación: {str(e)}")
        raise HTTPException(status_code=503, detail=f"Error al obtener detalles: {str(e)}")

@router.get("/stations/search/{query}", response_model=List[FuelStationResponse])
async def search_stations(
    query: str,
    current_user: dict = Depends(get_current_user_data)
):
    """Busca estaciones por nombre o localidad"""
    try:
        # Intentar obtener todas las estaciones
        try:
            all_stations = await _fetch_all_stations()
        except HTTPException as e:
            if e.status_code == 503 and cache["all_stations"]:
                # Si hay error de conexión pero tenemos caché, usar la caché
                logger.warning("Usando datos en caché para búsqueda después de error")
                all_stations = cache["all_stations"]
            else:
                # Si no hay caché o es otro tipo de error, propagar la excepción
                logger.error(f"Error al buscar estaciones: {str(e)}")
                raise HTTPException(
                    status_code=503, 
                    detail=f"Error al buscar estaciones: {str(e)}"
                )
        
        # Convertir a minúsculas para búsqueda insensible a mayúsculas/minúsculas
        query = query.lower()
        
        # Buscar estaciones que contengan la consulta en cualquier campo relevante
        filtered_stations = []
        
        for station in all_stations:
            # Buscar en todos los campos posibles
            if (query in station.get("name", "").lower() or
                query in station.get("brand", "").lower() or
                query in station.get("city", "").lower() or
                query in station.get("province", "").lower() or
                query in station.get("address", "").lower() or
                # También buscar en los campos alternativos
                query in station.get("nombre", "").lower() or
                query in station.get("localidad", "").lower() or
                query in station.get("provincia", "").lower() or
                query in station.get("municipio", "").lower()):
                
                filtered_stations.append(station)
        
        # Limitar resultados a 50 estaciones
        filtered_stations = filtered_stations[:50]
        
        # Verificar favoritos para el usuario actual
        user_id = ObjectId(current_user["id"])
        favorites = await db.db.favorite_stations.find({
            "user_id": user_id
        }).to_list(1000)
        
        favorite_ids = [fav["station_id"] for fav in favorites]
        
        # Marcar estaciones como favoritas
        for station in filtered_stations:
            station["is_favorite"] = station["id"] in favorite_ids
        
        # Convertir a objetos FuelStationResponse directamente (no FuelStation)
        result_stations = []
        for station in filtered_stations:
            try:
                # Asegurar que la fecha de actualización es válida
                if "last_updated" not in station or not isinstance(station["last_updated"], datetime):
                    station["last_updated"] = datetime.now()
                
                # Crear directamente un FuelStationResponse
                response_station = FuelStationResponse(
                    id=str(station["id"]),
                    name=str(station.get("name", "")),
                    brand=str(station.get("brand", "")),
                    latitude=float(station.get("latitude", 0.0)),
                    longitude=float(station.get("longitude", 0.0)),
                    address=str(station.get("address", "")),
                    city=str(station.get("city", "")),
                    province=str(station.get("province", "")),
                    postal_code=str(station.get("postal_code", "")),
                    prices=station.get("prices", {}),
                    schedule=str(station.get("schedule", "")),
                    is_favorite=bool(station.get("is_favorite", False)),
                    last_updated=station["last_updated"],
                    distance=station.get("distance")
                )
                result_stations.append(response_station)
            except Exception as e:
                logger.error(f"Error creando FuelStationResponse para búsqueda: {str(e)}")
                
        logger.info(f"Búsqueda de '{query}': {len(filtered_stations)} resultados, {len(result_stations)} convertidos")
        return result_stations
    except HTTPException:
        # Re-lanzar las HTTPException para mantener el status_code y el mensaje
        raise
    except Exception as e:
        logger.error(f"Error al buscar estaciones: {str(e)}")
        raise HTTPException(status_code=503, detail=f"Error en la búsqueda: {str(e)}")

def _calculate_distance(lat1, lon1, lat2, lon2):
    """Calcula la distancia en km entre dos coordenadas"""
    try:
        # Verificar que tenemos coordenadas válidas
        if lat1 is None or lon1 is None or lat2 is None or lon2 is None:
            return float('inf')
            
        # Convertir a float si vienen como strings
        try:
            lat1 = float(lat1)
            lon1 = float(lon1)
            lat2 = float(lat2)
            lon2 = float(lon2)
        except (ValueError, TypeError):
            return float('inf')
            
        # Verificar rangos de coordenadas
        if (abs(lat1) > 90 or abs(lat2) > 90 or 
            abs(lon1) > 180 or abs(lon2) > 180):
            return float('inf')
        
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
    except Exception as e:
        logger.error(f"Error calculando distancia: {str(e)}")
        return float('inf')

def _process_nearby_stations(all_stations, lat, lng, radius, fuel_type=None):
    """Procesa estaciones cercanas a partir de una lista y coordenadas"""
    try:
        nearby_stations = []
        
        for station in all_stations:
            try:
                # Calcular distancia
                distance = _calculate_distance(lat, lng, station["latitude"], station["longitude"])
                
                # Si está dentro del radio, añadir a la lista
                if distance <= radius:
                    # Si se especifica tipo de combustible, verificar que la estación lo tenga
                    if fuel_type and fuel_type not in station.get("prices", {}):
                        continue
                    
                    # Añadir la distancia a la estación
                    station_copy = dict(station)
                    station_copy["distance"] = distance
                    
                    # Asegurar que tiene _id para FuelStation.from_dict
                    if "id" in station_copy and "_id" not in station_copy:
                        station_copy["_id"] = station_copy["id"]
                    
                    nearby_stations.append(station_copy)
            except Exception as e:
                logger.error(f"Error procesando estación para nearby: {str(e)}")
                continue
        
        # Ordenar por distancia (las más cercanas primero)
        nearby_stations.sort(key=lambda x: x.get("distance", float("inf")))
        
        # Limitar a 50 resultados para evitar respuestas muy grandes
        nearby_stations = nearby_stations[:50]
        
        # Crear objetos FuelStationResponse directamente, en lugar de FuelStation
        response_stations = []
        for station in nearby_stations:
            try:
                # Verificar y preparar los datos esenciales
                if "id" not in station and "_id" in station:
                    station["id"] = str(station["_id"])
                elif "_id" not in station and "id" in station:
                    station["_id"] = station["id"]
                elif "id" not in station and "_id" not in station:
                    new_id = str(ObjectId())
                    station["id"] = new_id
                    station["_id"] = new_id
                
                # Asegurar que la fecha de actualización es válida
                if "last_updated" not in station or not isinstance(station["last_updated"], datetime):
                    station["last_updated"] = datetime.now()
                
                # Crear directamente un FuelStationResponse (no un FuelStation)
                response_station = FuelStationResponse(
                    id=str(station["id"]),
                    name=str(station.get("name", "")),
                    brand=str(station.get("brand", "")),
                    latitude=float(station.get("latitude", 0.0)),
                    longitude=float(station.get("longitude", 0.0)),
                    address=str(station.get("address", "")),
                    city=str(station.get("city", "")),
                    province=str(station.get("province", "")),
                    postal_code=str(station.get("postal_code", "")),
                    prices=station.get("prices", {}),
                    schedule=str(station.get("schedule", "")),
                    is_favorite=bool(station.get("is_favorite", False)),
                    last_updated=station["last_updated"],
                    distance=station.get("distance")
                )
                response_stations.append(response_station)
            except Exception as e:
                logger.error(f"Error creando FuelStationResponse: {str(e)}")
                # Continuar con la siguiente estación
        
        logger.info(f"Procesadas {len(nearby_stations)} estaciones cercanas, convertidas {len(response_stations)}")
        return {"stations": response_stations}
    except Exception as e:
        logger.error(f"Error general en _process_nearby_stations: {str(e)}")
        # En caso de error, devolver una lista vacía en lugar de propagar el error
        return {"stations": []} 