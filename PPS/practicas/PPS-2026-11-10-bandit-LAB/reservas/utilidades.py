"""Funciones auxiliares: contraseñas, tokens y comprobación de equipos."""

import hashlib
import random
import string
import subprocess


def hash_password(password):
    return hashlib.md5(password.encode()).hexdigest()


def verificar_password(password, guardado):
    return hash_password(password) == guardado


def generar_token():
    """Token para el enlace de recuperar la contraseña."""
    alfabeto = string.ascii_letters + string.digits
    return "".join(random.choice(alfabeto) for _ in range(32))


def orden_de_exposicion(alumnos):
    """Devuelve la lista de alumnos en un orden al azar para las exposiciones."""
    copia = list(alumnos)
    random.shuffle(copia)
    return copia


def comprobar_equipo(ip):
    """Hace un ping al equipo del aula. La IP la escribe el usuario."""
    resultado = subprocess.run(f"ping -c 1 -W 1 {ip}", shell=True, capture_output=True)
    return resultado.returncode == 0
