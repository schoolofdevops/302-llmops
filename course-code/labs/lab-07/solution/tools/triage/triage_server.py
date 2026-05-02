"""triage_server.py — MCP tool that classifies dental symptom severity using an LLM.

Runs as a FastMCP Streamable HTTP server on port 8010.
Per D-09 in CONTEXT.md: this tool prompts the LLM with a triage rubric.
"""
import json, os
import httpx
from mcp.server.fastmcp import FastMCP
from mcp.server.streamable_http import TransportSecuritySettings

# Disable DNS rebinding protection: MCP runs in Docker where the Host header
# will be "mcp-triage:8010" (Docker service name) which differs from 127.0.0.1.
# FastMCP defaults to localhost-only protection; override here for container mode.
mcp = FastMCP(
    "triage",
    json_response=True,
    transport_security=TransportSecuritySettings(enable_dns_rebinding_protection=False),
)

LLM_BASE_URL = os.environ.get("LLM_BASE_URL", "https://api.groq.com/openai/v1")
LLM_API_KEY  = os.environ.get("LLM_API_KEY", "")
LLM_MODEL    = os.environ.get("LLM_MODEL", "llama-3.3-70b-versatile")
PORT         = int(os.environ.get("PORT", "8010"))

TRIAGE_PROMPT = """You are a dental triage assistant.
Classify the symptom severity as one of: severe, urgent, routine.
Respond ONLY with a JSON object: {{"severity": "severe"|"urgent"|"routine", "reason": "<one short sentence>"}}
Symptom: {symptom}"""

# 512 tokens allows room for thinking models (gemini-2.5-flash uses internal
# reasoning tokens before output; 100 was too small and returned truncated JSON).
_MAX_TOKENS = int(os.environ.get("LLM_MAX_TOKENS", "512"))


def _extract_json(text: str) -> dict:
    """Parse JSON from LLM response, stripping markdown code fences if present.

    Gemini and some other models wrap JSON in ```json...``` blocks even when
    instructed not to. Strip fences before parsing.
    """
    stripped = text.strip()
    # Remove leading ```json or ``` fence
    if stripped.startswith("```"):
        stripped = stripped.split("\n", 1)[-1]
    # Remove trailing ``` fence
    if stripped.endswith("```"):
        stripped = stripped.rsplit("```", 1)[0]
    return json.loads(stripped.strip())


@mcp.tool()
async def triage(symptom: str) -> dict:
    """Classify a dental symptom severity (severe/urgent/routine).

    Args:
        symptom: Patient's symptom description in natural language.
    """
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(
            f"{LLM_BASE_URL}/chat/completions",
            headers={"Authorization": f"Bearer {LLM_API_KEY}"},
            json={
                "model": LLM_MODEL,
                "messages": [{"role": "user", "content": TRIAGE_PROMPT.format(symptom=symptom)}],
                "max_tokens": _MAX_TOKENS,
                "temperature": 0.1,
            },
        )
        resp.raise_for_status()
        text = resp.json()["choices"][0]["message"]["content"]
    return _extract_json(text)


@mcp.custom_route("/health", methods=["GET"])
async def health(_request):
    from starlette.responses import JSONResponse
    return JSONResponse({"ok": True, "tool": "triage"})


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(mcp.streamable_http_app(), host="0.0.0.0", port=PORT)
