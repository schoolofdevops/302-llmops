---
gsd_state_version: 1.0
milestone: v0.19.0
milestone_name: milestone
status: Ready to execute
stopped_at: Completed 02-01-PLAN.md
last_updated: "2026-04-23T09:04:19.852Z"
progress:
  total_phases: 4
  completed_phases: 1
  total_plans: 12
  completed_plans: 6
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-12)

**Core value:** Teach practitioners how to take AI systems (LLMs + agents) from prototype to production on Kubernetes — the only course covering the full journey from RAG to agentic deployments with K8s Agent Sandbox.
**Current focus:** Phase 02 — llmops-labs-day-1

## Current Position

Phase: 02 (llmops-labs-day-1) — EXECUTING
Plan: 2 of 7

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

*Updated after each plan completion*
| Phase 01-course-infrastructure P01 | 2min | 2 tasks | 32 files |
| Phase 01-course-infrastructure P02 | 16min | 2 tasks | 40 files |
| Phase 01-course-infrastructure P03 | 2min | 2 tasks | 5 files |
| Phase 01-course-infrastructure P04 | 4min | 2 tasks | 6 files |
| Phase 01-course-infrastructure P05 | 2min | 2 tasks | 3 files |
| Phase 02-llmops-labs-day-1 P01 | 1min | 2 tasks | 2 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Pre-phase]: Agent framework = Hermes Agent (NousResearch) — configure and deploy, not build from scratch
- [Pre-phase]: Two-phase LLM — Labs 00-05 use local SmolLM2-135M, Labs 06+ use Gemini/Groq free-tier API
- [Pre-phase]: No LangGraph/CrewAI — Hermes is the modern approach
- [Pre-phase]: FAISS in-process (zero overhead) over Qdrant/Milvus
- [Pre-phase]: Docusaurus replaces MkDocs; Chainlit for web UI
- [Phase 01-course-infrastructure]: D-02: lab-NN zero-padded two-digit naming (lab-00 through lab-13)
- [Phase 01-course-infrastructure]: D-10/D-12: Generic namespace names and no domain branding in infrastructure (llm-serving, llm-app, monitoring, argocd, argo-workflows)
- [Phase 01-course-infrastructure]: Redirect Docusaurus homepage to /docs instead of landing page — keeps learners on docs immediately
- [Phase 01-course-infrastructure]: Docusaurus Tabs pattern (groupId=operating-systems) established for all OS-specific commands in lab pages
- [Phase 01-course-infrastructure]: Preflight scripts: starter and solution identical (no REPLACE placeholders in scripts); memory warn 8-12GB not fail; TDD bash test suite with 14 tests
- [Phase 01-course-infrastructure]: Dual ImageVolume gate pattern (kubeadmConfigPatches + KubeletConfiguration) required for KIND cluster — single location silently fails
- [Phase 01-course-infrastructure]: bootstrap-kind.sh uses mktemp+sed substitution for REPLACE_HOST_PATH — preserves placeholder in tracked config
- [Phase 01-course-infrastructure]: Solution KIND config uses ./llmops-project relative path (not absolute) — works on macOS and Windows Git Bash from repo root
- [Phase 01-course-infrastructure]: cleanup-phase3.sh uses per-CRD kubectl delete lines for --ignore-not-found on each CRD individually
- [Phase 01-course-infrastructure]: helm status guard pattern before helm uninstall prevents script failure when release was never installed
- [Phase 02-llmops-labs-day-1]: Use official vllm/vllm-openai-cpu:v0.19.0-x86_64 image — abandoned schoolofdevops/vllm-cpu-nonuma:0.9.1 removed
- [Phase 02-llmops-labs-day-1]: KServe marked N/A for Phase 2 labs — plain K8s Deployment used per D-10

### Pending Todos

None yet.

### Blockers/Concerns

None yet.

## Session Continuity

Last session: 2026-04-23T09:04:19.849Z
Stopped at: Completed 02-01-PLAN.md
Resume file: None
