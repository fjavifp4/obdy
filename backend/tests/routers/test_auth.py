import pytest
from fastapi.testclient import TestClient
from fastapi import status

# Importar la función auxiliar desde conftest
from ..conftest import create_user_and_get_token 

# No es necesario importar la app o db aquí, conftest se encarga

def test_register_user_success(client: TestClient):
    """Testea el registro exitoso de un nuevo usuario."""
    response = client.post(
        "/auth/register",
        json={"username": "testuser", "email": "test@example.com", "password": "password123"}
    )
    assert response.status_code == status.HTTP_201_CREATED
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"

def test_register_user_existing_email(client: TestClient):
    """Testea el registro con un email que ya existe."""
    # Primero registra un usuario
    client.post(
        "/auth/register",
        json={"username": "testuser2", "email": "test2@example.com", "password": "password123"}
    )
    # Intenta registrar de nuevo con el mismo email
    response = client.post(
        "/auth/register",
        json={"username": "anotheruser", "email": "test2@example.com", "password": "anotherpassword"}
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "Email ya registrado" in response.json()["detail"]

def test_login_success(client: TestClient):
    """Testea el login exitoso."""
    # Registrar primero
    email = "login@example.com"
    password = "password123"
    client.post(
        "/auth/register",
        json={"username": "loginuser", "email": email, "password": password}
    )
    # Intentar login
    response = client.post(
        "/auth/login",
        data={"username": email, "password": password} # FastAPI espera form data para OAuth2PasswordRequestForm
    )
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"

def test_login_wrong_password(client: TestClient):
    """Testea el login con contraseña incorrecta."""
    # Registrar primero
    email = "wrongpass@example.com"
    password = "password123"
    client.post(
        "/auth/register",
        json={"username": "wrongpassuser", "email": email, "password": password}
    )
    # Intentar login con contraseña incorrecta
    response = client.post(
        "/auth/login",
        data={"username": email, "password": "wrongpassword"}
    )
    assert response.status_code == status.HTTP_401_UNAUTHORIZED
    assert "Credenciales incorrectas" in response.json()["detail"]

def test_login_nonexistent_user(client: TestClient):
    """Testea el login con un usuario que no existe."""
    response = client.post(
        "/auth/login",
        data={"username": "nonexistent@example.com", "password": "password123"}
    )
    assert response.status_code == status.HTTP_401_UNAUTHORIZED
    assert "Credenciales incorrectas" in response.json()["detail"] # La ruta devuelve este mensaje para usuario no encontrado también

# --- Tests para /change-password --- 

def test_change_password_success(client: TestClient):
    """Testea el cambio de contraseña exitoso."""
    old_password = "password123"
    new_password = "newpassword456"
    # Crear usuario y obtener token
    token, _ = create_user_and_get_token(client, "changepw_success") 
    headers = {"Authorization": f"Bearer {token}"}
    
    # Cambiar contraseña
    response = client.put(
        "/auth/change-password",
        headers=headers,
        json={"current_password": old_password, "new_password": new_password}
    )
    assert response.status_code == status.HTTP_200_OK
    assert response.json() == {"message": "Contraseña actualizada correctamente"}

    # Verificar que se puede hacer login con la nueva contraseña
    user_email = "test_changepw_success@example.com" # Email usado en create_user_and_get_token
    login_response = client.post(
        "/auth/login",
        data={"username": user_email, "password": new_password}
    )
    assert login_response.status_code == status.HTTP_200_OK
    assert "access_token" in login_response.json()

    # Verificar que NO se puede hacer login con la contraseña antigua
    login_response_old = client.post(
        "/auth/login",
        data={"username": user_email, "password": old_password}
    )
    assert login_response_old.status_code == status.HTTP_401_UNAUTHORIZED

def test_change_password_wrong_current(client: TestClient):
    """Testea el cambio de contraseña con la contraseña actual incorrecta."""
    old_password = "password123"
    new_password = "newpassword456"
    # Crear usuario y obtener token
    token, _ = create_user_and_get_token(client, "changepw_wrongcurr") 
    headers = {"Authorization": f"Bearer {token}"}
    
    # Intentar cambiar contraseña con current_password incorrecta
    response = client.put(
        "/auth/change-password",
        headers=headers,
        json={"current_password": "incorrect_old_password", "new_password": new_password}
    )
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "Contraseña actual incorrecta" in response.json()["detail"]

def test_change_password_unauthorized(client: TestClient):
    """Testea el cambio de contraseña sin token de autenticación."""
    # No crear usuario ni token
    response = client.put(
        "/auth/change-password",
        json={"current_password": "any", "new_password": "any"}
    )
    assert response.status_code == status.HTTP_401_UNAUTHORIZED
    assert "Not authenticated" in response.json()["detail"] # Esperamos el error estándar de FastAPI 