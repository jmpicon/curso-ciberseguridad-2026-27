import pytest

from reservas import bd, informes, sesiones, utilidades


@pytest.fixture
def con():
    c = bd.conectar()
    bd.anadir_reserva(c, "ana", "2.04", "2026-11-10", "08:00")
    bd.anadir_reserva(c, "luis", "2.05", "2026-11-11", "10:00")
    yield c
    c.close()


def test_buscar_reservas_de_un_usuario(con):
    assert bd.buscar_reservas(con, "ana") == [("2.04", "2026-11-10", "08:00")]


def test_listar_ordenado_por_aula(con):
    filas = bd.listar_ordenado(con, "aula")
    assert [f[1] for f in filas] == ["2.04", "2.05"]


def test_listar_ordenado_rechaza_columna(con):
    with pytest.raises(ValueError):
        bd.listar_ordenado(con, "usuario; DROP TABLE reservas")


def test_password_correcta_e_incorrecta():
    guardado = utilidades.hash_password("Prueba-2026")
    assert utilidades.verificar_password("Prueba-2026", guardado)
    assert not utilidades.verificar_password("otra", guardado)


def test_token_largo_y_distinto():
    a, b = utilidades.generar_token(), utilidades.generar_token()
    assert len(a) >= 32 and a != b


def test_orden_de_exposicion_mantiene_alumnos():
    alumnos = ["01", "02", "03", "04"]
    assert sorted(utilidades.orden_de_exposicion(alumnos)) == alumnos


def test_cookie_ida_y_vuelta():
    datos = {"usuario": "ana", "rol": "alumno"}
    assert sesiones.leer_cookie(sesiones.crear_cookie(datos)) == datos


def test_leer_informe():
    assert "aula 2.04" in informes.leer_informe("ocupacion-octubre.txt")
