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
  - MinIO 5.4.0 running in minio namespace (1 replica, verified healthy on NodePort 30900)
  - S3 bucket minio/models/smollm2-finetuned/ populated with merged-model (516.52 MiB, 6 files)

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

duration: 25min
completed: 2026-06-15
---

# Phase 03 Plan 02: MinIO Manifests + Model Uploader Job Summary

**MinIO 5.4.0 standalone installed on KIND with NodePorts 30900/30901; merged-model (516.52 MiB, 6 files) uploaded to minio/models/smollm2-finetuned/ via one-shot mc Job; lab-06 solution/starter manifests created**

## Performance

- **Duration:** ~25 min (Tasks 1+2 automated, Task 3 human-verified)
- **Started:** 2026-06-15T00:00:00Z
- **Completed:** 2026-06-15
- **Tasks:** 3 of 3 (all complete)
- **Files created:** 6

## Accomplishments

- Created lab-06 directory tree (solution/k8s + starter/k8s) with six manifest files for Tasks 1 and 2
- MinIO Helm values file uses standalone mode + replicas=1 (both required per Pitfall 5), NodePort 30900/30901, 2Gi PVC
- model-uploader Job solution is complete with mc retry loop, mb + cp --recursive, and ls verification
- Starter Job has mc command body blanked with TODO hint (all other fields complete: image, resources, volumeMounts, volumes)
- Inline comments document Pitfall 4 (no nodeName needed) and Pitfall 6 (ClusterIP not NodePort) in each manifest
- MinIO Helm chart 5.4.0 installed: 1 replica pod Running (Pitfall 5 avoided — NOT 16 replicas)
- curl http://localhost:30900/minio/health/live returned HTTP 200
- model-uploader Job completed (1/1): 6 files uploaded to minio/models/smollm2-finetuned/ at 89.36 MiB/s (total 516.52 MiB)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create MinIO namespace manifest and Helm values file (solution + starter)** - `0062e12` (feat)
2. **Task 2: Create model-uploader Job manifest (solution + starter with blanks)** - `9dccb9f` (feat)
3. **Task 3: Install MinIO and run model-uploader Job; verify model in S3** - human-verified (checkpoint:human-verify APPROVED)

**Plan metadata:** (this SUMMARY.md commit)

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

Task 3 was a checkpoint:human-verify gate. The following was confirmed by human verification:

1. MinIO Helm repo added (`helm repo add minio-official https://charts.min.io/`) and chart 5.4.0 installed
2. MinIO pod: 1/1 Running in minio namespace (NOT 16 replicas — Pitfall 5 confirmed avoided)
3. `curl http://localhost:30900/minio/health/live` returned HTTP 200
4. model-uploader Job applied and completed: `kubectl wait --for=condition=complete job/model-uploader -n llm-app` satisfied
5. 6 files uploaded to minio/models/smollm2-finetuned/ at 89.36 MiB/s:
   - chat_template.jinja (368 B)
   - config.json (904 B)
   - generation_config.json (131 B)
   - model.safetensors (513 MiB) — key artifact
   - tokenizer.json (3.4 MiB)
   - tokenizer_config.json (383 B)
   - Total: 516.52 MiB transferred

## Known Stubs

None — no placeholder data or hardcoded empty values in the manifests.

## Threat Flags

No new network endpoints or auth paths beyond what was described in the plan's threat model.
The minio/minio123 credential in the Helm values and Job manifest is accepted per T-03-02 (course-grade demo, not production). Inline comments in both files note "demo only, not production".

## Next Phase Readiness

All plan acceptance criteria met:
- MinIO 5.4.0 running at NodePort 30900 (S3 API) and 30901 (console) in minio namespace, 1 replica
- Bucket `models` populated with `smollm2-finetuned/` containing model.safetensors (513 MiB) + 5 supporting files
- Ready for 03-03: vLLM initContainer Deployment + NodePort Service (Pattern B — disk-based loading from MinIO)

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
- Task 3 (checkpoint:human-verify) — APPROVED by human; MinIO healthy + model upload confirmed
