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

            db_name = self.extract_db_name(self.database_url)
            if not db_name:
                raise ValueError(f"No se pudo extraer el nombre de la base de datos de la URL: {self.database_url}")

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

db = Database()
