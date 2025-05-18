import pytest
import io
from fastapi.testclient import TestClient
from fastapi import status
from bson import ObjectId
from datetime import datetime, timedelta

# Importar la función auxiliar
from ..conftest import create_user_and_get_token

# Datos de ejemplo para vehículos y mantenimiento
VEHICLE_DATA_1 = {
    "brand": "Toyota",
    "model": "Corolla",
    "year": 2020,
    "licensePlate": "1234ABC",
    "current_kilometers": 50000
}
VEHICLE_DATA_2 = {
    "brand": "Honda",
    "model": "Civic",
    "year": 2019,
    "licensePlate": "5678DEF",
    "current_kilometers": 65000
}
MAINTENANCE_DATA_OIL = {
    "type": "Cambio de Aceite",
    "last_change_km": 45000,
    "recommended_interval_km": 15000,
    "last_change_date": (datetime.utcnow() - timedelta(days=180)).strftime('%Y-%m-%dT%H:%M:%S'),
    "notes": "Cambio de aceite regular",
    "km_since_last_change": 0.0
}
MAINTENANCE_DATA_BRAKES = {
    "type": "Revisión Frenos",
    "last_change_km": 30000,
    "recommended_interval_km": 30000,
    "last_change_date": (datetime.utcnow() - timedelta(days=365)).strftime('%Y-%m-%dT%H:%M:%S'),
    "notes": "Pastillas delanteras",
    "km_since_last_change": 0.0
}

# --- Tests para CRUD de Vehículos --- 

def test_create_vehicle_success(client: TestClient):
    token, _ = create_user_and_get_token(client, "vehicle_create")
    headers = {"Authorization": f"Bearer {token}"}
    
    response = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    
    assert response.status_code == status.HTTP_201_CREATED
    data = response.json()
    assert data["brand"] == VEHICLE_DATA_1["brand"]
    assert data["model"] == VEHICLE_DATA_1["model"]
    assert data["licensePlate"] == VEHICLE_DATA_1["licensePlate"]
    assert "id" in data
    assert "userId" in data
    assert "logo" in data # Verificar que el campo logo existe (puede ser None)

def test_create_vehicle_duplicate_license_plate(client: TestClient):
    token, _ = create_user_and_get_token(client, "vehicle_dup_plate")
    headers = {"Authorization": f"Bearer {token}"}
    
    # Crear el primer vehículo
    client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    # Intentar crear otro con la misma matrícula
    response = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "Ya existe un vehículo con esa matrícula" in response.json()["detail"]

def test_get_user_vehicles_success(client: TestClient):
    token, _ = create_user_and_get_token(client, "vehicle_get_list")
    headers = {"Authorization": f"Bearer {token}"}
    
    # Crear dos vehículos
    client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    client.post("/vehicles", headers=headers, json=VEHICLE_DATA_2)
    
    response = client.get("/vehicles", headers=headers)
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert isinstance(data, list)
    assert len(data) == 2
    assert data[0]["licensePlate"] == VEHICLE_DATA_1["licensePlate"]
    assert data[1]["licensePlate"] == VEHICLE_DATA_2["licensePlate"]

def test_get_specific_vehicle_success(client: TestClient):
    token, _ = create_user_and_get_token(client, "vehicle_get_one")
    headers = {"Authorization": f"Bearer {token}"}
    
    create_response = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    vehicle_id = create_response.json()["id"]
    
    response = client.get(f"/vehicles/{vehicle_id}", headers=headers)
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["id"] == vehicle_id
    assert data["licensePlate"] == VEHICLE_DATA_1["licensePlate"]

def test_get_specific_vehicle_not_found(client: TestClient):
    token, _ = create_user_and_get_token(client, "vehicle_get_notfound")
    headers = {"Authorization": f"Bearer {token}"}
    non_existent_id = str(ObjectId())
    
    response = client.get(f"/vehicles/{non_existent_id}", headers=headers)
    
    assert response.status_code == status.HTTP_404_NOT_FOUND

def test_get_specific_vehicle_forbidden(client: TestClient):
    # Crear usuario 1 y su vehículo
    token1, _ = create_user_and_get_token(client, "vehicle_get_forbidden1")
    headers1 = {"Authorization": f"Bearer {token1}"}
    create_response = client.post("/vehicles", headers=headers1, json=VEHICLE_DATA_1)
    vehicle_id1 = create_response.json()["id"]
    
    # Crear usuario 2
    token2, _ = create_user_and_get_token(client, "vehicle_get_forbidden2")
    headers2 = {"Authorization": f"Bearer {token2}"}
    
    # Usuario 2 intenta obtener vehículo de usuario 1
    response = client.get(f"/vehicles/{vehicle_id1}", headers=headers2)
    
    assert response.status_code == status.HTTP_404_NOT_FOUND # La ruta devuelve 404 si el user_id no coincide

def test_update_vehicle_success(client: TestClient):
    token, _ = create_user_and_get_token(client, "vehicle_update")
    headers = {"Authorization": f"Bearer {token}"}
    create_response = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    vehicle_id = create_response.json()["id"]
    
    update_data = {"current_kilometers": 55000, "model": "Corolla Hybrid"}
    
    response = client.put(f"/vehicles/{vehicle_id}", headers=headers, json=update_data)
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["id"] == vehicle_id
    assert data["current_kilometers"] == 55000
    assert data["model"] == "Corolla Hybrid"
    assert data["brand"] == VEHICLE_DATA_1["brand"] # Brand no debería cambiar

def test_delete_vehicle_success(client: TestClient):
    token, _ = create_user_and_get_token(client, "vehicle_delete")
    headers = {"Authorization": f"Bearer {token}"}
    create_response = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    vehicle_id = create_response.json()["id"]
    
    delete_response = client.delete(f"/vehicles/{vehicle_id}", headers=headers)
    assert delete_response.status_code == status.HTTP_204_NO_CONTENT
    
    # Verificar que ya no se puede obtener
    get_response = client.get(f"/vehicles/{vehicle_id}", headers=headers)
    assert get_response.status_code == status.HTTP_404_NOT_FOUND

# --- Tests para Mantenimiento --- 

def test_add_maintenance_record_success(client: TestClient):
    token, _ = create_user_and_get_token(client, "maint_add")
    headers = {"Authorization": f"Bearer {token}"}
    create_response = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    vehicle_id = create_response.json()["id"]
    
    response = client.post(f"/vehicles/{vehicle_id}/maintenance", headers=headers, json=MAINTENANCE_DATA_OIL)
    
    assert response.status_code == status.HTTP_201_CREATED # Esperamos 201 según la signatura de la ruta
    data = response.json()
    assert data["type"] == MAINTENANCE_DATA_OIL["type"]
    assert data["last_change_km"] == MAINTENANCE_DATA_OIL["last_change_km"]
    assert "id" in data
    assert "next_change_km" in data # Verificar que se calcula

def test_get_maintenance_records_success(client: TestClient):
    token, _ = create_user_and_get_token(client, "maint_get")
    headers = {"Authorization": f"Bearer {token}"}
    create_response = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    vehicle_id = create_response.json()["id"]
    
    # Añadir dos registros
    # Usar copias para evitar modificar los diccionarios originales si hay reintentos
    add_resp_1 = client.post(f"/vehicles/{vehicle_id}/maintenance", headers=headers, json=MAINTENANCE_DATA_OIL.copy())
    assert add_resp_1.status_code == status.HTTP_201_CREATED, f"Fallo al añadir OIL: {add_resp_1.text}"
    add_resp_2 = client.post(f"/vehicles/{vehicle_id}/maintenance", headers=headers, json=MAINTENANCE_DATA_BRAKES.copy())
    assert add_resp_2.status_code == status.HTTP_201_CREATED, f"Fallo al añadir BRAKES: {add_resp_2.text}"
    
    response = client.get(f"/vehicles/{vehicle_id}/maintenance", headers=headers)
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert isinstance(data, list)
    assert len(data) == 2
    # Ordenar por tipo para asegurar la comparación independientemente del orden de inserción
    data.sort(key=lambda x: x['type'])
    assert data[0]["type"] == MAINTENANCE_DATA_OIL["type"]
    assert data[1]["type"] == MAINTENANCE_DATA_BRAKES["type"]

def test_delete_maintenance_record_success(client: TestClient):
    token, _ = create_user_and_get_token(client, "maint_delete")
    headers = {"Authorization": f"Bearer {token}"}
    create_response = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    vehicle_id = create_response.json()["id"]
    add_response = client.post(f"/vehicles/{vehicle_id}/maintenance", headers=headers, json=MAINTENANCE_DATA_OIL.copy())
    assert add_response.status_code == status.HTTP_201_CREATED, f"Fallo al añadir registro para borrar: {add_response.text}"
    maintenance_id = add_response.json()["id"]
    
    delete_response = client.delete(f"/vehicles/{vehicle_id}/maintenance/{maintenance_id}", headers=headers)
    assert delete_response.status_code == status.HTTP_204_NO_CONTENT
    
    # Verificar que ya no está en la lista
    get_response = client.get(f"/vehicles/{vehicle_id}/maintenance", headers=headers)
    assert get_response.status_code == status.HTTP_200_OK
    assert len(get_response.json()) == 0

# --- Tests para Manual PDF (GridFS) --- 

# Crear un archivo PDF falso en memoria
fake_pdf_content = b"%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj 2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj 3 0 obj<</Type/Page/MediaBox[0 0 612 792]>>endobj\nxref\n0 4\n0000000000 65535 f\n0000000010 00000 n\n0000000059 00000 n\n0000000112 00000 n\ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n178\n%%EOF"
fake_pdf_file = ("manual.pdf", io.BytesIO(fake_pdf_content), "application/pdf")

def test_upload_manual_success(client: TestClient):
    token, _ = create_user_and_get_token(client, "manual_upload")
    headers = {"Authorization": f"Bearer {token}"}
    create_response = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    vehicle_id = create_response.json()["id"]
    
    # El TestClient requiere que los archivos se pasen en un diccionario 'files'
    # Crear una nueva instancia de BytesIO para cada test para evitar problemas de cursor
    files = {"file": ("manual.pdf", io.BytesIO(fake_pdf_content), "application/pdf")}
    
    response = client.post(f"/vehicles/{vehicle_id}/manual", headers=headers, files=files)
    
    assert response.status_code == status.HTTP_201_CREATED, f"Error al subir manual: {response.text}"
    # Verificar que el vehículo ahora tiene una referencia al manual
    get_vehicle_response = client.get(f"/vehicles/{vehicle_id}", headers=headers)
    assert get_vehicle_response.status_code == status.HTTP_200_OK
    assert get_vehicle_response.json()["pdf_manual_grid_fs_id"] is not None

def test_upload_manual_wrong_file_type(client: TestClient):
    token, _ = create_user_and_get_token(client, "manual_upload_wrongtype")
    headers = {"Authorization": f"Bearer {token}"}
    create_response = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    vehicle_id = create_response.json()["id"]
    
    # Archivo de texto plano
    fake_txt_file = ("manual.txt", io.BytesIO(b"not a pdf"), "text/plain")
    files = {"file": fake_txt_file}
    
    response = client.post(f"/vehicles/{vehicle_id}/manual", headers=headers, files=files)
    
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "El archivo debe ser un PDF" in response.json()["detail"]

def test_get_manual_success(client: TestClient):
    token, _ = create_user_and_get_token(client, "manual_get")
    headers = {"Authorization": f"Bearer {token}"}
    create_response = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    vehicle_id = create_response.json()["id"]
    
    # Subir primero
    files = {"file": ("manual.pdf", io.BytesIO(fake_pdf_content), "application/pdf")}
    upload_resp = client.post(f"/vehicles/{vehicle_id}/manual", headers=headers, files=files)
    assert upload_resp.status_code == status.HTTP_201_CREATED, f"Fallo al subir manual para GET: {upload_resp.text}"
    
    # Obtener
    response = client.get(f"/vehicles/{vehicle_id}/manual", headers=headers)
    
    assert response.status_code == status.HTTP_200_OK
    assert response.content == fake_pdf_content
    assert response.headers["content-type"] == "application/pdf"

def test_get_manual_not_found(client: TestClient):
    token, _ = create_user_and_get_token(client, "manual_get_notfound")
    headers = {"Authorization": f"Bearer {token}"}
    create_response = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    vehicle_id = create_response.json()["id"]
    # No subir manual
    
    response = client.get(f"/vehicles/{vehicle_id}/manual", headers=headers)
    assert response.status_code == status.HTTP_404_NOT_FOUND

def test_delete_manual_success(client: TestClient):
    token, _ = create_user_and_get_token(client, "manual_delete")
    headers = {"Authorization": f"Bearer {token}"}
    create_response = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    vehicle_id = create_response.json()["id"]
    
    # Subir primero
    files = {"file": ("manual.pdf", io.BytesIO(fake_pdf_content), "application/pdf")}
    upload_resp = client.post(f"/vehicles/{vehicle_id}/manual", headers=headers, files=files)
    assert upload_resp.status_code == status.HTTP_201_CREATED, f"Fallo al subir manual para DELETE: {upload_resp.text}"
    
    # Verificar que existe
    get_response_before = client.get(f"/vehicles/{vehicle_id}/manual", headers=headers)
    assert get_response_before.status_code == status.HTTP_200_OK
    
    # Eliminar
    delete_response = client.delete(f"/vehicles/{vehicle_id}/manual", headers=headers)
    assert delete_response.status_code == status.HTTP_204_NO_CONTENT
    
    # Verificar que ya no existe
    get_response_after = client.get(f"/vehicles/{vehicle_id}/manual", headers=headers)
    assert get_response_after.status_code == status.HTTP_404_NOT_FOUND
    
    # Verificar que la referencia se eliminó del vehículo
    get_vehicle_response = client.get(f"/vehicles/{vehicle_id}", headers=headers)
    assert get_vehicle_response.status_code == status.HTTP_200_OK
    assert get_vehicle_response.json()["pdf_manual_grid_fs_id"] is None

# --- TESTS AVANZADOS Y TODOs ---

def test_update_maintenance_record_success(client: TestClient):
    token, _ = create_user_and_get_token(client, "maint_update")
    headers = {"Authorization": f"Bearer {token}"}
    create_response = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    vehicle_id = create_response.json()["id"]
    add_response = client.post(f"/vehicles/{vehicle_id}/maintenance", headers=headers, json=MAINTENANCE_DATA_OIL.copy())
    assert add_response.status_code == status.HTTP_201_CREATED
    maintenance_id = add_response.json()["id"]

    update_data = {
        "type": "Cambio de Aceite",
        "notes": "Actualizado por test",
        "last_change_km": 46000,
        "recommended_interval_km": 12000,
        "last_change_date": (datetime.utcnow() - timedelta(days=10)).strftime('%Y-%m-%dT%H:%M:%S'),
        "km_since_last_change": 1000
    }

    response = client.put(f"/vehicles/{vehicle_id}/maintenance/{maintenance_id}", headers=headers, json=update_data)
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["id"] == maintenance_id
    assert data["notes"] == "Actualizado por test"
    assert data["last_change_km"] == 46000
    assert data["recommended_interval_km"] == 12000
    assert data["next_change_km"] == 46000 + 12000  # Verificar el cálculo automático
    assert data["km_since_last_change"] == 1000


def test_complete_maintenance_success(client: TestClient):
    token, _ = create_user_and_get_token(client, "maint_complete")
    headers = {"Authorization": f"Bearer {token}"}
    
    # Crear vehículo
    create_response = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    vehicle_id = create_response.json()["id"]
    
    # Crear mantenimiento
    add_response = client.post(f"/vehicles/{vehicle_id}/maintenance", headers=headers, json=MAINTENANCE_DATA_OIL.copy())
    assert add_response.status_code == status.HTTP_201_CREATED
    maintenance_id = add_response.json()["id"]

    # Refrescar token para la siguiente operación
    login_response = client.post(
        "/auth/login",
        data={"username": f"test_maint_complete@example.com", "password": "password123"}
    )
    assert login_response.status_code == status.HTTP_200_OK
    token_fresh = login_response.json()["access_token"]
    headers_fresh = {"Authorization": f"Bearer {token_fresh}"}

    # Actualizar con km recorridos
    update_data = {
        "type": "Cambio de Aceite",
        "last_change_km": 45000,
        "recommended_interval_km": 15000,
        "last_change_date": (datetime.utcnow() - timedelta(days=180)).strftime('%Y-%m-%dT%H:%M:%S'),
        "km_since_last_change": 500
    }
    update_response = client.put(f"/vehicles/{vehicle_id}/maintenance/{maintenance_id}", headers=headers_fresh, json=update_data)
    assert update_response.status_code == status.HTTP_200_OK
    
    # Refrescar token nuevamente
    login_response2 = client.post(
        "/auth/login",
        data={"username": f"test_maint_complete@example.com", "password": "password123"}
    )
    assert login_response2.status_code == status.HTTP_200_OK
    token_fresh2 = login_response2.json()["access_token"]
    headers_fresh2 = {"Authorization": f"Bearer {token_fresh2}"}

    # Completar mantenimiento
    response = client.post(f"/vehicles/{vehicle_id}/maintenance/{maintenance_id}/complete", headers=headers_fresh2)
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["id"] == maintenance_id
    assert data["km_since_last_change"] == 0.0
    assert data["last_change_km"] == 45000 + 500
    assert data["next_change_km"] == data["last_change_km"] + data["recommended_interval_km"]


def test_update_itv_and_complete_itv(client: TestClient):
    token, _ = create_user_and_get_token(client, "itv_update")
    headers = {"Authorization": f"Bearer {token}"}
    create_response = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    vehicle_id = create_response.json()["id"]

    # Actualizar ITV con fecha pasada (última ITV)
    from datetime import timezone
    last_itv_date = (datetime.utcnow() - timedelta(days=400)).replace(tzinfo=timezone.utc)
    itv_data = {"itv_date": last_itv_date.isoformat()}
    response = client.post(f"/vehicles/{vehicle_id}/itv", headers=headers, json=itv_data)
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert "last_itv_date" in data
    assert "next_itv_date" in data

    # Completar ITV (la próxima se convierte en la última)
    response2 = client.post(f"/vehicles/{vehicle_id}/itv/complete", headers=headers)
    assert response2.status_code == status.HTTP_200_OK
    data2 = response2.json()
    assert "last_itv_date" in data2
    assert "next_itv_date" in data2


def test_analyze_maintenance_pdf_no_manual(client: TestClient):
    token, _ = create_user_and_get_token(client, "analyze_pdf_no_manual")
    headers = {"Authorization": f"Bearer {token}"}
    create_response = client.post("/vehicles", headers=headers, json=VEHICLE_DATA_1)
    vehicle_id = create_response.json()["id"]
    # No subimos manual
    response = client.post(f"/vehicles/{vehicle_id}/maintenance-ai", headers=headers)
    assert response.status_code == 404
    assert "manual" in response.json()["detail"].lower()

