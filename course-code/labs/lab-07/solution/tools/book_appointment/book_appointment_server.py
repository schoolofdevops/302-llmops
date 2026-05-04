"""book_appointment_server.py — MCP tool that books a Smile Dental appointment.

Per D-11 in CONTEXT.md: writes to ConfigMap in K8s mode, local JSON in Docker Compose.
This Lab-07 file uses local-JSON only; Lab 08 will add the ConfigMap path via env-var switch.
"""
import datetime, json, os, pathlib
from filelock import FileLock
from mcp.server.fastmcp import FastMCP
from mcp.server.streamable_http import TransportSecuritySettings
from tools.otel_setup import setup_tracing
from guardrails.middleware import GuardrailMiddleware
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor

# Disable DNS rebinding protection: MCP runs in Docker where the Host header
# will be "mcp-book-appointment:8030" (Docker service name).
mcp = FastMCP(
    "book_appointment",
    json_response=True,
    transport_security=TransportSecuritySettings(enable_dns_rebinding_protection=False),
)

# Pitfall 9: register GuardrailMiddleware BEFORE streamable_http_app() (called at module bottom).
mcp.add_middleware(GuardrailMiddleware())

# OTEL: must run BEFORE creating streamable_http_app() so FastAPI instrumentation hooks the right routes.
setup_tracing(service_name=os.environ.get("OTEL_SERVICE_NAME", "mcp-book-appointment"))
HTTPXClientInstrumentor().instrument()

BOOKINGS_FILE = pathlib.Path(os.environ.get("BOOKINGS_FILE", "/data/bookings.json"))
PORT = int(os.environ.get("PORT", "8030"))


def _append_local(booking: dict) -> None:
    BOOKINGS_FILE.parent.mkdir(parents=True, exist_ok=True)
    if not BOOKINGS_FILE.exists():
        BOOKINGS_FILE.write_text("[]")
    # filelock works on Linux + macOS + Windows (W4 cross-platform fix; replaces fcntl.flock)
    lock = FileLock(str(BOOKINGS_FILE) + ".lock")
    with lock:
        with open(BOOKINGS_FILE, "r+") as f:
            data = json.load(f)
            data.append(booking)
            f.seek(0)
            json.dump(data, f, indent=2)
            f.truncate()


def _append_configmap(booking: dict) -> None:
    """K8s mode: patch the bookings ConfigMap in BOOKING_NAMESPACE (D-11)."""
    from kubernetes import client as k8s_client, config as k8s_config
    NAMESPACE = os.environ.get("BOOKING_NAMESPACE", "llm-app")
    CM_NAME   = os.environ.get("BOOKING_CM_NAME", "bookings")
    k8s_config.load_incluster_config()
    v1 = k8s_client.CoreV1Api()
    cm = v1.read_namespaced_config_map(CM_NAME, NAMESPACE)
    data = json.loads(cm.data.get("bookings", "[]"))
    data.append(booking)
    v1.patch_namespaced_config_map(
        CM_NAME, NAMESPACE,
        {"data": {"bookings": json.dumps(data, indent=2)}},
    )


@mcp.tool()
def book_appointment(
    patient_name: str,
    treatment: str,
    urgency: str,
    preferred_date: str = "soonest available",
) -> dict:
    """Book an appointment at Smile Dental Clinic.

    Args:
        patient_name: Full name of the patient.
        treatment: Treatment or procedure name.
        urgency: severe / urgent / routine (from triage).
        preferred_date: Preferred date or "soonest available".

    Returns:
        Booking confirmation with appointment_id (format SD-YYYYMMDDHHMMSS).
    """
    booking = {
        "appointment_id": f"SD-{datetime.datetime.utcnow().strftime('%Y%m%d%H%M%S')}",
        "patient_name": patient_name,
        "treatment": treatment,
        "urgency": urgency,
        "preferred_date": preferred_date,
        "status": "confirmed",
        "created_at": datetime.datetime.utcnow().isoformat(),
    }
    backend = os.environ.get("BOOKING_BACKEND", "local")
    if backend == "configmap":
        _append_configmap(booking)
        booking["storage"] = "configmap"
    else:
        _append_local(booking)
        booking["storage"] = "local-file"
    return booking


@mcp.custom_route("/health", methods=["GET"])
async def health(_request):
    from starlette.responses import JSONResponse
    return JSONResponse({"ok": True, "tool": "book_appointment"})


if __name__ == "__main__":
    import uvicorn
    _app = mcp.streamable_http_app()
    FastAPIInstrumentor.instrument_app(_app)
    uvicorn.run(_app, host="0.0.0.0", port=PORT)
