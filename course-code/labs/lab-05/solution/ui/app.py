#!/usr/bin/env python3
"""
app.py — Smile Dental Chainlit Chat UI with glass-box learning mode.

Glass-box mode: Each pipeline stage (RAG retrieval, prompt construction,
LLM generation) is visible as a collapsible Chainlit Step so students can
see exactly what the system is doing at each stage.

Environment:
  RETRIEVER_URL — FastAPI retriever base URL (default: cluster-internal service)
  VLLM_URL      — vLLM OpenAI-compatible API base URL
  MODEL_NAME    — Model identifier for vLLM API calls
"""
import os, time, json, threading
import chainlit as cl
import httpx
from prometheus_client import Counter, Histogram, start_http_server

# ---- Prometheus metrics ---------------------------------------------------

chat_requests_total = Counter(
    "chat_requests_total", "Total chat messages processed", ["status"]
)
chat_latency_seconds = Histogram(
    "chat_latency_seconds", "End-to-end chat response latency"
)

# Start standalone Prometheus metrics server on port 9090.
# Chainlit's catch-all route /{full_path:path} intercepts any /metrics mount
# on the main app (port 8000), so a separate port is the reliable approach.
_metrics_thread = threading.Thread(
    target=lambda: start_http_server(9090), daemon=True
)
_metrics_thread.start()

# ---- Configuration -------------------------------------------------------

RETRIEVER_URL = os.environ.get(
    "RETRIEVER_URL",
    "http://rag-retriever.llm-app.svc.cluster.local:8001"
)
VLLM_URL = os.environ.get(
    "VLLM_URL",
    "http://vllm-smollm2.llm-serving.svc.cluster.local:8000"
)
MODEL_NAME = os.environ.get("MODEL_NAME", "smollm2-135m-finetuned")
MAX_TOKENS = int(os.environ.get("MAX_TOKENS", "300"))
TOP_K = int(os.environ.get("TOP_K", "3"))

SYSTEM_PROMPT = (
    "You are a helpful assistant for Smile Dental Clinic, Pune. "
    "Answer questions about dental treatments, pricing (in INR), "
    "appointment policies, and general dental health. "
    "Be concise, accurate, and friendly. "
    "If you don't know something, say so honestly."
)

# ---- Helpers --------------------------------------------------------------

def build_messages(query: str, hits: list[dict]) -> list[dict]:
    """Build LLM messages from user query and RAG retrieval hits.

    Constructs a context string from retrieved document chunks and
    wraps it in the standard system + user message format expected
    by OpenAI-compatible chat completion APIs.
    """
    # Construct context string from each retrieved chunk
    context_parts = []
    for hit in hits:
        section = hit.get("section", "General")
        text = hit.get("text", "")
        context_parts.append(f"Section: {section}\n{text}")
    context = "\n\n".join(context_parts)

    return [
        {
            "role": "system",
            "content": SYSTEM_PROMPT + "\n\nContext:\n" + context,
        },
        {
            "role": "user",
            "content": query,
        },
    ]


def parse_sse(line: str) -> str | None:
    """Parse a Server-Sent Events line and return the token text (or None).

    vLLM streams responses as SSE: each line is either empty, a heartbeat,
    or "data: {...}" containing a delta token. The final message is
    "data: [DONE]" which we skip.
    """
    if line.startswith("data: ") and line != "data: [DONE]":
        try:
            payload = json.loads(line[6:])
            return payload["choices"][0]["delta"].get("content", "")
        except (json.JSONDecodeError, KeyError, IndexError):
            return None
    return None

# ---- Chainlit handlers ---------------------------------------------------

@cl.on_chat_start
async def on_chat_start():
    """Send welcome message when chat session starts."""
    await cl.Message(
        content=(
            "Welcome to **Smile Dental Clinic** assistant!\n\n"
            "I can help you with information about treatments, pricing (INR), "
            "appointment policies, and general dental health questions.\n\n"
            "_Expand the steps below each answer to see how I found the information._"
        )
    ).send()


@cl.on_message
async def on_message(message: cl.Message):
    """Handle incoming user messages through the RAG + LLM pipeline.

    Each pipeline stage is wrapped in a cl.Step so students can expand
    the steps to see exactly what data flowed through each stage.
    """
    hits = []
    t_start = time.monotonic()

    # ---- Step 1: RAG Retrieval -------------------------------------------
    try:
        async with cl.Step(
            name="Retrieving clinic documents",
            type="tool",
            default_open=False,
        ) as s:
            s.input = message.content
            t0 = time.monotonic()
            async with httpx.AsyncClient(timeout=30) as client:
                resp = await client.post(
                    f"{RETRIEVER_URL}/search",
                    json={"query": message.content, "k": TOP_K},
                )
                resp.raise_for_status()
            hits = resp.json().get("hits", [])
            elapsed = time.monotonic() - t0
            doc_lines = "\n".join(
                f"  [{i+1}] {h.get('doc_id', '?')} ({h.get('section', '?')}) — score {h.get('score', 0):.2f}"
                for i, h in enumerate(hits)
            )
            s.output = f"Found {len(hits)} relevant chunks in {elapsed:.2f}s\n{doc_lines}"
    except Exception as exc:
        chat_requests_total.labels(status="retriever_error").inc()
        await cl.Message(
            content=f"Retriever error: {exc}\n\nMake sure the RAG retriever service is running."
        ).send()
        return

    # ---- Step 2: Prompt Construction -------------------------------------
    async with cl.Step(
        name="Building prompt",
        type="run",
        show_input="json",
    ) as s:
        messages = build_messages(message.content, hits)
        s.input = messages
        s.output = (
            f"Constructed {len(messages)}-message prompt "
            f"with {len(hits)} context chunks"
        )

    # ---- Streaming response message (created before Step 3 so tokens
    #      stream into the main chat, not hidden inside the step) ----------
    response_msg = cl.Message(content="")
    await response_msg.send()

    # ---- Step 3: LLM Generation (streaming) -----------------------------
    try:
        async with cl.Step(name="LLM generation", type="run") as s:
            async with httpx.AsyncClient(timeout=120) as client:
                async with client.stream(
                    "POST",
                    f"{VLLM_URL}/v1/chat/completions",
                    json={
                        "model": MODEL_NAME,
                        "messages": messages,
                        "max_tokens": MAX_TOKENS,
                        "temperature": 0.1,
                        "stream": True,
                    },
                ) as stream:
                    async for line in stream.aiter_lines():
                        token = parse_sse(line)
                        if token:
                            await response_msg.stream_token(token)
            s.output = "Generation complete"
    except Exception as exc:
        chat_requests_total.labels(status="llm_error").inc()
        await cl.Message(
            content=f"LLM generation error: {exc}\n\nMake sure the vLLM service is running."
        ).send()
        return

    await response_msg.update()
    chat_requests_total.labels(status="ok").inc()
    chat_latency_seconds.observe(time.monotonic() - t_start)
