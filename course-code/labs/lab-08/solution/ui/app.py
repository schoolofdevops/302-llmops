"""app.py — Smile Dental Day-2 Chainlit UI calling Hermes Agent via Sandbox Router.

Differences from Lab-07 (Docker Compose):
  - AGENT_URL default points at sandbox-router-svc.llm-agent.svc.cluster.local:8080
    instead of hermes:8642 directly. The Router routes to per-session Sandbox pods.
  - Welcome banner updated for Day-2 K8s context.
  - Everything else (on_message handler, prom counters, tool-call steps) identical to Lab-07.
"""
import os, time, threading
import chainlit as cl
import httpx
from prometheus_client import Counter, Histogram, start_http_server

chat_requests_total = Counter("chat_requests_total", "Total chat messages processed", ["status"])
chat_latency_seconds = Histogram("chat_latency_seconds", "End-to-end chat response latency")

threading.Thread(target=lambda: start_http_server(9090), daemon=True).start()

AGENT_URL  = os.environ.get(
    "AGENT_URL",
    "http://sandbox-router-svc.llm-agent.svc.cluster.local:8080",
)
HERMES_KEY = os.environ.get("HERMES_API_KEY", "smile-dental-course-key")
SYSTEM_PROMPT = (
    "You are the Smile Dental Clinic assistant. Use the triage, treatment_lookup, "
    "and book_appointment tools in sequence for patient symptom queries."
)


@cl.on_chat_start
async def on_chat_start():
    await cl.Message(
        content=(
            "Welcome to **Smile Dental Clinic** assistant (Day 2 — K8s Agent Sandbox edition).\n\n"
            "Your message goes through the Sandbox Router into a per-session Hermes Sandbox claimed from the WarmPool. "
            "Try _\"severe tooth pain since yesterday\"_ to see triage -> treatment lookup -> appointment booking.\n\n"
            "_Expand the steps under each answer to see which tools the agent called._"
        )
    ).send()


@cl.on_message
async def on_message(message: cl.Message):
    t_start = time.monotonic()
    try:
        async with cl.Step(name="Agent processing", type="run") as agent_step:
            agent_step.input = message.content

            async with httpx.AsyncClient(timeout=120) as client:
                resp = await client.post(
                    f"{AGENT_URL}/v1/chat/completions",
                    headers={"Authorization": f"Bearer {HERMES_KEY}"},
                    json={
                        "model": "hermes",
                        "messages": [
                            {"role": "system", "content": SYSTEM_PROMPT},
                            {"role": "user",   "content": message.content},
                        ],
                        "stream": False,
                    },
                )
                resp.raise_for_status()
                data = resp.json()

            agent_step.output = f"Agent completed in {time.monotonic() - t_start:.2f}s"

            tool_calls = data["choices"][0]["message"].get("tool_calls", []) or []
            for tc in tool_calls:
                tool_name = tc.get("function", {}).get("name", "tool")
                async with cl.Step(name=f"Tool: {tool_name}", type="tool", default_open=False) as tcs:
                    tcs.input = tc.get("function", {}).get("arguments", "{}")
                    tcs.output = "(result is included in the agent's final answer)"

        answer = data["choices"][0]["message"]["content"] or "(empty response)"
        await cl.Message(content=answer).send()
        chat_requests_total.labels(status="ok").inc()
    except Exception as e:
        chat_requests_total.labels(status="error").inc()
        await cl.Message(content=f"Error contacting agent: {type(e).__name__}: {e}").send()
    finally:
        chat_latency_seconds.observe(time.monotonic() - t_start)
