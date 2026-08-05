"""Quick smoke test for the LSTM sentiment API."""

from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_health():
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


def test_predict_positive():
    resp = client.post(
        "/predict-sentiment",
        json={"review_text": "Great service, very professional and on time!"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["sentiment"] == "positive"
    assert body["confidence"] > 0.5


def test_predict_negative():
    resp = client.post(
        "/predict-sentiment",
        json={"review_text": "Terrible experience, rude and never showed up."},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["sentiment"] == "negative"
    assert body["confidence"] > 0.5
