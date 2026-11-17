"""Configuración de la aplicación.

⚠️ PRÁCTICA PPS-11: Hay secretos escritos directamente en este fichero.
Tu tarea es moverlos a variables de entorno y hacer que la app no arranque
si faltan. Busca los TODO para saber qué cambiar.
"""
import os
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent

# TODO 1 — Lee SECRET_KEY de la variable de entorno MIWEB_SECRET_KEY.
#           Pista: os.environ.get("MIWEB_SECRET_KEY")
SECRET_KEY = "reservas-2026-cambiar"

# TODO 2 — Lee ADMIN_CLAVE de la variable de entorno MIWEB_ADMIN_CLAVE.
ADMIN_CLAVE = "Admin2026!"

# TODO 3 — DEBUG debe estar apagado por defecto. Solo "1" lo enciende.
#           Pista: os.environ.get("MIWEB_DEBUG", "0") == "1"
DEBUG = True

BD = Path(os.environ.get("MIWEB_BD", RAIZ / "datos" / "miweb.db"))
REGISTRO_SEGURIDAD = Path(os.environ.get("MIWEB_REGISTRO", RAIZ / "registros" / "seguridad.log"))
