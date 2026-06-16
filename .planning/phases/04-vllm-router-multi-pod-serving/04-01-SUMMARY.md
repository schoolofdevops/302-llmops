---
phase: 04-vllm-router-multi-pod-serving
plan: "01"
subsystem: infra
tags: [kind, kubernetes, nodeport, port-mapping, cluster-setup]

# Dependency graph
requires:
  - phase: 02-llmops-spine
    provides: "KIND cluster setup (lab-00), vllm-smollm2 deployment (lab-04), disk-loading pattern (lab-06)"
  - phase: 03-disk-loading
    provides: "MinIO object store, model-uploader Job, Pattern B (vllm-smollm2-disk)"
provides:
  - "kind-config.yaml with NodePort 30201 for lmstack-router external access"
  - "Cluster recreation instructions for GAP-3 fix"
affects:
  - "04-02-helm-install-vllm-stack"
  - "04-03-verify-router"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "KIND extraPortMappings: all NodePorts listed on control-plane node only (workers not needed)"
    - "Numeric ordering of extraPortMappings for readability (30200, 30201, 30203, 30300, ...)"

key-files:
  created: []
  modified:
    - "course-code/labs/lab-00/solution/setup/kind-config.yaml"

key-decisions:
  - "Inserted 30201 between 30200 and 30203 (numeric order) rather than after 30203 as the plan literally stated — plan intent was 'numeric order' and literal placement would violate that"

patterns-established:
  - "NodePort mapping: only add to control-plane node, not workers"

requirements-completed: [SERVE-03]

# Metrics
duration: 5min
completed: 2026-06-16
---

# Phase 4 Plan 01: GAP-3 NodePort 30201 Fix Summary

**Added NodePort 30201 to KIND control-plane extraPortMappings, enabling lmstack-router external access after cluster recreate**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-06-16T00:00:00Z
- **Completed:** 2026-06-16T00:05:00Z
- **Tasks:** 1 of 2 (Task 2 is blocking human checkpoint)
- **Files modified:** 1

## Accomplishments
- Added `containerPort: 30201 / hostPort: 30201` to kind-config.yaml in correct numeric position (between 30200 and 30203)
- Verified the entry with `grep containerPort: 30201` — confirmed present
- Committed as `feat(04-01)` with GAP-3 reference

## Task Commits

Each task was committed atomically:

1. **Task 1: Add NodePort 30201 to kind-config.yaml** - `df2a273` (feat)
2. **Task 2: Cluster recreate + stack redeploy** - PENDING (blocking human checkpoint)

**Plan metadata:** (committed with SUMMARY.md)

## Files Created/Modified
- `course-code/labs/lab-00/solution/setup/kind-config.yaml` - Added containerPort/hostPort 30201 entry in control-plane extraPortMappings

## Decisions Made
- Inserted 30201 between 30200 and 30203 (numeric order). The plan text said "insert after 30203" but also said "keep port list in numeric order for readability" — those are contradictory. Numeric order is the correct intent, so 30201 goes between 30200 and 30203.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Port insertion position corrected for numeric order**
- **Found during:** Task 1 (Add NodePort 30201 to kind-config.yaml)
- **Issue:** Plan said "insert after containerPort: 30203" but also said "keep port list in numeric order." These contradict: 30201 < 30203, so inserting after 30203 breaks numeric order.
- **Fix:** Inserted 30201 between 30200 and 30203 to maintain numeric ordering.
- **Files modified:** course-code/labs/lab-00/solution/setup/kind-config.yaml
- **Verification:** Port list reads ...30200, 30201, 30300... in numeric sequence with 30203 remaining after 30201.
- **Committed in:** df2a273 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - instruction inconsistency corrected)
**Impact on plan:** Cosmetic ordering fix only; does not affect functionality.

## Issues Encountered
None beyond the plan instruction inconsistency noted above.

## User Setup Required

**Cluster recreation is required.** This plan included a `checkpoint:human-action` (Task 2) that requires the user to:

1. Destroy the existing KIND cluster: `kind delete cluster --name llmops-kind`
2. Recreate it from the updated kind-config.yaml
3. Redeploy the Phase 02/03 prerequisite stack (MinIO, model-uploader, Pattern A + B deployments)
4. Scale both vllm deployments to 0 replicas for memory headroom

Full step-by-step instructions are in the checkpoint message returned to the orchestrator.

## Threat Surface Scan

No new network endpoints, auth paths, or schema changes introduced. The only change is adding a port mapping to a KIND cluster config file (version-controlled, local only). No threat flags to report.

## Known Stubs

None. This plan only modifies a YAML config file.

## Next Phase Readiness

- After the user completes the cluster recreation (Task 2), Phase 04 Plan 02 (Helm install of vllm-stack) can proceed.
- Blocker: User must run cluster recreate and confirm via "approved" signal before Plan 04-02 starts.

## Addendum — Checkpoint Resolution (2026-06-16)

Cluster recreate completed. Additional issues found and resolved:

| Issue | Root Cause | Fix | Commit |
|-------|-----------|-----|--------|
| `llm-app` namespace missing | Plan omitted create step | User created manually; plan fixed | — |
| model-uploader stuck ContainerCreating | `./llmops-project` resolves to empty `setup/llmops-project/` | Uploaded model via `aws` CLI to MinIO S3 endpoint; hostPath fixed | e6b1fa1 |
| `kubectl cp` to MinIO failed | No `tar` in MinIO container | Used `aws s3 cp --endpoint-url http://localhost:30900` | — |
| monitoring + KEDA missing | All workloads lost on cluster delete | Reinstalled kube-prometheus-stack 83.4.2 + KEDA 2.19.0 | — |

**kind-config.yaml hostPath fix (commit e6b1fa1):** `./llmops-project` → `../../../../../llmops-project` across all 3 node entries. Relative path from `setup/` must traverse up to course root where `llmops-project/` actually lives.

**Final verified state:**
- 3 nodes Ready; NodePort 30201 mapped in Docker PortBindings
- MinIO Running; `models/smollm2-finetuned/` bucket with 6 files (513MiB safetensors)
- `vllm-smollm2` DESIRED=0, `vllm-smollm2-disk` DESIRED=0
- kube-prometheus-stack Running in `monitoring`; KEDA Running in `keda`

**Plan 04-01 COMPLETE — proceeding to Wave 1 (04-02)**

---
*Phase: 04-vllm-router-multi-pod-serving*
*Completed: 2026-06-16*
