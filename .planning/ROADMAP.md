# Roadmap: LLMOps & AgentOps with Kubernetes

## Overview

Four phases build a complete hands-on course from scaffolding to production operations. Phase 1 establishes the course infrastructure (Docusaurus site, repo structure, preflight scripts). Phase 2 delivers Day 1 labs covering the full LLMOps lifecycle on local SmolLM2 — RAG, fine-tuning, packaging, serving, web UI, and LLM observability. Phase 3 delivers Day 2 labs where the assistant evolves into a Hermes-powered multi-tool agent deployed on Kubernetes Agent Sandbox with OTEL tracing. Phase 4 completes Day 3 with production operations — autoscaling, GitOps, Argo Workflows pipelines, evals, guardrails, and a capstone exercise.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Course Infrastructure** - Repo scaffold, Docusaurus site, preflight validation, version pinning, K8s setup lab
- [x] **Phase 2: LLMOps Labs (Day 1)** - RAG, fine-tuning, packaging, serving, web UI, and LLM observability labs using local SmolLM2 (completed 2026-04-23)
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
**Goal**: Students complete Day 1 labs and have a running Smile Dental assistant — synthetic data generated, model fine-tuned on CPU, packaged as OCI image, served via vLLM (plain K8s Deployment), accessible through a Chainlit glass-box chat UI, with Prometheus/Grafana dashboards showing LLM metrics
**Depends on**: Phase 1
**Requirements**: RAG-01, RAG-02, RAG-03, RAG-04, TUNE-01, TUNE-02, TUNE-03, PKG-01, PKG-02, SERVE-01, SERVE-02, SERVE-03, UI-01, UI-02, UI-03, OBS-01, OBS-02, OBS-03, OBS-04
**Success Criteria** (what must be TRUE):
  1. Student can query the FAISS retriever and see relevant Smile Dental clinic documents returned
  2. LoRA fine-tuning job completes as a Kubernetes Job and produces a merged model artifact
  3. Fine-tuned model is packaged as an OCI image, mounted via ImageVolumes, and served by vLLM (plain K8s Deployment, no KServe)
  4. Chainlit chat UI is accessible via NodePort, shows streaming responses with glass-box Steps, and is connected to the full RAG + LLM pipeline
  5. Grafana dashboard shows vLLM TTFT, latency, and token throughput scraped from Prometheus (using vllm: metric prefix)
**Plans**: 7 plans

Plans:
- [x] 02-01-PLAN.md — Fix config.env + COURSE_VERSIONS.md vLLM image (schoolofdevops → official vllm/vllm-openai-cpu:v0.19.0-x86_64)
- [x] 02-02-PLAN.md — Lab 01 code: Smile Dental synthetic dataset (5 JSON files) + FAISS RAG retriever (build_index.py, retriever.py, K8s manifests)
- [x] 02-03-PLAN.md — Lab 02 code: CPU LoRA fine-tuning (train_lora.py, merge_lora.py, Dockerfile, K8s Job YAML)
- [x] 02-04-PLAN.md — Lab 03+04 code: OCI model packaging (Dockerfile.model-asset, build script) + vLLM K8s Deployment (plain Deployment, no KServe)
- [x] 02-05-PLAN.md — Lab 05 code: Chainlit web UI with glass-box Steps (app.py, config.toml, CSS, K8s Deployment)
- [x] 02-06-PLAN.md — Lab 06 code: Prometheus + Grafana observability (3 ServiceMonitors, Grafana dashboard ConfigMap with vllm: metrics)
- [x] 02-07-PLAN.md — Docusaurus lab guide pages for all 6 Day 1 labs (rewrites placeholder pages with complete instructions)

### Phase 02.1: Flatten workspace and switch to uv (INSERTED)

**Goal:** Lab guides use a flat `llmops-project/` workspace (no per-lab sub-directories) consistent with K8s mount paths, and student-facing pip commands are replaced with uv for faster installs
**Requirements**: FLAT-01, FLAT-02, FLAT-03
**Depends on:** Phase 2
**Success Criteria** (what must be TRUE):
  1. All lab guide workspace paths use flat `llmops-project/` with no `lab-01/` sub-directory nesting
  2. Student-facing pip install commands replaced with `uv pip install --system` in labs 01 and 02
  3. Lab 01 includes uv installation instructions before the first uv command
  4. K8s manifest pip commands inside YAML code blocks and course-code/ files are untouched
  5. Cross-lab data dependency paths are consistent (lab-03 references `llmops-project/datasets/train/`)
**Plans:** 1/1 plans complete

Plans:
- [x] 02.1-01-PLAN.md — Flatten workspace paths in labs 01-03 + switch pip to uv in labs 01-02

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
**Plans**: 7 plans

Plans:
- [x] 03-01-PLAN.md — COURSE_VERSIONS.md + config.env Day 2 pins + Lab 06 wind-down (D-19/D-20)
- [x] 03-02-PLAN.md — Lab 07 code: Hermes startup verification + 3 MCP tool servers (TDD) + Hermes config + Docker Compose + Day-2 Chainlit
- [x] 03-03-PLAN.md — Lab 07 Docusaurus walkthrough page (course-content/docs/labs/lab-07-agent-core.md)
- [x] 03-04-PLAN.md — Lab 08 code: Agent Sandbox v0.4.3 install + Router image verify + 13 K8s manifests + cold/warm demo + book_appointment K8s mode
- [x] 03-05-PLAN.md — Lab 08 Docusaurus walkthrough page (course-content/docs/labs/lab-08-agent-sandbox.md)
- [x] 03-06-PLAN.md — Lab 09 code: Tempo + OTEL Collector Helm install + MCP OTEL instrumentation + cost middleware proxy + Grafana dashboard
- [x] 03-07-PLAN.md — Lab 09 Docusaurus walkthrough page (course-content/docs/labs/lab-09-observability.md)

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
| 1. Course Infrastructure | 5/5 | Complete |  |
| 2. LLMOps Labs (Day 1) | 7/7 | Complete   | 2026-04-23 |
| 2.1 Flatten workspace + uv | 0/1 | Not started | - |
| 3. AgentOps Labs (Day 2) | 5/7 | In Progress|  |
| 4. Production Ops + Capstone (Day 3) | 0/TBD | Not started | - |
