import os
from unittest.mock import patch, MagicMock
import pytest

os.environ["DATABASE_URL"] = "postgres://postgres:postgres@localhost:5432/flags_db"
os.environ["AUTH_SERVICE_URL"] = "http://localhost:8001"

with patch("psycopg2.pool.SimpleConnectionPool") as mock_pool:
    import app as flag_app


@pytest.fixture
def client():
    flag_app.app.config["TESTING"] = True
    with flag_app.app.test_client() as test_client:
        yield test_client


def test_health_endpoint(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_create_flag_unauthorized(client):
    response = client.post("/flags", json={"name": "test-flag"})
    assert response.status_code == 401


@patch("app.requests.get")
def test_create_flag_missing_name(mock_get, client):
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_get.return_value = mock_resp

    response = client.post(
        "/flags",
        headers={"Authorization": "Bearer tm_key_123"},
        json={"description": "sem nome"},
    )
    assert response.status_code == 400

