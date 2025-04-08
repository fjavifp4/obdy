import pytest
from fastapi import status
from bson import ObjectId
from datetime import datetime, timedelta

class TestMaintenanceRoutes:
    """Pruebas para las rutas de mantenimiento"""

    async def test_create_maintenance(self, client, auth_headers, test_db, test_user):
        """Prueba de creación de un registro de mantenimiento con datos válidos"""
        user_data, _ = test_user
        user_id = user_data["id"]
        
        # Crear un vehículo para la prueba
        vehicle = {
            "brand": "Toyota",
            "model": "Corolla",
            "year": 2020,
            "license_plate": "ABC123",
            "initial_km": 10000,
            "current_km": 15000,
            "fuel_type": "Gasolina",
            "user_id": user_id
        }
        
        vehicle_result = await test_db.db.vehicles.insert_one(vehicle)
        vehicle_id = str(vehicle_result.inserted_id)

        # Datos para crear un nuevo mantenimiento
        maintenance_date = datetime.now().isoformat()
        maintenance_data = {
            "vehicle_id": vehicle_id,
            "type": "Cambio de aceite",
            "description": "Cambio de aceite y filtro",
            "date": maintenance_date,
            "km_at_maintenance": 15000,
            "cost": 120.50
        }

        # Enviar solicitud de creación
        response = client.post("/maintenance/", json=maintenance_data, headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_201_CREATED
        response_data = response.json()
        
        # Verificar datos del mantenimiento devuelto
        assert response_data["vehicle_id"] == maintenance_data["vehicle_id"]
        assert response_data["type"] == maintenance_data["type"]
        assert response_data["description"] == maintenance_data["description"]
        assert response_data["km_at_maintenance"] == maintenance_data["km_at_maintenance"]
        assert response_data["cost"] == maintenance_data["cost"]
        assert "id" in response_data
        
        # Verificar que el mantenimiento está en la base de datos
        maintenance_id = response_data["id"]
        db_maintenance = await test_db.db.maintenance.find_one({"_id": maintenance_id})
        assert db_maintenance is not None
        
        # Limpiar después de la prueba
        await test_db.db.maintenance.delete_one({"_id": maintenance_id})
        await test_db.db.vehicles.delete_one({"_id": ObjectId(vehicle_id)})

    async def test_get_vehicle_maintenance(self, client, auth_headers, test_db, test_user):
        """Prueba para obtener todos los registros de mantenimiento de un vehículo"""
        user_data, _ = test_user
        user_id = user_data["id"]
        
        # Crear un vehículo para la prueba
        vehicle = {
            "brand": "Ford",
            "model": "Focus",
            "year": 2019,
            "license_plate": "XYZ789",
            "initial_km": 5000,
            "current_km": 25000,
            "fuel_type": "Diésel",
            "user_id": user_id
        }
        
        vehicle_result = await test_db.db.vehicles.insert_one(vehicle)
        vehicle_id = str(vehicle_result.inserted_id)
        
        # Crear dos registros de mantenimiento para el vehículo
        maintenance1 = {
            "vehicle_id": vehicle_id,
            "type": "Cambio de aceite",
            "description": "Mantenimiento regular",
            "date": (datetime.now() - timedelta(days=60)).isoformat(),
            "km_at_maintenance": 15000,
            "cost": 100.0,
            "user_id": user_id
        }
        
        maintenance2 = {
            "vehicle_id": vehicle_id,
            "type": "Cambio de frenos",
            "description": "Cambio de pastillas delanteras",
            "date": datetime.now().isoformat(),
            "km_at_maintenance": 25000,
            "cost": 250.0,
            "user_id": user_id
        }
        
        result1 = await test_db.db.maintenance.insert_one(maintenance1)
        result2 = await test_db.db.maintenance.insert_one(maintenance2)
        
        # Guardar IDs para limpieza posterior
        maintenance_id1 = str(result1.inserted_id)
        maintenance_id2 = str(result2.inserted_id)
        
        # Obtener mantenimientos del vehículo
        response = client.get(f"/maintenance/vehicle/{vehicle_id}", headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        maintenance_records = response.json()
        
        # Verificar que se devuelven los registros correctos
        assert len(maintenance_records) == 2
        maintenance_types = [m["type"] for m in maintenance_records]
        assert "Cambio de aceite" in maintenance_types
        assert "Cambio de frenos" in maintenance_types
        
        # Limpiar después de la prueba
        await test_db.db.maintenance.delete_many({
            "_id": {"$in": [ObjectId(maintenance_id1), ObjectId(maintenance_id2)]}
        })
        await test_db.db.vehicles.delete_one({"_id": ObjectId(vehicle_id)})

    async def test_get_maintenance_by_id(self, client, auth_headers, test_db, test_user):
        """Prueba para obtener un registro de mantenimiento específico por su ID"""
        user_data, _ = test_user
        user_id = user_data["id"]
        
        # Crear un vehículo para la prueba
        vehicle = {
            "brand": "Volkswagen",
            "model": "Golf",
            "year": 2018,
            "license_plate": "VWG123",
            "initial_km": 20000,
            "current_km": 45000,
            "fuel_type": "Gasolina",
            "user_id": user_id
        }
        
        vehicle_result = await test_db.db.vehicles.insert_one(vehicle)
        vehicle_id = str(vehicle_result.inserted_id)
        
        # Crear un registro de mantenimiento
        maintenance = {
            "vehicle_id": vehicle_id,
            "type": "Revisión completa",
            "description": "Revisión anual",
            "date": datetime.now().isoformat(),
            "km_at_maintenance": 40000,
            "cost": 350.0,
            "user_id": user_id
        }
        
        result = await test_db.db.maintenance.insert_one(maintenance)
        maintenance_id = str(result.inserted_id)
        
        # Obtener el mantenimiento por ID
        response = client.get(f"/maintenance/{maintenance_id}", headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        response_data = response.json()
        
        # Verificar datos del mantenimiento
        assert response_data["id"] == maintenance_id
        assert response_data["vehicle_id"] == maintenance["vehicle_id"]
        assert response_data["type"] == maintenance["type"]
        assert response_data["description"] == maintenance["description"]
        assert response_data["km_at_maintenance"] == maintenance["km_at_maintenance"]
        assert response_data["cost"] == maintenance["cost"]
        
        # Limpiar después de la prueba
        await test_db.db.maintenance.delete_one({"_id": ObjectId(maintenance_id)})
        await test_db.db.vehicles.delete_one({"_id": ObjectId(vehicle_id)})

    async def test_update_maintenance(self, client, auth_headers, test_db, test_user):
        """Prueba para actualizar un registro de mantenimiento existente"""
        user_data, _ = test_user
        user_id = user_data["id"]
        
        # Crear un vehículo para la prueba
        vehicle = {
            "brand": "Mazda",
            "model": "3",
            "year": 2017,
            "license_plate": "MZD345",
            "initial_km": 15000,
            "current_km": 52000,
            "fuel_type": "Gasolina",
            "user_id": user_id
        }
        
        vehicle_result = await test_db.db.vehicles.insert_one(vehicle)
        vehicle_id = str(vehicle_result.inserted_id)
        
        # Crear un registro de mantenimiento para actualizar
        maintenance = {
            "vehicle_id": vehicle_id,
            "type": "Cambio de ruedas",
            "description": "Cambio de 2 ruedas delanteras",
            "date": datetime.now().isoformat(),
            "km_at_maintenance": 50000,
            "cost": 200.0,
            "user_id": user_id
        }
        
        result = await test_db.db.maintenance.insert_one(maintenance)
        maintenance_id = str(result.inserted_id)
        
        # Datos actualizados
        new_date = (datetime.now() - timedelta(days=1)).isoformat()
        update_data = {
            "description": "Cambio de 4 ruedas completas",
            "cost": 400.0,
            "date": new_date
        }
        
        # Enviar solicitud de actualización
        response = client.put(f"/maintenance/{maintenance_id}", json=update_data, headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        response_data = response.json()
        
        # Verificar datos actualizados
        assert response_data["id"] == maintenance_id
        assert response_data["vehicle_id"] == maintenance["vehicle_id"]  # No cambia
        assert response_data["type"] == maintenance["type"]  # No cambia
        assert response_data["description"] == update_data["description"]  # Actualizado
        assert response_data["cost"] == update_data["cost"]  # Actualizado
        
        # Verificar actualización en la base de datos
        db_maintenance = await test_db.db.maintenance.find_one({"_id": ObjectId(maintenance_id)})
        assert db_maintenance["description"] == update_data["description"]
        assert db_maintenance["cost"] == update_data["cost"]
        
        # Limpiar después de la prueba
        await test_db.db.maintenance.delete_one({"_id": ObjectId(maintenance_id)})
        await test_db.db.vehicles.delete_one({"_id": ObjectId(vehicle_id)})

    async def test_delete_maintenance(self, client, auth_headers, test_db, test_user):
        """Prueba para eliminar un registro de mantenimiento"""
        user_data, _ = test_user
        user_id = user_data["id"]
        
        # Crear un vehículo para la prueba
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
        
        vehicle_result = await test_db.db.vehicles.insert_one(vehicle)
        vehicle_id = str(vehicle_result.inserted_id)
        
        # Crear un registro de mantenimiento para eliminar
        maintenance = {
            "vehicle_id": vehicle_id,
            "type": "ITV",
            "description": "Inspección técnica obligatoria",
            "date": datetime.now().isoformat(),
            "km_at_maintenance": 75000,
            "cost": 50.0,
            "user_id": user_id
        }
        
        result = await test_db.db.maintenance.insert_one(maintenance)
        maintenance_id = str(result.inserted_id)
        
        # Verificar que el mantenimiento existe
        assert await test_db.db.maintenance.find_one({"_id": ObjectId(maintenance_id)}) is not None
        
        # Enviar solicitud de eliminación
        response = client.delete(f"/maintenance/{maintenance_id}", headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_204_NO_CONTENT
        
        # Verificar que el mantenimiento ya no existe en la base de datos
        assert await test_db.db.maintenance.find_one({"_id": ObjectId(maintenance_id)}) is None
        
        # Limpiar después de la prueba
        await test_db.db.vehicles.delete_one({"_id": ObjectId(vehicle_id)}) 