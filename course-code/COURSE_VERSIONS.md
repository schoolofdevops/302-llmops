# Course Versions

Tested combination for this course delivery.
All versions verified on macOS Apple Silicon and x86-64 Windows.

**Last verified:** 2026-05-02 + Day 2 components added
**Workshop delivery:** v1.0

## Core Infrastructure

| Component | Pinned Version | Compatibility Reason |
|-----------|---------------|----------------------|
| kindest/node | v1.34.0 | ImageVolume beta available; v1.33 requires manual gate enable; v1.35 not yet tested |
| KIND CLI | 0.27.0 | Supports kind config v1alpha4; tested on macOS Apple Silicon + x86 |
| kubectl | 1.34.x | Server version match; avoid skew beyond ±1 minor version |
| Helm | 3.x | 3.18+ preferred; any 3.x works |
| Docker Desktop | 4.x (engine 28+) | Set Resources > Memory >= 12GB for Labs 04-09 |

## ML / LLM Stack

| Component | Pinned Version | Compatibility Reason |
|-----------|---------------|----------------------|
| Python | 3.11 | PEFT + PyTorch + Transformers tested on 3.11; 3.12 has edge cases with some PEFT versions |
| PyTorch | 2.4+ (CPU) | MKL included in x86_64 wheels; required for NumPy 2.x compatibility |
| Transformers | 4.50+ | Required by vLLM 0.19.0; SmolLM2-135M tokenizer compatibility |
| PEFT | 0.14+ | LoRA CPU training on SmolLM2-135M; 0.14 adds stable merge_and_unload |
| Sentence-Transformers | 3.x | all-MiniLM-L6-v2 embeddings; 22MB, 14.7ms/1K tokens on CPU |
| FAISS | faiss-cpu latest | In-process vector search; no version constraint beyond Python 3.11 compat |
| NumPy | 1.26.4 | Pin to avoid NumPy 2.x breaking changes with older scipy/faiss |
| HuggingFace SmolLM2-135M-Instruct | main | Base model for fine-tuning; 135M params, CPU-compatible |

## Serving & Deployment

| Component | Pinned Version | Compatibility Reason |
|-----------|---------------|----------------------|
| vLLM | 0.9.1 | Custom CPU image: `schoolofdevops/vllm-cpu-nonuma:0.9.1` — stripped-down, no NUMA, CPU-only inference on mac/windows |
| KServe | N/A (Phase 2) | Not used in Day 1 labs; plain K8s Deployment used for vLLM serving (Phase 3+ only) |
| kube-prometheus-stack | latest Helm chart | Pin chart version at workshop delivery time |

## Web UI & Agent

| Component | Pinned Version | Compatibility Reason |
|-----------|---------------|----------------------|
| Chainlit | 2.11.0 | Requires `--host 0.0.0.0` for K8s NodePort access; 2.11 has stable WebSocket streaming |
| FastAPI | 0.x (latest) | Pydantic v2 compatible; use fastapi[standard] for uvicorn inclusion |

## Agent + Observability (Day 2)

| Component | Pinned Version | Compatibility Reason |
|-----------|---------------|----------------------|
| `nousresearch/hermes-agent` Docker image | `latest` | Only published Docker Hub tag (2.4 GB); pull at workshop delivery time. Requires 64K+ context window model |
| Kubernetes Agent Sandbox CRDs + controller | v0.4.3 | Latest as of 2026-04-28. KIND explicitly supported. SandboxWarmPool creates Sandbox CRs (v0.3.10+). API: `agents.x-k8s.io/v1alpha1` + `extensions.agents.x-k8s.io/v1alpha1` |
| `k8s-agent-sandbox` Python SDK | 0.4.3 | Matches CRD version; used by Chainlit to claim per-session Sandbox |
| MCP Python SDK (`mcp[cli]`) | 1.27.0 | FastMCP `streamable_http_app()` — Streamable HTTP transport (MCP spec 2025-03-26). SSE deprecated |
| `opentelemetry-sdk` | 1.41.1 | OTLP gRPC exporter; matches collector 0.151.0 |
| `opentelemetry-exporter-otlp-proto-grpc` | 1.41.1 | Tracks SDK version |
| `opentelemetry-instrumentation-httpx` | 0.62b1 | Auto-instruments httpx calls inside MCP tool servers (treatment_lookup → RAG retriever) |
| `opentelemetry-instrumentation-fastapi` | 0.62b1 | Auto-instruments FastMCP HTTP server |
| Grafana Tempo Helm chart | 1.24.4 | Single-binary mode, in-memory tmpfs storage — fits KIND |
| OpenTelemetry Collector Helm chart | 0.153.0 | `mode: deployment` (one pod) for KIND footprint |
| `kubernetes` Python client | 32.x (latest) | book_appointment MCP tool patches `bookings` ConfigMap via in-cluster RBAC |
| `filelock` Python lib | >=3.13.0 | Cross-platform file lock for `book_appointment` local-JSON mode (replaces `fcntl.flock` so Windows hosts can run `pytest` — W4) |
| Groq recommended model | `llama-3.3-70b-versatile` | 128K context (satisfies Hermes 64K minimum); free tier 30 RPM / 6K TPM / 1000 RPD |
| Gemini recommended model | `gemini-2.5-flash` | 1M context; OpenAI-compat at `https://generativelanguage.googleapis.com/v1beta/openai/`. Free tier 10 RPM / 500 RPD |

## Documentation Site

| Component | Pinned Version | Compatibility Reason |
|-----------|---------------|----------------------|
| Docusaurus | 3.10.0 | npm latest as of 2026-04-12; MDX 3, dark/light toggle, versioning |
| Node.js | 22.x LTS | For Docusaurus build only; 18+ required by Docusaurus 3 |

## Notes

- vLLM CPU image: `schoolofdevops/vllm-cpu-nonuma:0.9.1` — custom stripped-down image for CPU-only inference without GPU on mac/windows
- KIND node image: always pin to `v1.34.0` — `latest` is not a valid KIND image tag
- For Hermes Agent (Lab 07): requires free-tier API key for Gemini (https://aistudio.google.com) or Groq (https://console.groq.com)
- Hermes Agent requires a model with at least 64,000 token context window — `llama-3.3-70b-versatile` (Groq) and `gemini-2.5-flash` (Gemini) both qualify; SmolLM2-135M does not. Day 2 uses remote LLM APIs.
- Kubernetes Agent Sandbox v0.4.3 is alpha (`v1alpha1`). KIND default kindnet does NOT enforce NetworkPolicy — Lab 08 applies it as a documented production pattern only.
- The Sandbox Router image (`us-central1-docker.pkg.dev/k8s-staging-images/agent-sandbox/sandbox-router:latest-main`) is on GCR. Pullability without GCP credentials is verified at start of Lab 08; fallback is `kubectl port-forward` mode.
- vLLM image stays at the existing pin; Day 2 scales the Deployment to 0 (manifest preserved for Day 3 autoscaling labs).
