from fastapi import APIRouter, HTTPException, Depends, status
from bson import ObjectId
from typing import List
from datetime import datetime
import requests
import json
import os

from dotenv import load_dotenv
from database import db
from schemas.chat import ChatCreate, ChatResponse
from routers.auth import get_current_user_data
from config.llm_config import SYSTEM_PROMPT

router = APIRouter()

load_dotenv()

# ======= CONFIGURACIÓN DE OPENROUTER =======

def build_openrouter_headers():
    return {
        "Authorization": f"Bearer {os.getenv('OPENROUTER_API_KEY')}",
        "HTTP-Referer": os.getenv('HTTP_REFERER'),
        "X-Title": os.getenv('X_TITLE'),
        "Content-Type": "application/json",
    }

# =========================================================
# =============== FUNCIÓN PARA LLAMAR A OPENROUTER ========
# =========================================================
async def get_llm_response(messages: List[dict]) -> str:
    """
    Envía el historial de la conversación en formato OpenAI (role, content)
    a OpenRouter. Incluimos un 'system' prompt si no existe ya en la lista.
    """
    try:
        # Asegurar que hay un mensaje 'system'
        if not any(m["role"] == "system" for m in messages):
            messages.insert(0, {"role": "system", "content": SYSTEM_PROMPT})

        # Construir la petición a OpenRouter
        data = {
            "model": os.getenv('OPENROUTER_MODEL'),
            "messages": messages
        }

        print("\n=== Enviando solicitud a OpenRouter ===")
        print(json.dumps(data, indent=2))  # Para depuración

        resp = requests.post(
            os.getenv('OPENROUTER_URL'),
            headers=build_openrouter_headers(),
            data=json.dumps(data)
        )

        print(f"\n=== Respuesta de OpenRouter (Status: {resp.status_code}) ===")
        print(resp.text)  # Mostrar la respuesta completa

        if resp.status_code == 200:
            result = resp.json()
            return result["choices"][0]["message"]["content"]
        else:
            raise HTTPException(
                status_code=resp.status_code,
                detail=f"Error en la API de OpenRouter: {resp.text}"
            )

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Error inesperado en la comunicación con OpenRouter: {str(e)}"
        )

# =================================================================
# ====================== RUTA PARA CREAR/OBTENER CHAT =============
# =================================================================
@router.post("", response_model=ChatResponse)
async def create_or_retrieve_chat(
    chat: ChatCreate,
    current_user: dict = Depends(get_current_user_data)
):
    """
    Obtener o crear un chat para un usuario y vehículo (o general).
    """
    try:
        # Construir una query para buscar un chat existente
        query = {"userId": ObjectId(current_user["id"])}
        if chat.vehicleId:
            try:
                query["vehicleId"] = ObjectId(chat.vehicleId)
            except:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Formato de vehicleId incorrecto"
                )
        else:
            query["vehicleId"] = None

        # Buscar si ya existe el chat
        existing_chat = await db.db.chats.find_one(query)

        if existing_chat:
            # Formatear mensajes existentes
            formatted_messages = [
                {
                    "id": str(msg["_id"]),
                    "content": msg["content"],
                    "isFromUser": msg["isFromUser"],
                    "timestamp": msg["timestamp"]
                }
                for msg in reversed(existing_chat.get("messages", []))
            ]
            return {
                "id": str(existing_chat["_id"]),
                "userId": str(existing_chat["userId"]),
                "vehicleId": str(existing_chat.get("vehicleId")) if existing_chat.get("vehicleId") else None,
                "messages": formatted_messages,
                "createdAt": existing_chat["createdAt"],
                "updatedAt": existing_chat["updatedAt"]
            }

        # Si no existe, crear uno nuevo
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
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al crear/obtener el chat: {str(e)}"
        )

# =================================================================
# ============ RUTA PARA AÑADIR MENSAJE Y OBTENER RESPUESTA =======
# =================================================================
@router.post("/{chat_id}/messages")
async def add_message(
    chat_id: str,
    message: dict,
    current_user: dict = Depends(get_current_user_data)
):
    """Añadir mensaje y obtener respuesta usando OpenRouter."""
    try:
        chat = await db.db.chats.find_one({"_id": ObjectId(chat_id), "userId": ObjectId(current_user["id"])})
        if not chat:
            raise HTTPException(status_code=404, detail="Chat no encontrado o no tienes permiso para acceder a él")

        # Convertir historial de mensajes a formato OpenAI
        llm_messages = []
        for msg in chat.get("messages", []):
            role = "user" if msg["isFromUser"] else "assistant"
            llm_messages.append({"role": role, "content": msg["content"]})

        # Añadir el nuevo mensaje
        llm_messages.append({"role": "user", "content": message["message"]})

        # Llamar a la función que usa OpenRouter
        llm_response = await get_llm_response(llm_messages)

        # Guardar el mensaje del usuario
        user_message = {
            "_id": ObjectId(),
            "content": message["message"],
            "isFromUser": True,
            "timestamp": datetime.utcnow()
        }

        # Guardar la respuesta del bot
        bot_message = {
            "_id": ObjectId(),
            "content": llm_response,
            "isFromUser": False,
            "timestamp": datetime.utcnow()
        }

        await db.db.chats.update_one(
            {"_id": ObjectId(chat_id)},
            {
                "$push": {"messages": {"$each": [user_message, bot_message]}},
                "$set": {"updatedAt": datetime.utcnow()}
            }
        )

        updated_chat = await db.db.chats.find_one({"_id": ObjectId(chat_id)})

        return {
            "id": str(updated_chat["_id"]),
            "userId": str(updated_chat["userId"]),
            "vehicleId": str(updated_chat.get("vehicleId")) if "vehicleId" in updated_chat else None,
            "messages": [
                {
                    "id": str(msg["_id"]),
                    "content": msg["content"],
                    "isFromUser": msg["isFromUser"],
                    "timestamp": msg["timestamp"]
                }
                for msg in reversed(updated_chat.get("messages", []))
            ],
            "createdAt": updated_chat["createdAt"],
            "updatedAt": updated_chat["updatedAt"]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al procesar el mensaje: {str(e)}")

@router.post("/{chat_id}/clear")
async def clear_chat(
    chat_id: str,
    current_user: dict = Depends(get_current_user_data)
):
    """Limpiar todos los mensajes de un chat."""
    try:
        # Verificar que el chat existe y pertenece al usuario
        chat = await db.db.chats.find_one({
            "_id": ObjectId(chat_id),
            "userId": ObjectId(current_user["id"])
        })
        
        if not chat:
            raise HTTPException(
                status_code=404,
                detail="Chat no encontrado o no tienes permiso para acceder a él"
            )

        # Actualizar el chat limpiando los mensajes
        await db.db.chats.update_one(
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

        # Formatear la respuesta
        return {
            "id": str(updated_chat["_id"]),
            "userId": str(updated_chat["userId"]),
            "vehicleId": str(updated_chat.get("vehicleId")) if updated_chat.get("vehicleId") else None,
            "messages": [],
            "createdAt": updated_chat["createdAt"],
            "updatedAt": updated_chat["updatedAt"]
        }

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error al limpiar el chat: {str(e)}"
        )
