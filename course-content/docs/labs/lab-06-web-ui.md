---
sidebar_position: 7
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Lab 06: Chainlit Web UI + Observability

**Day 1 | Duration: ~45 minutes**

## Learning Objectives

- Deploy the Smile Dental Chainlit chat interface to Kubernetes
- Understand Chainlit's "glass-box" mode — expandable steps that reveal each pipeline stage
- Install Prometheus and Grafana via kube-prometheus-stack Helm chart
- Configure ServiceMonitors to scrape vLLM, the retriever, and Chainlit metrics
- Observe LLM-specific metrics (Time to First Token, request count) in a pre-built Grafana dashboard

This is the final Day 1 lab. By the end, you'll have a fully running Smile Dental assistant — accessible in a browser, backed by the RAG retriever and vLLM you deployed in Labs 01-05, with real-time metrics visible in Grafana.

---

## Part A: Smile Dental Chat UI

### Why Chainlit for This Course?

Chainlit is a Python-native chat framework that integrates directly with async Python code. No frontend JavaScript, no separate REST layer — your `on_message` handler is also the API handler. For this course, the key feature is **Steps**: collapsible panels in the chat UI that reveal what each pipeline stage received and produced.

This makes the Chainlit UI "glass-box" rather than "black-box" — a deliberate pedagogical choice. Students can see exactly which documents the RAG retriever returned, what prompt was assembled and sent to vLLM, and how long each stage took. This visibility is essential for understanding LLMOps: when a response is wrong, you can trace back to see whether the retriever found relevant documents, whether the prompt was correctly constructed, or whether vLLM generated something unexpected.

### How app.py Works

Open `course-code/labs/lab-05/solution/ui/app.py`. The handler for incoming messages (`on_message`) runs three pipeline stages, each wrapped in a `cl.Step`:

**Step 1 — RAG Retrieval:**
```python
async with cl.Step(name="Retrieving clinic documents", type="tool") as s:
    s.input = message.content
    resp = await client.post(f"{RETRIEVER_URL}/search",
                             json={"query": message.content, "k": TOP_K})
    hits = resp.json().get("hits", [])
    s.output = f"Found {len(hits)} relevant chunks in {elapsed:.2f}s"
```

When you expand this step in the browser, `s.input` shows the user's raw question, and `s.output` shows how many clinic documents matched and how quickly.

**Step 2 — Prompt Construction:**
```python
async with cl.Step(name="Building prompt", type="run", show_input="json") as s:
    messages = build_messages(message.content, hits)
    s.input = messages   # shows full message list as JSON
    s.output = f"Constructed {len(messages)}-message prompt..."
```

Expand this step to see the exact system prompt + context chunks + user question that was sent to vLLM. This is the most educational step — students can see the full RAG-augmented prompt.

**Step 3 — LLM Generation:**
```python
# Streaming message created BEFORE the step, so tokens appear in main chat thread
response_msg = cl.Message(content="")
await response_msg.send()

async with cl.Step(name="LLM generation", type="run") as s:
    async with client.stream("POST", f"{VLLM_URL}/v1/chat/completions", ...) as stream:
        async for line in stream.aiter_lines():
            token = parse_sse(line)
            if token:
                await response_msg.stream_token(token)
```

:::note Why the streaming message is created before the step
If you create `response_msg` inside the `cl.Step` context, streaming tokens appear inside the collapsed step rather than in the main chat thread. By creating the message before entering the step, tokens stream visibly to the user while the step records generation metadata.
:::

All commands assume you are in the **repository root** (`302-llmops/`).

### Step A1: Build the Chainlit Docker image

```bash
docker build \
  -t kind-registry:5001/smile-dental-ui:v1.0.0 \
  course-code/labs/lab-05/solution/ui/
```

```bash
docker push kind-registry:5001/smile-dental-ui:v1.0.0
```

Build time: 2-3 minutes (installs Chainlit, httpx, and dependencies).

### Step A2: Deploy to Kubernetes

```bash
kubectl apply -f course-code/labs/lab-05/solution/k8s/
```

Expected output:
```
deployment.apps/chainlit-ui created
service/chainlit-ui created
```

Check pod status:

```bash
kubectl get pods -n llm-app -l app=chainlit-ui
```

The pod should be `Running 1/1` within about 30 seconds.

:::warning Chainlit requires --host 0.0.0.0
The Chainlit container image CMD includes `--host 0.0.0.0`. Without this flag, Chainlit binds to `127.0.0.1` inside the container, and the NodePort cannot forward traffic to it (WebSocket connections will fail with HTTP 403). The provided Dockerfile already includes this — do not remove it if you rebuild.
:::

### Step A3: Open the Smile Dental chat interface

Open your browser and navigate to:

```
http://localhost:30300
```

You should see the Smile Dental Clinic assistant welcome message:
> Welcome to **Smile Dental Clinic** assistant!

### Step A4: Try a dental query and explore glass-box mode

Send a question such as:
> How much does teeth whitening cost at Smile Dental?

After the response appears:

1. **Click on "Retrieving clinic documents"** — expand this step to see which dental documents scored highest in FAISS retrieval. Look for `TX-WHITE-01` (Teeth Whitening treatment) in the hits.

2. **Click on "Building prompt"** — expand to see the exact JSON messages array sent to vLLM. You'll see the system prompt, the retrieved context chunks injected as context, and the user's question.

3. **Click on "LLM generation"** — shows generation metadata.

Try a policy question next:
> What happens if I cancel my appointment?

Expand the retrieval step — you should see policy documents (`POLICY-*`) scoring highest rather than treatment documents. This confirms the semantic retrieval is working correctly.

---

## Part B: LLM Observability

### Why Observability Matters for LLMs

Traditional application metrics (CPU, memory, request rate) don't tell you what matters most for LLMs:

- **Time to First Token (TTFT)** — how long until the user sees the first word? This determines perceived responsiveness.
- **KV cache utilization** — are you close to OOM? High cache pressure predicts inference failures before they happen.
- **Request queue depth** — are requests stacking up because the model is slow? This predicts latency spikes.
- **Token throughput** — how many tokens per second? This determines your capacity ceiling.

vLLM 0.9.1 exposes all of these as Prometheus metrics with the prefix `vllm:` (with a colon, not an underscore).

:::warning vLLM metric prefix uses a colon, not an underscore
vLLM 0.9.1 metric names look like:
- `vllm:time_to_first_token_seconds` ✅ correct
- `vllm_request_ttft_seconds` ✗ old format (pre-v0.15.0)

If you see "No data" in a Grafana panel, check that your PromQL query uses `vllm:` (colon) prefix. The pre-built dashboard in this lab uses the correct names.
:::

:::note KV Cache metric name — vLLM CPU naming quirk
The KV Cache panel queries `vllm:gpu_cache_usage_perc`. Despite running on CPU, vLLM 0.9.1 uses this same metric name for both GPU and CPU backends. There is no separate `vllm:cpu_cache_usage_perc` metric. The value correctly reflects your CPU KV cache utilization (set by `VLLM_CPU_KVCACHE_SPACE=2`).
:::

### Architecture

```
vLLM Pod → :8000/metrics → Prometheus (scrapes every 30s) → Grafana (queries every 30s)
RAG Pod  → :8001/metrics ↗
Chainlit → :9090/metrics ↗

Prometheus discovers targets via ServiceMonitor CRDs (defined by the course code)
Grafana loads dashboards from ConfigMaps labeled grafana_dashboard: "1"
```

:::note Chainlit uses a separate metrics port
Chainlit registers a catch-all route `/{full_path:path}` that intercepts any `/metrics` path on port 8000. The `app.py` in this lab works around this by starting a standalone `prometheus_client` HTTP server on port **9090**. The Deployment exposes both ports, and the ServiceMonitor scrapes port 9090 for `chat_requests_total` and `chat_latency_seconds`.
:::

### Step B1: Install kube-prometheus-stack

```bash
bash course-code/labs/lab-06/solution/scripts/install-monitoring.sh
```

This installs `prometheus-community/kube-prometheus-stack` chart version 83.4.2 with:
- Grafana on NodePort 30400 (admin/prom-operator)
- Prometheus on NodePort 30500
- `serviceMonitorSelectorNilUsesHelmValues=false` — this critical flag allows Prometheus to discover ServiceMonitors from other namespaces (llm-serving, llm-app), not just the monitoring namespace

Installation takes 2-3 minutes. Wait for the command to return before proceeding.

```bash
# Confirm all monitoring pods are Running
kubectl get pods -n monitoring
```

### Step B2: Apply ServiceMonitors and the Grafana dashboard

```bash
kubectl apply -f course-code/labs/lab-06/solution/k8s/observability/
```

This creates:
- `ServiceMonitor/vllm-monitor` — scrapes vLLM `/metrics` every 30s
- `ServiceMonitor/retriever-monitor` — scrapes RAG retriever `/metrics` every 30s
- `ServiceMonitor/chainlit-monitor` — scrapes Chainlit metrics every 30s
- `ConfigMap/vllm-dashboard` — the Grafana dashboard JSON (labeled `grafana_dashboard: "1"` for auto-discovery)

Verify the ConfigMap is created:

```bash
kubectl get configmap vllm-dashboard -n monitoring
```

### Step B3: Open Grafana

Navigate to:
```
http://localhost:30400
```

Login with: **admin / prom-operator**

Go to **Dashboards** (the grid icon in the left sidebar) → **Browse** → look for **"Smile Dental — LLM Pipeline"**.

:::note Dashboard may take 1-2 minutes to appear
Grafana discovers dashboard ConfigMaps via a sidecar running every 60 seconds. If you don't see the dashboard immediately, wait a minute and refresh.
:::

### Step B4: Generate traffic and observe metrics

Two traffic generator scripts are provided. Run the **full pipeline script** to populate all panels — it calls the RAG retriever and vLLM in sequence, exactly as Chainlit does internally:

```bash
bash course-code/labs/lab-06/solution/scripts/generate-traffic-full.sh localhost 30100 30200 3
```

This sends 30 requests total (3 rounds × 10 queries), calling the RAG retriever for each query before sending the result to vLLM. While it runs (~5 minutes), open Grafana and watch the panels update.

Expected output:
```
=================================================
 Smile Dental Full Pipeline Traffic Generator
=================================================
 Retriever: http://localhost:30100
 vLLM:      http://localhost:30200
 Rounds:    3  |  Queries: 10 per round  |  Delay: 5s

 Panels populated:
   ✓ TTFT, TPOT, E2E Latency, Token Throughput
   ✓ Active & Queued Requests (KEDA signal)
   ✓ KV Cache Utilization
   ✓ RAG Retriever Query Rate
   ~ Chat Rate + Chat Latency: use browser at http://localhost:30300
=================================================

--- Round 1/3 ---
[1] How much does teeth whitening cost at Smile Dental?
     [3 docs] → At Smile Dental, we offer teeth whitening starting from ₹3,000...
...
=================================================
 Done: 30 requests, 0 errors
=================================================
```

To also populate the **Chat Request Rate** and **Chat End-to-End Latency** panels, send a few queries through the browser UI at `http://localhost:30300` while the script is running. Those panels track Chainlit-level traffic and require the `on_message` handler to execute.

:::note Two traffic scripts
- `generate-traffic-full.sh` — calls RAG retriever + vLLM in sequence (populates 7/9 panels)
- `generate-traffic.sh` — calls vLLM directly, no RAG retrieval (populates 6/9 panels, useful for isolated vLLM load testing)
:::

Return to Grafana and watch the panels update:

| Panel | What to look for |
|-------|-----------------|
| **Time to First Token (P95)** | Should be 1-5 seconds on CPU; spikes indicate slow requests |
| **End-to-End Request Latency (P95)** | Total vLLM request latency from receipt to response complete |
| **Active & Queued Requests** | Spikes to 1 during inference, returns to 0 when complete |
| **KV Cache Utilization** | Should stay well below 100% at `VLLM_CPU_KVCACHE_SPACE=2` |
| **Chat Request Rate** | Chainlit-level requests/sec; confirms traffic hitting the UI layer |
| **Chat End-to-End Latency (P95)** | Full pipeline latency: RAG retrieval + prompt construction + LLM generation |

## Verification

Confirm the full pipeline is working end-to-end:

```bash
# 1. Chainlit pod is running
kubectl get pods -n llm-app -l app=chainlit-ui
# Expected: 1/1 Running

# 2. Grafana is reachable
curl -s http://localhost:30400/api/health | python3 -c "import sys, json; print(json.load(sys.stdin))"
# Expected: {'commit': '...', 'database': 'ok', 'version': '...'}

# 3. Prometheus is scraping vLLM (check targets)
curl -s http://localhost:30500/api/v1/targets | python3 -c "
import sys, json
targets = json.load(sys.stdin)['data']['activeTargets']
vllm = [t for t in targets if 'llm-serving' in t.get('labels', {}).get('namespace', '')]
print(f'vLLM targets: {len(vllm)}')
for t in vllm:
    print(f'  {t[\"labels\"][\"job\"]}: {t[\"health\"]}')
"
# Expected: vllm-monitor: up

# 4. vLLM metric prefix check
curl -s http://localhost:30200/metrics | grep "^vllm:" | head -3
# Expected: lines starting with vllm: (colon, not underscore)
```

## After This Lab

You have completed the full Day 1 LLMOps pipeline:

| Component | URL | Status |
|-----------|-----|--------|
| RAG Retriever | `http://localhost:30100/search` | Running |
| vLLM API | `http://localhost:30200/v1/chat/completions` | Running |
| Smile Dental Chat | `http://localhost:30300` | Running |
| Grafana | `http://localhost:30400` | Running |
| Prometheus | `http://localhost:30500` | Running |

The pipeline:
1. User sends a question in Chainlit
2. Chainlit calls the RAG retriever → gets top-3 clinic documents
3. Chainlit assembles a prompt with the retrieved context and calls vLLM
4. vLLM streams tokens back → Chainlit streams them to the browser
5. All three services expose Prometheus metrics → Grafana shows TTFT, latency, cache utilization

The glass-box Chainlit interface means students can see every step of this pipeline from the browser — making the RAG + LLM architecture observable and understandable, not just functional.
