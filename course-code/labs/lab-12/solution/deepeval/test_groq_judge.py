"""TDD tests for groq_judge.py — write BEFORE implementation."""
import os
from unittest.mock import MagicMock


def test_groq_judge_init_reads_env_vars(monkeypatch):
    monkeypatch.setenv("LLM_BASE_URL", "https://api.groq.com/openai/v1")
    monkeypatch.setenv("GROQ_API_KEY", "gsk_test")
    monkeypatch.delenv("LLM_MODEL", raising=False)  # default branch
    from importlib import reload
    from deepeval_local import groq_judge
    reload(groq_judge)
    j = groq_judge.GroqJudge()
    assert j.model_name == "llama-3.3-70b-versatile"  # default


def test_groq_judge_generate_returns_content(monkeypatch):
    monkeypatch.setenv("LLM_BASE_URL", "https://api.groq.com/openai/v1")
    monkeypatch.setenv("GROQ_API_KEY", "gsk_test")
    monkeypatch.setenv("LLM_MODEL", "llama-3.3-70b-versatile")
    from importlib import reload
    from deepeval_local import groq_judge
    reload(groq_judge)
    j = groq_judge.GroqJudge()
    fake_msg = MagicMock()
    fake_msg.content = "Yes, root canal at Smile Dental."
    fake_resp = MagicMock()
    fake_resp.choices = [MagicMock(message=fake_msg)]
    j.client.chat.completions.create = MagicMock(return_value=fake_resp)
    out = j.generate("Does Smile Dental do root canals?")
    assert out == "Yes, root canal at Smile Dental."


def test_groq_judge_generate_uses_temperature_0_1(monkeypatch):
    monkeypatch.setenv("LLM_BASE_URL", "https://api.groq.com/openai/v1")
    monkeypatch.setenv("GROQ_API_KEY", "gsk_test")
    monkeypatch.setenv("LLM_MODEL", "llama-3.3-70b-versatile")
    from importlib import reload
    from deepeval_local import groq_judge
    reload(groq_judge)
    j = groq_judge.GroqJudge()
    fake_msg = MagicMock()
    fake_msg.content = "ok"
    fake_resp = MagicMock()
    fake_resp.choices = [MagicMock(message=fake_msg)]
    j.client.chat.completions.create = MagicMock(return_value=fake_resp)
    j.generate("anything")
    kwargs = j.client.chat.completions.create.call_args.kwargs
    assert kwargs["temperature"] == 0.1


def test_groq_judge_get_model_name(monkeypatch):
    monkeypatch.setenv("LLM_BASE_URL", "https://api.groq.com/openai/v1")
    monkeypatch.setenv("GROQ_API_KEY", "gsk_test")
    monkeypatch.setenv("LLM_MODEL", "llama-3.3-70b-versatile")
    from importlib import reload
    from deepeval_local import groq_judge
    reload(groq_judge)
    assert groq_judge.GroqJudge().get_model_name() == "llama-3.3-70b-versatile"
