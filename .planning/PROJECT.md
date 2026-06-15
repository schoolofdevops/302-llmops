# LLMOps with Kubernetes

## What This Is

A comprehensive, hands-on course on **LLMOps** — bringing DevOps practices to LLM and GenAI systems on Kubernetes. Students build Smile Dental — a CPU-only RAG + fine-tuned model serving stack — and learn to operate every layer of a real LLM deployment. Covers the full LLMOps lifecycle: synthetic data → RAG → CPU LoRA fine-tuning → model packaging (OCI + disk-based) → three serving patterns (plain vLLM Deployment, KServe InferenceService, vLLM Router multi-pod) → observability → autoscaling → GitOps → training pipelines. Future milestones add GPU instructor-led demos (training, serving, right-sizing, cost economics), governance/guardrails/cost tracking, and AI API alternative for build-vs-buy comparison. Designed for DevOps/SRE engineers, ML engineers, and platform engineers. Delivered as instructor-led workshop + self-paced Udemy course.

**Companion course:** AgentOps content (Hermes Agent, MCP tools, Kubernetes Agent Sandbox, guardrails, eval gates, capstone) moved to a separate course in repo `schoolofdevops/303-agentops`. Builds on this LLMOps foundation.

## Core Value

Teach practitioners LLMOps — applying DevOps discipline (CI/CD, GitOps, observability, autoscaling, IaC, automation) to the full LLM/GenAI lifecycle on Kubernetes. The only course that covers data → fine-tune → package → serve → observe → scale → GitOps with multiple serving patterns (plain vLLM, KServe, vLLM Router, optional AI API), and bridges the CPU-laptop / GPU-production gap with instructor-led GPU demos covering right-sizing, cost economics, and training workflows.

## Current Milestone: v1.0.0 LLMOps with Kubernetes

**Goal:** Rebuild 302-llmops as a comprehensive LLMOps course — drop AgentOps content (split to 303-agentops), restore + modernize the original lab guide curriculum (which already used KServe RawDeployment), add new serving + packaging patterns, and add GPU instructor demos.

**Target features:**

*Curriculum split:*
- Drop AgentOps content (Hermes, MCP, Agent Sandbox, guardrails, eval gate, capstone) — moves to 303-agentops
- Migrate AgentOps content to 303-agentops with thorough README + planning context (PROJECT.md equivalent) so future sessions on that repo have full context (not just code-move)

*Restore + modernize original LLMOps spine:*
- Modernize original lab guide curriculum (llmops-labuide Labs 00-08) for 2026 stack
- Restore KServe InferenceService (RawDeployment mode) as the original Lab 4 approach used — v0.19.0 had dropped this for plain Deployment

*Add new serving patterns (multiple ways to serve LLMs in production):*
- Plain vLLM Deployment (baseline — already in v0.19.0)
- KServe InferenceService RawDeployment (managed serving abstraction — original approach)
- vLLM Router + multi-pod horizontal serving (production scale-out pattern)
- (Optional) AI API service alternative — show how to integrate Groq/Gemini if free quota available, and when API is the right choice vs self-hosted vLLM

*Add new model packaging patterns:*
- OCI image + ImageVolume (existing in v0.19.0)
- Disk-based loading via initContainer download (PVC or emptyDir, MinIO-backed) — production pattern for large models
- Decision tree: when to use OCI vs disk-based

*Production operations:*
- Argo Workflows training pipeline (data→index→train→merge), no eval gate (eval is in 303-agentops)
- HPA + KEDA autoscaling (existing in v0.19.0)
- ArgoCD GitOps App-of-Apps (existing in v0.19.0)

*Constraints preserved:*
- All hands-on labs CPU-only, KIND, 16GB RAM
- Cross-platform (macOS + Windows + Linux)

*Deferred to v1.1 (next milestone):*
- GOVERN: model registry, inference-layer guardrails, distributed tracing, token-cost tracking, audit trails
- GPU instructor demos (right-sizing, cost economics, training, serving) — uses instructor's GCP credits
- API: optional AI API alternative (Groq/Gemini) for build-vs-buy comparison

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

(Validated in v1.0.0 Phase 01: Curriculum Migration to 303-agentops)

- v0.19.0 release tagged + pushed to origin; v0.19.x maintenance branch active so existing learners' forks resolve to a frozen working state
- `schoolofdevops/303-agentops` repo bootstrapped with PROJECT.md, README.md, MIGRATION-FROM-302-LLMOPS.md, full Phase 03 planning archive, agent slices of Phase 04 planning, and lab-07..13 code+docs (single fresh-copy bootstrap commit per D-01; history preserved via 302-llmops v0.19.0 tag, NOT git filter-repo)
- 302-llmops main carries no AgentOps content: lab-07..13 deleted; Docusaurus title renamed to "LLMOps with Kubernetes"; `@docusaurus/plugin-client-redirects@3.10.0` covers all 7 removed lab URLs; site builds with `onBrokenLinks: 'throw'` exit 0
- CHANGELOG.md `## v1.0.0 — split from v0.19.0` entry + repo-root README.md "Which version are you on?" version selector linking v0.19.0 tag, v1.0.0 main, and 303-agentops

### Active

(SPINE/SERVE/PACKAGE/OPS — to be validated in Phases 02-06; see REQUIREMENTS.md)

### Out of Scope

- **GPU-required hands-on labs** — all student labs stay CPU-friendly (16GB RAM laptops). GPU content is **instructor demo only** (videos/live demos using instructor's GCP credits). Students don't need GPU access.
- Cloud-specific managed serving (Vertex AI, SageMaker JumpStart) — keep cloud-agnostic; show patterns that work on EKS/GKE/AKS/on-prem
- Mobile app or native UI — web interface only (Chainlit)
- Enterprise auth/SSO integration — keep demo-grade for learning
- **AgentOps content** — Hermes Agent, MCP tool servers, Kubernetes Agent Sandbox, multi-tool agent workflows, GuardrailMiddleware, DeepEval eval gates, insurance_check capstone, governance/audit trails. Moved to companion course `schoolofdevops/303-agentops`. Rationale: combining LLMOps + AgentOps in one course diluted both; learners couldn't do justice to either.
- **Eval gate in Argo Workflows pipeline** — eval gating belongs in AgentOps course where it's contextually relevant. LLMOps pipeline lab focuses on orchestration of training pipeline (data→index→train→merge), not quality gating.
- **Knative serverless mode for KServe** — adds ~1.5GB RAM (Knative + Istio + cert-manager); not justifiable on 16GB laptops. KServe RawDeployment delivers managed serving abstraction without the dependency chain.

## Context

**Current state (post v0.19.0):** v0.19.0 shipped a combined LLMOps + AgentOps 3-day workshop. Strategic decision: split into two focused courses. This repo (302-llmops) becomes LLMOps-only. AgentOps work moves to 303-agentops.

**Why split:** Combining LLMOps + AgentOps in one 3-day course diluted both. LLMOps deserves deep coverage (data→fine-tune→serve→scale→GitOps with multiple serving patterns). AgentOps deserves its own course (agent architecture, MCP tools, sandbox, guardrails, evals). Splitting allows justice to each topic.

**Brownfield context:**
- `llmops-labuide/` (NOT in repo, separate dir) — original MkDocs lab guide (Labs 00-08) — reference for original curriculum coverage
- v0.19.0 phases archived to `.planning/milestones/v0.19.0-phases/`
- Existing `course-content/docs/labs/` and `course-code/labs/` from v0.19.0 — most LLMOps content (Labs 0-6 in current numbering) is reusable; agent labs (07-13) need to be removed and migrated to 303-agentops

**What's new for v1.0.0:**
- vLLM Router pattern for multi-pod horizontal serving (production-grade alternative to single vLLM Deployment)
- KServe InferenceService as managed serving abstraction (compare/contrast with raw Deployment)
- Disk-based model loading (download-on-startup) alongside OCI ImageVolume — image approach doesn't scale to large models, disk pattern matches real-world deployments
- Argo Workflows kept as training pipeline orchestrator (no eval gate — that belongs in 303-agentops)

**Target audience:** DevOps/SRE engineers, ML engineers, platform engineers. Bridges Kubernetes operational expertise and LLM serving operations.

**Delivery:** Instructor-led workshop + Udemy self-paced course. Companion code repo with starter/solution per lab.

## Constraints

- **Duration**: Tighter than v0.19.0's 3-day combined course — to be sized by roadmap (likely 2-2.5 days, 9-11 labs)
- **Hardware**: Must run on laptops with 16GB RAM, CPU-only (KIND clusters)
- **Platform**: Must work on both Windows AND macOS (Docker Desktop + KIND). Apple Silicon is the primary verification target for v1.0.0; Intel mac (macOS amd64) is no longer a supported claim (out of mainstream sale since 2023). Windows x86-64 follows the same Docker Desktop + KIND path documented per-lab; full attestation tracked in each phase VERIFICATION.md.
- **Code delivery**: Companion Git repo with starter/ and solution/ per lab — no copy-paste walls
- **Site platform**: Docusaurus (already established v0.19.0)
- **Naming**: "Smile Dental" (already established v0.19.0)
- **Model size**: Small models (SmolLM2-135M) for fine-tuning labs; larger 1-3B models considered for serving labs that don't require training
- **No agent framework dependency**: This course covers LLM serving infrastructure, not agent orchestration — agent content lives in 303-agentops

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
| Split LLMOps and AgentOps into two courses | v0.19.0 combined course diluted both topics; learners couldn't go deep on either. Splitting allows each course to do justice to its domain. | Decided 2026-05-07 |
| Move AgentOps to schoolofdevops/303-agentops | Companion course builds on LLMOps foundation; separate repo isolates dependencies and sequencing. | Decided 2026-05-07 |
| Add vLLM Router multi-pod serving lab | Single vLLM Deployment is fine for demos but doesn't show production horizontal serving pattern. vLLM Router solves multi-pod load balancing. | Decided 2026-05-07 |
| Add KServe InferenceService lab (separate from raw Deployment lab) | KServe is the standard managed serving abstraction; learners need to compare/contrast with raw Deployment to understand trade-offs. | Decided 2026-05-07 |
| Add disk-based model loading lab alongside OCI ImageVolume | OCI ImageVolume approach doesn't scale to multi-GB models (image size, registry limits). Real production downloads from object storage at startup. Both patterns covered. | Decided 2026-05-07 |
| Drop eval gate from Argo Workflows pipeline | Eval gating is contextually agentic (eval = quality of agent responses). LLMOps pipeline lab teaches orchestration of training pipeline, not response quality. Eval moves to 303-agentops. | Decided 2026-05-07 |
| Restore KServe (RawDeployment mode) | Original llmops-labuide Lab 4 used `serving.kserve.io/v1beta1 InferenceService` with RawDeployment — v0.19.0 had dropped this for plain Deployment. Restoring the original approach AND adding plain Deployment as comparison. RawDeployment avoids Knative/Istio overhead on 16GB laptops. | Decided 2026-05-07 |
| GPU content as instructor demos, not student labs | Many students want to know how to right-size GPU instances, cost economics, and GPU training/serving — but expecting GPU access excludes most learners. Solution: use instructor's GCP credits for recorded/live demo modules; hands-on labs stay CPU-only. | Decided 2026-05-07 |
| Optional AI API service comparison | Show vLLM self-hosted vs API-based (Groq/Gemini free tier) so students understand the build-vs-buy tradeoff. Conditional on free quota availability — gracefully skipped if not available. | Decided 2026-05-07 |
| Course framing: LLMOps = DevOps for LLM/GenAI = production-grade by definition | LLMOps inherently means bringing DevOps practices (CI/CD, GitOps, observability, autoscaling, IaC) to LLM/GenAI systems. "Production-grade" is the definition of LLMOps, not a separate selling point. Course covers all relevant components for production deployments including GPU demos and API alternatives. | Decided 2026-05-07 |

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
*Last updated: 2026-05-07 — Phase 01 (Curriculum Migration to 303-agentops) complete; v0.19.0 frozen, 303-agentops bootstrapped, 302-llmops main is LLMOps-only*
