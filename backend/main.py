from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import db
from routers import auth, users, vehicles, chats, trips, fuel
import logging


@asynccontextmanager
async def lifespan(app: FastAPI):
    await db.connect()   # ──▶ levanta excepción si no hay BD
    yield
    await db.close()

app = FastAPI(lifespan=lifespan, title="OBD Scanner API", version="0.1.0")

# Configurar CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Incluir routers
app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(users.router, prefix="/users", tags=["users"])
app.include_router(vehicles.router, prefix="/vehicles", tags=["vehicles"])
app.include_router(chats.router, prefix="/chats", tags=["chats"])
app.include_router(trips.router, prefix="/trips", tags=["trips"])
app.include_router(fuel.router, prefix="/fuel", tags=["fuel"])

@app.on_event("startup")
async def startup_db_client():
    try:
        db.connect_to_database()
    except Exception as e:
        logging.error(f"Error al conectar a la base de datos: {e}")

@app.on_event("shutdown")
async def shutdown_db_client():
    try:
        db.close_database_connection()
    except Exception as e:
        logging.error(f"Error al cerrar la conexión de base de datos: {e}")

@app.get("/")
async def root():
    return {"message": "Bienvenido a OBD Scanner API"}


'''from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import db
from routers import auth, users, vehicles, chats, trips, fuel
from contextlib import asynccontextmanager

app = FastAPI(
    title="OBD Scanner API",
    description="API para la aplicación OBD Scanner con autenticación de usuarios",
    version="0.1.0",
    openapi_tags=[{
        "name": "auth",
        "description": "Operaciones de autenticación"
    }],
)

app.swagger_ui_init_oauth = {
    "usePkceWithAuthorizationCodeGrant": True,
    "clientId": "",
    "clientSecret": ""
}

# Definir el esquema de seguridad
app.openapi_components = {
    "securitySchemes": {
        "OAuth2PasswordBearer": {
            "type": "oauth2",
            "flows": {
                "password": {
                    "tokenUrl": "auth/login",
                    "scopes": {}
                }
            }
        }
    }
}

# Aplicar seguridad global
app.openapi_security = [{"OAuth2PasswordBearer": []}]

# Configurar CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Incluir routers
app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(users.router, prefix="/users", tags=["users"])
app.include_router(vehicles.router, prefix="/vehicles", tags=["vehicles"])
app.include_router(chats.router, prefix="/chats", tags=["chats"])
app.include_router(trips.router, prefix="/trips", tags=["trips"])
app.include_router(fuel.router, prefix="/fuel", tags=["fuel"])

@app.on_event("startup")
async def startup_db_client():
    db.connect_to_database()

@app.on_event("shutdown")
async def shutdown_db_client():
    db.close_database_connection()

@app.get("/")
async def root():
    return {"message": "Bienvenido a OBD Scanner API"} '''