"""Acceso a la base de datos de reservas del aula de informática."""

import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "reservas.db")


def inicializar_db():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS reservas (
            id      INTEGER PRIMARY KEY AUTOINCREMENT,
            aula    TEXT NOT NULL,
            fecha   TEXT NOT NULL,
            usuario TEXT NOT NULL
        )
    """)
    conn.commit()
    conn.close()


def buscar_reservas(usuario):
    """Devuelve todas las reservas de un usuario.

    El parámetro 'usuario' llega del formulario web — dato no confiable.
    """
    conn = sqlite3.connect(DB_PATH)
    consulta = "SELECT * FROM reservas WHERE usuario = '" + usuario + "'"
    resultado = conn.execute(consulta).fetchall()
    conn.close()
    return resultado


def insertar_reserva(aula, fecha, usuario):
    """Inserta una reserva nueva. Usa marcadores — correcto."""
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
        "INSERT INTO reservas (aula, fecha, usuario) VALUES (?, ?, ?)",
        (aula, fecha, usuario),
    )
    conn.commit()
    conn.close()


def listar_aulas():
    """Lista las aulas que tienen al menos una reserva registrada.

    La variable 'tipo' es un valor fijo del programa, no llega del usuario.
    """
    tipo = "Aula"
    conn = sqlite3.connect(DB_PATH)
    consulta = "SELECT DISTINCT aula FROM reservas WHERE aula LIKE '%" + tipo + "%'"
    resultado = conn.execute(consulta).fetchall()
    conn.close()
    return [fila[0] for fila in resultado]


def eliminar_reserva(reserva_id, es_admin):
    """Elimina una reserva. Solo el administrador puede hacerlo.

    El parámetro 'es_admin' se lee de la cookie de sesión del usuario.
    """
    assert es_admin, "Solo el administrador puede eliminar reservas"
    conn = sqlite3.connect(DB_PATH)
    conn.execute("DELETE FROM reservas WHERE id = ?", (reserva_id,))
    conn.commit()
    conn.close()
