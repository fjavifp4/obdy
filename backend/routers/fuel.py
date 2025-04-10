from fastapi import APIRouter, HTTPException, Depends, status, Query
from bson import ObjectId
from typing import List, Optional, Dict
from datetime import datetime
import math
import random
import httpx
import logging
from pydantic import BaseModel, ValidationError
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

async def _calculate_general_prices(stations: List[Dict]):
    """Calcula precios medios a partir de una lista de estaciones procesadas."""
    if not stations:
        return {}
    
    fuel_totals = {}
    fuel_counts = {}
    
    for station in stations:
        # Asegurarse de que station es un diccionario antes de acceder a prices
        if isinstance(station, dict):
            for fuel_type, price in station.get("prices", {}).items():
                if isinstance(price, (int, float)) and price > 0:
                    fuel_totals[fuel_type] = fuel_totals.get(fuel_type, 0) + price
                    fuel_counts[fuel_type] = fuel_counts.get(fuel_type, 0) + 1
        else:
            logger.warning(f"Elemento inesperado en lista de estaciones para calcular precios: {type(station)}")

    average_prices = {}
    for fuel_type, total in fuel_totals.items():
        count = fuel_counts.get(fuel_type, 0)
        if count > 0:
            average_prices[fuel_type] = round(total / count, 3)
    
    return average_prices

@router.get("/prices", response_model=FuelPrices)
async def get_fuel_prices(current_user: dict = Depends(get_current_user_data)):
    """Obtiene los precios medios de los combustibles."""
    try:
        all_processed_stations = await _get_processed_stations(user_id=None) 
        if not all_processed_stations:
             logger.warning("No hay datos de estaciones para calcular precios.")
             return FuelPrices(prices={}, last_updated=datetime.now()) 
             
        average_prices = await _calculate_general_prices(all_processed_stations)
        return FuelPrices(prices=average_prices, last_updated=datetime.now())
    except HTTPException as http_exc:
         raise http_exc
    except Exception as e:
        logger.error(f"Error inesperado en get_fuel_prices: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Error interno al obtener precios generales")

@router.get("/stations/nearby", response_model=FuelStationList)
async def get_nearby_stations(
    params: NearbyStationsParams = Depends(),
    current_user: dict = Depends(get_current_user_data)
):
    """Busca gasolineras cercanas a una ubicación."""
    try:
        user_id = ObjectId(current_user["id"])
        all_processed_stations = await _get_processed_stations(user_id)
        nearby_stations_data = _process_nearby_stations(
            all_processed_stations,
            params.lat,
            params.lng,
            params.radius,
            params.fuel_type
        )
        try:
            response_stations = [FuelStationResponse(**station_data) for station_data in nearby_stations_data]
        except ValidationError as e:
             logger.error(f"Error de validación Pydantic en /nearby para estaciones: {e.json()}")
             problematic_ids = [s.get('id', 'N/A') for s in nearby_stations_data]
             logger.debug(f"IDs de estaciones cercanas que fallaron validación: {problematic_ids}")
             raise HTTPException(status_code=500, detail="Error interno al formatear estaciones cercanas")
        return FuelStationList(stations=response_stations)
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"Error inesperado en get_nearby_stations: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Error interno al buscar estaciones cercanas")

async def _get_processed_stations(user_id: Optional[ObjectId]) -> List[Dict]:
    """Función auxiliar para obtener las estaciones YA PROCESADAS por _fetch_all_stations y añadirles el estado de favorito."""
    
    # 1. Obtener la lista de estaciones ya procesadas
    try:
        # _fetch_all_stations ya maneja caché, API, curl, backup y devuelve una lista procesada
        processed_stations_base = await _fetch_all_stations() 
        if not processed_stations_base:
            logger.info("No se obtuvieron estaciones base procesadas.")
            return []
    except HTTPException as http_exc: # Re-lanzar excepciones HTTP conocidas
        raise http_exc
    except Exception as e:
        logger.error(f"Error inesperado llamando a _fetch_all_stations: {e}", exc_info=True)
        # Si _fetch_all_stations falla catastróficamente, devolvemos lista vacía o lanzamos error
        # Devolver lista vacía puede ser más seguro para el frontend
        return [] 

    # 2. Obtener favoritos del usuario (si aplica)
    favorite_ids = set()
    if user_id:
        try:
            favorites_cursor = db.db.favorite_stations.find({"user_id": user_id})
            favorite_ids = {str(fav["station_id"]) async for fav in favorites_cursor if "station_id" in fav}
        except Exception as e:
            logger.error(f"Error obteniendo favoritos para {user_id}: {e}", exc_info=True)
            # Continuar sin favoritos si hay error, las estaciones simplemente no se marcarán

    # 3. Añadir el campo 'is_favorite' a cada estación
    final_processed_stations = []
    for station in processed_stations_base:
        if isinstance(station, dict) and "id" in station:
            station_id = station["id"] # El ID ya está presente gracias a _fetch_all_stations
            station["is_favorite"] = station_id in favorite_ids
            final_processed_stations.append(station)
        else:
            logger.warning(f"Elemento inválido o sin ID en la lista de processed_stations_base: {station}")

    logger.info(f"Retornando {len(final_processed_stations)} estaciones procesadas finales (con estado de favorito).")
    return final_processed_stations

def _calculate_distance(lat1, lon1, lat2, lon2):
    """Calcula la distancia haversine entre dos puntos en km."""
    R = 6371 # Radio de la Tierra en km
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = math.sin(delta_phi / 2.0) ** 2 + \
        math.cos(phi1) * math.cos(phi2) * \
        math.sin(delta_lambda / 2.0) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    distance = R * c
    return distance

def _process_nearby_stations(processed_stations: List[Dict], lat: float, lng: float, radius: float, fuel_type: Optional[str] = None) -> List[Dict]:
    """Filtra estaciones procesadas por cercanía y tipo de combustible."""
    nearby = []
    logger.info(f"Procesando {len(processed_stations)} estaciones para nearby (lat={lat}, lng={lng}, radius={radius}, fuel={fuel_type})")
    for station in processed_stations:
        if not isinstance(station, dict):
             logger.warning(f"Elemento inesperado en processed_stations: {type(station)}, saltando.")
             continue
             
        station_id = station.get("id", "ID Desconocido") 
                
        if 'latitude' not in station or 'longitude' not in station:
            logger.warning(f"Estación {station_id} no tiene coordenadas 'latitude' o 'longitude', saltando.")
            continue

        try:
            latitude = station['latitude'] 
            longitude = station['longitude']
            
            if not isinstance(latitude, (int, float)) or not isinstance(longitude, (int, float)):
                 logger.warning(f"Estación {station_id} tiene tipos de coordenadas inválidos ({type(latitude)}, {type(longitude)}), saltando.")
                 continue

            distance = _calculate_distance(lat, lng, latitude, longitude)
            
            if distance <= radius:
                station_prices = station.get('prices', {})
                if fuel_type and fuel_type not in station_prices:
                    continue 
                
                station_copy = station.copy() 
                station_copy["distance"] = round(distance, 2)
                nearby.append(station_copy)
                 
        except KeyError as e_key: # Renombrar
            logger.error(f"KeyError inesperado procesando estación {station_id} para nearby: Falta la clave {e_key}")
        except Exception as e_nearby: # Renombrar
             logger.error(f"Error general procesando estación {station_id} para nearby: {e_nearby}", exc_info=True)
    
    nearby.sort(key=lambda x: x.get("distance", float('inf'))) 
    logger.info(f"Encontradas {len(nearby)} estaciones cercanas válidas.")
    return nearby

@router.get("/stations/favorites", response_model=FuelStationList)
async def get_favorite_stations(current_user: dict = Depends(get_current_user_data)):
    """Obtiene las estaciones favoritas del usuario"""
    try:
        user_id = ObjectId(current_user["id"])
        all_processed_stations = await _get_processed_stations(user_id)
        favorite_stations_data = [s for s in all_processed_stations if s.get("is_favorite", False)]
        try:
             response_stations = [FuelStationResponse(**station_data) for station_data in favorite_stations_data]
        except ValidationError as e:
             logger.error(f"Error de validación Pydantic en /favorites para estaciones: {e.json()}")
             problematic_ids = [s.get('id', 'N/A') for s in favorite_stations_data]
             logger.debug(f"IDs de estaciones favoritas que fallaron validación: {problematic_ids}")
             raise HTTPException(status_code=500, detail="Error interno al formatear estaciones favoritas")
        return FuelStationList(stations=response_stations)
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"Error inesperado en get_favorite_stations: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Error interno al obtener estaciones favoritas")

@router.post("/stations/favorites", status_code=status.HTTP_201_CREATED)
async def add_favorite_station(
    favorite: FavoriteStationAdd,
    current_user: dict = Depends(get_current_user_data)
):
    """Añade una estación a favoritos"""
    try:
        user_id = ObjectId(current_user["id"])
        station_id = favorite.station_id # Este es el IDEESS
        
        existing = await db.db.favorite_stations.find_one({
            "user_id": user_id,
            "station_id": station_id
        })
        
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La estación ya está en favoritos"
            )
        
        new_favorite = {
            "user_id": user_id,
            "station_id": station_id,
            "created_at": datetime.now()
        }
        result = await db.db.favorite_stations.insert_one(new_favorite)
        
        if not result.inserted_id:
            raise HTTPException(status_code=500, detail="Error al añadir a favoritos")
        
        return {
            "user_id": str(user_id),
            "station_id": station_id,
            "created_at": new_favorite["created_at"]
        }
        
    except HTTPException as http_exc:
         raise http_exc 
    except Exception as e:
        logger.error(f"Error al añadir favorito: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Error interno al añadir a favoritos")

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
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Estación no encontrada en favoritos"
            )
        
        return {"message": "Estación eliminada de favoritos"}
        
    except HTTPException as http_exc:
         raise http_exc 
    except Exception as e:
        logger.error(f"Error al eliminar favorito: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Error interno al eliminar de favoritos")

@router.get("/stations/{station_id}", response_model=FuelStationResponse)
async def get_station_details(station_id: str, current_user: dict = Depends(get_current_user_data)):
    """Obtiene los detalles de una estación"""
    try:
        user_id = ObjectId(current_user["id"])
        all_processed_stations = await _get_processed_stations(user_id)
        station_data = next((s for s in all_processed_stations if s.get("id") == station_id), None)
        if not station_data:
            raise HTTPException(status_code=404, detail="Estación no encontrada")
        logger.info(f"[get_station_details] Datos de estación encontrados para {station_id}: {station_data}")
        if isinstance(station_data, dict):
             logger.info(f"[get_station_details] ¿Contiene 'is_favorite'?: {'is_favorite' in station_data}")
        try:
             response_obj = FuelStationResponse(**station_data)
             logger.info(f"[get_station_details] Objeto Pydantic creado para {station_id}: {response_obj.model_dump()}")
             return response_obj
        except ValidationError as e:
             logger.error(f"Error de validación Pydantic en /stations/{station_id}: {e.json()}")
             logger.info(f"[get_station_details] Datos problemáticos que fallaron validación para {station_id}: {station_data}")
             raise HTTPException(status_code=500, detail="Error interno al formatear detalles de la estación")
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"Error inesperado en get_station_details para {station_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Error interno al obtener detalles de la estación")

@router.get("/stations/search/{query}", response_model=List[FuelStationResponse])
async def search_stations(query: str, current_user: dict = Depends(get_current_user_data)):
    """Busca estaciones por nombre, dirección o localidad"""
    try:
        user_id = ObjectId(current_user["id"])
        all_processed_stations = await _get_processed_stations(user_id)
        query_lower = query.lower().strip()
        if not query_lower:
             return []
        matching_stations_data = [
            s for s in all_processed_stations 
            if query_lower in s.get('name', '').lower() or \
               query_lower in s.get('address', '').lower() or \
               query_lower in s.get('city', '').lower() or \
               query_lower in s.get('brand', '').lower()
        ]
        try:
             response_stations = [FuelStationResponse(**station_data) for station_data in matching_stations_data]
        except ValidationError as e:
             logger.error(f"Error de validación Pydantic en /search/{query}: {e.json()}")
             problematic_ids = [s.get('id', 'N/A') for s in matching_stations_data]
             logger.debug(f"IDs de estaciones en búsqueda que fallaron validación: {problematic_ids}")
             raise HTTPException(status_code=500, detail="Error interno al formatear resultados de búsqueda")
        logger.info(f"Búsqueda de '{query}': {len(response_stations)} resultados.")
        return response_stations
    except HTTPException as http_exc:
        raise http_exc
    except Exception as e:
        logger.error(f"Error inesperado en search_stations para '{query}': {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Error interno al buscar estaciones") 