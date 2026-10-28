# Proyecto de prácticas: reservas del aula

Proyecto para la práctica de Bandit del 10 de noviembre. Es una aplicación pequeña de
reservas del aula de informática con varios problemas de seguridad a propósito.
Los datos y las contraseñas son inventados. No lo despliegues en ningún servidor.

    python3 -m venv .venv
    . .venv/bin/activate
    pip install pytest "bandit[toml]"
    python -m pytest
    bandit -r reservas
