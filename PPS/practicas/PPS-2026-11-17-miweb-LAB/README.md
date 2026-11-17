# PPS-2026-11-17-miweb-LAB

Aplicación de reservas del aula de informática (base para la práctica PPS-11).

## Puesta en marcha

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
```

## Ejecutar los tests

```bash
python -m pytest
```

Al principio verás que **6 tests fallan** (en `test_secretos.py`).
Tu tarea es hacer que pasen los 17 en total.

## Estructura

```
miweb/
    __init__.py   — Rutas Flask y lógica principal
    bd.py         — Base de datos SQLite
    config.py     — Configuración (aquí están los secretos que debes mover)
    registro.py   — Registro de seguridad en formato JSON
    templates/    — Plantillas HTML
    static/       — CSS
despliegue/
    miweb.env.ejemplo   — Plantilla para tu fichero .env
    miweb.service       — Servicio systemd
    nginx-miweb.conf    — Configuración nginx
    instalar-servicio.sh
    red-solo-anfitrion.sh
tests/
    conftest.py
    test_funciona.py    — 9 tests que deben pasar siempre
    test_secretos.py    — 8 tests que fallan al principio (tu tarea: hacerlos pasar)
wsgi.py           — Punto de entrada para gunicorn
```

Los secretos están en el código. Busca los `TODO` para saber qué cambiar.
