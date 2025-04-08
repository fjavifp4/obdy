import pytest
from fastapi import status
from models.user import User

pytestmark = pytest.mark.asyncio

class TestAuthRoutes:
    """Pruebas para las rutas de autenticación"""

    async def test_register_user(self, client, test_db):
        """Prueba de registro de usuario con datos válidos"""
        # Datos para registrar un nuevo usuario
        user_data = {
            "username": "nuevo_usuario",
            "email": "nuevo@example.com",
            "password": "Contraseña123!"
        }

        # Enviar solicitud de registro
        response = client.post("/auth/register", json=user_data)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_201_CREATED
        response_data = response.json()
        
        # Verificar datos del usuario devuelto
        assert response_data["username"] == user_data["username"]
        assert response_data["email"] == user_data["email"]
        assert "id" in response_data
        assert "password" not in response_data
        
        # Verificar que el usuario está en la base de datos
        user_id = response_data["id"]
        db_user = await test_db.db.users.find_one({"_id": user_id})
        assert db_user is not None
        assert db_user["username"] == user_data["username"]
        assert db_user["email"] == user_data["email"]
        
        # Limpiar después de la prueba
        await test_db.db.users.delete_one({"_id": user_id})

    async def test_register_duplicate_email(self, client, test_user):
        """Prueba de registro con email duplicado"""
        user_data, _ = test_user
        
        # Intentar registrar un usuario con el mismo email
        duplicate_user = {
            "username": "otro_usuario",
            "email": user_data["email"],  # Email duplicado
            "password": "Contraseña123!"
        }

        # Enviar solicitud de registro
        response = client.post("/auth/register", json=duplicate_user)
        
        # Verificar que la respuesta es un error
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        response_data = response.json()
        
        # Verificar mensaje de error
        assert "email" in response_data["detail"].lower()

    async def test_login_success(self, client, test_db):
        """Prueba de login exitoso"""
        # Crear usuario con contraseña conocida para prueba
        from passlib.context import CryptContext
        pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
        
        password = "TestPassword123!"
        user_data = {
            "username": "login_test",
            "email": "login@example.com",
            "password": pwd_context.hash(password)
        }
        
        result = await test_db.db.users.insert_one(user_data)
        user_id = str(result.inserted_id)
        
        # Datos para login
        login_data = {
            "username": user_data["email"],
            "password": password
        }
        
        # Enviar solicitud de login
        response = client.post("/auth/login", data=login_data)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        response_data = response.json()
        
        # Verificar que hay un token de acceso
        assert "access_token" in response_data
        assert response_data["token_type"] == "bearer"
        
        # Limpiar después de la prueba
        await test_db.db.users.delete_one({"_id": result.inserted_id})

    async def test_login_invalid_credentials(self, client, test_user):
        """Prueba de login con credenciales inválidas"""
        user_data, _ = test_user
        
        # Datos con contraseña incorrecta
        login_data = {
            "username": user_data["email"],
            "password": "ContraseñaIncorrecta123!"
        }
        
        # Enviar solicitud de login
        response = client.post("/auth/login", data=login_data)
        
        # Verificar respuesta de error
        assert response.status_code == status.HTTP_401_UNAUTHORIZED
        response_data = response.json()
        
        # Verificar mensaje de error
        assert "credenciales" in response_data["detail"].lower() or "credentials" in response_data["detail"].lower()

    async def test_me_endpoint(self, client, auth_headers, test_user):
        """Prueba del endpoint /me para obtener información del usuario autenticado"""
        user_data, _ = test_user
        
        # Enviar solicitud al endpoint /me con token de autenticación
        response = client.get("/auth/me", headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        response_data = response.json()
        
        # Verificar datos del usuario
        assert response_data["id"] == user_data["id"]
        assert response_data["username"] == user_data["username"]
        assert response_data["email"] == user_data["email"]
        assert "password" not in response_data

    async def test_unauthorized_access(self, client):
        """Prueba de acceso no autorizado a un endpoint protegido"""
        # Intentar acceder al endpoint /me sin autenticación
        response = client.get("/auth/me")
        
        # Verificar respuesta de error
        assert response.status_code == status.HTTP_401_UNAUTHORIZED 