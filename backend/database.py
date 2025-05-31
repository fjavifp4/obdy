import os
import logging
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv
from pymongo.uri_parser import parse_uri

load_dotenv()

class Database:
    """Gestor asíncrono de conexión MongoDB con Motor."""
    def __init__(self):
        self._client: AsyncIOMotorClient | None = None
        self.db = None
        self._uri = os.getenv("DATABASE_URL")

    async def connect(self):
        """Abre la conexión. Lanza excepción si falla."""
        if self.db:              
            return

        if not self._uri:
            raise RuntimeError("DATABASE_URL no definida en variables de entorno")

        logging.info(f"[DB] Conectando a {self._uri}")

        self._client = AsyncIOMotorClient(
            self._uri,
            serverSelectionTimeoutMS=5_000,      
            tlsAllowInvalidCertificates=True        
        )

        # Comprueba que el clúster responde
        try:
            await self._client.admin.command("ping")
        except Exception as exc:
            # Cierra inmediatamente y propaga el error
            self._client.close()
            self._client = None
            logging.error(f"[DB] No se pudo conectar: {exc}")
            raise

        # Obtiene el nombre de base de datos de la URI
        db_name = parse_uri(self._uri).get("database")
        if not db_name:
            raise RuntimeError(
                f"[DB] La URI no contiene nombre de BD: {self._uri}"
            )

        self.db = self._client[db_name]
        logging.info(f"[DB] Conectado a la BD «{db_name}» ✅")

    async def close(self):
        """Cierra la conexión (se invoca en shutdown)."""
        if self._client:
            logging.info("[DB] Cerrando conexión MongoDB")
            self._client.close()
            self._client = None
            self.db = None


db = Database()



'''import os
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv
from pymongo.uri_parser import parse_uri

load_dotenv()

class Database:
    client: AsyncIOMotorClient = None
    database_url = os.getenv("DATABASE_URL")
    db = None

    def connect_to_database(self):
        if not self.database_url:
            raise ValueError("DATABASE_URL no está definida en el entorno.")
        try:
            print(f"[DB Connector] Intentando conectar a: {self.database_url}")
            self.client = AsyncIOMotorClient(self.database_url)
            
            db_name = parse_uri(self.database_url).get('database')
            if not db_name:
                raise ValueError(f"No se especificó el nombre de la base de datos en la URL: {self.database_url}")
                
            self.db = self.client[db_name]
            print(f"[DB Connector] Conexión exitosa a la base de datos '{self.db.name}'")
        except Exception as e:
            print(f"[DB Connector] Error conectando a la base de datos: {e}")
            self.client = None
            self.db = None

    def close_database_connection(self):
        if self.client:
            current_db_name = self.db.name if self.db is not None else "N/A"
            print(f"[DB Connector] Cerrando conexión a la base de datos '{current_db_name}'")
            self.client.close()
            self.client = None
            self.db = None

 
db = Database() '''