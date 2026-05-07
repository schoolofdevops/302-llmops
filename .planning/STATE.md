---
gsd_state_version: 1.0
milestone: v1.0.0
milestone_name: milestone
status: Phase complete — ready for verification
stopped_at: Completed 01-curriculum-migration-to-303-agentops/01-04-PLAN.md (AgentOps deletion + build verify — Phase 01 COMPLETE)
last_updated: "2026-05-07T08:24:25.781Z"
last_activity: 2026-05-07
progress:
  total_phases: 6
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-07)

**Core value:** Teach practitioners how to deploy and operate LLM serving infrastructure on Kubernetes — full LLMOps lifecycle (data → fine-tune → package → serve → observe → scale → GitOps) with three serving patterns (plain vLLM, vLLM Router, KServe) and two model-packaging patterns (OCI ImageVolume, disk-based) on CPU-only KIND.

**Current focus:** Phase 01 — curriculum-migration-to-303-agentops

## Current Position

Phase: 01 (curriculum-migration-to-303-agentops) — EXECUTING
Plan: 4 of 4

## Performance Metrics

**Velocity:**

- Total plans completed: 0
- Average duration: -
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**

- Last 5 plans: none yet
- Trend: -

| Phase 01-curriculum-migration-to-303-agentops P01 | 2 | 2 tasks | 0 files |
| Phase 01-curriculum-migration-to-303-agentops P02 | 6 | 5 tasks | 216 files |
| Phase 01-curriculum-migration-to-303-agentops P03 | 199 | 4 tasks | 6 files |
| Phase 01-curriculum-migration-to-303-agentops P04 | 12 | 3 tasks | 181 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table. Recent decisions affecting v1.0.0:

- [Pre-milestone 2026-05-07]: Split LLMOps and AgentOps into two courses (302-llmops + 303-agentops)
- [Pre-milestone 2026-05-07]: Reset phase numbering to 01 for v1.0.0 (clean slate)
- [Pre-milestone 2026-05-07]: Course goal expanded — "production-grade GenAI systems with all relevant components" (not just narrow LLMOps focus)
- [Pre-milestone 2026-05-07]: Restore KServe RawDeployment (original Lab 4 approach in llmops-labuide); v0.19.0 had dropped it
- [Pre-milestone 2026-05-07]: Three serving patterns covered: plain vLLM Deployment, KServe InferenceService, vLLM Router multi-pod
- [Pre-milestone 2026-05-07]: Add disk-based model loading alongside OCI ImageVolume
- [Pre-milestone 2026-05-07]: Drop eval gate from Argo Workflows pipeline (moves to 303-agentops)
- [Pre-milestone 2026-05-07]: GPU content as instructor demos (GCP credits), not student labs — DEFERRED to v1.1
- [Pre-milestone 2026-05-07]: Optional AI API service comparison (Groq/Gemini free tier) — DEFERRED to v1.1
- [Roadmap 2026-05-07]: Six-phase structure (Migration → Spine → Disk Loading → Router → KServe+Decision → Ops); SERVE-04 absorbed into Phase 05 instead of standalone Phase 07 (decision lab is more meaningful once all three patterns coexist)
- [Roadmap 2026-05-07]: SERVE-01 aliased to SPINE-05 (same Lab 04, framed as "Pattern A"); PACKAGE-01 aliased to SPINE-04 (same Lab 03, framed as "Pattern A")
- [Phase 01-curriculum-migration-to-303-agentops]: v0.19.x maintenance branch created from annotated tag commit (0fada73), not tag object — correct Git semantics; branch points to frozen content
- [Phase 01-curriculum-migration-to-303-agentops]: RTK proxy intercepts dotted branch name args; use rtk proxy git for branch operations with non-alphanumeric names (v0.19.x)
- [Phase 01-curriculum-migration-to-303-agentops]: Single bootstrap commit per D-02 — fresh copy of 302-llmops v0.19.0 AgentOps content to 303-agentops
- [Phase 01-curriculum-migration-to-303-agentops]: Task 1 automated (repo already existed empty+public) — no human action required for checkpoint:human-action
- [Phase 01-curriculum-migration-to-303-agentops]: Redirects use single landing page target (303-agentops) for all 7 lab URLs per D-05 default
- [Phase 01-curriculum-migration-to-303-agentops]: logo.alt updated from 'LLMOps & AgentOps Logo' to 'LLMOps Logo' alongside title rename (D-06)
- [Phase 01-curriculum-migration-to-303-agentops]: Untracked runtime artifacts in lab-07 dirs (sqlite, pytest caches) left on disk — gitignored, never tracked, no action needed
- [Phase 01-curriculum-migration-to-303-agentops]: D-10 order complete: tag→branch→303-bootstrap→redirects→delete→build-verify — all 8 steps done across plans 01-01..01-04

### Reusable from v0.19.0

Most LLMOps content from v0.19.0 Phase 02 (Day 1 labs) is reusable as starting point:

- KIND cluster setup (Lab 00 → Phase 02 SPINE-01)
- Synthetic data + RAG retriever (Lab 01 → Phase 02 SPINE-02)
- CPU LoRA fine-tuning (Lab 02 → Phase 02 SPINE-03)
- OCI model packaging (Lab 03 → Phase 02 SPINE-04, also delivers PACKAGE-01)
- vLLM plain Deployment + Chainlit (Lab 04+05 → Phase 02 SPINE-05, also delivers SERVE-01)
- Prometheus + Grafana observability (Lab 06 → Phase 02 SPINE-06)

Phase 04 v0.19.0 partial reuse (now Phase 06 in v1.0.0):

- Autoscaling (HPA + KEDA) → Phase 06 OPS-01 (drop agent context, validate against 3 serving patterns)
- ArgoCD GitOps → Phase 06 OPS-02
- Argo Workflows → Phase 06 OPS-03 (drop eval gate)

### Move to 303-agentops (Phase 01 work)

- Phase 03 (AgentOps Day 2): Hermes Agent, MCP tools, Sandbox, OTEL Tempo, cost middleware
- Phase 04 partial: Guardrails, DeepEval eval gate, capstone (insurance_check), governance
- ALL `.planning/phases/03-*/` and `04-*/` agent slices, decisions log, validated configs (this is the migration — not just file copy)

### Pending Todos

- Phase 01 plan must include explicit "context dossier" step (`MIGRATION-FROM-302-LLMOPS.md` in 303-agentops) before any `git rm` — Pitfall 9
- Resolve four live-cluster-verification gate items at phase-plan time:
  1. vllm-stack 0.1.10 + `vllm/vllm-openai-cpu` end-to-end on KIND (Phase 04)
  2. KServe v0.18 `kserve-huggingfaceserver` CPU on arm64 / Mac M1/M2 (Phase 05)
  3. Pin exact `lmstack-router` dev tag for milestone reproducibility (Phase 04)
  4. Exact resource budgets per lab on a real 16GB laptop via `kubectl top pods -A` (every phase)

### Blockers/Concerns

None. (Roadmapper flagged stale concern about phase archive; verified — `.planning/phases/` is empty, all 5 v0.19.0 phase dirs in `.planning/milestones/v0.19.0-phases/`.)

## Session Continuity

Last session: 2026-05-07T08:24:25.778Z
Last activity: 2026-05-07
Stopped at: Completed 01-curriculum-migration-to-303-agentops/01-04-PLAN.md (AgentOps deletion + build verify — Phase 01 COMPLETE)
Resume file: None
Next command: `/gsd:plan-phase 01`
