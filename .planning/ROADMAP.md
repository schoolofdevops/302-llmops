# Roadmap — v1.0.0 LLMOps with Kubernetes

**Milestone:** v1.0.0 LLMOps with Kubernetes (focused course; AgentOps split to 303-agentops)
**Granularity:** coarse
**Total v1.0.0 requirements:** 21 — all mapped (100% coverage)
**Created:** 2026-05-07

## Overview

Six phases rebuild 302-llmops as a focused LLMOps course. Phase 01 lifts AgentOps content + planning context out to `schoolofdevops/303-agentops` while preserving v0.19.0 as a tagged release. Phase 02 carries forward and re-validates the original LLMOps spine (Labs 00-05) on a clean post-migration cluster. Phase 03 introduces disk-based model loading via MinIO + initContainer (the cheapest control-plane delta and the model-source artifact store reused later). Phase 04 adds the vLLM Production Stack router for multi-pod horizontal serving. Phase 05 restores KServe `InferenceService` (Standard/RawDeployment mode) as the third serving pattern AND publishes the side-by-side serving-decision lab now that all three patterns exist. Phase 06 re-validates the production operations layer (HPA/KEDA, ArgoCD GitOps, Argo Workflows training pipeline) against all three serving patterns, with the eval gate dropped (it lives in 303-agentops now).

Phase numbering starts at 01 (`--reset-phase-numbers` mode for v1.0.0). Old v0.19.0 phases remain in `.planning/phases/` until the orchestrator/user moves them to `.planning/milestones/v0.19.0-phases/`.

## Phases

**Phase Numbering:**
- Integer phases (01, 02, 03): Planned milestone work
- Decimal phases (02.1, 02.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 01: Curriculum Migration to 303-agentops** — Tag v0.19.0, baseline 303-agentops with full context, transfer AgentOps code + planning artifacts, delete from this repo, configure Docusaurus redirects (foundational gate; nothing else can begin until this lands) (completed 2026-05-07)
- [ ] **Phase 02: Modernize LLMOps Spine (Labs 00-05)** — Carry-forward + end-to-end verification of Labs 00-05 (KIND, RAG, LoRA, OCI packaging, plain vLLM Deployment + Chainlit, Prometheus/Grafana) on the post-migration cluster, with 2026 dependency refresh
- [x] **Phase 03: Disk-Based Model Loading (MinIO + initContainer)** (completed 2026-06-15) — Add MinIO in-cluster object store + disk-loading vLLM Deployment with sentinel + sha256 verification + sized emptyDir; publish OCI-vs-disk decision lab page
- [ ] **Phase 04: vLLM Router Multi-Pod Serving** — Add vLLM Production Stack router (vllm-stack 0.1.10, pinned dev-tag) fronting two CPU backend pods with session/prefix-aware routing default; KEDA scales backends, not router
- [ ] **Phase 05: KServe InferenceService + Serving Decision Lab** — Restore KServe `InferenceService` (v0.18.0 Standard/RawDeployment mode) with custom CPU `ClusterServingRuntime`; close out with side-by-side serving-pattern comparison/decision lab (when to use each)
- [ ] **Phase 06: Production Operations Layer** — Re-validate HPA + KEDA, ArgoCD App-of-Apps, and Argo Workflows training pipeline (data → index → train → merge, no eval gate) against all three serving patterns

## Phase Details

### Phase 01: Curriculum Migration to 303-agentops
**Goal**: Future Claude/Gemini sessions on `schoolofdevops/303-agentops` can resume the AgentOps work with full context (decisions, validated configs, planning artifacts), and 302-llmops `main` carries no AgentOps content
**Depends on**: Nothing (foundational gate)
**Requirements**: MIGRATE-01, MIGRATE-02, MIGRATE-03, MIGRATE-04, MIGRATE-05
**Success Criteria** (what must be TRUE):
  1. `git tag v0.19.0` exists in this repo and is pushed to origin; `v0.19.x` maintenance branch created so existing learners' forks don't break
  2. `schoolofdevops/303-agentops` repo is initialized with `PROJECT.md`, `README.md`, `MIGRATION-FROM-302-LLMOPS.md`, and a `.planning/` baseline (decisions log, validated configs from v0.19.0 Phase 03)
  3. AgentOps code (Labs 07-13: Hermes, MCP servers, Sandbox manifests, OTEL/Tempo, guardrails, eval gate, capstone) and matching planning artifacts (`.planning/phases/03-*/`, `04-*/` agent slices) are present in 303-agentops with git history preserved
  4. AgentOps content is removed from 302-llmops; Docusaurus build succeeds with `onBrokenLinks: 'throw'`; `@docusaurus/plugin-client-redirects` covers every removed/renumbered lab URL
  5. CHANGELOG.md has an explicit "v1.0.0 — split from v0.19.0" entry and README has a "which version are you on?" section linking v0.19.0 tag, v1.0.0 main, and 303-agentops
**Plans**: 4 plans
**Estimated complexity**: M (2 repos + Docusaurus redirects; high-risk if context-transfer is mishandled — see Pitfall 9)

Plans:
- [x] 01-01-PLAN.md — Freeze v0.19.0: push tag + create v0.19.x maintenance branch
- [x] 01-02-PLAN.md — Bootstrap 303-agentops: create repo + copy labs + write dossier + push
- [x] 01-03-PLAN.md — Docusaurus redirects + title rename + CHANGELOG + repo-root README
- [x] 01-04-PLAN.md — Delete AgentOps from 302 main + verify Docusaurus build

### Phase 02: Modernize LLMOps Spine (Labs 00-05)
**Goal**: Students can run Labs 00 through 05 end-to-end on a fresh post-migration KIND cluster and arrive at a Smile Dental assistant served via plain vLLM Deployment with Chainlit UI and Prometheus/Grafana observability
**Depends on**: Phase 01
**Requirements**: SPINE-01, SPINE-02, SPINE-03, SPINE-04, SPINE-05, SPINE-06, SERVE-01 *(alias — delivered by SPINE-05 as "Pattern A")*, PACKAGE-01 *(alias — delivered by SPINE-04 as "Pattern A")*
**Success Criteria** (what must be TRUE):
  1. Lab 00 brings up a KIND cluster on KIND 1.34 + Docker Desktop on macOS arm64 (verified) and Windows amd64 (attestation pending) with ImageVolume feature gate enabled and dual ImageVolume gates verified (functional alpine ImageVolume test)
  2. Student can run Lab 01 (synthetic data + FAISS RAG) and Lab 02 (CPU LoRA fine-tune of SmolLM2-135M, max_steps=50) and produce a merged model artifact
  3. Lab 03 packages the merged model as an OCI image, and Lab 04 serves it via plain vLLM K8s Deployment + Chainlit chat UI accessible at `localhost:30300` (this Deployment is documented in Lab 04 as "Serving Pattern A")
  4. Lab 05 (Prometheus + Grafana) shows live `vllm:` metrics (TTFT, latency histogram, token throughput) on a dashboard scraped from the running vLLM pod
  5. All six labs use 2026-pinned dependency versions in `COURSE_VERSIONS.md` and verified end-to-end on a single KIND cluster session within the 16GB-RAM budget
**Plans**: 8 plans
**Estimated complexity**: M (mostly verification of carry-forward content; six labs is the ceiling on size)
**UI hint**: yes

Plans:
- [ ] 02-01-PLAN.md — Phase prep: orphan cleanup + COURSE_VERSIONS.md edits + cross-platform claim alignment (D-05, D-08, D-09, D-15, D-16, D-17)
- [ ] 02-02-PLAN.md — Structural changes: kind-config.yaml NodePort fix (GAP-1) + lab dir restructure + doc page merges + sidebars + Docusaurus build (D-01..D-04)
- [ ] 02-03-PLAN.md — Lab 00 cluster setup: bring up KIND, verify dual ImageVolume gates functionally, capture baseline budget (SPINE-01)
- [ ] 02-04-PLAN.md — Lab 01: synth data + FAISS RAG retriever; capture budget (SPINE-02)
- [ ] 02-05-PLAN.md — Lab 02: CPU LoRA fine-tune Job; capture PEAK + POST budget (SPINE-03)
- [ ] 02-06-PLAN.md — Lab 03: OCI model packaging + ImageVolume mount verify + D-18 Pattern-A teaser (SPINE-04, PACKAGE-01)
- [ ] 02-07-PLAN.md — Lab 04: plain vLLM Deployment + Chainlit UI + D-13 /metrics verify + D-19 Pattern-A teaser (SPINE-05, SERVE-01)
- [ ] 02-08-PLAN.md — Lab 05: kube-prometheus-stack 83.4.2 + ServiceMonitors + Grafana dashboard + cumulative budget + 02-VERIFICATION.md (SPINE-06)

### Phase 03: Disk-Based Model Loading (MinIO + initContainer)
**Goal**: Students can deploy the same fine-tuned model via runtime initContainer download from in-cluster MinIO instead of OCI ImageVolume, and choose between the two patterns based on model size and update cadence
**Depends on**: Phase 02
**Requirements**: PACKAGE-02, PACKAGE-03
**Success Criteria** (what must be TRUE):
  1. MinIO is installed in a `minio` namespace, accessible via NodePort 30900 (S3 API) and 30901 (console), and a one-shot `model-uploader` Job copies the Lab 02 merged model to `s3://models/smollm2-finetuned/`
  2. A `vllm-smollm2-disk` Deployment serves the model after an initContainer downloads it into a sized emptyDir (sizeLimit + matching ephemeral-storage requests + sentinel file + sha256 verification), accessible at NodePort 30203
  3. Student observes that pod restart re-downloads the model (deliberate emptyDir trade-off) and reads the lab-text contrast with the PVC alternative
  4. A decision-tree lab page documents when to use OCI ImageVolume (≤2GB, immutable promotion) vs disk-based (>2GB, frequent updates, object-store-backed)
**Plans**: 4 plans
**Estimated complexity**: S (single new infra component; pattern is straightforward; pitfalls 6 + 7 are well-known)

Plans:
- [x] 03-01-PLAN.md — GAP-2 fix: add NodePorts 30203/30900/30901 to kind-config.yaml + cluster recreate + Phase 02 stack redeploy
- [x] 03-02-PLAN.md — MinIO install (chart 5.4.0, standalone, NodePort 30900/30901) + model-uploader Job (mc upload to s3://models/smollm2-finetuned/)
- [x] 03-03-PLAN.md — vllm-smollm2-disk Deployment: initContainer + emptyDir sizeLimit:1Gi + sha256 + sentinel + NodePort 30203
- [x] 03-04-PLAN.md — Lab 06 doc page (PACKAGE-02 + PACKAGE-03 decision tree) + sidebars.ts + COURSE_VERSIONS.md

### Phase 04: vLLM Router Multi-Pod Serving
**Goal**: Students can deploy the same fine-tuned model behind a vLLM Production Stack router with two CPU backend pods, observe session/prefix-aware routing preserving KV cache, and watch KEDA scale the backends (not the router)
**Depends on**: Phase 02 (needs working plain vLLM lab as the "before" comparison)
**Requirements**: SERVE-03
**Success Criteria** (what must be TRUE):
  1. `vllm-stack` Helm chart 0.1.10 installed with `lmcache/lmstack-router` pinned to a dated dev tag (no `latest`), router pod running with `replicas: 1` and 2 vLLM CPU backends labelled `app=vllm-backend`
  2. Router service at NodePort 30201 returns identical chat responses to the existing plain-vLLM NodePort 30200 (router is transparent), and `kubectl get endpoints` shows both backend IPs
  3. Lab default routing logic is `session` or `prefixaware` (not round-robin); a benchmark step shows multi-turn chat is faster with session routing than with round-robin (Pitfall 1)
  4. KEDA ScaledObject targets `Deployment/vllm-backend` (not the router) with metric `sum(vllm:num_requests_waiting{app="vllm-backend"})`, `minReplicaCount: 1`, `maxReplicaCount: 3`, and load-driven scale-up is observable
  5. Lab teardown command leaves the cluster ready for Phase 05 (16GB headroom restored)
**Plans**: TBD
**Estimated complexity**: M (live-cluster-verification gate item: vllm-stack 0.1.10 + `vllm/vllm-openai-cpu` end-to-end on KIND has not been validated upstream)

### Phase 05: KServe InferenceService + Serving Decision Lab
**Goal**: Students can deploy the same fine-tuned model via KServe `InferenceService` (Standard/RawDeployment mode, no Knative, no Istio) and choose between plain Deployment, vLLM Router, and KServe based on a published decision tree
**Depends on**: Phase 04 (needs all three serving patterns coexisting before the decision-lab page can be written meaningfully)
**Requirements**: SERVE-02, SERVE-04
**Success Criteria** (what must be TRUE):
  1. cert-manager v1.16.x and Gateway API CRDs v1.2.1 installed; KServe v0.18.0 installed in `kserve` namespace via OCI Helm chart with `deploymentMode=Standard` (Knative + Istio confirmed absent)
  2. Custom CPU `ClusterServingRuntime` (wrapping `vllm/vllm-openai-cpu`) is registered, and an `InferenceService` `smollm2` reaches `READY: True` with the same fine-tuned model accessible at NodePort 30202
  3. Predictor readiness probe is tuned for CPU model load (initialDelaySeconds≥90, failureThreshold≥30) — pod does not crashloop on first start (Pitfall 11)
  4. The serving-decision lab page publishes a side-by-side comparison table (lines of YAML, scaling primitive, storage, cluster overhead) and a decision tree for plain vs router vs KServe, validated against students' actual experience from Phases 02-05
  5. Lab calls out arm64-on-Mac as a known gate item (built-in `kserve-huggingfaceserver` image is amd64-only at v0.18) and provides the custom CPU runtime as the arm64-tolerant path
**Plans**: TBD
**Estimated complexity**: L (largest control-plane footprint of all serving patterns; KServe install fragility on KIND is a documented hazard — Pitfall 4; arm64 fallback path needs live verification)

### Phase 06: Production Operations Layer
**Goal**: Students operate all three serving patterns under autoscaling, GitOps, and a training pipeline — closing the LLMOps lifecycle (data → fine-tune → package → serve → observe → scale → GitOps → automated retrain)
**Depends on**: Phase 05 (production ops layer must validate against all three serving patterns)
**Requirements**: OPS-01, OPS-02, OPS-03
**Success Criteria** (what must be TRUE):
  1. HPA on Chat API (CPU-based) and KEDA on vLLM (Prometheus metric `vllm:num_requests_waiting`) are validated against all three SERVE patterns: plain Deployment, vLLM Router (KEDA on backends), and KServe (KEDA on predictor) — load test shows scale-up/down for each
  2. ArgoCD App-of-Apps manages vLLM (any of the three patterns), MinIO, Chainlit, and observability stack from a `gitops-repo`; a `kubectl tag` promotion via Git commit triggers automatic redeployment within 70s (matches v0.19.0 GITOPS-02 evidence)
  3. Argo Workflows `WorkflowTemplate` runs the full DAG `data → index → train → merge` to completion as a `Workflow` and persists artifacts to MinIO — NO eval gate, NO commit-tag step (those are 303-agentops scope)
  4. End-to-end run shows: a code/config change in Git → ArgoCD reconciles → Argo Workflow re-runs the training pipeline → new model artifact lands in MinIO → vLLM redeploys with the new artifact (closes the LLMOps loop)
**Plans**: TBD
**Estimated complexity**: M (mostly carry-forward from v0.19.0 Phase 04 with eval gate removed; the new work is re-validating against three serving patterns and confirming the loop closes end-to-end)

## Progress

**Execution Order:**
Phases execute in numeric order: 01 → 02 → 03 → 04 → 05 → 06

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 01. Curriculum Migration to 303-agentops | 4/4 | Complete    | 2026-05-07 |
| 02. Modernize LLMOps Spine (Labs 00-05) | 0/8 | Not started | - |
| 03. Disk-Based Model Loading (MinIO + initContainer) | 0/4 | Not started | - |
| 04. vLLM Router Multi-Pod Serving | 0/TBD | Not started | - |
| 05. KServe InferenceService + Serving Decision Lab | 0/TBD | Not started | - |
| 06. Production Operations Layer | 0/TBD | Not started | - |

## Coverage

All 21 v1.0.0 requirements mapped (no orphans):

| Category | Requirements | Phase |
|----------|--------------|-------|
| MIGRATE | MIGRATE-01..05 (5) | 01 |
| SPINE | SPINE-01..06 (6) | 02 |
| SERVE | SERVE-01 *(alias of SPINE-05)*, SERVE-02 (KServe), SERVE-03 (Router), SERVE-04 (decision lab) | 02 (alias), 04, 05, 05 |
| PACKAGE | PACKAGE-01 *(alias of SPINE-04)*, PACKAGE-02 (disk), PACKAGE-03 (decision page) | 02 (alias), 03, 03 |
| OPS | OPS-01, OPS-02, OPS-03 | 06 |

Aliases:
- **SERVE-01** is delivered by **SPINE-05** (Lab 04 plain vLLM Deployment) and documented as "Pattern A" in the Phase 05 serving-decision lab
- **PACKAGE-01** is delivered by **SPINE-04** (Lab 03 OCI ImageVolume) and documented as "Pattern A" in the Phase 03 packaging-decision lab

Out-of-scope for this milestone (deferred to v1.1, NOT mapped here): GOVERN-01..05, API-01..02, GPU-01..06.

## Notes for Plan-Phase

- **Live-cluster verification gates** to resolve at plan-phase time: vllm-stack 0.1.10 + `vllm/vllm-openai-cpu` on KIND (Phase 04), KServe v0.18 `kserve-huggingfaceserver` arm64 (Phase 05), exact pinned `lmstack-router` tag (Phase 04), exact resource budgets per lab on real 16GB laptop (Phase 02-06)
- **Mandatory teardown** between Phases 04, 05, 06 — all four serving variants do not fit on 16GB simultaneously (PITFALLS.md "Pattern table"). Each phase plan must include a teardown step
- **GitOps round-trip per phase** is anti-pattern — defer all GitOps integration to Phase 06's OPS-02 lab (don't re-teach in Phases 03, 04, 05)
- **Phase 01 is a context-transfer, not a file-copy** — give it real time; the planning artifacts (`.planning/phases/03-*/`, decisions log, validated configs) are the migration, not the code
