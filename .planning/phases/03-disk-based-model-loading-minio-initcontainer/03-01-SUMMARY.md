---
phase: 03-disk-based-model-loading-minio-initcontainer
plan: 01
subsystem: infra
tags: [kind, kubernetes, nodeport, minio, vllm]

# Dependency graph
requires:
  - phase: 02-modernize-llmops-spine-labs-00-05
    provides: "Phase 02 base stack (vLLM Pattern A, RAG retriever, Chainlit) as redeployment target"
provides:
  - "kind-config.yaml (solution + starter) updated with NodePorts 30203, 30900, 30901"
  - "KIND cluster recreate instructions with Phase 02 base stack redeploy"
affects:
  - 03-disk-based-model-loading-minio-initcontainer

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "KIND extraPortMappings must be added at cluster creation — post-creation addition requires delete+recreate"
    - "Control-plane node owns all NodePort bindings; worker nodes get extraMounts only"

key-files:
  created: []
  modified:
    - course-code/labs/lab-00/solution/setup/kind-config.yaml
    - course-code/labs/lab-00/starter/setup/kind-config.yaml

key-decisions:
  - "Skip kube-prometheus-stack redeploy after cluster recreate to preserve ~1 GB headroom for MinIO + vllm-smollm2-disk"
  - "Add 30203 (vllm-smollm2-disk), 30900 (MinIO API), 30901 (MinIO console) to control-plane node only"

patterns-established:
  - "Phase 03 NodePorts use range 30203/30900/30901 — distinct from Phase 02 range 30200/30300/30400/30500"

requirements-completed: [PACKAGE-02]

# Metrics
duration: 5min
completed: 2026-06-15
---

# Phase 03 Plan 01: KIND cluster NodePort additions for Phase 03 (MinIO + disk-based vLLM) Summary

**KIND kind-config.yaml updated with NodePorts 30203 (vllm-smollm2-disk), 30900 (MinIO API), and 30901 (MinIO console) on the control-plane node in both solution and starter files — cluster recreate + Phase 02 base stack redeploy awaiting human verification.**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-06-15T13:00:00Z
- **Completed:** 2026-06-15 (paused at Task 2 checkpoint)
- **Tasks:** 1 of 2 completed (Task 2 is checkpoint:human-verify)
- **Files modified:** 2

## Accomplishments
- Added three new extraPortMappings entries (30203, 30900, 30901) after the existing 30500 entry in the control-plane node section of both kind-config.yaml files
- Preserved all existing Phase 02 NodePorts (30200, 30300, 30400, 30500) and all comments unchanged
- Worker nodes (worker, worker2) left unchanged — no extraPortMappings added there

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Phase 03 NodePorts to kind-config.yaml (solution + starter)** - `6ac99bb` (chore)
2. **Task 2: Recreate KIND cluster and redeploy Phase 02 base stack** - AWAITING HUMAN VERIFICATION

**Plan metadata:** (pending — will be created after human checkpoint completion)

## Files Created/Modified
- `course-code/labs/lab-00/solution/setup/kind-config.yaml` - Added containerPort 30203/30900/30901 to control-plane extraPortMappings
- `course-code/labs/lab-00/starter/setup/kind-config.yaml` - Same three additions to control-plane extraPortMappings

## Decisions Made
- Skip kube-prometheus-stack redeploy after cluster recreate to preserve ~1 GB headroom for MinIO + Pattern B vLLM. Monitoring can be restored with the Lab 06 helm install command if needed.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None — both kind-config.yaml files were structurally identical for the section being modified; edits applied cleanly.

## User Setup Required

**Cluster recreate required.** NodePort bindings in KIND cannot be hot-added post-creation. After this checkpoint:

1. `kind delete cluster --name llmops-kind`
2. `kind create cluster --config course-code/labs/lab-00/solution/setup/kind-config.yaml`
3. Redeploy Phase 02 base stack (see Task 2 instructions in PLAN.md)

See `03-01-PLAN.md` Task 2 for the full 11-step verification sequence.

## Next Phase Readiness

After the human checkpoint is approved:
- KIND cluster will have NodePorts 30203/30900/30901 bound on the host
- Phase 02 base stack (retriever + vLLM Pattern A + Chainlit) will be running
- Ready for Plan 03-02: MinIO deployment and model upload

---
*Phase: 03-disk-based-model-loading-minio-initcontainer*
*Completed: 2026-06-15 (partial — paused at checkpoint Task 2)*
