from utils.car_logo_scraper import get_car_logo
import logging

# Configurar logging
logging.basicConfig(level=logging.INFO)

# Lista de marcas a probar
brands = ['Volkswagen', 'Ford', 'Toyota', 'Honda', 'BMW', 'Mercedes']

print("Prueba de obtención de logos de coches:")
print("-" * 40)

for brand in brands:
    print(f"Buscando logo para {brand}...")
    logo = get_car_logo(brand)
    if logo:
        print(f"✅ Logo encontrado para {brand} (longitud: {len(logo)} caracteres)")
    else:
        print(f"❌ No se encontró logo para {brand}")
    print("-" * 40) 