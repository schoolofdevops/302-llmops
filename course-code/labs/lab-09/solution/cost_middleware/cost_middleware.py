"""cost_middleware.py — FastAPI proxy that intercepts /v1/chat/completions
and emits Prometheus token + cost Counter metrics from a price-table ConfigMap.

Place between Chainlit and the Sandbox Router so all agent traffic is measured.
"""
import json, os
from typing import Any
import httpx
from fastapi import FastAPI, Request, Response
from prometheus_client import Counter, CollectorRegistry, generate_latest, CONTENT_TYPE_LATEST

UPSTREAM_URL    = os.environ.get("UPSTREAM_URL", "http://sandbox-router-svc.llm-agent.svc.cluster.local:8080")
HERMES_API_KEY  = os.environ.get("HERMES_API_KEY", "smile-dental-course-key")
PRICE_PATH      = os.environ.get("PRICE_TABLE_PATH", "/etc/llm-prices/prices.json")

with open(PRICE_PATH, "r") as _f:
    PRICES: dict[str, dict[str, float]] = json.load(_f)

# Isolated registry — each module reload (e.g. in tests) gets fresh counters.
# In production only one reload happens at startup.
_registry = CollectorRegistry()

tokens_total = Counter(
    "agent_llm_tokens_total", "Total LLM tokens consumed by the agent",
    ["provider", "model", "direction"],
    registry=_registry,
)
cost_usd_total = Counter(
    "agent_llm_cost_usd_total", "Total LLM API cost in USD",
    ["provider", "model"],
    registry=_registry,
)


def compute_cost_usd(model: str, prompt_tokens: int, completion_tokens: int) -> float:
    """Look up model pricing and compute USD cost. Unknown models cost 0.0."""
    p = PRICES.get(model)
    if not p:
        return 0.0
    return (prompt_tokens / 1_000_000.0) * p["input_usd_per_1m"] + \
           (completion_tokens / 1_000_000.0) * p["output_usd_per_1m"]


def _provider_of(model: str) -> str:
    return model.split("/", 1)[0] if "/" in model else "unknown"


app = FastAPI(title="Smile Dental Cost Middleware")


@app.get("/health")
async def health():
    return {"ok": True}


@app.get("/metrics")
async def metrics():
    return Response(content=generate_latest(_registry), media_type=CONTENT_TYPE_LATEST)


@app.post("/v1/chat/completions")
async def proxy_chat(request: Request):
    body: Any = await request.json()
    headers = {
        "Authorization": f"Bearer {HERMES_API_KEY}",
        "Content-Type": "application/json",
    }
    async with httpx.AsyncClient(timeout=180) as client:
        upstream = await client.post(f"{UPSTREAM_URL}/v1/chat/completions", json=body, headers=headers)

    if upstream.status_code == 200:
        try:
            data = upstream.json()
            model = data.get("model") or body.get("model", "unknown")
            usage = data.get("usage") or {}
            in_t  = int(usage.get("prompt_tokens", 0))
            out_t = int(usage.get("completion_tokens", 0))
            provider = _provider_of(model)
            tokens_total.labels(provider=provider, model=model, direction="input").inc(in_t)
            tokens_total.labels(provider=provider, model=model, direction="output").inc(out_t)
            cost_usd_total.labels(provider=provider, model=model).inc(compute_cost_usd(model, in_t, out_t))
        except Exception:
            pass  # never break the response path
    return Response(content=upstream.content, status_code=upstream.status_code,
                    media_type=upstream.headers.get("content-type", "application/json"))
