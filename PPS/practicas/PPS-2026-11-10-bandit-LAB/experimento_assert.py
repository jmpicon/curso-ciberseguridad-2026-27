"""Demuestra que assert desaparece cuando Python se ejecuta con -O.

Ejecuta este script de dos formas y compara las salidas:

    python  experimento_assert.py      (modo normal)
    python -O experimento_assert.py    (modo optimizado — assert se omite)
"""

import os
import sys

# Ajusta el path para importar el paquete desde la carpeta del proyecto
sys.path.insert(0, os.path.dirname(__file__))

from reservas.base_datos import inicializar_db, insertar_reserva, eliminar_reserva

# Usamos una base de datos temporal para el experimento
import reservas.base_datos as bd
import tempfile

db_temporal = tempfile.mktemp(suffix=".db")
bd.DB_PATH = db_temporal
inicializar_db()
insertar_reserva("Aula-01", "2026-11-10", "alumno1")

print("Intentando eliminar una reserva sin ser administrador (es_admin=False)...")
print()

try:
    eliminar_reserva(1, es_admin=False)
    print("RESULTADO: La reserva se ha eliminado.")
    print("         → el assert NO bloqueó la operación.")
    if not __debug__:
        print("         (python -O desactiva los assert — esto es lo esperado con -O)")
    else:
        print("         Esto NO debería haber pasado en modo normal.")
except AssertionError:
    print("RESULTADO: AssertionError — operación bloqueada por el assert.")
    print("         → parece seguro... pero prueba con  python -O experimento_assert.py")

# Limpia la base de datos temporal
os.unlink(db_temporal)
