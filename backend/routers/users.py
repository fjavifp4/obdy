from fastapi import APIRouter, HTTPException, Depends, status
from bson import ObjectId, errors as bson_errors
from datetime import datetime

from database import db
from schemas.user import UserResponse, UserUpdate
from routers.auth import get_current_user_data
from models.user import User

router = APIRouter()

@router.get("/me", response_model=UserResponse)
async def get_current_user(current_user: dict = Depends(get_current_user_data)):
    """Obtener datos del usuario actual"""
    try:
        user_object_id = ObjectId(current_user["id"])
    except (bson_errors.InvalidId, TypeError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="ID de usuario inválido en el token"
        )
        
    user = await db.db.users.find_one({"_id": user_object_id})
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado"
        )
    
    if "vehicles" in user:
        if isinstance(user["vehicles"], list):
             for vehicle in user["vehicles"]:
                 if isinstance(vehicle, dict) and "_id" in vehicle:
                      vehicle["id"] = str(vehicle["_id"])
            
    user["id"] = str(user["_id"])
    return user

@router.put("/{user_id}", response_model=UserResponse)
async def update_user(
    user_id: str,
    user_update: UserUpdate,
    current_user: dict = Depends(get_current_user_data)
):
    """Actualizar datos del usuario"""
    try:
        user_object_id_from_path = ObjectId(user_id)
    except (bson_errors.InvalidId, TypeError):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, 
            detail="El formato del ID de usuario proporcionado es inválido."
        )

    current_user_id_str = current_user.get("id")
    if not current_user_id_str:
         raise HTTPException(status_code=401, detail="Token inválido: falta ID de usuario")

    try:
        current_user_object_id = ObjectId(current_user_id_str)
    except (bson_errors.InvalidId, TypeError):
        raise HTTPException(status_code=401, detail="Token inválido: ID de formato incorrecto")

    if current_user_object_id != user_object_id_from_path:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para modificar este usuario"
        )

    update_data = user_update.model_dump(exclude_unset=True)
    update_data["updated_at"] = datetime.utcnow()
    
    result = await db.db.users.update_one(
        {"_id": user_object_id_from_path},
        {"$set": update_data}
    )
    
    if result.modified_count == 0:
        existing_user = await db.db.users.find_one({"_id": user_object_id_from_path})
        if not existing_user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Usuario no encontrado"
            )

    updated_user = await db.db.users.find_one({"_id": user_object_id_from_path})
    if not updated_user:
         raise HTTPException(status_code=500, detail="Error al recuperar usuario actualizado")
         
    updated_user["id"] = str(updated_user["_id"])
    return UserResponse(**updated_user) 