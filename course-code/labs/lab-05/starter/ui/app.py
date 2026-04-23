#!/usr/bin/env python3
"""
app.py — Smile Dental Chainlit Chat UI with glass-box learning mode.

TODO: Implement following the lab guide.

Glass-box mode uses Chainlit Steps to show each pipeline stage:
1. RAG Retrieval — calls the retriever service
2. Prompt Construction — builds the LLM prompt with context
3. LLM Generation — streams the response from vLLM

Environment:
  RETRIEVER_URL — FastAPI retriever base URL
  VLLM_URL      — vLLM OpenAI-compatible API base URL
  MODEL_NAME    — Model identifier for vLLM
"""
import os, time, json
import chainlit as cl
import httpx

RETRIEVER_URL = os.environ.get(
    "RETRIEVER_URL",
    "http://rag-retriever.llm-app.svc.cluster.local:8001"
)
VLLM_URL = os.environ.get(
    "VLLM_URL",
    "http://vllm-smollm2.llm-serving.svc.cluster.local:8000"
)
MODEL_NAME = os.environ.get("MODEL_NAME", "smollm2-135m-finetuned")
SYSTEM_PROMPT = (
    "You are a helpful assistant for Smile Dental Clinic, Pune. "
    "Answer questions about dental treatments, pricing (in INR), "
    "appointment policies, and general dental health."
)


def build_messages(query: str, hits: list[dict]) -> list[dict]:
    """Build LLM messages from user query and RAG hits."""
    # TODO: Construct context string from hits
    # TODO: Each hit has keys: section, text
    # TODO: Format as "Section: {section}\n{text}" joined by double newlines
    # TODO: Return [{"role": "system", "content": SYSTEM_PROMPT + "\n\nContext:\n" + context},
    #                {"role": "user", "content": query}]
    pass


def parse_sse(line: str):
    """Parse a Server-Sent Events line and return the token text (or None)."""
    # TODO: Check if line starts with "data: " and is not "data: [DONE]"
    # TODO: Parse JSON from line[6:] and extract choices[0].delta.get("content", "")
    # TODO: Return None for non-content lines or on parse errors
    pass


@cl.on_chat_start
async def on_chat_start():
    """Send welcome message when chat session starts."""
    # TODO: Send a welcome Message with Smile Dental branding
    # TODO: Include: clinic name, what the assistant can help with,
    #       and a hint about expanding steps to see pipeline internals
    pass


@cl.on_message
async def on_message(message: cl.Message):
    """Handle incoming user messages through the RAG + LLM pipeline."""
    # TODO: Step 1 — RAG Retrieval
    #   Use: async with cl.Step(name="Retrieving clinic documents", type="tool", default_open=False) as s:
    #   Set s.input = message.content
    #   POST to RETRIEVER_URL/search with {"query": message.content, "k": 3}
    #   Set hits = resp.json().get("hits", [])
    #   Set s.output = f"Found {len(hits)} relevant chunks in {elapsed:.2f}s"
    #   Wrap in try/except — on error send error Message and return

    # TODO: Step 2 — Prompt Construction
    #   Use: async with cl.Step(name="Building prompt", type="run", show_input="json") as s:
    #   Call messages = build_messages(message.content, hits)
    #   Set s.input = messages  (shown as collapsible JSON in UI)
    #   Set s.output = f"Constructed {len(messages)}-message prompt with {len(hits)} context chunks"

    # TODO: Create streaming response message:
    #   response_msg = cl.Message(content="")
    #   await response_msg.send()

    # TODO: Step 3 — LLM Generation
    #   Use: async with cl.Step(name="LLM generation", type="run") as s:
    #   Stream POST to VLLM_URL/v1/chat/completions with:
    #     {"model": MODEL_NAME, "messages": messages, "max_tokens": 300,
    #      "temperature": 0.1, "stream": True}
    #   Use httpx.AsyncClient(timeout=120) + client.stream("POST", ...)
    #   async for line in stream.aiter_lines():
    #       token = parse_sse(line)
    #       if token: await response_msg.stream_token(token)
    #   Set s.output = "Generation complete"
    #   Wrap in try/except — on error send error Message and return

    # TODO: await response_msg.update()
    pass
