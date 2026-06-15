---
sidebar_position: 5
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Lab 04: Model Serving with vLLM + Chainlit Web UI

**Day 1 | Duration: ~75 minutes**

## Learning Objectives

- Deploy vLLM on Kubernetes using a plain Deployment (no KServe)
- Understand CPU inference constraints and the key vLLM configuration parameters
- Use the ImageVolume mount pattern to load the model from OCI into the serving pod
- Test the OpenAI-compatible `/v1/chat/completions` API with dental domain queries
- Deploy the Smile Dental Chainlit chat interface to Kubernetes
- Understand Chainlit's "glass-box" mode — expandable steps that reveal each pipeline stage

## What Is vLLM?

vLLM is a high-performance LLM inference engine originally designed for GPU serving. Its key innovation is **PagedAttention** — a memory management technique that treats the KV cache (the attention memory that grows as generation progresses) like virtual memory pages, eliminating memory fragmentation and enabling higher throughput.

For this course, we use the CPU version (`schoolofdevops/vllm-cpu-nonuma:0.9.1`) — a custom-built CPU-only image that works without any GPU hardware. CPU inference is slower than GPU (2-10 seconds per response instead of &lt;1 second), but it runs on any laptop with 16 GB RAM.

The critical property of vLLM for this course is its **OpenAI-compatible API**. The `/v1/chat/completions` endpoint accepts the same JSON format as OpenAI's API — the Chainlit UI in Part 2 of this lab can connect to vLLM using the same code it would use for GPT-4o.

## Why Plain Deployment, Not KServe?

KServe adds model lifecycle management, canary deployments, and autoscaling — features that matter in production but add significant setup complexity (Knative, Istio, cert-manager). For Day 1 of the course, a plain Kubernetes `Deployment + Service` gets vLLM running with fewer moving parts. We focus on understanding what vLLM does and how the OpenAI API works.

## Key Configuration Warnings

:::warning VLLM_CPU_KVCACHE_SPACE must be 2, not 4
The default KV cache allocation for vLLM is 4 GB. On KIND worker nodes with only 5 Gi memory limit, setting `VLLM_CPU_KVCACHE_SPACE=4` causes the pod to **OOM-kill during inference** (not at startup — it crashes when processing the first long request). The manifest in this lab sets it to `2`, which is safe on 5 Gi nodes.

Do not change this value during the workshop.
:::

:::warning Expect 2-3 minutes of NotReady after pod starts
Loading SmolLM2-135M (514 MB) into memory on CPU takes 60-180 seconds. The `readinessProbe` is configured with `initialDelaySeconds: 120` to account for this. During those 2-3 minutes, the pod shows as `Running` but not `Ready`. This is normal — do not delete and recreate the pod.
:::

## Deployment YAML Walkthrough

Open `course-code/labs/lab-04/solution/k8s/30-deploy-vllm.yaml`. Key sections explained:

**vLLM startup arguments:**
```yaml
args:
  - --model=/models/model   # path to model weights (from ImageVolume mount)
  - --host=0.0.0.0
  - --port=8000
  - --max-model-len=4096  # max total context length (prompt + response)
  - --served-model-name=smollm2-135m-finetuned  # name used in API calls
  - --dtype=float32       # float32 required for CPU — bfloat16 kernels not supported on CPU
  - --disable-frontend-multiprocessing  # required for CPU backend stability
  - --max-num-seqs=1      # only 1 concurrent request (CPU constraint)
  # Note: /metrics endpoint is always enabled in vLLM 0.9.1 — no flag needed
```

**Environment variables:**
```yaml
env:
  - name: VLLM_TARGET_DEVICE
    value: "cpu"
  - name: VLLM_CPU_KVCACHE_SPACE
    value: "2"    # NOT 4 — OOM risk on 5Gi KIND nodes
  - name: OMP_NUM_THREADS
    value: "4"    # controls CPU parallelism for inference
  - name: VLLM_CPU_OMP_THREADS_BIND
    value: "auto" # pins threads to physical cores for cache locality
```

**Readiness probe:**
```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 120   # wait 2 min before checking
  periodSeconds: 10
  failureThreshold: 18       # allow up to 3 more minutes after initial delay
```

**ImageVolume mount** (model from Lab 03):
```yaml
volumes:
  - name: model
    image:
      reference: kind-registry:5001/smollm2-135m-finetuned:v1.0.0
      pullPolicy: IfNotPresent
```

Kubernetes pulls the model OCI image to the node and mounts its filesystem at `/models`. vLLM reads from `/models/model` (the directory that was `COPY merged-model/ /model/` in the Dockerfile).

---

## Part 1: vLLM Serving

All commands assume you are in the **repository root** (`302-llmops/`).

### Step 1: Verify the model image is in the registry

```bash
docker images | grep smollm2-135m-finetuned
# Expected: kind-registry:5001/smollm2-135m-finetuned v1.0.0 ...
```

If missing, go back to Lab 03 and run the build script first.

### Step 2: Deploy vLLM

```bash
kubectl apply -f course-code/labs/lab-04/solution/k8s/
```

Expected output:
```
deployment.apps/vllm-smollm2 created
service/vllm-smollm2 created
```

### Step 3: Watch pod startup (expect 2-3 minutes)

```bash
kubectl get pods -n llm-serving -w
```

Typical progression:

```
NAME                             READY   STATUS    RESTARTS   AGE
vllm-smollm2-xxxxxxxxx-xxxxx    0/1     Running   0          0s
vllm-smollm2-xxxxxxxxx-xxxxx    0/1     Running   0          30s
vllm-smollm2-xxxxxxxxx-xxxxx    0/1     Running   0          90s
vllm-smollm2-xxxxxxxxx-xxxxx    1/1     Running   0          135s  ← Ready!
```

Press `Ctrl+C` when the pod shows `1/1 Running`.

:::tip Use this wait time
While vLLM loads, take 2-3 minutes to review the vLLM deployment YAML or preview the Chainlit UI code in Part 2.
:::

### Step 4: Check vLLM startup logs

```bash
kubectl logs -f deployment/vllm-smollm2 -n llm-serving
```

Look for these lines indicating successful startup:

```
INFO: vLLM API server version 0.9.1
Loading safetensors checkpoint shards: 100% Completed | 1/1
INFO: Loading weights took 0.81 seconds
INFO: Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000
```

Press `Ctrl+C` to exit the log stream.

### Step 5: Test with the provided script

```bash
bash course-code/labs/lab-04/solution/scripts/test-vllm.sh localhost 30200
```

The script runs three tests:
1. **Health check** — `GET /health` returns HTTP 200 (empty body)
2. **List models** — `GET /v1/models` confirms `smollm2-135m-finetuned` is loaded
3. **Chat completion** — asks "How much does teeth whitening cost?" and prints the response

Expected final output:
```
=== All vLLM tests passed ===
```

### Step 6: Manual curl test

Send a dental query directly:

```bash
curl -s http://localhost:30200/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "smollm2-135m-finetuned",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant for Smile Dental Clinic, Pune."},
      {"role": "user", "content": "What is the cancellation policy at Smile Dental?"}
    ],
    "max_tokens": 150,
    "temperature": 0.1
  }' | python3 -m json.tool
```

The response `choices[0].message.content` should reference Smile Dental's cancellation policy. If it does not — for example if it gives a generic answer — it means the model weights from Lab 02 did not load correctly.

### Verification (Part 1)

Confirm the service is accessible and responding:

```bash
# Health endpoint — returns HTTP 200 with empty body
curl -w "%{http_code}" http://localhost:30200/health
# 200

# Model list
curl http://localhost:30200/v1/models | python3 -c "
import sys, json
models = json.load(sys.stdin)
names = [m['id'] for m in models['data']]
print('Loaded models:', names)
assert 'smollm2-135m-finetuned' in names, 'Model not found!'
print('OK: model is loaded')
"

# Metrics endpoint (Lab 05 will scrape this)
curl http://localhost:30200/metrics | grep "vllm:" | head -5
```

The metrics endpoint should return lines starting with `vllm:` — for example `vllm:num_requests_running`. These are the Prometheus metrics that Lab 05 will scrape for the Grafana dashboard.

---

## Part 2: Chainlit Web UI

### Why Chainlit for This Course?

Chainlit is a Python-native chat framework that integrates directly with async Python code. No frontend JavaScript, no separate REST layer — your `on_message` handler is also the API handler. For this course, the key feature is **Steps**: collapsible panels in the chat UI that reveal what each pipeline stage received and produced.

This makes the Chainlit UI "glass-box" rather than "black-box" — a deliberate pedagogical choice. Students can see exactly which documents the RAG retriever returned, what prompt was assembled and sent to vLLM, and how long each stage took. This visibility is essential for understanding LLMOps: when a response is wrong, you can trace back to see whether the retriever found relevant documents, whether the prompt was correctly constructed, or whether vLLM generated something unexpected.

### How app.py Works

Open `course-code/labs/lab-04/solution/ui/app.py`. The handler for incoming messages (`on_message`) runs three pipeline stages, each wrapped in a `cl.Step`:

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
  course-code/labs/lab-04/solution/ui/
```

```bash
docker push kind-registry:5001/smile-dental-ui:v1.0.0
```

Build time: 2-3 minutes (installs Chainlit, httpx, and dependencies).

### Step A2: Deploy to Kubernetes

```bash
kubectl apply -f course-code/labs/lab-04/solution/k8s/
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

## Verification

Confirm the full vLLM + Chainlit stack is working end-to-end:

```bash
# 1. vLLM service
curl -w "%{http_code}" http://localhost:30200/health
# 200

# 2. Chainlit pod is running
kubectl get pods -n llm-app -l app=chainlit-ui
# Expected: 1/1 Running

# 3. vLLM metrics (Lab 05 will scrape these)
curl http://localhost:30200/metrics | grep "^vllm:" | head -3
# Expected: lines starting with vllm: (colon, not underscore)
```

## After This Lab

| Resource | Status |
|----------|--------|
| `vllm-smollm2` Deployment | Running (1/1) in `llm-serving` namespace |
| `vllm-smollm2` Service | NodePort 30200 |
| `chainlit-ui` Deployment | Running (1/1) in `llm-app` namespace |
| `chainlit-ui` Service | NodePort 30300 |
| API endpoint | `http://localhost:30200/v1/chat/completions` |
| Chat UI | `http://localhost:30300` |

**Continue to Lab 05** to install Prometheus and Grafana and observe LLM-specific metrics (TTFT, KV cache, request throughput) from the vLLM, retriever, and Chainlit services.

{/* D-19 PATTERN-A TEASER PLACEHOLDER (final wording lands in plan 02-07 task 3) */}
