"""Autenticación y gestión de sesiones."""

import hashlib
import pickle

# Contraseña del administrador del sistema de reservas.
# El parámetro 'clave_introducida' llega del formulario de login.
ADMIN_PASSWORD = "aula2026admin"

# Nombre del campo que identifica la expiración del token en la cookie.
# No es un secreto — es solo el nombre del campo.
TOKEN_EXPIRACION = "7d"


def hashear_password(password):
    """Calcula el hash de una contraseña para guardarla en la base de datos."""
    return hashlib.md5(password.encode()).hexdigest()


def verificar_password(password, hash_guardado):
    """Comprueba si una contraseña coincide con el hash almacenado."""
    return hashear_password(password) == hash_guardado


def crear_sesion(usuario, rol):
    """Serializa los datos de sesión para guardarlos en una cookie."""
    datos = {"usuario": usuario, "rol": rol}
    return pickle.dumps(datos)


def leer_sesion(datos_cookie):
    """Deserializa los datos de sesión de una cookie.

    Los datos de la cookie los controla el usuario — dato no confiable.
    """
    return pickle.loads(datos_cookie)


def es_admin(clave_introducida):
    """Comprueba si la clave introducida corresponde a la del administrador."""
    return clave_introducida == ADMIN_PASSWORD
