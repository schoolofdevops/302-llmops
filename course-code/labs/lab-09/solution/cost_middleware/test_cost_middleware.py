"""Cost middleware TDD tests — RUN BEFORE writing cost_middleware.py."""
import json, os
import pytest
from unittest.mock import patch, AsyncMock
from fastapi.testclient import TestClient


PRICES = {
    "groq/llama-3.3-70b-versatile": {"input_usd_per_1m": 0.59, "output_usd_per_1m": 0.79},
    "google/gemini-2.5-flash":      {"input_usd_per_1m": 0.30, "output_usd_per_1m": 2.50},
}


@pytest.fixture
def app(tmp_path, monkeypatch):
    prices_path = tmp_path / "prices.json"
    prices_path.write_text(json.dumps(PRICES))
    monkeypatch.setenv("PRICE_TABLE_PATH", str(prices_path))
    monkeypatch.setenv("UPSTREAM_URL", "http://upstream.invalid")
    monkeypatch.setenv("HERMES_API_KEY", "smile-dental-course-key")
    from importlib import reload
    from cost_middleware import cost_middleware as mw
    reload(mw)
    return mw.app


def test_compute_cost_usd_groq_llama(app):
    from cost_middleware.cost_middleware import compute_cost_usd
    cost = compute_cost_usd("groq/llama-3.3-70b-versatile", prompt_tokens=1_000_000, completion_tokens=1_000_000)
    assert abs(cost - (0.59 + 0.79)) < 1e-9


def test_compute_cost_usd_unknown_model(app):
    from cost_middleware.cost_middleware import compute_cost_usd
    assert compute_cost_usd("unknown/model", 100, 200) == 0.0


def test_proxy_emits_token_counters_on_response(app):
    fake_resp = AsyncMock()
    fake_resp.status_code = 200
    fake_resp.json = lambda: {
        "model": "groq/llama-3.3-70b-versatile",
        "choices": [{"message": {"content": "ok"}}],
        "usage": {"prompt_tokens": 10, "completion_tokens": 20},
    }
    fake_resp.content = json.dumps(fake_resp.json()).encode()
    fake_resp.headers = {"content-type": "application/json"}
    with patch("cost_middleware.cost_middleware.httpx.AsyncClient") as mock_cli:
        mock_cli.return_value.__aenter__.return_value.post = AsyncMock(return_value=fake_resp)
        with TestClient(app) as client:
            r = client.post("/v1/chat/completions", json={"model":"x","messages":[]})
    assert r.status_code == 200
    metrics = TestClient(app).get("/metrics").text
    assert 'agent_llm_tokens_total{direction="input"' in metrics
    assert 'agent_llm_tokens_total{direction="output"' in metrics
    assert 'agent_llm_cost_usd_total{' in metrics


def test_proxy_passes_through_response_body(app):
    body = {"choices":[{"message":{"content":"hello"}}], "usage":{"prompt_tokens":1,"completion_tokens":1}, "model":"groq/llama-3.3-70b-versatile"}
    fake_resp = AsyncMock()
    fake_resp.status_code = 200
    fake_resp.json = lambda: body
    fake_resp.content = json.dumps(body).encode()
    fake_resp.headers = {"content-type": "application/json"}
    with patch("cost_middleware.cost_middleware.httpx.AsyncClient") as mock_cli:
        mock_cli.return_value.__aenter__.return_value.post = AsyncMock(return_value=fake_resp)
        with TestClient(app) as client:
            r = client.post("/v1/chat/completions", json={"model":"x","messages":[]})
    assert r.json() == body
