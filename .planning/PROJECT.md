# LLMOps & AgentOps with Kubernetes

## What This Is

A comprehensive, hands-on course that teaches how to productionize LLM applications and AI agents on Kubernetes. Students build a dental clinic assistant (Smile Dental) from scratch — starting with RAG and fine-tuning, evolving into a multi-tool agent, then deploying it with production-grade observability, autoscaling, GitOps, and Kubernetes Agent Sandbox. Designed for DevOps engineers, ML engineers, and full-stack developers. Delivered as both instructor-led 3-day workshops and a self-paced Udemy course.

## Core Value

Teach practitioners how to take AI systems (LLMs + agents) from prototype to production on Kubernetes — the only course that covers the full journey from RAG to agentic deployments with K8s Agent Sandbox.

## Requirements

### Validated

(Existing course topics — being rewritten from scratch with modernized content)

- Kubernetes cluster setup (KIND) with ImageVolumes — existing (Lab 00)
- Synthetic data generation + FAISS RAG retriever — existing (Lab 01)
- CPU LoRA fine-tuning of SmolLM2 — existing (Lab 02)
- Model packaging as OCI image — existing (Lab 03)
- Model serving with KServe + vLLM — existing (Lab 04)
- Prometheus + Grafana observability for LLM workloads — existing (Lab 05)
- Autoscaling with HPA/KEDA/VPA — existing (Lab 06)
- GitOps with ArgoCD — existing (Lab 07)
- Argo Workflows for LLM pipelines — existing (Lab 08)

(Validated in Phase 1: Course Infrastructure)

- Course infrastructure scaffold — Docusaurus site, companion code repo, preflight scripts, KIND config, cleanup scripts

(Validated in Phase 2: LLMOps Labs Day 1)

- Synthetic data generation + FAISS RAG retriever — rewritten with Smile Dental Pune data (Lab 01)
- CPU LoRA fine-tuning of SmolLM2-135M — rewritten with PEFT 0.19.0, max_steps=50 (Lab 02)
- OCI model packaging with alpine:3.20 — rewritten (Lab 03)
- Model serving with vLLM plain K8s Deployment — rewritten, no KServe (Lab 04)
- Chainlit web UI with glass-box learning mode — new (Lab 05)
- Prometheus + Grafana observability with correct vllm: metrics — rewritten (Lab 06)
- Companion code with starter/solution per lab — validated
- Domain renamed to Smile Dental globally — validated
- Docusaurus lab pages with concept explanations — 6 pages written

(Validated in Phase 02.1: Flatten workspace + uv)

- Flat `llmops-project/` workspace replaces per-lab subdirs (`lab-01/`, `lab-02/`) across all lab guides
- `uv` is primary package installer in student-facing commands (`pip` documented as fallback)

(Validated in Phase 3: AgentOps Labs Day 2)

- Hermes Agent (NousResearch v0.12.0) configured for Smile Dental — 3 MCP tool servers (triage, treatment_lookup, book_appointment) + multi-step workflow validated live (Lab 07)
- Two-phase LLM strategy — Day 2 labs switch to free-tier API; both Groq (`llama-3.3-70b-versatile`) and Gemini (`gemini-2.5-flash`) live-tested
- Kubernetes Agent Sandbox v0.4.3 — CRDs installed, agent deployed as Sandbox + SandboxWarmPool (replicas=2) + NetworkPolicy + Sandbox Router gateway (Lab 08)
- Cold-vs-warm timing demo — observed warm 7.95s / cold refill 25.03s / cold 2.54s
- Agent observability — Grafana Tempo + OTEL Collector deployed; 3 MCP tools auto-instrumented; cost middleware emits `agent_llm_tokens_total` + `agent_llm_cost_usd_total`; Grafana dashboard auto-discovered (Lab 09)
- D-18 partial compliance documented honestly: tool/retriever spans hierarchical; Hermes-internal `agent.request`/`llm.completion` not visible (closed binary)

### Active

- [ ] Structure for 3-day workshop format (~24 hours, 12-15 labs)
- [ ] Ensure all content is 2026-relevant (current AI landscape, modern frameworks, latest K8s features)
- [ ] Design for dual delivery: instructor-led workshop + Udemy self-paced course
- [ ] Evaluate and integrate LLM evaluation/testing practices (evals, guardrails)

### Out of Scope

- GPU-specific content — course stays CPU-friendly for accessibility on laptops
- Cloud-specific managed services (EKS/GKE/AKS specifics) — keep cloud-agnostic with KIND
- Mobile app or native UI — web interface only
- Enterprise auth/SSO integration — keep demo-grade for learning

## Context

**Current state:** Existing course has 9 labs (00-08) using MkDocs with readthedocs theme. All code is inline (copy-paste). Domain is "Atharva Dental Clinic" with India-specific context (INR, Pune). Application is CLI/curl-based. No agent capabilities. No web UI.

**What's changing in the AI world (2026):**
- Agentic AI is mainstream — tool-using, multi-step agents are production workloads
- Kubernetes Agent Sandbox (k8s-sigs) provides first-class primitives for agent workloads (Sandbox CRD, warm pools, isolation)
- LLM evaluation and guardrails are now expected practices
- Agent frameworks have matured (LangGraph, CrewAI, Anthropic Agent SDK, OpenAI Agents SDK)
- vLLM has evolved significantly; model serving landscape has shifted
- Observability for AI has expanded beyond basic metrics to include traces, evals, cost tracking

**Brownfield context:** The `llmops-labuide/` directory contains the existing MkDocs site with all lab content. The `slides/` directory has presentation PDFs/DOCX for 5 modules. Both will be replaced with the rewritten course.

**Target audience:** Mixed — DevOps/platform engineers, ML/AI engineers, and full-stack developers. Course must bridge Kubernetes expertise and AI/ML expertise.

**Delivery:** 3-day instructor-led workshop AND bestselling Udemy course. Code companion repo with starter/solution per module.

## Constraints

- **Duration**: ~24 hours of content fitting a 3-day workshop format (12-15 labs)
- **Hardware**: Must run on laptops with 16GB RAM, CPU-only (KIND clusters)
- **Platform**: Must work on both Windows AND macOS (Docker Desktop + KIND)
- **Code delivery**: Companion Git repo with starter/ and solution/ per module — no copy-paste walls
- **Site platform**: Docusaurus (replacing MkDocs)
- **Naming**: "Smile Dental" (not "Atharva") — globally accessible branding
- **Model size**: Small models (SmolLM2-135M or similar) that work on CPU for LLMOps labs
- **LLM API for agents**: Free-tier API access required (Google Gemini or Groq) — students must not need to pay
- **No heavy frameworks**: Avoid LangGraph/CrewAI — prefer native LLM tool-calling or lightweight approach

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Rewrite from scratch vs. update existing | User wants fresh structure, modern flow, and fundamentally different scope (adding agents, web UI, new tooling) | Rewrite from scratch |
| Rename Atharva to Smile Dental | "Atharva" is India-specific, hard to type globally; "Smile" is universally accessible | Pending implementation |
| Docusaurus over MkDocs | Modern React-based doc framework, better for course sites with interactive elements, versioning, search | Pending |
| Starter + solution code structure | Eliminates copy-paste walls; students get working starter code and can reference solutions | Pending |
| Kubernetes Agent Sandbox for agentic module | First-class K8s primitive for agent workloads — new, differentiated, production-relevant | Pending |
| Agent framework: Hermes Agent | NousResearch/hermes-agent — model-agnostic, lightweight ($5 VPS), 40+ tools, MCP support, Docker sandbox built-in, MIT licensed, 47k stars. Configure and deploy, don't build from scratch. | Decided |
| No LangGraph/CrewAI | Over-abstracted Pythonic frameworks are dated. Hermes is the modern approach — self-improving, persistent memory, multi-platform. | Decided |
| Two-phase LLM strategy | Labs 00-05 use local SmolLM2-135M (LLMOps focus). Labs 06+ switch to free-tier API (Gemini/Groq) for agentic capabilities — local 135M model can't do tool-calling reliably. | Decided |
| Support both Gemini and Groq | Abstract behind OpenAI-compatible API so students can use either free-tier provider | Decided |
| Windows + macOS support | All labs must work on both platforms via Docker Desktop + KIND | Decided |
| Dual delivery format | Workshop (3-day) + Udemy maximizes reach and revenue | Pending |
| Live cluster verification | Every phase verified against a real KIND cluster on this machine — create, run labs step-by-step, tear down. Mandatory. | Decided |
| Web UI: Chainlit | Chat-native, streaming, agent step traces, zero CSS, Docker-friendly | Decided |
| FAISS over Qdrant | Zero resource overhead (in-process). Qdrant adds ~100-500MB for no learning benefit at demo scale. | Decided |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-02 after Phase 3 completion*
