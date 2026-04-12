# Roadmap: LLMOps & AgentOps with Kubernetes

## Overview

Four phases build a complete hands-on course from scaffolding to production operations. Phase 1 establishes the course infrastructure (Docusaurus site, repo structure, preflight scripts). Phase 2 delivers Day 1 labs covering the full LLMOps lifecycle on local SmolLM2 — RAG, fine-tuning, packaging, serving, web UI, and LLM observability. Phase 3 delivers Day 2 labs where the assistant evolves into a Hermes-powered multi-tool agent deployed on Kubernetes Agent Sandbox with OTEL tracing. Phase 4 completes Day 3 with production operations — autoscaling, GitOps, Argo Workflows pipelines, evals, guardrails, and a capstone exercise.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Course Infrastructure** - Repo scaffold, Docusaurus site, preflight validation, version pinning, K8s setup lab
- [ ] **Phase 2: LLMOps Labs (Day 1)** - RAG, fine-tuning, packaging, serving, web UI, and LLM observability labs using local SmolLM2
- [ ] **Phase 3: AgentOps Labs (Day 2)** - Hermes Agent with custom tools, K8s Agent Sandbox deployment, and agent observability with OTEL
- [ ] **Phase 4: Production Ops + Capstone (Day 3)** - Autoscaling, GitOps, Argo Workflows pipelines, eval gate, guardrails, and capstone exercise

## Phase Details

### Phase 1: Course Infrastructure
**Goal**: Students can open the course site, clone the companion repo, run preflight, and spin up a KIND cluster — everything needed before touching a lab
**Depends on**: Nothing (first phase)
**Requirements**: INFRA-01, INFRA-02, INFRA-03, INFRA-04, INFRA-05, K8S-01, K8S-02, K8S-03
**Success Criteria** (what must be TRUE):
  1. Docusaurus site builds and serves the course with workshop and Udemy navigation paths
  2. Companion repo has starter/ and solution/ directories for every lab module
  3. Preflight script runs on Windows and macOS and validates Docker Desktop memory, disk, and K8s version
  4. COURSE_VERSIONS.md pins all dependency versions and KIND cluster setup succeeds with ImageVolume feature gates
  5. Cleanup scripts exist for each resource-heavy lab section and reduce cluster load when executed
**Plans**: 5 plans

Plans:
- [x] 01-01-PLAN.md — Code repo skeleton (14 lab dirs with starter/solution, shared/, config.env)
- [x] 01-02-PLAN.md — Docusaurus 3.10.0 site scaffold with sidebar, dark theme, 14 lab placeholder pages
- [x] 01-03-PLAN.md — Cross-platform preflight scripts (bash + PowerShell, Docker/tools/port/cluster checks)
- [x] 01-04-PLAN.md — KIND cluster config (dual ImageVolume gates), bootstrap-kind.sh, namespaces.yaml, COURSE_VERSIONS.md
- [x] 01-05-PLAN.md — Cleanup scripts for phase transitions (cleanup-phase1/2/3.sh)

### Phase 2: LLMOps Labs (Day 1)
**Goal**: Students complete Day 1 labs and have a running dental assistant — synthetic data generated, model fine-tuned on CPU, packaged as OCI image, served via vLLM/KServe, accessible through a chat UI, with Prometheus/Grafana dashboards showing LLM metrics
**Depends on**: Phase 1
**Requirements**: RAG-01, RAG-02, RAG-03, RAG-04, TUNE-01, TUNE-02, TUNE-03, PKG-01, PKG-02, SERVE-01, SERVE-02, SERVE-03, UI-01, UI-02, UI-03, OBS-01, OBS-02, OBS-03, OBS-04
**Success Criteria** (what must be TRUE):
  1. Student can query the FAISS retriever and see relevant Smile Dental clinic documents returned
  2. LoRA fine-tuning job completes as a Kubernetes Job and produces a merged model artifact
  3. Fine-tuned model is packaged as an OCI image, mounted via ImageVolumes, and served by vLLM behind KServe
  4. Chainlit chat UI is accessible via NodePort, shows streaming responses, and is connected to the full RAG + LLM pipeline
  5. Grafana dashboard shows vLLM TTFT, latency, and token throughput scraped from Prometheus
**Plans**: TBD
**UI hint**: yes

### Phase 3: AgentOps Labs (Day 2)
**Goal**: Students deploy Hermes Agent configured for Smile Dental, demonstrate a multi-step agent workflow using a free-tier LLM API, run it inside Kubernetes Agent Sandbox with isolation, and observe tool-call traces end-to-end via OTEL
**Depends on**: Phase 2
**Requirements**: AGENT-01, AGENT-02, AGENT-03, AGENT-04, SANDBOX-01, SANDBOX-02, SANDBOX-03, SANDBOX-04, OBS-05, OBS-06, OBS-07
**Success Criteria** (what must be TRUE):
  1. Hermes Agent handles a multi-step workflow (symptom → triage → treatment lookup → appointment booking) using Gemini or Groq free-tier API
  2. Agent uses the existing RAG retriever as a tool and produces answers grounded in Smile Dental data
  3. Agent runs as a Kubernetes Sandbox resource with isolation and is accessible via Sandbox stable gateway identity
  4. SandboxWarmPool is configured and a cold-start vs warm-start timing comparison is observable
  5. OTEL traces show distributed spans across agent → retriever → LLM calls, visualized in Grafana Tempo or Jaeger
**Plans**: TBD

### Phase 4: Production Ops + Capstone (Day 3)
**Goal**: Students operate the system in production mode — autoscaling under load, all components managed by ArgoCD via GitOps, model pipeline automated as an Argo Workflow with an eval quality gate, guardrails protecting the agent, and a capstone that exercises the full stack end to end
**Depends on**: Phase 3
**Requirements**: SCALE-01, SCALE-02, SCALE-03, GITOPS-01, GITOPS-02, GITOPS-03, EVAL-01, EVAL-02, GUARD-01, GUARD-02, GUARD-03, CAP-01
**Success Criteria** (what must be TRUE):
  1. HPA and KEDA ScaledObjects scale the Chat API in response to a load generator job and the scaling is visible in Grafana
  2. ArgoCD manages all components via App-of-Apps; a model tag update in Git triggers automatic redeployment
  3. Argo Workflows DAG runs the full data → train → package → deploy pipeline and halts on eval failure
  4. DeepEval quality gate blocks a deployment when RAG faithfulness drops below threshold
  5. Agent input and output guardrails block out-of-scope medical advice and the capstone exercise completes successfully end to end
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Course Infrastructure | 4/5 | In Progress|  |
| 2. LLMOps Labs (Day 1) | 0/TBD | Not started | - |
| 3. AgentOps Labs (Day 2) | 0/TBD | Not started | - |
| 4. Production Ops + Capstone (Day 3) | 0/TBD | Not started | - |
