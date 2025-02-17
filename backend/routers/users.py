from fastapi import APIRouter, HTTPException, Depends, status
from bson import ObjectId
from datetime import datetime

from database import db
from schemas.user import UserResponse, UserUpdate
from routers.auth import get_current_user_data
from models.user import User

router = APIRouter()

@router.get("/me", response_model=UserResponse)
async def get_current_user(current_user: dict = Depends(get_current_user_data)):
    """Obtener datos del usuario actual"""
    user = await db.db.users.find_one({"_id": ObjectId(current_user["id"])})
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado"
        )
    
    if "vehicles" in user:
        for vehicle in user["vehicles"]:
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
    if current_user["id"] != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permiso para modificar este usuario"
        )

    update_data = user_update.dict(exclude_unset=True)
    update_data["updated_at"] = datetime.utcnow()
    
    result = await db.db.users.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": update_data}
    )
    
    if result.modified_count == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado"
        )
        
    updated_user = await db.db.users.find_one({"_id": ObjectId(user_id)})
    updated_user["id"] = str(updated_user["_id"])
    return UserResponse(**updated_user) 