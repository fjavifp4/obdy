import pytest
from fastapi import status
from bson import ObjectId
import json

class TestVehicleRoutes:
    """Pruebas para las rutas relacionadas con vehículos"""

    async def test_create_vehicle(self, client, test_user, auth_headers, test_db):
        """Prueba la creación de un nuevo vehículo"""
        user_data, _ = test_user
        
        # Datos del vehículo para prueba
        test_vehicle_data = {
            "brand": "Toyota",
            "model": "Corolla",
            "year": 2020,
            "license_plate": "ABC123",
            "fuel_type": "gasoline",
            "kilometers": 5000,
            "maintenance_records": []
        }
        
        # Enviar solicitud para crear vehículo
        response = client.post("/vehicles/", json=test_vehicle_data, headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_201_CREATED
        
        # Verificar contenido de la respuesta
        data = response.json()
        assert "id" in data
        assert data["brand"] == test_vehicle_data["brand"]
        assert data["model"] == test_vehicle_data["model"]
        assert data["license_plate"] == test_vehicle_data["license_plate"]
        assert data["user_id"] == user_data["id"]
        
        # Verificar que el vehículo se haya creado en la base de datos
        vehicle_in_db = await test_db.db.vehicles.find_one({"_id": ObjectId(data["id"])})
        assert vehicle_in_db is not None
        assert vehicle_in_db["brand"] == test_vehicle_data["brand"]
        assert vehicle_in_db["model"] == test_vehicle_data["model"]
        assert vehicle_in_db["user_id"] == ObjectId(user_data["id"])
        
        # Limpiar después de la prueba
        await test_db.db.vehicles.delete_one({"_id": ObjectId(data["id"])})

    async def test_get_user_vehicles(self, client, test_user, test_vehicle, auth_headers):
        """Prueba obtener todos los vehículos de un usuario"""
        user_data, _ = test_user
        vehicle_data, _ = test_vehicle
        
        # Enviar solicitud para obtener vehículos del usuario
        response = client.get("/vehicles/", headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        
        # Verificar contenido de la respuesta
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 1  # Al menos debería estar el vehículo de prueba
        
        # Buscar el vehículo de prueba en la lista
        found = False
        for vehicle in data:
            if vehicle["id"] == vehicle_data["id"]:
                found = True
                assert vehicle["brand"] == vehicle_data["brand"]
                assert vehicle["model"] == vehicle_data["model"]
                assert vehicle["license_plate"] == vehicle_data["license_plate"]
                assert vehicle["user_id"] == user_data["id"]
                break
        
        assert found, "No se encontró el vehículo de prueba en la respuesta"

    async def test_get_vehicle_by_id(self, client, test_vehicle, auth_headers):
        """Prueba obtener un vehículo específico por ID"""
        vehicle_data, _ = test_vehicle
        
        # Enviar solicitud para obtener el vehículo por ID
        response = client.get(f"/vehicles/{vehicle_data['id']}", headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        
        # Verificar contenido de la respuesta
        data = response.json()
        assert data["id"] == vehicle_data["id"]
        assert data["brand"] == vehicle_data["brand"]
        assert data["model"] == vehicle_data["model"]
        assert data["license_plate"] == vehicle_data["license_plate"]

    async def test_update_vehicle(self, client, test_vehicle, auth_headers, test_db):
        """Prueba la actualización de un vehículo"""
        vehicle_data, _ = test_vehicle
        
        # Datos para actualizar
        update_data = {
            "brand": "Honda",
            "model": "Civic",
            "license_plate": "XYZ789",
            "year": 2022,
            "kilometers": 10000
        }
        
        # Enviar solicitud de actualización
        response = client.put(f"/vehicles/{vehicle_data['id']}", json=update_data, headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        
        # Verificar contenido de la respuesta
        data = response.json()
        assert data["id"] == vehicle_data["id"]
        assert data["brand"] == update_data["brand"]
        assert data["model"] == update_data["model"]
        assert data["license_plate"] == update_data["license_plate"]
        assert data["kilometers"] == update_data["kilometers"]
        
        # Verificar que los cambios se hayan guardado en la base de datos
        updated_vehicle = await test_db.db.vehicles.find_one({"_id": ObjectId(vehicle_data["id"])})
        assert updated_vehicle["brand"] == update_data["brand"]
        assert updated_vehicle["model"] == update_data["model"]
        assert updated_vehicle["license_plate"] == update_data["license_plate"]
        assert updated_vehicle["kilometers"] == update_data["kilometers"]

    async def test_delete_vehicle(self, client, test_user, auth_headers, test_db):
        """Prueba la eliminación de un vehículo"""
        # Crear un vehículo específico para eliminar
        user_data, _ = test_user
        
        test_vehicle_data = {
            "brand": "Ford",
            "model": "Focus",
            "year": 2019,
            "license_plate": "DEL123",
            "fuel_type": "gasoline",
            "kilometers": 15000,
            "maintenance_records": []
        }
        
        # Crear el vehículo
        create_response = client.post("/vehicles/", json=test_vehicle_data, headers=auth_headers)
        assert create_response.status_code == status.HTTP_201_CREATED
        vehicle_id = create_response.json()["id"]
        
        # Enviar solicitud para eliminar el vehículo
        response = client.delete(f"/vehicles/{vehicle_id}", headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_204_NO_CONTENT
        
        # Verificar que el vehículo haya sido eliminado de la base de datos
        deleted_vehicle = await test_db.db.vehicles.find_one({"_id": ObjectId(vehicle_id)})
        assert deleted_vehicle is None

    async def test_get_nonexistent_vehicle(self, client, auth_headers):
        """Prueba obtener un vehículo que no existe"""
        # ID de un vehículo que no existe
        nonexistent_id = str(ObjectId())
        
        # Enviar solicitud para obtener un vehículo que no existe
        response = client.get(f"/vehicles/{nonexistent_id}", headers=auth_headers)
        
        # Verificar respuesta de error
        assert response.status_code == status.HTTP_404_NOT_FOUND

    async def test_update_nonexistent_vehicle(self, client, auth_headers):
        """Prueba actualizar un vehículo que no existe"""
        # ID de un vehículo que no existe
        nonexistent_id = str(ObjectId())
        
        # Datos para actualizar
        update_data = {
            "brand": "Nissan",
            "model": "Juke",
            "license_plate": "UPD123"
        }
        
        # Enviar solicitud para actualizar un vehículo que no existe
        response = client.put(f"/vehicles/{nonexistent_id}", json=update_data, headers=auth_headers)
        
        # Verificar respuesta de error
        assert response.status_code == status.HTTP_404_NOT_FOUND

    async def test_unauthorized_vehicle_access(self, client, test_vehicle):
        """Prueba acceder a un vehículo sin autenticación"""
        vehicle_data, _ = test_vehicle
        
        # Enviar solicitud sin token de autenticación
        response = client.get(f"/vehicles/{vehicle_data['id']}")
        
        # Verificar respuesta de error
        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    async def test_access_other_user_vehicle(self, client, test_vehicle):
        """Prueba acceder al vehículo de otro usuario"""
        vehicle_data, _ = test_vehicle
        
        # Crear un nuevo usuario para la prueba
        other_user_data = {
            "username": "otheruser",
            "email": "otheruser@example.com",
            "password": "Password123!"
        }
        
        # Registrar el usuario
        register_response = client.post("/users/register", json=other_user_data)
        assert register_response.status_code == status.HTTP_201_CREATED
        
        # Iniciar sesión con el nuevo usuario
        login_data = {
            "username": other_user_data["username"],
            "password": other_user_data["password"]
        }
        
        login_response = client.post("/users/login", data=login_data)
        assert login_response.status_code == status.HTTP_200_OK
        
        # Obtener token de acceso
        token = login_response.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # Intentar acceder al vehículo del otro usuario
        response = client.get(f"/vehicles/{vehicle_data['id']}", headers=headers)
        
        # Verificar respuesta de error (no debería poder acceder)
        assert response.status_code == status.HTTP_404_NOT_FOUND 