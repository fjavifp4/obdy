import pytest
from fastapi.testclient import TestClient
from fastapi import status
from bson import ObjectId
from datetime import datetime

# Importar funciones auxiliares y datos
from ..conftest import create_user_and_get_token

# --- Datos Simulados --- 
# Estructura simplificada basada en el nombre ListaEESSPrecio (DATOS CRUDOS)
MOCKED_STATION_RAW_1 = {
    "IDEESS": "1111", # ID de la estación
    "C.P.": "28001",
    "Dirección": "CALLE SERRANO, 1",
    "Horario": "L-D: 24H",
    "Latitud": "40.426917",
    "Longitud (WGS84)": "-3.684639",
    "Localidad": "MADRID",
    "Municipio": "Madrid",
    "Provincia": "MADRID",
    "Precio Gasolina 95 E5": "1.801",
    "Precio Gasoleo A": "1.755",
    "Rótulo": "REPSOL",
    "% Bioetanol": "0,0",
    "% Éster metílico": "0,0",
    # ... otros campos de precios y detalles ...
}
MOCKED_STATION_RAW_2 = {
    "IDEESS": "2222",
    "C.P.": "28002",
    "Dirección": "CALLE PRINCIPE DE VERGARA, 100",
    "Horario": "L-V: 07:00-22:00",
    "Latitud": "40.435806", 
    "Longitud (WGS84)": "-3.677472",
    "Localidad": "MADRID",
    "Municipio": "Madrid",
    "Provincia": "MADRID",
    "Precio Gasolina 95 E5": "1.799",
    "Precio Gasoleo A": "1.750",
    "Precio Gasoleo Premium": "1.850",
    "Rótulo": "CEPSA",
    "% Bioetanol": "0,0",
    "% Éster metílico": "0,0",
}
# --- Datos Simulados PROCESADOS (como los devolvería _fetch_all_stations real) ---
MOCKED_STATION_PROCESSED_1 = {
    "id": "1111",
    "name": "REPSOL MADRID", # Normalizado
    "brand": "REPSOL",
    "latitude": 40.426917,
    "longitude": -3.684639,
    "address": "CALLE SERRANO, 1",
    "city": "MADRID",
    "province": "MADRID",
    "postal_code": "28001",
    "schedule": "L-D: 24H",
    "prices": {"gasolina95": 1.801, "diesel": 1.755},
    "last_updated": datetime.now(), # El valor exacto no suele importan en tests
    # No incluimos is_favorite aquí, porque eso lo añade _get_processed_stations
}
MOCKED_STATION_PROCESSED_2 = {
    "id": "2222",
    "name": "CEPSA MADRID", # Normalizado
    "brand": "CEPSA",
    "latitude": 40.435806,
    "longitude": -3.677472,
    "address": "CALLE PRINCIPE DE VERGARA, 100",
    "city": "MADRID",
    "province": "MADRID",
    "postal_code": "28002",
    "schedule": "L-V: 07:00-22:00",
    "prices": {"gasolina95": 1.799, "diesel": 1.750, "dieselPlus": 1.850},
    "last_updated": datetime.now(),
}
# Lista PROCESADA para el mock
MOCKED_PROCESSED_STATIONS_LIST = [MOCKED_STATION_PROCESSED_1, MOCKED_STATION_PROCESSED_2]

# --- Mocking Setup --- 
@pytest.fixture(autouse=True)
def mock_external_calls(mocker):
    """Mockea las llamadas externas y de sistema de archivos."""
    # --- CORRECCIÓN: Mockear _fetch_all_stations para que devuelva la lista PROCESADA ---
    # mocker.patch("routers.fuel._fetch_all_stations", return_value=MOCKED_STATIONS_DATA["ListaEESSPrecio"]) # Devolvía datos CRUDOS
    mocker.patch("routers.fuel._fetch_all_stations", return_value=MOCKED_PROCESSED_STATIONS_LIST)
    # --- FIN CORRECCIÓN ---
    
    # Mockear funciones de carga/guardado de backup (sigue siendo útil)
    mocker.patch("routers.fuel._load_preloaded_data", return_value=None) # No cargar backup
    mocker.patch("routers.fuel._save_data_backup", return_value=True) # Simular éxito al guardar
    
    # (Opcional) Mockear el cálculo de precios generales si es complejo
    # mocker.patch("routers.fuel._calculate_general_prices", return_value={...})

# --- Tests para Favoritos --- 

def test_add_favorite_station_success(client: TestClient):
    token, user_id = create_user_and_get_token(client, "fav_add")
    headers = {"Authorization": f"Bearer {token}"}
    # Usar el ID procesado
    station_id_to_add = MOCKED_STATION_PROCESSED_1["id"]
    
    response = client.post("/fuel/stations/favorites", headers=headers, json={"station_id": station_id_to_add})
    
    assert response.status_code == status.HTTP_201_CREATED
    data = response.json()
    assert data["station_id"] == station_id_to_add
    assert data["user_id"] == user_id

def test_add_favorite_station_already_exists(client: TestClient):
    token, _ = create_user_and_get_token(client, "fav_add_dup")
    headers = {"Authorization": f"Bearer {token}"}
    station_id_to_add = MOCKED_STATION_PROCESSED_1["id"]
    
    # Añadir una vez
    client.post("/fuel/stations/favorites", headers=headers, json={"station_id": station_id_to_add})
    # Intentar añadir de nuevo
    response = client.post("/fuel/stations/favorites", headers=headers, json={"station_id": station_id_to_add})
    
    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "La estación ya está en favoritos" in response.json()["detail"]

def test_get_favorite_stations_success(client: TestClient):
    token, user_id = create_user_and_get_token(client, "fav_get")
    headers = {"Authorization": f"Bearer {token}"}
    station_id_1 = MOCKED_STATION_PROCESSED_1["id"]
    station_id_2 = MOCKED_STATION_PROCESSED_2["id"]
    
    # Añadir dos favoritos
    client.post("/fuel/stations/favorites", headers=headers, json={"station_id": station_id_1})
    client.post("/fuel/stations/favorites", headers=headers, json={"station_id": station_id_2})
    
    response = client.get("/fuel/stations/favorites", headers=headers)
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert isinstance(data["stations"], list)
    assert len(data["stations"]) == 2
    # Verificar que los IDs están presentes (el orden puede variar)
    returned_ids = {s["id"] for s in data["stations"]}
    assert station_id_1 in returned_ids
    assert station_id_2 in returned_ids
    # Verificar que la estructura de una estación es correcta
    # Usar datos PROCESADOS para la comparación
    assert data["stations"][0]["brand"] == MOCKED_STATION_PROCESSED_1["brand"] or data["stations"][0]["brand"] == MOCKED_STATION_PROCESSED_2["brand"]

def test_get_favorite_stations_empty(client: TestClient):
    token, _ = create_user_and_get_token(client, "fav_get_empty")
    headers = {"Authorization": f"Bearer {token}"}
    # No añadir favoritos
    response = client.get("/fuel/stations/favorites", headers=headers)
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["stations"] == []

def test_remove_favorite_station_success(client: TestClient):
    token, _ = create_user_and_get_token(client, "fav_remove")
    headers = {"Authorization": f"Bearer {token}"}
    station_id_to_remove = MOCKED_STATION_PROCESSED_1["id"]
    
    # Añadir primero
    add_resp = client.post("/fuel/stations/favorites", headers=headers, json={"station_id": station_id_to_remove})
    assert add_resp.status_code == status.HTTP_201_CREATED
    
    # Eliminar
    remove_response = client.delete(f"/fuel/stations/favorites/{station_id_to_remove}", headers=headers)
    assert remove_response.status_code == status.HTTP_200_OK # La ruta devuelve 200 OK
    assert remove_response.json() == {"message": "Estación eliminada de favoritos"}
    
    # Verificar que ya no está en la lista
    get_resp = client.get("/fuel/stations/favorites", headers=headers)
    assert get_resp.status_code == status.HTTP_200_OK
    assert not any(s["id"] == station_id_to_remove for s in get_resp.json()["stations"])

def test_remove_favorite_station_not_found(client: TestClient):
    token, _ = create_user_and_get_token(client, "fav_remove_notfound")
    headers = {"Authorization": f"Bearer {token}"}
    non_existent_station_id = "9999"
    
    response = client.delete(f"/fuel/stations/favorites/{non_existent_station_id}", headers=headers)
    assert response.status_code == status.HTTP_404_NOT_FOUND
    assert "Estación no encontrada en favoritos" in response.json()["detail"]

# --- Tests para Rutas Adicionales --- 

def test_get_fuel_prices(client: TestClient):
    token, _ = create_user_and_get_token(client, "fuel_prices")
    headers = {"Authorization": f"Bearer {token}"}
    
    response = client.get("/fuel/prices", headers=headers)
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert "prices" in data
    # Verificar precios basados en datos mockeados PROCESADOS
    assert "gasolina95" in data["prices"]
    # Media de 1.801 y 1.799 es 1.800
    assert data["prices"]["gasolina95"] == pytest.approx(1.800)
    assert "diesel" in data["prices"]
    # Media de 1.755 y 1.750 es 1.7525, redondeado a 3 decimales es 1.752
    assert data["prices"]["diesel"] == pytest.approx(1.752)
    assert "dieselPlus" in data["prices"]
    # Solo está en la estación 2
    assert data["prices"]["dieselPlus"] == MOCKED_STATION_PROCESSED_2["prices"]["dieselPlus"]
    assert len(data["prices"]) == 3

def test_get_nearby_stations_success(client: TestClient):
    token, _ = create_user_and_get_token(client, "nearby_stations")
    headers = {"Authorization": f"Bearer {token}"}
    
    # Usar coordenadas cercanas a MOCKED_STATION_PROCESSED_1
    lat = 40.427
    lng = -3.685
    radius = 1 # 1 km de radio debería incluir solo la estación 1
    
    response = client.get(f"/fuel/stations/nearby?lat={lat}&lng={lng}&radius={radius}", headers=headers)
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert isinstance(data["stations"], list)
    assert len(data["stations"]) == 1
    # Comparar con ID procesado
    assert data["stations"][0]["id"] == MOCKED_STATION_PROCESSED_1["id"]
    assert "distance" in data["stations"][0]
    assert data["stations"][0]["distance"] < radius

def test_get_nearby_stations_with_fuel_type(client: TestClient):
    token, _ = create_user_and_get_token(client, "nearby_fuel_type")
    headers = {"Authorization": f"Bearer {token}"}
    
    # Usar coordenadas cercanas a ambas y radio amplio
    lat = 40.43
    lng = -3.68
    radius = 5
    fuel_type = "dieselPlus" # Solo MOCKED_STATION_PROCESSED_2 tiene este
    
    response = client.get(f"/fuel/stations/nearby?lat={lat}&lng={lng}&radius={radius}&fuel_type={fuel_type}", headers=headers)
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert isinstance(data["stations"], list)
    assert len(data["stations"]) == 1
    assert data["stations"][0]["id"] == MOCKED_STATION_PROCESSED_2["id"]
    assert fuel_type in data["stations"][0]["prices"]

def test_get_nearby_stations_not_found(client: TestClient):
    token, _ = create_user_and_get_token(client, "nearby_notfound")
    headers = {"Authorization": f"Bearer {token}"}
    # Coordenadas lejanas
    lat = 0
    lng = 0
    radius = 1
    response = client.get(f"/fuel/stations/nearby?lat={lat}&lng={lng}&radius={radius}", headers=headers)
    assert response.status_code == status.HTTP_200_OK # Devuelve 200 con lista vacía
    assert response.json()["stations"] == []

def test_get_station_details_success(client: TestClient):
    token, user_id = create_user_and_get_token(client, "station_details")
    headers = {"Authorization": f"Bearer {token}"}
    station_id = MOCKED_STATION_PROCESSED_1["id"]
    
    # Añadir como favorito para probar ese campo
    client.post("/fuel/stations/favorites", headers=headers, json={"station_id": station_id})

    response = client.get(f"/fuel/stations/{station_id}", headers=headers)
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["id"] == station_id
    assert data["brand"] == MOCKED_STATION_PROCESSED_1["brand"]
    assert data["address"] == MOCKED_STATION_PROCESSED_1["address"]
    assert "gasolina95" in data["prices"]
    assert data["isfavorite"] is True

def test_get_station_details_not_favorite(client: TestClient):
    token, _ = create_user_and_get_token(client, "station_details_notfav")
    headers = {"Authorization": f"Bearer {token}"}
    station_id = MOCKED_STATION_PROCESSED_2["id"]
    # No añadir como favorito

    response = client.get(f"/fuel/stations/{station_id}", headers=headers)
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["id"] == station_id
    assert data["isfavorite"] is False

def test_get_station_details_not_found(client: TestClient):
    token, _ = create_user_and_get_token(client, "station_details_notfound")
    headers = {"Authorization": f"Bearer {token}"}
    non_existent_station_id = "0000"
    response = client.get(f"/fuel/stations/{non_existent_station_id}", headers=headers)
    assert response.status_code == status.HTTP_404_NOT_FOUND

def test_search_stations_by_brand(client: TestClient):
    token, _ = create_user_and_get_token(client, "search_brand")
    headers = {"Authorization": f"Bearer {token}"}
    query = "REPSOL"
    response = client.get(f"/fuel/stations/search/{query}", headers=headers)
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    # Comprobar marca procesada
    assert all(s["brand"].upper() == query for s in data)
    assert data[0]["id"] == MOCKED_STATION_PROCESSED_1["id"]

def test_search_stations_by_city(client: TestClient):
    token, _ = create_user_and_get_token(client, "search_city")
    headers = {"Authorization": f"Bearer {token}"}
    query = "MADRID"
    response = client.get(f"/fuel/stations/search/{query}", headers=headers)
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert len(data) >= 2 # Ambas estaciones mockeadas están en Madrid
    assert MOCKED_STATION_PROCESSED_1["id"] in [s["id"] for s in data]
    assert MOCKED_STATION_PROCESSED_2["id"] in [s["id"] for s in data]

def test_search_stations_no_results(client: TestClient):
    token, _ = create_user_and_get_token(client, "search_noresult")
    headers = {"Authorization": f"Bearer {token}"}
    query = "XYZ_NON_EXISTENT"
    response = client.get(f"/fuel/stations/search/{query}", headers=headers)
    assert response.status_code == status.HTTP_200_OK
    assert response.json() == [] 