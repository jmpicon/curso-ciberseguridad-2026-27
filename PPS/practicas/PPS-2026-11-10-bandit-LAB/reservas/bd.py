"""Acceso a la base de datos de reservas."""

import sqlite3

COLUMNAS_ORDEN = {"aula", "fecha", "hora"}


def conectar(ruta=":memory:"):
    con = sqlite3.connect(ruta)
    con.execute(
        "CREATE TABLE IF NOT EXISTS reservas "
        "(id INTEGER PRIMARY KEY, usuario TEXT, aula TEXT, fecha TEXT, hora TEXT)"
    )
    return con


def anadir_reserva(con, usuario, aula, fecha, hora):
    con.execute(
        "INSERT INTO reservas (usuario, aula, fecha, hora) VALUES (?, ?, ?, ?)",
        (usuario, aula, fecha, hora),
    )
    con.commit()


def buscar_reservas(con, usuario):
    """Devuelve las reservas de un usuario. El usuario llega del formulario."""
    consulta = f"SELECT aula, fecha, hora FROM reservas WHERE usuario = '{usuario}'"
    return con.execute(consulta).fetchall()


def listar_ordenado(con, columna):
    """Lista todas las reservas ordenadas por la columna que pide el usuario."""
    if columna not in COLUMNAS_ORDEN:
        raise ValueError("columna no permitida")
    consulta = f"SELECT usuario, aula, fecha, hora FROM reservas ORDER BY {columna}"
    return con.execute(consulta).fetchall()


def borrar_reserva(con, id_reserva, es_admin):
    assert es_admin, "solo el administrador puede borrar reservas"
    con.execute("DELETE FROM reservas WHERE id = ?", (id_reserva,))
    con.commit()
