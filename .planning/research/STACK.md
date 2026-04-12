# Stack Research

**Domain:** LLMOps & AgentOps course running on Kubernetes (CPU-only, KIND clusters)
**Researched:** 2026-04-12
**Confidence:** MEDIUM-HIGH (most claims verified against PyPI, official docs, or multiple current sources)

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Python | 3.11 | Primary language | Keep existing — stable, well-supported by all ML libs, 3.12 still has edge-case incompatibilities with PEFT |
| Kubernetes | 1.34+ | Orchestration | Keep existing — matches course constraint |
| KIND | latest | Local cluster | Keep existing — CPU-friendly, widely taught |
| FastAPI | 0.115+ | Chat API, RAG API | Keep existing — standard for ML serving, async-native |
| vLLM | 0.19.0 | LLM inference serving | Latest stable (released April 3 2026); official CPU images now on Docker Hub (`vllm/vllm-openai-cpu:v0.19.0-x86_64`) replacing community schoolofdevops builds — significant upgrade from 0.9.1 |
| LangGraph | 1.1.6 | Agent orchestration | Production-stable (April 2026); best teachability for graph-based agents; model-agnostic |
| Chainlit | 2.11.0 | Chat web UI | Chat-native (streaming, message threading, agent step display built in); simpler to Dockerize than custom React for a course |
| Qdrant | 1.13+ | Vector store | Kubernetes-native Helm chart; REST + gRPC; cleaner teaching story than FAISS for a K8s course |
| DeepEval | 3.9.6 | LLM evaluation | pytest-compatible; 50+ metrics covering RAG faithfulness, contextual recall, agent quality |
| NeMo Guardrails | 0.21.0 | Safety/guardrails | Best-documented open-source guardrails toolkit; LangGraph integration; configurable via Colang DSL |
| Docusaurus | 3.9.2 | Course documentation site | Meta-maintained; React-based; versioning, search, MDX support; Algolia AI search in 3.9 |

### ML / AI Libraries

| Library | Version | Purpose | Notes |
|---------|---------|---------|-------|
| HuggingFace Transformers | 4.50+ | Model loading, inference | Keep — required by PEFT and vLLM |
| PEFT | 0.14+ | LoRA fine-tuning | Keep — CPU LoRA on SmolLM2-135M still valid; most teachable fine-tuning path |
| Sentence-Transformers | 3.x | Embeddings for RAG | Keep all-MiniLM-L6-v2; still the fastest CPU-class embedding model at 22MB; 14.7ms/1K tokens |
| PyTorch | 2.4+ (CPU) | Deep learning backend | Keep CPU variant — constraint-free on 16GB RAM laptops |
| NumPy | 2.x | Numerical computing | Upgrade from 1.26.4 — PyTorch 2.4+ requires NumPy 2.x on Python 3.11 |

### Infrastructure / GitOps (Keep Existing)

| Technology | Version | Purpose | Notes |
|------------|---------|---------|-------|
| KServe | 0.14+ | Model serving CRD | Keep — pairs with vLLM InferenceService |
| Prometheus + kube-prometheus-stack | latest Helm | Metrics | Keep |
| Grafana | latest via Helm | Dashboards | Keep |
| KEDA | 2.x | Event-driven autoscaling | Keep |
| ArgoCD | 2.x | GitOps delivery | Keep |
| Argo Workflows | 3.x | Pipeline orchestration | Keep |
| Kubernetes Agent Sandbox | 0.3.10 | Agent workload isolation | Add — stable release (April 2025); provides Sandbox CRD, SandboxWarmPool, Python SDK |

---

## Decision Rationale — The Nine Questions

### 1. Base Model: Keep SmolLM2-135M-Instruct

**Recommendation: Keep SmolLM2-135M-Instruct for fine-tuning module. Add SmolLM3-3B for serving/agent module.**

SmolLM2-135M remains the only model in the HuggingFace SmolLM family that reliably runs CPU LoRA fine-tuning in a 3-hour workshop lab without requiring 8GB+ VRAM. SmolLM3-3B was released in 2026 and outperforms Llama-3.2-3B, but its fine-tuning documentation explicitly warns that training will fail on CPU-only. Phi-4-mini and Qwen2.5-0.5B require more RAM and are slower to download.

Decision: **SmolLM2-135M-Instruct for Lab 02 (LoRA fine-tuning)**. For the serving and agent labs, swap to **SmolLM3-3B** (or keep SmolLM2-135M as the packaged+served model — it demonstrates the concept cleanly regardless of capability).

Confidence: HIGH — verified HuggingFace docs for SmolLM3-3B explicitly note GPU requirement for training.

### 2. Agent Framework: LangGraph

**Recommendation: LangGraph 1.1.6 as primary teaching framework.**

- **LangGraph** reached 1.0 (production-stable) in late 2025 and is at 1.1.6 as of April 2026. Model-agnostic (works with any OpenAI-compatible API, which vLLM exposes). Graph-based state machine mental model maps directly to Kubernetes concepts (nodes, edges, state). First-class checkpointing. Best for teaching because the explicit typed state makes agent behavior inspectable and debuggable in a classroom.
- **CrewAI 1.14.1** is the most beginner-friendly (role-based crews), but abstracts too much for a course that wants students to understand what agents are doing. Production readiness rated MEDIUM vs LangGraph's HIGH.
- **OpenAI Agents SDK 0.13.6** is fastest path to working code but hard-couples to OpenAI models — unacceptable for a course using local vLLM. Despite the description saying "100+ LLMs", its core design is OpenAI-centric.
- **Claude Agent SDK 0.1.58** is excellent for Anthropic-managed agents but requires Anthropic API — wrong for a local/K8s-native course.

Decision: **LangGraph 1.1.6 as primary. Mention CrewAI and OpenAI Agents SDK as "in the wild" alternatives in lecture; do not build labs around them.**

Confidence: HIGH — version verified against PyPI; teachability rationale verified against multiple 2026 comparison articles.

### 3. Vector Store: Replace FAISS with Qdrant

**Recommendation: Qdrant (Helm-deployed, 1.13+) replaces FAISS.**

FAISS is a library, not a service — it runs in-process, can't demonstrate K8s-native persistence, scaling, or API patterns that a K8s course should showcase. Qdrant has:
- Official Helm chart (single `helm install` command for students)
- REST API students can `curl` directly — makes RAG retrieval visible and debuggable
- Persistent storage via PVC — demonstrates K8s storage patterns
- Python SDK (`qdrant-client`) is simpler than FAISS index serialization

Alternatives considered: ChromaDB (no production-grade Helm chart), pgvector (requires PostgreSQL — adds complexity for a non-SQL course), Milvus (heavy — two additional operator pods, wrong for 16GB RAM constraint).

Keep FAISS in Lab 01 only as a "before" reference showing why a managed vector service matters. Replace with Qdrant from Lab 01 solution onward.

Confidence: MEDIUM — Qdrant Helm chart deployment verified; FAISS limitation reasoning is architectural judgment, not benchmarked.

### 4. vLLM: Upgrade to 0.19.0

**Recommendation: vLLM 0.19.0 with official CPU Docker image.**

The existing course uses `schoolofdevops/vllm-cpu-nonuma:0.9.1` — a community build that is now obsolete. As of January 20, 2026, the vLLM project ships official multi-arch CPU Docker images at `vllm/vllm-openai-cpu`. 

Use: `vllm/vllm-openai-cpu:v0.19.0-x86_64` (or `latest-x86_64`).

v0.19.0 CPU improvements include 48.9% throughput improvement for pooling models, tcmalloc enabled by default, and AVX2/AVX512 support. Requires glibc >= 2.35 (Ubuntu 22.04+ base — consistent with existing KIND images).

Confidence: HIGH — version verified on PyPI (released April 3 2026) and Docker Hub migration date verified via web sources.

### 5. Chat Web UI: Chainlit

**Recommendation: Chainlit 2.11.0.**

For a course whose explicit goal is to add a web chat interface replacing CLI/curl:
- **Chainlit**: Chat-native, streaming out of the box, agent step display (LangGraph integration shows reasoning traces), zero CSS to write, Dockerizes in ~10 lines. Known Kubernetes caveat: needs `--host 0.0.0.0 -h` flags and careful ingress path config to avoid 404s on sub-path deployments — teachable, not a blocker.
- **Gradio**: Best for 5-line demos and HuggingFace Spaces — good for a single-slide "here's a quick UI", not production-looking enough for a course that positions itself as production-grade.
- **Streamlit**: Better for data dashboards than pure chat; more boilerplate to get streaming right.
- **Custom React**: Months of scope not weeks; wrong for a course constraint.

Confidence: MEDIUM — version verified on PyPI; Kubernetes deployment caveats verified on GitHub issues.

### 6. Documentation Site: Docusaurus 3.9.2

**Recommendation: Docusaurus 3.9.2 — confirmed by project decision, research validates it.**

Already a project decision (replacing MkDocs). Research confirms it is the right call:
- 3.9.2 is the current stable release with Algolia AI search (DocSearch v4 with Ask AI)
- Versioning support — courses need versioned docs (v1, v2 per workshop year)
- MDX lets instructors embed interactive components (live code blocks, quizzes)
- Meta-maintained — not going away
- Rspack persistent cache makes build times fast

The main criticism in 2026 is zero built-in AI features, but this is irrelevant — students are building the AI, not consuming it through the docs site.

Confidence: HIGH — version verified on npmjs.com; feature claims verified against Docusaurus official blog.

### 7. Kubernetes Agent Sandbox: v0.3.10

**Recommendation: kubernetes-sigs/agent-sandbox v0.3.10.**

This is the project's differentiating module and the reason the course is uniquely positioned. What we know:
- v0.3.10 released April 8, 2025 (latest stable as of April 2026)
- Kubernetes blog published "Running Agents on Kubernetes with Agent Sandbox" in March 2026 — indicates official endorsement
- v0.2.1 added "Secure by Default" networking isolation — this is now the baseline
- Python SDK (`sigs.k8s.io/agent-sandbox`) available via Go Packages; Python binding via PyPI

Teaching approach: Introduce Sandbox CRD as "the StatefulSet for AI agents" — it provides stable hostname + network identity + persistent storage + configurable isolation (gVisor/Kata Containers). SandboxWarmPool = pre-warmed agent environments for fast startup (connects to KEDA autoscaling concepts already taught).

Risk: Still pre-1.0, API may evolve. Flag the Agent Sandbox lab for deeper research before build — API surface needs to be verified against v0.3.10 release notes before writing lab content.

Confidence: MEDIUM — version verified on GitHub releases; some API details inferred from docs/blog sources.

### 8. LLM Evaluation: DeepEval

**Recommendation: DeepEval 3.9.6 as the primary evaluation framework.**

Three-layer eval strategy for the course evals module:
1. **DeepEval** (pytest-native) — unit tests for RAG: faithfulness, contextual precision, contextual recall. Fits course's TDD-adjacent teaching style. 50+ metrics, RAGAS integration included.
2. **Langfuse** (OSS) — production monitoring layer. Deploys on Kubernetes. Provides traces, cost tracking, prompt versioning. Can be self-hosted in the K8s cluster — makes observability tangible.
3. **RAGAS** — mention as the academic baseline; point students to it for deeper reading. Do not build a dedicated lab around it (DeepEval wraps it anyway).

Do not use LangSmith — requires Langchain account/API key, wrong for a self-hosted course.

Confidence: MEDIUM — DeepEval version verified on PyPI; Langfuse self-hosting capability verified via docs.

### 9. Guardrails: NeMo Guardrails

**Recommendation: NeMo Guardrails 0.21.0.**

For a course lab on safety:
- NeMo Guardrails is the most complete open-source solution: input rails, output rails, topic rails, fact-checking, hallucination detection
- Colang DSL is teachable in < 30 minutes — students configure guardrails without writing Python
- LangGraph integration exists natively — bolts onto the agent module

Guardrails AI is a close alternative but has a smaller community, and its value is in output validation (structured output coercion) rather than conversational safety rails — a different use case.

Do not use proprietary content moderation APIs (OpenAI moderation, AWS Comprehend) — incompatible with the local/self-hosted course philosophy.

Confidence: MEDIUM — version verified on PyPI; feature claims verified against NVIDIA docs and 2026 blog sources.

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `schoolofdevops/vllm-cpu-nonuma:0.9.1` | Abandoned community build; superseded by official vLLM Docker Hub images | `vllm/vllm-openai-cpu:v0.19.0-x86_64` |
| FAISS as the RAG store | In-process library; cannot demonstrate K8s-native service patterns | Qdrant via Helm |
| OpenAI Agents SDK as teaching framework | Hard-couples to OpenAI API; unusable with local vLLM | LangGraph (model-agnostic) |
| CrewAI as primary framework | Too abstract for teaching what agents do; medium production-readiness | LangGraph for depth; mention CrewAI as alternative |
| Claude Agent SDK as primary framework | Requires Anthropic API; not self-hostable | LangGraph; mention in lecture only |
| Gradio for the chat UI | Demo-grade, not production-looking; poor Kubernetes story | Chainlit |
| Custom React chat UI | Weeks of scope not hours | Chainlit |
| Milvus as vector store | Heavy (operator + etcd + pulsar); exceeds 16GB RAM laptop constraint | Qdrant |
| ChromaDB as vector store | No production Helm chart; in-memory default misleads students | Qdrant |
| LangSmith for observability | Requires Langchain account; not self-hostable in K8s cluster | Langfuse (self-hosted) |
| MkDocs + ReadTheDocs theme | Cannot version docs; no MDX; no interactive components | Docusaurus 3.9.2 |
| SmolLM3-3B for LoRA fine-tuning | Requires 8GB VRAM; CPU training fails per HuggingFace docs | SmolLM2-135M-Instruct (fine-tuning only) |

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| LangGraph | CrewAI | If the course were specifically about role-based multi-agent collaboration (enterprise workflows) |
| LangGraph | OpenAI Agents SDK | If the course required OpenAI API as the LLM backend (not local/vLLM) |
| Qdrant | pgvector | If the course already taught PostgreSQL and wanted to avoid a separate service |
| Chainlit | Streamlit | If the UI needed to show data dashboards alongside chat (e.g., metrics visualization) |
| DeepEval | RAGAS standalone | If the course wanted a pure metrics-focused research-grade evaluation (no TDD angle) |
| NeMo Guardrails | Guardrails AI | If the primary goal were structured output validation rather than conversational safety |
| Docusaurus | MkDocs Material | If the course team preferred Python toolchain and did not need versioning or MDX |

---

## Installation Summary

```bash
# Agent framework
pip install langgraph==1.1.6 langgraph-prebuilt==1.0.9

# Chat UI
pip install chainlit==2.11.0

# Vector store client
pip install qdrant-client>=1.9.0

# Evaluation
pip install deepeval==3.9.6

# Guardrails
pip install nemoguardrails==0.21.0

# Embeddings (unchanged)
pip install sentence-transformers>=3.0.0

# Fine-tuning (unchanged)
pip install peft>=0.14.0 transformers>=4.50.0

# vLLM — Docker only (not pip-installed in course)
# docker pull vllm/vllm-openai-cpu:v0.19.0-x86_64

# Qdrant — Helm only
# helm repo add qdrant https://qdrant.github.io/qdrant-helm
# helm install qdrant qdrant/qdrant

# Kubernetes Agent Sandbox — kubectl/Helm
# kubectl apply -f https://github.com/kubernetes-sigs/agent-sandbox/releases/download/v0.3.10/install.yaml

# Docusaurus — Node.js
# npx create-docusaurus@3.9.2 my-course classic
```

---

## Version Compatibility Notes

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| vllm 0.19.0 (CPU) | glibc >= 2.35 | Ubuntu 22.04+ base required; KIND nodes use ubuntu-jammy — compatible |
| vllm 0.19.0 | transformers >= 4.50.0 | Note: vLLM 0.9.x required transformers < 4.54.0 — the 0.19 requirement is different direction |
| LangGraph 1.1.6 | Python >= 3.10 | Compatible with course's Python 3.11 |
| DeepEval 3.9.6 | Python >= 3.9 | Compatible |
| NeMo Guardrails 0.21.0 | LangGraph 1.x | Native integration exists |
| Chainlit 2.11.0 | LangGraph 1.x | Native integration exists via `chainlit.langchain` callbacks |
| NumPy 2.x | PyTorch 2.4+ | PyTorch 2.4+ requires NumPy 2.x on Python 3.11 — upgrade from existing 1.26.4 |
| K8s Agent Sandbox 0.3.10 | Kubernetes 1.28+ | Requires Kubernetes >= 1.28; course's 1.34 is compatible |

---

## Sources

- PyPI release pages — version verification for: vllm (0.19.0), langgraph (1.1.6), chainlit (2.11.0), deepeval (3.9.6), nemoguardrails (0.21.0), crewai (1.14.1), openai-agents (0.13.6), claude-agent-sdk (0.1.58) — HIGH confidence
- GitHub releases page for kubernetes-sigs/agent-sandbox — v0.3.10 release date April 8, 2025 — HIGH confidence
- Docusaurus official blog (docusaurus.io/blog/releases/3.8) and InfoQ news on 3.9 — MEDIUM confidence
- WebSearch: multiple 2026 agent framework comparison articles (particula.tech, gurusup.com, langfuse.com, fungies.io) — MEDIUM confidence
- WebSearch: vLLM CPU Docker Hub official images post-January 2026 migration — MEDIUM confidence
- WebSearch: SmolLM3-3B CPU training limitation (HuggingFace smol-course docs) — HIGH confidence
- WebSearch: Qdrant Helm chart (qdrant-helm GitHub) — HIGH confidence
- WebSearch: Chainlit Kubernetes deployment caveats (GitHub issues #780, #384) — MEDIUM confidence

---

*Stack research for: LLMOps & AgentOps with Kubernetes course*
*Researched: 2026-04-12*
