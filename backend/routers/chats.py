from fastapi import APIRouter, HTTPException, Depends, status
from bson import ObjectId
from typing import List
from datetime import datetime
import httpx

from database import db
from schemas.chat import ChatCreate, ChatResponse, MessageCreate
from routers.auth import get_current_user_data
from config.llm_config import get_formatted_messages

router = APIRouter()

LLM_URL = "http://192.168.1.134:1234/v1/chat/completions"

async def get_llm_response(messages: List[dict]) -> str:
    try:
        formatted_messages = get_formatted_messages(messages)
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                LLM_URL,
                json={
                    "messages": formatted_messages,
                    "model": "local-model",
                    "temperature": 0.7
                },
                timeout=30.0
            )
            
            if response.status_code == 200:
                result = response.json()
                return result['choices'][0]['message']['content']
            else:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="Error al comunicarse con el LLM"
                )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Error de comunicación con el LLM: {str(e)}"
        )

@router.post("", response_model=ChatResponse)
async def create_chat(
    chat: ChatCreate,
    current_user: dict = Depends(get_current_user_data)
):
    """Obtener o crear una conversación"""
    try:        
        # Construir la consulta base
        query = {"userId": ObjectId(current_user["id"])}
        
        if chat.vehicleId:
            try:
                vehicle_id = ObjectId(chat.vehicleId)
                vehicle = await db.db.vehicles.find_one({
                    "_id": vehicle_id,
                    "user_id": ObjectId(current_user["id"])
                })
                
                if not vehicle:
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail=f"No se encontró el vehículo con ID: {chat.vehicleId}"
                    )
                
                query["vehicleId"] = vehicle_id
                
            except Exception as e:
                if isinstance(e, HTTPException):
                    raise e
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Error al procesar el ID del vehículo: {str(e)}"
                )
        else:
            query["vehicleId"] = None
        
        # Buscar chat existente
        existing_chat = await db.db.chats.find_one(query)
        
        if existing_chat:
            # Formatear los mensajes existentes
            formatted_messages = []
            for msg in reversed(existing_chat.get("messages", [])):
                formatted_messages.append({
                    "id": str(msg["_id"]),
                    "content": msg["content"],
                    "isFromUser": msg["isFromUser"],
                    "timestamp": msg["timestamp"]
                })
            
            return {
                "id": str(existing_chat["_id"]),
                "userId": str(existing_chat["userId"]),
                "vehicleId": str(existing_chat["vehicleId"]) if existing_chat.get("vehicleId") else None,
                "messages": formatted_messages,  # Ahora incluimos los mensajes existentes
                "createdAt": existing_chat["createdAt"],
                "updatedAt": existing_chat["updatedAt"]
            }
        
        # Si no existe, crear nuevo chat
        new_chat = {
            "userId": ObjectId(current_user["id"]),
            "vehicleId": ObjectId(chat.vehicleId) if chat.vehicleId else None,
            "messages": [],
            "createdAt": datetime.utcnow(),
            "updatedAt": datetime.utcnow()
        }
        
        result = await db.db.chats.insert_one(new_chat)
        
        return {
            "id": str(result.inserted_id),
            "userId": str(current_user["id"]),
            "vehicleId": str(chat.vehicleId) if chat.vehicleId else None,
            "messages": [],
            "createdAt": new_chat["createdAt"],
            "updatedAt": new_chat["updatedAt"]
        }
        
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al crear/obtener el chat: {str(e)}"
        )

@router.get("", response_model=List[ChatResponse])
async def get_user_chats(current_user: dict = Depends(get_current_user_data)):
    """Obtener todas las conversaciones del usuario"""
    try:
        chats = await db.db.chats.find(
            {"userId": ObjectId(current_user["id"])}
        ).to_list(None)
        
        formatted_chats = []
        for chat in chats:
            messages = []
            for msg in reversed(chat.get("messages", [])):
                messages.append({
                    "id": str(msg["_id"]),
                    "content": msg["content"],
                    "isFromUser": msg["isFromUser"],
                    "timestamp": msg["timestamp"]
                })
                
            formatted_chat = {
                "id": str(chat["_id"]),
                "userId": str(chat["userId"]),
                "vehicleId": str(chat["vehicleId"]) if chat.get("vehicleId") else None,
                "messages": messages,
                "createdAt": chat["createdAt"],
                "updatedAt": chat["updatedAt"]
            }
            formatted_chats.append(formatted_chat)
        
        return formatted_chats
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al obtener los chats: {str(e)}"
        )

@router.post("/{chat_id}/messages")
async def add_message(
    chat_id: str,
    message: dict,
    current_user: dict = Depends(get_current_user_data)
):
    try:
        # Obtener el chat actual y verificar permisos
        chat = await db.db.chats.find_one({
            "_id": ObjectId(chat_id),
            "userId": ObjectId(current_user["id"])  # Verificar que el chat pertenece al usuario
        })
        
        if not chat:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Chat no encontrado o no tienes permiso para acceder a él"
            )

        # Preparar el historial de mensajes para el LLM
        llm_messages = []
        for msg in chat.get("messages", []):
            role = "user" if msg["isFromUser"] else "assistant"
            llm_messages.append({
                "role": role,
                "content": msg["content"]
            })
        
        # Añadir el nuevo mensaje del usuario
        llm_messages.append({
            "role": "user",
            "content": message["message"]
        })

        # Guardar el mensaje del usuario
        user_message = {
            "_id": ObjectId(),
            "content": message["message"],
            "isFromUser": True,
            "timestamp": datetime.utcnow()
        }
        
        # Obtener respuesta del LLM con todo el contexto
        llm_response = await get_llm_response(llm_messages)
        
        # Guardar la respuesta del LLM
        bot_message = {
            "_id": ObjectId(),
            "content": llm_response,
            "isFromUser": False,
            "timestamp": datetime.utcnow()
        }
        
        # Actualizar el chat con ambos mensajes
        result = await db.db.chats.update_one(
            {"_id": ObjectId(chat_id)},
            {
                "$push": {
                    "messages": {
                        "$each": [user_message, bot_message]
                    }
                },
                "$set": {"updatedAt": datetime.utcnow()}
            }
        )
        
        # Obtener el chat actualizado y formatear la respuesta
        updated_chat = await db.db.chats.find_one({"_id": ObjectId(chat_id)})
        
        # Convertir ObjectId a strings y formatear mensajes
        formatted_messages = []
        for msg in reversed(updated_chat.get("messages", [])):
            formatted_messages.append({
                "id": str(msg["_id"]),
                "content": msg["content"],
                "isFromUser": msg["isFromUser"],
                "timestamp": msg["timestamp"]
            })
            
        return {
            "id": str(updated_chat["_id"]),
            "userId": str(updated_chat["userId"]),
            "vehicleId": str(updated_chat["vehicleId"]) if "vehicleId" in updated_chat else None,
            "messages": formatted_messages,
            "createdAt": updated_chat["createdAt"],
            "updatedAt": updated_chat["updatedAt"]
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al procesar el mensaje: {str(e)}"
        )

@router.post("/{chat_id}/clear", response_model=ChatResponse)
async def clear_chat(
    chat_id: str,
    current_user: dict = Depends(get_current_user_data)
):
    """Limpiar todos los mensajes de un chat"""
    try:
        # Verificar que el chat existe y pertenece al usuario
        chat = await db.db.chats.find_one({
            "_id": ObjectId(chat_id),
            "userId": ObjectId(current_user["id"])
        })
        
        if not chat:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Chat no encontrado o no tienes permiso para acceder a él"
            )
        
        # Limpiar los mensajes y actualizar la fecha
        result = await db.db.chats.update_one(
            {"_id": ObjectId(chat_id)},
            {
                "$set": {
                    "messages": [],
                    "updatedAt": datetime.utcnow()
                }
            }
        )
        
        # Obtener el chat actualizado
        updated_chat = await db.db.chats.find_one({"_id": ObjectId(chat_id)})
        
        return {
            "id": str(updated_chat["_id"]),
            "userId": str(updated_chat["userId"]),
            "vehicleId": str(updated_chat["vehicleId"]) if updated_chat.get("vehicleId") else None,
            "messages": [],
            "createdAt": updated_chat["createdAt"],
            "updatedAt": updated_chat["updatedAt"]
        }
        
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al limpiar el chat: {str(e)}"
        ) 