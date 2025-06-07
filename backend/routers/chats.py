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
    api_key = os.getenv('OPENROUTER_API_KEY')
    if not api_key:
        # Error si la clave de API no está configurada
        raise ValueError("La variable de entorno OPENROUTER_API_KEY no está configurada en el servidor.")
        
    try:
        # Asegurar que hay un mensaje 'system'
        if not any(m["role"] == "system" for m in messages):
            messages.insert(0, {"role": "system", "content": SYSTEM_PROMPT})

        # Construir la petición a OpenRouter
        data = {
            "model": os.getenv('OPENROUTER_MODEL'),
            "messages": messages,
            "temperature": 0.3,  # Temperatura baja para respuestas más deterministas
            "top_p": 0.3,        # Valor bajo para reducir la creatividad
            #"max_tokens": 250
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
            # Verificar si el content está vacío pero hay reasoning
            content = result["choices"][0]["message"]["content"]
            if content == "" and "reasoning" in result["choices"][0]["message"] and result["choices"][0]["message"]["reasoning"]:
                # Usar el campo reasoning como contenido de la respuesta
                content = "Respuesta del asistente: " + result["choices"][0]["message"]["reasoning"]
                print(f"\n=== Usando campo reasoning como respuesta: {content} ===")
            return content
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
    try:
        # Construir una query para buscar un chat existente
        query = {"userId": ObjectId(current_user["id"])}
        vehicle_info = None

        if chat.vehicleId:
            try:
                vehicle_id = ObjectId(chat.vehicleId)
                query["vehicleId"] = vehicle_id

                # Obtener información del vehículo y sus mantenimientos
                vehicle = await db.db.vehicles.find_one({"_id": vehicle_id})
                if vehicle:
                    maintenance_records = vehicle.get("maintenance_records", [])

                    # Si no hay mantenimientos, asegurarnos de que sea una lista vacía, no None
                    if maintenance_records is None:
                        maintenance_records = []

                    vehicle_info = {
                        "brand": vehicle.get("brand", ""),
                        "model": vehicle.get("model", ""),
                        "year": vehicle.get("year", ""),
                        "maintenance_records": [
                            {
                                "type": record.get("type", ""),
                                "last_change_km": record.get("last_change_km", 0),
                                "recommended_interval_km": record.get("recommended_interval_km", 0),
                                "next_change_km": record.get("next_change_km", 0),
                                "last_change_date": record.get("last_change_date").strftime("%Y-%m-%d") if record.get("last_change_date") else "",
                                "notes": record.get("notes", ""),
                                "km_since_last_change": record.get("km_since_last_change", 0)
                            }
                            for record in maintenance_records
                        ] if maintenance_records else [],
                        "last_itv_date": vehicle.get("last_itv_date"),
                        "next_itv_date": vehicle.get("next_itv_date"),
                        "licensePlate": vehicle.get("licensePlate", "")
                    }

                    # Modificar el system prompt para incluir la información del vehículo
                    if vehicle_info:
                        vehicle_context = f"""
                        Información del vehículo del usuario:
                        - Marca: {vehicle_info['brand']}
                        - Modelo: {vehicle_info['model']}
                        - Año: {vehicle_info['year']}
                        - Matrícula: {vehicle_info['licensePlate']}
                        
                        Información de ITV:
                        - Última ITV: {vehicle_info['last_itv_date'].strftime("%Y-%m-%d") if vehicle_info['last_itv_date'] else "No registrada"}
                        - Próxima ITV: {vehicle_info['next_itv_date'].strftime("%Y-%m-%d") if vehicle_info['next_itv_date'] else "No registrada"}

                        Registros de mantenimiento disponibles:
                        {_format_maintenance_records(vehicle_info['maintenance_records'])}

                        INSTRUCCIONES IMPORTANTES:
                        1. Limítate SOLO a la información anterior.
                        2. Si te preguntan sobre mantenimientos y no hay datos registrados, responde EXPLÍCITAMENTE que no hay información de mantenimiento para este vehículo.
                        3. NUNCA inventes datos de mantenimiento o sugieras fechas específicas si no están en los registros anteriores.
                        4. Si te preguntan por aspectos específicos que no están en estos datos, indica claramente: "No dispongo de esa información en mis registros".
                        """
                        messages = [
                            {"role": "system", "content": SYSTEM_PROMPT + "\n\n" + vehicle_context}
                        ]
                    else:
                        messages = [{"role": "system", "content": SYSTEM_PROMPT}]

            except Exception as e:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Error al procesar la información del vehículo: {str(e)}"
                )
        else:
            query["vehicleId"] = None
            messages = [{"role": "system", "content": SYSTEM_PROMPT}]

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
                for msg in existing_chat.get("messages", [])
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
            detail=f"Error al crear/recuperar el chat: {str(e)}"
        )

def _format_maintenance_records(records: List[dict]) -> str:
    if not records:
        return """
        NO HAY NINGÚN MANTENIMIENTO REGISTRADO EN EL SISTEMA PARA ESTE VEHÍCULO
        
        • No se dispone de historial de mantenimiento
        • No hay información sobre próximos mantenimientos recomendados
        • No hay datos sobre cambios anteriores

        INSTRUCCIÓN DIRECTA: Cuando te pregunten sobre mantenimientos específicos, 
        DEBES responder "No tengo información de mantenimiento registrada para este vehículo. 
        Te recomiendo consultar con el concesionario o taller para obtener datos precisos."
        """
    
    formatted_records = []
    for record in records:
        formatted_record = f"""
        - Tipo: {record['type']}
        - Último cambio: {record['last_change_km']} km ({record['last_change_date']})
        - Intervalo recomendado: {record['recommended_interval_km']} km
        - Próximo cambio: {record['next_change_km']} km
        - Kilómetros recorridos desde último cambio: {record.get('km_since_last_change', 0)} km
        - Notas: {record['notes']}
        """
        formatted_records.append(formatted_record)
    
    return "\n".join(formatted_records)

# =================================================================
# ============ RUTA PARA AÑADIR MENSAJE Y OBTENER RESPUESTA =======
# =================================================================
@router.post("/{chat_id}/messages", response_model=ChatResponse)
async def add_message(
    chat_id: str,
    message: dict,
    current_user: dict = Depends(get_current_user_data)
):
    """Añade un mensaje de usuario, obtiene respuesta del LLM y actualiza el chat."""
    try:
        chat_object_id = ObjectId(chat_id)
        user_object_id = ObjectId(current_user["id"])
    except Exception:
        raise HTTPException(status_code=400, detail="Formato de ID inválido")

    # Buscar el chat
    chat = await db.db.chats.find_one({"_id": chat_object_id})
    
    # --- CORRECCIÓN: Comprobar existencia y pertenencia --- 
    if chat is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chat no encontrado")
    if chat["userId"] != user_object_id:
        # No dar pistas, devolver 404 también si no pertenece al usuario
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chat no encontrado")
    # --- FIN CORRECCIÓN --- 

    # Extraer contenido del mensaje
    user_content = message.get("content")
    if not user_content or not isinstance(user_content, str):
        raise HTTPException(status_code=400, detail="El mensaje debe tener un campo 'content' de tipo string")

    # Crear el mensaje del usuario
    user_message_doc = {
        "_id": ObjectId(),
        "content": user_content,
        "isFromUser": True,
        "timestamp": datetime.utcnow()
    }
    
    # Añadir mensaje de usuario a la BD
    await db.db.chats.update_one(
        {"_id": chat_object_id},
        {
            "$push": {"messages": user_message_doc},
            "$set": {"updatedAt": datetime.utcnow()}
        }
    )
    
    # Preparar historial para el LLM
    # Recuperar mensajes actualizados y formatear para la API
    updated_chat = await db.db.chats.find_one({"_id": chat_object_id})
    db_messages = updated_chat.get("messages", [])
    
    # Formatear para el LLM (role, content)
    history_for_llm = []
    vehicle_context = "" # Inicializar vacío
    
    # Añadir contexto del vehículo si existe
    if updated_chat.get("vehicleId"):
        vehicle = await db.db.vehicles.find_one({"_id": updated_chat["vehicleId"]})
        if vehicle:
            vehicle_info = { # Extraer info necesaria
                "brand": vehicle.get("brand", ""),
                "model": vehicle.get("model", ""),
                "year": vehicle.get("year", ""),
                "licensePlate": vehicle.get("licensePlate", ""),
                "maintenance_records": vehicle.get("maintenance_records", []),
                "last_itv_date": vehicle.get("last_itv_date"),
                "next_itv_date": vehicle.get("next_itv_date"),
            }
            vehicle_context = f"""
            Información del vehículo del usuario:
            - Marca: {vehicle_info['brand']}
            - Modelo: {vehicle_info['model']}
            - Año: {vehicle_info['year']}
            - Matrícula: {vehicle_info['licensePlate']}
            
            Información de ITV:
            - Última ITV: {vehicle_info['last_itv_date'].strftime("%Y-%m-%d") if vehicle_info['last_itv_date'] else "No registrada"}
            - Próxima ITV: {vehicle_info['next_itv_date'].strftime("%Y-%m-%d") if vehicle_info['next_itv_date'] else "No registrada"}

            Registros de mantenimiento disponibles:
            {_format_maintenance_records(vehicle_info['maintenance_records'])}

            INSTRUCCIONES IMPORTANTES:
            1. Limítate SOLO a la información anterior.
            2. Si te preguntan sobre mantenimientos y no hay datos registrados, responde EXPLÍCITAMENTE que no hay información de mantenimiento para este vehículo.
            3. NUNCA inventes datos de mantenimiento o sugieras fechas específicas si no están en los registros anteriores.
            4. Si te preguntan por aspectos específicos que no están en estos datos, indica claramente: "No dispongo de esa información en mis registros".
            """

    # Añadir system prompt (con o sin contexto de vehículo)
    history_for_llm.append({"role": "system", "content": SYSTEM_PROMPT + ("\n\n" + vehicle_context if vehicle_context else "")})
    
    # Añadir historial de mensajes
    for msg in db_messages:
        history_for_llm.append({
            "role": "user" if msg["isFromUser"] else "assistant",
            "content": msg["content"]
        })

    # Obtener respuesta del LLM (aquí se usará el mock durante los tests)
    llm_response_content = await get_llm_response(history_for_llm)
    
    # Crear el mensaje del asistente
    assistant_message_doc = {
        "_id": ObjectId(),
        "content": llm_response_content,
        "isFromUser": False,
        "timestamp": datetime.utcnow()
    }
    
    # Añadir mensaje del asistente a la BD
    await db.db.chats.update_one(
        {"_id": chat_object_id},
        {
            "$push": {"messages": assistant_message_doc},
            "$set": {"updatedAt": datetime.utcnow()}
        }
    )
    
    # Devolver el chat completo actualizado usando el schema de respuesta
    final_chat = await db.db.chats.find_one({"_id": chat_object_id})
    
    # --- CORRECCIÓN: Formatear mensajes antes de validar con ChatResponse ---
    formatted_messages = []
    for msg in final_chat.get("messages", []):
        formatted_messages.append({
            "id": str(msg["_id"]),
            "content": msg["content"],
            "isFromUser": msg["isFromUser"],
            "timestamp": msg["timestamp"]
        })
    # --- FIN CORRECCIÓN ---
    
    # Crear el diccionario final para ChatResponse
    response_data = {
        **final_chat,
        "id": str(final_chat["_id"]),
        "userId": str(final_chat["userId"]),
        "vehicleId": str(final_chat.get("vehicleId")) if final_chat.get("vehicleId") else None,
        "messages": formatted_messages # Usar la lista formateada
    }
    
    # Validar y devolver
    try:
        return ChatResponse(**response_data)
    except ValidationError as e:
        # Loggear el error de validación detallado
        logger.error(f"Error de validación al crear ChatResponse: {e.json()}") 
        raise HTTPException(status_code=500, detail="Error interno al formatear la respuesta del chat.")

# =================================================================
# ====================== RUTA PARA LIMPIAR CHAT ===================
# =================================================================
@router.post("/{chat_id}/clear", response_model=ChatResponse)
async def clear_chat(
    chat_id: str,
    current_user: dict = Depends(get_current_user_data)
):
    """Borra todos los mensajes de un chat existente."""
    try:
        chat_object_id = ObjectId(chat_id)
        user_object_id = ObjectId(current_user["id"])
    except Exception:
        raise HTTPException(status_code=400, detail="Formato de ID inválido")

    # Buscar el chat
    chat = await db.db.chats.find_one({"_id": chat_object_id})
    
    # --- CORRECCIÓN: Comprobar existencia y pertenencia --- 
    if chat is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chat no encontrado")
    if chat["userId"] != user_object_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Chat no encontrado")
    # --- FIN CORRECCIÓN --- 

    # Limpiar mensajes
    await db.db.chats.update_one(
        {"_id": chat_object_id},
        {
            "$set": {"messages": [], "updatedAt": datetime.utcnow()}
        }
    )

    # Obtener el chat actualizado
    updated_chat = await db.db.chats.find_one({"_id": chat_object_id})
    
    # Formatear mensajes
    formatted_messages = []
    for msg in updated_chat.get("messages", []):
        formatted_messages.append({
            "id": str(msg["_id"]),
            "content": msg["content"],
            "isFromUser": msg["isFromUser"],
            "timestamp": msg["timestamp"]
        })
    
    # Crear el diccionario final para ChatResponse
    response_data = {
        **updated_chat,
        "id": str(updated_chat["_id"]),
        "userId": str(updated_chat["userId"]),
        "vehicleId": str(updated_chat.get("vehicleId")) if updated_chat.get("vehicleId") else None,
        "messages": formatted_messages
    }
    
    # Validar y devolver
    try:
        return ChatResponse(**response_data)
    except ValidationError as e:
        logger.error(f"Error de validación al crear ChatResponse: {e.json()}") 
        raise HTTPException(status_code=500, detail="Error interno al formatear la respuesta del chat.")
