import pytest

from lifepilot import db


@pytest.fixture
def conn():
    """An in-memory database with the schema applied."""
    connection = db.connect(":memory:")
    yield connection
    connection.close()
