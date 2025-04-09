import pytest
from fastapi.testclient import TestClient
from fastapi import status
from bson import ObjectId # Necesario para simular IDs

# Importar la función auxiliar
from ..conftest import create_user_and_get_token


def test_get_current_user_success(client: TestClient):
    """Testea obtener los datos del usuario autenticado correctamente."""
    token, user_id = create_user_and_get_token(client, "me_success")
    headers = {"Authorization": f"Bearer {token}"}
    
    response = client.get("/users/me", headers=headers)
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["email"] == "test_me_success@example.com"
    assert data["username"] == "testuser_me_success"
    assert data["id"] == user_id
    assert "password_hash" not in data # Asegurarse de que no se expone la contraseña hasheada

def test_get_current_user_unauthorized(client: TestClient):
    """Testea obtener los datos del usuario sin token."""
    response = client.get("/users/me")
    assert response.status_code == status.HTTP_401_UNAUTHORIZED # Esperamos 401 si no hay token
    assert response.json()["detail"] == "Not authenticated"

def test_update_user_success(client: TestClient):
    """Testea actualizar los datos del usuario correctamente."""
    token, user_id = create_user_and_get_token(client, "update_success")
    headers = {"Authorization": f"Bearer {token}"}
    new_username = "updated_username"
    
    update_payload = {"username": new_username}
    
    response = client.put(f"/users/{user_id}", headers=headers, json=update_payload)
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["username"] == new_username
    assert data["email"] == "test_update_success@example.com" # El email no debería cambiar
    assert data["id"] == user_id

    # Verificar que el cambio persiste
    get_response = client.get("/users/me", headers=headers)
    assert get_response.status_code == status.HTTP_200_OK
    assert get_response.json()["username"] == new_username

def test_update_other_user_forbidden(client: TestClient):
    """Testea que un usuario no puede modificar los datos de otro."""
    token1, user_id1 = create_user_and_get_token(client, "user1")
    token2, user_id2 = create_user_and_get_token(client, "user2") # Crear un segundo usuario
    
    headers1 = {"Authorization": f"Bearer {token1}"}
    update_payload = {"username": "hacked_username"}
    
    # Intentar que user1 modifique a user2
    response = client.put(f"/users/{user_id2}", headers=headers1, json=update_payload)
    
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert response.json()["detail"] == "No tienes permiso para modificar este usuario"

def test_update_user_not_found(client: TestClient):
    """Testea actualizar un usuario con un ID que no existe (resulta en 403)."""
    token, _ = create_user_and_get_token(client, "update_notfound")
    headers = {"Authorization": f"Bearer {token}"}
    non_existent_id = str(ObjectId()) # Generar un ObjectId válido pero inexistente
    
    update_payload = {"username": "irrelevant"}
    
    # En la implementación actual, si el token es válido pero el ID de la URL no coincide
    # con el ID del usuario del token, SIEMPRE dará 403.
    response = client.put(f"/users/{non_existent_id}", headers=headers, json=update_payload)
    assert response.status_code == status.HTTP_403_FORBIDDEN
    assert response.json()["detail"] == "No tienes permiso para modificar este usuario"

def test_update_user_invalid_id_format(client: TestClient):
    """Testea actualizar un usuario con un ID en formato inválido."""
    token, _ = create_user_and_get_token(client, "update_invalid_id")
    headers = {"Authorization": f"Bearer {token}"}
    invalid_id = "not-a-valid-objectid"
    
    update_payload = {"username": "irrelevant"}
    
    # FastAPI/Pydantic debería devolver un error de validación (422) si el ID no es válido
    # antes de que llegue a nuestra lógica de ruta que compara IDs.
    response = client.put(f"/users/{invalid_id}", headers=headers, json=update_payload)
    assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY 