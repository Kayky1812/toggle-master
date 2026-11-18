import os
from unittest.mock import patch, MagicMock
import pytest

os.environ["DATABASE_URL"] = "postgres://postgres:postgres@localhost:5432/targeting_db"
os.environ["AUTH_SERVICE_URL"] = "http://localhost:8001"

with patch("psycopg2.pool.SimpleConnectionPool") as mock_pool:
    import app as targeting_app


@pytest.fixture
def client():
    targeting_app.app.config["TESTING"] = True
    with targeting_app.app.test_client() as test_client:
        yield test_client


def test_health_endpoint(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_create_rule_unauthorized(client):
    response = client.post("/rules", json={"flag_name": "test-flag", "rules": {}})
    assert response.status_code == 401


@patch("app.requests.get")
def test_create_rule_missing_fields(mock_get, client):
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_get.return_value = mock_resp

    response = client.post(
        "/rules",
        headers={"Authorization": "Bearer tm_key_123"},
        json={"flag_name": "test-flag"},
    )
    assert response.status_code == 400

