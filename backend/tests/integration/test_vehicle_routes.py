import pytest
from fastapi import status
from bson import ObjectId

class TestVehicleRoutes:
    """Pruebas para las rutas de vehículos"""

    async def test_create_vehicle(self, client, auth_headers, test_db):
        """Prueba de creación de un vehículo con datos válidos"""
        # Datos para crear un nuevo vehículo
        vehicle_data = {
            "brand": "Toyota",
            "model": "Corolla",
            "year": 2020,
            "license_plate": "ABC123",
            "initial_km": 10000,
            "current_km": 10000,
            "fuel_type": "Gasolina"
        }

        # Enviar solicitud de creación
        response = client.post("/vehicles/", json=vehicle_data, headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_201_CREATED
        response_data = response.json()
        
        # Verificar datos del vehículo devuelto
        assert response_data["brand"] == vehicle_data["brand"]
        assert response_data["model"] == vehicle_data["model"]
        assert response_data["year"] == vehicle_data["year"]
        assert response_data["license_plate"] == vehicle_data["license_plate"]
        assert response_data["initial_km"] == vehicle_data["initial_km"]
        assert response_data["current_km"] == vehicle_data["current_km"]
        assert response_data["fuel_type"] == vehicle_data["fuel_type"]
        assert "id" in response_data
        
        # Verificar que el vehículo está en la base de datos
        vehicle_id = response_data["id"]
        db_vehicle = await test_db.db.vehicles.find_one({"_id": vehicle_id})
        assert db_vehicle is not None
        
        # Limpiar después de la prueba
        await test_db.db.vehicles.delete_one({"_id": vehicle_id})

    async def test_get_vehicles(self, client, auth_headers, test_db, test_user):
        """Prueba para obtener todos los vehículos del usuario"""
        user_data, _ = test_user
        user_id = user_data["id"]
        
        # Crear dos vehículos para el usuario de prueba
        vehicle1 = {
            "brand": "Ford",
            "model": "Focus",
            "year": 2019,
            "license_plate": "XYZ789",
            "initial_km": 5000,
            "current_km": 7500,
            "fuel_type": "Diésel",
            "user_id": user_id
        }
        
        vehicle2 = {
            "brand": "Honda",
            "model": "Civic",
            "year": 2021,
            "license_plate": "DEF456",
            "initial_km": 0,
            "current_km": 1200,
            "fuel_type": "Gasolina",
            "user_id": user_id
        }
        
        result1 = await test_db.db.vehicles.insert_one(vehicle1)
        result2 = await test_db.db.vehicles.insert_one(vehicle2)
        
        # Guardar IDs para limpieza posterior
        vehicle_id1 = str(result1.inserted_id)
        vehicle_id2 = str(result2.inserted_id)
        
        # Obtener vehículos del usuario
        response = client.get("/vehicles/", headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        vehicles = response.json()
        
        # Verificar que se devuelven los vehículos correctos
        assert len(vehicles) == 2
        vehicles_brands = [v["brand"] for v in vehicles]
        assert "Ford" in vehicles_brands
        assert "Honda" in vehicles_brands
        
        # Limpiar después de la prueba
        await test_db.db.vehicles.delete_many({
            "_id": {"$in": [ObjectId(vehicle_id1), ObjectId(vehicle_id2)]}
        })

    async def test_get_vehicle_by_id(self, client, auth_headers, test_db, test_user):
        """Prueba para obtener un vehículo específico por su ID"""
        user_data, _ = test_user
        user_id = user_data["id"]
        
        # Crear un vehículo para el usuario de prueba
        vehicle = {
            "brand": "Volkswagen",
            "model": "Golf",
            "year": 2018,
            "license_plate": "VWG123",
            "initial_km": 20000,
            "current_km": 35000,
            "fuel_type": "Gasolina",
            "user_id": user_id
        }
        
        result = await test_db.db.vehicles.insert_one(vehicle)
        vehicle_id = str(result.inserted_id)
        
        # Obtener el vehículo por ID
        response = client.get(f"/vehicles/{vehicle_id}", headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        response_data = response.json()
        
        # Verificar datos del vehículo
        assert response_data["id"] == vehicle_id
        assert response_data["brand"] == vehicle["brand"]
        assert response_data["model"] == vehicle["model"]
        assert response_data["year"] == vehicle["year"]
        assert response_data["license_plate"] == vehicle["license_plate"]
        
        # Limpiar después de la prueba
        await test_db.db.vehicles.delete_one({"_id": ObjectId(vehicle_id)})

    async def test_update_vehicle(self, client, auth_headers, test_db, test_user):
        """Prueba para actualizar un vehículo existente"""
        user_data, _ = test_user
        user_id = user_data["id"]
        
        # Crear un vehículo para actualizar
        vehicle = {
            "brand": "Mazda",
            "model": "3",
            "year": 2017,
            "license_plate": "MZD345",
            "initial_km": 15000,
            "current_km": 42000,
            "fuel_type": "Gasolina",
            "user_id": user_id
        }
        
        result = await test_db.db.vehicles.insert_one(vehicle)
        vehicle_id = str(result.inserted_id)
        
        # Datos actualizados
        update_data = {
            "current_km": 45000,
            "license_plate": "MZD999"
        }
        
        # Enviar solicitud de actualización
        response = client.put(f"/vehicles/{vehicle_id}", json=update_data, headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        response_data = response.json()
        
        # Verificar datos actualizados
        assert response_data["id"] == vehicle_id
        assert response_data["brand"] == vehicle["brand"]  # No cambia
        assert response_data["model"] == vehicle["model"]  # No cambia
        assert response_data["current_km"] == update_data["current_km"]  # Actualizado
        assert response_data["license_plate"] == update_data["license_plate"]  # Actualizado
        
        # Verificar actualización en la base de datos
        db_vehicle = await test_db.db.vehicles.find_one({"_id": ObjectId(vehicle_id)})
        assert db_vehicle["current_km"] == update_data["current_km"]
        assert db_vehicle["license_plate"] == update_data["license_plate"]
        
        # Limpiar después de la prueba
        await test_db.db.vehicles.delete_one({"_id": ObjectId(vehicle_id)})

    async def test_delete_vehicle(self, client, auth_headers, test_db, test_user):
        """Prueba para eliminar un vehículo"""
        user_data, _ = test_user
        user_id = user_data["id"]
        
        # Crear un vehículo para eliminar
        vehicle = {
            "brand": "Seat",
            "model": "Ibiza",
            "year": 2016,
            "license_plate": "IBZ123",
            "initial_km": 30000,
            "current_km": 80000,
            "fuel_type": "Diésel",
            "user_id": user_id
        }
        
        result = await test_db.db.vehicles.insert_one(vehicle)
        vehicle_id = str(result.inserted_id)
        
        # Verificar que el vehículo existe
        assert await test_db.db.vehicles.find_one({"_id": ObjectId(vehicle_id)}) is not None
        
        # Enviar solicitud de eliminación
        response = client.delete(f"/vehicles/{vehicle_id}", headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_204_NO_CONTENT
        
        # Verificar que el vehículo ya no existe en la base de datos
        assert await test_db.db.vehicles.find_one({"_id": ObjectId(vehicle_id)}) is None

    async def test_unauthorized_vehicle_access(self, client, test_db, test_user, auth_headers):
        """Prueba para verificar que un usuario no puede acceder a vehículos de otro usuario"""
        user_data, _ = test_user
        
        # Crear otro usuario para esta prueba
        other_user = {
            "username": "otro_usuario",
            "email": "otro@example.com",
            "password": "hashed_password"
        }
        other_user_result = await test_db.db.users.insert_one(other_user)
        other_user_id = str(other_user_result.inserted_id)
        
        # Crear un vehículo para el otro usuario
        vehicle = {
            "brand": "Audi",
            "model": "A3",
            "year": 2022,
            "license_plate": "AUD456",
            "initial_km": 0,
            "current_km": 500,
            "fuel_type": "Gasolina",
            "user_id": other_user_id
        }
        
        result = await test_db.db.vehicles.insert_one(vehicle)
        vehicle_id = str(result.inserted_id)
        
        # Intentar acceder al vehículo del otro usuario
        response = client.get(f"/vehicles/{vehicle_id}", headers=auth_headers)
        
        # Verificar respuesta de error (no encontrado o no autorizado)
        assert response.status_code in [status.HTTP_404_NOT_FOUND, status.HTTP_403_FORBIDDEN]
        
        # Limpiar después de la prueba
        await test_db.db.vehicles.delete_one({"_id": ObjectId(vehicle_id)})
        await test_db.db.users.delete_one({"_id": ObjectId(other_user_id)}) 