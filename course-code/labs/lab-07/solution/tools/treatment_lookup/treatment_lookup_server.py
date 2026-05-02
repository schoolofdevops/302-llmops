"""treatment_lookup_server.py — MCP tool that wraps the Day-1 RAG retriever.

Per D-10 in CONTEXT.md: calls existing rag-retriever /search endpoint.
"""
import os
import httpx
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("treatment_lookup", json_response=True)

RETRIEVER_URL = os.environ.get(
    "RETRIEVER_URL",
    "http://rag-retriever.llm-app.svc.cluster.local:8001",
)
PORT = int(os.environ.get("PORT", "8020"))


@mcp.tool()
async def treatment_lookup(treatment_name: str, k: int = 3) -> list[dict]:
    """Look up Smile Dental treatment information from the clinic knowledge base.

    Args:
        treatment_name: Treatment name or description.
        k: Number of relevant chunks to retrieve (default 3).
    """
    async with httpx.AsyncClient(timeout=15) as client:
        resp = await client.post(
            f"{RETRIEVER_URL}/search",
            json={"query": treatment_name, "k": k},
        )
        resp.raise_for_status()
    return resp.json().get("hits", [])


@mcp.custom_route("/health", methods=["GET"])
async def health(_request):
    from starlette.responses import JSONResponse
    return JSONResponse({"ok": True, "tool": "treatment_lookup"})


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(mcp.streamable_http_app(), host="0.0.0.0", port=PORT)
