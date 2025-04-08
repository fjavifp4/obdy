import pytest
import os
import asyncio
from motor.motor_asyncio import AsyncIOMotorClient
from fastapi.testclient import TestClient
from fastapi import FastAPI
from dotenv import load_dotenv
from passlib.context import CryptContext
from datetime import datetime, timedelta
from jose import jwt
from models.user import User
from bson import ObjectId
import importlib
import sys
import uuid

# Cargar variables de entorno para pruebas
load_dotenv()

# Asegurarse de usar la base de datos de prueba
TEST_DATABASE_URL = os.environ.get("TEST_DATABASE_URL", "mongodb://localhost:27017/test_car_app")
TEST_DATABASE_NAME = "test_car_app"

# Database para pruebas
class TestDatabase:
    """Clase para manejar la conexión a la base de datos de prueba"""
    def __init__(self):
        self.client = AsyncIOMotorClient(TEST_DATABASE_URL)
        self.db = self.client[TEST_DATABASE_NAME]

    async def clear_collections(self):
        """Limpia todas las colecciones en la base de datos de prueba"""
        collections = await self.db.list_collection_names()
        for collection in collections:
            await self.db[collection].delete_many({})

# Crear una instancia de la base de datos de prueba
test_db_instance = TestDatabase()

# Mockear la instancia de db global
from database import Database
original_db = sys.modules['database'].db

# Configuración para hash de contraseñas
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Configuración para JWT
SECRET_KEY = os.getenv("SECRET_KEY")
ALGORITHM = os.getenv("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))

# Importar la app después de cargar las variables de entorno para usar la base de datos de test
from main import app

def create_access_token(data: dict, expires_delta: timedelta = None):
    """Crear un token de acceso JWT"""
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

# Utilidades para ejecutar operaciones asincrónicas de manera síncrona
def run_async(coro):
    """Ejecuta una corutina asincrónicamente dentro de una función síncrona"""
    loop = asyncio.get_event_loop()
    return loop.run_until_complete(coro)

@pytest.fixture(scope="session", autouse=True)
def mock_db():
    # Reemplazar la instancia de db en el módulo database
    sys.modules['database'].db = test_db_instance
    yield
    # Restaurar la instancia original
    sys.modules['database'].db = original_db

@pytest.fixture(scope="session")
def event_loop():
    """Crear un bucle de eventos para las pruebas"""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()

@pytest.fixture
def test_db():
    """Fixture para proporcionar una instancia de la base de datos de prueba"""
    run_async(test_db_instance.clear_collections())
    yield test_db_instance
    run_async(test_db_instance.clear_collections())

@pytest.fixture
def client():
    """Fixture para proporcionar un cliente de prueba para la API FastAPI"""
    # Ya no es necesario sobreescribir dependencias porque hemos reemplazado db globalmente
    with TestClient(app) as client:
        yield client

@pytest.fixture
def test_user(client, test_db):
    """Fixture para crear un usuario de prueba y devolver sus datos y token de acceso"""
    # Datos del usuario de prueba con un valor único para evitar conflictos
    random_suffix = uuid.uuid4().hex[:8]
    email = f"test_user_{random_suffix}@example.com"
    username = f"test_user_{random_suffix}"
    
    user_data = {
        "username": username,
        "email": email,
        "password": "TestPassword123!"
    }
    
    # Registrar el usuario
    response = client.post("/auth/register", json=user_data)
    assert response.status_code == 201
    
    # La respuesta solo contiene el token, no los datos del usuario
    token_data = response.json()
    assert "access_token" in token_data
    
    # Crear estructura con datos de usuario y token para mantener compatibilidad
    user = {
        "id": username,  # Usamos username como identificador ya que no tenemos el ID real
        "username": username,
        "email": email
    }
    
    # Devolver user y token como una tupla
    result = (user, token_data["access_token"])
    
    # Yield para permitir que las pruebas usen los datos
    yield result
    
    # Limpiar después de la prueba
    # No podemos usar ObjectId ya que no tenemos el _id real, pero podemos eliminar por email
    run_async(test_db_instance.db.users.delete_one({"email": email}))

@pytest.fixture
def auth_headers(test_user):
    """Fixture para proporcionar los encabezados de autenticación para las solicitudes"""
    user, access_token = test_user
    return {"Authorization": f"Bearer {access_token}"}

@pytest.fixture
def test_vehicle(client, test_db, auth_headers, test_user):
    """Fixture para crear un vehículo de prueba"""
    user, _ = test_user
    
    # Datos del vehículo de prueba
    random_suffix = uuid.uuid4().hex[:6]
    vehicle_data = {
        "make": "Test Make",
        "model": "Test Model",
        "year": 2023,
        "license_plate": f"TEST{random_suffix}",
        "fuel_type": "gasoline",
        "current_kilometers": 1000
    }
    
    # Crear el vehículo
    response = client.post("/vehicles/", json=vehicle_data, headers=auth_headers)
    assert response.status_code == 201
    
    vehicle = response.json()
    vehicle_id = vehicle["id"]
    
    yield vehicle
    
    # Limpiar después de la prueba
    run_async(test_db_instance.db.vehicles.delete_one({"_id": ObjectId(vehicle_id)}))

@pytest.fixture
def test_trip(client, test_db, auth_headers, test_vehicle):
    """Fixture para crear un viaje de prueba"""
    # Datos del viaje de prueba
    trip_data = {
        "vehicle_id": test_vehicle["id"],
        "distance_in_km": 0.0,
        "fuel_consumption_liters": 0.0,
        "average_speed_kmh": 0.0,
        "duration_seconds": 0
    }
    
    # Crear el viaje
    response = client.post("/trips", json=trip_data, headers=auth_headers)
    assert response.status_code == 201
    
    trip = response.json()
    trip_id = trip["id"]
    
    yield trip
    
    # Limpiar después de la prueba
    run_async(test_db_instance.db.trips.delete_one({"_id": ObjectId(trip_id)})) 