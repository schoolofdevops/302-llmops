"""TDD tests for book_appointment MCP tool (local JSON file fallback for Lab 07)."""
import json, os, re, tempfile
import pytest


def test_book_appointment_configmap_backend_writes_to_configmap(monkeypatch, tmp_path):
    """B2: When BOOKING_BACKEND=configmap, the tool MUST call
    kubernetes.client.CoreV1Api.patch_namespaced_config_map with the new
    booking appended to the existing bookings list. This is the K8s mode path
    that Lab 08 manifests rely on; without TDD here the K8s path was untested."""
    import json as _json
    import sys, types

    monkeypatch.setenv("BOOKING_BACKEND", "configmap")
    monkeypatch.setenv("BOOKING_NAMESPACE", "llm-app")
    monkeypatch.setenv("BOOKING_CM_NAME", "bookings")
    monkeypatch.setenv("BOOKINGS_FILE", str(tmp_path / "bookings.json"))

    # Build a fake `kubernetes` package the SUT can import in-cluster.
    captured = {"read_args": None, "patch_args": None, "patch_body": None}

    class _CM:
        # Pre-populate with an existing booking so we verify APPEND, not REPLACE.
        data = {"bookings": _json.dumps([{"appointment_id": "SD-PRE-EXISTING"}])}

    class _FakeV1:
        def read_namespaced_config_map(self, name, namespace):
            captured["read_args"] = (name, namespace)
            return _CM()
        def patch_namespaced_config_map(self, name, namespace, body):
            captured["patch_args"] = (name, namespace)
            captured["patch_body"] = body

    fake_k8s = types.ModuleType("kubernetes")
    fake_client = types.ModuleType("kubernetes.client")
    fake_config = types.ModuleType("kubernetes.config")
    fake_v1 = _FakeV1()
    fake_client.CoreV1Api = lambda: fake_v1
    fake_config.load_incluster_config = lambda: None
    fake_k8s.client = fake_client
    fake_k8s.config = fake_config
    monkeypatch.setitem(sys.modules, "kubernetes", fake_k8s)
    monkeypatch.setitem(sys.modules, "kubernetes.client", fake_client)
    monkeypatch.setitem(sys.modules, "kubernetes.config", fake_config)

    # SUT
    from importlib import reload
    from tools.book_appointment import book_appointment_server
    reload(book_appointment_server)
    result = book_appointment_server.book_appointment(
        patient_name="Aanya Sharma",
        treatment="root canal",
        urgency="severe",
        preferred_date="tomorrow",
    )

    # Tool returned ConfigMap-mode marker
    assert result["storage"] == "configmap"
    assert result["patient_name"] == "Aanya Sharma"

    # K8s API was called with the right name/namespace
    assert captured["read_args"]  == ("bookings", "llm-app")
    assert captured["patch_args"] == ("bookings", "llm-app")

    # Patch body appended (did not replace) the bookings list
    patched_data = _json.loads(captured["patch_body"]["data"]["bookings"])
    assert len(patched_data) == 2, "Expected APPEND not REPLACE; existing booking missing"
    assert patched_data[0]["appointment_id"] == "SD-PRE-EXISTING"
    assert patched_data[1]["patient_name"]   == "Aanya Sharma"
    assert patched_data[1]["urgency"]        == "severe"

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
