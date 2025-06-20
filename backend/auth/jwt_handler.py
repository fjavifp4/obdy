from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from dotenv import load_dotenv
import os

load_dotenv()

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """
    Crea un token JWT con los datos proporcionados
    
    Args:
        data (dict): Datos a codificar en el token
        expires_delta (Optional[timedelta]): Tiempo de expiración opcional
        
    Returns:
        str: Token JWT generado
    """
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 10080)))
    
    to_encode.update({"exp": expire})
    return jwt.encode(
        to_encode, 
        os.getenv("SECRET_KEY"), 
        algorithm=os.getenv("ALGORITHM")
    )

def verify_token(token: str, raise_exception: bool = False) -> Optional[dict]:
    """
    Verifica un token JWT
    
    Args:
        token (str): Token JWT a verificar
        raise_exception (bool): Si es True, propaga la excepción JWTError. Si es False, devuelve None en caso de error.
        
    Returns:
        Optional[dict]: Datos decodificados del token o None si es inválido
        
    Raises:
        JWTError: Si el token es inválido o ha expirado y raise_exception es True
    """
    try:
        payload = jwt.decode(
            token, 
            os.getenv("SECRET_KEY"), 
            algorithms=[os.getenv("ALGORITHM")]
        )
        return payload
    except JWTError as e:
        if raise_exception:
            raise e
        return None 