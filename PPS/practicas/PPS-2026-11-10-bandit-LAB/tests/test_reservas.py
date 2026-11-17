"""Tests del sistema de reservas del aula de informática.

Estos 8 tests comprueban el comportamiento normal de la aplicación.
Tienen que pasar antes y después de las correcciones de seguridad.
No los modifiques — si una corrección los rompe, revisa la corrección.
"""

from reservas.base_datos import insertar_reserva, buscar_reservas
from reservas.autenticacion import (
    hashear_password,
    verificar_password,
    crear_sesion,
    leer_sesion,
    es_admin,
    ADMIN_PASSWORD,
)
from reservas.informes import leer_informe


def test_buscar_reserva_existente():
    insertar_reserva("Aula-01", "2026-11-15", "alumno1")
    resultado = buscar_reservas("alumno1")
    assert len(resultado) == 1
    assert resultado[0][1] == "Aula-01"


def test_buscar_reserva_inexistente():
    resultado = buscar_reservas("usuario_que_no_existe")
    assert resultado == []


def test_hashear_password_devuelve_string():
    resultado = hashear_password("clave123")
    assert isinstance(resultado, str)
    assert len(resultado) > 0


def test_passwords_distintas_dan_hashes_distintos():
    h1 = hashear_password("claveA")
    h2 = hashear_password("claveB")
    assert h1 != h2


def test_verificar_password_acepta_correcta():
    h = hashear_password("mi_clave")
    assert verificar_password("mi_clave", h) is True


def test_crear_y_leer_sesion():
    datos = crear_sesion("alumno1", "usuario")
    resultado = leer_sesion(datos)
    assert resultado["usuario"] == "alumno1"
    assert resultado["rol"] == "usuario"


def test_es_admin_con_clave_correcta():
    assert es_admin(ADMIN_PASSWORD) is True


def test_leer_informe_existente():
    contenido = leer_informe("ocupacion-octubre.txt")
    assert "octubre" in contenido.lower()
    assert len(contenido) > 0
