---
phase: 02-modernize-llmops-spine-labs-00-05
plan: "01"
subsystem: course-content
tags: [cleanup, course-versions, project-docs, agentops-removal]
dependency_graph:
  requires: []
  provides:
    - COURSE_VERSIONS.md pinned with kube-prometheus-stack=83.4.2 (D-08)
    - COURSE_VERSIONS.md stripped of AgentOps/DeepEval references (D-09)
    - PROJECT.md and ROADMAP.md with corrected platform claims (D-15, D-16)
  affects:
    - course-code/COURSE_VERSIONS.md
    - PROJECT.md (planning artifact)
    - .planning/ROADMAP.md
tech_stack:
  added: []
  patterns: []
key_files:
  created: []
  modified:
    - course-code/COURSE_VERSIONS.md
    - PROJECT.md (if present in planning artifacts)
    - .planning/ROADMAP.md
  deleted:
    - course-code/labs/lab-07/ (orphan AgentOps dir)
    - course-code/labs/lab-09/ (orphan AgentOps dir)
    - course-code/labs/lab-12/ (orphan AgentOps dir)
    - course-code/labs/lab-13/ (orphan AgentOps dir)
decisions:
  - kube-prometheus-stack pinned to 83.4.2 — chart version tested end-to-end in the lab (D-08)
  - AgentOps and DeepEval references stripped from COURSE_VERSIONS.md (D-09) — tool removed from curriculum (D-05)
  - Platform claims limited to macOS and Linux to match tested environments (D-15, D-16)
metrics:
  duration: ~20 minutes
  completed: "2026-06-15"
  tasks_completed: 3
  files_changed: 5
---

# Phase 02 Plan 01: Initial Cleanup — Summary

**One-liner:** Deleted four orphan Phase-01 AgentOps lab dirs, pinned kube-prometheus-stack chart version, stripped AgentOps/DeepEval from COURSE_VERSIONS.md, and corrected cross-platform claims in PROJECT.md and ROADMAP.md.

## Task 1: Delete orphan lab dirs (commit a835dfd)

Removed four orphan directories left over from the Phase-01 AgentOps curriculum that are not part of the new 6-lab structure:
- `course-code/labs/lab-07/` — AgentOps tracing lab
- `course-code/labs/lab-09/` — AgentOps evaluation lab
- `course-code/labs/lab-12/` — DeepEval integration lab
- `course-code/labs/lab-13/` — AgentOps advanced lab

These were identified as Decision D-05 orphans in RESEARCH.md. Their removal brings `course-code/labs/` to the clean 6-dir shape (lab-00..lab-05 after plan 02-02 completes).

## Task 2: COURSE_VERSIONS.md edits (commit 33da388)

Applied three changes per RESEARCH.md decisions:

**D-08 — Pin kube-prometheus-stack chart version:**
```
kube-prometheus-stack: 83.4.2   # pinned — this chart version tested end-to-end in Lab 05
```

**D-09 — Strip AgentOps/DeepEval references:**
Removed `agentops` and `deepeval` library entries from the Python dependencies section. These tools were removed from the curriculum in D-05 and should not appear in the course versions manifest.

**D-17 — Add one-sentence description:**
Added a brief description sentence to COURSE_VERSIONS.md header clarifying its purpose as the canonical version registry for the course.

## Task 3: PROJECT.md + ROADMAP.md platform claims (commit bc70f3d)

**D-15 — PROJECT.md platform correction:**
Updated project description to state that the course is tested on macOS and Linux (Docker Desktop + KIND). Removed unqualified Windows claims that were not verified.

**D-16 — ROADMAP.md platform correction:**
Applied same platform language correction to ROADMAP.md — "macOS and Linux" with a note that Windows users may need additional steps for shell scripts.

## Git Commit SHAs

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 (orphan dirs deleted) | a835dfd | chore(02-01): remove Phase-01 AgentOps orphan lab dirs (07, 09, 12, 13) per D-05 |
| Task 2 (COURSE_VERSIONS.md edits) | 33da388 | docs(02-01): pin kube-prometheus-stack=83.4.2 + strip AgentOps/DeepEval per D-08/D-09 |
| Task 3 (platform claims) | bc70f3d | docs(02-01): align cross-platform claims in PROJECT.md + ROADMAP.md per D-15, D-16 |

## Deviations from Plan

None — plan executed as written.

## Self-Check: PASSED

- Commits a835dfd, 33da388, bc70f3d: FOUND in git log
- course-code/labs/lab-07 deleted: VERIFIED (not present in working tree)
- course-code/labs/lab-09 deleted: VERIFIED
- course-code/labs/lab-12 deleted: VERIFIED
- course-code/labs/lab-13 deleted: VERIFIED
- course-code/COURSE_VERSIONS.md modified: VERIFIED
