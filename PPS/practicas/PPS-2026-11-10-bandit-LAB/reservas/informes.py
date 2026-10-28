"""Descarga de los informes de ocupación de las aulas."""

from pathlib import Path

from reservas.config import CARPETA_INFORMES


def leer_informe(nombre, carpeta=CARPETA_INFORMES):
    """Devuelve el texto del informe. El nombre llega en la URL: /informes?nombre=..."""
    ruta = Path(carpeta) / nombre
    return ruta.read_text(encoding="utf-8")
