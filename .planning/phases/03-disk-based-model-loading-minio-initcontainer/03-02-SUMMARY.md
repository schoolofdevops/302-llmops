---
phase: 03-disk-based-model-loading-minio-initcontainer
plan: "02"
subsystem: infra
tags: [minio, kubernetes, helm, object-storage, job, mc, model-upload, s3]

requires:
  - phase: 03-01
    provides: KIND cluster with NodePorts 30900/30901 bound; llm-app namespace exists

provides:
  - MinIO namespace manifest (00-namespace-minio.yaml) for both solution/ and starter/
  - MinIO Helm values (10-minio-values.yaml) standalone mode NodePort 30900/30901
  - model-uploader Job manifest (20-job-model-uploader.yaml) — solution complete, starter blanked
  - Checkpoint: human verifies MinIO install + model-uploader Job completion

affects: [03-03, 03-04]

tech-stack:
  added:
    - MinIO Helm chart minio-official/minio 5.4.0 (standalone mode)
    - quay.io/minio/mc:RELEASE.2024-11-21T17-21-54Z (mc client in Job)
  patterns:
    - Helm values file pattern (solution = starter, both complete — students install not write)
    - One-shot Job pattern for model upload: retry loop → mc mb → mc cp → mc ls verify
    - ClusterIP DNS (minio.minio:9000) vs NodePort (30900) distinction documented inline

key-files:
  created:
    - course-code/labs/lab-06/solution/k8s/00-namespace-minio.yaml
    - course-code/labs/lab-06/solution/k8s/10-minio-values.yaml
    - course-code/labs/lab-06/solution/k8s/20-job-model-uploader.yaml
    - course-code/labs/lab-06/starter/k8s/00-namespace-minio.yaml
    - course-code/labs/lab-06/starter/k8s/10-minio-values.yaml
    - course-code/labs/lab-06/starter/k8s/20-job-model-uploader.yaml
  modified: []

key-decisions:
  - "No nodeName constraint on model-uploader Job — all KIND nodes share macOS host bind-mount (Pitfall 4 confirmed)"
  - "model-uploader Job in llm-app namespace (not minio) — follows 'app workloads in app namespace' convention"
  - "Starter 10-minio-values.yaml is identical to solution — students install the chart using the file, not write it"
  - "starter 20-job-model-uploader.yaml blanks only the mc command body — all other fields complete for student focus"

patterns-established:
  - "Helm values file: both mode: standalone AND replicas: 1 always paired (Pitfall 5 guard)"
  - "In-cluster S3 access: always use ClusterIP DNS (minio.minio:9000), never NodePort 30900 from pods"
  - "mc retry loop: until mc alias set ... ; do sleep 5; done — idiomatic wait-for-minio"

requirements-completed: [PACKAGE-02]

duration: 15min
completed: 2026-06-15
---

# Phase 03 Plan 02: MinIO Manifests + Model Uploader Job Summary

**MinIO standalone Helm values and one-shot mc Job manifest to upload merged-model (513 MB) from hostPath to S3 bucket minio/models/smollm2-finetuned/, with starter/solution split**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-06-15T00:00:00Z
- **Completed:** 2026-06-15
- **Tasks:** 2 of 3 (Task 3 is checkpoint:human-verify — paused for human)
- **Files created:** 6

## Accomplishments

- Created lab-06 directory tree (solution/k8s + starter/k8s) with all four manifest files for Task 1 and Task 2
- MinIO Helm values file uses standalone mode + replicas=1 (both required per Pitfall 5), NodePort 30900/30901, 2Gi PVC
- model-uploader Job solution is complete with mc retry loop, mb + cp --recursive, and ls verification
- Starter Job has mc command body blanked with TODO hint (all other fields complete: image, resources, volumeMounts, volumes)
- Inline comments document Pitfall 4 (no nodeName needed) and Pitfall 6 (ClusterIP not NodePort) in each manifest

## Task Commits

Each task was committed atomically:

1. **Task 1: Create MinIO namespace manifest and Helm values file (solution + starter)** - `0062e12` (feat)
2. **Task 2: Create model-uploader Job manifest (solution + starter with blanks)** - `9dccb9f` (feat)
3. **Task 3: checkpoint:human-verify** — PAUSED (awaiting human install + verification)

**Plan metadata:** (committed after checkpoint resolves in 03-02 continuation)

## Files Created/Modified

- `course-code/labs/lab-06/solution/k8s/00-namespace-minio.yaml` - minio namespace with course/phase labels
- `course-code/labs/lab-06/solution/k8s/10-minio-values.yaml` - MinIO Helm values standalone mode, NodePort 30900/30901
- `course-code/labs/lab-06/solution/k8s/20-job-model-uploader.yaml` - complete model-uploader Job (mc retry + mb + cp + ls)
- `course-code/labs/lab-06/starter/k8s/00-namespace-minio.yaml` - identical to solution (no blanks)
- `course-code/labs/lab-06/starter/k8s/10-minio-values.yaml` - identical to solution (students install, not write)
- `course-code/labs/lab-06/starter/k8s/20-job-model-uploader.yaml` - mc command body blanked with TODO comments

## Decisions Made

- No `nodeName` constraint on model-uploader Job — all KIND nodes share the macOS host Docker bind-mount for `./llmops-project` → `/mnt/project`, so the model files at `/mnt/project/training/merged-model` are visible on any node that schedules the Job (confirmed in Pitfall 4 RESEARCH.md)
- Job placed in `llm-app` namespace (not `minio`) — consistent with "app workloads in app namespace" convention; MinIO is infrastructure, the Job is an app operation
- Both `mode: standalone` and `replicas: 1` included in Helm values as explicit protection against Pitfall 5 (chart v5.4.0 may default to 16-replica StatefulSet without both)
- Starter `10-minio-values.yaml` is identical to solution — students run `helm install` using this file, they don't fill in blanks

## Deviations from Plan

None — plan executed exactly as written. Manifest content follows the exact YAML from the plan's `<action>` section and verified patterns from RESEARCH.md.

## Issues Encountered

None.

## User Setup Required

Task 3 (checkpoint:human-verify) requires the student/instructor to:
1. Add MinIO Helm repo and install with `helm install minio minio-official/minio --namespace minio -f ...`
2. Wait for MinIO pod (1/1 Running, NOT 16 — Pitfall 5 check)
3. Apply model-uploader Job and wait for completion
4. Run `mc ls minio/models/smollm2-finetuned/` from inside cluster to verify model.safetensors (513 MB)

## Known Stubs

None — no placeholder data or hardcoded empty values in the manifests.

## Threat Flags

No new network endpoints or auth paths beyond what was described in the plan's threat model.
The minio/minio123 credential in the Helm values and Job manifest is accepted per T-03-02 (course-grade demo, not production). Inline comments in both files note "demo only, not production".

## Next Phase Readiness

After human approves Task 3 checkpoint:
- MinIO running at NodePort 30900 (S3 API) and 30901 (console) in minio namespace
- Bucket `models` populated with `smollm2-finetuned/model.safetensors` (513 MB)
- Ready for 03-03: vLLM initContainer Deployment + NodePort Service (Pattern B)

---
*Phase: 03-disk-based-model-loading-minio-initcontainer*
*Completed: 2026-06-15*

## Self-Check: PASSED

- `course-code/labs/lab-06/solution/k8s/00-namespace-minio.yaml` — FOUND
- `course-code/labs/lab-06/solution/k8s/10-minio-values.yaml` — FOUND
- `course-code/labs/lab-06/solution/k8s/20-job-model-uploader.yaml` — FOUND
- `course-code/labs/lab-06/starter/k8s/00-namespace-minio.yaml` — FOUND
- `course-code/labs/lab-06/starter/k8s/10-minio-values.yaml` — FOUND
- `course-code/labs/lab-06/starter/k8s/20-job-model-uploader.yaml` — FOUND
- Task 1 commit `0062e12` — verified
- Task 2 commit `9dccb9f` — verified
