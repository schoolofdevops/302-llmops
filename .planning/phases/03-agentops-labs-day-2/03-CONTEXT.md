# Phase 3: AgentOps Labs (Day 2) - Context

**Gathered:** 2026-05-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Day 2 labs (07, 08, 09) deliver a Hermes-powered multi-tool agent for Smile Dental Clinic, deployed on Kubernetes Agent Sandbox with isolation and warm-pool startup, observed end-to-end via OTEL traces in Grafana Tempo plus Prometheus-based API cost tracking.

Scope = labs 07 (agent core, Docker), 08 (K8s Agent Sandbox), 09 (agent observability + OTEL + Tempo + cost). Reuses Day 1 RAG retriever, Chainlit UI, Prometheus/Grafana stack. Switches LLM from local SmolLM2 to free-tier API (Groq or Gemini, student-toggle).

</domain>

<decisions>
## Implementation Decisions

### Agent Framework Integration
- **D-01:** Use upstream `hermes-agent` container image as-is. Students provide config + register tools — no fork, no rewrite. Aligns with locked decision "configure and deploy, don't build from scratch".
- **D-02:** Tools surfaced as **MCP servers** (3 separate processes: `triage`, `treatment_lookup`, `book_appointment`). Hermes connects via MCP protocol. Demonstrates the protocol students hear about; isolates each tool.
- **D-03:** Session memory = **stateless per-session**. No persistent memory backend. Each Chainlit session starts fresh agent context.

### LLM Provider
- **D-04:** Both **Groq** and **Gemini** supported side-by-side. Student sets `GROQ_API_KEY` OR `GEMINI_API_KEY`. Lab guides cover both setups. Both consumed via OpenAI-compatible base URL.

### K8s Agent Sandbox Topology
- **D-05:** Agent deployed as **per-session Sandbox** claimed from `SandboxWarmPool`. Each Chainlit session gets its own pre-warmed Sandbox instance. Demonstrates isolation per user + warm-pool benefit.
- **D-06:** `SandboxWarmPool` replicas=2. Lab 08 demos cold-vs-warm by scaling pool to 0, sending request (cold), then scaling back and repeating (warm). Satisfies success criterion #4.
- **D-07:** Sandbox networking = **NetworkPolicy egress allow-list**. Allow only: `rag-retriever.llm-app.svc` + `api.groq.com` + `generativelanguage.googleapis.com`. Default-deny everything else. Real isolation pattern.
- **D-08:** Gateway exposure = **Chainlit UI is the front door**. Chainlit (already on NodePort 30300) calls Sandbox via the Sandbox Gateway resource (cluster-internal). Students reach agent through familiar chat UI. SANDBOX-04 satisfied via gateway being the named ingress.

### Tool Implementations
- **D-09:** `triage` MCP tool = **LLM-prompted classifier**. Tool prompts the LLM with rubric (severe/urgent/routine) + symptom text, parses JSON severity. Costs 1 extra LLM call per triage; demos LLM-as-tool pattern.
- **D-10:** `treatment_lookup` MCP tool = **wraps existing RAG retriever**. Tool calls `rag-retriever.llm-app.svc.cluster.local:8001/search` with treatment name, returns top-k chunks. Reuses Day 1 work; satisfies AGENT-03 cleanly.
- **D-11:** `book_appointment` MCP tool = **ConfigMap-backed JSON**. Bookings persisted to a ConfigMap (`bookings` in `llm-app` namespace). Students can `kubectl get cm bookings -o yaml` to verify side effect. Zero external DB; persists across pod restarts; visible and K8s-native.

### Multi-Step Workflow Demo (AGENT-04)
- **D-12:** Canonical demo workflow = **symptom → triage → treatment_lookup → book_appointment**. Example query: "severe tooth pain since yesterday". Agent chains: `triage(severe)` → `treatment_lookup(emergency root canal)` → `book_appointment(soonest)`. Hits all 3 tools in one turn; matches success criterion #1 verbatim.

### Lab Boundaries (07/08/09)
- **D-13:** **Lab 07 = Agent core (Docker)**. Run Hermes container + 3 MCP tool containers via Docker Compose locally. Wire to Groq/Gemini, prove multi-step workflow end-to-end outside K8s. Closes AGENT-01..04.
- **D-14:** **Lab 08 = K8s Agent Sandbox**. Install Sandbox CRD on KIND cluster. Deploy agent as Sandbox + SandboxWarmPool + NetworkPolicy + Gateway. Wire Chainlit UI to call Sandbox via Gateway. Cold-vs-warm timing demo. Closes SANDBOX-01..04.
- **D-15:** **Lab 09 = Agent observability**. Deploy OTEL collector + Grafana Tempo (Helm). Instrument agent + MCP tools + retriever calls with OTEL spans. Add Prometheus cost-tracking middleware. Build Grafana dashboard showing token throughput, per-tool latency, USD cost, trace links. Closes OBS-05..07.

### Observability Implementation
- **D-16:** Trace backend = **Grafana Tempo**. Helm chart `grafana/tempo`. Reuses Day 1 Grafana for unified metrics + traces + logs view. Lighter than Jaeger for KIND footprint.
- **D-17:** Cost tracking = **Prometheus counters in agent middleware**. Emits `agent_llm_tokens_total{provider,model,direction=in|out}` and `agent_llm_cost_usd_total{provider,model}` (computed from a static price table mounted as ConfigMap). Surfaces in Grafana dashboard.
- **D-18:** OTEL span tree = **hierarchical**. `agent.request` (root) → `llm.completion` (per LLM call, with token/cost attrs) + `tool.invoke` (per tool, with `mcp.call` child for MCP transport) + `retriever.search` nested under `treatment_lookup` tool span. Satisfies OBS-06 "distributed tracing across agent → retriever → LLM" literally.

### Lean Cluster Between Day 1 and Day 2
- **D-19:** Day 2 stops using vLLM (cloud LLM via Groq/Gemini takes over). To keep KIND lean on 16GB laptops, **scale `vllm-smollm2` Deployment to `replicas=0`** at the Day 1 → Day 2 boundary. Manifest stays in place (Day 3 autoscaling labs scale it back up). Quick to bring back via `kubectl scale`. Estimated saving: ~2-4 GB RAM + sustained CPU.
- **D-20:** Wind-down step lives at **end of Lab 06 (Day 1 final lab)** in a new "Wind down before Day 2" subsection after Part B. Scales vLLM Deployment to 0; leaves RAG retriever, Chainlit UI, Prometheus, Grafana running (all reused by Day 2). Symmetric "scale back up" note appears at the start of Day 3 (Phase 4) when autoscaling labs need vLLM again. Risk note: students who jump directly to Lab 07 without doing Lab 06 wind-down will run with extra load — document this in Lab 07 prerequisites.

### Claude's Discretion
- Exact wording + commands for the Lab 06 wind-down section (`kubectl scale deploy vllm-smollm2 --replicas=0 -n llm-serving` + verification step)
- Symmetric "scale vLLM back up" prelude in Phase 4 / Day 3 first lab
- Container build / image registry strategy for the 3 MCP tool images (use existing kind-registry pattern from Day 1)
- Hermes container image source / tag (researcher confirms current upstream tag and CPU compatibility)
- Static USD price table values (use 2026 published Groq/Gemini free-tier rates; researcher fetches)
- Sandbox CRD version + warm-pool spec syntax (researcher fetches current K8s Agent Sandbox docs)
- MCP transport choice within K8s (stdio over sidecar vs. SSE/HTTP — researcher picks based on hermes-agent client support)
- Chainlit changes for Day 2 (replace direct vLLM call path with Sandbox Gateway call; keep glass-box steps; add tool-call step type)
- OTEL collector deploy mode (DaemonSet vs Deployment) — pick based on KIND footprint
- Tempo storage backend (in-memory for KIND — no S3/MinIO needed)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project / Course Specs
- `.planning/PROJECT.md` — Locked decisions (Hermes Agent, two-phase LLM, no LangGraph/CrewAI, Chainlit UI, FAISS over Qdrant, Smile Dental naming, CPU-only)
- `.planning/REQUIREMENTS.md` §AGENT-01..04, §SANDBOX-01..04, §OBS-05..07 — 11 requirements scoped to Phase 3
- `.planning/ROADMAP.md` §"Phase 3: AgentOps Labs (Day 2)" — Goal + 5 success criteria

### Day 1 Code Reused or Wrapped
- `course-code/labs/lab-01/solution/rag/retriever.py` — FastAPI retriever; `treatment_lookup` MCP tool wraps `/search` endpoint
- `course-code/labs/lab-01/solution/k8s/10-retriever-deployment.yaml` + `10-retriever-service.yaml` — Service is `rag-retriever.llm-app.svc.cluster.local:8001`
- `course-code/labs/lab-04/solution/k8s/30-deploy-vllm.yaml` + `30-svc-vllm.yaml` — Day 2 does NOT delete; D-19 scales replicas to 0 at Day 1→2 boundary so manifest survives for Day 3 autoscaling labs
- `course-code/labs/lab-05/solution/ui/app.py` — Chainlit UI; Day 2 modifies to call Sandbox Gateway in place of vLLM directly; preserves glass-box steps and adds tool-call step type
- `course-code/labs/lab-05/solution/k8s/40-deploy-chainlit.yaml` + `40-svc-chainlit.yaml` — Chainlit Deployment + NodePort 30300
- `course-code/labs/lab-06/solution/k8s/observability/*.yaml` — ServiceMonitors + Grafana dashboard ConfigMap; Day 2 extends with agent metrics + Tempo datasource
- `course-content/docs/labs/lab-06-web-ui.md` — Day 1 final lab; Day 2 work appends a "Wind down before Day 2" subsection after Part B
- `course-code/config.env` — Namespaces (`NS_APP=llm-app`, `NS_MONITORING=monitoring`); add `NS_AGENT=llm-agent` if needed
- `course-code/COURSE_VERSIONS.md` — Version pinning ledger; add Hermes image tag, K8s Sandbox CRD version, OTEL collector version, Tempo chart version

### Empty Day 2 Lab Slots (writers / artifact targets)
- `course-code/labs/lab-07/{starter,solution}/` — Empty; lab 07 artifacts land here
- `course-code/labs/lab-08/{starter,solution}/` — Empty; lab 08 artifacts land here
- `course-code/labs/lab-09/{starter,solution}/` — Empty; lab 09 artifacts land here
- `course-content/docs/labs/lab-07-agent-core.md` — 25-line placeholder; rewrite with full lab content
- `course-content/docs/labs/lab-08-agent-sandbox.md` — 25-line placeholder; rewrite
- `course-content/docs/labs/lab-09-observability.md` — 25-line placeholder; rewrite

### External Docs (researcher MUST fetch + cite)
- Hermes Agent repo (NousResearch/hermes-agent) — README, tool registration / MCP integration, container image tag, system prompt configuration. Researcher confirms current upstream API surface.
- Kubernetes Agent Sandbox (kubernetes-sigs/agent-sandbox) — Sandbox CRD spec, SandboxWarmPool spec, Gateway resource, NetworkPolicy patterns. Researcher fetches current `v0.x` API.
- Model Context Protocol (modelcontextprotocol.io) — MCP server spec, transport options (stdio, SSE, HTTP), Python SDK. Researcher picks transport that hermes-agent client supports.
- OpenTelemetry semantic conventions for GenAI (`gen_ai.*` attributes) — span naming, token attributes, cost attribute conventions
- Grafana Tempo Helm chart docs (`grafana/tempo`) — single-binary mode, in-memory storage, datasource wiring
- OpenTelemetry Collector Helm chart docs — minimal config for Tempo backend
- Groq Cloud free-tier docs + Gemini API free-tier docs — current free-tier limits, OpenAI-compatible base URL, model IDs

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **RAG retriever FastAPI service** — Already deployed at `rag-retriever.llm-app.svc.cluster.local:8001`. `treatment_lookup` MCP tool wraps `/search`. Zero new RAG work.
- **Chainlit UI with glass-box Steps** — Established `cl.Step` pattern (RAG → prompt → LLM). Day 2 adds tool-call step kind, swaps the LLM call for a Sandbox Gateway call. UI continuity reduces lab content load.
- **Prometheus + Grafana stack** — kube-prometheus-stack already running in `monitoring`. Day 2 adds ServiceMonitor for agent + Tempo datasource + new dashboard panels (no new stack).
- **kind-registry:5001 local registry** — Used by Day 1 for model image. Day 2 uses same registry for 3 MCP tool images + agent image (if customized).
- **`course-code/config.env`** — Centralized namespace + version env. Day 2 extends, doesn't replace.

### Established Patterns
- **Lab dir convention** — `course-code/labs/lab-NN/{starter,solution}/{k8s,…}`. Day 2 follows.
- **Numbered K8s manifest files** — `10-foo.yaml`, `30-bar.yaml`, `40-baz.yaml` (range = layer/concern). Day 2 picks ranges: 50-agent-sandbox, 60-mcp-tools, 70-otel.
- **Namespace per concern** — `llm-serving` (vLLM), `llm-app` (RAG, UI), `monitoring` (Prom/Graf). Day 2 adds `llm-agent` for Sandbox + MCP tool resources.
- **NodePort for student access** — 30300 (Chainlit), 30500 (Grafana). No Ingress controller assumed.
- **CPU-only constraint** — Hermes container, MCP tool containers, OTEL collector, Tempo all must run on CPU on a 16GB-laptop KIND cluster.
- **Inline Pydantic + FastAPI for service interfaces** — RAG retriever pattern. MCP tools follow same Python style if Python-implemented.

### Integration Points
- **Chainlit → Sandbox Gateway** — replaces existing Chainlit → vLLM direct call path
- **Sandbox (Hermes) → MCP tools** — via MCP protocol, configured by Hermes deployment manifest
- **`treatment_lookup` MCP tool → RAG retriever** — HTTP call to existing service
- **Hermes → Groq/Gemini** — via OpenAI-compatible base URL, API key from K8s Secret
- **Agent + tools → OTEL Collector → Tempo** — OTLP gRPC; collector exposes Prometheus exporter for agent metrics
- **Agent middleware → Prometheus** — `/metrics` scraped by existing kube-prometheus-stack via new ServiceMonitor

</code_context>

<specifics>
## Specific Ideas

- Canonical demo query for the workshop walkthrough: "severe tooth pain since yesterday" — chains all 3 tools.
- Cold-vs-warm Sandbox timing demo: scale `SandboxWarmPool` to 0 → send request → measure cold start → scale back to 2 → repeat → compare. Show timing in `kubectl describe sandbox` events or via OTEL span duration.
- Bookings ConfigMap as a "show students the side effect" moment: `kubectl get cm bookings -o yaml` after a successful booking call.
- Glass-box trace narrative in Lab 09: pick the canonical query, click through Tempo to show full span tree, then point at Grafana cost panel showing the USD increment from that single request.

</specifics>

<deferred>
## Deferred Ideas

- **Persistent agent memory across sessions** (Hermes feature) — useful for "remembers your previous appointments" UX, but adds storage layer. Defer to v2 (post-v1 release).
- **Multi-agent coordination via Sandbox** — multiple Hermes agents talking to each other. Already in v2 requirements (MULTI-01, MULTI-02).
- **Langfuse trace dashboard** — already deferred in v2 (ADV-OBS-01).
- **Code-interpreter / shell tool inside Sandbox** — Sandbox can run untrusted code; powerful pedagogy, but blows scope. Defer.
- **Real calendar/EHR integration for booking** — out of scope; ConfigMap mock sufficient for course value.
- **Custom Hermes fork with course-specific prompts baked in** — D-01 chose upstream-as-is; revisit only if upstream config surface proves insufficient.
- **Jaeger as alternative trace backend** — D-16 chose Tempo; Jaeger could be a v2 option chapter.

</deferred>

---

*Phase: 03-agentops-labs-day-2*
*Context gathered: 2026-05-02*
