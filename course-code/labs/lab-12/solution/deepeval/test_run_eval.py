"""TDD tests for run_eval.py — write BEFORE implementation."""
import json
import time
import sys
import os
from unittest.mock import patch, MagicMock

EVAL_FIXTURE = """\
{"question":"How much does a root canal cost?","expected_answer":"4500-6500","ground_truth_context":["root canal: 4500-6500"]}
{"question":"What are Sunday hours?","expected_answer":"10 AM to 4 PM","ground_truth_context":["Sunday 10 AM-4 PM emergencies only"]}
"""


def _stub_metric(score: float):
    m = MagicMock()
    m.measure = MagicMock(return_value=None)
    m.score = score
    m.success = score >= 0.7
    return m


def _stub_metric_class(score: float):
    """Return a class (callable) that always returns the stub metric instance."""
    stub = _stub_metric(score)

    class StubFaithfulnessMetric:
        def __new__(cls, *args, **kwargs):
            return stub

    return StubFaithfulnessMetric


def test_run_eval_pass_writes_true(tmp_path, monkeypatch):
    eval_file = tmp_path / "eval.jsonl"
    eval_file.write_text(EVAL_FIXTURE)
    out_file = tmp_path / "eval-pass.txt"
    monkeypatch.setenv("LLM_BASE_URL", "https://api.groq.com/openai/v1")
    monkeypatch.setenv("GROQ_API_KEY", "gsk_test")
    # Import fresh, then patch the module attribute after import
    import importlib
    import deepeval_local.run_eval as run_eval_mod
    importlib.reload(run_eval_mod)
    orig = run_eval_mod.FaithfulnessMetric
    try:
        run_eval_mod.FaithfulnessMetric = _stub_metric_class(0.9)
        run_eval_mod.run(
            eval_path=str(eval_file),
            out_path=str(out_file),
            threshold=0.7,
            sleep_seconds=0.0,
            vllm_url="http://stub",
            vllm_model="stub",
        )
    finally:
        run_eval_mod.FaithfulnessMetric = orig
    assert out_file.read_text().strip() == "true"


def test_run_eval_fail_writes_false(tmp_path, monkeypatch):
    eval_file = tmp_path / "eval.jsonl"
    eval_file.write_text(EVAL_FIXTURE)
    out_file = tmp_path / "eval-pass.txt"
    monkeypatch.setenv("LLM_BASE_URL", "https://api.groq.com/openai/v1")
    monkeypatch.setenv("GROQ_API_KEY", "gsk_test")
    import importlib
    import deepeval_local.run_eval as run_eval_mod
    importlib.reload(run_eval_mod)
    orig = run_eval_mod.FaithfulnessMetric
    try:
        run_eval_mod.FaithfulnessMetric = _stub_metric_class(0.5)
        run_eval_mod.run(
            eval_path=str(eval_file),
            out_path=str(out_file),
            threshold=0.7,
            sleep_seconds=0.0,
            vllm_url="http://stub",
            vllm_model="stub",
        )
    finally:
        run_eval_mod.FaithfulnessMetric = orig
    assert out_file.read_text().strip() == "false"


def test_run_eval_sequential_with_sleep(tmp_path, monkeypatch):
    # 3 items x 1s sleep between = >= 2s total elapsed
    eval_file = tmp_path / "eval.jsonl"
    eval_file.write_text(
        EVAL_FIXTURE
        + '{"question":"q3","expected_answer":"a3","ground_truth_context":["c3"]}\n'
    )
    out_file = tmp_path / "eval-pass.txt"
    monkeypatch.setenv("LLM_BASE_URL", "https://api.groq.com/openai/v1")
    monkeypatch.setenv("GROQ_API_KEY", "gsk_test")
    import importlib
    import deepeval_local.run_eval as run_eval_mod
    importlib.reload(run_eval_mod)
    orig = run_eval_mod.FaithfulnessMetric
    try:
        run_eval_mod.FaithfulnessMetric = _stub_metric_class(0.9)
        t0 = time.monotonic()
        run_eval_mod.run(
            eval_path=str(eval_file),
            out_path=str(out_file),
            threshold=0.7,
            sleep_seconds=1.0,
            vllm_url="http://stub",
            vllm_model="stub",
        )
        elapsed = time.monotonic() - t0
    finally:
        run_eval_mod.FaithfulnessMetric = orig
    assert elapsed >= 2.0, f"expected >=2s elapsed (3 items + 2 sleeps), got {elapsed:.2f}"


def test_run_eval_handles_jsonl_format(tmp_path, monkeypatch):
    # JSONL = one JSON per line. NOT a JSON array.
    eval_file = tmp_path / "eval.jsonl"
    eval_file.write_text(EVAL_FIXTURE)
    out_file = tmp_path / "eval-pass.txt"
    monkeypatch.setenv("LLM_BASE_URL", "https://api.groq.com/openai/v1")
    monkeypatch.setenv("GROQ_API_KEY", "gsk_test")
    import importlib
    import deepeval_local.run_eval as run_eval_mod
    importlib.reload(run_eval_mod)
    orig = run_eval_mod.FaithfulnessMetric
    try:
        run_eval_mod.FaithfulnessMetric = _stub_metric_class(0.9)
        run_eval_mod.run(
            eval_path=str(eval_file),
            out_path=str(out_file),
            threshold=0.7,
            sleep_seconds=0.0,
            vllm_url="http://stub",
            vllm_model="stub",
        )
    finally:
        run_eval_mod.FaithfulnessMetric = orig
    # No JSONDecodeError = parse worked
    assert out_file.exists()
