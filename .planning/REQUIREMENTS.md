# Requirements — v1.0.0 LLMOps with Kubernetes

**Milestone:** v1.0.0
**Status:** Defined 2026-05-07; mapped to phases 2026-05-07
**Course goal:** Apply DevOps discipline (CI/CD, GitOps, observability, autoscaling, IaC, automation) to the full LLM/GenAI lifecycle on Kubernetes.

---

## v1.0.0 Requirements

### MIGRATE — Curriculum migration to 303-agentops (foundational)

Foundational; gates all other v1.0.0 work. v0.19.0 must be tagged + 303-agentops baselined before main mutates.

- [x] **MIGRATE-01**: Tag and push `v0.19.0` release in this repo before any v1.0.0 content lands on main; create `v0.19.x` maintenance branch
- [x] **MIGRATE-02**: Bootstrap `schoolofdevops/303-agentops` repo with PROJECT.md, README, MIGRATION-FROM-302-LLMOPS.md, and `.planning/` baseline
- [x] **MIGRATE-03**: Transfer AgentOps code (Labs 7-13: Hermes Agent, MCP tools, Sandbox, OTEL/Tempo, guardrails, eval gate, capstone) to 303-agentops with git history preserved (git filter-repo)
- [x] **MIGRATE-04**: Transfer AgentOps planning context (.planning/phases/03-* and 04-* archives, decisions log, accumulated context, validated configs) to 303-agentops as durable handoff
- [ ] **MIGRATE-05**: Delete AgentOps content from 302-llmops; configure Docusaurus `@docusaurus/plugin-client-redirects` for renumbered/removed labs; set `onBrokenLinks: 'throw'`

### SPINE — Restore + modernize LLMOps Labs 00-06

Carry forward from v0.19.0; verify each lab end-to-end on post-migration cluster; refresh dependency pins for 2026 stack.

- [ ] **SPINE-01**: Lab 00 (KIND cluster setup) — verify end-to-end on post-migration cluster; refresh KIND/k8s versions if needed
- [ ] **SPINE-02**: Lab 01 (Synthetic data + RAG retriever) — verify end-to-end
- [ ] **SPINE-03**: Lab 02 (CPU LoRA fine-tuning of SmolLM2-135M) — verify end-to-end
- [ ] **SPINE-04**: Lab 03 (OCI ImageVolume packaging) — verify end-to-end
- [ ] **SPINE-05**: Lab 04 (plain vLLM Deployment + Chat API + Chainlit UI) — verify end-to-end; this becomes the baseline for SERVE patterns
- [ ] **SPINE-06**: Lab 05 (Prometheus + Grafana observability for vLLM) — verify end-to-end

### SERVE — Three serving patterns as sibling labs

Same fine-tuned model, three deployment styles. Side-by-side comparison.

- [ ] **SERVE-01**: Pattern A — plain vLLM Deployment baseline (already delivered by SPINE-05; documented as "Pattern A" in comparison)
- [ ] **SERVE-02**: Pattern B — KServe `InferenceService` Standard/RawDeployment mode lab (KServe v0.18.0; restored from original llmops-labuide Lab 4); cert-manager + Gateway API CRDs prerequisites; custom CPU `ClusterServingRuntime` for vllm/vllm-openai-cpu
- [ ] **SERVE-03**: Pattern C — vLLM Production Stack router multi-pod horizontal serving lab (vllm-stack 0.1.10); router + 2 backends; routing strategy comparison (round-robin vs prefix-aware vs session); KEDA scales backend pods (not router)
- [ ] **SERVE-04**: Comparison/decision lab page — when to use each pattern (table + decision tree based on model size, traffic pattern, ops maturity)

### PACKAGE — Two model packaging patterns

OCI image (existing) + disk-based loading (new). Decision tree.

- [ ] **PACKAGE-01**: Pattern A — OCI ImageVolume packaging baseline (already delivered by SPINE-04; documented as "Pattern A" in comparison)
- [ ] **PACKAGE-02**: Pattern B — disk-based loading lab via MinIO + initContainer download; explicit `sizeLimit` on emptyDir; matching `ephemeral-storage` requests; sentinel file + sha256 verification
- [ ] **PACKAGE-03**: Comparison/decision lab page — when to use OCI ImageVolume vs disk-based (model size, registry constraints, startup time tradeoffs)

### OPS — Production operations layer

Re-validate v0.19.0 ops against all 3 serving patterns; drop eval gate.

- [ ] **OPS-01**: Autoscaling lab — HPA on Chat API (CPU-based) + KEDA on vLLM (Prometheus metric `vllm:num_requests_waiting`); validate behavior against all 3 SERVE patterns
- [ ] **OPS-02**: GitOps lab — ArgoCD App-of-Apps managing vLLM/KServe/Router/MinIO/Chainlit; vLLM tag promotion via Git commit; declarative model promotion demo
- [ ] **OPS-03**: Argo Workflows training pipeline lab — DAG: data → index → train → merge (NO eval gate, NO commit-tag step; eval moved to 303-agentops)

---

## Future Requirements (v1.1 and beyond)

### v1.1 — GOVERN: Model governance, guardrails, cost tracking, extended observability

Confirmed for v1.1 milestone (per user direction 2026-05-07 — "same with governance, we will add most aspects in 1.1").

- [ ] **GOVERN-01**: Model registry / versioning — track dataset version → adapter version → deployed model in MinIO/Git
- [ ] **GOVERN-02**: Input/output guardrails at the inference layer (PII redaction, toxicity filter, rate limiting) — distinct from agent guardrails (which live in 303-agentops)
- [ ] **GOVERN-03**: Distributed tracing for inference request path (Chainlit → Retriever → vLLM) via OTEL Collector + Tempo
- [ ] **GOVERN-04**: Token-cost tracking middleware — emit `$/1M-tokens` metrics for self-hosted vLLM; comparison dashboard with API rates (feeds back into API-02 build-vs-buy mental model)
- [ ] **GOVERN-05**: Model promotion audit trail — ArgoCD history + Git log + structured changelog automation (extends OPS-02 GitOps audit)

### v1.1 — API: Optional AI API alternative

Confirmed for v1.1 milestone (per user direction 2026-05-07). Pairs naturally with GOVERN-04 cost tracking — together they form the build-vs-buy story (cost data + actual API integration). Gracefully skippable if free-tier quota unavailable.

- [ ] **API-01**: OpenAI-compatible client swap demo — point Chainlit at Groq or Gemini OpenAI-compat endpoint instead of self-hosted vLLM (env-var swap; show identical UX)
- [ ] **API-02**: Build-vs-buy decision tree — when to self-host vLLM vs use API service (cost crossover, latency tradeoffs, data residency, rate limits) — uses GOVERN-04 cost tracking data

### v1.1 — GPU: Instructor-led GPU demos (all aspects)

Confirmed for v1.1 milestone (per user direction 2026-05-07 — "note down gpu for 1.1 though, all aspects of it"). Uses instructor's GCP credits. Recorded video segments + live workshop demos. Not student-hands-on labs.

- [ ] **GPU-01**: GPU right-sizing demo — T4 vs A10 vs L4 vs A100 selection for SmolLM2-135M / 1B / 7B serving; instance-type decision matrix
- [ ] **GPU-02**: GPU cost economics demo — $/hr instance cost vs $/1M-token throughput; self-hosted GPU vs API breakeven analysis; spot vs on-demand
- [ ] **GPU-03**: GPU training demo — full fine-tune (or larger LoRA on 1B+ model) on GPU vs CPU LoRA from SPINE-03 (time, cost, quality comparison)
- [ ] **GPU-04**: GPU vLLM serving demo — throughput / TTFT / KV-cache benchmarks vs CPU vLLM from SPINE-05
- [ ] **GPU-05**: GPU autoscaling on cloud — KEDA + cluster-autoscaler with GPU node pools; how scaling differs from CPU
- [ ] **GPU-06**: GPU cost monitoring — KubeCost or equivalent showing per-pod GPU cost attribution

---

## Out of Scope (explicit exclusions)

### v1.0.0 explicit exclusions

- **GPU-required hands-on labs** — all student labs CPU-only (16GB RAM constraint). GPU is instructor demo only (deferred to v1.1).
- **AgentOps content** (Hermes Agent, MCP tools, Kubernetes Agent Sandbox, multi-tool agent workflows, GuardrailMiddleware for agents, DeepEval eval gate, insurance_check capstone, governance/audit trails for agents). Moved to `schoolofdevops/303-agentops`.
- **Eval gate in Argo Workflows pipeline** — eval gating belongs in AgentOps course (eval = quality of agent responses). LLMOps pipeline lab teaches orchestration (data→index→train→merge), not response quality.
- **Knative serverless mode for KServe** — adds ~1.5GB RAM (Knative + Istio + cert-manager); breaks 16GB constraint. KServe RawDeployment delivers managed serving abstraction without the dependency chain. Knative may be optional appendix only.
- **Cloud-specific managed serving** (Vertex AI Online Prediction, SageMaker JumpStart, Azure ML endpoints) — keep cloud-agnostic; show patterns that work on EKS/GKE/AKS/on-prem.
- **Mobile app or native UI** — web interface only (Chainlit).
- **Enterprise auth/SSO integration** — keep demo-grade for learning.

---

## Traceability

Every v1.0.0 requirement is mapped to exactly one phase. SERVE-01 and PACKAGE-01 are aliases — they are delivered by the same lab as SPINE-05 and SPINE-04 respectively, framed as "Pattern A" in the comparison labs (SERVE-04, PACKAGE-03).

| REQ-ID | Phase | Plan | Status |
|--------|-------|------|--------|
| MIGRATE-01 | 01 | TBD | Not started |
| MIGRATE-02 | 01 | TBD | Not started |
| MIGRATE-03 | 01 | TBD | Not started |
| MIGRATE-04 | 01 | TBD | Not started |
| MIGRATE-05 | 01 | TBD | Not started |
| SPINE-01 | 02 | TBD | Not started |
| SPINE-02 | 02 | TBD | Not started |
| SPINE-03 | 02 | TBD | Not started |
| SPINE-04 | 02 | TBD | Not started (also delivers PACKAGE-01) |
| SPINE-05 | 02 | TBD | Not started (also delivers SERVE-01) |
| SPINE-06 | 02 | TBD | Not started |
| SERVE-01 | 02 | TBD | Not started (alias — delivered by SPINE-05; framed as "Pattern A" in SERVE-04 decision lab) |
| SERVE-02 | 05 | TBD | Not started |
| SERVE-03 | 04 | TBD | Not started |
| SERVE-04 | 05 | TBD | Not started (decision lab written after all 3 patterns exist) |
| PACKAGE-01 | 02 | TBD | Not started (alias — delivered by SPINE-04; framed as "Pattern A" in PACKAGE-03 decision lab) |
| PACKAGE-02 | 03 | TBD | Not started |
| PACKAGE-03 | 03 | TBD | Not started |
| OPS-01 | 06 | TBD | Not started |
| OPS-02 | 06 | TBD | Not started |
| OPS-03 | 06 | TBD | Not started |

**Coverage check:** 21/21 v1.0.0 requirements mapped (100%). No orphans. No duplicates (aliases noted).

---

*Defined: 2026-05-07*
*Mapped to phases: 2026-05-07*
*Total v1.0.0 requirements: 21 (5 MIGRATE + 6 SPINE + 4 SERVE + 3 PACKAGE + 3 OPS)*
*Deferred to v1.1: 13 (5 GOVERN + 2 API + 6 GPU)*
