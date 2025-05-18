import pytest
from fastapi.testclient import TestClient
from fastapi import status
from bson import ObjectId

# Importar la función auxiliar y datos de ejemplo de vehículos
from ..conftest import create_user_and_get_token
from .test_vehicles import VEHICLE_DATA_1 # Necesitamos crear un vehículo

# --- Mocking Setup --- 
MOCKED_LLM_RESPONSE = "Soy una respuesta mockeada del LLM."

@pytest.fixture(autouse=True) # Aplicar a todos los tests de este módulo
def mock_llm_response(mocker):
    """Mockea la función get_llm_response para evitar llamadas reales a OpenRouter."""
    # La ruta a parchear es relativa a donde se llama la función
    return mocker.patch("routers.chats.get_llm_response", return_value=MOCKED_LLM_RESPONSE)

# --- Tests para POST /chats (create_or_retrieve) --- 

def test_create_or_retrieve_chat_no_vehicle(client: TestClient):
    token, user_id = create_user_and_get_token(client, "chat_no_vehicle")
    headers = {"Authorization": f"Bearer {token}"}
    
    # Primera llamada: crear
    response_create = client.post("/chats", headers=headers, json={"vehicleId": None})
    assert response_create.status_code == status.HTTP_200_OK # La ruta devuelve 200 OK
    data_create = response_create.json()
    assert data_create["userId"] == user_id
    assert data_create["vehicleId"] is None
    assert data_create["messages"] == []
    chat_id = data_create["id"]

    # Segunda llamada: obtener
    response_retrieve = client.post("/chats", headers=headers, json={"vehicleId": None})
    assert response_retrieve.status_code == status.HTTP_200_OK
    data_retrieve = response_retrieve.json()
    assert data_retrieve["id"] == chat_id # Debe ser el mismo chat
    assert data_retrieve["userId"] == user_id
    assert data_retrieve["vehicleId"] is None

def test_create_or_retrieve_chat_with_vehicle(client: TestClient):
    token, user_id = create_user_and_get_token(client, "chat_with_vehicle")
    headers = {"Authorization": f"Bearer {token}"}
    
    # Crear un vehículo primero
    vehicle_create_response = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    assert vehicle_create_response.status_code == status.HTTP_201_CREATED
    vehicle_id = vehicle_create_response.json()["id"]

    # Primera llamada: crear chat para el vehículo
    response_create = client.post("/chats", headers=headers, json={"vehicleId": vehicle_id})
    assert response_create.status_code == status.HTTP_200_OK
    data_create = response_create.json()
    assert data_create["userId"] == user_id
    assert data_create["vehicleId"] == vehicle_id
    assert data_create["messages"] == []
    chat_id = data_create["id"]

    # Hacer login con las mismas credenciales para obtener un token fresco
    login_response = client.post(
        "/auth/login",
        data={"username": f"test_chat_with_vehicle@example.com", "password": "password123"}
    )
    assert login_response.status_code == status.HTTP_200_OK
    token_fresh = login_response.json()["access_token"]
    headers_fresh = {"Authorization": f"Bearer {token_fresh}"}
    
    # Segunda llamada: obtener el mismo chat
    response_retrieve = client.post("/chats", headers=headers_fresh, json={"vehicleId": vehicle_id})
    assert response_retrieve.status_code == status.HTTP_200_OK
    data_retrieve = response_retrieve.json()
    assert data_retrieve["id"] == chat_id
    assert data_retrieve["userId"] == user_id
    assert data_retrieve["vehicleId"] == vehicle_id

def test_create_chat_invalid_vehicle_id(client: TestClient):
    token, _ = create_user_and_get_token(client, "chat_invalid_vehicle")
    headers = {"Authorization": f"Bearer {token}"}
    invalid_vehicle_id = str(ObjectId()) # ID válido pero no existente

    response = client.post("/chats", headers=headers, json={"vehicleId": invalid_vehicle_id})
    # La lógica actual intenta buscar el vehículo. Si no lo encuentra, 
    # simplemente no añade contexto de vehículo, pero crea el chat igual (devuelve 200).
    # Si el ID fuera inválido en formato, podría dar 400.
    # Ajustamos la expectativa a 200 OK según la lógica vista.
    assert response.status_code == status.HTTP_200_OK 
    data = response.json()
    assert data["vehicleId"] == invalid_vehicle_id # Guarda el ID aunque no encuentre vehículo

# --- Tests para POST /chats/{chat_id}/messages --- 

def test_add_message_success_no_vehicle(client: TestClient, mock_llm_response):
    token, _ = create_user_and_get_token(client, "msg_no_vehicle")
    headers = {"Authorization": f"Bearer {token}"}
    
    create_chat_response = client.post("/chats", headers=headers, json={"vehicleId": None})
    chat_id = create_chat_response.json()["id"]
    
    user_message = {"content": "Hola"}
    response = client.post(f"/chats/{chat_id}/messages", headers=headers, json=user_message)
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["id"] == chat_id
    assert len(data["messages"]) == 2 # Mensaje usuario + respuesta LLM mockeada
    
    # La API devuelve en orden cronológico (más antiguo primero)
    assert data["messages"][0]["content"] == user_message["content"]
    assert data["messages"][0]["isFromUser"] is True
    assert data["messages"][1]["content"] == MOCKED_LLM_RESPONSE
    assert data["messages"][1]["isFromUser"] is False
    
    mock_llm_response.assert_called_once()

def test_add_message_success_with_vehicle(client: TestClient, mock_llm_response):
    token, _ = create_user_and_get_token(client, "msg_with_vehicle")
    headers = {"Authorization": f"Bearer {token}"}
    
    vehicle_create_response = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    vehicle_id = vehicle_create_response.json()["id"]

    create_chat_response = client.post("/chats", headers=headers, json={"vehicleId": vehicle_id})
    chat_id = create_chat_response.json()["id"]

    user_message = {"content": "¿Cuándo toca el aceite?"}
    response = client.post(f"/chats/{chat_id}/messages", headers=headers, json=user_message)
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["id"] == chat_id
    assert len(data["messages"]) == 2
    
    # La API devuelve en orden cronológico (más antiguo primero)
    assert data["messages"][0]["content"] == user_message["content"]
    assert data["messages"][0]["isFromUser"] is True
    assert data["messages"][1]["content"] == MOCKED_LLM_RESPONSE
    assert data["messages"][1]["isFromUser"] is False
    
    mock_llm_response.assert_called_once()
    call_args, _ = mock_llm_response.call_args
    sent_messages = call_args[0]
    assert any(m["role"] == "system" and VEHICLE_DATA_1["brand"] in m["content"] for m in sent_messages)
    assert any(m["role"] == "user" and m["content"] == user_message["content"] for m in sent_messages)

def test_add_message_chat_not_found(client: TestClient):
    token, _ = create_user_and_get_token(client, "msg_chat_notfound")
    headers = {"Authorization": f"Bearer {token}"}
    non_existent_chat_id = str(ObjectId())
    user_message = {"content": "Hola"}

    response = client.post(f"/chats/{non_existent_chat_id}/messages", headers=headers, json=user_message)
    assert response.status_code == status.HTTP_404_NOT_FOUND

def test_add_message_chat_forbidden(client: TestClient):
    # Usuario 1 crea un chat
    token1, _ = create_user_and_get_token(client, "msg_chat_forbidden1")
    headers1 = {"Authorization": f"Bearer {token1}"}
    create_chat_response = client.post("/chats", headers=headers1, json={"vehicleId": None})
    chat_id1 = create_chat_response.json()["id"]

    # Usuario 2 intenta mandar mensaje al chat de Usuario 1
    token2, _ = create_user_and_get_token(client, "msg_chat_forbidden2")
    headers2 = {"Authorization": f"Bearer {token2}"}
    user_message = {"content": "Intruso"}

    response = client.post(f"/chats/{chat_id1}/messages", headers=headers2, json=user_message)
    assert response.status_code == status.HTTP_404_NOT_FOUND # La ruta devuelve 404 si user ID no coincide

# --- Tests para POST /chats/{chat_id}/clear --- 

def test_clear_chat_success(client: TestClient):
    token, _ = create_user_and_get_token(client, "clear_chat")
    headers = {"Authorization": f"Bearer {token}"}
    
    # Crear chat y añadir mensaje
    create_chat_response = client.post("/chats", headers=headers, json={"vehicleId": None})
    chat_id = create_chat_response.json()["id"]
    client.post(f"/chats/{chat_id}/messages", headers=headers, json={"content": "Mensaje 1"})
    client.post(f"/chats/{chat_id}/messages", headers=headers, json={"content": "Mensaje 2"})

    # Verificar que hay mensajes
    get_response = client.post("/chats", headers=headers, json={"vehicleId": None}) # Recupera el chat
    assert len(get_response.json()["messages"]) > 0 

    # Limpiar chat
    clear_response = client.post(f"/chats/{chat_id}/clear", headers=headers)
    assert clear_response.status_code == status.HTTP_200_OK
    
    # Verificar que la respuesta contiene el chat actualizado con mensajes vacíos
    response_data = clear_response.json()
    assert "id" in response_data
    assert "userId" in response_data
    assert "messages" in response_data
    assert len(response_data["messages"]) == 0

    # Verificar que no hay mensajes
    get_response_after = client.post("/chats", headers=headers, json={"vehicleId": None})
    assert len(get_response_after.json()["messages"]) == 0

def test_clear_chat_not_found(client: TestClient):
    token, _ = create_user_and_get_token(client, "clear_chat_notfound")
    headers = {"Authorization": f"Bearer {token}"}
    non_existent_chat_id = str(ObjectId())

    response = client.post(f"/chats/{non_existent_chat_id}/clear", headers=headers)
    assert response.status_code == status.HTTP_404_NOT_FOUND

def test_clear_chat_forbidden(client: TestClient):
    # Usuario 1 crea un chat
    token1, _ = create_user_and_get_token(client, "clear_chat_forbidden1")
    headers1 = {"Authorization": f"Bearer {token1}"}
    create_chat_response = client.post("/chats", headers=headers1, json={"vehicleId": None})
    chat_id1 = create_chat_response.json()["id"]

    # Usuario 2 intenta limpiar el chat de Usuario 1
    token2, _ = create_user_and_get_token(client, "clear_chat_forbidden2")
    headers2 = {"Authorization": f"Bearer {token2}"}

    response = client.post(f"/chats/{chat_id1}/clear", headers=headers2)
    assert response.status_code == status.HTTP_404_NOT_FOUND # La ruta devuelve 404
