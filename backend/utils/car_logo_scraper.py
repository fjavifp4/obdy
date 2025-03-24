import requests
from bs4 import BeautifulSoup
import base64
import re
import logging

logger = logging.getLogger(__name__)

# Cabeceras para simular un navegador web
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
    'Referer': 'https://www.google.com/',
    'DNT': '1',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1'
}

def normalize_brand_name(brand_name):
    """
    Normaliza el nombre de la marca para buscar coincidencias en carlogos.org
    """
    # Convertir a minúsculas y eliminar espacios adicionales
    normalized = brand_name.lower().strip()
    
    # Mapeo de nombres de marcas comunes con sus equivalentes en carlogos.org
    brand_mapping = {
        'vw': 'volkswagen',
        'mercedes': 'mercedes-benz',
        'chevy': 'chevrolet',
        'gm': 'general-motors',
    }
    
    # Reemplazar si hay una coincidencia exacta
    if normalized in brand_mapping:
        return brand_mapping[normalized]
    
    # Manejo especial para algunas marcas
    for key, value in brand_mapping.items():
        if key in normalized:
            return value
    
    # Remover caracteres especiales y convertir espacios a guiones
    normalized = re.sub(r'[^\w\s]', '', normalized)
    normalized = normalized.replace(' ', '-')
    
    return normalized

def get_car_logo(brand):
    """
    Obtiene el logo de la marca de coche haciendo scraping a carlogos.org
    
    Args:
        brand (str): Nombre de la marca del coche
    
    Returns:
        str: Imagen del logo codificada en base64 o None si no se encuentra
    """
    try:
        # Normalizar el nombre de la marca para la URL
        normalized_brand = normalize_brand_name(brand)
        
        # URL base para carlogos.org
        base_url = "https://www.carlogos.org/car-brands"
        
        # Construir URL completa
        url = f"{base_url}/{normalized_brand}-logo.html"
        
        # Realizar petición HTTP
        try:
            response = requests.get(url, headers=HEADERS, timeout=10)
            response.raise_for_status()  # Lanzar excepción si hay error HTTP
        except (requests.RequestException, requests.Timeout) as e:
            logger.warning(f"Error al acceder a {url}: {str(e)}")
            return search_logo_in_main_page(brand)
        
        # Parsear la página HTML
        soup = BeautifulSoup(response.content, 'html.parser')
        
        # Método 1: Buscar el logo en la estructura: article > logo-art > present > a > img
        logo_present = soup.select_one('div.article div.logo-art div.present a img')
        if logo_present and logo_present.get('src'):
            img_url = logo_present.get('src')
            logger.info(f"Encontrado logo mediante estructura article>logo-art>present: {img_url}")
            # Asegurarse de que la URL sea absoluta
            if not img_url.startswith(('http://', 'https://')):
                img_url = f"https://www.carlogos.org{img_url}"
            try:
                return download_and_encode_image(img_url)
            except Exception as e:
                logger.warning(f"Error al descargar logo de {img_url}: {str(e)}")
        
        # Método 2: Buscar cualquier imagen que coincida con el patrón /car-logos/{brand}*.png
        img_tags = soup.find_all('img')
        for img in img_tags:
            src = img.get('src', '')
            if f"/car-logos/{normalized_brand}" in src.lower() and '.png' in src.lower():
                logger.info(f"Encontrado logo mediante búsqueda de patrón en src: {src}")
                # Asegurarse de que la URL sea absoluta
                if not src.startswith(('http://', 'https://')):
                    src = f"https://www.carlogos.org{src}"
                try:
                    return download_and_encode_image(src)
                except Exception as e:
                    logger.warning(f"Error al descargar logo de {src}: {str(e)}")
                    continue
        
        # Método 3: El método original
        logo_div = soup.find('div', class_='car-logo')
        if logo_div:
            img_tag = logo_div.find('img')
            if img_tag and img_tag.get('src'):
                img_url = img_tag.get('src')
                logger.info(f"Encontrado logo mediante método original: {img_url}")
                # Asegurarse de que la URL sea absoluta
                if not img_url.startswith(('http://', 'https://')):
                    img_url = f"https://www.carlogos.org{img_url}"
                try:
                    return download_and_encode_image(img_url)
                except Exception as e:
                    logger.warning(f"Error al descargar logo de {img_url}: {str(e)}")
        
        # Si no se encuentra, buscar en la página principal
        logger.info(f"No se encontró el logo para {brand} en la página específica, buscando en la lista general...")
        return search_logo_in_main_page(brand)
    
    except Exception as e:
        logger.error(f"Error al obtener el logo para {brand}: {str(e)}")
        return None

def download_and_encode_image(img_url):
    """
    Descarga una imagen y la codifica en base64
    
    Args:
        img_url (str): URL de la imagen
    
    Returns:
        str: Imagen codificada en base64 o None si hay error
    """
    try:
        # Verificar que la URL es válida
        if not img_url or not isinstance(img_url, str):
            logger.error(f"URL de imagen inválida: {img_url}")
            return None

        # Realizar la petición con timeout y verificación de estado
        img_response = requests.get(img_url, headers=HEADERS, timeout=10)
        img_response.raise_for_status()

        # Verificar que el contenido es una imagen
        content_type = img_response.headers.get('content-type', '')
        if not content_type.startswith('image/'):
            logger.error(f"El contenido no es una imagen: {content_type}")
            return None

        # Verificar que el contenido no está vacío
        if not img_response.content:
            logger.error("El contenido de la imagen está vacío")
            return None

        # Codificar la imagen en base64
        try:
            logo_base64 = base64.b64encode(img_response.content).decode('utf-8')
            if not logo_base64:
                logger.error("Error al codificar la imagen en base64")
                return None
            return logo_base64
        except Exception as e:
            logger.error(f"Error al codificar la imagen en base64: {str(e)}")
            return None

    except requests.exceptions.Timeout:
        logger.error(f"Timeout al descargar la imagen de {img_url}")
        return None
    except requests.exceptions.RequestException as e:
        logger.error(f"Error en la petición HTTP al descargar la imagen de {img_url}: {str(e)}")
        return None
    except Exception as e:
        logger.error(f"Error inesperado al descargar o codificar la imagen {img_url}: {str(e)}")
        return None

def search_logo_in_main_page(brand):
    """
    Busca el logo en la página principal de carlogos.org si no encuentra la página específica
    
    Args:
        brand (str): Nombre de la marca del coche
    
    Returns:
        str: Imagen del logo codificada en base64 o None si no se encuentra
    """
    try:
        # URL de la página principal con todos los logos
        url = "https://www.carlogos.org/car-brands/"
        
        # Realizar petición HTTP con timeout para evitar que se quede esperando
        try:
            response = requests.get(url, headers=HEADERS, timeout=10)
            response.raise_for_status()  # Lanzar excepción si hay error HTTP
        except (requests.RequestException, requests.Timeout) as e:
            logger.warning(f"No se pudo acceder a la página principal de carlogos.org: {str(e)}")
            return search_direct_image(brand)
        
        # Parsear la página HTML
        soup = BeautifulSoup(response.content, 'html.parser')
        
        # Normalizar el nombre de la marca para buscar coincidencias
        search_brand = normalize_brand_name(brand)
        
        # Método 1: Buscar enlaces con clase logo-item que contengan el nombre de la marca
        logo_links = soup.find_all('a', class_='logo-item')
        for link in logo_links:
            # Obtener el texto del enlace y normalizarlo
            link_text = link.get_text().lower() if link.get_text() else ''
            
            # Buscar coincidencias con el nombre de la marca
            if search_brand in link_text or any(search_brand in alt.lower() for alt in link.get('alt', '').split()):
                # Encontrar la imagen dentro del enlace
                img_tag = link.find('img')
                if img_tag and img_tag.get('src'):
                    img_url = img_tag.get('src')
                    logger.info(f"Encontrado logo en página principal mediante logo-item: {img_url}")
                    # Asegurarse de que la URL sea absoluta
                    if not img_url.startswith(('http://', 'https://')):
                        img_url = f"https://www.carlogos.org{img_url}"
                    return download_and_encode_image(img_url)
        
        # Método 2: Buscar cualquier imagen que coincida con el patrón /car-logos/{brand}*.png
        img_tags = soup.find_all('img')
        for img in img_tags:
            src = img.get('src', '')
            if f"/car-logos/{search_brand}" in src.lower() and '.png' in src.lower():
                logger.info(f"Encontrado logo en página principal mediante patrón en src: {src}")
                # Asegurarse de que la URL sea absoluta
                if not src.startswith(('http://', 'https://')):
                    src = f"https://www.carlogos.org{src}"
                return download_and_encode_image(src)
        
        logger.warning(f"No se encontró coincidencia para {brand} en la página principal")
        return search_direct_image(brand)
    
    except Exception as e:
        logger.error(f"Error al buscar el logo en la página principal para {brand}: {str(e)}")
        return search_direct_image(brand)

def search_direct_image(brand):
    """
    Último recurso: buscar directamente una URL de imagen basada en patrones comunes
    
    Args:
        brand (str): Nombre de la marca del coche
    
    Returns:
        str: Imagen del logo codificada en base64 o None si no se encuentra
    """
    try:
        normalized_brand = normalize_brand_name(brand)
        
        # Lista de posibles patrones de URL para el logo
        url_patterns = [
            f"https://www.carlogos.org/car-logos/{normalized_brand}-logo.png",
            f"https://www.carlogos.org/car-logos/{normalized_brand}-logo-640.png", 
            f"https://www.carlogos.org/car-logos/{normalized_brand}-logo-2020-640.png",
            f"https://www.carlogos.org/car-logos/{normalized_brand}-logo-2017-640.png",
            f"https://www.carlogos.org/logo/{normalized_brand}-logo.png"
        ]
        
        for url in url_patterns:
            try:
                response = requests.get(url, headers=HEADERS, timeout=5)
                if response.status_code == 200:
                    logger.info(f"Encontrado logo mediante URL directa: {url}")
                    return base64.b64encode(response.content).decode('utf-8')
            except:
                continue
        
        logger.warning(f"No se pudo encontrar un logo para {brand} mediante ningún método")
        return None
    
    except Exception as e:
        logger.error(f"Error al buscar la imagen directamente para {brand}: {str(e)}")
        return None 