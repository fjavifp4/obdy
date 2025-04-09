from fastapi import APIRouter, HTTPException, Depends, status, Body
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from typing import Annotated
from datetime import timedelta, datetime
from passlib.context import CryptContext
from bson import ObjectId

from database import db
from schemas.user import UserCreate, UserLogin, UserResponse, Token
from auth.jwt_handler import create_access_token, verify_token
from models.user import User

router = APIRouter()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
#oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

async def get_current_user_data(token: str = Depends(oauth2_scheme)):
    """
    Verifica el token y devuelve los datos del usuario
    """
    try:
        payload = verify_token(token)
        user = await db.db.users.find_one({"email": payload["sub"]})
        if user is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Usuario no encontrado"
            )
        user["id"] = str(user["_id"])
        if "password_hash" not in user:
            print(f"Advertencia: Usuario {user.get('email')} no tiene campo 'password_hash'")
        return user
    except Exception as e:
        print(f"Error en get_current_user_data: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales inválidas",
            headers={"WWW-Authenticate": "Bearer"},
        )

@router.post("/login", response_model=Token)
async def login(form_data: Annotated[OAuth2PasswordRequestForm, Depends()]):
    """Login de usuario"""
    user = await db.db.users.find_one({"email": form_data.username})

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales incorrectas",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    stored_password_hash = user.get("password_hash")
    if not stored_password_hash:
        print(f"Error: Falta password_hash para el usuario {form_data.username}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error interno: configuración de usuario incompleta."
        )

    if not pwd_context.verify(form_data.password, stored_password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales incorrectas",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    user_email = user.get("email")
    if not user_email:
        print(f"Error: Falta email para el usuario con ID {user.get('_id')}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error interno: datos de usuario incompletos."
        )

    access_token = create_access_token(data={"sub": user_email})
    return {"access_token": access_token, "token_type": "bearer"}

@router.put("/change-password")
async def change_password(
    current_password: str = Body(...),
    new_password: str = Body(...),
    current_user: dict = Depends(get_current_user_data)
):
    """Cambio de contraseña"""
    current_password_hash = current_user.get("password_hash")
    if not current_password_hash or not pwd_context.verify(current_password, current_password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contraseña actual incorrecta"
        )
    
    hashed_password = pwd_context.hash(new_password)
    await db.db.users.update_one(
        {"_id": ObjectId(current_user["id"])},
        {"$set": {"password_hash": hashed_password}}
    )
    
    return {"message": "Contraseña actualizada correctamente"}

@router.post("/register", response_model=Token, status_code=status.HTTP_201_CREATED)
async def register(user_data: UserCreate):
    # Verificar si el usuario ya existe
    existing_user = await User.find_by_email(db.db, user_data.email)
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email ya registrado"
        )
    
    # Crear nuevo usuario usando el modelo
    hashed_password = pwd_context.hash(user_data.password)
    new_user_dict = {
        "username": user_data.username,
        "email": user_data.email,
        "password_hash": hashed_password,
        "created_at": datetime.utcnow(),
        "updated_at": datetime.utcnow()
    }

    # Insertar en la base de datos
    result = await db.db.users.insert_one(new_user_dict)
    created_user = await User.find_by_id(db.db, str(result.inserted_id))
    
    if not created_user:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error al crear el usuario"
        )
    
    created_user_email = created_user.get("email")
    if not created_user_email:
        print(f"Error: Usuario recién creado {result.inserted_id} no tiene email")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error interno al crear el usuario: faltan datos."
        )

    access_token = create_access_token(data={"sub": created_user_email})
    
    # Formatear la respuesta para que coincida con UserResponse
    return {"access_token": access_token, "token_type": "bearer"} 