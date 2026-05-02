---
sidebar_position: 8
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Lab 07: Agent Core

**Day 2 | Duration: ~60 minutes**

Today the Smile Dental assistant becomes an agent. We swap the local SmolLM2 model for a free-tier cloud LLM (Groq or Gemini), wrap the clinic's business logic as three MCP tool servers, and orchestrate them with the **Hermes Agent** gateway. Chainlit's pipeline-call path is replaced by a single agent call — Hermes decides which tools to invoke and in what order. Lab 07 runs entirely in Docker Compose so the iteration loop stays fast; Lab 08 ports the same stack to Kubernetes Agent Sandbox.

## Learning Objectives

- **Understand** the distinction between a pipeline (fixed RAG → prompt → LLM) and an agent (LLM decides which tools to call)
- **Configure** the Hermes Agent gateway via `config.yaml` and `SOUL.md` to serve Smile Dental business logic
- **Build** three FastMCP Streamable HTTP tool servers (triage, treatment_lookup, book_appointment) and register them with Hermes
- **Run** the multi-step Docker Compose stack end-to-end with a real free-tier LLM provider
- **Verify** the canonical "severe tooth pain since yesterday" query exercises all three tools in sequence

## Lab Files

Companion code: `course-code/labs/lab-07/`

Key subdirectories in `solution/`:
- `hermes-config/` — `config.yaml`, `SOUL.md` (Hermes identity + model config)
- `tools/triage/` — symptom severity classifier (LLM-as-tool pattern)
- `tools/treatment_lookup/` — wraps the Day-1 RAG retriever
- `tools/book_appointment/` — persists bookings to a JSON volume
- `ui/` — Day-2 Chainlit app calling Hermes instead of vLLM
- `scripts/verify-hermes-startup.sh` — pre-flight image check

## Prerequisites

- [ ] Day 1 labs (00–06) complete and KIND cluster running
- [ ] Day-1 RAG retriever reachable on host port 8001 — in a **separate terminal** run:
  ```bash
  kubectl -n llm-app port-forward svc/rag-retriever 8001:8001
  ```
  Leave this terminal open for the duration of Lab 07.
- [ ] vLLM scaled to 0 to free ~2–4 GB RAM. If you completed the "Wind Down Before Day 2" section at the end of Lab 06, you already ran this. If not, run it now:
  ```bash
  kubectl scale deployment vllm-smollm2 --replicas=0 -n llm-serving
  ```
- [ ] Free-tier API key from **either** [Groq Cloud](https://console.groq.com) (recommended) **or** [Google AI Studio](https://aistudio.google.com)
- [ ] Docker Desktop running with at least 6 GB RAM available:
  ```bash
  docker info | grep -i memory
  ```

---

## Part A: Verify the Hermes image starts on your machine

### Why verify first?

The `nousresearch/hermes-agent:latest` image is 2.4 GB and only published under the `latest` tag — there is no pinned version to fall back on. On a slow network or CPU-constrained laptop, startup can take 30–60 seconds. It is much better to confirm the image pulls and the gateway starts before investing 30 minutes in configuration. This check resolves the CPU-only startup question documented in RESEARCH.md open questions Q2 and Q3.

```bash
bash course-code/labs/lab-07/solution/scripts/verify-hermes-startup.sh
```

The script pulls the image, starts a one-shot container, waits up to 60 seconds for `/health`, and validates that `/v1/chat/completions` is reachable. On success you will see:

```
OK: Hermes Agent image starts on CPU-only host with headless 'hermes gateway' command.
    Port 8642 exposes /health and /v1/chat/completions.
```

:::warning Image pull is large (~2.4 GB)
Run this on a good network connection or let it run in the background. The first pull may take several minutes. Subsequent runs use the Docker layer cache and start in seconds.
:::

---

## Part B: Set up your LLM provider

### Why a remote LLM here?

Hermes Agent enforces a **64,000-token minimum context window** at startup. SmolLM2-135M (the model from Day 1) has a 4,096-token context and does not qualify — Hermes will refuse to start with it. For Day 2 we use a free-tier cloud LLM: Groq's `llama-3.3-70b-versatile` (128K context) or Google's `gemini-2.5-flash` (1M context). Both are consumed via an OpenAI-compatible base URL, so the same Chainlit and Hermes config works for either provider.

<Tabs groupId="llm-provider">
<TabItem value="groq" label="Groq (recommended)">

**Why Groq is recommended:** Fastest inference for Llama on free-tier; limits are clear (30 RPM / 6K TPM / 1000 RPD per model per day); no rate-limit surprises mid-workshop.

1. Sign up at [console.groq.com](https://console.groq.com) and create an API key (`gsk_…`).
2. Copy the example env file:
   ```bash
   cd course-code/labs/lab-07/solution
   cp .env.example .env
   ```
3. Edit `.env` and uncomment the Groq block:
   ```bash
   HERMES_API_KEY=smile-dental-course-key

   GROQ_API_KEY=gsk_your_key_here
   LLM_BASE_URL=https://api.groq.com/openai/v1
   LLM_MODEL=llama-3.3-70b-versatile
   ```

</TabItem>
<TabItem value="gemini" label="Gemini (alternative)">

**Why Gemini is the alternative:** Google AI Studio has a very generous free tier (15 RPM, 1M TPM per day for Flash models) but the Gemini 2.5 Flash model is a "thinking" model — it uses internal reasoning tokens before producing output. The `triage` tool sets `max_tokens=512` to leave headroom for thinking; if you lower this value the triage response may be truncated.

1. Get a key from [aistudio.google.com](https://aistudio.google.com) → API keys → Create API key.
2. Copy the example env file:
   ```bash
   cd course-code/labs/lab-07/solution
   cp .env.example .env
   ```
3. Edit `.env` and uncomment the Gemini block:
   ```bash
   HERMES_API_KEY=smile-dental-course-key

   GOOGLE_API_KEY=AIza_your_key_here
   LLM_BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai
   LLM_MODEL=gemini-2.5-flash
   ```

:::note Gemini OpenAI-compat endpoint
The `LLM_BASE_URL` above points Hermes at Google's OpenAI-compatibility layer (`/v1beta/openai`). This is different from the native Gemini API. Using the native endpoint would require a different `model.default` format (`google/gemini-2.5-flash`) and an extra `GEMINI_BASE_URL` env var in the compose file — the solution code already sets this up in `docker-compose.yaml` for you.
:::

</TabItem>
</Tabs>

---

## Part C: Tour the MCP tool servers

### What is MCP?

The **Model Context Protocol** (MCP) is an open spec for connecting LLMs to external tools in a transport-agnostic way. An MCP server exposes typed, documented functions that any MCP client — including Hermes — can discover and call at runtime. Lab 07 uses **Streamable HTTP** transport, the current standard since the MCP spec update on 2025-03-26. The older SSE transport is now deprecated; do not use it for new servers.

Each MCP server in this lab is a standalone FastMCP application running on its own port. Hermes registers all three at startup by polling their `/mcp` endpoints, then prefixes their tools as `mcp_<server>_<tool>` in its internal tool registry.

### triage — LLM-prompted severity classifier

This tool implements the D-09 pattern: the tool makes its own LLM call to classify severity — demonstrating that MCP tools can themselves invoke LLMs.

From `course-code/labs/lab-07/solution/tools/triage/triage_server.py`:

```python
mcp = FastMCP(
    "triage",
    json_response=True,
    transport_security=TransportSecuritySettings(enable_dns_rebinding_protection=False),
)

TRIAGE_PROMPT = """You are a dental triage assistant.
Classify the symptom severity as one of: severe, urgent, routine.
Respond ONLY with a JSON object: {{"severity": "severe"|"urgent"|"routine", "reason": "<one short sentence>"}}
Symptom: {symptom}"""

@mcp.tool()
async def triage(symptom: str) -> dict:
    """Classify a dental symptom severity (severe/urgent/routine).

    Args:
        symptom: Patient's symptom description in natural language.
    """
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(
            f"{LLM_BASE_URL}/chat/completions",
            headers={"Authorization": f"Bearer {LLM_API_KEY}"},
            json={
                "model": LLM_MODEL,
                "messages": [{"role": "user", "content": TRIAGE_PROMPT.format(symptom=symptom)}],
                "max_tokens": _MAX_TOKENS,
                "temperature": 0.1,
            },
        )
        resp.raise_for_status()
        text = resp.json()["choices"][0]["message"]["content"]
    return _extract_json(text)
```

### treatment_lookup — wraps the Day-1 RAG retriever

This tool reuses the Day-1 RAG retriever unchanged (D-10). It calls `/search` and returns top-k chunks. In Docker Compose mode the URL is `host.docker.internal:8001`; Lab 08 points it at the in-cluster Service.

From `course-code/labs/lab-07/solution/tools/treatment_lookup/treatment_lookup_server.py`:

```python
@mcp.tool()
async def treatment_lookup(treatment_name: str, k: int = 3) -> list[dict]:
    """Look up Smile Dental treatment information from the clinic knowledge base.

    Args:
        treatment_name: Treatment name or description.
        k: Number of relevant chunks to retrieve (default 3).
    """
    async with httpx.AsyncClient(timeout=15) as client:
        resp = await client.post(
            f"{RETRIEVER_URL}/search",
            json={"query": treatment_name, "k": k},
        )
        resp.raise_for_status()
    return resp.json().get("hits", [])
```

### book_appointment — persists bookings to JSON (Lab 07) / ConfigMap (Lab 08)

This tool implements D-11: writes to a named Docker volume (`bookings-data`) at `/data/bookings.json`. Lab 08 extends it to write to a Kubernetes ConfigMap. `filelock` replaces `fcntl.flock` for Windows Docker Desktop compatibility.

From `course-code/labs/lab-07/solution/tools/book_appointment/book_appointment_server.py`:

```python
@mcp.tool()
def book_appointment(
    patient_name: str,
    treatment: str,
    urgency: str,
    preferred_date: str = "soonest available",
) -> dict:
    """Book an appointment at Smile Dental Clinic.

    Args:
        patient_name: Full name of the patient.
        treatment: Treatment or procedure name.
        urgency: severe / urgent / routine (from triage).
        preferred_date: Preferred date or "soonest available".

    Returns:
        Booking confirmation with appointment_id (format SD-YYYYMMDDHHMMSS).
    """
    booking = {
        "appointment_id": f"SD-{datetime.datetime.utcnow().strftime('%Y%m%d%H%M%S')}",
        "patient_name": patient_name,
        "treatment": treatment,
        "urgency": urgency,
        "preferred_date": preferred_date,
        "status": "confirmed",
        "created_at": datetime.datetime.utcnow().isoformat(),
    }
    _append_local(booking)
    booking["storage"] = "local-file"
    return booking
```

:::tip How tools become available to the LLM
At startup Hermes polls each `url` in `config.yaml` and discovers tools via MCP. It prefixes each as `mcp_<server>_<tool>` — the agent sees `mcp_triage_triage`, `mcp_treatment_lookup_treatment_lookup`, `mcp_book_appointment_book_appointment`. These names appear in the `tool_calls` array of every Hermes response. Any OpenAI-compatible LLM (Groq Llama-3.3, Gemini 2.5 Flash) can use them without extra integration.
:::

---

## Part D: Hermes configuration

Hermes reads configuration from files mounted at `/opt/data/` inside the container. The Docker Compose file mounts `./hermes-config/` to that path.

### config.yaml

```yaml
# Hermes Agent configuration for Smile Dental — Lab 07 (Docker Compose mode)
# MCP servers reach each other inside the agent-net Docker network by service name.

model:
  default: groq/llama-3.3-70b-versatile     # 128K context — satisfies Hermes 64K minimum

mcp_servers:
  triage:
    url: "http://mcp-triage:8010/mcp"
  treatment_lookup:
    url: "http://mcp-treatment-lookup:8020/mcp"
  book_appointment:
    url: "http://mcp-book-appointment:8030/mcp"

agent:
  max_turns: 10
  disabled_toolsets: [memory, web, browser, code, voice]

compression:
  enabled: false

display:
  streaming: false
```

Key lines: `model.default` selects a 128K-context Groq model (satisfies Hermes's 64K minimum). The three `mcp_servers` URLs use Docker service names — the `/mcp` suffix is mandatory (see Common Pitfalls). `disabled_toolsets` turns off Hermes's 40+ built-in tools so only the three Smile Dental tools are available. `compression.enabled: false` simplifies short demo sessions.

:::warning The /mcp path suffix is mandatory
All three `url` values end in `/mcp`. This is where FastMCP's `streamable_http_app()` mounts the MCP endpoint by default. If you omit `/mcp` and use `http://mcp-triage:8010/` instead, Hermes logs `Connection refused` or HTTP 404 when it tries to discover tools at startup — and the tools will not be available to the LLM.
:::

### SOUL.md

The `SOUL.md` file is the Hermes system prompt — it defines the agent's identity:

```markdown
You are the Smile Dental Clinic AI assistant. You help patients with three workflows:

1. **Triage** — assess symptom severity (severe / urgent / routine) using the `triage` tool.
2. **Treatment lookup** — find clinically relevant treatment information using the `treatment_lookup` tool, which queries the Smile Dental knowledge base.
3. **Appointment booking** — schedule a consultation using the `book_appointment` tool. Always pass the urgency from triage and the treatment name from the lookup.

For any patient query that mentions a symptom, follow this sequence: triage the symptom, look up the relevant treatment, then book the appointment. Be concise, professional, and reassuring. Only book an appointment after you have triaged and looked up the treatment.
```

---

## Part E: Day-2 Chainlit changes

### What changed from Day 1

Day 1 ran three fixed pipeline steps: RAG retrieval, prompt construction, vLLM generation. Day 2 replaces all three with a single `Agent processing` step — Chainlit sends the message to Hermes `/v1/chat/completions` and renders a collapsible sub-step for each tool call in the response. Removed: RAG step, prompt-building step, vLLM streaming + SSE logic. Added: `AGENT_URL`/`HERMES_API_KEY` env vars, dynamic tool sub-steps.

### The on_message handler

From `course-code/labs/lab-07/solution/ui/app.py`:

```python
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
```

`stream: False` keeps Lab 07 simple — the full response arrives in one JSON payload. Lab 09 (observability) may revisit streaming once OTEL tracing is wired in.

---

## Part F: Run the multi-step demo

### Start the stack

```bash
cd course-code/labs/lab-07/solution
cp .env.example .env   # if you haven't already — then edit to add your API key
docker compose up -d --build
```

Build time: 2–4 minutes on first run (base images + Python deps). Subsequent starts use the image cache.

Check all five services are healthy:

```bash
docker compose ps
# Expected: hermes-agent, chainlit-ui, mcp-triage, mcp-treatment-lookup, mcp-book-appointment — all Up/healthy
```

### Canonical demo — curl

Send the canonical multi-step query directly to the Hermes API:

```bash
curl -s -X POST http://localhost:8642/v1/chat/completions \
  -H "Authorization: Bearer smile-dental-course-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model":"hermes",
    "messages":[
      {"role":"system","content":"Use triage, treatment_lookup, and book_appointment tools in sequence."},
      {"role":"user","content":"severe tooth pain since yesterday — please book me in"}
    ],
    "stream": false
  }' | python3 -m json.tool
```

In the response, look for `"tool_calls"` with three entries: `mcp_triage_triage`, `mcp_treatment_lookup_treatment_lookup`, `mcp_book_appointment_book_appointment`.

:::note treatment_lookup may return empty hits
If the Day-1 RAG retriever is not port-forwarded (`kubectl -n llm-app port-forward svc/rag-retriever 8001:8001`), `treatment_lookup` returns an empty list. The agent gracefully continues to `book_appointment` anyway — this is expected behavior in Docker Compose mode. Full end-to-end with retrieval works in Lab 08 (K8s).
:::

### Canonical demo — Chainlit UI

Open `http://localhost:8000` in your browser. You will see the Smile Dental welcome message.

Type: **severe tooth pain since yesterday**

After the response, expand the `Agent processing` step — you will see three `Tool: mcp_*` sub-steps revealing which tools were called and with what arguments.

{/* TODO: screenshot of Chainlit Step expansion showing 3 tool calls */}

### Verify the booking was saved

```bash
docker compose exec mcp-book-appointment cat /data/bookings.json
# Expected: JSON array with appointment_id "SD-YYYYMMDDHHMMSS", status "confirmed"
```

---

## Verification

```bash
# 1. All services healthy
docker compose ps
# Expected: all 5 containers Up / healthy

# 2. Hermes health endpoint
curl http://localhost:8642/health
# Expected: 200 with {"status":"ok"}

# 3. MCP servers registered at startup
docker compose logs hermes | grep -i mcp
# Expected: triage, treatment_lookup, book_appointment registered

# 4. Canonical query calls all 3 tools
curl -s -X POST http://localhost:8642/v1/chat/completions \
  -H "Authorization: Bearer smile-dental-course-key" \
  -H "Content-Type: application/json" \
  -d '{"model":"hermes","messages":[{"role":"user","content":"severe tooth pain since yesterday — book me in"}],"stream":false}' \
  | python3 -m json.tool | grep '"name"'
# Expected: mcp_triage_triage, mcp_treatment_lookup_treatment_lookup, mcp_book_appointment_book_appointment

# 5. Booking persisted
docker compose exec mcp-book-appointment cat /data/bookings.json
# Expected: JSON array with >= 1 entry containing appointment_id SD-YYYYMMDDHHMMSS
```

---

## Common Pitfalls

:::warning Hermes requires a model with 64K+ context window
Hermes enforces a 64,000-token minimum context window at startup. If you point it at a small model or an API that returns a lower `context_length`, Hermes exits with `ValueError: context_length below MINIMUM_CONTEXT_LENGTH`. Use `llama-3.3-70b-versatile` (Groq, 128K) or `gemini-2.5-flash` (Gemini, 1M). SmolLM2-135M (4K context) does not qualify.
:::

:::warning MCP url MUST end in /mcp
Every MCP server URL in `config.yaml` must include the `/mcp` path suffix. FastMCP's `streamable_http_app()` mounts the MCP endpoint at `/mcp` by default. Using `http://mcp-triage:8010/` (no suffix) causes Hermes to log `Connection refused` or HTTP 404 when registering tools at startup, and the tools will not be available to the LLM.
:::

:::warning API_SERVER_HOST=0.0.0.0 is mandatory inside containers
Without `API_SERVER_HOST=0.0.0.0` in the Hermes environment, Hermes binds its API server to `127.0.0.1` only. Chainlit and your local `curl` commands both run outside the container network, so they receive `Connection refused` on port 8642. The `docker-compose.yaml` already sets this, but if you run Hermes manually or override env vars, include this setting.
:::

:::note Linux Docker users — host.docker.internal requires extra_hosts
On Linux, `host.docker.internal` does not resolve by default inside containers. The `mcp-treatment-lookup` service in `docker-compose.yaml` already includes:
```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```
This resolves the Day-1 RAG retriever at `http://host.docker.internal:8001`. On macOS and Windows Docker Desktop, this is automatic. On Linux Docker Engine, the `extra_hosts` entry is required.
:::

:::warning Free-tier rate limits
Groq free tier: 30 RPM / 6,000 TPM / 1,000 RPD per model. Each canonical demo query consumes 2–3 LLM calls (one for triage, one for the agent's final reasoning). For a class of 20 students sharing one account, switch to individual accounts or use Gemini which has higher daily token limits. If you receive HTTP 429, wait 60 seconds or switch to the other provider via `.env`.
:::

---

## After This Lab

| Component | URL | Status |
|-----------|-----|--------|
| Hermes Agent gateway | `http://localhost:8642/v1/chat/completions` | Running (Docker) |
| Smile Dental Chat (Day-2) | `http://localhost:8000` | Running (Docker) |
| mcp-triage | container-internal `:8010/mcp` | Running (Docker) |
| mcp-treatment-lookup | container-internal `:8020/mcp` | Running (Docker) |
| mcp-book-appointment | container-internal `:8030/mcp` | Running (Docker) |
| RAG retriever (Day 1, port-forwarded) | `http://localhost:8001` | Required upstream (KIND) |

In Lab 08 we package this exact stack into Kubernetes Agent Sandbox. Each Chainlit session will claim its own pre-warmed Sandbox instance from a `SandboxWarmPool` — providing per-user isolation and near-zero cold-start latency. The functionality is identical to what you built here; Lab 08 is promotion to Kubernetes, not new features.

---

## Tear Down (optional)

```bash
cd course-code/labs/lab-07/solution
docker compose down -v
```

The `-v` flag removes the `bookings-data` volume. Leave the stack running if you want to compare the Docker Compose version with the Lab 08 Kubernetes deployment. Stop the `kubectl port-forward` terminal (Ctrl-C) when done.
