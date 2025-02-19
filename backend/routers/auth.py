from fastapi import APIRouter, HTTPException, Depends, status, Body
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from typing import Annotated
from datetime import timedelta
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
        return user
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciales inválidas",
            headers={"WWW-Authenticate": "Bearer"},
        )

@router.post("/login", response_model=Token)
async def login(form_data: Annotated[OAuth2PasswordRequestForm, Depends()]):
    """Login de usuario"""
    try:
        user = await db.db.users.find_one({"email": form_data.username})
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Credenciales incorrectas",
                headers={"WWW-Authenticate": "Bearer"},
            )

        if not pwd_context.verify(form_data.password, user.get("hashed_password", "")):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Credenciales incorrectas",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        access_token = create_access_token(data={"sub": user["email"]})
        return {"access_token": access_token, "token_type": "bearer"}
    except KeyError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error en la estructura de datos del usuario: {str(e)}"
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error interno del servidor: {str(e)}"
        )

@router.put("/change-password")
async def change_password(
    current_password: str = Body(...),
    new_password: str = Body(...),
    current_user: dict = Depends(get_current_user_data)
):
    """Cambio de contraseña"""
    if not pwd_context.verify(current_password, current_user["hashed_password"]):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contraseña actual incorrecta"
        )
    
    hashed_password = pwd_context.hash(new_password)
    await db.db.users.update_one(
        {"_id": ObjectId(current_user["id"])},
        {"$set": {"hashed_password": hashed_password}}
    )
    
    return {"message": "Contraseña actualizada correctamente"}

@router.post("/register", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
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
    new_user = User(
        username=user_data.username,
        email=user_data.email,
        password_hash=hashed_password
    )
    
    # Insertar en la base de datos
    result = await db.db.users.insert_one(new_user.__dict__)
    created_user = await User.find_by_id(db.db, str(result.inserted_id))
    
    if not created_user:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error al crear el usuario"
        )
    
    # Formatear la respuesta para que coincida con UserResponse
    return {
        "id": str(created_user["_id"]),
        "username": created_user["username"],
        "email": created_user["email"],
        "createdAt": created_user["created_at"],
        "updatedAt": created_user["updated_at"],
        "vehicles": []  # Añadir lista vacía de vehículos
    } 