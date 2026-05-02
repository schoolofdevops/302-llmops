---
phase: 03-agentops-labs-day-2
plan: "07"
subsystem: lab-content
tags: [lab-09, docusaurus, otel, tempo, cost-middleware, grafana, mcp-observability, d18-disclosure]
dependency_graph:
  requires: [03-06]
  provides: [lab-09-observability-page]
  affects: []
tech_stack:
  added: []
  patterns:
    - "Hermes D-18 partial compliance disclosure pattern (B5): closed-binary caveat + time-window Tempo workaround"
    - "Embed live numeric evidence (agent_llm_cost_usd_total) from prior plan SUMMARY"
    - "MDX-safe admonitions (:::warning / :::tip / :::info) for student-facing caveats"
key_files:
  created: []
  modified:
    - course-content/docs/labs/lab-09-observability.md
decisions:
  - "agent_llm_cost_usd_total embedded as 0.000613 USD — pre-traffic value from 03-06 SUMMARY; note added that this ticks up on first Chainlit chat"
  - "Dashboard panel-type fallback NOT needed — panels 3+4 use type=traces (confirmed working in Grafana 10.x per 03-06); lab notes Explore path as backup"
  - "otel_setup.py shown verbatim; cost_middleware.py shown as condensed excerpt (full file is 85 lines; verbatim would push page over 600-line cap)"
metrics:
  duration: "~12 minutes"
  completed: "2026-05-02T14:33:00Z"
  tasks: 1
  files: 1
---

# Phase 03 Plan 07: Lab 09 Observability Page Summary

**One-liner:** 599-line Lab 09 Docusaurus walkthrough covering Tempo + OTEL Collector install, MCP tool OTEL instrumentation (with honest D-18/Hermes traceparent limitation), cost middleware deployment, Grafana dashboard auto-discovery, and Tempo span-tree click-through closing OBS-06.

## Objective Achieved

`course-content/docs/labs/lab-09-observability.md` replaced. Was 25-line placeholder, now 599-line complete walkthrough:
- Part A: Helm install of Tempo 1.24.4 + OTEL Collector 0.153.0 via `install-otel-tempo.sh`
- Part B: MCP tool OTEL instrumentation explained (otel_setup.py verbatim, triage_server.py diff) with D-18 partial compliance warning block
- Part C: Cost middleware deployment + price ConfigMap + Chainlit overlay via `40-chainlit-deploy-lab09.yaml`
- Part D: Grafana dashboard auto-discovery via `grafana_dashboard: "1"` ConfigMap label; panel walk-through
- Part E: `run-canonical-query-traced.sh` + Chainlit query + Tempo click-through; observed cost 0.000613 USD embedded

## Final File Metrics

| Attribute | Value |
|-----------|-------|
| Line count | 599 |
| Line count range | 300-600 (PASS) |
| Docusaurus build | green (`npm run build` exits 0) |
| Frontmatter sidebar_position | 10 |
| Header Day label | Day 2 (was "Day 3" in placeholder) |

## Live Evidence from 03-06 SUMMARY Embedded

- `agent_llm_cost_usd_total` = 0.000613 USD — embedded verbatim from 03-06 SUMMARY "Observed Metrics" table
- Note added: value is pre-traffic baseline; metric ticks up on first Chainlit chat

## Dashboard Panel-Type Fallback Status

NOT needed. Panels 3+4 use `type: traces` (Grafana 10.x with Tempo datasource). The 03-06 SUMMARY confirms panels 3+4 use `type=traces` and are working. The lab page includes an :::info admonition pointing students to Grafana → Explore → Tempo as a fallback.

## B5 D-18 Partial Compliance Disclosure

The page contains (verified):
- String `D-18` — references the CONTEXT.md decision
- `closed binary` — explains why agent.request/llm.completion spans are absent
- `OUT OF SCOPE for v1` — documents that reconsidering D-01 is deferred
- `traceparent` — explains the MCP context propagation limitation
- Time-window search workaround in both the :::warning block (Part B) and Common Pitfalls

## Phase 3 Closure — Requirements Closed by Phase

| Requirement | Description | Closed By Plan |
|-------------|-------------|----------------|
| AGENT-01 | Hermes configured with 3 MCP tools | 03-02 |
| AGENT-02 | Hermes connected to free-tier LLM (Groq/Gemini) | 03-02 |
| AGENT-03 | Hermes integrated with RAG retriever as tool | 03-02 |
| AGENT-04 | Multi-step demo workflow (triage → lookup → book) | 03-02 |
| SANDBOX-01 | K8s Agent Sandbox CRDs installed on KIND | 03-04 |
| SANDBOX-02 | Hermes deployed as Sandbox resource | 03-04 |
| SANDBOX-03 | SandboxWarmPool for fast startup | 03-04 |
| SANDBOX-04 | Agent accessible via Sandbox Router gateway | 03-04 |
| OBS-05 | Tool-call traces + API cost tracking + latency | 03-06 (infra) + 03-07 (docs) |
| OBS-06 | OTEL distributed tracing agent → retriever → LLM | 03-06 (infra) + 03-07 (docs) |
| OBS-07 | OTEL collector deployed, traces in Grafana Tempo | 03-06 (infra) + 03-07 (docs) |

All 11 Phase 3 requirements (AGENT-01..04, SANDBOX-01..04, OBS-05..07) are closed.

## Deviations from Plan

None — plan executed exactly as written. The page was written fresh from the required plan structure; no deviations were needed.

## Known Stubs

None. The page references real artifacts created in 03-06: real Helm charts, real K8s manifests, real scripts. The 0.000613 USD value is the real pre-traffic baseline, not a placeholder.

## Self-Check: PASSED

See below.
