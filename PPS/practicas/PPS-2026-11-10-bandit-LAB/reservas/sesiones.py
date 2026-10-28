"""Sesiones guardadas en una cookie del navegador."""

import base64
import pickle


def crear_cookie(datos):
    return base64.b64encode(pickle.dumps(datos)).decode()


def leer_cookie(cookie):
    """La cookie la envía el navegador del usuario en cada petición."""
    return pickle.loads(base64.b64decode(cookie))
