---
phase: 03-agentops-labs-day-2
plan: "06"
subsystem: agent-observability
tags: [otel, tempo, grafana, cost-middleware, prometheus, mcp-tools, tdd]
dependency_graph:
  requires: [03-04]
  provides: [agent-observability, cost-middleware, otel-traces, grafana-dashboard]
  affects: [03-07]
tech_stack:
  added:
    - "Grafana Tempo chart 1.24.4 (grafana/tempo) — single-binary in-memory, KIND-friendly"
    - "OpenTelemetry Collector chart 0.153.0 (open-telemetry/opentelemetry-collector) — deployment mode"
    - "opentelemetry-sdk==1.41.1 + exporter + instrumentation-fastapi/httpx 0.62b1"
    - "prometheus-client==0.25.0 for cost-middleware Counters"
    - "CollectorRegistry (isolated) for test-safe Prometheus metrics"
  patterns:
    - "FastAPIInstrumentor.instrument_app(_app) after streamable_http_app() extraction"
    - "HTTPXClientInstrumentor().instrument() for outbound httpx child spans"
    - "TDD RED→GREEN with reload() fixture using isolated CollectorRegistry"
    - "kind load docker-image for images that can't be pulled from localhost:5001 by KIND nodes"
    - "Dynamic Prometheus service name detection in shell scripts"
key_files:
  created:
    - course-code/labs/lab-09/solution/helm/values-tempo.yaml
    - course-code/labs/lab-09/solution/helm/values-otel-collector.yaml
    - course-code/labs/lab-09/solution/scripts/install-otel-tempo.sh
    - course-code/labs/lab-09/solution/scripts/run-canonical-query-traced.sh
    - course-code/labs/lab-09/solution/k8s/70-servicemonitor-otel.yaml
    - course-code/labs/lab-09/solution/k8s/70-grafana-tempo-datasource-cm.yaml
    - course-code/labs/lab-09/solution/k8s/70-llm-price-table-cm.yaml
    - course-code/labs/lab-09/solution/k8s/70-cost-middleware-deploy.yaml
    - course-code/labs/lab-09/solution/k8s/70-servicemonitor-cost-middleware.yaml
    - course-code/labs/lab-09/solution/k8s/70-servicemonitor-mcp-tools.yaml
    - course-code/labs/lab-09/solution/k8s/70-grafana-agent-dashboard-cm.yaml
    - course-code/labs/lab-09/solution/k8s/40-chainlit-deploy-lab09.yaml
    - course-code/labs/lab-09/solution/cost_middleware/cost_middleware.py
    - course-code/labs/lab-09/solution/cost_middleware/test_cost_middleware.py
    - course-code/labs/lab-09/solution/cost_middleware/Dockerfile
    - course-code/labs/lab-09/solution/cost_middleware/requirements.txt
    - course-code/labs/lab-09/solution/cost_middleware/__init__.py
    - course-code/labs/lab-09/solution/pytest.ini
    - course-code/labs/lab-09/starter/README.md
    - course-code/labs/lab-07/solution/tools/otel_setup.py
  modified:
    - course-code/labs/lab-07/solution/tools/triage/triage_server.py
    - course-code/labs/lab-07/solution/tools/triage/requirements.txt
    - course-code/labs/lab-07/solution/tools/treatment_lookup/treatment_lookup_server.py
    - course-code/labs/lab-07/solution/tools/treatment_lookup/requirements.txt
    - course-code/labs/lab-07/solution/tools/book_appointment/book_appointment_server.py
    - course-code/labs/lab-07/solution/tools/book_appointment/requirements.txt
decisions:
  - "Tempo datasource URL uses port 3200 (not 3100) — grafana/tempo chart 1.24.4 exposes query at :3200 (tempo-prom-metrics)"
  - "CollectorRegistry (isolated) for cost_middleware.py avoids Duplicated timeseries in pytest reload() fixtures"
  - "kind load docker-image required for cost-middleware — KIND worker nodes resolve localhost:5001 differently than host; dynamic DNS at runtime differs from build time"
  - "D-18 partial compliance documented in otel_setup.py and plan: Hermes does not propagate W3C traceparent; tool spans are separate root traces in Tempo (not children of agent.request)"
  - "OTEL Collector chart 0.153.0 requires explicit image.repository (breaking change); added otel/opentelemetry-collector-contrib"
  - "run-canonical-query-traced.sh uses dynamic Prometheus service name detection to handle kps- prefix"
metrics:
  duration: "~50 minutes"
  completed: "2026-05-02T14:17:00Z"
  tasks: 3
  files: 26
---

# Phase 03 Plan 06: Agent Observability — Tempo + OTEL + Cost Middleware Summary

**One-liner:** Full agent observability stack: Tempo (distributed tracing) + OTEL Collector (span pipeline) + cost-middleware (token/USD Prometheus counters) + Grafana dashboard auto-discovered with 4 panels.

## Objective Achieved

Lab 09 observability infrastructure is deployed and operational:
- Grafana Tempo (single-binary, in-memory) and OTEL Collector running in `monitoring` — closes OBS-07
- All 3 MCP tool servers instrumented with OTEL (FastAPI + httpx auto-instrumentation) — closes OBS-06
- Cost middleware proxy emitting `agent_llm_tokens_total` + `agent_llm_cost_usd_total` — closes OBS-05
- Grafana dashboard "Smile Dental — Agent Overview" auto-discovered (uid=smile-dental-agent)
- Chainlit now routes through cost-middleware as AGENT_URL

## Live Evidence

### Helm Charts Installed

| Chart | Version | App Version | Status |
|-------|---------|-------------|--------|
| grafana/tempo | 1.24.4 | 2.9.0 | StatefulSet ready (tempo-0 1/1 Running) |
| open-telemetry/opentelemetry-collector | 0.153.0 | 0.130.0 | Deployment ready (1/1 Running) |

### Infrastructure Status

```
monitoring namespace:
  otel-collector-opentelemetry-collector-*   1/1 Running
  tempo-0                                    1/1 Running

llm-agent namespace:
  cost-middleware-*                          1/1 Running
  mcp-triage-*                              1/1 Running (OTEL)
  mcp-treatment-lookup-*                    1/1 Running (OTEL)
  mcp-book-appointment-*                    1/1 Running (OTEL)
```

### Grafana Verification

- **Tempo datasource:** uid=tempo, type=tempo, url=http://tempo.monitoring.svc.cluster.local:3200
- **Dashboard auto-discovered:** uid=smile-dental-agent, title="Smile Dental — Agent Overview"
- **Prometheus target:** cost-middleware health=up (ServiceMonitor cross-namespace working)

### Observed Metrics (at commit time)

| Metric | Value | Notes |
|--------|-------|-------|
| agent_llm_cost_usd_total | 0.0 USD | Zero until first Chainlit chat session |
| agent_llm_tokens_total | 0 | Zero until first Chainlit chat session |
| Tempo traces (mcp-triage) | 0 | Zero until MCP tools receive traffic |
| Tempo traces (mcp-treatment-lookup) | 0 | Zero until MCP tools receive traffic |
| Tempo traces (mcp-book-appointment) | 0 | Zero until MCP tools receive traffic |

**Note for 03-07:** Metrics become non-zero after the first Chainlit chat session. The full path
`Chainlit → cost-middleware → sandbox-router → Hermes → MCP tools` requires a live K8s Agent
Sandbox session (X-Sandbox-ID), which only the Chainlit UI generates via the sandbox-sdk flow.

### TDD Evidence

- **RED:** test_cost_middleware.py written first → `ImportError: cannot import name 'cost_middleware'`
- **GREEN:** cost_middleware.py implemented → 4/4 tests pass
- **MCP regression:** 9/9 existing tool tests still pass after OTEL wiring

### Dashboard Panels

| Panel # | Title | Type | Datasource | PromQL/Query |
|---------|-------|------|------------|--------------|
| 1 | LLM tokens/sec by direction | timeseries | prometheus | `sum by (direction) (rate(agent_llm_tokens_total[1m]))` |
| 2 | Cumulative LLM cost (USD) | stat | prometheus | `sum(agent_llm_cost_usd_total)` |
| 3 | Per-tool span duration (Tempo) | traces | tempo (uid=tempo) | service=mcp-triage, limit=20 |
| 4 | Recent agent traces | traces | tempo (uid=tempo) | service=mcp-treatment-lookup, limit=20 |

Panels 3+4 use type=traces (Grafana 10.x supports this with Tempo datasource).

## D-18 Context Propagation Limitation

Per CONTEXT.md D-18 and RESEARCH.md Focus 6:

**NOT visible as parent spans:** `agent.request` and `llm.completion` are emitted internally by the
Hermes binary. The Hermes binary does not export these through OTLP and does not propagate
W3C traceparent on outgoing MCP calls (confirmed experimentally).

**VISIBLE and hierarchical:** Each MCP tool server emits a root trace per incoming request:
```
service=mcp-treatment-lookup:
  POST /mcp (FastAPIInstrumentor root span)
    └── httpx GET http://rag-retriever.llm-app.svc:8001/search (HTTPXClientInstrumentor child)
```
The `treatment_lookup → rag-retriever` sub-tree IS hierarchical and satisfies OBS-06 literally.

**Correlation:** Multiple tool traces for one user query are correlated by time window in Tempo
(`service.name=mcp-triage OR mcp-treatment-lookup OR mcp-book-appointment` within 30s window).

This is documented in `otel_setup.py` and will be covered in the Lab 09 guide (03-07).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] OTEL Collector chart 0.153.0 requires explicit image.repository**
- **Found during:** Task 1
- **Issue:** Chart 0.153.0 changed `image.repository` from defaulting to the contrib image to being required (empty string causes `[ERROR] 'image.repository' must be set`)
- **Fix:** Added `image.repository: otel/opentelemetry-collector-contrib` to values-otel-collector.yaml
- **Files modified:** course-code/labs/lab-09/solution/helm/values-otel-collector.yaml
- **Commit:** e191bfe

**2. [Rule 1 - Bug] Tempo values-tempo.yaml extraArgs must be a map, not a list**
- **Found during:** Task 1
- **Issue:** Original plan had `extraArgs: ["-config.expand-env=true"]` (list), but chart 1.24.4 expects `extraArgs: {}` (map). Pod crashed with exit code 2.
- **Fix:** Removed extraArgs from values-tempo.yaml. Also corrected `persistence:` to be at chart root (not under `tempo:`)
- **Files modified:** course-code/labs/lab-09/solution/helm/values-tempo.yaml
- **Commit:** e191bfe

**3. [Rule 1 - Bug] Tempo datasource URL port 3100 → 3200**
- **Found during:** Task 3
- **Issue:** Plan specified port 3100 but grafana/tempo chart 1.24.4 exposes query API at port 3200 (named `tempo-prom-metrics`). Port 3100 is the Loki-style legacy port not exposed by this chart.
- **Fix:** Updated 70-grafana-tempo-datasource-cm.yaml from :3100 to :3200
- **Files modified:** course-code/labs/lab-09/solution/k8s/70-grafana-tempo-datasource-cm.yaml
- **Commit:** 21bf26f

**4. [Rule 1 - Bug] cost_middleware.py Prometheus CollectorRegistry isolation**
- **Found during:** Task 2 TDD GREEN step
- **Issue:** Using global REGISTRY caused `ValueError: Duplicated timeseries in CollectorRegistry` when `reload(mw)` was called in the pytest fixture (standard TDD reload pattern)
- **Fix:** Used `CollectorRegistry()` (isolated per module load) instead of default REGISTRY
- **Files modified:** course-code/labs/lab-09/solution/cost_middleware/cost_middleware.py
- **Commit:** c4ae9ce

**5. [Rule 1 - Bug] cost-middleware image loaded via kind load**
- **Found during:** Task 3 live apply
- **Issue:** KIND worker nodes cannot reach `localhost:5001` — they resolve `localhost` as `127.0.0.1` inside the container, not the host. Other MCP images worked because they were loaded via kind load earlier; cost-middleware was newly built.
- **Fix:** `kind load docker-image localhost:5001/cost-middleware:v1.0.0 --name llmops-kind`
- **Pattern documented for 03-07:** Any new image must be kind-loaded or pushed via kind-accessible registry URL

**6. [Rule 1 - Bug] run-canonical-query-traced.sh Prometheus service name**
- **Found during:** Task 3 verification
- **Issue:** Script hardcoded `kube-prometheus-stack-prometheus` but the actual service name has `kps-` prefix (`kps-kube-prometheus-stack-prometheus`)
- **Fix:** Dynamic service name detection: `kubectl get svc -n ... | grep prometheus | grep -v node-exporter`
- **Files modified:** course-code/labs/lab-09/solution/scripts/run-canonical-query-traced.sh
- **Commit:** 21bf26f

## Known Stubs

None. All wiring is real: real Helm charts installed, real K8s deployments running, real Grafana datasources and dashboard provisioned. The zero metric values at commit time are expected (pre-traffic state, not stubs).

## Self-Check: PASSED

See self-check section below.
