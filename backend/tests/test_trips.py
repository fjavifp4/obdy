import pytest
from fastapi import status
from bson import ObjectId
from datetime import datetime, timedelta

class TestTripRoutes:
    """Pruebas para las rutas relacionadas con viajes"""

    async def test_create_trip(self, client, test_vehicle, auth_headers, test_db):
        """Prueba la creación de un nuevo viaje"""
        vehicle_data = test_vehicle
        
        # Datos del viaje para prueba
        trip_data = {
            "vehicle_id": vehicle_data["id"],
            "distance_in_km": 0.0,
            "fuel_consumption_liters": 0.0,
            "average_speed_kmh": 0.0,
            "duration_seconds": 0
        }
        
        # Enviar solicitud para crear viaje
        response = client.post("/trips", json=trip_data, headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_201_CREATED
        
        # Verificar contenido de la respuesta
        data = response.json()
        assert "id" in data
        assert data["vehicle_id"] == vehicle_data["id"]
        assert data["is_active"] is True
        assert data["start_time"] is not None
        
        # Verificar que el viaje se haya creado en la base de datos
        trip_in_db = await test_db.db.trips.find_one({"_id": ObjectId(data["id"])})
        assert trip_in_db is not None
        assert trip_in_db["vehicle_id"] == ObjectId(vehicle_data["id"])
        assert trip_in_db["is_active"] is True
        
        # Limpiar después de la prueba
        await test_db.db.trips.delete_one({"_id": ObjectId(data["id"])})

    async def test_end_trip(self, client, test_trip, auth_headers, test_db):
        """Prueba finalizar un viaje activo"""
        trip_id = test_trip["id"]
        
        # Asegurarse de que el viaje esté activo
        await test_db.db.trips.update_one(
            {"_id": ObjectId(trip_id)},
            {"$set": {"is_active": True, "end_time": None}}
        )
        
        # Enviar solicitud para finalizar el viaje
        response = client.put(f"/trips/{trip_id}/end", headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        
        # Verificar contenido de la respuesta
        data = response.json()
        assert data["id"] == trip_id
        assert data["is_active"] is False
        assert data["end_time"] is not None
        
        # Verificar que el viaje se haya actualizado en la base de datos
        updated_trip = await test_db.db.trips.find_one({"_id": ObjectId(trip_id)})
        assert updated_trip is not None
        assert updated_trip["is_active"] is False
        assert "end_time" in updated_trip

    async def test_add_gps_point(self, client, test_trip, auth_headers, test_db):
        """Prueba añadir un punto GPS a un viaje activo"""
        trip_id = test_trip["id"]
        
        # Asegurarse de que el viaje esté activo
        await test_db.db.trips.update_one(
            {"_id": ObjectId(trip_id)},
            {"$set": {"is_active": True, "end_time": None}}
        )
        
        # Datos del punto GPS
        now = datetime.utcnow()
        gps_data = {
            "latitude": 40.416775,
            "longitude": -3.703790,
            "timestamp": now.isoformat()
        }
        
        # Enviar solicitud para añadir un punto GPS
        response = client.post(f"/trips/{trip_id}/gps-point", json=gps_data, headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        
        # Verificar que el punto GPS se haya añadido en la base de datos
        updated_trip = await test_db.db.trips.find_one({"_id": ObjectId(trip_id)})
        assert updated_trip is not None
        assert "gps_points" in updated_trip
        assert len(updated_trip["gps_points"]) > 0
        
        # Encontrar el punto añadido
        found = False
        for point in updated_trip["gps_points"]:
            if (abs(point["latitude"] - gps_data["latitude"]) < 0.001 and 
                abs(point["longitude"] - gps_data["longitude"]) < 0.001):
                found = True
                break
        
        assert found, "No se encontró el punto GPS añadido en la base de datos"

    async def test_add_gps_points_batch(self, client, test_trip, auth_headers, test_db):
        """Prueba añadir múltiples puntos GPS a un viaje activo"""
        trip_id = test_trip["id"]
        
        # Asegurarse de que el viaje esté activo
        await test_db.db.trips.update_one(
            {"_id": ObjectId(trip_id)},
            {"$set": {"is_active": True, "end_time": None}}
        )
        
        # Datos de los puntos GPS
        now = datetime.utcnow()
        gps_batch = [
            {
                "latitude": 40.416775,
                "longitude": -3.703790,
                "timestamp": now.isoformat()
            },
            {
                "latitude": 40.417000,
                "longitude": -3.704000,
                "timestamp": (now + timedelta(minutes=1)).isoformat()
            }
        ]
        
        # Enviar solicitud para añadir puntos GPS en lote
        response = client.post(f"/trips/{trip_id}/gps-points/batch", json=gps_batch, headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        
        # Verificar que los puntos GPS se hayan añadido en la base de datos
        updated_trip = await test_db.db.trips.find_one({"_id": ObjectId(trip_id)})
        assert updated_trip is not None
        assert "gps_points" in updated_trip
        assert len(updated_trip["gps_points"]) >= 2
        
        # Restaurar el estado para otras pruebas si es necesario
        # await test_db.db.trips.update_one(
        #     {"_id": ObjectId(trip_id)},
        #     {"$set": {"gps_points": []}}
        # )

    async def test_get_user_trips(self, client, test_trip, auth_headers):
        """Prueba obtener todos los viajes del usuario"""
        # Enviar solicitud para obtener los viajes del usuario
        response = client.get("/trips", headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        
        # Verificar contenido de la respuesta
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 1  # Al menos debería estar el viaje de prueba
        
        # Verificar si el viaje de prueba está en los resultados
        trip_ids = [trip["id"] for trip in data]
        assert test_trip["id"] in trip_ids

    async def test_get_active_trip(self, client, test_trip, auth_headers, test_db):
        """Prueba obtener el viaje activo del usuario"""
        # Asegurarse de que el viaje de prueba esté activo
        await test_db.db.trips.update_one(
            {"_id": ObjectId(test_trip["id"])},
            {"$set": {"is_active": True, "end_time": None}}
        )
        
        # Enviar solicitud para obtener el viaje activo
        response = client.get("/trips/active", headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        
        # Verificar contenido de la respuesta
        data = response.json()
        assert data["id"] == test_trip["id"]
        assert data["is_active"] is True

    async def test_update_trip(self, client, test_trip, auth_headers, test_db):
        """Prueba actualizar un viaje"""
        trip_id = test_trip["id"]
        
        # Datos para actualizar
        update_data = {
            "distance_in_km": 15.5,
            "fuel_consumption_liters": 1.8,
            "average_speed_kmh": 55.0,
            "duration_seconds": 1200,
            "gps_points": [
                {
                    "latitude": 40.416775,
                    "longitude": -3.703790,
                    "timestamp": datetime.utcnow().isoformat()
                }
            ]
        }
        
        # Enviar solicitud de actualización
        response = client.put(f"/trips/{trip_id}", json=update_data, headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        
        # Verificar contenido de la respuesta
        data = response.json()
        assert data["id"] == trip_id
        assert data["distance_in_km"] == update_data["distance_in_km"]
        assert data["fuel_consumption_liters"] == update_data["fuel_consumption_liters"]
        assert data["average_speed_kmh"] == update_data["average_speed_kmh"]
        assert data["duration_seconds"] == update_data["duration_seconds"]
        
        # Verificar que los cambios se hayan guardado en la base de datos
        updated_trip = await test_db.db.trips.find_one({"_id": ObjectId(trip_id)})
        assert updated_trip is not None
        assert updated_trip["distance_in_km"] == update_data["distance_in_km"]
        assert updated_trip["fuel_consumption_liters"] == update_data["fuel_consumption_liters"]
        assert updated_trip["average_speed_kmh"] == update_data["average_speed_kmh"]
        assert updated_trip["duration_seconds"] == update_data["duration_seconds"]

    async def test_get_vehicle_trip_stats(self, client, test_vehicle, test_trip, auth_headers):
        """Prueba obtener estadísticas de viajes para un vehículo"""
        vehicle_id = test_vehicle["id"]
        
        # Enviar solicitud para obtener estadísticas del vehículo
        response = client.get(f"/trips/vehicle/{vehicle_id}/stats", headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        
        # Verificar estructura de la respuesta
        data = response.json()
        assert "total_trips" in data
        assert "total_distance_km" in data
        assert "total_fuel_consumption_liters" in data
        assert "total_duration_seconds" in data
        assert "average_speed_kmh" in data
        assert "average_fuel_economy_km_per_liter" in data

    async def test_delete_trip(self, client, test_user, test_vehicle, auth_headers, test_db):
        """Prueba eliminar un viaje"""
        # Crear un viaje específico para eliminar
        user_data, _ = test_user
        
        # Datos del viaje para prueba
        trip_data = {
            "user_id": ObjectId(user_data["id"]),
            "vehicle_id": ObjectId(test_vehicle["id"]),
            "start_time": datetime.utcnow(),
            "distance_in_km": 10.0,
            "fuel_consumption_liters": 1.0,
            "average_speed_kmh": 50.0,
            "duration_seconds": 1200,
            "is_active": False,
            "gps_points": [],
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }
        
        # Insertar el viaje directamente en la base de datos
        result = await test_db.db.trips.insert_one(trip_data)
        trip_id = str(result.inserted_id)
        
        # Enviar solicitud para eliminar el viaje
        response = client.delete(f"/trips/{trip_id}", headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_204_NO_CONTENT
        
        # Verificar que el viaje haya sido eliminado de la base de datos
        deleted_trip = await test_db.db.trips.find_one({"_id": ObjectId(trip_id)})
        assert deleted_trip is None

    async def test_nonexistent_trip(self, client, auth_headers):
        """Prueba acceder a un viaje que no existe"""
        # ID de un viaje que no existe
        nonexistent_id = str(ObjectId())
        
        # Enviar solicitud para obtener un viaje que no existe
        response = client.get(f"/trips/{nonexistent_id}", headers=auth_headers)
        
        # Verificar respuesta de error
        assert response.status_code == status.HTTP_404_NOT_FOUND

    async def test_end_inactive_trip(self, client, test_trip, auth_headers, test_db):
        """Prueba finalizar un viaje que ya está inactivo"""
        trip_id = test_trip["id"]
        
        # Primero finalizar el viaje
        await test_db.db.trips.update_one(
            {"_id": ObjectId(trip_id)},
            {"$set": {"is_active": False, "end_time": datetime.utcnow()}}
        )
        
        # Intentar finalizar el viaje de nuevo
        response = client.put(f"/trips/{trip_id}/end", headers=auth_headers)
        
        # Verificar respuesta de error
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        
        # Restaurar el estado para otras pruebas
        await test_db.db.trips.update_one(
            {"_id": ObjectId(trip_id)},
            {"$set": {"is_active": True, "end_time": None}}
        )

    async def test_unauthorized_trip_access(self, client, test_trip):
        """Prueba acceder a un viaje sin autenticación"""
        trip_id = test_trip["id"]
        
        # Enviar solicitud sin token de autenticación
        response = client.get(f"/trips/{trip_id}")
        
        # Verificar respuesta de error
        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    async def test_add_gps_to_inactive_trip(self, client, test_trip, auth_headers, test_db):
        """Prueba añadir puntos GPS a un viaje inactivo"""
        trip_id = test_trip["id"]
        
        # Finalizar el viaje
        await test_db.db.trips.update_one(
            {"_id": ObjectId(trip_id)},
            {"$set": {"is_active": False, "end_time": datetime.utcnow()}}
        )
        
        # Datos del punto GPS
        gps_data = {
            "latitude": 40.416775,
            "longitude": -3.703790,
            "timestamp": datetime.utcnow().isoformat()
        }
        
        # Enviar solicitud para añadir un punto GPS a un viaje inactivo
        response = client.post(f"/trips/{trip_id}/gps-point", json=gps_data, headers=auth_headers)
        
        # Verificar respuesta de error
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        
        # Restaurar el estado para otras pruebas
        await test_db.db.trips.update_one(
            {"_id": ObjectId(trip_id)},
            {"$set": {"is_active": True, "end_time": None}}
        )
        
    async def test_get_trips_for_vehicle(self, client, test_vehicle, test_trip, auth_headers, test_db):
        """Prueba obtener viajes para un vehículo específico"""
        vehicle_id = test_vehicle["id"]
        
        # Asegurarse de que el viaje de prueba esté asociado al vehículo
        await test_db.db.trips.update_one(
            {"_id": ObjectId(test_trip["id"])},
            {"$set": {"vehicle_id": ObjectId(vehicle_id)}}
        )
        
        # Enviar solicitud para obtener los viajes del vehículo
        response = client.get(f"/trips?vehicle_id={vehicle_id}", headers=auth_headers)
        
        # Verificar respuesta exitosa
        assert response.status_code == status.HTTP_200_OK
        
        # Verificar contenido de la respuesta
        data = response.json()
        assert isinstance(data, list)
        
        # Verificar que el viaje de prueba esté en la respuesta
        trip_ids = [trip["id"] for trip in data]
        assert test_trip["id"] in trip_ids, "El viaje de prueba no está en la lista de viajes del vehículo"
        
        # Verificar que todos los viajes pertenecen al vehículo correcto
        for trip in data:
            assert trip["vehicle_id"] == vehicle_id, f"El viaje {trip['id']} no está asociado al vehículo correcto"
    
    async def test_trip_with_gps_points(self, client, test_trip, auth_headers, test_db):
        """Prueba crear un viaje con puntos GPS y recuperarlo"""
        trip_id = test_trip["id"]
        
        # Asegurarse de que el viaje esté activo
        await test_db.db.trips.update_one(
            {"_id": ObjectId(trip_id)},
            {"$set": {"is_active": True, "end_time": None, "gps_points": []}}
        )
        
        # Añadir varios puntos GPS para simular una ruta
        now = datetime.utcnow()
        gps_points = [
            # Simulación de un recorrido en Madrid
            {"latitude": 40.416775, "longitude": -3.703790, "timestamp": now.isoformat()},
            {"latitude": 40.417500, "longitude": -3.704200, "timestamp": (now + timedelta(minutes=2)).isoformat()},
            {"latitude": 40.418300, "longitude": -3.704600, "timestamp": (now + timedelta(minutes=4)).isoformat()},
            {"latitude": 40.419100, "longitude": -3.705000, "timestamp": (now + timedelta(minutes=6)).isoformat()},
            {"latitude": 40.420000, "longitude": -3.705500, "timestamp": (now + timedelta(minutes=8)).isoformat()}
        ]
        
        # Enviar solicitud para añadir puntos GPS en lote
        response = client.post(f"/trips/{trip_id}/gps-points/batch", json=gps_points, headers=auth_headers)
        assert response.status_code == status.HTTP_200_OK
        
        # Obtener el viaje y verificar que contiene los puntos GPS
        response = client.get(f"/trips/{trip_id}", headers=auth_headers)
        assert response.status_code == status.HTTP_200_OK
        
        trip_data = response.json()
        assert "gps_points" in trip_data
        assert len(trip_data["gps_points"]) >= len(gps_points)
        
        # Verificar que los puntos se añadieron correctamente
        db_trip = await test_db.db.trips.find_one({"_id": ObjectId(trip_id)})
        assert len(db_trip["gps_points"]) >= len(gps_points)
        
        # Verificar que los puntos tienen el formato correcto
        for point in db_trip["gps_points"]:
            assert "latitude" in point
            assert "longitude" in point
            assert "timestamp" in point
            
    async def test_user_trip_statistics(self, client, test_user, test_vehicle, auth_headers, test_db):
        """Prueba obtener estadísticas de viaje a nivel de usuario"""
        user_data, _ = test_user
        vehicle_id = test_vehicle["id"]
        
        # Crear varios viajes para tener estadísticas significativas
        trip_data = {
            "vehicle_id": vehicle_id,
            "distance_in_km": 10.0,
            "fuel_consumption_liters": 1.0,
            "average_speed_kmh": 50.0,
            "duration_seconds": 1200
        }
        
        # Crear primer viaje
        response1 = client.post("/trips", json=trip_data, headers=auth_headers)
        assert response1.status_code == status.HTTP_201_CREATED
        trip1_id = response1.json()["id"]
        
        # Crear segundo viaje con datos diferentes
        trip_data["distance_in_km"] = 15.0
        trip_data["fuel_consumption_liters"] = 1.5
        trip_data["average_speed_kmh"] = 60.0
        trip_data["duration_seconds"] = 1500
        
        response2 = client.post("/trips", json=trip_data, headers=auth_headers)
        assert response2.status_code == status.HTTP_201_CREATED
        trip2_id = response2.json()["id"]
        
        # Obtener estadísticas del vehículo
        response = client.get(f"/trips/vehicle/{vehicle_id}/stats", headers=auth_headers)
        assert response.status_code == status.HTTP_200_OK
        
        # Verificar las estadísticas
        stats = response.json()
        assert stats["total_trips"] >= 2
        assert stats["total_distance_km"] >= 25.0  # Al menos los 25 km de los dos viajes creados
        assert stats["total_fuel_consumption_liters"] >= 2.5  # Al menos los 2.5 L de los dos viajes
        assert "average_speed_kmh" in stats
        assert "average_fuel_economy_km_per_liter" in stats
        
        # Limpiar después de la prueba
        await test_db.db.trips.delete_many({"_id": {"$in": [ObjectId(trip1_id), ObjectId(trip2_id)]}}) 