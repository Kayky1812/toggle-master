import os
import json
from unittest.mock import patch, MagicMock
import pytest

os.environ["AWS_REGION"] = "us-east-1"
os.environ["AWS_SQS_URL"] = "https://sqs.us-east-1.amazonaws.com/123456789012/toggle-master-events"
os.environ["AWS_DYNAMODB_TABLE"] = "ToggleMasterAnalytics"

with patch("threading.Thread"):
    import app as analytics_app


@pytest.fixture
def client():
    analytics_app.app.config["TESTING"] = True
    with analytics_app.app.test_client() as test_client:
        yield test_client


def test_health_endpoint(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


@patch("app.dynamodb_client")
@patch("app.sqs_client")
def test_process_message_success(mock_sqs, mock_dynamo):
    msg = {
        "MessageId": "msg-1",
        "ReceiptHandle": "rh-1",
        "Body": json.dumps({
            "user_id": "user-123",
            "flag_name": "enable-new-dashboard",
            "result": True,
            "timestamp": "2026-11-18T12:00:00Z",
        }),
    }
    analytics_app.process_message(msg)
    assert mock_dynamo.put_item.called
    assert mock_sqs.delete_message.called

