#!/usr/bin/env python3
"""Resume la salida de wazuh-logtest en una tabla: una fila por línea de registro.

Uso:
    python3 resumen_logtest.py salida-logtest.txt
    python3 resumen_logtest.py salida-logtest.txt --solo-alertas
    python3 resumen_logtest.py salida-logtest.txt --min-nivel 10

Solo usa la biblioteca estándar de Python. Está hecho para la salida de wazuh-logtest
4.14; con otras versiones el formato puede cambiar.
"""

import argparse
import re
import sys

CAMPO = re.compile(r"^\s+(full event|id|level|description): '(.*)'$")


def leer(ruta):
    eventos, actual = [], None
    with open(ruta, encoding="utf-8", errors="replace") as f:
        for linea in f:
            linea = linea.rstrip("\n")
            m = CAMPO.match(linea)
            if m and m.group(1) == "full event":
                actual = {"evento": m.group(2), "id": "-", "level": "0",
                          "description": "(sin regla)", "alerta": False}
                eventos.append(actual)
            elif m and actual is not None:
                actual[m.group(1)] = m.group(2)
            elif "Alert to be generated" in linea and actual is not None:
                actual["alerta"] = True
    return eventos


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("fichero", help="salida guardada de wazuh-logtest")
    p.add_argument("--solo-alertas", action="store_true",
                   help="muestra solo las líneas que generan alerta")
    p.add_argument("--min-nivel", type=int, default=0,
                   help="muestra solo las reglas con este nivel o más")
    a = p.parse_args()

    try:
        eventos = leer(a.fichero)
    except OSError as e:
        sys.exit(f"No puedo leer {a.fichero}: {e}")
    if not eventos:
        sys.exit("No he encontrado ningún 'full event'. ¿Es la salida de wazuh-logtest?")

    print(f"{'#':>3}  {'alerta':6}  {'regla':>6}  {'nivel':>5}  descripción  |  registro")
    for n, e in enumerate(eventos, 1):
        nivel = int(e["level"]) if e["level"].isdigit() else 0
        if a.solo_alertas and not e["alerta"]:
            continue
        if nivel < a.min_nivel:
            continue
        marca = "sí" if e["alerta"] else "no"
        print(f"{n:>3}  {marca:6}  {e['id']:>6}  {nivel:>5}  {e['description']}  |  {e['evento']}")


if __name__ == "__main__":
    main()
