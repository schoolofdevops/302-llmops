---
phase: 01-course-infrastructure
plan: 01
subsystem: infra
tags: [course-code, lab-structure, kind, kubernetes, config]

# Dependency graph
requires: []
provides:
  - "14 lab directories (lab-00 to lab-13) each with starter/ and solution/ subdirectories under course-code/labs/"
  - "course-code/shared/k8s/ and course-code/shared/scripts/ directories for shared manifests and cleanup scripts"
  - "course-code/config.env with CLUSTER_NAME, PROJECT_DIR, MODEL_IMAGE_TAG, VLLM_IMAGE, BASE_MODEL, EMBEDDING_MODEL, and 5 NS_* keys"
  - "course-code/README.md with student workflow documentation (starter -> follow lab -> compare solution)"
affects:
  - "02-course-infrastructure (preflight scripts go into labs/lab-00/starter)"
  - "All subsequent wave-2+ plans that write lab content into labs/lab-NN/starter and labs/lab-NN/solution"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "lab-NN zero-padded two-digit naming convention (D-02)"
    - "starter/solution sibling directory pattern per lab (D-03)"
    - "Generic infrastructure naming — no domain branding in namespaces or config keys (D-10, D-12)"
    - "Central config.env pattern for artifact configuration (Pattern 6 from RESEARCH.md)"

key-files:
  created:
    - "course-code/labs/lab-00 through lab-13/starter/.gitkeep (14 files)"
    - "course-code/labs/lab-00 through lab-13/solution/.gitkeep (14 files)"
    - "course-code/shared/k8s/.gitkeep"
    - "course-code/shared/scripts/.gitkeep"
    - "course-code/config.env"
    - "course-code/README.md"
  modified: []

key-decisions:
  - "D-02: lab-NN zero-padded two-digit naming (lab-00 through lab-13)"
  - "D-10: Generic namespace names (llm-serving, llm-app, monitoring, argocd, argo-workflows) — not brand-specific"
  - "D-11: Labs 00-13 inclusive (14 labs for 3-day workshop format)"
  - "D-12: Infrastructure naming stays generic; Smile Dental branding only in use-case content"

patterns-established:
  - "Pattern: starter/ contains REPLACE placeholder templates; solution/ contains fully working reference files"
  - "Pattern: config.env as single source of truth for artifact version pinning and cluster configuration"
  - "Pattern: shared/ directory for cross-lab reusable assets (k8s manifests, cleanup scripts)"

requirements-completed: [INFRA-01]

# Metrics
duration: 2min
completed: 2026-04-12
---

# Phase 01 Plan 01: Course Code Repository Skeleton Summary

**14-lab companion code repository skeleton with starter/solution structure, shared infrastructure directories, central config.env, and student workflow README**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-04-12T06:11:03Z
- **Completed:** 2026-04-12T06:12:24Z
- **Tasks:** 2
- **Files modified:** 32 (28 .gitkeep lab files + 2 shared .gitkeep + config.env + README.md)

## Accomplishments

- Created all 28 lab subdirectories (14 labs × starter/solution) under course-code/labs/
- Created shared/k8s/ and shared/scripts/ for cross-lab reusable assets
- Created config.env with all required keys: CLUSTER_NAME, PROJECT_DIR, MODEL_IMAGE_TAG, VLLM_IMAGE, BASE_MODEL, EMBEDDING_MODEL, and 5 NS_* namespace keys
- Created README.md documenting the student workflow (copy starter, follow lab, compare solution, reset from next starter if behind)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create lab directory skeleton (lab-00 through lab-13)** - `17f6237` (chore)
2. **Task 2: Create shared directory structure, config.env, and README.md** - `e663ce0` (chore)

## Files Created/Modified

- `course-code/labs/lab-00/starter/.gitkeep` through `course-code/labs/lab-13/solution/.gitkeep` — 28 empty placeholder files for git directory tracking
- `course-code/shared/k8s/.gitkeep` — Shared Kubernetes manifests directory placeholder
- `course-code/shared/scripts/.gitkeep` — Shared cleanup scripts directory placeholder
- `course-code/config.env` — Central artifact configuration with all namespace keys and version pins
- `course-code/README.md` — Student workflow documentation (starter/solution pattern)

## Decisions Made

- Followed all decisions from 01-CONTEXT.md: D-02 (zero-padded lab naming), D-10 (generic namespace names), D-11 (labs 00-13), D-12 (no domain branding in infrastructure)
- No architectural decisions required beyond what was specified in the plan

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None — directory creation and file writing succeeded without issues.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- course-code/ skeleton is complete — Wave 2 plans can now write preflight scripts into labs/lab-00/starter/ and KIND configs into labs/lab-00/solution/
- All subsequent lab-content plans have their target directories ready
- No blockers or concerns

---
*Phase: 01-course-infrastructure*
*Completed: 2026-04-12*
