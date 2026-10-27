"""Experimento: ¿impide el assert que un alumno borre reservas?"""

from reservas import bd

con = bd.conectar()
bd.anadir_reserva(con, "ana", "2.04", "2026-11-10", "08:00")
bd.borrar_reserva(con, 1, es_admin=False)
print("Reservas que quedan:", con.execute("SELECT COUNT(*) FROM reservas").fetchone()[0])
