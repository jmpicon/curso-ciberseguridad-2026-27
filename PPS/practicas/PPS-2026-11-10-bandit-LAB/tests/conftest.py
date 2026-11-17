"""Fixtures compartidas para los tests del laboratorio."""

import pytest
import reservas.base_datos as bd


@pytest.fixture(autouse=True)
def db_temporal(tmp_path, monkeypatch):
    """Cada test usa una base de datos temporal nueva y vacía."""
    ruta = str(tmp_path / "test.db")
    monkeypatch.setattr(bd, "DB_PATH", ruta)
    bd.inicializar_db()
    yield
