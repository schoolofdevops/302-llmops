---
phase: 02-llmops-labs-day-1
plan: "04"
subsystem: infra
tags: [vllm, docker, kubernetes, alpine, imagevolume, model-serving, oci-packaging]

# Dependency graph
requires:
  - phase: 02-llmops-labs-day-1
    plan: "03"
    provides: Lab 02 LoRA training and merge scripts — merged-model/ is the input to Lab 03 packaging
provides:
  - Lab 03 OCI model packaging: Dockerfile.model-asset (alpine:3.20) and build_model_image.sh
  - Lab 04 vLLM serving: K8s Deployment + NodePort Service + end-to-end test script
  - starter/ skeletons for both labs with TODO structure
affects:
  - 02-05
  - 02-06
  - 02-07

# Tech tracking
tech-stack:
  added:
    - alpine:3.20 (minimal OCI base for model weight packaging)
    - schoolofdevops/vllm-cpu-nonuma:0.9.1 (custom CPU vLLM image)
    - Kubernetes ImageVolume (mount OCI image as data volume at /models)
  patterns:
    - "Model-as-OCI-image: package weights in alpine:3.20, no entrypoint, mount via ImageVolume"
    - "CPU vLLM serving: VLLM_CPU_KVCACHE_SPACE=2 (not 4) prevents OOM on 5Gi KIND nodes"
    - "readinessProbe initialDelaySeconds=120 — SmolLM2-135M loads in 60-180s on CPU"
    - "Plain K8s Deployment + NodePort instead of KServe for lab simplicity (D-10)"

key-files:
  created:
    - course-code/labs/lab-03/solution/Dockerfile.model-asset
    - course-code/labs/lab-03/solution/build_model_image.sh
    - course-code/labs/lab-03/starter/Dockerfile.model-asset
    - course-code/labs/lab-03/starter/build_model_image.sh
    - course-code/labs/lab-04/solution/k8s/30-deploy-vllm.yaml
    - course-code/labs/lab-04/solution/k8s/30-svc-vllm.yaml
    - course-code/labs/lab-04/solution/scripts/test-vllm.sh
    - course-code/labs/lab-04/starter/k8s/30-deploy-vllm.yaml
    - course-code/labs/lab-04/starter/k8s/30-svc-vllm.yaml
    - course-code/labs/lab-04/starter/scripts/test-vllm.sh
  modified: []

key-decisions:
  - "VLLM_CPU_KVCACHE_SPACE=2 (not default 4) — OOM protection on 5Gi KIND worker nodes"
  - "ImageVolume pattern: kind-registry:5001/smollm2-135m-finetuned:v1.0.0 mounted at /models via volumes.image"
  - "nodeName: llmops-kind-worker — pin vLLM pod to worker node in KIND single-worker cluster"
  - "readinessProbe initialDelaySeconds=120 + failureThreshold=18 — allows up to 300s total load time"

patterns-established:
  - "OCI model packaging: FROM alpine:3.20 + COPY merged-model/ /model/ + no CMD = data volume image"
  - "build_model_image.sh pattern: source config.env, validate dir, mktemp build context, docker build + push"
  - "vLLM CPU args: --dtype=bfloat16 --disable-frontend-multiprocessing --max-num-seqs=1 --enable-metrics"
  - "test-vllm.sh: sequential /health, /v1/models, /v1/chat/completions with dental domain query"

requirements-completed: [PKG-01, PKG-02, SERVE-01, SERVE-02, SERVE-03]

# Metrics
duration: 4min
completed: 2026-04-23
---

# Phase 02 Plan 04: Lab 03 OCI Packaging + Lab 04 vLLM Serving Summary

**Alpine:3.20 model-as-OCI-image packaging with build script, plus CPU vLLM Deployment on KIND using ImageVolume mount at nodePort 30200**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-23T09:15:06Z
- **Completed:** 2026-04-23T09:19:00Z
- **Tasks:** 2
- **Files modified:** 10 created

## Accomplishments

- Lab 03: Dockerfile.model-asset uses FROM alpine:3.20, COPY merged-model/ /model/, no CMD/ENTRYPOINT — minimal data volume image
- Lab 03: build_model_image.sh validates merged-model dir, creates mktemp build context, builds and pushes to kind-registry:5001
- Lab 04: vLLM Deployment YAML with schoolofdevops/vllm-cpu-nonuma:0.9.1, KVCACHE=2 OOM protection, 120s readiness probe
- Lab 04: NodePort Service exposing vLLM on port 30200 for student curl access
- Lab 04: test-vllm.sh exercises full inference path: /health → /v1/models → /v1/chat/completions with Smile Dental dental query
- Both labs: starter/ skeleton files with TODO comments at exactly the right learning points

## Task Commits

Each task was committed atomically:

1. **Task 1: Lab 03 OCI model packaging** - `3c47839` (feat)
2. **Task 2: Lab 04 vLLM K8s serving** - `ee53469` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `course-code/labs/lab-03/solution/Dockerfile.model-asset` - Minimal alpine:3.20 OCI image for model weights
- `course-code/labs/lab-03/solution/build_model_image.sh` - Build and push to kind-registry:5001 with validation
- `course-code/labs/lab-03/starter/Dockerfile.model-asset` - Skeleton with TODO FROM and COPY instructions
- `course-code/labs/lab-03/starter/build_model_image.sh` - Skeleton with TODO structure
- `course-code/labs/lab-04/solution/k8s/30-deploy-vllm.yaml` - vLLM Deployment: CPU image, env vars, probes, ImageVolume
- `course-code/labs/lab-04/solution/k8s/30-svc-vllm.yaml` - NodePort Service on 30200
- `course-code/labs/lab-04/solution/scripts/test-vllm.sh` - End-to-end test: health + models + chat completion
- `course-code/labs/lab-04/starter/k8s/30-deploy-vllm.yaml` - Skeleton with TODO at image, args, probes, volume reference
- `course-code/labs/lab-04/starter/k8s/30-svc-vllm.yaml` - Full service (provided to students)
- `course-code/labs/lab-04/starter/scripts/test-vllm.sh` - Full test script (provided to students)

## Decisions Made

- VLLM_CPU_KVCACHE_SPACE=2: plan mandated this exact value (not 4) to prevent OOM on 5Gi KIND worker nodes
- nodeName: llmops-kind-worker: pinned to worker node matching KIND cluster topology from Lab 00
- ImageVolume reference uses v1.0.0 tag matching MODEL_IMAGE_TAG in config.env

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Known Stubs

None. All files are complete solutions or intentional TODO skeletons for student exercise.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Lab 03 + Lab 04 code complete; students can package their fine-tuned model and serve it with vLLM on KIND
- Lab 05 (observability) can consume vLLM --enable-metrics output from the serving Deployment
- No blockers

---
*Phase: 02-llmops-labs-day-1*
*Completed: 2026-04-23*
