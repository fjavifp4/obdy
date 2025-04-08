import pytest
from fastapi import status
from bson import ObjectId
import re

# Patrón para validar formato de token JWT
JWT_PATTERN = re.compile(r'^[A-Za-z0-9-_]+\.[A-Za-z0-9-_]+\.[A-Za-z0-9-_]+$')

class TestUserRoutes:
    """Pruebas para las rutas relacionadas con usuarios"""

    async def test_register_user(self, client, test_db):
        """Prueba el registro de un nuevo usuario"""
        # Datos de usuario para prueba
        test_user_data = {
            "username": "testregister",
            "email": "testregister@example.com",
            "password": "Password123!"
        }
        
        # Enviar solicitud de registro
        response = client.post("/users/register", json=test_user_data)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_201_CREATED
        
        # Verificar contenido de la respuesta
        data = response.json()
        assert "id" in data
        assert data["username"] == test_user_data["username"]
        assert data["email"] == test_user_data["email"]
        assert "password" not in data  # La contraseña no debe estar en la respuesta
        
        # Verificar que el usuario se haya creado en la base de datos
        user_in_db = await test_db.db.users.find_one({"_id": ObjectId(data["id"])})
        assert user_in_db is not None
        assert user_in_db["username"] == test_user_data["username"]
        assert user_in_db["email"] == test_user_data["email"]
        assert "hashed_password" in user_in_db  # La contraseña debe estar hasheada
        
        # Limpiar después de la prueba
        await test_db.db.users.delete_one({"_id": ObjectId(data["id"])})

    async def test_login_user(self, client, test_db):
        """Prueba el inicio de sesión de un usuario"""
        # Primero, registrar un usuario
        test_user_data = {
            "username": "testlogin",
            "email": "testlogin@example.com",
            "password": "Password123!"
        }
        
        register_response = client.post("/users/register", json=test_user_data)
        assert register_response.status_code == status.HTTP_201_CREATED
        user_id = register_response.json()["id"]
        
        # Datos para el inicio de sesión
        login_data = {
            "username": test_user_data["username"],
            "password": test_user_data["password"]
        }
        
        # Enviar solicitud de inicio de sesión
        response = client.post("/users/login", data=login_data)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        
        # Verificar contenido de la respuesta
        data = response.json()
        assert "access_token" in data
        assert "token_type" in data
        assert data["token_type"] == "bearer"
        
        # Verificar formato del token
        assert JWT_PATTERN.match(data["access_token"])
        
        # Limpiar después de la prueba
        await test_db.db.users.delete_one({"_id": ObjectId(user_id)})

    async def test_get_current_user(self, client, test_user, auth_headers):
        """Prueba obtener información del usuario actual"""
        # Enviar solicitud para obtener el usuario actual
        response = client.get("/users/me", headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        
        # Verificar contenido de la respuesta
        user_data, _ = test_user
        data = response.json()
        
        assert data["id"] == user_data["id"]
        assert data["username"] == user_data["username"]
        assert data["email"] == user_data["email"]
        assert "password" not in data

    async def test_update_user(self, client, test_user, auth_headers, test_db):
        """Prueba la actualización de información del usuario"""
        user_data, _ = test_user
        
        # Datos para actualizar
        update_data = {
            "email": "updated@example.com",
            "username": "updated_username"
        }
        
        # Enviar solicitud de actualización
        response = client.put("/users/me", json=update_data, headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        
        # Verificar contenido de la respuesta
        data = response.json()
        assert data["id"] == user_data["id"]
        assert data["username"] == update_data["username"]
        assert data["email"] == update_data["email"]
        
        # Verificar que los cambios se hayan guardado en la base de datos
        updated_user = await test_db.db.users.find_one({"_id": ObjectId(user_data["id"])})
        assert updated_user["username"] == update_data["username"]
        assert updated_user["email"] == update_data["email"]

    async def test_login_invalid_credentials(self, client):
        """Prueba el inicio de sesión con credenciales inválidas"""
        # Datos para el inicio de sesión con credenciales inválidas
        login_data = {
            "username": "nonexistent_user",
            "password": "InvalidPassword123!"
        }
        
        # Enviar solicitud de inicio de sesión
        response = client.post("/users/login", data=login_data)
        
        # Verificar respuesta de error
        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    async def test_register_duplicate_username(self, client, test_user):
        """Prueba el registro con un nombre de usuario duplicado"""
        user_data, _ = test_user
        
        # Datos para registro con nombre de usuario existente
        duplicate_user_data = {
            "username": user_data["username"],
            "email": "another_email@example.com",
            "password": "Password123!"
        }
        
        # Enviar solicitud de registro
        response = client.post("/users/register", json=duplicate_user_data)
        
        # Verificar respuesta de error
        assert response.status_code == status.HTTP_400_BAD_REQUEST

    async def test_unauthorized_access(self, client):
        """Prueba el acceso a rutas protegidas sin token o con token inválido"""
        # Acceso sin token
        response = client.get("/users/me")
        assert response.status_code == status.HTTP_401_UNAUTHORIZED
        
        # Acceso con token inválido
        invalid_headers = {"Authorization": "Bearer invalid_token"}
        response = client.get("/users/me", headers=invalid_headers)
        assert response.status_code == status.HTTP_401_UNAUTHORIZED 