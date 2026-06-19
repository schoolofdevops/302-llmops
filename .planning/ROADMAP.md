# Roadmap — LLMOps with Kubernetes

## Milestones

- ✅ **v1.0.0 LLMOps with Kubernetes** — Phases 01–06 (shipped 2026-06-19) — [archive](.planning/milestones/v1.0.0-ROADMAP.md)

## Phases

<details>
<summary>✅ v1.0.0 LLMOps with Kubernetes (Phases 01–06) — SHIPPED 2026-06-19</summary>

- [x] Phase 01: Curriculum Migration to 303-agentops (4/4 plans) — completed 2026-05-07
- [x] Phase 02: Modernize LLMOps Spine (Labs 00-05) (8/8 plans) — completed 2026-06-15
- [x] Phase 03: Disk-Based Model Loading (MinIO + initContainer) (4/4 plans) — completed 2026-06-15
- [x] Phase 04: vLLM Router Multi-Pod Serving (4/4 plans) — completed 2026-06-16
- [x] Phase 05: KServe InferenceService + Serving Decision Lab (4/4 plans) — completed 2026-06-17
- [x] Phase 06: Production Operations Layer (4/4 plans) — completed 2026-06-18

Full details: [.planning/milestones/v1.0.0-ROADMAP.md](.planning/milestones/v1.0.0-ROADMAP.md)

</details>

## Progress

| Phase | Milestone | Plans | Status | Completed |
|-------|-----------|-------|--------|-----------|
| 01. Curriculum Migration to 303-agentops | v1.0.0 | 4/4 | Complete | 2026-05-07 |
| 02. Modernize LLMOps Spine (Labs 00-05) | v1.0.0 | 8/8 | Complete | 2026-06-15 |
| 03. Disk-Based Model Loading | v1.0.0 | 4/4 | Complete | 2026-06-15 |
| 04. vLLM Router Multi-Pod Serving | v1.0.0 | 4/4 | Complete | 2026-06-16 |
| 05. KServe InferenceService + Decision Lab | v1.0.0 | 4/4 | Complete | 2026-06-17 |
| 06. Production Operations Layer | v1.0.0 | 4/4 | Complete | 2026-06-18 |

**Total: 24/24 plans complete across 6 phases.**

## Next Milestone: v1.1

Start planning with `/gsd:new-milestone`. Candidate scope (from v1.0.0 requirements):

- **GOVERN**: model registry, inference-layer guardrails, distributed tracing, token-cost tracking, audit trails
- **GPU**: instructor-led demos — right-sizing, cost economics, training, serving (GCP credits)
- **API**: optional AI API alternative (Groq/Gemini) for build-vs-buy comparison
- **SPINE UAT**: end-to-end re-verify Labs 00-05 on fresh cluster
- **OPS UAT**: ArgoCD rolling restart + KEDA scale-up on fresh cluster
