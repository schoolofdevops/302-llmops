"""book_appointment_server.py — MCP tool that books a Smile Dental appointment.

Per D-11 in CONTEXT.md: writes to ConfigMap in K8s mode, local JSON in Docker Compose.
This Lab-07 file uses local-JSON only; Lab 08 will add the ConfigMap path via env-var switch.
"""
import datetime, json, os, pathlib
from filelock import FileLock
from mcp.server.fastmcp import FastMCP
from mcp.server.streamable_http import TransportSecuritySettings

# Disable DNS rebinding protection: MCP runs in Docker where the Host header
# will be "mcp-book-appointment:8030" (Docker service name).
mcp = FastMCP(
    "book_appointment",
    json_response=True,
    transport_security=TransportSecuritySettings(enable_dns_rebinding_protection=False),
)

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
    _append_local(booking)
    booking["storage"] = "local-file"
    return booking


@mcp.custom_route("/health", methods=["GET"])
async def health(_request):
    from starlette.responses import JSONResponse
    return JSONResponse({"ok": True, "tool": "book_appointment"})


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(mcp.streamable_http_app(), host="0.0.0.0", port=PORT)
