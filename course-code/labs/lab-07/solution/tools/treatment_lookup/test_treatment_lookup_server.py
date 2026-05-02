"""TDD tests for treatment_lookup MCP tool."""
import pytest
from unittest.mock import patch, AsyncMock

@pytest.mark.asyncio
async def test_treatment_lookup_returns_hits_list():
    from tools.treatment_lookup import treatment_lookup_server
    fake_resp = AsyncMock()
    fake_resp.raise_for_status = lambda: None
    fake_resp.json = lambda: {"hits": [{"doc_id": "d1", "section": "crown", "text": "Zirconia crowns…", "score": 0.91}]}
    with patch("tools.treatment_lookup.treatment_lookup_server.httpx.AsyncClient") as mock_cli:
        mock_cli.return_value.__aenter__.return_value.post = AsyncMock(return_value=fake_resp)
        hits = await treatment_lookup_server.treatment_lookup("crown")
    assert isinstance(hits, list) and len(hits) >= 1
    assert "doc_id" in hits[0] and "section" in hits[0] and "text" in hits[0]

@pytest.mark.asyncio
async def test_treatment_lookup_propagates_k_param():
    from tools.treatment_lookup import treatment_lookup_server
    captured = {}
    async def fake_post(url, json):
        captured["body"] = json
        r = AsyncMock(); r.raise_for_status = lambda: None
        r.json = lambda: {"hits": []}
        return r
    fake_cli = AsyncMock()
    fake_cli.__aenter__.return_value.post = fake_post
    with patch("tools.treatment_lookup.treatment_lookup_server.httpx.AsyncClient", return_value=fake_cli):
        await treatment_lookup_server.treatment_lookup("crown", k=5)
    assert captured["body"]["k"] == 5
    assert captured["body"]["query"] == "crown"
