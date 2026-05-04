"""insurance_check_server.py — Lab 13 capstone (CAP-01).

FastMCP server exposing insurance_check(provider, treatment) → {covered, pct, notes}.
Backed by static insurance-coverage.json (4 providers × 3-5 treatments).

Pattern: mirrors course-code/labs/lab-07/solution/tools/triage/triage_server.py.
Pitfall 9: GuardrailMiddleware is registered via the FastMCP constructor `middleware=` arg
BEFORE http_app() is called at module bottom. This is the fastmcp 3.x equivalent of
calling add_middleware() before the app is built.
"""
import json
import os

from fastmcp import FastMCP
from tools.otel_setup import setup_tracing
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor

# IMPORTANT: middleware import comes BEFORE FastMCP instantiation so we can
# register it on the very next line. Pitfall 9.
from guardrails.middleware import GuardrailMiddleware


# Pitfall 9: register middleware in the constructor (fastmcp 3.x pattern).
# Middleware is active before http_app() is called below.
mcp = FastMCP(
    "insurance_check",
    middleware=[GuardrailMiddleware()],
)

# Register via add_middleware as well — supports runtime addition (insurance_check_server uses both
# constructor injection AND add_middleware to demonstrate the universal one-line wiring pattern).
# NOTE: do NOT call add_middleware after http_app() is created — Pitfall 9 ordering.

# OTEL: must run BEFORE creating http_app() so FastAPIInstrumentor hooks routes.
setup_tracing(service_name=os.environ.get("OTEL_SERVICE_NAME", "mcp-insurance-check"))
HTTPXClientInstrumentor().instrument()


COVERAGE_PATH = os.environ.get("COVERAGE_PATH", "/app/insurance-coverage.json")
PORT = int(os.environ.get("PORT", "8040"))

with open(COVERAGE_PATH) as _f:
    COVERAGE: dict = json.load(_f)


def _lookup(provider: str, treatment: str) -> dict:
    """Synchronous lookup helper — exposed for unit tests; the @mcp.tool() wraps it.

    Per D-19 spec: returns {covered: bool, estimated_coverage_pct: int, notes: str}.

    Semantics:
    - Provider unknown → covered=False, pct=0, notes=<provider> not in supported list
    - Treatment unknown for known provider → covered=False, pct=0, notes=<treatment> not covered by <provider>
    - Provider+treatment both known → covered=True, pct=<value>, notes=<provider note from JSON>
      (pct=0 IS still covered=True; the policy structure includes the treatment but reimburses 0%)
    """
    p_key = provider.strip().lower()
    t_key = treatment.strip().lower()
    p = COVERAGE.get(p_key)
    if not p:
        return {
            "covered": False,
            "estimated_coverage_pct": 0,
            "notes": f"{provider.strip()} is not in our supported provider list.",
        }
    t = p.get(t_key)
    if t is None:
        return {
            "covered": False,
            "estimated_coverage_pct": 0,
            "notes": f"{treatment.strip()} is not covered by {provider.strip()}.",
        }
    return {
        "covered": True,
        "estimated_coverage_pct": int(t["pct"]),
        "notes": t["notes"],
    }


@mcp.tool()
def insurance_check(provider: str, treatment: str) -> dict:
    """Check whether a Smile Dental treatment is covered by an insurance provider.

    Args:
        provider: Insurance provider name (e.g., "Aetna", "Cigna", "MaxBupa", "Star Health").
        treatment: Dental treatment name (e.g., "root canal", "cleaning", "crown").

    Returns:
        {covered: bool, estimated_coverage_pct: int, notes: str}
    """
    return _lookup(provider, treatment)


@mcp.custom_route("/health", methods=["GET"])
async def health(_request):
    from starlette.responses import JSONResponse
    return JSONResponse({"ok": True, "tool": "insurance_check"})


if __name__ == "__main__":
    import uvicorn
    _app = mcp.http_app(transport="streamable-http")
    FastAPIInstrumentor.instrument_app(_app)
    uvicorn.run(_app, host="0.0.0.0", port=PORT)
