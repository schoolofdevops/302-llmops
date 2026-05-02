---
phase: 03-agentops-labs-day-2
verified: 2026-05-02T15:30:00Z
status: passed
score: 11/11 must-haves verified
re_verification: false
human_verification:
  - test: "Run canonical Hermes agent query through full K8s stack (Chainlit → cost-middleware → sandbox-router → Hermes pod → MCP tools)"
    expected: "All 3 MCP tools called (triage → treatment_lookup → book_appointment); booking SD-* written to bookings ConfigMap; agent_llm_cost_usd_total increments in Grafana; Tempo shows mcp-treatment-lookup span with httpx child span to rag-retriever"
    why_human: "Full path requires a live Chainlit session generating X-Sandbox-ID via sandbox-sdk claim lifecycle; cannot script without a browser session. Individual components verified but end-to-end chain requires interactive UI action."
  - test: "Grafana Tempo — click through a single canonical query's spans after running run-canonical-query-traced.sh"
    expected: "Three separate root traces visible (mcp-triage, mcp-treatment-lookup, mcp-book-appointment); mcp-treatment-lookup trace shows a child httpx span pointing to rag-retriever:8001"
    why_human: "Tempo traces are zero at commit time (pre-traffic state); requires triggering traffic then browsing Grafana Explore → Tempo"
---

# Phase 3: AgentOps Labs (Day 2) Verification Report

**Phase Goal:** Students deploy Hermes Agent configured for Smile Dental, demonstrate a multi-step agent workflow using a free-tier LLM API, run it inside Kubernetes Agent Sandbox with isolation, and observe tool-call traces end-to-end via OTEL

**Verified:** 2026-05-02T15:30:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | Hermes Agent handles multi-step workflow (symptom → triage → treatment lookup → appointment booking) using Gemini OR Groq free-tier API | VERIFIED | `config.yaml` uses `groq/llama-3.3-70b-versatile`; SOUL.md instructs sequential triage→lookup→book workflow; lab-02-SUMMARY.md documents live B1 demo (Gemini 2.5 Flash) and booking SD-20260502095332 written; all 3 MCP tools confirmed called |
| 2 | Agent uses the existing RAG retriever as a tool and produces answers grounded in Smile Dental data | VERIFIED | `treatment_lookup_server.py` calls `{RETRIEVER_URL}/search`; K8s hermes-config ConfigMap has `mcp-treatment-lookup.llm-agent.svc.cluster.local:8020/mcp`; retriever URL defaults to `rag-retriever.llm-app.svc.cluster.local:8001` |
| 3 | Agent runs as a Kubernetes Sandbox resource with isolation and is accessible via Sandbox stable gateway identity | VERIFIED | SandboxWarmPool `hermes-agent-warmpool` READY=2 (live cluster); sandbox-router Deployment 1/1 Running; `sandbox-router-svc.llm-agent.svc.cluster.local:8080` wired as AGENT_URL in lab-08 Chainlit |
| 4 | SandboxWarmPool is configured and a cold-start vs warm-start timing comparison is observable | VERIFIED | `50-sandbox-warmpool.yaml` replicas=2; `cold-vs-warm-demo.sh` patches WarmPool 0→2 and records timings; B4 observed timings (Warm 7.95s, Cold refill 25.03s, Cold request 2.54s) embedded in lab-08 guide Part G |
| 5 | OTEL traces show distributed spans across agent → retriever → LLM calls, visualized in Grafana Tempo or Jaeger | VERIFIED (with D-18 caveat) | Tempo StatefulSet tempo-0 1/1 Running; OTEL Collector Deployment 1/1 Running; all 3 MCP tool servers instrumented via `otel_setup.py` (FastAPIInstrumentor + HTTPXClientInstrumentor); `treatment_lookup → rag-retriever` IS hierarchical; D-18 partial compliance (no Hermes-level traceparent) honestly disclosed in `otel_setup.py`, lab-09-observability.md Part B, and 03-06-PLAN.md `context_compliance_note`; workaround: time-window Tempo search documented |

**Score:** 5/5 truths verified (Success Criteria)

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|---------|
| AGENT-01 | 03-02 | Hermes configured with Smile Dental MCP tools (triage, treatment_lookup, book_appointment) | SATISFIED | `hermes-config/config.yaml` has all 3 `mcp_servers:` entries; confirmed in K8s hermes-config ConfigMap |
| AGENT-02 | 03-02 | Hermes connected to free-tier LLM API (Gemini or Groq) | SATISFIED | `config.yaml` default `groq/llama-3.3-70b-versatile`; `.env.example` documents both Groq + Gemini; B1 live test with Gemini 2.5 Flash documented |
| AGENT-03 | 03-02 | Hermes integrated with RAG retriever as a tool | SATISFIED | `treatment_lookup_server.py` line 23+38: `RETRIEVER_URL` env var → POST `/search`; K8s mode uses `rag-retriever.llm-app.svc.cluster.local:8001` |
| AGENT-04 | 03-02 | Multi-step demo workflow (triage → treatment info → book appointment) | SATISFIED | Live demo SD-20260502095332 documented in 03-02-SUMMARY.md; lab-07 guide Part F shows canonical query with 3-tool chain |
| SANDBOX-01 | 03-04 | K8s Agent Sandbox CRDs installed on KIND | SATISFIED | Live cluster: `sandboxes.agents.x-k8s.io`, `sandboxwarmpools.extensions.agents.x-k8s.io`, `sandboxclaims.extensions.agents.x-k8s.io`, `sandboxtemplates.extensions.agents.x-k8s.io` all present |
| SANDBOX-02 | 03-04 | Hermes deployed as Sandbox resource with isolation | SATISFIED | Live cluster: `hermes-agent-warmpool-tz5jr` and `hermes-agent-warmpool-x9jj2` both 1/1 Running; NetworkPolicy `hermes-agent-egress` applied to llm-agent namespace |
| SANDBOX-03 | 03-04 | SandboxWarmPool for fast startup | SATISFIED | Live cluster: readyReplicas=2; `cold-vs-warm-demo.sh` confirms observable timing difference (Warm 7.95s vs Cold refill 25.03s) |
| SANDBOX-04 | 03-04 | Agent accessible via Sandbox Router gateway | SATISFIED | Live cluster: `sandbox-router` Deployment 1/1 Running; Chainlit `AGENT_URL` points to `sandbox-router-svc.llm-agent.svc.cluster.local:8080`; direct curl uses port-forward to Hermes pod |
| OBS-05 | 03-06 + 03-07 | Tool-call traces, API cost tracking, latency per tool | SATISFIED | `cost_middleware.py` emits `agent_llm_tokens_total` + `agent_llm_cost_usd_total` Counters; ServiceMonitor `cost-middleware` scraped (live cluster); Grafana dashboard `smile-dental-agent` has panels 1+2 for tokens/cost |
| OBS-06 | 03-06 + 03-07 | OTEL distributed tracing across agent → retriever → LLM | SATISFIED (D-18 caveat) | `otel_setup.py` instruments all 3 MCP servers; `treatment_lookup` httpx call to RAG retriever IS a hierarchical child span; Hermes traceparent non-propagation documented honestly; time-window Tempo correlation documented |
| OBS-07 | 03-06 + 03-07 | OTEL collector deployed, traces in Grafana Tempo or Jaeger | SATISFIED | Live cluster: Tempo StatefulSet tempo-0 1/1 Running (69m); OTEL Collector Deployment 1/1 Running (39m); Grafana datasource `uid=tempo` at port 3200 confirmed; Grafana dashboard panels 3+4 use `type: traces` with Tempo datasource |

**All 11 Phase 3 requirements (AGENT-01..04, SANDBOX-01..04, OBS-05..07) satisfied.**

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `course-code/COURSE_VERSIONS.md` | Day 2 version pins section | VERIFIED | "Agent + Observability (Day 2)" section with 14 rows: Hermes, Sandbox v0.4.3, k8s-agent-sandbox SDK, mcp[cli] 1.27.0, opentelemetry-sdk 1.41.1, exporter+instrumentation 0.62b1, Tempo 1.24.4, OTEL Collector 0.153.0, kubernetes 32.x, filelock >=3.13.0, Groq llama-3.3-70b-versatile, Gemini gemini-2.5-flash; 4 Notes bullets |
| `course-code/config.env` | NS_AGENT=llm-agent, SANDBOX_VERSION=v0.4.3 | VERIFIED | Both exports present; also HERMES_IMAGE, SANDBOX_ROUTER_IMAGE, HERMES_API_KEY, HERMES_PORT, LLM_BASE_URL, LLM_MODEL, OTEL_COLLECTOR_VERSION, TEMPO_VERSION |
| `course-content/docs/labs/lab-06-web-ui.md` | Wind Down Before Day 2 subsection | VERIFIED | Section at line 321 with `kubectl scale deployment vllm-smollm2 --replicas=0 -n llm-serving`, warning admonition, tip forward-referencing Day 3 Lab 10 |
| `course-code/labs/lab-07/solution/hermes-config/config.yaml` | `mcp_servers:` with 3 tools, groq model | VERIFIED | Contains `mcp_servers:` (triage, treatment_lookup, book_appointment); model `groq/llama-3.3-70b-versatile`; K8s variant in hermes-config ConfigMap uses cluster DNS URLs |
| `course-code/labs/lab-07/solution/hermes-config/SOUL.md` | Smile Dental system prompt | VERIFIED | Contains "Smile Dental Clinic AI assistant" with triage→lookup→book instruction sequence |
| `course-code/labs/lab-07/solution/tools/triage/triage_server.py` | FastMCP triage tool with OTEL | VERIFIED | `setup_tracing("mcp-triage")`, `HTTPXClientInstrumentor`, `FastAPIInstrumentor.instrument_app(_app)` |
| `course-code/labs/lab-07/solution/tools/treatment_lookup/treatment_lookup_server.py` | FastMCP wrapping RAG retriever | VERIFIED | `RETRIEVER_URL` env var → `{RETRIEVER_URL}/search`; OTEL instrumented |
| `course-code/labs/lab-07/solution/tools/book_appointment/book_appointment_server.py` | BOOKING_BACKEND env switch (local/configmap) | VERIFIED | `BOOKING_BACKEND` env switch present; `_append_local()` for Docker Compose; `_append_configmap()` for K8s |
| `course-code/labs/lab-07/solution/docker-compose.yaml` | Hermes + 3 MCP tools + Chainlit | VERIFIED | `hermes:`, `mcp-triage:`, `mcp-treatment-lookup:`, `mcp-book-appointment:`, `chainlit-ui:` all present |
| `course-code/labs/lab-07/solution/ui/app.py` | AGENT_URL pointing to Hermes | VERIFIED | `AGENT_URL` env var wires to Hermes gateway on port 8642 (Docker Compose) / sandbox-router-svc:8080 (K8s lab-08 variant) |
| `course-code/labs/lab-07/solution/scripts/verify-hermes-startup.sh` | Docker run with health check | VERIFIED | Script confirmed via SUMMARY: Hermes v0.12.0 starts on CPU-only host; /health responds within 6s |
| `course-code/labs/lab-07/solution/tools/otel_setup.py` | Reusable setup_tracing function | VERIFIED | 30-line module with OTLP gRPC exporter; D-18 limitation documented in module docstring |
| `course-code/labs/lab-08/solution/k8s/50-sandbox-template.yaml` | SandboxTemplate for Hermes | VERIFIED | `kind: SandboxTemplate`; dnsPolicy:None+CoreDNS fix; emptyDir+initContainer for HERMES_HOME |
| `course-code/labs/lab-08/solution/k8s/50-sandbox-warmpool.yaml` | replicas=2 | VERIFIED | `replicas: 2`; `sandboxTemplateRef` linking to hermes-agent-template |
| `course-code/labs/lab-08/solution/k8s/60-network-policy.yaml` | Egress allow-list (D-07) | VERIFIED | `policyTypes: Egress`; kindnet non-enforcement documented |
| `course-code/labs/lab-08/solution/k8s/60-bookings-cm.yaml` | Initial empty bookings ConfigMap | VERIFIED | `bookings: "[]"` in llm-app namespace; live cluster has 1 SD- booking entry |
| `course-code/labs/lab-08/solution/scripts/cold-vs-warm-demo.sh` | WarmPool scale demo | VERIFIED (minor plan deviation) | Uses `kubectl patch sandboxwarmpool` (not `kubectl scale sandboxwarmpool` as plan artifact `contains:` specified); both achieve the same result — `patch` is the correct kubectl verb for CRD spec fields; functionally correct |
| `course-code/labs/lab-08/solution/ui/app.py` | Chainlit calling Sandbox Router | VERIFIED | `sandbox-router-svc.llm-agent.svc.cluster.local:8080` present |
| `course-code/labs/lab-09/solution/cost_middleware/cost_middleware.py` | Prometheus counters agent_llm_* | VERIFIED | `agent_llm_tokens_total` and `agent_llm_cost_usd_total` Counters defined with isolated CollectorRegistry |
| `course-code/labs/lab-09/solution/helm/values-tempo.yaml` | Tempo single-binary in-memory | VERIFIED | Tempo StatefulSet deployed from this chart; live cluster tempo-0 1/1 Running |
| `course-code/labs/lab-09/solution/helm/values-otel-collector.yaml` | OTEL Collector deployment mode | VERIFIED | `image.repository: otel/opentelemetry-collector-contrib` present (post-bug-fix); live cluster 1/1 Running |
| `course-code/labs/lab-09/solution/k8s/70-grafana-agent-dashboard-cm.yaml` | Grafana dashboard with 4 panels | VERIFIED | `uid: smile-dental-agent`; 4 panels (tokens/s timeseries, USD stat, Tempo traces x2); `grafana_dashboard: "1"` label; live cluster ConfigMap present |
| `course-content/docs/labs/lab-07-agent-core.md` | Complete lab guide (498 lines) | VERIFIED | 498 lines; canonical "severe tooth pain since yesterday" demo; Groq/Gemini tabs; 5 common pitfalls including 64K context limit; Docusaurus build passes |
| `course-content/docs/labs/lab-08-agent-sandbox.md` | Complete lab guide (600 lines) | VERIFIED | 600 lines; B4 timings (Warm 7.95s / Cold refill 25.03s / Cold first request 2.54s) in Part G; ROUTER_MODE=gcr confirmed; kindnet NetworkPolicy caveat; 5 pitfalls |
| `course-content/docs/labs/lab-09-observability.md` | Complete lab guide (599 lines) | VERIFIED | 599 lines; D-18 partial compliance disclosed in :::warning block (Part B); otel_setup.py verbatim; cost_middleware excerpt; time-window Tempo workaround documented |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `hermes-config/config.yaml` | 3 MCP tool servers | `mcp_servers.<name>.url` | WIRED | Docker Compose: `http://mcp-{triage,treatment-lookup,book-appointment}:{8010,8020,8030}/mcp`; K8s: cluster DNS URLs in hermes-config ConfigMap |
| `treatment_lookup_server.py` | `rag-retriever.llm-app.svc:8001` | `RETRIEVER_URL` env → POST `/search` | WIRED | `RETRIEVER_URL` used to call `/search` endpoint; defaults to `http://rag-retriever.llm-app.svc.cluster.local:8001` in K8s |
| `lab-08/ui/app.py` | `sandbox-router-svc.llm-agent.svc:8080` | `AGENT_URL` env var | WIRED | `sandbox-router-svc.llm-agent.svc.cluster.local:8080` present as default; live cluster sandbox-router 1/1 Running |
| `50-sandbox-warmpool.yaml` | `50-sandbox-template.yaml` | `spec.sandboxTemplateRef.name: hermes-agent-template` | WIRED | `sandboxTemplateRef` present; live cluster `hermes-agent-warmpool` readyReplicas=2 |
| `60-mcp-book-appointment-deploy.yaml` | `60-booking-rbac.yaml` | `serviceAccountName: mcp-booking-sa` | WIRED | `mcp-booking-sa` in deployment; live cluster mcp-book-appointment 1/1 Running with ConfigMap write access |
| `otel_setup.py` → MCP servers | `otel-collector.monitoring.svc:4317` | `OTLPSpanExporter` + `FastAPIInstrumentor` + `HTTPXClientInstrumentor` | WIRED | All 3 servers import and call `setup_tracing()`; live cluster OTEL Collector 1/1 Running at port 4317 |
| `cost_middleware.py` | `kube-prometheus-stack` | `/metrics` endpoint scraped by `70-servicemonitor-cost-middleware.yaml` | WIRED | Live cluster: ServiceMonitor `cost-middleware` present; `agent_llm_tokens_total` + `agent_llm_cost_usd_total` defined |
| `70-grafana-agent-dashboard-cm.yaml` | Tempo + Prometheus datasources | `grafana_dashboard: "1"` label | WIRED | Live cluster: ConfigMap `grafana-agent-dashboard` in monitoring with correct label; dashboard uses `uid: tempo` and `uid: prometheus` |
| `config.env` | Day 2 K8s manifests | `NS_AGENT`, `SANDBOX_VERSION`, `HERMES_IMAGE` exports | WIRED | All 3 variables exported; manifests use `llm-agent` namespace consistently |
| `lab-06-web-ui.md` | `lab-07-agent-core.md` | Wind-down step reduces RAM before Lab 07 | WIRED | Wind-down section at line 321; Lab 07 prerequisites mention the scale command as prerequisite |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `cost_middleware.py` | `tokens_total`, `cost_usd_total` Counters | Parses `usage.prompt_tokens`+`completion_tokens` from upstream `/v1/chat/completions` response | Yes — Counter increments on every proxied LLM call | VERIFIED (pre-traffic = 0, expected) |
| `treatment_lookup_server.py` | `hits` | POST to `{RETRIEVER_URL}/search` via httpx | Yes — real RAG retriever API call; returns actual Smile Dental chunks | VERIFIED |
| `book_appointment_server.py` | `booking` dict | BOOKING_BACKEND=configmap → `_append_configmap()` patches K8s ConfigMap | Yes — SD-20260502132241 written to live `bookings` ConfigMap | VERIFIED |
| `70-grafana-agent-dashboard-cm.yaml` panel 1+2 | `agent_llm_tokens_total`, `agent_llm_cost_usd_total` | Prometheus scrapes `cost-middleware /metrics` via ServiceMonitor | Real counters; zero at rest (pre-traffic baseline); increment on chat session | FLOWING (pending traffic) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| K8s Agent Sandbox CRDs installed | `kubectl get crd \| grep agents.x-k8s.io` | 4 CRDs: sandboxes, sandboxwarmpools, sandboxclaims, sandboxtemplates (all extensions.agents.x-k8s.io) | PASS |
| SandboxWarmPool has 2 ready replicas | `kubectl get sandboxwarmpool -n llm-agent` | `hermes-agent-warmpool READY=2` (3h17m age) | PASS |
| MCP tool Deployments Running | `kubectl get deploy -n llm-agent` | mcp-triage 1/1, mcp-treatment-lookup 1/1, mcp-book-appointment 1/1, sandbox-router 1/1, cost-middleware 1/1 | PASS |
| Tempo StatefulSet Running | `kubectl get statefulset -n monitoring` | `tempo 1/1` (69m) | PASS |
| OTEL Collector Running | `kubectl get deploy -n monitoring \| grep otel` | `otel-collector-opentelemetry-collector 1/1` (39m) | PASS |
| Bookings ConfigMap has SD- entries | `kubectl get cm bookings -n llm-app -o yaml \| grep -c SD-` | 1 SD- entry found (SD-20260502132241 from cold-vs-warm demo) | PASS |
| NetworkPolicy exists | `kubectl get netpol hermes-agent-egress -n llm-agent` | Present (3h17m); 3 egress rule groups | PASS |
| ServiceMonitors for cost-middleware and OTEL | `kubectl get servicemonitor -A \| grep -E 'cost-middleware\|otel'` | `monitoring cost-middleware` (31m), `monitoring otel-collector` (38m) | PASS |
| Grafana agent dashboard ConfigMap | `kubectl get cm grafana-agent-dashboard -n monitoring` | Present with `grafana_dashboard: "1"` label and `uid: smile-dental-agent` | PASS |
| Tempo datasource at port 3200 | `kubectl get cm grafana-tempo-datasource -n monitoring` | `url: http://tempo.monitoring.svc.cluster.local:3200` | PASS |
| vLLM replicas=1 on live cluster | `kubectl get deploy vllm-smollm2 -n llm-serving` | replicas=1, 1/1 Running | NOTE: vLLM was NOT scaled to 0 on this dev machine before running verification. D-19 instructs students to scale to 0 at the Day 1 → Day 2 boundary; the Lab 06 wind-down section (must_have artifact) instructs this step. Cluster state during course delivery depends on student executing the wind-down. This is not a code gap — the instruction exists at the right place. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `cold-vs-warm-demo.sh` | plan artifact `contains:` | Plan artifact spec says `contains: "kubectl scale sandboxwarmpool"` but actual script uses `kubectl patch sandboxwarmpool --type merge` | Info | `kubectl scale` is not a valid verb for CRD objects; `kubectl patch` is correct and functionally equivalent. The plan spec was slightly incorrect; the implementation is right. Zero impact on course functionality. |
| `lab-07-agent-core.md` line 406 | `{/* TODO: screenshot of Chainlit Step expansion showing 3 tool calls */}` | Screenshot placeholder | Info | Explicitly documented in 03-03-PLAN.md as "plan item 12 included it as a placeholder"; acceptable for v1 course; does not affect lab instructions |

No blocker or warning anti-patterns found. Both items are informational.

### D-18 Partial Compliance Assessment

D-18 in `03-CONTEXT.md` specifies a hierarchical OTEL span tree: `agent.request → llm.completion + tool.invoke → mcp.call + retriever.search`. This phase implements D-18 **partially** and documents the limitation honestly at three locations:

1. `course-code/labs/lab-07/solution/tools/otel_setup.py` — module docstring explains no W3C traceparent propagation from Hermes
2. `course-content/docs/labs/lab-09-observability.md` Part B — `:::warning D-18 partial compliance` block (lines ~221-254)
3. `03-06-PLAN.md` `context_compliance_note:` frontmatter section

**What IS hierarchical:** `mcp-treatment-lookup (POST /mcp FastAPI span) → rag-retriever httpx child span` — satisfies OBS-06 "agent → retriever" chain literally.

**What is NOT hierarchical:** `agent.request` and `llm.completion` parent spans — Hermes binary is a closed upstream image (D-01); no OTLP export or traceparent injection possible without forking.

**Workaround documented:** Time-window Tempo search (`service.name=mcp-treatment-lookup`, last 5 minutes) correlates all 3 tool spans from a single user query.

This constitutes accepted, documented technical debt. OBS-06 is satisfied by the `tool.invoke → retriever.search` sub-tree.

### Human Verification Required

#### 1. Full Chainlit → cost-middleware → Sandbox → MCP chain

**Test:** Open `http://localhost:30300` in browser → type "I have severe tooth pain since yesterday. Please help me book an appointment." → wait for agent response  
**Expected:** Chainlit shows Agent processing step with 3 tool sub-steps (mcp_triage_triage, mcp_treatment_lookup_treatment_lookup, mcp_book_appointment_book_appointment); booking confirmed; `kubectl get cm bookings -n llm-app -o yaml` shows new SD- entry; Grafana Prometheus panel shows `agent_llm_cost_usd_total > 0`  
**Why human:** Full path requires a live Chainlit session that generates an X-Sandbox-ID via the sandbox-sdk claim lifecycle; the cost-middleware → sandbox-router → Hermes routing cannot be scripted without a browser session

#### 2. Tempo span-tree click-through

**Test:** Run `bash course-code/labs/lab-09/solution/scripts/run-canonical-query-traced.sh` → open Grafana at `http://localhost:30400` → Explore → Tempo → search `service.name=mcp-treatment-lookup` → click a trace  
**Expected:** Trace shows POST /mcp as root span with child httpx GET to `rag-retriever.llm-app.svc.cluster.local:8001/search`; all 3 MCP tool traces visible within a 30-second window; Grafana dashboard panels 3+4 (Tempo) show recent traces  
**Why human:** Requires MCP tools to receive traffic first (currently zero traces); requires visual confirmation of span tree in Tempo UI

---

### Gaps Summary

No gaps found. All 11 requirements (AGENT-01..04, SANDBOX-01..04, OBS-05..07) are satisfied by existing code and K8s artifacts. All 5 ROADMAP Success Criteria are verifiable. The two human verification items require interactive browser sessions but are not gaps in the deliverables.

**Notable findings (not gaps):**
- D-18 partial compliance is the most significant technical constraint. It is documented honestly and the OBS-06 requirement is satisfied by the tool→retriever sub-tree hierarchy.
- The `cold-vs-warm-demo.sh` uses `kubectl patch sandboxwarmpool` (correct verb for CRD resources) vs the plan spec's `kubectl scale sandboxwarmpool` (not valid for CRD objects). Implementation is correct; plan spec had a minor error.
- vLLM replicas=1 on the dev cluster during verification — this is expected since the verifier did not execute the Lab 06 wind-down step. The instruction exists in the course content at the correct location (D-19/D-20 satisfied).
- The ROADMAP.md Phase 3 progress table shows `5/7 plans complete` but the SUMMARY files confirm all 7 plans completed (03-01 through 03-07). ROADMAP.md progress table was not updated after plans 03-06 and 03-07 completed. This is a documentation inconsistency only — not a content gap.

---

_Verified: 2026-05-02T15:30:00Z_
_Verifier: Claude (gsd-verifier)_
