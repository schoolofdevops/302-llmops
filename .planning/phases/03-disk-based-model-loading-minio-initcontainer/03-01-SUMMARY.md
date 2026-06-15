---
phase: 03-disk-based-model-loading-minio-initcontainer
plan: "01"
subsystem: infra
tags: [kind, kubernetes, nodeport, minio, vllm, rag-retriever, chainlit]

# Dependency graph
requires:
  - phase: 02-modernize-llmops-spine-labs-00-05
    provides: Phase 02 base stack (vllm-smollm2, rag-retriever, chainlit-ui) manifests and NodePorts 30200/30300/30400/30500
provides:
  - Updated kind-config.yaml (solution + starter) with NodePorts 30203, 30900, 30901 for Phase 03 workloads
  - Running KIND cluster llmops-kind with all Phase 02 + Phase 03 NodePorts bound at the host
  - Phase 02 base stack redeployed (vllm-smollm2 in llm-serving, rag-retriever in llm-app, chainlit-ui in llm-app)
  - kube-prometheus-stack intentionally omitted to preserve ~3.25 GB RAM headroom for MinIO + Pattern B
affects:
  - 03-disk-based-model-loading-minio-initcontainer plans 02/03/04

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "KIND extraPortMappings must be declared at cluster-create time; post-creation hot-add is impossible — delete+recreate cycle required"
    - "Memory budget: skip kube-prometheus-stack during Phase 03 to reserve headroom for MinIO + second vLLM pod"
    - "Control-plane node owns all NodePort bindings; worker nodes get extraMounts only"

key-files:
  created: []
  modified:
    - course-code/labs/lab-00/solution/setup/kind-config.yaml
    - course-code/labs/lab-00/starter/setup/kind-config.yaml

key-decisions:
  - "kube-prometheus-stack intentionally NOT redeployed after cluster recreate — preserves ~3.25 GB RAM for MinIO + vllm-smollm2-disk; can be restored with Lab 05 helm install if needed"
  - "rag-retriever requires two ConfigMaps (clinic-data, retriever-code) not present in lab-01 k8s/ manifests — created manually via kubectl create configmap; this is a GAP in lab-01 manifest coverage"
  - "Add 30203 (vllm-smollm2-disk), 30900 (MinIO API), 30901 (MinIO console) to control-plane node only"

patterns-established:
  - "Phase 03 NodePorts use range 30203/30900/30901 — distinct from Phase 02 range 30200/30300/30400/30500"

requirements-completed: [PACKAGE-02]

# Metrics
duration: 35min
completed: 2026-06-15
---

# Phase 03 Plan 01: KIND cluster NodePort additions + cluster recreate Summary

**NodePorts 30203/30900/30901 added to kind-config.yaml, KIND cluster recreated with all six Phase 02+03 ports bound, and Phase 02 base stack (vllm-smollm2 + rag-retriever + chainlit-ui) verified healthy — Phase 03 environment fully ready**

## Performance

- **Duration:** ~35 min (Task 1 automated; Task 2 human-executed cluster recreate + redeploy)
- **Started:** 2026-06-15T13:00:00Z
- **Completed:** 2026-06-15
- **Tasks:** 2 of 2 completed
- **Files modified:** 2

## Accomplishments

- Both kind-config.yaml files (solution + starter) updated with three new extraPortMappings entries (30203, 30900, 30901) on the control-plane node; all existing Phase 02 ports preserved
- KIND cluster llmops-kind recreated; docker inspect confirmed hostPort bindings for 30203, 30900, and 30901
- Phase 02 base stack redeployed and verified: vllm-smollm2 Running 1/1 (llm-serving), rag-retriever Running 1/1 (llm-app), chainlit-ui Running (llm-app)
- curl localhost:30200/health returned HTTP 200; curl localhost:30300 returned HTTP 200
- kube-prometheus-stack deferred to preserve memory headroom for upcoming MinIO + Pattern B work

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Phase 03 NodePorts to kind-config.yaml (solution + starter)** - `6ac99bb` (fix)
2. **Task 2: Recreate KIND cluster and redeploy Phase 02 base stack** - human-executed; no code commit (cluster state only)

## Files Created/Modified

- `course-code/labs/lab-00/solution/setup/kind-config.yaml` - Added extraPortMappings for containerPort/hostPort 30203, 30900, 30901 on control-plane node
- `course-code/labs/lab-00/starter/setup/kind-config.yaml` - Same three portMapping additions (student starter file kept in sync)

## Decisions Made

- **kube-prometheus-stack skipped:** After cluster recreate, Prometheus + Grafana were intentionally NOT redeployed. Phase 03 does not require monitoring running simultaneously with MinIO + a second vLLM pod. Skipping preserves approximately 1-3 GB RAM. Lab 05 helm install command restores it if needed.
- **rag-retriever ConfigMap gap identified:** The lab-01 k8s/ directory contains only a Deployment and Service manifest. The rag-retriever Pod requires two ConfigMaps — `clinic-data` (dental clinic JSON data) and `retriever-code` (the Python retriever script) — that were created manually via `kubectl create configmap`. This is a known gap for the lab-01 guide (see Issues Encountered).

## Deviations from Plan

None — plan executed exactly as written. Task 1 was automated (file edits + commit). Task 2 was a checkpoint:human-verify that the user approved after running all 11 verification steps.

## Issues Encountered

**rag-retriever ConfigMap gap (course content gap, not an executor blocker):** The lab-01 solution k8s/ manifests do not include ConfigMap definitions for `clinic-data` or `retriever-code`. During the Phase 02 base stack redeploy after cluster recreate, these two ConfigMaps had to be created manually via `kubectl create configmap` before the rag-retriever Deployment could reach Running state.

Students following the lab guide step-by-step would encounter a Pod that fails to start (missing volume mounts). This gap must be addressed in a future plan — either by adding ConfigMap YAML files to `course-code/labs/lab-01/solution/k8s/` or by including explicit `kubectl create configmap` commands in the lab-01 guide.

**Verification result summary (human-confirmed):**

| Check | Result |
|-------|--------|
| hostPort bindings for 30203/30900/30901 | Confirmed via docker inspect |
| kubectl get nodes (3 nodes, all Ready) | Confirmed |
| vllm-smollm2 Running 1/1 (llm-serving) | Confirmed |
| curl localhost:30200/health → 200 | Confirmed |
| curl localhost:30300 (Chainlit) → 200 | Confirmed |
| rag-retriever Running 1/1, /health {"ok":true} | Confirmed |
| kube-prometheus-stack | Intentionally NOT redeployed |

## User Setup Required

None beyond what was already executed in the human checkpoint.

## Known Stubs

None.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes introduced. kind-config.yaml is course configuration reviewed during the human checkpoint before cluster creation.

## Next Phase Readiness

- KIND cluster is running with all six Phase 02 + Phase 03 NodePorts bound (30200, 30300, 30400, 30500, 30203, 30900, 30901)
- Phase 02 base stack is healthy: vllm-smollm2, rag-retriever, chainlit-ui all Running
- NodePort 30900 (MinIO API) and 30901 (MinIO console) are bound — Plan 03-02 (MinIO deploy) can proceed immediately
- NodePort 30203 (vllm-smollm2-disk) is bound — Plan 03-03 (Pattern B vLLM) can proceed
- **Open gap:** lab-01 k8s/ manifests are missing ConfigMap definitions for clinic-data and retriever-code — must be addressed before the lab guide is student-ready

---
*Phase: 03-disk-based-model-loading-minio-initcontainer*
*Completed: 2026-06-15*
