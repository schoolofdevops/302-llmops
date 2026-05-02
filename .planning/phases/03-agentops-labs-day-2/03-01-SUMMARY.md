---
phase: 03-agentops-labs-day-2
plan: 01
subsystem: infra
tags: [course-versions, config, vllm, hermes-agent, kubernetes-agent-sandbox, mcp, otel, tempo, groq, gemini, filelock]

# Dependency graph
requires:
  - phase: 02-llmops-labs-day-1
    provides: "Lab 06 web UI page, config.env namespace vars, COURSE_VERSIONS.md Day 1 pins"
provides:
  - "COURSE_VERSIONS.md Agent + Observability (Day 2) section with 14 pinned versions"
  - "config.env Day 2 vars: NS_AGENT, SANDBOX_VERSION, HERMES_IMAGE, LLM_BASE_URL, LLM_MODEL, OTEL/Tempo versions"
  - "Lab 06 Wind Down Before Day 2 subsection with vLLM scale-to-0 command"
affects: [03-02, 03-03, 03-04, 03-05, 03-06, 03-07, lab-07-agent-core, lab-08-agent-sandbox, lab-09-observability]

# Tech tracking
tech-stack:
  added:
    - "nousresearch/hermes-agent:latest (Hermes Agent container image)"
    - "k8s-agent-sandbox 0.4.3 Python SDK"
    - "mcp[cli] 1.27.0 (FastMCP streamable HTTP)"
    - "opentelemetry-sdk 1.41.1"
    - "opentelemetry-exporter-otlp-proto-grpc 1.41.1"
    - "opentelemetry-instrumentation-httpx 0.62b1"
    - "opentelemetry-instrumentation-fastapi 0.62b1"
    - "Grafana Tempo Helm chart 1.24.4"
    - "OpenTelemetry Collector Helm chart 0.153.0"
    - "kubernetes Python client 32.x"
    - "filelock >=3.13.0 (Windows-compatible file lock)"
    - "Groq llama-3.3-70b-versatile (128K context, free tier)"
    - "Gemini gemini-2.5-flash (1M context, free tier)"
    - "Kubernetes Agent Sandbox CRDs v0.4.3"
  patterns:
    - "config.env as single source of truth for all namespace and version env vars"
    - "COURSE_VERSIONS.md grouped by day (Day 1 / Day 2) for workshop clarity"
    - "vLLM scale-to-0 at day boundary (manifest preserved for Day 3 autoscaling)"

key-files:
  created: []
  modified:
    - course-code/COURSE_VERSIONS.md
    - course-code/config.env
    - course-content/docs/labs/lab-06-web-ui.md

key-decisions:
  - "filelock >=3.13.0 added as W4 Windows-compatibility pin alongside other Day 2 versions"
  - "Groq llama-3.3-70b-versatile is primary LLM_MODEL default in config.env (128K context satisfies Hermes 64K minimum)"
  - "kindnet NetworkPolicy limitation documented explicitly in COURSE_VERSIONS.md Notes"
  - "Wind-down section uses kubectl scale deployment (not deploy short form) for explicitness"

patterns-established:
  - "Day boundary wind-down pattern: scale resource to 0, verify termination, confirm manifest preserved"
  - "config.env commented-out API key placeholders pattern for student-provided secrets"

requirements-completed: []

# Metrics
duration: 10min
completed: 2026-05-02
---

# Phase 3 Plan 01: Day 2 Foundations Summary

**Day 2 version pins (Hermes, Sandbox v0.4.3, MCP 1.27.0, OTEL 1.41.1, Tempo 1.24.4) landed in COURSE_VERSIONS.md and config.env, with Lab 06 wind-down subsection freeing ~2-4 GB before Lab 07**

## Performance

- **Duration:** 10 min
- **Started:** 2026-05-02T08:25:19Z
- **Completed:** 2026-05-02T08:35:00Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Added "Agent + Observability (Day 2)" section to COURSE_VERSIONS.md with 14 pinned versions covering all Phase 3 components (Hermes image, Sandbox v0.4.3, MCP 1.27.0, OTEL SDK/exporter/instrumentation, Grafana Tempo chart 1.24.4, OTel Collector chart 0.153.0, kubernetes Python client, filelock W4 pin, Groq and Gemini model IDs) plus 4 Notes bullets
- Extended config.env with 10 new Day 2 variables (NS_AGENT, SANDBOX_VERSION, HERMES_IMAGE, SANDBOX_ROUTER_IMAGE, HERMES_API_KEY, HERMES_PORT, LLM_BASE_URL, LLM_MODEL, OTEL_COLLECTOR_VERSION, TEMPO_VERSION) and 2 commented API key placeholders; all Day 1 keys preserved
- Inserted "Wind Down Before Day 2" subsection into Lab 06 between Verification and After This Lab sections, including kubectl scale command, verification steps, Docusaurus warning admonition, and tip forward-referencing Day 3 Lab 10 autoscaling

## Task Commits

1. **Task 1: Update COURSE_VERSIONS.md with Day 2 pinned versions** - `d693426` (feat)
2. **Task 2: Extend config.env with Day 2 namespace and image variables** - `9a61f92` (feat)
3. **Task 3: Add Wind Down Before Day 2 subsection to Lab 06 page** - `a70783a` (feat)

## Files Created/Modified

- `course-code/COURSE_VERSIONS.md` - New "Agent + Observability (Day 2)" table section (14 rows) + 4 new Notes bullets; Last verified date updated
- `course-code/config.env` - 10 new Day 2 exports + 2 commented API key placeholders appended at end
- `course-content/docs/labs/lab-06-web-ui.md` - New subsection inserted at line 321 between Verification (line ~294) and After This Lab (line 346)

## Decisions Made

- **filelock >=3.13.0 pinned as W4 requirement:** The `book_appointment` MCP tool uses local-JSON mode in tests; `fcntl.flock` is Unix-only so Windows workshop attendees would fail pytest. filelock provides cross-platform file locking.
- **Groq as default LLM_MODEL in config.env:** RESEARCH.md Focus 7 recommends Groq as safer primary recommendation; Gemini is the alternative. LLM_BASE_URL defaults to Groq endpoint. Students switch to Gemini by changing two vars.
- **kubectl scale deployment (full form):** Wind-down section uses `kubectl scale deployment` not `kubectl scale deploy` for clarity to students who may not know the short form alias.
- **kindnet NetworkPolicy caveat explicitly noted:** Second critical research finding — kindnet does NOT enforce NetworkPolicy. This is documented in COURSE_VERSIONS.md Notes so Lab 08 planner has the constraint visible at a glance.

## Deviations from Plan

None - plan executed exactly as written. All 14 versions from RESEARCH.md Version Pin Table present. config.env additions match spec verbatim. Lab 06 wind-down section uses exact wording from plan task action.

## Issues Encountered

None. The `grep -q` commands used in verification required `/usr/bin/grep` direct path (RTK hook intercepts `grep` via rtk proxy). All verifications passed.

## User Setup Required

None - no external service configuration required. Students will need to set GROQ_API_KEY or GOOGLE_API_KEY in their shell when starting Lab 07 (not required for this plan).

## Next Phase Readiness

- Plans 03-02 through 03-07 can reference `course-code/config.env` for `NS_AGENT`, `SANDBOX_VERSION`, `HERMES_IMAGE` without defining them again
- COURSE_VERSIONS.md is the authoritative version reference for all Day 2 K8s manifests and requirements.txt files in downstream plans
- Lab 07 starter code can import `LLM_BASE_URL` and `LLM_MODEL` from config.env
- The vLLM Deployment manifest is preserved at scale=0; Phase 4 autoscaling plan can scale it back up without recreating the manifest

---
*Phase: 03-agentops-labs-day-2*
*Completed: 2026-05-02*
