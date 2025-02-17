import os
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv

load_dotenv()

class Database:
    client: AsyncIOMotorClient = None
    database_url = os.getenv("DATABASE_URL")

    def connect_to_database(self):
        try:
            self.client = AsyncIOMotorClient(self.database_url)
            self.db = self.client['obd_scanner_db']
            print("Conexión exitosa a la base de datos")
        except Exception as e:
            print(f"Error conectando a la base de datos: {e}")

    def close_database_connection(self):
        if self.client:
            self.client.close()
            print("Conexión a la base de datos cerrada")

 
db = Database() 