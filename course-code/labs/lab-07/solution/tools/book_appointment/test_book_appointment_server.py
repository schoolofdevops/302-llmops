"""TDD tests for book_appointment MCP tool (local JSON file fallback for Lab 07)."""
import json, os, re, tempfile
import pytest

def test_book_appointment_returns_confirmation(monkeypatch, tmp_path):
    monkeypatch.setenv("BOOKINGS_FILE", str(tmp_path / "bookings.json"))
    from importlib import reload
    from tools.book_appointment import book_appointment_server
    reload(book_appointment_server)
    result = book_appointment_server.book_appointment(
        patient_name="Aanya Sharma",
        treatment="root canal",
        urgency="severe",
        preferred_date="tomorrow",
    )
    assert re.match(r"^SD-\d{14}$", result["appointment_id"])
    assert result["status"] == "confirmed"
    assert result["patient_name"] == "Aanya Sharma"
    assert result["treatment"] == "root canal"
    assert result["urgency"] == "severe"

def test_book_appointment_writes_to_local_file(monkeypatch, tmp_path):
    bf = tmp_path / "bookings.json"
    monkeypatch.setenv("BOOKINGS_FILE", str(bf))
    from importlib import reload
    from tools.book_appointment import book_appointment_server
    reload(book_appointment_server)
    book_appointment_server.book_appointment("A", "cleaning", "routine", "next week")
    data = json.loads(bf.read_text())
    assert len(data) == 1
    assert data[0]["patient_name"] == "A"
