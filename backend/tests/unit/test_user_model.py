import pytest
from bson import ObjectId
from models.user import User

pytestmark = pytest.mark.asyncio

class TestUserModel:
    
    async def test_create_user(self, test_db):
        """Probar la creación de un usuario"""
        # Datos para el usuario de prueba
        user_data = {
            "username": "nuevo_usuario",
            "email": "nuevo@example.com",
            "password_hash": "hashed_password"
        }
        
        # Crear un nuevo usuario
        user = User(**user_data)
        
        # Verificar que los atributos sean correctos
        assert user.username == user_data["username"]
        assert user.email == user_data["email"]
        assert user.password_hash == user_data["password_hash"]
        
        # Insertar en la base de datos
        result = await test_db.db.users.insert_one(user.__dict__)
        inserted_id = result.inserted_id
        
        # Verificar que se insertó correctamente
        assert result.acknowledged
        
        # Recuperar de la base de datos
        retrieved_user = await test_db.db.users.find_one({"_id": inserted_id})
        
        # Verificar que los datos son los mismos
        assert retrieved_user["username"] == user_data["username"]
        assert retrieved_user["email"] == user_data["email"]
        assert retrieved_user["password_hash"] == user_data["password_hash"]
        
        # Limpiar después de la prueba
        await test_db.db.users.delete_one({"_id": inserted_id})
    
    async def test_find_by_email(self, test_db):
        """Probar el método find_by_email"""
        # Datos para el usuario de prueba
        user_data = {
            "username": "usuario_email",
            "email": "email_test@example.com",
            "password_hash": "hashed_password"
        }
        
        # Crear e insertar usuario
        user = User(**user_data)
        result = await test_db.db.users.insert_one(user.__dict__)
        
        # Usar el método find_by_email
        found_user = await User.find_by_email(test_db.db, user_data["email"])
        
        # Verificar que se encontró el usuario correcto
        assert found_user is not None
        assert found_user.email == user_data["email"]
        
        # Limpiar
        await test_db.db.users.delete_one({"_id": result.inserted_id})
    
    async def test_find_by_id(self, test_db):
        """Probar el método find_by_id"""
        # Datos para el usuario de prueba
        user_data = {
            "username": "usuario_id",
            "email": "id_test@example.com",
            "password_hash": "hashed_password"
        }
        
        # Crear e insertar usuario
        user = User(**user_data)
        result = await test_db.db.users.insert_one(user.__dict__)
        user_id = result.inserted_id
        
        # Usar el método find_by_id
        found_user = await User.find_by_id(test_db.db, str(user_id))
        
        # Verificar que se encontró el usuario correcto
        assert found_user is not None
        assert found_user.email == user_data["email"]
        assert str(found_user._id) == str(user_id)
        
        # Limpiar
        await test_db.db.users.delete_one({"_id": user_id})
    
    async def test_user_not_found(self, test_db):
        """Probar que los métodos devuelven None cuando no se encuentra el usuario"""
        # ID inexistente
        non_existent_id = ObjectId()
        user = await User.find_by_id(test_db.db, str(non_existent_id))
        assert user is None
        
        # Email inexistente
        user = await User.find_by_email(test_db.db, "no_existe@example.com")
        assert user is None 