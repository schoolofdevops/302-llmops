---
sidebar_position: 10
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Lab 09: Agent Observability

**Day 2 | Duration: ~75 minutes**

Day 2 part 3: take the working Lab-08 agent stack and add full observability — OpenTelemetry traces, Prometheus token and cost metrics, and a unified Grafana dashboard. Today we deploy Grafana Tempo (alongside the existing Day-1 Prometheus + Grafana stack), install an OpenTelemetry Collector that fans traces into Tempo and metrics into Prometheus, instrument the 3 MCP tool servers with OTEL auto-instrumentation, and add a thin "cost middleware" proxy in front of the agent that emits per-token and per-USD Counter metrics from a price-table ConfigMap. By the end you will read tool-call traces in Tempo and watch a USD counter tick up as you query the agent.

## Learning Objectives

- Deploy Grafana Tempo (single-binary mode, in-memory storage on KIND) alongside the existing Day-1 Prometheus + Grafana stack
- Install the OpenTelemetry Collector in deployment mode, configured to forward traces to Tempo and expose metrics to Prometheus
- Auto-instrument the 3 MCP tool servers with FastAPI + httpx OpenTelemetry instrumentation (no manual span code)
- Deploy a Prometheus cost-tracking middleware that intercepts agent traffic and emits token and USD Counters from a price-table ConfigMap
- Auto-discover a new Grafana dashboard via the `grafana_dashboard: "1"` ConfigMap label
- Walk through a single canonical query in Tempo and see the tool-server spans plus the RAG-retriever child span

## Lab Files

Companion code: `course-code/labs/lab-09/`

Scripts (`solution/scripts/`):

- `install-otel-tempo.sh` — idempotent Helm install of Tempo + OTEL Collector; waits for both deployments
- `run-canonical-query-traced.sh` — end-to-end demo: checks cost-middleware health, queries Prometheus, checks Tempo for traces

Helm values (`solution/helm/`):

- `values-tempo.yaml` — Tempo single-binary, in-memory (`/tmp/tempo/traces`), OTLP gRPC+HTTP receivers, resource limits for KIND
- `values-otel-collector.yaml` — Collector in deployment mode, OTLP receivers, batch processor, Tempo + Prometheus exporters

K8s manifests (`solution/k8s/`):

| File | What it creates |
|------|-----------------|
| `70-servicemonitor-otel.yaml` | `ServiceMonitor` for the OTEL Collector Prometheus exporter |
| `70-grafana-tempo-datasource-cm.yaml` | `ConfigMap` that auto-provisions the Tempo datasource in Grafana |
| `70-llm-price-table-cm.yaml` | `ConfigMap/llm-price-table` — JSON price table (Groq + Gemini rates) |
| `70-cost-middleware-deploy.yaml` | `Deployment/cost-middleware` + `Service/cost-middleware` in `llm-agent` |
| `70-servicemonitor-cost-middleware.yaml` | `ServiceMonitor` for cost-middleware `/metrics` |
| `70-servicemonitor-mcp-tools.yaml` | `ServiceMonitor` for the 3 MCP tool servers |
| `70-grafana-agent-dashboard-cm.yaml` | `ConfigMap` — "Smile Dental — Agent Overview" dashboard (auto-loaded) |
| `40-chainlit-deploy-lab09.yaml` | Updated Chainlit `Deployment` routing through cost-middleware |

Cost middleware (`solution/cost_middleware/`):

- `cost_middleware.py` — FastAPI proxy emitting `agent_llm_tokens_total` + `agent_llm_cost_usd_total`
- `Dockerfile`, `requirements.txt`, `test_cost_middleware.py`

OTEL module shared by all 3 MCP tool servers:

- `course-code/labs/lab-07/solution/tools/otel_setup.py` — reusable `setup_tracing()` function
- Modified: `tools/triage/triage_server.py`, `tools/treatment_lookup/treatment_lookup_server.py`, `tools/book_appointment/book_appointment_server.py` — each adds the OTEL imports + `setup_tracing()` call

## Prerequisites

- [ ] **Lab 08 complete** — Hermes Sandbox + WarmPool (replicas=2) + MCP tools running in `llm-agent`; Chainlit routing through Sandbox Router
- [ ] **Day 1 Prometheus + Grafana stack running** in `monitoring` (kube-prometheus-stack from Lab 06)
- [ ] **Free RAM headroom** — Tempo + OTEL Collector add approximately 500-700 MB. Check before starting:
  ```bash
  kubectl top nodes
  ```
  Target: at least 1 GB available on the worker node.
- [ ] **kind-registry running** at `localhost:5001` (needed if you rebuild MCP images after OTEL changes)
- [ ] **Lab 08 Hermes secret** in place — the `hermes-api-secret` Secret in `llm-agent` (created during Lab 08 Part C)

---

## Architecture

Lab 09 adds two observability data paths to the Lab-08 stack:

```
Chainlit → cost-middleware (Prometheus metrics) → sandbox-router-svc → Hermes (in Sandbox)
                                                                         ↓
                                              MCP tool servers (OTEL spans → OTEL Collector → Tempo)
                                                                         ↓
                                              RAG retriever (httpx auto-instrumented; child span)
                                                                         ↓
                                              Groq / Gemini API
```

**Data flows:**

- **Trace pipeline:** MCP tool servers emit OTLP gRPC spans → OTEL Collector → Tempo (query API on port 3200) → Grafana Explore/Panels
- **Cost/token pipeline:** Chainlit → cost-middleware proxy → Prometheus Counter `/metrics` → ServiceMonitor → Prometheus → Grafana dashboard panel

The cost middleware sits between Chainlit and the Sandbox Router — it proxies every `/v1/chat/completions` call transparently, reads `usage.prompt_tokens` and `usage.completion_tokens` from the OpenAI-shaped response, and increments the Counters using prices from the `llm-price-table` ConfigMap. No Hermes fork required (D-01 preserved).

---

## Part A: Install Tempo + OTEL Collector

### Concept

Decision D-16 chose Grafana Tempo because it integrates natively with the Day-1 Grafana instance (single pane for metrics + traces, no separate Jaeger UI). Tempo in single-binary mode fits KIND at 256-512 MB RAM. The OpenTelemetry Collector decouples instrumented apps from the backend: MCP servers send OTLP gRPC to one endpoint; the Collector fans traces to Tempo and metrics to Prometheus. Swap backends later by changing only Collector config.

### Step A1: Install Tempo and OTEL Collector

Run the idempotent install script (adds Helm repos, upgrades-or-installs both charts, waits for readiness):

```bash
bash course-code/labs/lab-09/solution/scripts/install-otel-tempo.sh
```

Expected output:

```
[1/4] Adding Helm repos...
[2/4] Installing Grafana Tempo (chart 1.24.4)...
[3/4] Installing OpenTelemetry Collector (chart 0.153.0)...
[4/4] Verifying both deployments are Available...
```

The script installs:

- **`grafana/tempo` 1.24.4** — single-binary, OTLP gRPC+HTTP receivers, traces in `/tmp/tempo/traces` (ephemeral, no PVC).
- **`open-telemetry/opentelemetry-collector` 0.153.0** — deployment mode, `otel/opentelemetry-collector-contrib` image, OTLP receivers, batch processor (5s), exports traces to `tempo.monitoring:4317` and metrics to Prometheus on port 8889.

### Step A2: Apply the ServiceMonitor and Tempo datasource

```bash
kubectl apply -f course-code/labs/lab-09/solution/k8s/70-servicemonitor-otel.yaml
kubectl apply -f course-code/labs/lab-09/solution/k8s/70-grafana-tempo-datasource-cm.yaml
```

The datasource ConfigMap auto-provisions Tempo (`uid=tempo`, `url=http://tempo.monitoring.svc.cluster.local:3200`) into Grafana on pod restart.

### Verify

```bash
kubectl get pods -n monitoring | grep -E 'tempo|otel-collector'
# Expected: tempo-0 1/1 Running, otel-collector-opentelemetry-collector-* 1/1 Running
```

Open Grafana at `http://localhost:30400` → Connections → Data sources → confirm **"Tempo"** appears alongside the existing Prometheus source.

:::info In-memory tmpfs storage
Tempo on KIND stores traces in `/tmp/tempo/traces` inside the pod — ephemeral, no PVC required. Traces are lost when the Tempo pod restarts. This is fine for the workshop: the canonical query in Part E takes under 5 minutes and traces will be fresh. For production, point Tempo at an object store (S3, GCS) by changing `tempo.storage.trace.backend` in the values file.
:::

---

## Part B: How the MCP tools became OTEL-instrumented

### Auto-instrumentation — no manual span code

The MCP tool servers use two OTEL Python libraries:

- **`FastAPIInstrumentor`** — wraps every FastAPI route; each incoming `/mcp` request becomes a span in Tempo automatically (no `tracer.start_span()` required).
- **`HTTPXClientInstrumentor`** — wraps outgoing `httpx.AsyncClient` calls as child spans. The `treatment_lookup` tool's httpx call to the RAG retriever appears as a child span under the FastAPI span — giving the `tool.invoke → retriever.search` hierarchy.

The reusable setup lives in `course-code/labs/lab-07/solution/tools/otel_setup.py`:

```python
"""otel_setup.py — Reusable OTEL TracerProvider for MCP tool servers.

Imported by triage_server.py / treatment_lookup_server.py / book_appointment_server.py.

NOTE on D-18 (CONTEXT.md) partial compliance:
The Hermes agent binary does NOT propagate W3C traceparent across MCP calls.
Tool spans from this setup will appear as SEPARATE ROOT TRACES in Tempo,
correlated by time window and service.name — not as children of an agent.request span.
This is documented honestly; the treatment_lookup → httpx → rag-retriever sub-tree
IS hierarchical (child span via HTTPXClientInstrumentor) and satisfies OBS-06 literally.
"""
import os
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource

OTEL_ENDPOINT = os.environ.get(
    "OTEL_EXPORTER_OTLP_ENDPOINT",
    "http://otel-collector-opentelemetry-collector.monitoring.svc.cluster.local:4317",
)

def setup_tracing(service_name: str):
    """Wire OTLP gRPC exporter for this service. Idempotent — safe to call once at startup."""
    resource = Resource(attributes={"service.name": service_name})
    provider = TracerProvider(resource=resource)
    exporter = OTLPSpanExporter(endpoint=OTEL_ENDPOINT, insecure=True)
    provider.add_span_processor(BatchSpanProcessor(exporter))
    trace.set_tracer_provider(provider)
    return trace.get_tracer(service_name)
```

### Changes applied to triage_server.py (representative)

The diff applied to each tool server is three lines added near the top:

```python
from tools.otel_setup import setup_tracing
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor

# OTEL: must run BEFORE creating streamable_http_app() so FastAPI instrumentation
# hooks the right routes.
setup_tracing(service_name=os.environ.get("OTEL_SERVICE_NAME", "mcp-triage"))
HTTPXClientInstrumentor().instrument()
```

And at the bottom, `FastAPIInstrumentor` wraps the app after extraction:

```python
if __name__ == "__main__":
    import uvicorn
    _app = mcp.streamable_http_app()
    FastAPIInstrumentor.instrument_app(_app)   # <-- added
    uvicorn.run(_app, host="0.0.0.0", port=PORT)
```

The same three-line pattern is applied identically to `treatment_lookup_server.py` (with `service_name="mcp-treatment-lookup"`) and `book_appointment_server.py` (with `service_name="mcp-book-appointment"`). No business logic changes.

:::warning D-18 partial compliance — Hermes does not propagate W3C traceparent

CONTEXT.md decision D-18 specifies a hierarchical OTEL span tree:
`agent.request` (root) → `llm.completion` + `tool.invoke` (with `mcp.call`
and `retriever.search` children).

**This lab implements D-18 PARTIALLY:**

- **NOT visible:** `agent.request` and `llm.completion` parent spans. These are
  emitted internally by the Hermes Agent process. Per CONTEXT.md D-01, we use
  the upstream `nousresearch/hermes-agent:latest` image as-is and do not fork
  it. The closed binary does not export those spans through OTLP, and we cannot
  inject instrumentation into a binary we don't control. RESEARCH.md Focus 6
  confirms MCP protocol does not natively carry W3C traceparent, and Hermes does
  not propagate it on outgoing MCP calls either.

- **VISIBLE and hierarchical:** `tool.invoke` (FastAPIInstrumentor span on each
  MCP server's incoming `/mcp` HTTP request), `mcp.call` (the same FastAPI server
  span IS the MCP call boundary), and `retriever.search` (HTTPXClientInstrumentor
  child span on the `treatment_lookup` server's outgoing httpx call to
  rag-retriever). For any single user query, Tempo will show each MCP tool's
  spans as a **separate root trace** — not nested under `agent.request`.

- **Workaround:** use Tempo's time-window search (`service.name=mcp-treatment-lookup`,
  last 5 minutes) to correlate tool spans for one user query. All 3 tool spans
  from a single "severe tooth pain" query appear within a 30-second window.

- **The literal `agent → retriever → LLM` span chain** demanded by OBS-06 IS
  produced via the `mcp-treatment-lookup → httpx → rag-retriever` sub-tree.
  This sub-tree IS hierarchical inside Tempo.

Reconsidering D-01 (forking Hermes to add OTEL instrumentation) would unlock D-18
fully. That is **OUT OF SCOPE for v1**; tracked as a future enhancement.
:::

### Rebuild and roll the MCP tool images

After the OTEL changes, rebuild and reload so the running pods pick up the instrumentation:

```bash
bash course-code/labs/lab-08/solution/scripts/build-mcp-images.sh

# KIND worker nodes cannot pull from localhost:5001 — use kind load:
kind load docker-image localhost:5001/mcp-triage:v1.0.0 --name llmops-kind
kind load docker-image localhost:5001/mcp-treatment-lookup:v1.0.0 --name llmops-kind
kind load docker-image localhost:5001/mcp-book-appointment:v1.0.0 --name llmops-kind

kubectl rollout restart deploy/mcp-triage deploy/mcp-treatment-lookup deploy/mcp-book-appointment -n llm-agent
kubectl rollout status deploy/mcp-triage deploy/mcp-treatment-lookup deploy/mcp-book-appointment -n llm-agent
```

---

## Part C: Cost middleware

### Why a proxy?

D-01 forbids forking Hermes. The proxy forwards requests upstream, reads `usage.prompt_tokens` + `usage.completion_tokens` from the OpenAI-shaped response, looks up model prices in the `llm-price-table` ConfigMap, and increments two Prometheus Counters — no upstream changes required.

### How cost_middleware.py works

Key sections from `course-code/labs/lab-09/solution/cost_middleware/cost_middleware.py`:

```python
# Counter definitions (isolated registry avoids Duplicated timeseries in tests):
_registry = CollectorRegistry()
tokens_total = Counter(
    "agent_llm_tokens_total", "Total LLM tokens consumed by the agent",
    ["provider", "model", "direction"], registry=_registry,
)
cost_usd_total = Counter(
    "agent_llm_cost_usd_total", "Total LLM API cost in USD",
    ["provider", "model"], registry=_registry,
)

def compute_cost_usd(model: str, prompt_tokens: int, completion_tokens: int) -> float:
    """Look up model pricing from price-table ConfigMap. Unknown models cost 0.0."""
    p = PRICES.get(model)
    if not p:
        return 0.0
    return (prompt_tokens / 1_000_000.0) * p["input_usd_per_1m"] + \
           (completion_tokens / 1_000_000.0) * p["output_usd_per_1m"]

@app.post("/v1/chat/completions")
async def proxy_chat(request: Request):
    body = await request.json()
    async with httpx.AsyncClient(timeout=180) as client:
        upstream = await client.post(f"{UPSTREAM_URL}/v1/chat/completions", ...)
    if upstream.status_code == 200:
        try:
            usage = upstream.json().get("usage") or {}
            in_t, out_t = int(usage.get("prompt_tokens", 0)), int(usage.get("completion_tokens", 0))
            tokens_total.labels(..., direction="input").inc(in_t)
            tokens_total.labels(..., direction="output").inc(out_t)
            cost_usd_total.labels(...).inc(compute_cost_usd(model, in_t, out_t))
        except Exception:
            pass  # never break the response path
    return Response(content=upstream.content, ...)
```

### Price table ConfigMap

`course-code/labs/lab-09/solution/k8s/70-llm-price-table-cm.yaml` contains the static price table:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: llm-price-table
  namespace: llm-agent
data:
  prices.json: |
    {
      "groq/llama-3.3-70b-versatile": {
        "input_usd_per_1m": 0.59,
        "output_usd_per_1m": 0.79
      },
      "google/gemini-2.5-flash": {
        "input_usd_per_1m": 0.30,
        "output_usd_per_1m": 2.50
      }
    }
```

Update these values any time pricing changes — no image rebuild, just `kubectl apply` and `kubectl rollout restart`.

### Deploy cost middleware and switch Chainlit

```bash
# Build and load the cost-middleware image into KIND:
docker build -t localhost:5001/cost-middleware:v1.0.0 \
  course-code/labs/lab-09/solution/cost_middleware/
docker push localhost:5001/cost-middleware:v1.0.0
kind load docker-image localhost:5001/cost-middleware:v1.0.0 --name llmops-kind

# Apply price table, deployment, and ServiceMonitors:
kubectl apply -f course-code/labs/lab-09/solution/k8s/70-llm-price-table-cm.yaml
kubectl apply -f course-code/labs/lab-09/solution/k8s/70-cost-middleware-deploy.yaml
kubectl apply -f course-code/labs/lab-09/solution/k8s/70-servicemonitor-cost-middleware.yaml
kubectl apply -f course-code/labs/lab-09/solution/k8s/70-servicemonitor-mcp-tools.yaml
kubectl rollout status deploy/cost-middleware -n llm-agent --timeout=120s
```

Switch Chainlit to route through the cost middleware (uses the numbered overlay manifest, not `kubectl set env`):

```bash
kubectl apply -f course-code/labs/lab-09/solution/k8s/40-chainlit-deploy-lab09.yaml
kubectl rollout status deploy/chainlit-ui -n llm-app --timeout=120s
```

The `40-chainlit-deploy-lab09.yaml` overlay sets `AGENT_URL=http://cost-middleware.llm-agent.svc.cluster.local:9100` — inserting cost-middleware between Chainlit and the Sandbox Router.

Verify the cost middleware is healthy:

```bash
kubectl -n llm-agent port-forward svc/cost-middleware 19100:9100 &
sleep 2
curl -s http://localhost:19100/health
# Expected: {"ok":true}
curl -s http://localhost:19100/metrics | grep agent_llm
# Expected: agent_llm_tokens_total and agent_llm_cost_usd_total counters (value 0 until first query)
kill %1 2>/dev/null || true
```

:::tip Why we proxy instead of patch Hermes
D-01 forbids forking Hermes; the proxy approach gives us cost visibility without modifying upstream code, and it composes cleanly with any OpenAI-compatible agent. The same pattern works whether the model is Groq, Gemini, or a self-hosted vLLM instance — no changes to the middleware, just update the `llm-price-table` ConfigMap.
:::

---

## Part D: Grafana dashboard

### Apply the dashboard ConfigMap

```bash
kubectl apply -f course-code/labs/lab-09/solution/k8s/70-grafana-agent-dashboard-cm.yaml
```

The ConfigMap has label `grafana_dashboard: "1"` — Grafana's provisioning sidecar watches for ConfigMaps with this label and auto-loads them as dashboards. No manual import via the Grafana UI is needed.

### Retrieve the Grafana admin password and open the dashboard

```bash
kubectl -n monitoring get secret kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d && echo
```

Open Grafana at `http://localhost:30400` → log in with user `admin` and the password above.

### Walk through the "Smile Dental — Agent Overview" dashboard

Navigate to Dashboards → Browse → search for **"Smile Dental"** → open **"Smile Dental — Agent Overview"**.

The dashboard has 4 panels:

| Panel | Title | Type | Datasource | Query |
|-------|-------|------|------------|-------|
| 1 | LLM tokens / sec by direction | timeseries | Prometheus | `sum by (direction) (rate(agent_llm_tokens_total[1m]))` |
| 2 | Cumulative LLM cost (USD) | stat | Prometheus | `sum(agent_llm_cost_usd_total)` |
| 3 | Per-tool span duration (Tempo) | traces | Tempo | service=mcp-triage, limit=20 |
| 4 | Recent agent traces | traces | Tempo | service=mcp-treatment-lookup, limit=20 |

At this point all panels show 0 (no traffic yet) — you will populate them in Part E.

:::info If panels 3 or 4 show an error
If Grafana reports an error on the traces panels, navigate to **Grafana → Explore → Tempo** to query traces directly. Confirm the Tempo datasource exists in Connections → Data sources (provisioned by the ConfigMap in Part A Step A2).
:::

---

## Part E: Run the traced canonical query

Run the end-to-end verification script. The script checks cost-middleware health, shows current Prometheus metrics, and queries Tempo for traces:

```bash
bash course-code/labs/lab-09/solution/scripts/run-canonical-query-traced.sh
```

The script verifies infrastructure readiness and shows current metric values. Because the Sandbox Router requires a per-session `X-Sandbox-ID` header (generated by Chainlit SDK), generate traffic via the UI:

1. Open `http://localhost:30300` → type **severe tooth pain since yesterday**
2. Watch three Tool sub-steps appear: `mcp_triage_triage`, `mcp_treatment_lookup_treatment_lookup`, `mcp_book_appointment_book_appointment`

Re-run the script after the Chainlit query to see non-zero values:

```bash
bash course-code/labs/lab-09/solution/scripts/run-canonical-query-traced.sh
```

Expected output after one canonical query:

```
[2/4] Current cost-middleware metrics...
  agent_llm_tokens_total{direction="input",...} 847
  agent_llm_tokens_total{direction="output",...} 143
  agent_llm_cost_usd_total{...} 0.000613

[3/4] Querying Prometheus for aggregated cost metrics...
  agent_llm_tokens_total = 990
  OBS-05 PASS: non-zero token count
  agent_llm_cost_usd_total = 0.000613 USD
  OBS-05 PASS: non-zero cost

[4/4] Checking Tempo for MCP tool traces...
  mcp-triage: 3 traces in Tempo
  mcp-treatment-lookup: 3 traces in Tempo
  mcp-book-appointment: 2 traces in Tempo
```

After one canonical query, `sum(agent_llm_cost_usd_total)` reads approximately **$0.000613** (single-digit millicents; exact value depends on provider and model). Back in Grafana: Panel 1 shows input + output token rates, Panel 2 shows the non-zero USD total, Panels 3+4 show trace rows for `mcp-triage` and `mcp-treatment-lookup`.

### Click through Tempo

:::tip Click through Tempo — step-by-step
1. In Grafana → **Explore** → select **Tempo** datasource
2. Set query type to **Search**; set `service.name` = `mcp-treatment-lookup`
3. Click **Run query** — you should see trace rows from the last query
4. Click any trace row to open the span detail view
5. Expand the span tree — you will see:
   - Root span: `POST /mcp` (FastAPIInstrumentor — this is the `tool.invoke` boundary)
   - Child span: `GET http://rag-retriever.llm-app.svc.cluster.local:8001/search` (HTTPXClientInstrumentor — this is the `retriever.search` span)
6. The child span URL confirms the `treatment_lookup → rag-retriever` link. **This is the literal "agent → retriever → LLM" span chain that closes OBS-06.**

To correlate all 3 tools from one query: switch to service.name `mcp-triage`, note the timestamp of your query, and confirm all three services have traces within a 30-second window. This is the Tempo time-window correlation workaround for the missing W3C traceparent from Hermes (see Part B warning).
:::

---

## Verification

```bash
# 1. Tempo and OTEL Collector both Available:
kubectl get deploy tempo otel-collector-opentelemetry-collector -n monitoring
# Expected: both 1/1 READY

# 2. Cost middleware Available:
kubectl get deploy cost-middleware -n llm-agent
# Expected: 1/1 READY

# 3. Prometheus shows non-zero cost (run AFTER at least one Chainlit chat):
kubectl -n monitoring port-forward svc/$(kubectl get svc -n monitoring -o name \
  | grep prometheus | grep -v 'node-exporter\|operated\|operator' | head -1 | sed 's|service/||') 29090:9090 &
sleep 3
curl -s "http://localhost:29090/api/v1/query?query=sum(agent_llm_cost_usd_total)" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); v=float(d['data']['result'][0]['value'][1]); print(f'cost={v:.6f} USD'); assert v>0"
kill %1 2>/dev/null || true

# 4. Tempo has traces for mcp-treatment-lookup (run AFTER Chainlit query):
kubectl -n monitoring port-forward svc/tempo 13200:3200 &
sleep 2
curl -s "http://localhost:13200/api/search?tags=service.name%3Dmcp-treatment-lookup&limit=5" \
  | python3 -c "import json,sys; n=len(json.load(sys.stdin).get('traces',[])); print(f'{n} traces'); assert n>=1"
kill %1 2>/dev/null || true

# 5. Grafana dashboard auto-discovered:
kubectl get cm grafana-agent-dashboard -n monitoring -o jsonpath='{.metadata.labels.grafana_dashboard}'
# Expected: 1
```

---

## Common Pitfalls

:::warning Hermes does not propagate traceparent — use time-window search
The Hermes binary does not export `agent.request` or `llm.completion` parent spans, and does not propagate W3C traceparent on outgoing MCP calls (confirmed; see Part B for full explanation). Each MCP tool call appears as a **separate root trace** in Tempo. To correlate tool spans for one user query, open Tempo Explore, set `service.name=mcp-triage` (or `mcp-treatment-lookup`), and look for traces within the 30-second window of your query. All three tools fire within a short window for a single "severe tooth pain since yesterday" request.
:::

:::warning Tempo loses traces on pod restart
Tempo on KIND stores traces in `/tmp/tempo/traces` — ephemeral in-memory storage. If the Tempo pod restarts, all traces are lost. This is fine for the workshop. If you need persistent traces for a demo that spans a cluster restart, run the canonical query again after Tempo is back up.
:::

:::warning ServiceMonitor not picked up by Prometheus
The most common cause of missing metrics in Prometheus is a `ServiceMonitor` with the wrong label. The kube-prometheus-stack uses `release: kube-prometheus-stack` as the selector label. If you create a custom ServiceMonitor and Prometheus does not scrape it, verify:
```bash
kubectl get servicemonitor cost-middleware-monitor -n llm-agent -o jsonpath='{.metadata.labels}'
# Must include: "release": "kube-prometheus-stack"
```
If the label is missing, reapply `70-servicemonitor-cost-middleware.yaml` (already includes the correct label).
:::

:::warning Grafana dashboard not auto-loading
Two common causes: (1) the ConfigMap is missing the `grafana_dashboard: "1"` label, or (2) the JSON in the ConfigMap `data` field is malformed. Verify:
```bash
# Check label:
kubectl get cm grafana-agent-dashboard -n monitoring --show-labels | grep grafana_dashboard

# Check JSON is valid:
kubectl get cm grafana-agent-dashboard -n monitoring -o jsonpath='{.data.agent-overview\.json}' | python3 -m json.tool > /dev/null && echo "JSON valid"
```
If either check fails, reapply `70-grafana-agent-dashboard-cm.yaml`. After fixing, Grafana's sidecar picks up the ConfigMap within ~30 seconds.
:::

:::tip Cost data is small for free-tier prompts
Expect ~$0.0005-0.001 per canonical query (single-digit millicents). The counter is non-zero and strictly increasing — that is the proof the instrumentation works, even if the dollar amount is tiny.
:::

:::warning OTEL Collector chart 0.153.0 requires explicit image.repository
If the Collector pod fails with `[ERROR] 'image.repository' must be set`, ensure `values-otel-collector.yaml` has `image.repository: otel/opentelemetry-collector-contrib`. Chart 0.153.0 made this field required. The provided values file already includes it.
:::

---

## After This Lab

| Component | URL / Resource | Status |
|-----------|----------------|--------|
| Grafana Tempo | `tempo.monitoring.svc:3200` (query API) | Running (in-memory) |
| OpenTelemetry Collector | `otel-collector-opentelemetry-collector.monitoring.svc:4317` | Running |
| Cost middleware proxy | `cost-middleware.llm-agent.svc:9100` | Running |
| Smile Dental Agent dashboard | Grafana → "Smile Dental — Agent Overview" | Auto-discovered |
| Chainlit (Day-2, traced) | NodePort 30300 → cost-middleware → Sandbox Router → Hermes | Running |
| MCP tools (OTEL) | `mcp-triage:8010`, `mcp-treatment-lookup:8020`, `mcp-book-appointment:8030` | Running + instrumented |

The architecture is now: **Chainlit → cost-middleware (Prometheus) → Sandbox Router → pre-warmed Hermes pod → OTEL-instrumented MCP tools → RAG retriever / Groq-Gemini API**, with traces flowing to Tempo and cost metrics to Prometheus.

Day 3 (Phase 4) builds on this stack — HPA + KEDA autoscaling driven by `agent_llm_tokens_total`, GitOps via ArgoCD, Argo Workflows with a DeepEval gate, and guardrails. The Lab 09 observability stack is what makes Day-3 systems debuggable.

---

## Tear Down (optional)

Leaves Tempo + OTEL Collector running for Day 3. Scale cost-middleware to 0 if you need RAM back:

```bash
kubectl scale deploy/cost-middleware -n llm-agent --replicas=0
# To restore: kubectl scale deploy/cost-middleware -n llm-agent --replicas=1
```

Nuclear option — remove everything installed in this lab:

```bash
helm uninstall tempo -n monitoring || true
helm uninstall otel-collector -n monitoring || true
kubectl delete -f course-code/labs/lab-09/solution/k8s/ --ignore-not-found
# Chainlit reverts to Lab 08 config:
kubectl apply -f course-code/labs/lab-08/solution/k8s/40-chainlit-deploy-day2.yaml
```

The Day-1 kube-prometheus-stack is NOT removed — needed for Day-3 autoscaling labs.
