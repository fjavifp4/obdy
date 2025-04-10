import os
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv
from urllib.parse import urlparse

load_dotenv()

class Database:
    client: AsyncIOMotorClient = None
    database_url = os.getenv("DATABASE_URL")
    db = None

    def extract_db_name(self, url: str) -> str:
        parsed = urlparse(url)
        if parsed.path and len(parsed.path) > 1:
            return parsed.path[1:]  # elimina el "/"
        return None

    def connect_to_database(self):
        if not self.database_url:
            raise ValueError("DATABASE_URL no está definida en el entorno.")
        try:
            print(f"[DB Connector] Intentando conectar a: {self.database_url}")
            self.client = AsyncIOMotorClient(self.database_url)

            # Intenta extraer la base de datos por defecto
            self.db = self.client.get_default_database()

            if self.db is None:
                raise ValueError("No se pudo determinar la base de datos por defecto. ¿La URL contiene el nombre de la DB?")
            
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

db = Database()
