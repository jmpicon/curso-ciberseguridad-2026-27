"""Lectura de informes de ocupación."""

import os

DIRECTORIO_INFORMES = os.path.join(os.path.dirname(__file__), "..", "informes")


def leer_informe(nombre):
    """Lee un informe de ocupación del aula.

    El parámetro 'nombre' llega de la URL: /informes?archivo=ocupacion-octubre.txt
    """
    ruta = os.path.join(DIRECTORIO_INFORMES, nombre)
    with open(ruta, "r", encoding="utf-8") as f:
        return f.read()
