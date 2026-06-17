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
duration: 35min
completed: 2026-06-17
---

# Phase 05 Plan 01: KServe InferenceService + Serving Decision Lab Summary

**NodePort 30202 added to both solution and starter kind-config.yaml files; KIND cluster recreated with 30202 bound; Phase 02/03 prerequisite stack redeployed with Patterns A and B at replicas=0, giving >=8GB RAM headroom for KServe.**

## Performance

- **Duration:** ~35 min (5 min automated + 30 min human-action cluster recreate and stack redeploy)
- **Started:** 2026-06-17T00:00:00Z
- **Completed:** 2026-06-17T00:35:00Z
- **Tasks:** 2 complete (1 auto + 1 human-action)
- **Files modified:** 2

## Accomplishments

- Added `containerPort: 30202 / hostPort: 30202` to solution `kind-config.yaml` extraPortMappings block after the 30201 entry
- Added `containerPort: 30201 / hostPort: 30201` and `containerPort: 30202 / hostPort: 30202` to starter `kind-config.yaml` — both files now identical in port mapping coverage
- Identified and auto-fixed a Phase 04 carry-over gap where Phase 04 GAP-3 had only patched the solution file, leaving the starter desynchronized by one port entry (30201)

## Task Commits

1. **Task 1: Add NodePort 30202 to both kind-config.yaml files** - `7ec67e0` (chore)
2. **Task 2: KIND cluster recreate + Phase 02/03 stack redeploy** - human-action (user-executed; no file-change commit — cluster state only)

**Plan metadata:** (docs commit — see below)

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

## Checkpoint Completed

**Task 2 (checkpoint:human-action)** was completed by the user. Confirmed outcomes:
1. KIND cluster `llmops-kind` deleted and recreated with updated kind-config.yaml
2. `docker inspect llmops-kind-control-plane` confirms `30202/tcp` bound on host
3. Phase 03 stack redeployed: MinIO running in `minio` namespace, model-uploader Job completed (`smollm2-finetuned/` object present)
4. Pattern A (`vllm-smollm2`) and Pattern B (`vllm-smollm2-disk`) both deployed in `llm-serving` at `replicas=0`
5. `kubectl top nodes` confirmed >=8GB free RAM across cluster

## Next Phase Readiness

Plan 05-02 (cert-manager v1.16.5 + Gateway API CRDs v1.2.1 + KServe v0.18.0 install) can begin immediately:

- NodePort 30202 is live on the host (`30202/tcp` visible in docker inspect)
- 3 nodes Ready (1 control-plane + 2 workers)
- MinIO healthy in `minio` namespace; `smollm2-finetuned/` model object accessible
- `llm-serving` namespace has Pattern A and B Deployments at replicas=0 (ready for 05-03 comparison lab)
- >=8GB free RAM headroom verified for KServe control-plane stack

No blockers for Plan 05-02.

## Threat Surface Scan

No new network endpoints, auth paths, or schema changes introduced. The 30202 NodePort mapping is a host-level localhost binding on an isolated Docker Desktop network — consistent with existing NodePort pattern (T-05-01 accepted in plan threat model).

## Known Stubs

None — this plan is infrastructure configuration only; no UI or data-flow code was written.

---
*Phase: 05-kserve-inferenceservice-serving-decision-lab*
*Completed: 2026-06-17*
