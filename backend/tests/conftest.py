import pytest
import os
import asyncio
from motor.motor_asyncio import AsyncIOMotorClient
from fastapi.testclient import TestClient
from fastapi import status # Importar status
from dotenv import load_dotenv
import pytest_asyncio

# Cargar variables de entorno desde .env
load_dotenv()

# Obtener las URLs de la BD
original_db_url = os.getenv("DATABASE_URL")
test_db_url = os.getenv("TEST_DATABASE_URL")
if not test_db_url:
    raise ValueError("TEST_DATABASE_URL no está definida en el archivo .env")

# Ahora importar la app y la instancia db (usará la URL por defecto inicialmente)
from main import app
from database import db

# Usar pytest_asyncio.fixture para fixtures asíncronas
# Scope "function"
@pytest_asyncio.fixture(scope="function")
async def test_db():
    """Fixture para conectar y limpiar la base de datos de prueba ANTES de cada test."""
    # --- Modificación Crítica: Asignar la URL de prueba a la instancia db --- 
    db.database_url = test_db_url
    db.client = None # Forzar reconexión con la nueva URL
    
    print(f"Intentando conectar a la base de datos de prueba: {test_db_url}...")
    db.connect_to_database() # Ahora usará test_db_url
    if not db.client:
       raise RuntimeError(f"Fallo al conectar a la base de datos de prueba: {test_db_url}")
    print(f"Conectado a BD de prueba: {db.db.name} en {test_db_url}")
    
    # Verificar conexión con ping
    try:
        await db.client.admin.command('ping')
        print("Ping a la BD de prueba exitoso.")
    except Exception as e:
        print(f"Error haciendo ping a la BD de prueba: {e}")
        raise RuntimeError(f"No se pudo hacer ping a la base de datos de prueba: {test_db_url}") from e

    # Limpieza ANTES del test (de la base de datos de PRUEBA)
    print(f"Limpiando colecciones en BD de prueba: {db.db.name}")
    await db.db.users.delete_many({}) # Limpiar la colección de usuarios
    collections_to_clear = ["vehicles", "trips", "chats", "favorite_stations", "fs.files", "fs.chunks"] # Añadir 'favorite_stations' y GridFS
    existing_collections = await db.db.list_collection_names()
    for col_name in collections_to_clear:
        if col_name in existing_collections:
            print(f"Limpiando colección: {col_name}")
            await db.db[col_name].delete_many({})
        else:
            print(f"Colección no encontrada para limpiar: {col_name}")
    
    yield db.db # Proporciona la instancia de la base de datos de prueba (motor) a los tests

    # No hay limpieza post-yield aquí, ya que se hace antes del siguiente test

# Mantener la fixture client como estaba
@pytest.fixture(scope="function")
def client(test_db): # test_db asegura que la BD está lista y limpia
    """Fixture que proporciona un TestClient para la app FastAPI."""
    # Importante: El cliente usa la instancia 'app' que a su vez usa la instancia 'db'
    # cuya URL ha sido modificada por la fixture test_db.
    with TestClient(app) as test_client:
        yield test_client

# Fixture para cerrar la conexión al final de la sesión
@pytest.fixture(scope="session", autouse=True)
def close_db_connection_session():
    """Cierra la conexión a la BD al final de toda la sesión de pruebas."""
    yield
    if db.client:
        # Asegurarse de que estamos cerrando la conexión de prueba
        print(f"Cerrando conexión a BD de prueba ({db.database_url}) al final de la sesión.")
        db.close_database_connection()

# Función auxiliar
def create_user_and_get_token(client: TestClient, user_suffix: str = "") -> tuple[str, str]:
    """Registra un usuario, hace login y devuelve (token, user_id)."""
    username = f"testuser_{user_suffix}"
    email = f"test_{user_suffix}@example.com"
    password = "password123"
    
    # Registrar
    register_response = client.post(
        "/auth/register",
        json={"username": username, "email": email, "password": password}
    )
    assert register_response.status_code == status.HTTP_201_CREATED, \
        f"Fallo al registrar usuario {email}: {register_response.text}"
    token = register_response.json()["access_token"]

    # Obtener ID del usuario
    headers = {"Authorization": f"Bearer {token}"}
    me_response = client.get("/users/me", headers=headers)
    assert me_response.status_code == status.HTTP_200_OK, \
        f"Fallo al obtener usuario {email} con token: {me_response.text}"
    user_id = me_response.json()["id"]
    
    return token, user_id
