---
phase: 05-kserve-inferenceservice-serving-decision-lab
plan: 03
subsystem: infra
tags: [kserve, inferenceservice, clusterservingruntime, vllm, emptydir, nodeport, rawdeployment]

# Dependency graph
requires:
  - phase: 05-kserve-inferenceservice-serving-decision-lab
    plan: 02
    provides: "KServe v0.18.0 control-plane installed; cert-manager + Gateway API CRDs ready"
provides:
  - "ClusterServingRuntime vllm-cpu-smollm2 YAML (solution + starter)"
  - "InferenceService smollm2 YAML (solution + starter)"
  - "smollm2-nodeport NodePort Service YAML (solution + starter) — separate Service required due to KServe controller reconciliation"
  - "InferenceService smollm2 READY=True on cluster with OpenAI-compatible API at NodePort 30202"
  - "Starter scaffolds with TODO markers for D-01, D-02, D-03, D-05, D-09, D-11 values"
affects:
  - "05-04-PLAN.md (Lab 08 guide — references these YAML files; must document 25-svc-nodeport.yaml pattern and remove kubectl-patch approach)"

# Tech tracking
tech-stack:
  added: [KServe InferenceService v1beta1, KServe ClusterServingRuntime v1alpha1]
  patterns:
    - "ClusterServingRuntime (v1alpha1) defines cluster-wide container spec; InferenceService provides per-service initContainers + volumes + probes"
    - "spec.predictor.containers (not spec.predictor.model) bypasses storage-initializer webhook — Pitfall 3 mitigation"
    - "sentinel file /mnt/model/READY written by initContainer, polled by kserve-container before vLLM start"
    - "D-11 probe tuning: initialDelaySeconds=90 + failureThreshold=30 = 390s total budget for CPU model load"
    - "Separate NodePort Service selecting KServe predictor pods via serving.kserve.io/inferenceservice label — do NOT patch the managed predictor Service"

key-files:
  created:
    - course-code/labs/lab-08/solution/k8s/10-clusterservingruntime.yaml
    - course-code/labs/lab-08/solution/k8s/20-inferenceservice.yaml
    - course-code/labs/lab-08/solution/k8s/25-svc-nodeport.yaml
    - course-code/labs/lab-08/starter/k8s/10-clusterservingruntime.yaml
    - course-code/labs/lab-08/starter/k8s/20-inferenceservice.yaml
    - course-code/labs/lab-08/starter/k8s/25-svc-nodeport.yaml
  modified: []

key-decisions:
  - "spec.predictor.initContainers (not spec.predictor.podSpec.initContainers) used — confirmed working on live cluster (Open Question 1 resolved)"
  - "Both solution files use spec.predictor.containers pattern (Pattern 2 per RESEARCH.md) — bypasses storage initializer regardless of annotation"
  - "Separate NodePort Service (25-svc-nodeport.yaml) is the correct exposure pattern — KServe controller continuously reconciles smollm2-predictor Service back to ClusterIP; kubectl patch does not persist"
  - "Selector label serving.kserve.io/inferenceservice: smollm2 targets predictor pods without coupling to generated pod-name hash"
  - "Starter scaffold philosophy: keep full key structure visible, mark TODO only at student-fill values (image, env values, probe integers, annotation values)"

patterns-established:
  - "ClusterServingRuntime + InferenceService split: runtime defines image+args+env; InferenceService overrides with initContainers+volumes+probes"
  - "No storageUri field in solution ISVC — storage initializer webhook never triggers (primary defense); annotation is belt-and-suspenders"
  - "Separate NodePort Service pattern for KServe InferenceService on KIND: create smollm2-nodeport selecting via KServe label, do not patch the managed Service"

requirements-completed: [SERVE-02]

# Metrics
duration: 45min
completed: 2026-06-17
---

# Phase 05 Plan 03: ClusterServingRuntime + InferenceService + NodePort Exposure — Summary

**ClusterServingRuntime vllm-cpu-smollm2 + InferenceService smollm2 deployed on KServe v0.18 RawDeployment; separate smollm2-nodeport Service exposes predictor at NodePort 30202; curl localhost:30202/v1/chat/completions verified returning valid response.**

## Performance

- **Duration:** ~45 min (Task 1 auto ~20min + human checkpoint apply/wait ~25min)
- **Started:** 2026-06-17T07:00:00Z
- **Completed:** 2026-06-17
- **Tasks:** 2 complete (1 auto + 1 checkpoint:human-action approved)
- **Files created:** 6

## Accomplishments

- Created `course-code/labs/lab-08/solution/k8s/10-clusterservingruntime.yaml` — complete ClusterServingRuntime with D-01 image, D-02 CPU env vars (VLLM_TARGET_DEVICE=cpu, VLLM_CPU_KVCACHE_SPACE=2, OMP_NUM_THREADS=4, VLLM_CPU_OMP_THREADS_BIND=auto), D-03 resources (4 CPU / 4Gi-5Gi), kserve-container name
- Created `course-code/labs/lab-08/solution/k8s/20-inferenceservice.yaml` — complete InferenceService with RawDeployment annotation (D-09), enable-storage-initialization:false (D-05), emptyDir initContainer mc cp from minio/models/smollm2-finetuned/ (D-04), sentinel-wait kserve-container, D-11 probes (initialDelaySeconds=90, failureThreshold=30), no storageUri field
- Created `course-code/labs/lab-08/solution/k8s/25-svc-nodeport.yaml` — separate NodePort Service selecting predictor pods via `serving.kserve.io/inferenceservice: smollm2` label on NodePort 30202
- Created starter scaffolds for all three files with TODO markers at student-fill values
- InferenceService `smollm2` reached READY=True on live cluster with exactly 2 containers (model-download initContainer + kserve-container), no storage-initializer sidecar
- `curl http://localhost:30202/v1/chat/completions` returns valid response (human verified)

## Task Commits

1. **Task 1: Write ClusterServingRuntime + InferenceService YAML (solution + starter)** — `6c747d4` (feat)
2. **Task 2: Human checkpoint (cluster apply + READY=True + NodePort verify)** — no commit (human verification)
3. **Post-checkpoint: Add 25-svc-nodeport.yaml (solution + starter)** — `373e8ad` (feat)

## Files Created/Modified

- `course-code/labs/lab-08/solution/k8s/10-clusterservingruntime.yaml` — ClusterServingRuntime vllm-cpu-smollm2 (complete solution)
- `course-code/labs/lab-08/solution/k8s/20-inferenceservice.yaml` — InferenceService smollm2 in llm-serving (complete solution)
- `course-code/labs/lab-08/solution/k8s/25-svc-nodeport.yaml` — Separate NodePort Service on 30202 (complete solution)
- `course-code/labs/lab-08/starter/k8s/10-clusterservingruntime.yaml` — Scaffold with 9 TODO markers
- `course-code/labs/lab-08/starter/k8s/20-inferenceservice.yaml` — Scaffold with 8 TODO markers
- `course-code/labs/lab-08/starter/k8s/25-svc-nodeport.yaml` — Scaffold with 2 TODO markers (selector label + nodePort)

## Open Question Resolution (for 05-04-PLAN reference)

**Open Question 1 (RESEARCH.md):** Does `spec.predictor.initContainers` exist in KServe v0.18 InferenceService CRD?
- **Resolution:** CONFIRMED WORKING — `spec.predictor.initContainers` and `spec.predictor.volumes` are accepted by KServe v0.18 on the live cluster. The `podSpec` wrapper is NOT required.
- **Field path used in solution YAML:** `spec.predictor.initContainers` and `spec.predictor.volumes`

**Open Question 2 — RawDeployment Service reconciliation:** KServe controller continuously reconciles its managed `smollm2-predictor` Service back to ClusterIP. `kubectl patch` succeeds momentarily but is reverted immediately. See Deviation 1 below.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical Functionality] Added 25-svc-nodeport.yaml — separate NodePort Service required**

- **Found during:** Task 2 (human-action checkpoint verification)
- **Issue:** Plan Step 5 instructed patching `smollm2-predictor` Service via `kubectl patch svc smollm2-predictor -n llm-serving -p '{"spec":{"type":"NodePort",...}}'`. The patch command succeeded (exit 0) but KServe's RawDeployment controller reconciled the Service back to `ClusterIP` immediately. `curl http://localhost:30202` was unreachable. This is expected KServe operator behavior — the controller owns its managed Services and continuously enforces desired state.
- **Fix:** Created `course-code/labs/lab-08/solution/k8s/25-svc-nodeport.yaml` — a separate `Service` of type `NodePort` with selector `serving.kserve.io/inferenceservice: smollm2`. This selects the predictor pods directly, bypasses the managed Service entirely, and is not touched by the KServe controller.
- **Files added:** `course-code/labs/lab-08/solution/k8s/25-svc-nodeport.yaml`, `course-code/labs/lab-08/starter/k8s/25-svc-nodeport.yaml`
- **Verification:** `curl http://localhost:30202/v1/chat/completions` returned HTTP 200 with valid chat completion JSON. Human confirmed before approving checkpoint.
- **Committed in:** `373e8ad`

---

**Total deviations:** 1 auto-fixed (Rule 2 — missing critical: correct NodePort exposure pattern)
**Impact on plan:** 25-svc-nodeport.yaml is now a permanent lab artifact. Plan 05-04 (Lab 08 doc) must:
- Add `25-svc-nodeport.yaml` as a required step after InferenceService reaches READY=True
- Remove the `kubectl patch svc smollm2-predictor` instruction
- Add a note explaining KServe controller reconciliation behavior (why separate Service is needed)

## Decision Lab Data Points (for Plan 05-04 / Lab 09)

| Metric | Pattern C (KServe) |
|--------|--------------------|
| YAML files | 3 (ClusterServingRuntime + InferenceService + NodePort Service) |
| Approximate YAML lines | ~170 (59 + 115 + ~25) |
| Scaling primitive | KServe HPA on InferenceService |
| Model source | emptyDir initContainer (same as Pattern B disk-loading) |
| Cluster overhead | cert-manager + Gateway API CRDs + KServe controller pod |
| NodePort exposure | Separate Service required — KServe manages predictor Service as ClusterIP |
| arm64 compatibility | Custom ClusterServingRuntime with schoolofdevops/vllm-cpu-nonuma:0.9.1 required |
| Probe tuning | Yes — initialDelaySeconds=90, failureThreshold=30 mandatory for CPU model load |

## Threat Surface Scan

No new network endpoints beyond plan threat model. T-05-08 (predictor on NodePort 30202) and T-05-10 (MinIO creds in cleartext initContainer command) remain accepted per plan disposition. The `smollm2-nodeport` Service exposes the same surface as the planned `smollm2-predictor` NodePort patch would have — same trust boundary, same acceptance posture.

## Known Stubs

None — all YAML solution files are complete working manifests. Starter scaffolds intentionally use empty/placeholder values at TODO locations; these are teaching stubs, not data-flow stubs.

## Self-Check: PASSED

- All 6 files exist at specified paths: VERIFIED
- solution/25-svc-nodeport.yaml: type=NodePort, selector label present, nodePort=30202: VERIFIED
- starter/25-svc-nodeport.yaml: 2 TODO markers present: VERIFIED
- Previous Task 1 self-check items (4 files): still VERIFIED (commits not reverted)
- InferenceService READY=True on live cluster: VERIFIED (human-confirmed)
- curl localhost:30202 chat completions: VERIFIED (human-confirmed)

---
*Phase: 05-kserve-inferenceservice-serving-decision-lab*
*Plan 03 completed: 2026-06-17*
