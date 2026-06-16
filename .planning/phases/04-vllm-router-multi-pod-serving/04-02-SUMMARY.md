---
phase: 04-vllm-router-multi-pod-serving
plan: "02"
status: complete
completed_at: "2026-06-16"
commits:
  - 6e7f110  # Values files + plan fixes
wave: 1
---

# 04-02 Summary — Helm Install vllm-stack 0.1.11 + Router Verified

## What Was Done

1. **Values files created** (Task 1)
   - `course-code/labs/lab-07/solution/k8s/00-values-vllm-router.yaml` — complete values
   - `course-code/labs/lab-07/starter/k8s/00-values-vllm-router.yaml` — guided TODO blanks for 4 fields

2. **helm template dry-run → CASE 1** — emptyDir initContainer rendered correctly in 0.1.11 chart. `initContainers:` block appears with `model-download` container and `/model` volumeMount. No fallback needed.

3. **helm install ran** (by executor agent before Docker crash) — release created at 10:09 (revision 1), upgraded at 10:31 (revision 2).

4. **ARM64 platform fix** — `lmcache/lmstack-router:v0.1.11` is amd64-only. KIND nodes on Apple Silicon refused to pull it (`no match for platform in manifest`).
   - `kind load` failed: no disk space for tar
   - Fix: `docker pull --platform linux/amd64 ...` → `docker tag ... localhost:5001/lmstack-router:v0.1.11` → `docker push localhost:5001/lmstack-router:v0.1.11`
   - Updated values: `repository: "kind-registry:5001/lmstack-router"`
   - helm upgrade applied new image; `kind-registry:5001` resolves inside cluster as expected

5. **Probe fix** — Rosetta emulation causes slow startup; liveness `timeout=1s` too tight.
   - Exit code 137 (SIGKILL) from liveness after 50s
   - Patched via `kubectl patch`: timeout 1s→10s, liveness failureThreshold 3→6, startup failureThreshold 3→12
   - Router stabilized: 1/1 Running, 0 restarts

## Final Verified State

| Check | Result |
|-------|--------|
| `helm list -n llm-serving` | vllm-stack 0.1.11, STATUS=deployed (rev 3) |
| Router pod | 1/1 Running, 0 restarts |
| Backend pods | 2/2 × 1/1 Running (initContainer completed in ~2min) |
| `GET localhost:30201/health` | `{"status":"healthy"}` |
| `POST localhost:30201/v1/chat/completions` | Valid response, model=smollm2-135m-finetuned |
| `kubectl get endpoints -n llm-serving` | router-service has 2 backend IPs |
| KEDA ScaledObject | READY=True, ACTIVE=False (idle at min replicas) |

## Key Facts for Plan 04-03

- **Backend Deployment name**: `vllm-stack-smollm2-deployment-vllm`
- **KEDA ScaledObject name**: `vllm-stack-smollm2-scaledobject`
- **helm template case**: CASE 1 (emptyDir initContainer works in 0.1.11)
- **ARM64 gate triggered**: YES — requires pre-push to kind-registry:5001
- **Probe patch required on arm64**: YES — liveness/startup timeout must be 10s+ under Rosetta

## Issues Encountered

| Issue | Root Cause | Fix |
|-------|-----------|-----|
| Docker overlay2 I/O error | Executor agent heavy ops caused Docker Desktop crash | Restart Docker Desktop |
| Router `no match for platform` | lmstack-router v0.1.11 is amd64-only | Push to kind-registry:5001 |
| `kind load` disk full | `/tmp` space exhausted by 5.3GB image tar | Use local registry instead |
| Router CrashLoopBackOff (exit 137) | Liveness probe timeout=1s too tight under Rosetta | Patch timeout→10s, failures→6/12 |
| helm upgrade timeout | `--wait --timeout 120s` too short for rolling update | Upgrade applied; patched RS manually |

## Values File Deviations from Plan

- `repository`: changed from `lmcache/lmstack-router` → `kind-registry:5001/lmstack-router` (arm64 fix)
- `minReplicaCount`: set to 2 (not 1 as plan said) — ensures 2 backends at idle for demo purposes
- ARM64 setup steps added as comments in both solution and starter files

## Ready for Plan 04-03
