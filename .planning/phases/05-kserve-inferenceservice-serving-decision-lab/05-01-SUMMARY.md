---
phase: 05-kserve-inferenceservice-serving-decision-lab
plan: 01
subsystem: infra
tags: [kind, kubernetes, nodeport, kserve, port-mapping]

# Dependency graph
requires:
  - phase: 04-vllm-router-multi-pod-serving
    provides: "kind-config.yaml with 30201 in solution; Phase 04 lab stack deployed"
provides:
  - "containerPort/hostPort 30202 added to solution kind-config.yaml extraPortMappings"
  - "containerPort/hostPort 30201+30202 added to starter kind-config.yaml (synced with solution)"
  - "KIND cluster ready to recreate with 30202 bound — prerequisite for Plan 05-03 InferenceService NodePort access"
affects:
  - "05-02-PLAN.md (KServe install — cluster must be recreated first)"
  - "05-03-PLAN.md (InferenceService NodePort 30202 curl access from host)"
  - "lab-00 student setup — cluster recreate instructions"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "GAP-N fix: add missing NodePort mapping to kind-config.yaml and recreate cluster — same pattern as Phase 04 GAP-3"
    - "Starter kept in strict sync with solution for all extraPortMappings entries"

key-files:
  created: []
  modified:
    - course-code/labs/lab-00/solution/setup/kind-config.yaml
    - course-code/labs/lab-00/starter/setup/kind-config.yaml

key-decisions:
  - "Added both 30201 and 30202 to starter (Rule 1 auto-fix): starter was missing 30201 from Phase 04 GAP-3 which only edited the solution file"
  - "30202 inserted after 30201 in numeric-adjacent position for solution; appended in same block for starter"

patterns-established:
  - "Pattern: Both solution and starter kind-config files must be edited together when adding NodePort mappings"

requirements-completed: [SERVE-02]

# Metrics
duration: 5min
completed: 2026-06-17
---

# Phase 05 Plan 01: KServe InferenceService + Serving Decision Lab Summary

**NodePort 30202 added to both solution and starter kind-config.yaml files; starter also backfilled with missing 30201 from Phase 04 GAP-3 — cluster ready to recreate for KServe host access.**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-06-17T00:00:00Z
- **Completed:** 2026-06-17T00:05:00Z
- **Tasks:** 1 auto (complete) + 1 checkpoint:human-action (pending user action)
- **Files modified:** 2

## Accomplishments

- Added `containerPort: 30202 / hostPort: 30202` to solution `kind-config.yaml` extraPortMappings block after the 30201 entry
- Added `containerPort: 30201 / hostPort: 30201` and `containerPort: 30202 / hostPort: 30202` to starter `kind-config.yaml` — both files now identical in port mapping coverage
- Identified and auto-fixed a Phase 04 carry-over gap where Phase 04 GAP-3 had only patched the solution file, leaving the starter desynchronized by one port entry (30201)

## Task Commits

1. **Task 1: Add NodePort 30202 to both kind-config.yaml files** - `7ec67e0` (chore)

**Plan metadata:** (docs commit — pending after checkpoint completes)

## Files Created/Modified

- `course-code/labs/lab-00/solution/setup/kind-config.yaml` — added `containerPort: 30202 / hostPort: 30202` after the 30201 block
- `course-code/labs/lab-00/starter/setup/kind-config.yaml` — added both 30201 and 30202 entries (30201 was missing, 30202 is the new Phase 05 requirement)

## Decisions Made

- Auto-fixed starter file to add missing 30201 alongside the new 30202 — the starter had diverged from solution during Phase 04 GAP-3 (that plan only specified solution edits). Keeping starter in sync is a correctness requirement (students following the starter path would hit a broken cluster after their PORT 30201 lab).
- Port ordering: 30202 inserted in numeric-adjacent order after 30201 in the solution; same relative ordering in the starter.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Added missing 30201 to starter kind-config.yaml**
- **Found during:** Task 1 (Add NodePort 30202 to both kind-config.yaml files)
- **Issue:** Starter file was missing `containerPort: 30201` — Phase 04 GAP-3 plan (04-01-PLAN.md) only specified editing the solution file, not the starter. The two files had diverged.
- **Fix:** Added both 30201 and 30202 entries to the starter file to bring it into full sync with the solution.
- **Files modified:** `course-code/labs/lab-00/starter/setup/kind-config.yaml`
- **Verification:** `grep containerPort: course-code/labs/lab-00/starter/setup/kind-config.yaml` shows identical port list to solution (18 entries each including 30201 and 30202)
- **Committed in:** `7ec67e0` (part of Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - pre-existing bug)
**Impact on plan:** Necessary correctness fix — students following the starter path need 30201 for Phase 04 vLLM Router labs that precede Phase 05.

## Issues Encountered

None — file edits were straightforward.

## Checkpoint Pending

**Task 2 (checkpoint:human-action)** requires the user to:
1. `kind delete cluster --name llmops-kind`
2. `kind create cluster --config course-code/labs/lab-00/solution/setup/kind-config.yaml`
3. Verify `docker inspect llmops-kind-control-plane` shows 30202/tcp bound
4. Redeploy Phase 03 stack (MinIO + model-uploader Job + Pattern A + Pattern B)
5. Scale both Pattern A and Pattern B to replicas=0 to free RAM for KServe install
6. Verify `kubectl top nodes` shows >=8GB free RAM

See full instructions in 05-01-PLAN.md checkpoint block.

## Next Phase Readiness

- Both kind-config.yaml files have 30202 mapped — waiting for human cluster recreate
- After checkpoint approved: Plan 05-02 (KServe install) can proceed immediately
- Blocker: KIND cluster must be recreated before any KServe install can succeed

## Threat Surface Scan

No new network endpoints, auth paths, or schema changes introduced. The 30202 NodePort mapping is a host-level localhost binding on an isolated Docker Desktop network — consistent with existing NodePort pattern (T-05-01 accepted in plan threat model).

## Known Stubs

None — this plan is infrastructure configuration only; no UI or data-flow code was written.

---
*Phase: 05-kserve-inferenceservice-serving-decision-lab*
*Completed: 2026-06-17*
