import pytest
from fastapi.testclient import TestClient
from fastapi import status
from bson import ObjectId
from datetime import datetime, timedelta

# Importar funciones auxiliares y datos
from ..conftest import create_user_and_get_token
from .test_vehicles import VEHICLE_DATA_1 # Necesitamos datos de vehículo

# Datos de ejemplo para viajes y puntos GPS
TRIP_CREATE_DATA = {
    # vehicle_id se añade dinámicamente
    "distance_in_km": 0.0,
    "fuel_consumption_liters": 0.0,
    "average_speed_kmh": 0.0,
    "duration_seconds": 0
}

GPS_POINT_1 = {"latitude": 40.7128, "longitude": -74.0060, "timestamp": datetime.utcnow().isoformat()}
GPS_POINT_2 = {"latitude": 40.7580, "longitude": -73.9855, "timestamp": (datetime.utcnow() + timedelta(minutes=5)).isoformat()}
GPS_POINTS_BATCH = [GPS_POINT_1, GPS_POINT_2]

TRIP_UPDATE_DATA = {
    "distance_in_km": 10.5,
    "fuel_consumption_liters": 1.2,
    "average_speed_kmh": 45.0,
    "duration_seconds": 14 * 60 # 14 minutos
}

# Helper para crear un viaje activo
def create_active_trip(client: TestClient, headers: dict, vehicle_id: str) -> str:
    trip_payload = {**TRIP_CREATE_DATA, "vehicle_id": vehicle_id}
    start_trip_resp = client.post("/trips", headers=headers, json=trip_payload)
    assert start_trip_resp.status_code == status.HTTP_201_CREATED
    return start_trip_resp.json()["id"]

def test_trip_lifecycle(client: TestClient):
    """Testea el ciclo de vida completo de un viaje."""
    token, user_id = create_user_and_get_token(client, "trip_lifecycle")
    headers = {"Authorization": f"Bearer {token}"}
    
    # 1. Crear vehículo asociado
    vehicle_resp = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    assert vehicle_resp.status_code == status.HTTP_201_CREATED
    vehicle_id = vehicle_resp.json()["id"]
    initial_km = vehicle_resp.json()["current_kilometers"]

    # 2. Iniciar viaje
    trip_payload = {**TRIP_CREATE_DATA, "vehicle_id": vehicle_id}
    start_trip_resp = client.post("/trips", headers=headers, json=trip_payload)
    assert start_trip_resp.status_code == status.HTTP_201_CREATED
    trip_data = start_trip_resp.json()
    trip_id = trip_data["id"]
    assert trip_data["vehicle_id"] == vehicle_id
    assert trip_data["user_id"] == user_id
    assert trip_data["is_active"] is True
    assert trip_data["end_time"] is None

    # 3. Verificar que está activo
    active_trip_resp = client.get("/trips/active", headers=headers)
    assert active_trip_resp.status_code == status.HTTP_200_OK
    assert active_trip_resp.json()["id"] == trip_id

    # 4. Añadir puntos GPS
    gps_resp = client.post(f"/trips/{trip_id}/gps-points/batch", headers=headers, json=GPS_POINTS_BATCH)
    assert gps_resp.status_code == status.HTTP_200_OK
    expected_gps_message = f"Se añadieron {len(GPS_POINTS_BATCH)} puntos GPS con éxito"
    assert gps_resp.json()["message"] == expected_gps_message
    
    # (Opcional) Verificar que los puntos están en el viaje (requiere GET by ID)
    # get_trip_resp = client.get(f"/trips/{trip_id}", headers=headers) # Necesitaría crear esta ruta
    # assert len(get_trip_resp.json()['gps_points']) == len(GPS_POINTS_BATCH)

    # 5. Actualizar datos del viaje
    update_resp = client.put(f"/trips/{trip_id}", headers=headers, json=TRIP_UPDATE_DATA)
    assert update_resp.status_code == status.HTTP_200_OK
    updated_trip_data = update_resp.json()
    assert updated_trip_data["distance_in_km"] == TRIP_UPDATE_DATA["distance_in_km"]
    assert updated_trip_data["average_speed_kmh"] == TRIP_UPDATE_DATA["average_speed_kmh"]
    
    # Verificar que los km del vehículo se actualizaron
    vehicle_resp_after_update = client.get(f"/vehicles/{vehicle_id}", headers=headers)
    assert vehicle_resp_after_update.status_code == status.HTTP_200_OK
    expected_km = initial_km + TRIP_UPDATE_DATA["distance_in_km"]
    assert vehicle_resp_after_update.json()["current_kilometers"] == pytest.approx(expected_km)

    # 6. Finalizar viaje
    end_trip_resp = client.put(f"/trips/{trip_id}/end", headers=headers)
    assert end_trip_resp.status_code == status.HTTP_200_OK
    ended_trip_data = end_trip_resp.json()
    assert ended_trip_data["is_active"] is False
    assert ended_trip_data["end_time"] is not None

    # 7. Verificar que ya no está activo
    no_active_trip_resp = client.get("/trips/active", headers=headers)
    assert no_active_trip_resp.status_code == status.HTTP_404_NOT_FOUND

    # 8. Obtener lista de viajes y verificar que aparece
    list_trips_resp = client.get(f"/trips?vehicle_id={vehicle_id}", headers=headers)
    assert list_trips_resp.status_code == status.HTTP_200_OK
    trips_list = list_trips_resp.json()
    assert isinstance(trips_list, list)
    assert len(trips_list) >= 1
    assert any(t["id"] == trip_id for t in trips_list)
    assert not trips_list[0]["is_active"] # El más reciente (este) debe estar inactivo

    # 9. Obtener estadísticas (test básico)
    stats_resp = client.get(f"/trips/vehicle/{vehicle_id}/stats", headers=headers)
    assert stats_resp.status_code == status.HTTP_200_OK
    stats_data = stats_resp.json()
    assert stats_data["total_trips"] >= 1
    assert stats_data["total_distance_km"] >= TRIP_UPDATE_DATA["distance_in_km"]

    # 10. Eliminar viaje
    delete_resp = client.delete(f"/trips/{trip_id}", headers=headers)
    assert delete_resp.status_code == status.HTTP_204_NO_CONTENT
    
    # Verificar que ya no está en la lista
    list_after_delete_resp = client.get(f"/trips?vehicle_id={vehicle_id}", headers=headers)
    assert list_after_delete_resp.status_code == status.HTTP_200_OK
    assert not any(t["id"] == trip_id for t in list_after_delete_resp.json())


def test_create_trip_vehicle_not_found(client: TestClient):
    token, _ = create_user_and_get_token(client, "trip_no_vehicle")
    headers = {"Authorization": f"Bearer {token}"}
    non_existent_vehicle_id = str(ObjectId())
    
    trip_payload = {**TRIP_CREATE_DATA, "vehicle_id": non_existent_vehicle_id}
    response = client.post("/trips", headers=headers, json=trip_payload)
    assert response.status_code == status.HTTP_404_NOT_FOUND

def test_get_active_trip_none_active(client: TestClient):
    token, _ = create_user_and_get_token(client, "trip_no_active")
    headers = {"Authorization": f"Bearer {token}"}
    # No crear ningún viaje activo
    response = client.get("/trips/active", headers=headers)
    assert response.status_code == status.HTTP_404_NOT_FOUND

def test_end_trip_not_found(client: TestClient):
    token, _ = create_user_and_get_token(client, "trip_end_notfound")
    headers = {"Authorization": f"Bearer {token}"}
    non_existent_trip_id = str(ObjectId())
    response = client.put(f"/trips/{non_existent_trip_id}/end", headers=headers)
    assert response.status_code == status.HTTP_404_NOT_FOUND

def test_add_single_gps_point(client: TestClient):
    token, _ = create_user_and_get_token(client, "trip_add_single_gps")
    headers = {"Authorization": f"Bearer {token}"}
    vehicle_resp = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    vehicle_id = vehicle_resp.json()["id"]
    trip_id = create_active_trip(client, headers, vehicle_id)
    
    gps_point_data = {"latitude": 41.0, "longitude": -74.1, "timestamp": datetime.utcnow().isoformat()}
    response = client.post(f"/trips/{trip_id}/gps-point", headers=headers, json=gps_point_data)
    assert response.status_code == status.HTTP_200_OK
    assert response.json() == {"message": "Punto GPS añadido con éxito"}

def test_end_trip_already_ended(client: TestClient):
    token, _ = create_user_and_get_token(client, "trip_end_ended")
    headers = {"Authorization": f"Bearer {token}"}
    vehicle_resp = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    vehicle_id = vehicle_resp.json()["id"]
    trip_id = create_active_trip(client, headers, vehicle_id)
    
    # Finalizar una vez
    client.put(f"/trips/{trip_id}/end", headers=headers)
    # Intentar finalizar de nuevo
    response = client.put(f"/trips/{trip_id}/end", headers=headers)
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "El viaje ya está finalizado" in response.json()["detail"]

def test_add_gps_to_ended_trip(client: TestClient):
    token, _ = create_user_and_get_token(client, "trip_gps_ended")
    headers = {"Authorization": f"Bearer {token}"}
    vehicle_resp = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    vehicle_id = vehicle_resp.json()["id"]
    trip_id = create_active_trip(client, headers, vehicle_id)
    
    # Finalizar viaje
    client.put(f"/trips/{trip_id}/end", headers=headers)
    # Intentar añadir GPS
    response = client.post(f"/trips/{trip_id}/gps-points/batch", headers=headers, json=GPS_POINTS_BATCH)
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "No se pueden añadir puntos GPS a un viaje finalizado" in response.json()["detail"]

def test_update_trip_not_found(client: TestClient):
    token, _ = create_user_and_get_token(client, "trip_update_notfound")
    headers = {"Authorization": f"Bearer {token}"}
    non_existent_trip_id = str(ObjectId())
    response = client.put(f"/trips/{non_existent_trip_id}", headers=headers, json=TRIP_UPDATE_DATA)
    assert response.status_code == status.HTTP_404_NOT_FOUND

def test_delete_trip_not_found(client: TestClient):
    token, _ = create_user_and_get_token(client, "trip_delete_notfound")
    headers = {"Authorization": f"Bearer {token}"}
    non_existent_trip_id = str(ObjectId())
    response = client.delete(f"/trips/{non_existent_trip_id}", headers=headers)
    assert response.status_code == status.HTTP_404_NOT_FOUND

def test_get_stats_vehicle_not_found(client: TestClient):
    token, _ = create_user_and_get_token(client, "trip_stats_novehicle")
    headers = {"Authorization": f"Bearer {token}"}
    non_existent_vehicle_id = str(ObjectId())
    response = client.get(f"/trips/vehicle/{non_existent_vehicle_id}/stats", headers=headers)
    assert response.status_code == status.HTTP_404_NOT_FOUND

def test_trip_forbidden_access(client: TestClient):
    # Usuario 1 crea vehículo y viaje
    token1, _ = create_user_and_get_token(client, "trip_forbidden1")
    headers1 = {"Authorization": f"Bearer {token1}"}
    vehicle_resp1 = client.post("/vehicles", headers=headers1, json=VEHICLE_DATA_1)
    vehicle_id1 = vehicle_resp1.json()["id"]
    trip_id1 = create_active_trip(client, headers1, vehicle_id1)

    # Usuario 2 intenta acceder/modificar viaje de Usuario 1
    token2, _ = create_user_and_get_token(client, "trip_forbidden2")
    headers2 = {"Authorization": f"Bearer {token2}"}
    
    update_resp = client.put(f"/trips/{trip_id1}", headers=headers2, json=TRIP_UPDATE_DATA)
    assert update_resp.status_code == status.HTTP_404_NOT_FOUND
    
    end_resp = client.put(f"/trips/{trip_id1}/end", headers=headers2)
    assert end_resp.status_code == status.HTTP_404_NOT_FOUND
    
    gps_resp = client.post(f"/trips/{trip_id1}/gps-points/batch", headers=headers2, json=GPS_POINTS_BATCH)
    assert gps_resp.status_code == status.HTTP_404_NOT_FOUND

    delete_resp = client.delete(f"/trips/{trip_id1}", headers=headers2)
    assert delete_resp.status_code == status.HTTP_404_NOT_FOUND

    stats_resp = client.get(f"/trips/vehicle/{vehicle_id1}/stats", headers=headers2)
    assert stats_resp.status_code == status.HTTP_404_NOT_FOUND # También da 404 si el vehículo no es del user

# --- TESTS AVANZADOS Y TODOs ---

def test_add_gps_point_forbidden(client: TestClient):
    # Usuario 1 crea vehículo y viaje
    token1, _ = create_user_and_get_token(client, "trip_gps_forbidden1")
    headers1 = {"Authorization": f"Bearer {token1}"}
    vehicle_resp1 = client.post("/vehicles", headers=headers1, json=VEHICLE_DATA_1)
    vehicle_id1 = vehicle_resp1.json()["id"]
    trip_id1 = create_active_trip(client, headers1, vehicle_id1)

    # Usuario 2 intenta añadir punto GPS
    token2, _ = create_user_and_get_token(client, "trip_gps_forbidden2")
    headers2 = {"Authorization": f"Bearer {token2}"}
    gps_point_data = {"latitude": 41.0, "longitude": -74.1, "timestamp": datetime.utcnow().isoformat()}
    response = client.post(f"/trips/{trip_id1}/gps-point", headers=headers2, json=gps_point_data)
    assert response.status_code == status.HTTP_404_NOT_FOUND


def test_add_gps_point_bad_request(client: TestClient):
    token, _ = create_user_and_get_token(client, "trip_gps_badreq")
    headers = {"Authorization": f"Bearer {token}"}
    vehicle_resp = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    vehicle_id = vehicle_resp.json()["id"]
    trip_id = create_active_trip(client, headers, vehicle_id)
    # Falta campo latitude
    gps_point_data = {"longitude": -74.1, "timestamp": datetime.utcnow().isoformat()}
    response = client.post(f"/trips/{trip_id}/gps-point", headers=headers, json=gps_point_data)
    assert response.status_code in (400, 422)


def test_trip_date_format(client: TestClient):
    token, _ = create_user_and_get_token(client, "trip_date_format")
    headers = {"Authorization": f"Bearer {token}"}
    vehicle_resp = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    vehicle_id = vehicle_resp.json()["id"]
    trip_id = create_active_trip(client, headers, vehicle_id)
    # Añadir punto GPS con formato de fecha ISO
    gps_point_data = {"latitude": 41.0, "longitude": -74.1, "timestamp": datetime.utcnow().isoformat()}
    response = client.post(f"/trips/{trip_id}/gps-point", headers=headers, json=gps_point_data)
    assert response.status_code == status.HTTP_200_OK
    # El endpoint no devuelve la fecha, pero si no da error, el formato es aceptado

# TODO: Más tests para casos de error (forbidden, bad requests), 
#       tests específicos para add_gps_point (single), 
#       verificar formato de fechas, etc. 