# Phase 2: LLMOps Labs (Day 1) - Research

**Researched:** 2026-04-12
**Domain:** End-to-end LLMOps pipeline — RAG, LoRA fine-tuning, OCI packaging, vLLM serving, Chainlit UI, Prometheus/Grafana observability on Kubernetes (CPU-only KIND)
**Confidence:** HIGH (core stack decisions verified against PyPI, Docker Hub, and official source repositories)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Keep Indian context (INR, Pune) — rename clinic from "Atharva" to "Smile Dental". No globalization needed.
- **D-02:** Richer dataset than current course: 10-15 treatments, 8-10 policies, 10+ FAQs, plus mock appointment slots and doctor schedules (for Phase 3 Hermes Agent).
- **D-03:** Include appointment data now so Phase 3 doesn't need to extend the dataset. Doctor names, availability windows, specializations.
- **D-04:** Use Chainlit's built-in Step feature for glass-box mode — collapsible panels showing RAG context retrieved, LLM prompt sent, raw response, and timing per step. Native support, minimal custom code.
- **D-05:** Branded Smile Dental UI — logo, dental-themed colors, welcome message mentioning the clinic.
- **D-06:** UI-04 requirement (glass box) implemented via Chainlit Steps — students can expand each step to see internals.
- **D-07:** One lab per topic, 6 labs total for Day 1: Lab 01 (Synthetic data + FAISS RAG retriever), Lab 02 (CPU LoRA fine-tuning SmolLM2-135M), Lab 03 (OCI model packaging ImageVolumes), Lab 04 (vLLM model serving), Lab 05 (Chainlit web UI glass-box), Lab 06 (Prometheus + Grafana observability).
- **D-08:** Skeleton starters — starter/ has directory structure + empty placeholder files. Solution/ has full working code. Students follow lab guide which explains the code, then copy from solution/.
- **D-09:** Python application code PROVIDED in solution/. Students copy, not write.
- **D-10:** Plain K8s Deployment + Service for vLLM serving — no KServe.
- **D-11:** vLLM 0.19.0 (upgrade from 0.9.1). Use `vllm/vllm-openai-cpu:v0.19.0-x86_64` (confirmed on Docker Hub). Fall back to `v0.19.0-arm64` for Apple Silicon.
- **D-12:** vLLM Router is stretch goal, NOT mandatory for v1.
- FAISS for vector store (zero overhead, in-process)
- SmolLM2-135M-Instruct for fine-tuning
- config.env has CLUSTER_NAME, namespaces, model references
- Docusaurus tabs for OS-specific commands
- Generic namespaces: llm-serving, llm-app, monitoring
- Solution KIND config uses ./llmops-project relative path

### Claude's Discretion

- Exact Chainlit theme colors and logo design
- FAISS index parameters (dimension, metric)
- LoRA hyperparameters (rank, alpha, learning rate)
- Prometheus ServiceMonitor vs PodMonitor choice
- Grafana dashboard layout and panel arrangement
- vLLM CPU-specific flags (kv-cache, max-model-len, OMP threads)

### Deferred Ideas (OUT OF SCOPE)

- vLLM Router as alternative to KServe — evaluate if needed, but not in v1 scope
- Agent-specific tools in the dataset (appointment booking logic) — data is included but tool implementation is Phase 3
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RAG-01 | Synthetic data generation for Smile Dental clinic domain (treatments, policies, FAQs) | Existing synth_data.py pattern from lab01.md; rename Atharva→Smile Dental, expand to D-02 spec |
| RAG-02 | FAISS vector index built from clinic data using sentence-transformers embeddings | faiss-cpu 1.13.2 + sentence-transformers 5.4.1; all-MiniLM-L6-v2 pattern verified |
| RAG-03 | FastAPI retriever service deployed on Kubernetes with health checks | FastAPI 0.135.3 + prometheus-client 0.25.0; existing retriever.py pattern reusable |
| RAG-04 | End-to-end RAG query demonstrating retrieval + LLM generation | Chainlit Step → retriever call → vLLM call → streaming response |
| TUNE-01 | CPU LoRA fine-tuning of SmolLM2-135M on synthetic dental clinic chat data | PEFT 0.19.0 + transformers 5.5.4 + torch 2.11.0; existing train_lora.py reusable with updated versions |
| TUNE-02 | LoRA adapter merge into base model producing a single model folder | merge_and_unload() from PEFT; existing merge_lora.py pattern |
| TUNE-03 | Training job runs as Kubernetes Job with resource limits | K8s Job YAML with CPU/memory limits; existing job-train-lora.yaml pattern |
| PKG-01 | Merged model packaged as OCI image | FROM alpine:3.20 Dockerfile.model-asset pattern verified from lab03.md |
| PKG-02 | Model mounted in Kubernetes via ImageVolumes | KIND cluster already has ImageVolume gate from Phase 1 lab-00 |
| SERVE-01 | vLLM serving fine-tuned model with OpenAI-compatible API | vllm/vllm-openai-cpu:v0.19.0-x86_64; plain K8s Deployment + NodePort |
| SERVE-02 | Plain K8s Deployment for vLLM (decision D-10, replaces KServe) | Deployment + Service YAML with CPU env vars; readinessProbe initialDelaySeconds: 120 |
| SERVE-03 | End-to-end inference test (prompt → vLLM → response) via curl and web UI | curl /v1/chat/completions + Chainlit UI validation |
| UI-01 | Chainlit chat interface connected to RAG + LLM pipeline | Chainlit 2.11.0 + @cl.on_message + cl.Step() context manager |
| UI-02 | Chat UI deployed as Kubernetes Deployment with NodePort access | Chainlit requires --host 0.0.0.0; NodePort 30300 pattern |
| UI-03 | Streaming responses displayed in real-time | cl.Message.stream_token() + vLLM stream=True; WebSocket via Chainlit |
| OBS-01 | Prometheus + Grafana stack deployed via Helm (kube-prometheus-stack) | kube-prometheus-stack chart 83.4.2; same helm install from lab05.md |
| OBS-02 | vLLM metrics scraped (TTFT, latency, tokens/sec, request counts) | vLLM v1 metrics API: `vllm:time_to_first_token_seconds`, `vllm:e2e_request_latency_seconds`, etc. |
| OBS-03 | Chat API and Retriever instrumented with Prometheus metrics | prometheus-client 0.25.0; existing chat_api.py + retriever.py patterns |
| OBS-04 | Grafana dashboard for LLM workload visibility | ConfigMap-based dashboard JSON; vLLM metric names confirmed |
</phase_requirements>

---

## Summary

Phase 2 builds the full LLMOps Day 1 pipeline across 6 sequential labs. The existing lab content (`llmops-labuide/docs/lab01.md` through `lab05.md`) provides the foundation — most code is reusable with targeted changes: rename Atharva→Smile Dental, expand the dataset, upgrade vLLM from the abandoned `schoolofdevops/vllm-cpu-nonuma:0.9.1` to the official `vllm/vllm-openai-cpu:v0.19.0-x86_64`, update ML library versions, replace KServe with plain Deployment, and add Chainlit Steps for glass-box mode.

The most critical version change is vLLM: the official CPU Docker image (`vllm/vllm-openai-cpu`) is confirmed on Docker Hub with v0.19.0 tags for both x86_64 and arm64. The image uses Ubuntu 22.04 base with Python 3.12 and torch 2.11.0 — no NUMA dependency issues that plagued the old schoolofdevops build. The vLLM v1 metrics API uses `vllm:` prefix (colon not underscore) which differs from the metric names in the existing lab05 code; this must be corrected in the ServiceMonitor and Grafana panel PromQL expressions.

Chainlit 2.11.0 is confirmed community-maintained (original team stepped back May 2025) and stable. The Step API supports both `@cl.step` decorator and `cl.Step()` context manager patterns with `default_open`, `show_input`, and `stream_token` capabilities — sufficient for glass-box mode without custom CSS.

**Primary recommendation:** Reuse the existing lab code as templates, execute targeted changes per lab, and validate the full pipeline end-to-end on a KIND cluster before finalizing lab content.

---

## Standard Stack

### Core — Lab 01 (RAG)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| faiss-cpu | 1.13.2 | In-process vector search | Zero overhead, no separate K8s service; confirmed decision FAISS over Qdrant |
| sentence-transformers | 5.4.1 | all-MiniLM-L6-v2 embeddings | 22MB, 14.7ms/1K tokens CPU; standard embedding model |
| FastAPI | 0.135.3 | Retriever REST API | Standard ML serving framework; existing code pattern |
| prometheus-client | 0.25.0 | /metrics endpoint instrumentation | Required for OBS-03 |
| numpy | 1.26.4 | Numerical backend | Pin to avoid FAISS/scipy compatibility issues with NumPy 2.x |

**Installation:**
```bash
pip install faiss-cpu==1.13.2 sentence-transformers==5.4.1 fastapi[standard]==0.135.3 prometheus-client==0.25.0 numpy==1.26.4
```

### Core — Lab 02 (Fine-Tuning)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| torch | 2.11.0 (CPU) | Deep learning backend | Latest stable; CPU wheel with MKL; matches vLLM-cpu Dockerfile |
| transformers | 5.5.4 | Model loading, SmolLM2 tokenizer | Required by PEFT; latest stable |
| peft | 0.19.0 | LoRA fine-tuning | Latest stable; stable merge_and_unload() |
| accelerate | 1.13.0 | Training loop management | Required by PEFT for CPU training |
| datasets | 4.8.4 | Loading JSONL training data | Standard HuggingFace data pipeline |

**Installation (training container):**
```bash
pip install "torch==2.11.0" --index-url https://download.pytorch.org/whl/cpu
pip install transformers==5.5.4 peft==0.19.0 accelerate==1.13.0 datasets==4.8.4
```

### Core — Lab 03 (OCI Packaging)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| alpine:3.20 | base image | Minimal model asset image | ~5MB base; no app code, just /model files |

**Pattern:** `Dockerfile.model-asset` uses `FROM alpine:3.20`, `COPY merged-model/ /model/`, no entrypoint needed.

### Core — Lab 04 (Serving)

| Image | Tag | Purpose | Why Standard |
|-------|-----|---------|--------------|
| vllm/vllm-openai-cpu | v0.19.0-x86_64 | LLM inference serving | Official CPU image; confirmed on Docker Hub; supersedes schoolofdevops build |
| vllm/vllm-openai-cpu | v0.19.0-arm64 | Same for Apple Silicon | Multi-arch; use on macOS dev machines if needed |

### Core — Lab 05 (Chainlit UI)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| chainlit | 2.11.0 | Chat web UI with Steps | Latest stable; community-maintained; Step API confirmed |
| httpx | latest | Async HTTP client for retriever/vLLM calls | Required for async streaming |

**Installation:**
```bash
pip install chainlit==2.11.0 httpx
```

### Core — Lab 06 (Observability)

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| kube-prometheus-stack | 83.4.2 (chart) | Prometheus + Grafana + AlertManager | Single Helm chart; Prometheus Operator 0.90.1, Grafana 11.6.1 |

**Installation:**
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install kps -n monitoring \
  prometheus-community/kube-prometheus-stack \
  --create-namespace \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30400 \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30500 \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

### Version Verification (verified 2026-04-12)

```bash
# Verify current versions before use:
pip index versions faiss-cpu 2>/dev/null | head -1    # 1.13.2
pip index versions sentence-transformers 2>/dev/null | head -1  # 5.4.1
pip index versions peft 2>/dev/null | head -1          # 0.19.0
pip index versions transformers 2>/dev/null | head -1  # 5.5.4
pip index versions chainlit 2>/dev/null | head -1      # 2.11.0
docker pull vllm/vllm-openai-cpu:v0.19.0-x86_64       # confirmed available
```

---

## Architecture Patterns

### Lab Directory Structure (carrying forward Phase 1 conventions)

```
course-code/labs/
├── lab-01/                          # RAG: Synthetic data + FAISS retriever
│   ├── starter/
│   │   ├── datasets/clinic/         # empty placeholder files
│   │   ├── rag/                     # build_index.py, retriever.py (empty)
│   │   ├── tools/                   # synth_data.py (empty)
│   │   └── k8s/                     # YAML manifests (empty)
│   └── solution/
│       ├── datasets/clinic/         # Smile Dental synthetic data
│       ├── rag/build_index.py       # FAISS index builder
│       ├── rag/retriever.py         # FastAPI retriever service
│       ├── tools/synth_data.py      # Data generation script
│       └── k8s/                     # K8s Deployment + Service YAML
├── lab-02/                          # Fine-tuning: CPU LoRA
│   ├── starter/training/            # Dockerfile, empty train/merge scripts
│   └── solution/training/           # train_lora.py, merge_lora.py, Dockerfile
├── lab-03/                          # OCI packaging: model asset image
│   ├── starter/                     # Dockerfile.model-asset (empty sections)
│   └── solution/                    # Complete Dockerfile + build_model_image.sh
├── lab-04/                          # Serving: plain K8s Deployment for vLLM
│   ├── starter/k8s/                 # deploy-vllm.yaml (empty), svc-vllm.yaml
│   └── solution/k8s/                # Complete YAML with CPU env vars + probes
├── lab-05/                          # Web UI: Chainlit glass-box
│   ├── starter/ui/                  # app.py (empty), Dockerfile
│   └── solution/ui/                 # Full Chainlit app with Steps
└── lab-06/                          # Observability: Prometheus + Grafana
    ├── starter/k8s/observability/   # ServiceMonitor YAMLs (empty)
    └── solution/k8s/observability/  # Complete ServiceMonitors + dashboard CM
```

### Pattern 1: Chainlit Steps for Glass-Box Mode

**What:** Each RAG/LLM pipeline stage is wrapped in a `cl.Step()` context manager to produce collapsible UI panels showing inputs, outputs, and timing.

**When to use:** Lab 05 (Chainlit UI). Also applies to any future agentic pipeline visualization.

**Example:**
```python
# Source: Chainlit step.py (GitHub Chainlit/chainlit, verified 2026-04-12)
import chainlit as cl
import httpx, time

@cl.on_message
async def on_message(message: cl.Message):
    # Step 1: RAG Retrieval
    async with cl.Step(
        name="RAG Retrieval",
        type="tool",
        show_input=True,
        default_open=False,
    ) as retrieval_step:
        retrieval_step.input = message.content
        t0 = time.monotonic()
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(
                f"{RETRIEVER_URL}/search",
                json={"query": message.content, "k": 3}
            )
        hits = resp.json().get("hits", [])
        retrieval_step.output = f"Retrieved {len(hits)} chunks in {time.monotonic()-t0:.2f}s"
        # retrieval_step is auto-sent on __aexit__

    # Step 2: Prompt Construction
    async with cl.Step(name="Prompt", type="run", show_input="json") as prompt_step:
        messages = build_messages(message.content, hits)
        prompt_step.input = messages  # shown as collapsible JSON
        prompt_step.output = f"{len(messages)} messages constructed"

    # Step 3: LLM Generation (streaming)
    async with cl.Step(name="LLM Response", type="run") as llm_step:
        final_msg = cl.Message(content="")
        await final_msg.send()
        async with httpx.AsyncClient(timeout=120) as client:
            async with client.stream(
                "POST",
                f"{VLLM_URL}/v1/chat/completions",
                json={**payload, "stream": True}
            ) as stream:
                async for chunk in stream.aiter_lines():
                    if chunk.startswith("data: "):
                        token = parse_sse_token(chunk)
                        await final_msg.stream_token(token)
        await final_msg.update()
        llm_step.output = "Generation complete"
```

**Key Step constructor parameters (verified from chainlit/step.py):**
```python
cl.Step(
    name: str,                        # Display name in UI
    type: str,                        # "tool", "run", "undefined"
    show_input: Union[bool, str],     # True, False, "json", "python", "sql"
    default_open: bool = False,       # Collapsed by default (True = open)
    auto_collapse: bool = False,      # Auto-collapse when done
    language: str = None,             # Code syntax highlighting in output
)
```

### Pattern 2: vLLM Plain K8s Deployment (CPU)

**What:** Replace KServe InferenceService with a plain K8s Deployment + Service for vLLM serving. Simpler, fewer moving parts, same API surface.

**When to use:** Lab 04. Decision D-10.

**Example:**
```yaml
# Source: vllm/vllm-openai-cpu:v0.19.0 verified on Docker Hub 2026-04-12
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-smollm2
  namespace: llm-serving
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vllm
  template:
    metadata:
      labels:
        app: vllm
    spec:
      nodeName: llmops-kind-worker   # pin to worker node (KIND constraint)
      containers:
      - name: vllm
        image: vllm/vllm-openai-cpu:v0.19.0-x86_64
        args:
          - /models/model
          - --host=0.0.0.0
          - --port=8000
          - --max-model-len=4096
          - --served-model-name=smollm2-135m-finetuned
          - --dtype=bfloat16
          - --disable-frontend-multiprocessing
          - --max-num-seqs=1
          - --enable-metrics          # exposes /metrics for Prometheus
        env:
          - name: VLLM_TARGET_DEVICE
            value: "cpu"
          - name: VLLM_CPU_KVCACHE_SPACE
            value: "2"                # GiB; 4 GiB default causes OOM on small nodes
          - name: OMP_NUM_THREADS
            value: "4"
          - name: VLLM_CPU_OMP_THREADS_BIND
            value: "auto"
        ports:
          - containerPort: 8000
        resources:
          requests:
            cpu: "4"
            memory: "4Gi"
          limits:
            cpu: "4"
            memory: "5Gi"
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 120   # model loading 60-180s on CPU
          periodSeconds: 10
          failureThreshold: 18       # 3 minutes total before giving up
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 180
          periodSeconds: 15
          failureThreshold: 10
        volumeMounts:
          - name: model
            mountPath: /models
            readOnly: true
      volumes:
        - name: model
          image:
            reference: kind-registry:5001/smollm2-135m-finetuned:v1
            pullPolicy: IfNotPresent
---
apiVersion: v1
kind: Service
metadata:
  name: vllm-smollm2
  namespace: llm-serving
spec:
  type: NodePort
  selector:
    app: vllm
  ports:
    - name: http
      port: 8000
      targetPort: 8000
      nodePort: 30200
```

### Pattern 3: FAISS Index Build + Persist

**What:** Build FAISS index once, serialize to disk. FastAPI retriever loads from disk on startup — 10x faster than rebuilding.

**When to use:** Lab 01.

**Example:**
```python
# Source: existing lab01.md code patterns (course repo)
import faiss
import numpy as np
from sentence_transformers import SentenceTransformer

def build_and_save_index(chunks: list[dict], output_path: str):
    model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
    texts = [c["text"] for c in chunks]
    embeddings = model.encode(texts, convert_to_numpy=True, normalize_embeddings=True)

    # Use IndexFlatIP for cosine similarity (normalized vectors → inner product = cosine)
    dim = embeddings.shape[1]          # 384 for all-MiniLM-L6-v2
    index = faiss.IndexFlatIP(dim)
    index.add(embeddings.astype(np.float32))

    faiss.write_index(index, f"{output_path}/faiss.index")
    # Also save metadata: doc_id, section, text for each chunk
    with open(f"{output_path}/metadata.json", "w") as f:
        json.dump(chunks, f, ensure_ascii=False, indent=2)
```

### Pattern 4: Prometheus ServiceMonitor for vLLM

**What:** ServiceMonitor CRD from kube-prometheus-stack instructs Prometheus to scrape vLLM metrics.

**Critical detail:** vLLM v1 exposes metrics at `GET /metrics` with the `vllm:` prefix (colon separator, not underscore). The existing lab05 code uses `chat_end_to_end_latency_seconds` (application metrics from prometheus-client) — those keep underscore naming. Only vLLM's own metrics use the `vllm:` prefix.

**Example:**
```yaml
# Lab 06 — ServiceMonitor for vLLM
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: vllm-monitor
  namespace: monitoring
spec:
  namespaceSelector:
    matchNames: [llm-serving]
  selector:
    matchLabels:
      app: vllm
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
```

### Pattern 5: Chainlit Branded UI Configuration

**What:** `.chainlit/config.toml` sets app name, chain-of-thought display mode, and CSS customization path.

**Example:**
```toml
# .chainlit/config.toml
[project]
enable_telemetry = false

[features]
# Disable authentication for demo purposes
multi_modal = false

[UI]
name = "Smile Dental Assistant"
description = "Your AI-powered dental clinic assistant"
default_theme = "dark"
layout = "default"
cot = "full"                      # show full chain of thought (Steps)
custom_css = "/public/smile-dental.css"
logo_file_url = "/public/smile-dental-logo.svg"
```

### Anti-Patterns to Avoid

- **Hardcoded REPLACE_ placeholders in YAML:** Use `envsubst` with `config.env` instead. Cascading failures when students miss substitutions.
- **No `readinessProbe.initialDelaySeconds` on vLLM:** Default probe fires immediately; SmolLM2 takes 60-180s to load on CPU — pod enters CrashLoopBackOff before model is ready.
- **Building FAISS index inside FastAPI startup handler:** Causes 30+ second pod startup delay; build index in a K8s Job, mount result as a volume or bake into image.
- **Inline code >20 lines in lab docs:** Use the starter/solution pattern — docs reference files, never inline them.
- **Using vLLM `--dtype=float16` on CPU:** `bfloat16` is preferred on modern x86 CPUs (AVX512BF16); float16 can cause NaN issues without GPU half-precision hardware. Check model compatibility.
- **Setting VLLM_CPU_KVCACHE_SPACE=4 (default):** OOM on KIND nodes with 5Gi memory limit. Use `2` for SmolLM2-135M with max-model-len=4096.
- **Using `vllm:` metric names in prometheus-client instrumentation:** Only vLLM's own internal metrics use this prefix. Application metrics (chat_api, retriever) use standard underscore naming.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Vector similarity search | Custom cosine similarity loop | FAISS IndexFlatIP | FAISS handles chunking, batching, memory layout — custom is 100x slower |
| Chat UI with streaming | Custom React + WebSocket | Chainlit | 3-6 weeks of frontend scope vs. 30 lines of Python |
| LLM metrics collection | Custom request timing code | `--enable-metrics` flag on vLLM | vLLM exposes 15+ detailed metrics including TTFT histograms automatically |
| Prometheus scraping config | Manual HTTP polling | ServiceMonitor CRD | kube-prometheus-stack operator handles scraping, relabeling, storage |
| LoRA adapter serialization | Custom checkpoint format | PEFT `merge_and_unload()` | PEFT handles optimizer state, weight merging, safetensors format |
| OCI image size optimization | Multi-stage build tuning | Alpine base + COPY weights only | alpine:3.20 base is ~5MB; just COPY the model folder |
| Token streaming | Server-Sent Events parsing | vLLM stream=True + httpx streaming | SSE parsing has many edge cases (empty lines, reconnect, heartbeats) |

**Key insight:** The existing lab code already correctly avoids hand-rolling most of these. The rewrite maintains that discipline — students understand the concepts, not implement the infrastructure.

---

## Common Pitfalls

### Pitfall 1: vLLM CPU Image — Wrong Image Name (Critical)

**What goes wrong:** The existing `course-code/config.env` still references `schoolofdevops/vllm-cpu-nonuma:0.9.1` and `COURSE_VERSIONS.md` mentions the same abandoned image. Any student using the old config will fail on `docker pull` (image abandoned, no new builds).

**Why it happens:** Phase 1 created these files before the STACK.md research confirmed the correct image. `COURSE_VERSIONS.md` has an internal inconsistency — the "vLLM" row says `v0.19.0` but the image field still references the old tag.

**How to avoid:** Phase 2 Wave 0 must update:
- `course-code/config.env`: `VLLM_IMAGE=vllm/vllm-openai-cpu:v0.19.0-x86_64`
- `course-code/COURSE_VERSIONS.md`: Update vLLM row image field

**Warning signs:** `docker pull schoolofdevops/vllm-cpu-nonuma:0.9.1` fails or returns a very old image.

---

### Pitfall 2: vLLM CPU KV Cache OOM (from PITFALLS.md — confirmed critical)

**What goes wrong:** Default `VLLM_CPU_KVCACHE_SPACE` is 4 GiB. KIND worker nodes with 5Gi memory limits OOM-kill the vLLM pod during inference, not during startup. Error message references GPU memory terms, confusing students.

**How to avoid:** Set `VLLM_CPU_KVCACHE_SPACE=2` in the Deployment env vars. Set `--max-model-len=4096`. Both are already in the research Pattern 2 example above.

---

### Pitfall 3: vLLM v1 Metrics Use `vllm:` Prefix (Colon, Not Underscore)

**What goes wrong:** The existing lab05 ServiceMonitor and Grafana dashboard PromQL expressions will need updating. The existing code uses metric names like `vllm_request_ttft_seconds` (underscore format from older vLLM). In vLLM v1 (0.19.x), the correct metric names are `vllm:time_to_first_token_seconds`, `vllm:e2e_request_latency_seconds`.

**Why it happens:** vLLM v1 introduced a new metrics API that reorganized metric naming conventions. Old dashboard JSON files will silently show "no data" in Grafana panels.

**How to avoid:** Use the confirmed metric names from vLLM v1 `loggers.py`:
- TTFT: `vllm:time_to_first_token_seconds` (Histogram)
- E2E latency: `vllm:e2e_request_latency_seconds` (Histogram)
- Token throughput: `rate(vllm:generation_tokens[1m])`
- Prompt tokens: `rate(vllm:prompt_tokens[1m])`
- Running requests: `vllm:num_requests_running` (Gauge)
- Waiting requests: `vllm:num_requests_waiting` (Gauge)
- KV cache usage: `vllm:kv_cache_usage_perc` (Gauge)

---

### Pitfall 4: CPU LoRA Training Time Kills Workshop Pacing (from PITFALLS.md)

**What goes wrong:** LoRA fine-tuning on CPU at default batch sizes takes 30-120 minutes. Workshop loses the room.

**How to avoid:**
- Reduce dataset to 200-500 synthetic Q&A examples (dental FAQ scale is already small enough)
- Default training config: `max_steps=50`, `per_device_train_batch_size=1`, `gradient_accumulation_steps=4`
- In lab guide: "Start training, switch to the concept slides — we'll come back in 15 minutes"
- Provide pre-trained checkpoint in `starter/lab-02/` for students who miss timing
- Add `caffeinate -i &` (macOS) or equivalent to lab setup section to prevent sleep

---

### Pitfall 5: Chainlit WebSocket Fails on Kubernetes NodePort Without Correct Host

**What goes wrong:** Chainlit requires `--host 0.0.0.0` to accept connections from outside the pod. Without it, the NodePort service is reachable but WebSocket connections are refused with a 403.

**How to avoid:** In the Chainlit Deployment CMD:
```yaml
command: ["chainlit", "run", "app.py", "--host", "0.0.0.0", "--port", "8000"]
```

---

### Pitfall 6: Cross-Lab Artifact Dependency Chain (from PITFALLS.md)

**What goes wrong:** Lab 02 output → Lab 03 → Lab 04. If training produces a different `RUN_ID`, the OCI image build and Deployment YAML all break.

**How to avoid:**
- `config.env` holds `MODEL_IMAGE_TAG` as single source of truth
- Pre-built artifacts at each lab entry point (merged model OCI image pre-pushed to kind-registry)
- Lab 02 starter includes a `checkpoint-50/` pre-trained checkpoint so students can skip training if needed

---

### Pitfall 7: vLLM v0.19.0 CPU Dockerfile Uses Python 3.12, Not 3.11

**What goes wrong:** The training container uses Python 3.11 (course standard). The vLLM CPU Docker image uses Python 3.12 by default. No conflict at serving time (they're separate containers), but students may try to install vLLM into the training container for testing — this will fail.

**How to avoid:** Make explicit in lab content: vLLM runs in its own container (`vllm/vllm-openai-cpu`). The training + retriever containers use Python 3.11. Never `pip install vllm` in training or retriever Dockerfiles.

---

### Pitfall 8: PEFT 0.12.0 → 0.19.0 Breaking Changes in Training Config

**What goes wrong:** The existing `training/Dockerfile` pins `peft==0.12.0 transformers==4.43.3 torch==2.3.1`. These are 2+ years old. PEFT 0.19.0 has a different `LoraConfig` parameter namespace; some arguments may be renamed or removed.

**How to avoid:**
- Verify `LoraConfig` signature against PEFT 0.19.0 release notes before finalizing lab code
- Key parameters that are stable: `r`, `lora_alpha`, `target_modules`, `lora_dropout`, `bias`, `task_type`
- `merge_and_unload()` is confirmed stable in PEFT 0.14+

**Recommended training config for SmolLM2-135M:**
```python
from peft import LoraConfig, get_peft_model, TaskType

lora_config = LoraConfig(
    r=8,                          # rank — 8 is small enough for CPU
    lora_alpha=16,                # scaling factor
    target_modules=["q_proj", "v_proj"],  # SmolLM2 attention modules
    lora_dropout=0.05,
    bias="none",
    task_type=TaskType.CAUSAL_LM,
)
```

---

## Code Examples

### Smile Dental Synthetic Data Structure (expanded per D-02)

```python
# datasets/clinic/treatments.json (10-15 treatments)
# Rename: Atharva Dental Clinic → Smile Dental Clinic, Pune
# Add specializations for Phase 3 doctor schedules:
{
  "code": "TX-ORTHO-01",
  "name": "Braces / Orthodontic Treatment",
  "category": "Orthodontics",
  "specialist": "Orthodontist",
  "indications": ["Misaligned teeth", "Spacing issues", "Bite problems"],
  "duration_minutes": 60,
  "visits": "12-24 (monthly)",
  "price_band_inr": [25000, 80000],
  "aftercare": ["Monthly tightening", "Avoid sticky foods"],
}

# datasets/clinic/doctors.json (new for Phase 3 prep)
[
  {
    "id": "DR-001",
    "name": "Dr. Priya Sharma",
    "specialization": "General Dentistry",
    "availability": {
      "monday": ["09:30", "11:00", "14:00", "16:30"],
      "tuesday": ["09:30", "11:00", "14:00"],
      "wednesday": ["09:30", "11:00", "14:00", "16:30"],
      "thursday": ["09:30", "11:00"],
      "friday": ["09:30", "11:00", "14:00", "16:30"],
      "saturday": ["09:30", "11:00"]
    }
  }
]
```

### Chainlit App Structure (Lab 05)

```python
# solution/ui/app.py — Smile Dental Chainlit App
# Source: Chainlit 2.11.0 docs + step.py (verified 2026-04-12)

import chainlit as cl
import httpx, os, time

RETRIEVER_URL = os.getenv("RETRIEVER_URL", "http://rag-retriever.llm-app.svc.cluster.local:8001")
VLLM_URL = os.getenv("VLLM_URL", "http://vllm-smollm2.llm-serving.svc.cluster.local:8000")
MODEL_NAME = os.getenv("MODEL_NAME", "smollm2-135m-finetuned")

@cl.on_chat_start
async def on_chat_start():
    await cl.Message(
        content=(
            "Welcome to **Smile Dental Clinic** assistant!\n\n"
            "I can help you with information about treatments, pricing (INR), "
            "appointment policies, and general dental health questions.\n\n"
            "_Expand the steps below each answer to see how I found the information._"
        )
    ).send()

@cl.on_message
async def on_message(message: cl.Message):
    # Step 1 — RAG Retrieval
    async with cl.Step(name="Retrieving clinic documents", type="tool", default_open=False) as s:
        s.input = message.content
        t0 = time.monotonic()
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(f"{RETRIEVER_URL}/search",
                                     json={"query": message.content, "k": 3})
        hits = resp.json().get("hits", [])
        elapsed = time.monotonic() - t0
        s.output = f"Found {len(hits)} relevant chunks in {elapsed:.2f}s"

    # Step 2 — Prompt Construction
    async with cl.Step(name="Building prompt", type="run", show_input="json") as s:
        messages = build_messages(message.content, hits)
        s.input = messages
        s.output = f"Constructed {len(messages)}-message prompt"

    # Step 3 — LLM Generation (streaming)
    response_msg = cl.Message(content="")
    await response_msg.send()
    async with cl.Step(name="LLM generation", type="run") as s:
        async with httpx.AsyncClient(timeout=120) as client:
            async with client.stream("POST", f"{VLLM_URL}/v1/chat/completions",
                json={"model": MODEL_NAME, "messages": messages,
                      "max_tokens": 300, "temperature": 0.1, "stream": True}
            ) as stream:
                async for line in stream.aiter_lines():
                    token = parse_sse(line)
                    if token:
                        await response_msg.stream_token(token)
        s.output = "Generation complete"
    await response_msg.update()
```

### vLLM Metrics PromQL (for Grafana Dashboard)

```promql
# TTFT p50 (50th percentile time to first token)
histogram_quantile(0.5, rate(vllm:time_to_first_token_seconds_bucket[5m]))

# TTFT p95
histogram_quantile(0.95, rate(vllm:time_to_first_token_seconds_bucket[5m]))

# E2E Request Latency p95
histogram_quantile(0.95, rate(vllm:e2e_request_latency_seconds_bucket[5m]))

# Token throughput (generation tokens/sec)
rate(vllm:generation_tokens_total[1m])

# Running + waiting requests
vllm:num_requests_running + vllm:num_requests_waiting

# KV Cache utilization
vllm:kv_cache_usage_perc
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `schoolofdevops/vllm-cpu-nonuma:0.9.1` (community build) | `vllm/vllm-openai-cpu:v0.19.0-x86_64` (official) | Jan 2026 | Must update config.env and COURSE_VERSIONS.md |
| KServe RawDeployment for vLLM | Plain K8s Deployment + Service (D-10) | Phase 2 decision | Simpler; fewer CRDs; same API surface |
| `vllm_request_ttft_seconds` (old metric name) | `vllm:time_to_first_token_seconds` (v1 metrics API) | vLLM v1.x | ServiceMonitor + Grafana PromQL must be updated |
| `peft==0.12.0 transformers==4.43.3 torch==2.3.1` | `peft==0.19.0 transformers==5.5.4 torch==2.11.0` | April 2026 | Training Dockerfile update required |
| "Atharva Dental Clinic" | "Smile Dental" | Phase 2 | All strings, system prompts, data files |
| CLI-only interface (curl) | Chainlit web UI with Steps | Phase 2 | Lab 05 adds full web interface |

**Deprecated/outdated:**
- `schoolofdevops/vllm-cpu-nonuma`: No new builds since v0.9.1. Do not use.
- `peft==0.12.0`: Two major version series behind. Use 0.19.0.
- `numpy==1.26.4`: May need reevaluation — FAISS/sentence-transformers may now be compatible with NumPy 2.x. Safe to keep 1.26.4 pin for Lab 01.

---

## Open Questions

1. **vLLM 0.19.0 CPU with SmolLM2-135M-Instruct — actual startup time on KIND**
   - What we know: Lab documentation from old course says 60-180 seconds; readinessProbe is set to 120s initial delay.
   - What's unclear: vLLM 0.19.0 has claimed 48.9% throughput improvement for pooling models; startup time improvement is unknown.
   - Recommendation: Validate in live cluster during Phase 2 execution. Set `initialDelaySeconds: 120` conservatively; adjust down if actual time is faster.

2. **`--dtype=bfloat16` vs `--dtype=float16` on CPU for SmolLM2**
   - What we know: vLLM CPU Dockerfile uses bfloat16 by default; existing lab04 config used float16.
   - What's unclear: SmolLM2-135M's model files use float32 — dtype flag controls inference precision. bfloat16 on CPU requires AVX512BF16 support.
   - Recommendation: Default to `--dtype=float32` for maximum compatibility on all student machines (slower but universally compatible); offer bfloat16 as optional optimization for AVX512BF16 machines.

3. **PEFT 0.19.0 `LoraConfig` API for SmolLM2-135M target_modules**
   - What we know: `q_proj`, `v_proj` are standard targets for LLaMA-family models; SmolLM2 uses a similar attention architecture.
   - What's unclear: Whether SmolLM2-135M uses exactly these module names or variant names.
   - Recommendation: Verify via `model.named_modules()` during execution phase; print all module names and confirm.

4. **Chainlit `cot = "full"` vs `cot = "tool_call"` for glass-box mode**
   - What we know: `cot = "full"` shows all Steps; `cot = "tool_call"` shows only tool-typed steps.
   - What's unclear: In educational context, is showing all steps (including "run" type) better or worse UX?
   - Recommendation: Default to `cot = "full"` so all Steps show by default; students learn what each step does. They can collapse what they don't need.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Docker | All labs | Yes | 28.4.0 | — |
| KIND CLI | Lab cluster setup | Yes | v0.27.0 | — |
| kubectl | All K8s labs | Yes | 1.32.3 (client) | Server version may differ |
| Helm | Lab 06 (kube-prometheus-stack) | Yes | 3.18.4 | — |
| Python 3 | Lab 01, 02 scripts | Yes | 3.13.7 (host) | Use 3.11 inside containers |
| Node.js | Docusaurus build | Yes | 22.21.1 | — |
| vllm/vllm-openai-cpu:v0.19.0-x86_64 | Lab 04 | Not cached | — | Pull at lab time; ~1.1 GB |
| kindest/node:v1.34.0 | KIND cluster | Not cached | — | Pull at lab time; ~1.06 GB |
| Docker memory (9.7 GiB VM) | Full stack | BORDERLINE | 9.7 GiB | Reduce KIND to 1 worker; stagger lab workloads |

**Missing dependencies with no fallback:**
- None that block execution.

**Missing dependencies with fallback:**
- Docker Desktop VM memory is 9.7 GiB. The PITFALLS.md recommends 12 GiB minimum for the full stack (vLLM 5Gi + Prometheus ~2Gi + node overhead). Lab content must stagger components: only bring up Lab 06 (Prometheus) AFTER Lab 04 (vLLM) is validated and torn down, or reduce vLLM limits to 3Gi for demo purposes.

**Note on kubectl client version:** kubectl 1.32.3 (client) connecting to KIND cluster with kindest/node:v1.34.0 has minor skew (client < server). This is outside the ±1 minor version official support window but works for all basic operations used in these labs. Update kubectl to 1.34.x before live cluster validation.

---

## Sources

### Primary (HIGH confidence)
- Docker Hub API v2 `vllm/vllm-openai-cpu` repository — confirmed tags v0.19.0-x86_64, v0.19.0-arm64 (both amd64+arm64 available, verified 2026-04-12)
- PyPI JSON API — version verification for: faiss-cpu (1.13.2), sentence-transformers (5.4.1), chainlit (2.11.0), peft (0.19.0), transformers (5.5.4), torch (2.11.0), accelerate (1.13.0), datasets (4.8.4), prometheus-client (0.25.0), fastapi (0.135.3)
- GitHub `Chainlit/chainlit` — `backend/chainlit/step.py` (Step class constructor, TrueStepType values, context manager implementation), `backend/chainlit/config.py` (UISettings schema)
- GitHub `vllm-project/vllm` — `vllm/v1/metrics/loggers.py` (confirmed metric names with `vllm:` prefix), `docker/Dockerfile.cpu` (base Ubuntu 22.04, Python 3.12, torch 2.11.0, ENTRYPOINT vllm serve), `vllm/envs.py` (VLLM_CPU_KVCACHE_SPACE default=4GiB, VLLM_CPU_OMP_THREADS_BIND, VLLM_TARGET_DEVICE)
- GitHub `prometheus-community/helm-charts` — kube-prometheus-stack chart 83.4.2 (Prometheus Operator 0.90.1, Grafana 11.6.1)
- `course-code/COURSE_VERSIONS.md` — existing version pins and inconsistency identified (VLLM_IMAGE still references old schoolofdevops image)
- `.planning/research/STACK.md` — Phase 1 research decisions (FAISS over Qdrant, Chainlit, vLLM 0.19.0)
- `.planning/research/PITFALLS.md` — vLLM CPU KV cache OOM, Docker memory limits, cross-lab artifacts, training time

### Secondary (MEDIUM confidence)
- Chainlit docs (docs.chainlit.io) — Step and Message concept pages (rendered content limited; key constructor parameters verified against source code)
- GitHub vllm-project/vllm release page v0.19.0 — 48.9% throughput improvement claim (rendered content limited; confirmed release exists)

### Tertiary (LOW confidence)
- Training timing estimate (30-120 minutes per epoch on CPU) — from PITFALLS.md; based on Phase 1 research. Needs live validation on the course machine.
- bfloat16 AVX512BF16 compatibility note — from CPU backend documentation references; exact behavior with SmolLM2-135M not live-tested.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all versions verified against PyPI and Docker Hub registries
- Architecture: HIGH — patterns derived directly from existing working lab code
- vLLM image: HIGH — Docker Hub API confirmed `vllm/vllm-openai-cpu` repository and v0.19.0 tags
- vLLM metrics: HIGH — verified against vllm/v1/metrics/loggers.py source
- Chainlit Steps API: HIGH — verified against chainlit/step.py source + config.py
- Pitfalls: HIGH — combination of PITFALLS.md research + direct source code verification
- Training time: LOW — estimated from Phase 1 research; needs live validation

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (stable stack) — vLLM CPU image tags are stable; Python library versions should be re-verified before course delivery if >30 days elapsed
