"""app.py — Smile Dental Day-2 Chainlit UI calling Hermes Agent gateway.

Differences from Day-1 (lab-05):
  - Calls Hermes /v1/chat/completions instead of vLLM directly.
  - Removes RAG-retrieval step (Hermes does it via the treatment_lookup MCP tool).
  - Adds dynamic tool-call sub-steps for each tool the agent invokes.
"""
import os, time, threading
import chainlit as cl
import httpx
from prometheus_client import Counter, Histogram, start_http_server

chat_requests_total = Counter("chat_requests_total", "Total chat messages processed", ["status"])
chat_latency_seconds = Histogram("chat_latency_seconds", "End-to-end chat response latency")

threading.Thread(target=lambda: start_http_server(9090), daemon=True).start()

AGENT_URL  = os.environ.get("AGENT_URL",  "http://hermes:8642")
HERMES_KEY = os.environ.get("HERMES_API_KEY", "smile-dental-course-key")
SYSTEM_PROMPT = (
    "You are the Smile Dental Clinic assistant. Use the triage, treatment_lookup, "
    "and book_appointment tools in sequence for patient symptom queries."
)


@cl.on_chat_start
async def on_chat_start():
    await cl.Message(
        content=(
            "Welcome to **Smile Dental Clinic** assistant!\n\n"
            "Try: _\"severe tooth pain since yesterday\"_ — the agent will triage, "
            "look up treatment options, and offer to book an appointment.\n\n"
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
