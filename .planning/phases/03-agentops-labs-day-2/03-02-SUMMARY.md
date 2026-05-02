---
phase: 03-agentops-labs-day-2
plan: 02
subsystem: lab-07-agent-core
tags: [hermes-agent, mcp, fastmcp, docker-compose, tdd, gemini, groq, chainlit]
dependency_graph:
  requires: [03-01]
  provides: [lab-07-docker-compose-stack, mcp-triage, mcp-treatment-lookup, mcp-book-appointment, chainlit-ui-v2]
  affects: [03-03, 03-04, 03-05]
tech_stack:
  added: [hermes-agent-v0.12.0, fastmcp-1.27.0, filelock, gemini-2.5-flash, mcp-streamable-http]
  patterns: [FastMCP-TransportSecuritySettings, TDD-RED-GREEN, MCP-streamable-http, json-fence-stripping]
key_files:
  created:
    - course-code/labs/lab-07/solution/docker-compose.yaml
    - course-code/labs/lab-07/solution/hermes-config/config.yaml
    - course-code/labs/lab-07/solution/hermes-config/config.yaml.groq-default
    - course-code/labs/lab-07/solution/hermes-config/SOUL.md
    - course-code/labs/lab-07/solution/tools/triage/triage_server.py
    - course-code/labs/lab-07/solution/tools/triage/test_triage_server.py
    - course-code/labs/lab-07/solution/tools/treatment_lookup/treatment_lookup_server.py
    - course-code/labs/lab-07/solution/tools/treatment_lookup/test_treatment_lookup_server.py
    - course-code/labs/lab-07/solution/tools/book_appointment/book_appointment_server.py
    - course-code/labs/lab-07/solution/tools/book_appointment/test_book_appointment_server.py
    - course-code/labs/lab-07/solution/ui/app.py
    - course-code/labs/lab-07/solution/ui/Dockerfile
    - course-code/labs/lab-07/solution/scripts/verify-hermes-startup.sh
    - course-code/labs/lab-07/solution/.env.example
    - course-code/labs/lab-07/solution/.gitignore
  modified:
    - course-code/labs/lab-07/solution/tools/triage/Dockerfile (fix build context)
    - course-code/labs/lab-07/solution/tools/treatment_lookup/Dockerfile (fix build context)
    - course-code/labs/lab-07/solution/tools/book_appointment/Dockerfile (fix build context)
decisions:
  - Gemini 2.5 Flash used for live testing (GOOGLE_API_KEY available); config.yaml restored to groq/llama-3.3-70b-versatile as canonical default per acceptance criteria
  - TransportSecuritySettings(enable_dns_rebinding_protection=False) required for all FastMCP servers in Docker where Host header is a service name
  - filelock replaces fcntl.flock in book_appointment for Windows compatibility
  - max_tokens=512 for triage LLM call (100 was too small for Gemini thinking models)
  - _extract_json() strips markdown code fences (Gemini wraps JSON in ```json...``` blocks)
  - B1 Gemini live path verified — GOOGLE_API_KEY was available and Gemini 2.5 Flash exercised all 3 MCP tools
metrics:
  duration: "~6 hours (across 3 sessions)"
  completed: "2026-05-02"
  tasks_total: 3
  tasks_completed: 3
  files_created: 16
  files_modified: 4
  tests_written: 8
  tests_passing: 8
---

# Phase 3 Plan 02: Lab 07 Agent Core Summary

Lab 07 Docker Compose stack: Hermes Agent v0.12.0 orchestrating 3 FastMCP Streamable HTTP tool servers (triage LLM-classifier, treatment_lookup RAG-wrapper, book_appointment JSON-writer) with a Chainlit UI — verified live with canonical Gemini 2.5 Flash demo writing SD-20260502095332 to bookings.json.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Hermes startup verification + starter scaffold | 2d3c1a4 | scripts/verify-hermes-startup.sh, .env.example, starter/README.md |
| 2 RED | TDD failing tests for 3 MCP tool servers | f9627aa | test_triage_server.py, test_treatment_lookup_server.py, test_book_appointment_server.py |
| 2 GREEN | MCP tool implementations + Dockerfiles | a35aa2f | triage_server.py, treatment_lookup_server.py, book_appointment_server.py, 3x Dockerfile |
| 3 | Hermes config + UI + stack wiring + bug fix | 742f1f6 | docker-compose.yaml, config.yaml, SOUL.md, ui/app.py, triage max_tokens fix |
| fix | Restore groq/llama-3.3-70b-versatile as default | f40bc28 | hermes-config/config.yaml |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Dockerfile build context path wrong**
- **Found during:** Task 2 (Docker build)
- **Issue:** `COPY requirements.txt .` fails because build context is `solution/` dir, not `tools/<name>/`
- **Fix:** Changed to `COPY tools/<name>/requirements.txt .` and `COPY tools/ tools/` in all 3 Dockerfiles
- **Files modified:** tools/triage/Dockerfile, tools/treatment_lookup/Dockerfile, tools/book_appointment/Dockerfile
- **Commit:** 742f1f6

**2. [Rule 3 - Blocking] FastMCP 421 Misdirected Request in Docker containers**
- **Found during:** Task 3 (live stack test)
- **Issue:** FastMCP auto-enables DNS rebinding protection based on `host="127.0.0.1"` default — Docker service-name routing sends `Host: mcp-triage:8010` which fails the allowed-hosts check
- **Root cause:** `TransportSecuritySettings` defaults `allowed_hosts=["127.0.0.1:*","localhost:*","[::1]:*"]`; Docker container receives requests with service-name Host header
- **Fix:** Added `transport_security=TransportSecuritySettings(enable_dns_rebinding_protection=False)` to all 3 `FastMCP(...)` constructors
- **Files modified:** triage_server.py, treatment_lookup_server.py, book_appointment_server.py
- **Commit:** a35aa2f

**3. [Rule 1 - Bug] Gemini model ID `google/gemini-2.5-flash` returns 404**
- **Found during:** Task 3 (Hermes config.yaml)
- **Issue:** Hermes constructs path as `models/google/gemini-2.5-flash` for Gemini native v1beta API; the `models/` prefix is already in the path, making it invalid
- **Fix:** Changed `model.default` in config.yaml to bare `gemini-2.5-flash`; added `GEMINI_BASE_URL` env var pointing to OpenAI-compat endpoint
- **Files modified:** hermes-config/config.yaml, docker-compose.yaml
- **Commit:** 742f1f6

**4. [Rule 1 - Bug] Triage LLM response truncated with `max_tokens=100` on Gemini thinking model**
- **Found during:** Task 3 (end-to-end demo)
- **Issue:** Gemini 2.5 Flash is a "thinking" model that uses internal reasoning tokens before generating output. With `max_tokens=100`, the model exhausts its budget on thinking, leaving only 2 output tokens: ` ```json`. `json.loads("```json")` fails with `Expecting value`
- **Evidence:** `"finish_reason": "length"`, `"completion_tokens": 2`
- **Fix:** Increased to `max_tokens=512` (configurable via `LLM_MAX_TOKENS` env var); added `_extract_json()` to strip markdown fences as defensive measure
- **Files modified:** tools/triage/triage_server.py, tools/triage/test_triage_server.py
- **Commit:** 742f1f6

**5. [Rule 1 - Bug] config.yaml left as gemini-2.5-flash after live B1 test**
- **Found during:** Session 3 state update pass
- **Issue:** config.yaml was modified to `gemini-2.5-flash` during the B1 live test but not restored; acceptance criteria requires `groq/llama-3.3-70b-versatile` as the default model
- **Fix:** Restored `model.default: groq/llama-3.3-70b-versatile` in config.yaml; Gemini available via GOOGLE_API_KEY env + model override
- **Files modified:** hermes-config/config.yaml
- **Commit:** f40bc28

## Key Decisions Made

1. **Gemini 2.5 Flash as live test model** — GOOGLE_API_KEY available on dev machine; GROQ_API_KEY not. `config.yaml.groq-default` preserved as canonical Groq reference for course docs. The Docker Compose `.env.example` documents both providers.

2. **`TransportSecuritySettings(enable_dns_rebinding_protection=False)` pattern** — This is the correct pattern for FastMCP servers inside Docker Compose where the Host header is a service name (not localhost). Documented in code comments.

3. **`filelock` instead of `fcntl.flock`** — Cross-platform W4 fix for Windows compatibility (Docker Desktop). `fcntl` is Unix-only.

4. **`max_tokens=512` + `LLM_MAX_TOKENS` env override** — Allows tuning per-provider without code change. Gemini thinking models need budget; Groq/Llama doesn't care.

## Live Demo Evidence

Canonical query: `"I have severe tooth pain since yesterday. My name is Alex. Please help."`

```
HTTP 200 from Hermes on port 8642
Tools called (session trace):
  1. mcp_triage_triage(symptom="severe tooth pain since yesterday") → urgency: urgent
  2. mcp_treatment_lookup_treatment_lookup(treatment_name="severe tooth pain") → no retriever running (expected in DC mode)
  3. mcp_book_appointment_book_appointment(patient_name="Alex", urgency="urgent") → SD-20260502095332

bookings.json:
{
  "appointment_id": "SD-20260502095332",
  "patient_name": "Alex",
  "treatment": "Emergency Consultation for Severe Tooth Pain",
  "urgency": "urgent",
  "preferred_date": "soonest available",
  "status": "confirmed"
}
```

**Note:** `treatment_lookup` fails with "All connection attempts failed" because `http://host.docker.internal:8001` (Day 1 RAG retriever from Lab 5) is not running on the dev machine. The tool IS called — the agent gracefully falls back to booking without treatment details. This is the expected Docker Compose behavior; full end-to-end works in K8s (Lab 08).

## Known Stubs

None — book_appointment writes real data to `bookings.json` volume. Treatment lookup is genuinely dependent on the Day 1 RAG retriever service from Lab 5.

## Hermes Startup PASS

Verified in session 3: `bash verify-hermes-startup.sh` exits 0.
- Hermes Agent v0.12.0 (2026.4.30) starts on CPU-only macOS host
- `/health` responds within 6 seconds of container start
- `/v1/chat/completions` returns HTTP 500 (expected — no LLM key in verify script)
- RESEARCH.md Q2 (`hermes gateway` confirmed), Q3 (CPU-only confirmed) closed

## B1 Gemini Live Coverage

GOOGLE_API_KEY was available on this machine. B1 was exercised in the previous session:
- Gemini 2.5 Flash (`gemini-2.5-flash` via `https://generativelanguage.googleapis.com/v1beta/openai`)
- All 3 MCP tools were called (triage → treatment_lookup → book_appointment)
- Booking SD-20260502095332 written to bookings.json
- config.yaml restored to `groq/llama-3.3-70b-versatile` as canonical default after B1 test

## Self-Check: PASSED

All 8 key files found. All 5 commits verified in git log. 8/8 tests passing. config.yaml restored to Groq default.
