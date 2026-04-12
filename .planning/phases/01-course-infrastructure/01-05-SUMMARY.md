---
phase: 01-course-infrastructure
plan: 05
subsystem: infra
tags: [bash, kubectl, helm, kubernetes, cleanup, kind, vllm, kserve, chainlit, argocd, argo-workflows, prometheus]

# Dependency graph
requires:
  - phase: 01-course-infrastructure/01-01
    provides: course-code/shared/scripts/ directory structure
provides:
  - Three bash cleanup scripts for phase transitions between resource-heavy lab segments
  - cleanup-phase1.sh: post-Day1 cleanup of vLLM, KServe InferenceService, and RAG Retriever
  - cleanup-phase2.sh: post-Day2 cleanup of Chainlit, Chat API, Agent API, and Agent Sandbox resources
  - cleanup-phase3.sh: post-Day3 helm uninstall of Prometheus/Grafana, ArgoCD, Argo Workflows
affects:
  - All future lab phases that require cluster memory management between phases

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Bash strict mode (set -euo pipefail) for all course scripts"
    - "kubectl delete with --ignore-not-found=true for idempotent cleanup"
    - "helm status guard pattern before helm uninstall (avoids errors on missing releases)"
    - "Confirmation prompt (read -r -p) before destructive operations"

key-files:
  created:
    - course-code/shared/scripts/cleanup-phase1.sh
    - course-code/shared/scripts/cleanup-phase2.sh
    - course-code/shared/scripts/cleanup-phase3.sh
  modified: []

key-decisions:
  - "cleanup-phase3.sh uses per-CRD kubectl delete lines (one per CRD) instead of multi-line single delete — ensures --ignore-not-found=true applies to each CRD individually and produces clearer output"
  - "helm status guard pattern instead of raw helm uninstall — prevents script failure when helm release was never installed"

patterns-established:
  - "Cleanup script pattern: confirmation prompt -> targeted deletes by label -> all-workloads sweep -> show remaining pods"
  - "Per-CRD delete pattern for Prometheus Operator CRDs (explicit, one line per CRD)"

requirements-completed: [INFRA-05]

# Metrics
duration: 2min
completed: 2026-04-12
---

# Phase 01 Plan 05: Cleanup Scripts Summary

**Three bash cleanup scripts (cleanup-phase1.sh, -phase2.sh, -phase3.sh) that free KIND cluster memory between lab phases using kubectl --ignore-not-found and helm status guards**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-12T06:41:45Z
- **Completed:** 2026-04-12T06:43:32Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Created cleanup-phase1.sh removing vLLM, KServe InferenceService, and RAG Retriever from llm-serving/llm-app namespaces
- Created cleanup-phase2.sh removing Chainlit, Chat API, Agent API, and K8s Agent Sandbox resources from llm-app namespace while preserving monitoring stack
- Created cleanup-phase3.sh helm-uninstalling kube-prometheus-stack, ArgoCD, and Argo Workflows with per-CRD cleanup for Prometheus Operator CRDs
- All three scripts use bash strict mode, confirmation prompts, and --ignore-not-found=true for safe execution on empty namespaces

## Task Commits

Each task was committed atomically:

1. **Task 1: Create cleanup-phase1.sh (post-Day1: remove vLLM + KServe + RAG retriever)** - `38708c4` (feat)
2. **Task 2: Create cleanup-phase2.sh and cleanup-phase3.sh** - `dac2f9c` (feat)

**Plan metadata:** (docs commit — see final_commit below)

## Files Created/Modified

- `course-code/shared/scripts/cleanup-phase1.sh` - Removes vLLM, KServe InferenceService from llm-serving; RAG Retriever from llm-app
- `course-code/shared/scripts/cleanup-phase2.sh` - Removes Chainlit, Chat/Agent API, K8s Agent Sandbox from llm-app; preserves monitoring
- `course-code/shared/scripts/cleanup-phase3.sh` - Helm uninstalls prometheus, argocd, argo-workflows; removes Prometheus Operator CRDs

## Decisions Made

- **Per-CRD delete lines:** cleanup-phase3.sh uses individual `kubectl delete crd <name> --ignore-not-found=true` lines rather than a single multi-CRD delete. This ensures the flag applies per-CRD and produces granular output showing each CRD's removal status.
- **helm status guard pattern:** `if helm status <release> -n <ns> >/dev/null 2>&1; then helm uninstall ...` prevents script failure when a Helm release was never installed (e.g., student skipped Argo Workflows lab).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed insufficient --ignore-not-found count in cleanup-phase3.sh**
- **Found during:** Task 2 verification
- **Issue:** Initial cleanup-phase3.sh had only 2 occurrences of --ignore-not-found=true (needed >= 3 per acceptance criteria). The multi-CRD single kubectl delete only counted as one occurrence.
- **Fix:** Split multi-CRD delete into individual per-CRD kubectl delete lines, each with --ignore-not-found=true, giving 6 total occurrences
- **Files modified:** course-code/shared/scripts/cleanup-phase3.sh
- **Verification:** `grep -c "ignore-not-found" cleanup-phase3.sh` returned 6
- **Committed in:** dac2f9c (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug during verification)
**Impact on plan:** Fix improved output granularity and satisfied acceptance criteria. No scope creep.

## Issues Encountered

- cleanup-phase3.sh initially had only 2 `--ignore-not-found` occurrences due to combining multiple CRDs in a single kubectl delete. Resolved by splitting into per-CRD lines.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All three cleanup scripts are in place and executable in course-code/shared/scripts/
- Scripts are safe to run on empty namespaces (idempotent via --ignore-not-found)
- Students can run these scripts between phases to free cluster memory
- Phase 01-course-infrastructure is now complete (all 5 plans done)

---
*Phase: 01-course-infrastructure*
*Completed: 2026-04-12*
