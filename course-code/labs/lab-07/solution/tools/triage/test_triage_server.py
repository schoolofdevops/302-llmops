"""TDD tests for triage MCP tool. Run BEFORE writing triage_server.py."""
import json
import pytest
from unittest.mock import patch, AsyncMock

# Tests assume triage_server exposes an async `triage(symptom: str) -> dict`
# that POSTs to LLM_BASE_URL/chat/completions and returns parsed JSON.

@pytest.mark.asyncio
async def test_triage_returns_severity_dict():
    from tools.triage import triage_server
    fake_resp = AsyncMock()
    fake_resp.raise_for_status = lambda: None
    fake_resp.json = lambda: {
        "choices": [{"message": {"content": '{"severity":"severe","reason":"swelling"}'}}]
    }
    with patch("tools.triage.triage_server.httpx.AsyncClient") as mock_cli:
        mock_cli.return_value.__aenter__.return_value.post = AsyncMock(return_value=fake_resp)
        result = await triage_server.triage("severe tooth pain")
    assert result["severity"] in {"severe", "urgent", "routine"}
    assert "reason" in result

@pytest.mark.asyncio
async def test_triage_handles_invalid_llm_json():
    from tools.triage import triage_server
    fake_resp = AsyncMock()
    fake_resp.raise_for_status = lambda: None
    fake_resp.json = lambda: {"choices": [{"message": {"content": "not json"}}]}
    with patch("tools.triage.triage_server.httpx.AsyncClient") as mock_cli:
        mock_cli.return_value.__aenter__.return_value.post = AsyncMock(return_value=fake_resp)
        with pytest.raises(json.JSONDecodeError):
            await triage_server.triage("anything")
