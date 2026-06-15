---
phase: 03-disk-based-model-loading-minio-initcontainer
plan: "03"
subsystem: lab-06-manifests
tags: [vllm, initcontainer, emptydir, minio, pattern-b, disk-based, nodeport]
dependency_graph:
  requires: ["03-02"]
  provides: ["lab-06/solution/k8s/30-deploy-vllm-disk.yaml", "lab-06/solution/k8s/30-svc-vllm-disk.yaml", "lab-06/starter/k8s/30-deploy-vllm-disk.yaml", "lab-06/starter/k8s/30-svc-vllm-disk.yaml"]
  affects: ["llm-serving namespace", "NodePort 30203"]
tech_stack:
  added: []
  patterns:
    - "initContainer + emptyDir model download with sha256 verification and sentinel gate"
    - "Shell sentinel-wait loop in main container (until [ -f /model/READY ])"
    - "emptyDir sizeLimit: 1Gi with ephemeral-storage requests/limits on both containers"
key_files:
  created:
    - course-code/labs/lab-06/solution/k8s/30-deploy-vllm-disk.yaml
    - course-code/labs/lab-06/solution/k8s/30-svc-vllm-disk.yaml
    - course-code/labs/lab-06/starter/k8s/30-deploy-vllm-disk.yaml
    - course-code/labs/lab-06/starter/k8s/30-svc-vllm-disk.yaml
  modified: []
decisions:
  - "emptyDir sizeLimit set to 1Gi (~2x headroom for 517 MB model) per Research Pitfall 2"
  - "sha256 hardcoded inline in initContainer command script (course-grade simplicity vs ConfigMap)"
  - "starter/ blanks only initContainer script body and sentinel wait loop body; all other fields complete"
  - "NodePort 30203 reserved exclusively for Pattern B vLLM to enable concurrent comparison with Pattern A at 30200"
metrics:
  duration: "<5 minutes"
  completed: "2026-06-15T12:23:00Z"
  tasks_completed: 1
  tasks_total: 2
  files_created: 4
  files_modified: 0
---

# Phase 03 Plan 03: vllm-smollm2-disk Deployment and Service Manifests Summary

**One-liner:** Pattern B vLLM Deployment with initContainer MinIO download, sha256 verification, /model/READY sentinel gate, and emptyDir sizeLimit:1Gi — solution and starter manifests for lab-06.

## What Was Built

Created four Kubernetes manifest files for lab-06 (Pattern B — disk-based model loading):

**Solution manifests (complete, deployable):**
- `course-code/labs/lab-06/solution/k8s/30-deploy-vllm-disk.yaml` — `vllm-smollm2-disk` Deployment with:
  - `initContainer` (`model-download`) using `quay.io/minio/mc:RELEASE.2024-11-21T17-21-54Z`
  - Shell script: `mc alias set` → `mc cp --recursive minio/models/smollm2-finetuned/ /model/` → sha256 verify → `touch /model/READY`
  - `emptyDir` volume with `sizeLimit: 1Gi`
  - Main vLLM container: sentinel wait loop then `exec python3 -m vllm.entrypoints.openai.api_server --model=/model ...`
  - `VLLM_CPU_KVCACHE_SPACE: "2"` (OOM guard for 5Gi KIND nodes)
  - Resources: initContainer `{cpu:200m, memory:128Mi, ephemeral-storage:1Gi}` / vLLM `{cpu:4, memory:4Gi, ephemeral-storage:1Gi}`
- `course-code/labs/lab-06/solution/k8s/30-svc-vllm-disk.yaml` — NodePort 30203 Service selecting `app: vllm-disk`

**Starter manifests (lab exercise):**
- `course-code/labs/lab-06/starter/k8s/30-deploy-vllm-disk.yaml` — identical structure with initContainer script body replaced by TODO comment and sentinel wait loop replaced by TODO comment; all other fields complete (image, resources, volumeMounts, env, probes)
- `course-code/labs/lab-06/starter/k8s/30-svc-vllm-disk.yaml` — identical to solution (no blanks)

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create vllm-smollm2-disk Deployment and Service manifests (solution + starter) | 3cb4071 | 4 files created |

## Tasks Awaiting Human Verification

| Task | Name | Status |
|------|------|--------|
| 2 | Deploy Pattern B vLLM, verify initContainer flow, observe emptyDir re-download | checkpoint:human-verify (blocking) |

## Deviations from Plan

None — plan executed exactly as written.

## Threat Surface Scan

No new security surface introduced beyond what is documented in the plan's threat model:
- T-03-05 mitigated: sha256 verification before sentinel write ensures integrity
- T-03-06 accepted: minio/minio123 credentials in manifest — course-grade, lab text must note demo-grade
- T-03-07 mitigated: sizeLimit:1Gi + ephemeral-storage requests/limits on both containers
- T-03-SC mitigated: quay.io/minio/mc pinned to exact dated tag (RELEASE.2024-11-21T17-21-54Z)

## Known Stubs

None. The manifests are complete and deployable for the solution. The starter intentionally blanks the initContainer script and sentinel loop for pedagogical purposes — this is by design, not a stub that blocks functionality.

## Self-Check: PASSED

Files exist:
- FOUND: course-code/labs/lab-06/solution/k8s/30-deploy-vllm-disk.yaml
- FOUND: course-code/labs/lab-06/solution/k8s/30-svc-vllm-disk.yaml
- FOUND: course-code/labs/lab-06/starter/k8s/30-deploy-vllm-disk.yaml
- FOUND: course-code/labs/lab-06/starter/k8s/30-svc-vllm-disk.yaml

Commit exists: 3cb4071 — feat(03-03): create vllm-smollm2-disk Deployment and Service manifests
