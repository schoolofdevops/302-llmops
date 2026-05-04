"""guardrails/middleware.py — FastMCP Middleware for input + output guardrails.

GUARD-01: input filter — regex/keyword block-list (D-16) + optional LLM scope-check.
GUARD-02: output filter — pattern check + canonical disclaimer injection (D-17).

Pattern source: RESEARCH.md §"Pattern 7: FastMCP middleware for guardrails".

Pitfall 9 reminder: this module ONLY defines the class. Consumers must pass
`middleware=[GuardrailMiddleware()]` to the FastMCP constructor, or call
`mcp.add_middleware(GuardrailMiddleware())` before the HTTP app is built.
"""
import json
import os
import re
from typing import Any

from fastmcp.server.middleware import Middleware, MiddlewareContext
from fastmcp.exceptions import ToolError


# Load the blocklist at module import — single read, in-memory match (fast).
# BLOCKLIST_PATH is overridable for tests; production value comes from a
# Kubernetes ConfigMap mounted at /etc/guardrails/blocklist.json.
_BLOCKLIST_PATH = os.environ.get("BLOCKLIST_PATH", "/etc/guardrails/blocklist.json")
with open(_BLOCKLIST_PATH) as _f:
    BLOCKLIST: dict = json.load(_f)

# Compile regexes once. re.IGNORECASE for human-typed input variation.
INPUT_REGEX = re.compile("|".join(BLOCKLIST["input_patterns"]), re.IGNORECASE) if BLOCKLIST["input_patterns"] else None
OUTPUT_REGEX = re.compile("|".join(BLOCKLIST["output_patterns"]), re.IGNORECASE) if BLOCKLIST["output_patterns"] else None
DISCLAIMER: str = BLOCKLIST.get("disclaimer",
    "Smile Dental cannot provide medical advice. "
    "For health concerns beyond dental care, please consult your physician.")


class GuardrailMiddleware(Middleware):
    """Two-layer guardrail wrapping each MCP @mcp.tool() invocation.

    Input layer: regex blocklist (fast, deterministic) + optional LLM scope-check
                 (D-16, gated by GUARDRAIL_LLM_CHECK=true env to save Groq quota).
    Output layer: regex blocklist match → replace tool result with disclaimer.

    Failure mode: ToolError raises a clean error visible to the agent runtime;
    Hermes / Chainlit display the disclaimer text to the user.
    """

    async def on_call_tool(self, context: MiddlewareContext, call_next):
        # --- INPUT GUARDRAIL ---
        args_blob = json.dumps(context.message.arguments, ensure_ascii=False)
        if INPUT_REGEX and INPUT_REGEX.search(args_blob):
            raise ToolError(DISCLAIMER)

        # Optional LLM scope-check — only if explicitly enabled (saves quota).
        # Per D-16: small classifier call to decide if the query is in-scope.
        if os.environ.get("GUARDRAIL_LLM_CHECK", "false").lower() == "true":
            scope_ok = await self._llm_scope_check(args_blob)
            if not scope_ok:
                raise ToolError(DISCLAIMER)

        # --- TOOL EXECUTION ---
        result = await call_next(context)

        # --- OUTPUT GUARDRAIL ---
        result_text = str(result)
        if OUTPUT_REGEX and OUTPUT_REGEX.search(result_text):
            return f"{DISCLAIMER}\n\n[Original response redacted: contained out-of-scope medical advice.]"
        return result

    async def _llm_scope_check(self, query: str) -> bool:
        """Single tiny LLM call — yes/no scope classifier. D-16 Layer 2.

        Off by default to save free-tier quota; enable with GUARDRAIL_LLM_CHECK=true.
        Uses the same LLM_BASE_URL/LLM_API_KEY/LLM_MODEL env vars as the rest of
        the agent (Groq llama-3.3-70b-versatile or Gemini 2.5 Flash).
        """
        import httpx
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                r = await c.post(
                    f"{os.environ['LLM_BASE_URL']}/chat/completions",
                    headers={"Authorization": f"Bearer {os.environ['LLM_API_KEY']}"},
                    json={
                        "model": os.environ.get("LLM_MODEL", "llama-3.3-70b-versatile"),
                        "messages": [{
                            "role": "user",
                            "content": (
                                "Is this a question about a dental clinic (dental treatments, "
                                "appointments, hours, dental insurance coverage)? "
                                "Answer ONLY 'yes' or 'no'. "
                                f"Query: {query}"
                            ),
                        }],
                        "max_tokens": 8,
                        "temperature": 0,
                    },
                )
                content = r.json()["choices"][0]["message"]["content"].strip().lower()
            return "yes" in content
        except Exception:
            # Fail-open on LLM check failure: regex layer already passed; better UX
            # than blocking every query when free-tier quota is exhausted.
            return True
