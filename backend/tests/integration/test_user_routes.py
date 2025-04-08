import pytest
from fastapi import status
from bson import ObjectId
import re

class TestUserRoutes:
    """Pruebas para las rutas de usuario"""

    async def test_register_user(self, client, test_db):
        """Prueba de registro de usuario con datos válidos"""
        user_data = {
            "username": "usuario_test",
            "email": "test@example.com",
            "password": "Password123!",
            "name": "Usuario Test"
        }
        
        # Enviar solicitud de registro
        response = client.post("/users/register", json=user_data)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_201_CREATED
        response_data = response.json()
        
        # Verificar datos del usuario devuelto (excepto el ID y password)
        assert response_data["username"] == user_data["username"]
        assert response_data["email"] == user_data["email"]
        assert response_data["name"] == user_data["name"]
        assert "id" in response_data
        assert "password" not in response_data  # La contraseña no debe devolverse
        
        # Verificar que el usuario está en la base de datos
        user_id = response_data["id"]
        db_user = await test_db.db.users.find_one({"_id": ObjectId(user_id)})
        assert db_user is not None
        
        # Limpiar después de la prueba
        await test_db.db.users.delete_one({"_id": ObjectId(user_id)})

    async def test_login_user(self, client, test_db):
        """Prueba de inicio de sesión de usuario con credenciales válidas"""
        # Crear un usuario para la prueba (con contraseña hasheada)
        from backend.core.security import get_password_hash
        
        user_data = {
            "username": "login_test",
            "email": "login@example.com",
            "password": get_password_hash("Password123!"),  # Contraseña hasheada
            "name": "Login Test"
        }
        
        user_result = await test_db.db.users.insert_one(user_data)
        user_id = str(user_result.inserted_id)
        
        # Datos para el inicio de sesión
        login_data = {
            "username": "login_test",
            "password": "Password123!"  # Contraseña sin hashear para la solicitud
        }
        
        # Enviar solicitud de inicio de sesión
        response = client.post("/users/login", data=login_data)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        response_data = response.json()
        
        # Verificar que la respuesta contiene el token de acceso
        assert "access_token" in response_data
        assert response_data["token_type"] == "bearer"
        
        # Verificar formato del token JWT
        token_pattern = r"^[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+\.?[A-Za-z0-9-_.+/=]*$"
        assert re.match(token_pattern, response_data["access_token"])
        
        # Limpiar después de la prueba
        await test_db.db.users.delete_one({"_id": ObjectId(user_id)})

    async def test_get_current_user(self, client, auth_headers, test_user):
        """Prueba para obtener información del usuario actual con token válido"""
        user_data, _ = test_user
        
        # Enviar solicitud para obtener usuario actual
        response = client.get("/users/me", headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        response_data = response.json()
        
        # Verificar que los datos del usuario coinciden
        assert response_data["id"] == user_data["id"]
        assert response_data["username"] == user_data["username"]
        assert response_data["email"] == user_data["email"]
        assert response_data["name"] == user_data["name"]
        assert "password" not in response_data  # La contraseña no debe devolverse

    async def test_update_user(self, client, auth_headers, test_db, test_user):
        """Prueba para actualizar información del usuario"""
        user_data, _ = test_user
        user_id = user_data["id"]
        
        # Datos actualizados
        update_data = {
            "name": "Nombre Actualizado",
            "email": "actualizado@example.com"
        }
        
        # Enviar solicitud de actualización
        response = client.put("/users/me", json=update_data, headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        response_data = response.json()
        
        # Verificar datos actualizados
        assert response_data["id"] == user_id
        assert response_data["name"] == update_data["name"]
        assert response_data["email"] == update_data["email"]
        assert response_data["username"] == user_data["username"]  # No cambia
        
        # Verificar actualización en la base de datos
        db_user = await test_db.db.users.find_one({"_id": ObjectId(user_id)})
        assert db_user["name"] == update_data["name"]
        assert db_user["email"] == update_data["email"]

    async def test_login_invalid_credentials(self, client, test_db):
        """Prueba de inicio de sesión con credenciales inválidas"""
        # Crear un usuario para la prueba (con contraseña hasheada)
        from backend.core.security import get_password_hash
        
        user_data = {
            "username": "invalid_login",
            "email": "invalid@example.com",
            "password": get_password_hash("CorrectPassword123!"),
            "name": "Invalid Login Test"
        }
        
        user_result = await test_db.db.users.insert_one(user_data)
        user_id = str(user_result.inserted_id)
        
        # Datos para el inicio de sesión con contraseña incorrecta
        login_data = {
            "username": "invalid_login",
            "password": "WrongPassword123!"
        }
        
        # Enviar solicitud de inicio de sesión
        response = client.post("/users/login", data=login_data)
        
        # Verificar respuesta de error
        assert response.status_code == status.HTTP_401_UNAUTHORIZED
        
        # Limpiar después de la prueba
        await test_db.db.users.delete_one({"_id": ObjectId(user_id)})

    async def test_register_duplicate_username(self, client, test_db):
        """Prueba de registro con nombre de usuario duplicado"""
        # Crear un usuario para la prueba
        user_data = {
            "username": "duplicate_user",
            "email": "original@example.com",
            "password": "Password123!",
            "name": "Original User"
        }
        
        # Registrar el primer usuario
        response1 = client.post("/users/register", json=user_data)
        assert response1.status_code == status.HTTP_201_CREATED
        user_id = response1.json()["id"]
        
        # Intentar registrar otro usuario con el mismo nombre de usuario
        duplicate_data = {
            "username": "duplicate_user",  # Mismo username
            "email": "different@example.com",
            "password": "Password123!",
            "name": "Duplicate User"
        }
        
        response2 = client.post("/users/register", json=duplicate_data)
        
        # Verificar respuesta de error
        assert response2.status_code == status.HTTP_400_BAD_REQUEST
        
        # Limpiar después de la prueba
        await test_db.db.users.delete_one({"_id": ObjectId(user_id)})

    async def test_unauthorized_access(self, client):
        """Prueba de acceso no autorizado a rutas protegidas"""
        # Intentar acceder sin token
        response = client.get("/users/me")
        
        # Verificar respuesta de error
        assert response.status_code == status.HTTP_401_UNAUTHORIZED
        
        # Intentar acceder con token inválido
        invalid_headers = {"Authorization": "Bearer invalid.token.here"}
        response = client.get("/users/me", headers=invalid_headers)
        
        # Verificar respuesta de error
        assert response.status_code == status.HTTP_401_UNAUTHORIZED 