# Requirements: LLMOps & AgentOps with Kubernetes

**Defined:** 2026-04-12
**Core Value:** Teach practitioners how to take AI systems (LLMs + agents) from prototype to production on Kubernetes

## v1 Requirements

Requirements for initial course release. Each maps to roadmap phases.

### Course Infrastructure

- [x] **INFRA-01**: Companion code repo with starter/ and solution/ directories per lab module
- [x] **INFRA-02**: Docusaurus site supporting dual delivery (workshop schedule + Udemy self-paced)
- [x] **INFRA-03**: Cross-platform preflight validation script (Windows + macOS Docker Desktop checks)
- [x] **INFRA-04**: Version pinning strategy (COURSE_VERSIONS.md) for all dependencies
- [ ] **INFRA-05**: Lab phase resource management — cleanup scripts between resource-heavy sections

### Kubernetes Setup

- [x] **K8S-01**: KIND cluster setup with ImageVolume feature gates (Windows + macOS)
- [x] **K8S-02**: Namespace strategy for ML, app, monitoring, and agent workloads
- [x] **K8S-03**: Preflight script validates Docker Desktop memory allocation, disk, and K8s version

### RAG System

- [ ] **RAG-01**: Synthetic data generation for Smile Dental clinic domain (treatments, policies, FAQs)
- [ ] **RAG-02**: FAISS vector index built from clinic data using sentence-transformers embeddings
- [ ] **RAG-03**: FastAPI retriever service deployed on Kubernetes with health checks
- [ ] **RAG-04**: End-to-end RAG query demonstrating retrieval + LLM generation

### Fine-Tuning

- [ ] **TUNE-01**: CPU LoRA fine-tuning of SmolLM2-135M on synthetic dental clinic chat data
- [ ] **TUNE-02**: LoRA adapter merge into base model producing a single model folder
- [ ] **TUNE-03**: Training job runs as Kubernetes Job with resource limits

### Model Packaging

- [ ] **PKG-01**: Merged model packaged as OCI image
- [ ] **PKG-02**: Model mounted in Kubernetes via ImageVolumes

### Model Serving

- [ ] **SERVE-01**: vLLM serving the fine-tuned model with OpenAI-compatible API
- [ ] **SERVE-02**: KServe RawDeployment wrapping vLLM with readiness probes
- [ ] **SERVE-03**: End-to-end inference test (prompt → vLLM → response) via curl and web UI

### Web Interface

- [ ] **UI-01**: Chainlit chat interface connected to the RAG + LLM pipeline
- [ ] **UI-02**: Chat UI deployed as Kubernetes Deployment with NodePort access
- [ ] **UI-03**: Streaming responses displayed in real-time
- [ ] **UI-04**: "Glass box" learning mode — UI shows RAG retrieval context, LLM prompt/response, agent tool-call steps, and per-step timing visually (educational, not just production)

### Agentic System

- [ ] **AGENT-01**: Hermes Agent configured with Smile Dental custom tools (appointment booking, treatment lookup, triage)
- [ ] **AGENT-02**: Hermes Agent connected to free-tier LLM API (Gemini or Groq — student choice, OpenAI-compatible)
- [ ] **AGENT-03**: Hermes Agent integrated with existing RAG retriever as a tool
- [ ] **AGENT-04**: Agent demonstrates multi-step workflow (e.g., symptom → triage → treatment info → book appointment)

### Agent Deployment (K8s Agent Sandbox)

- [ ] **SANDBOX-01**: Kubernetes Agent Sandbox CRD installed on KIND cluster
- [ ] **SANDBOX-02**: Hermes Agent deployed as a Sandbox resource with isolation
- [ ] **SANDBOX-03**: SandboxWarmPool configured for fast agent startup
- [ ] **SANDBOX-04**: Agent accessible via gateway (Sandbox stable identity + networking)

### Observability

- [ ] **OBS-01**: Prometheus + Grafana stack deployed via Helm (kube-prometheus-stack)
- [ ] **OBS-02**: vLLM metrics scraped (TTFT, latency, tokens/sec, request counts)
- [ ] **OBS-03**: Chat API and Retriever instrumented with Prometheus metrics
- [ ] **OBS-04**: Grafana dashboard for LLM workload visibility
- [ ] **OBS-05**: Agent observability — tool-call traces, API cost tracking, latency per tool
- [ ] **OBS-06**: OpenTelemetry (OTEL) instrumentation for distributed tracing across agent → retriever → LLM
- [ ] **OBS-07**: OTEL collector deployed on K8s, traces visualized in Grafana Tempo or Jaeger

### Autoscaling

- [ ] **SCALE-01**: HPA on Chat API (CPU-based scaling)
- [ ] **SCALE-02**: KEDA ScaledObject for Prometheus-driven scaling (RPS-based)
- [ ] **SCALE-03**: Load generator job to demonstrate scaling behavior

### GitOps & Pipelines

- [ ] **GITOPS-01**: ArgoCD deployed and managing all components via App-of-Apps pattern
- [ ] **GITOPS-02**: Model promotion by updating ImageVolume tag in Git (ArgoCD syncs automatically)
- [ ] **GITOPS-03**: Argo Workflows DAG automating the LLM pipeline (data → train → package → deploy)

### Evaluation & Quality Gate

- [ ] **EVAL-01**: DeepEval test suite for RAG quality (faithfulness, context precision/recall)
- [ ] **EVAL-02**: Evaluation integrated into Argo Workflows as a quality gate before model deployment

### Guardrails & Governance

- [ ] **GUARD-01**: Input validation and prompt safety filtering for the agent (lightweight, code-based — no heavy framework)
- [ ] **GUARD-02**: Output guardrails — detect and block hallucinated medical advice beyond scope
- [ ] **GUARD-03**: Governance overview — model versioning, audit trail via GitOps, OTEL traces as compliance evidence

### Capstone

- [ ] **CAP-01**: End-to-end exercise tying all components — add a new tool to Hermes Agent, deploy via GitOps, validate via eval gate, observe in Grafana

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Security & Guardrails

- **SEC-01**: NeMo Guardrails or similar for input/output safety filtering
- **SEC-02**: Network policies isolating agent sandbox from cluster services

### Advanced Observability

- **ADV-OBS-01**: Langfuse self-hosted for detailed LLM trace visualization
- **ADV-OBS-02**: Cost tracking dashboard for API-based LLM usage

### Multi-Agent

- **MULTI-01**: Multiple Hermes agents coordinating via K8s Agent Sandbox
- **MULTI-02**: Agent-to-agent communication patterns

## Out of Scope

| Feature | Reason |
|---------|--------|
| GPU-specific content | Course must run on CPU-only laptops (16GB RAM) |
| Cloud managed K8s (EKS/GKE/AKS) | Keep cloud-agnostic with KIND for accessibility |
| LangGraph / CrewAI | Over-abstracted; Hermes Agent is the modern approach |
| Qdrant / Milvus / Weaviate | Extra resource overhead; FAISS is zero-cost in-process for demo data |
| Custom agent from scratch | Course teaches AgentOps (deploy, observe, manage), not agent internals |
| Mobile app | Web interface via Chainlit is sufficient |
| Enterprise auth/SSO | Demo-grade for learning |
| Langfuse (v1) | Too resource-heavy (~512MB-1GB) for KIND alongside other workloads |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| INFRA-01 | Phase 1 | Complete |
| INFRA-02 | Phase 1 | Complete |
| INFRA-03 | Phase 1 | Complete |
| INFRA-04 | Phase 1 | Complete |
| INFRA-05 | Phase 1 | Pending |
| K8S-01 | Phase 1 | Complete |
| K8S-02 | Phase 1 | Complete |
| K8S-03 | Phase 1 | Complete |
| RAG-01 | Phase 2 | Pending |
| RAG-02 | Phase 2 | Pending |
| RAG-03 | Phase 2 | Pending |
| RAG-04 | Phase 2 | Pending |
| TUNE-01 | Phase 2 | Pending |
| TUNE-02 | Phase 2 | Pending |
| TUNE-03 | Phase 2 | Pending |
| PKG-01 | Phase 2 | Pending |
| PKG-02 | Phase 2 | Pending |
| SERVE-01 | Phase 2 | Pending |
| SERVE-02 | Phase 2 | Pending |
| SERVE-03 | Phase 2 | Pending |
| UI-01 | Phase 2 | Pending |
| UI-02 | Phase 2 | Pending |
| UI-03 | Phase 2 | Pending |
| OBS-01 | Phase 2 | Pending |
| OBS-02 | Phase 2 | Pending |
| OBS-03 | Phase 2 | Pending |
| OBS-04 | Phase 2 | Pending |
| AGENT-01 | Phase 3 | Pending |
| AGENT-02 | Phase 3 | Pending |
| AGENT-03 | Phase 3 | Pending |
| AGENT-04 | Phase 3 | Pending |
| SANDBOX-01 | Phase 3 | Pending |
| SANDBOX-02 | Phase 3 | Pending |
| SANDBOX-03 | Phase 3 | Pending |
| SANDBOX-04 | Phase 3 | Pending |
| OBS-05 | Phase 3 | Pending |
| OBS-06 | Phase 3 | Pending |
| OBS-07 | Phase 3 | Pending |
| SCALE-01 | Phase 4 | Pending |
| SCALE-02 | Phase 4 | Pending |
| SCALE-03 | Phase 4 | Pending |
| GITOPS-01 | Phase 4 | Pending |
| GITOPS-02 | Phase 4 | Pending |
| GITOPS-03 | Phase 4 | Pending |
| EVAL-01 | Phase 4 | Pending |
| EVAL-02 | Phase 4 | Pending |
| GUARD-01 | Phase 4 | Pending |
| GUARD-02 | Phase 4 | Pending |
| GUARD-03 | Phase 4 | Pending |
| CAP-01 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 40 total
- Mapped to phases: 40
- Unmapped: 0

---
*Requirements defined: 2026-04-12*
*Last updated: 2026-04-12 after roadmap creation — all 40 requirements mapped*
