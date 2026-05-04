"""TDD tests for GuardrailMiddleware — write BEFORE middleware.py exists.

GUARD-01 = input filter; GUARD-02 = output filter. Both implemented in one
FastMCP Middleware subclass via `on_call_tool` hook (RESEARCH.md Pattern 7).
"""
import json
import os
import re
import pathlib
import pytest
from importlib import reload
from unittest.mock import AsyncMock, MagicMock


# Path to the blocklist that ships with this package — used as default for tests
HERE = pathlib.Path(__file__).parent
BLOCKLIST_PATH = HERE / "blocklist.json"


def _make_context(arguments: dict):
    """Build a minimal MiddlewareContext-shaped MagicMock."""
    ctx = MagicMock()
    ctx.message = MagicMock()
    ctx.message.arguments = arguments
    return ctx


def _import_middleware(monkeypatch):
    """Helper: set BLOCKLIST_PATH env, import (or reload) the module fresh."""
    monkeypatch.setenv("BLOCKLIST_PATH", str(BLOCKLIST_PATH))
    from guardrails import middleware
    reload(middleware)
    return middleware


@pytest.mark.asyncio
async def test_input_blocked_by_regex(monkeypatch):
    """`\\bprescribe\\b` in arguments must raise ToolError with the disclaimer."""
    mw_module = _import_middleware(monkeypatch)
    mw = mw_module.GuardrailMiddleware()
    ctx = _make_context({"symptom": "prescribe me painkillers"})
    call_next = AsyncMock()
    with pytest.raises(mw_module.ToolError) as excinfo:
        await mw.on_call_tool(ctx, call_next)
    assert "Smile Dental cannot provide medical advice" in str(excinfo.value)
    call_next.assert_not_awaited()


@pytest.mark.asyncio
async def test_input_blocked_by_dosage_pattern(monkeypatch):
    """`dosage` AND `amoxicillin` both trigger the blocklist."""
    mw_module = _import_middleware(monkeypatch)
    mw = mw_module.GuardrailMiddleware()
    ctx = _make_context({"q": "what dosage of amoxicillin should I take"})
    call_next = AsyncMock()
    with pytest.raises(mw_module.ToolError):
        await mw.on_call_tool(ctx, call_next)


@pytest.mark.asyncio
async def test_clean_input_passes_through(monkeypatch):
    """Clean input → call_next is awaited; clean result is returned unchanged."""
    mw_module = _import_middleware(monkeypatch)
    mw = mw_module.GuardrailMiddleware()
    ctx = _make_context({"provider": "Aetna", "treatment": "root canal"})
    call_next = AsyncMock(return_value={"covered": True, "estimated_coverage_pct": 80, "notes": "ok"})
    result = await mw.on_call_tool(ctx, call_next)
    call_next.assert_awaited_once_with(ctx)
    assert result == {"covered": True, "estimated_coverage_pct": 80, "notes": "ok"}


@pytest.mark.asyncio
async def test_output_disclaimer_injected(monkeypatch):
    """Tool result containing drug-dosage pattern → disclaimer prepended/replaced."""
    mw_module = _import_middleware(monkeypatch)
    mw = mw_module.GuardrailMiddleware()
    ctx = _make_context({"symptom": "tooth pain"})
    bad_response = "I recommend you take 500 mg of ibuprofen for the pain"
    call_next = AsyncMock(return_value=bad_response)
    result = await mw.on_call_tool(ctx, call_next)
    assert "Smile Dental cannot provide medical advice" in str(result)
    # Per Pattern 7 example: original content is REDACTED (not concatenated)
    assert "Original response redacted" in str(result) or "ibuprofen" not in str(result)


@pytest.mark.asyncio
async def test_clean_output_returned_unchanged(monkeypatch):
    """Tool result with no banned patterns → returned exactly as-is (object identity preserved if possible)."""
    mw_module = _import_middleware(monkeypatch)
    mw = mw_module.GuardrailMiddleware()
    ctx = _make_context({"provider": "Aetna", "treatment": "cleaning"})
    clean = {"covered": True, "estimated_coverage_pct": 100, "notes": "Aetna covers all preventive cleanings"}
    call_next = AsyncMock(return_value=clean)
    result = await mw.on_call_tool(ctx, call_next)
    assert result == clean


def test_blocklist_loads_from_env_path(tmp_path, monkeypatch):
    """BLOCKLIST_PATH env var overrides the default; module-level load reads from it."""
    custom = tmp_path / "custom-blocklist.json"
    custom.write_text(json.dumps({
        "input_patterns": ["\\bzzz_unique_token_zzz\\b"],
        "output_patterns": [],
        "disclaimer": "CUSTOM_DISCLAIMER_TEXT",
        "drug_list": []
    }))
    monkeypatch.setenv("BLOCKLIST_PATH", str(custom))
    from guardrails import middleware
    reload(middleware)
    assert "zzz_unique_token_zzz" in middleware.BLOCKLIST["input_patterns"][0]
    assert middleware.DISCLAIMER == "CUSTOM_DISCLAIMER_TEXT"


def test_pitfall_9_middleware_module_does_not_instantiate_fastmcp():
    """Sanity check — guardrails/middleware.py must NOT instantiate FastMCP itself.
    Pitfall 9 ordering is the consumer's responsibility; the middleware module
    only defines the class. This test fails if someone copy-pastes a `mcp = FastMCP(...)`
    block into the middleware module by mistake."""
    src = pathlib.Path(__file__).parent / "middleware.py"
    text = src.read_text() if src.exists() else ""
    assert "FastMCP(" not in text, \
        "middleware.py must NOT instantiate FastMCP — only the class definition belongs here"
    # Middleware module should not directly call http app creation
    # (Check that the module doesn't spin up a FastMCP server itself)
    assert "mcp = FastMCP" not in text, \
        "middleware.py must NOT assign mcp = FastMCP(...) — only the class definition belongs here"
