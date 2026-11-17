# PPS-2026-11-10-bandit-LAB

Aplicación de gestión de reservas del aula de informática.
Tiene fallos de seguridad intencionados para la práctica de Bandit.

## Puesta en marcha

```
python3 -m venv .venv
. .venv/bin/activate
pip install pytest "bandit[toml]"
python -m pytest
# → 8 passed
bandit --version
```

## Estructura

```
reservas/
    base_datos.py    — SQLite: buscar, insertar, eliminar reservas
    autenticacion.py — Hash de contraseñas, sesiones, comprobación de admin
    utilidades.py    — Ping de equipos, generación de tokens
    informes.py      — Lectura de informes de ocupación
tests/
    test_reservas.py — 8 tests que describen el comportamiento correcto
informes/            — Ficheros de texto con informes de ocupación
experimento_assert.py — Demuestra el efecto de python -O sobre assert
informe.md           — Plantilla para tu análisis y correcciones
pyproject.toml       — Configuración del proyecto (añade [tool.bandit] en el apt. 9)
```

El código de producción tiene fallos. Las contraseñas son inventadas.
No despliegues esta aplicación en ningún servidor.
