---
phase: 02-llmops-labs-day-1
plan: "05"
subsystem: ui
tags: [chainlit, httpx, python, kubernetes, nodeport, streaming, sse]

# Dependency graph
requires:
  - phase: 02-llmops-labs-day-1
    provides: RAG retriever (Lab 01) and vLLM serving (Lab 04) services that the UI calls

provides:
  - Chainlit chat UI (app.py) with 3 collapsible glass-box Steps: RAG retrieval, prompt construction, LLM generation
  - Token-by-token streaming via httpx AsyncClient + vLLM stream=True + cl.stream_token()
  - Smile Dental branding: config.toml (cot=full, dark theme), dental-themed CSS overrides
  - K8s Deployment in llm-app namespace with readinessProbe
  - K8s NodePort Service on port 30300 (http://localhost:30300)
  - Starter skeleton app.py with 15 TODO markers at every implementation point

affects:
  - 02-06 (observability lab scrapes Chainlit pod metrics from llm-app namespace)

# Tech tracking
tech-stack:
  added:
    - chainlit==2.11.0 (chat UI framework with native Steps and streaming)
    - httpx (async HTTP client for retriever and vLLM calls)
  patterns:
    - cl.Step as context manager for glass-box pipeline visualization
    - parse_sse() helper for Server-Sent Events token extraction
    - build_messages() to compose system+user chat messages from RAG hits
    - --host 0.0.0.0 in Chainlit CMD (Pitfall 5: required for NodePort WebSocket)

key-files:
  created:
    - course-code/labs/lab-05/solution/ui/app.py
    - course-code/labs/lab-05/solution/ui/requirements.txt
    - course-code/labs/lab-05/solution/ui/Dockerfile
    - course-code/labs/lab-05/solution/ui/.chainlit/config.toml
    - course-code/labs/lab-05/solution/ui/public/smile-dental.css
    - course-code/labs/lab-05/solution/k8s/40-deploy-chainlit.yaml
    - course-code/labs/lab-05/solution/k8s/40-svc-chainlit.yaml
    - course-code/labs/lab-05/starter/ui/app.py
    - course-code/labs/lab-05/starter/ui/requirements.txt
    - course-code/labs/lab-05/starter/ui/Dockerfile
    - course-code/labs/lab-05/starter/ui/.chainlit/config.toml
    - course-code/labs/lab-05/starter/k8s/40-deploy-chainlit.yaml
    - course-code/labs/lab-05/starter/k8s/40-svc-chainlit.yaml
  modified: []

key-decisions:
  - "Pitfall 5 handled: Chainlit Dockerfile CMD uses --host 0.0.0.0 --port 8000 to avoid WebSocket 403 on NodePort"
  - "Step 3 streaming message created before the cl.Step context manager so tokens stream into main chat thread"
  - "parse_sse() returns None (not empty string) on non-content lines to avoid spurious stream_token calls"

patterns-established:
  - "Glass-box pattern: wrap each pipeline stage in cl.Step context manager with s.input/s.output for student visibility"
  - "SSE parsing: check startswith('data: ') and line != 'data: [DONE]' before JSON parse"
  - "Starter skeletons: Dockerfile/requirements.txt/config.toml/K8s manifests identical to solution; only app.py has TODOs"

requirements-completed:
  - UI-01
  - UI-02
  - UI-03

# Metrics
duration: 7min
completed: 2026-04-23
---

# Phase 2 Plan 05: Chainlit Glass-Box Chat UI Summary

**Chainlit 2.11.0 chat UI with 3 collapsible pipeline Steps (RAG retrieval, prompt construction, LLM generation streaming) deployed on NodePort 30300 in llm-app namespace**

## Performance

- **Duration:** 7 min
- **Started:** 2026-04-23T09:20:36Z
- **Completed:** 2026-04-23T09:27:00Z
- **Tasks:** 2
- **Files modified:** 13

## Accomplishments

- Complete Chainlit app with glass-box mode: 3 cl.Step wrappers expose each pipeline stage as collapsible panels in the UI, letting students inspect RAG context, prompt messages, and generation timing
- Token-by-token streaming from vLLM via httpx.AsyncClient stream + cl.Message.stream_token() with SSE parsing
- Smile Dental branding: dark theme, dental-blue/health-green CSS variables, welcome message with clinic name and pipeline hint
- K8s Deployment (llm-app namespace, readinessProbe, 250m/256Mi requests) + NodePort 30300 Service
- Starter skeleton with 15 TODO markers showing exactly where students implement each pipeline stage

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Chainlit app with glass-box Steps (solution/)** - `c4b810c` (feat)
2. **Task 2: K8s manifests + starter skeletons (solution/ + starter/)** - `130bf6c` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified

- `course-code/labs/lab-05/solution/ui/app.py` - Chainlit app with on_chat_start (welcome), on_message (3 Steps + streaming)
- `course-code/labs/lab-05/solution/ui/requirements.txt` - chainlit==2.11.0, httpx
- `course-code/labs/lab-05/solution/ui/Dockerfile` - python:3.11-slim, CMD with --host 0.0.0.0 --port 8000
- `course-code/labs/lab-05/solution/ui/.chainlit/config.toml` - Smile Dental Assistant, dark theme, cot=full
- `course-code/labs/lab-05/solution/ui/public/smile-dental.css` - Dental blue/green CSS variables, step border, header accent
- `course-code/labs/lab-05/solution/k8s/40-deploy-chainlit.yaml` - Deployment in llm-app, readinessProbe, RETRIEVER_URL + VLLM_URL envs
- `course-code/labs/lab-05/solution/k8s/40-svc-chainlit.yaml` - NodePort 30300 Service
- `course-code/labs/lab-05/starter/ui/app.py` - Skeleton with 15 TODOs at every implementation point
- `course-code/labs/lab-05/starter/ui/requirements.txt` - Identical to solution
- `course-code/labs/lab-05/starter/ui/Dockerfile` - Identical to solution
- `course-code/labs/lab-05/starter/ui/.chainlit/config.toml` - Identical to solution
- `course-code/labs/lab-05/starter/k8s/40-deploy-chainlit.yaml` - Identical to solution
- `course-code/labs/lab-05/starter/k8s/40-svc-chainlit.yaml` - Identical to solution

## Decisions Made

- Streaming response message (`cl.Message`) created before entering the Step 3 context manager — this ensures tokens appear in the main chat thread rather than inside the step's hidden output area
- `parse_sse()` returns `None` (not `""`) for non-content lines; calling code checks `if token:` before streaming to avoid empty stream_token calls
- `--host 0.0.0.0` in Dockerfile CMD is a hard requirement (Pitfall 5) — without it, the NodePort WebSocket handshake returns 403

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. Students build and push the Docker image to kind-registry:5001 as part of the lab procedure.

## Next Phase Readiness

- Lab 05 is ready: solution/ and starter/ complete with all required files
- Lab 06 (observability) can scrape the chainlit-ui pod in llm-app namespace — no changes needed to Lab 05 for that
- Students access the UI at http://localhost:30300 after `kubectl apply -f k8s/` in llm-app namespace

---
*Phase: 02-llmops-labs-day-1*
*Completed: 2026-04-23*
