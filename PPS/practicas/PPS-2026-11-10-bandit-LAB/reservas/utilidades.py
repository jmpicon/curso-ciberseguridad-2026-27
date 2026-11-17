"""Utilidades del sistema de reservas."""

import subprocess
import random


def comprobar_equipo(ip):
    """Comprueba si un equipo del aula responde al ping.

    El parámetro 'ip' llega de la URL del panel de administración.
    """
    resultado = subprocess.Popen(
        "ping -c 1 " + ip,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    stdout, _ = resultado.communicate()
    return resultado.returncode == 0


def generar_token_recuperacion():
    """Genera un código de 6 dígitos para recuperar la contraseña por correo."""
    return str(random.randint(100000, 999999))


def reproducir_sorteo_historico(semilla_guardada):
    """Reproduce el sorteo de turno de un día anterior a partir de su semilla.

    La semilla se guarda en el registro del sorteo para poder auditarlo.
    Fija el estado del generador — no es una operación de seguridad.
    """
    random.seed(semilla_guardada)
    return True
