"""TDD tests for insurance_check MCP tool — write BEFORE insurance_check_server.py.

CAP-01 capstone: spec from D-19 — insurance_check(provider, treatment) -> {covered, pct, notes}.
"""
import json
import os
import pathlib
import pytest
from importlib import reload


HERE = pathlib.Path(__file__).parent
COVERAGE_PATH = HERE / "insurance-coverage.json"


def _import_server(monkeypatch):
    """Import insurance_check_server fresh with the bundled coverage JSON."""
    monkeypatch.setenv("COVERAGE_PATH", str(COVERAGE_PATH))
    # Avoid the OTEL collector retry-spam in tests
    monkeypatch.setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "")
    # Avoid blocklist.json open failing in middleware module load
    monkeypatch.setenv("BLOCKLIST_PATH", str(HERE.parent.parent / "guardrails" / "blocklist.json"))
    from tools.insurance_check import insurance_check_server
    reload(insurance_check_server)
    return insurance_check_server


def test_insurance_check_known_provider_known_treatment(monkeypatch):
    srv = _import_server(monkeypatch)
    result = srv._lookup("Aetna", "root canal")
    assert result["covered"] is True
    assert result["estimated_coverage_pct"] == 80
    assert "₹15,000" in result["notes"]


def test_insurance_check_unknown_provider(monkeypatch):
    srv = _import_server(monkeypatch)
    result = srv._lookup("Bogus Insurance", "cleaning")
    assert result["covered"] is False
    assert result["estimated_coverage_pct"] == 0
    assert "not in our supported provider list" in result["notes"]


def test_insurance_check_known_provider_unknown_treatment(monkeypatch):
    srv = _import_server(monkeypatch)
    result = srv._lookup("Aetna", "implant")
    assert result["covered"] is False
    assert result["estimated_coverage_pct"] == 0
    assert "not covered by Aetna" in result["notes"]


def test_insurance_check_case_insensitive(monkeypatch):
    srv = _import_server(monkeypatch)
    r = srv._lookup("AETNA", "Root Canal")
    assert r["covered"] is True
    assert r["estimated_coverage_pct"] == 80


def test_insurance_check_zero_pct_is_still_covered(monkeypatch):
    """MaxBupa cleaning is in the policy structure but pct=0.
    Distinguish 'not in list' (covered=False, custom note) from 'in list with pct=0'.
    Per the Code Examples §insurance_check spec: presence in the dict means covered=True."""
    srv = _import_server(monkeypatch)
    r = srv._lookup("MaxBupa", "cleaning")
    assert r["covered"] is True
    assert r["estimated_coverage_pct"] == 0
    assert "does not cover" in r["notes"].lower()


def test_insurance_check_strips_whitespace(monkeypatch):
    srv = _import_server(monkeypatch)
    r = srv._lookup("  Cigna  ", "  crown  ")
    assert r["covered"] is True
    assert r["estimated_coverage_pct"] == 50
