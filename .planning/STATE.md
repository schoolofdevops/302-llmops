---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: Ready to execute
stopped_at: Completed 01-course-infrastructure/01-03-PLAN.md
last_updated: "2026-04-12T06:35:26.398Z"
progress:
  total_phases: 4
  completed_phases: 0
  total_plans: 5
  completed_plans: 3
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-12)

**Core value:** Teach practitioners how to take AI systems (LLMs + agents) from prototype to production on Kubernetes — the only course covering the full journey from RAG to agentic deployments with K8s Agent Sandbox.
**Current focus:** Phase 01 — course-infrastructure

## Current Position

Phase: 01 (course-infrastructure) — EXECUTING
Plan: 4 of 5

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

### Pending Todos

None yet.

### Blockers/Concerns

None yet.

## Session Continuity

Last session: 2026-04-12T06:35:26.396Z
Stopped at: Completed 01-course-infrastructure/01-03-PLAN.md
Resume file: None
