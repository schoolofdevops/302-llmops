---
phase: 03-disk-based-model-loading-minio-initcontainer
verified: 2026-06-15T18:00:00Z
status: human_needed
score: 9/9
overrides_applied: 0
human_verification:
  - test: "Docusaurus build succeeds with lab-06 sidebar entry"
    expected: "npx docusaurus build from course-content/ exits 0 with no broken-link errors for labs/lab-06-disk-model-loading"
    why_human: "Cannot run npm/Docusaurus build in this environment without starting a server process; sidebar entry path 'labs/lab-06-disk-model-loading' must resolve to the existing .md file slug"
  - test: "Windows PowerShell command variants in Lab 06 guide work as written"
    expected: "PowerShell curl (Invoke-RestMethod) and multi-line backtick continuation commands produce identical output to macOS/Linux variants; no syntax error on Windows Docker Desktop + KIND"
    why_human: "Cannot execute PowerShell commands in this environment; the guide provides Windows tab variants that require live Windows testing"
---

# Phase 03: Disk-Based Model Loading (MinIO + initContainer) — Verification Report

**Phase Goal:** Students can deploy the same fine-tuned model via runtime initContainer download from in-cluster MinIO instead of OCI ImageVolume, and choose between the two patterns based on model size and update cadence
**Verified:** 2026-06-15T18:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | MinIO is installed in `minio` namespace, accessible via NodePort 30900 (S3 API) and 30901 (console), and a one-shot `model-uploader` Job copies the merged model to `s3://models/smollm2-finetuned/` | VERIFIED | 00-namespace-minio.yaml has `name: minio`; 10-minio-values.yaml has `mode: standalone`, `nodePort: 30900`, `nodePort: 30901`; 20-job-model-uploader.yaml has complete mc retry loop, `mc mb`, `mc cp --recursive`, targeting `minio.minio:9000` (ClusterIP); orchestrator-confirmed live: MinIO pod 1/1 Running, `curl http://localhost:30900/minio/health/live` → 200, model-uploader Job Complete 1/1, 516.52 MiB uploaded |
| 2 | A `vllm-smollm2-disk` Deployment serves the model after an initContainer downloads it into a sized emptyDir (sizeLimit + matching ephemeral-storage requests + sentinel file + sha256 verification), accessible at NodePort 30203 | VERIFIED | 30-deploy-vllm-disk.yaml: initContainer `model-download` with `mc cp --recursive minio/models/smollm2-finetuned/ /model/`, sha256 verification using `cut -d' ' -f1` (not awk — Alpine-safe), `touch /model/READY` sentinel, `emptyDir sizeLimit: 1Gi`, ephemeral-storage requests/limits on both containers; 30-svc-vllm-disk.yaml: `nodePort: 30203`; orchestrator-confirmed live: pod 1/1 Running, `curl http://localhost:30203/health` → 200, `curl http://localhost:30203/v1/models` → `id: "smollm2-135m-finetuned"` |
| 3 | Student observes that pod restart re-downloads the model (deliberate emptyDir trade-off) and reads the lab-text contrast with the PVC alternative | VERIFIED | Orchestrator-confirmed live: pod delete triggered full initContainer re-run with "Downloading model..." reappearing; lab-06-disk-model-loading.md Part 4 (lines 248-289) explicitly covers emptyDir lifecycle, pod-delete exercise, and PVC alternative forward reference to Phase 06 |
| 4 | A decision-tree lab page documents when to use OCI ImageVolume (≤2GB, immutable promotion) vs disk-based (>2GB, frequent updates, object-store-backed) | VERIFIED | lab-06-disk-model-loading.md Part 5 (lines 291-316) contains 6-row comparison table (Model size, Update cadence, Registry dependency, Cold-start behavior, Credential management, Production choice) plus Choose Pattern A / Choose Pattern B bullet decision trees and closing context note |
| 5 | kind-config.yaml extraPortMappings includes 30203, 30900, and 30901 on the control-plane node | VERIFIED | solution/setup/kind-config.yaml lines 105-116 contain all three ports with `containerPort`/`hostPort`/`listenAddress: "0.0.0.0"` on control-plane only; starter/setup/kind-config.yaml confirmed via Python check — all three ports present; orchestrator-confirmed live: docker inspect shows hostPort bindings |
| 6 | Lab 06 guide exists with sidebar_position: 7 and covers all five parts | VERIFIED | course-content/docs/labs/lab-06-disk-model-loading.md: 323 lines, `sidebar_position: 7`, Day 2 header, Parts 1-5 all present, no emoji, demo-credential warning in Part 1, memory budget warning in Part 3 |
| 7 | sidebars.ts Labs category includes `labs/lab-06-disk-model-loading` after `labs/lab-05-observability` | VERIFIED | sidebars.ts line 21 (`lab-06-disk-model-loading`) confirmed after line 20 (`lab-05-observability`); Python ordering check passed |
| 8 | COURSE_VERSIONS.md has new `Object Storage (Phase 03+)` section with MinIO Helm chart row and mc image row | VERIFIED | COURSE_VERSIONS.md line 40-45: `## Object Storage (Phase 03+)` section present with `minio-official/minio 5.4.0` and `quay.io/minio/mc:RELEASE.2024-11-21T17-21-54Z` rows; `Last verified: 2026-06-15 (v1.0.0 Phase 03)` |
| 9 | Starter files exist for lab-06 with appropriate TODO blanks for pedagogical exercises | VERIFIED | All 5 starter files confirmed present (`00-namespace-minio.yaml`, `10-minio-values.yaml`, `20-job-model-uploader.yaml`, `30-deploy-vllm-disk.yaml`, `30-svc-vllm-disk.yaml`); starter uploader has TODO in mc command body; starter deploy has TODO in initContainer script body and sentinel wait loop |

**Score:** 9/9 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `course-code/labs/lab-00/solution/setup/kind-config.yaml` | Phase 03 NodePorts 30203/30900/30901 | VERIFIED | Lines 105-116 contain all three portMapping entries on control-plane node |
| `course-code/labs/lab-00/starter/setup/kind-config.yaml` | Phase 03 NodePorts 30203/30900/30901 | VERIFIED | Confirmed present via Python file scan |
| `course-code/labs/lab-06/solution/k8s/00-namespace-minio.yaml` | minio namespace | VERIFIED | `name: minio`, labels `course: llmops`, `phase: "03"` |
| `course-code/labs/lab-06/solution/k8s/10-minio-values.yaml` | MinIO Helm values standalone mode | VERIFIED | `mode: standalone`, `replicas: 1`, `nodePort: 30900`, `nodePort: 30901`, demo credential warning comment |
| `course-code/labs/lab-06/solution/k8s/20-job-model-uploader.yaml` | model-uploader Job complete | VERIFIED | mc retry loop, `mc mb --ignore-existing`, `mc cp --recursive /mnt/model/`, `minio.minio:9000` ClusterIP, no nodeName |
| `course-code/labs/lab-06/solution/k8s/30-deploy-vllm-disk.yaml` | vllm-smollm2-disk Deployment with initContainer | VERIFIED | initContainer `model-download`, sha256 verification with `cut -d' ' -f1`, sentinel `touch /model/READY`, emptyDir `sizeLimit: 1Gi`, sentinel wait loop, `--model=/model`, no nodeName |
| `course-code/labs/lab-06/solution/k8s/30-svc-vllm-disk.yaml` | NodePort 30203 Service | VERIFIED | `nodePort: 30203`, selector `app: vllm-disk` |
| `course-code/labs/lab-06/starter/k8s/` (5 files) | Starter files with pedagogical blanks | VERIFIED | All 5 files present; uploader and deploy have TODO-blanked sections |
| `course-content/docs/labs/lab-06-disk-model-loading.md` | Lab 06 guide (min 200 lines, sidebar_position: 7) | VERIFIED | 323 lines, `sidebar_position: 7` |
| `course-content/sidebars.ts` | lab-06 entry after lab-05 | VERIFIED | Line 21 after line 20, correct order confirmed |
| `course-code/COURSE_VERSIONS.md` | Object Storage section with MinIO versions | VERIFIED | New section present with both rows |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `extraPortMappings` | NodePort 30900 | KIND control-plane container bind | VERIFIED | `containerPort: 30900` present in kind-config.yaml; orchestrator-confirmed live bound |
| `extraPortMappings` | NodePort 30901 | KIND control-plane container bind | VERIFIED | `containerPort: 30901` present; orchestrator-confirmed live bound |
| `extraPortMappings` | NodePort 30203 | KIND control-plane container bind | VERIFIED | `containerPort: 30203` present; orchestrator-confirmed live bound |
| `model-uploader Job` | MinIO S3 API | `mc alias set minio http://minio.minio:9000 minio minio123` | VERIFIED | Pattern present in 20-job-model-uploader.yaml line 36; orchestrator-confirmed Job Complete 1/1 |
| `/mnt/project/training/merged-model` | `minio/models/smollm2-finetuned/` | `mc cp --recursive` | VERIFIED | Pattern present in 20-job-model-uploader.yaml line 42; 516.52 MiB upload confirmed |
| `initContainer model-download` | emptyDir `/model` | `mc cp --recursive minio/models/smollm2-finetuned/ /model/` | VERIFIED | Pattern present in 30-deploy-vllm-disk.yaml line 38; orchestrator initContainer logs confirmed |
| `vLLM main container` | `/model/READY` sentinel | `until [ -f /model/READY ]` | VERIFIED | Sentinel write `touch /model/READY` on line 47; wait loop on line 68 |
| `vllm-smollm2-disk Service` | host `localhost:30203` | NodePort 30203 | VERIFIED | `nodePort: 30203` in 30-svc-vllm-disk.yaml; orchestrator-confirmed `curl http://localhost:30203/health` → 200 |
| `sidebars.ts` | `course-content/docs/labs/lab-06-disk-model-loading.md` | Docusaurus sidebar item | VERIFIED (wiring) | File exists at exact path matching sidebar slug; Docusaurus build result needs human confirmation |

### Data-Flow Trace (Level 4)

Pattern B is infrastructure/deployment (Kubernetes manifests + lab guide), not a web app with dynamic state variables. The "data" is the model file flowing from the host through MinIO to the emptyDir. This flow was verified by the orchestrator live:

| Flow Step | Source | Destination | Produces Real Data | Status |
|-----------|--------|-------------|-------------------|--------|
| Model files on host | `/mnt/project/training/merged-model` | MinIO `minio/models/smollm2-finetuned/` | 516.52 MiB, 6 files | FLOWING |
| InitContainer download | MinIO ClusterIP | emptyDir `/model` | sha256 verified `model.safetensors` | FLOWING |
| vLLM inference | `/model` (emptyDir) | OpenAI-compat API at `:8000` | `id: "smollm2-135m-finetuned"` | FLOWING |
| emptyDir re-download | Pod restart wipes emptyDir | initContainer re-runs | Model re-downloaded | FLOWING |

### Behavioral Spot-Checks

All spot-checks based on orchestrator-confirmed live cluster facts (no server restart needed):

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| MinIO S3 API health | `curl http://localhost:30900/minio/health/live` | HTTP 200 | PASS |
| vllm-disk inference health | `curl http://localhost:30203/health` | HTTP 200 | PASS |
| Model served correctly | `curl http://localhost:30203/v1/models` | `id: "smollm2-135m-finetuned"` | PASS |
| initContainer sha256 | Pod logs: "sha256 verified. Writing sentinel." | Present | PASS |
| emptyDir re-download | Pod restart triggers initContainer re-run | "Model download complete." in new pod | PASS |
| model-uploader Job | `kubectl get jobs -n llm-app` | Complete 1/1 | PASS |

### Probe Execution

No `scripts/*/tests/probe-*.sh` files discovered. Phase does not declare probes. SKIPPED.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| PACKAGE-02 | 03-01, 03-02, 03-03, 03-04 | Pattern B — disk-based loading lab via MinIO + initContainer; emptyDir sizeLimit; ephemeral-storage requests; sentinel + sha256 | SATISFIED | All manifests created and live-verified: MinIO running, model uploaded, vllm-smollm2-disk serving at 30203, sha256 verified, emptyDir re-download confirmed |
| PACKAGE-03 | 03-04 | Comparison/decision lab page — OCI ImageVolume vs disk-based | SATISFIED | lab-06-disk-model-loading.md Part 5 contains 6-row decision table, Choose Pattern A/B bullet lists, closing context note |

**Note on REQUIREMENTS.md traceability table:** The table at the bottom of REQUIREMENTS.md still shows PACKAGE-02 and PACKAGE-03 as "Not started" (the status field was not updated after execution). Similarly, ROADMAP.md Progress table shows Phase 03 as "Not started 0/4 plans". STATE.md shows "Phase 03 PLANNED." These are tracking artifacts that need updating, but they do not affect whether the phase goal was achieved — the actual deliverables exist and are verified. This is a documentation tracking gap, not a phase delivery gap.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `.planning/REQUIREMENTS.md` | 127-128 | Status "Not started" for PACKAGE-02, PACKAGE-03 — stale | Info | Tracking-only; does not affect student-facing deliverables |
| `.planning/ROADMAP.md` | 139 | Phase 03 "Not started, 0/4 plans" — stale | Info | Tracking-only; does not affect student-facing deliverables |
| `.planning/STATE.md` | frontmatter | `completed_phases: 1`, `completed_plans: 8` — stale (Phase 03 complete) | Info | Tracking-only |

No `TBD`, `FIXME`, or `XXX` debt markers found in any solution files. No placeholder patterns found. Starter files have intentional `TODO` blanks (pedagogical design, not stubs).

### Human Verification Required

#### 1. Docusaurus Build Passes with Lab 06

**Test:** From `course-content/` directory, run `npx docusaurus build` (or `npm run build`)
**Expected:** Build exits 0. No broken-link errors. Lab 06 page renders in the built site under the Labs sidebar category as item 7 at `/labs/lab-06-disk-model-loading`
**Why human:** Cannot run npm/Docusaurus build in this verification environment without starting a long-lived process. The file path match between `sidebars.ts` item `'labs/lab-06-disk-model-loading'` and the actual file `docs/labs/lab-06-disk-model-loading.md` is structurally correct, but only a live build proves no MDX parsing errors or link resolution failures.

#### 2. Windows PowerShell Lab Commands Function

**Test:** On a Windows Docker Desktop + KIND environment, follow Lab 06 Parts 1-3 using the Windows PowerShell tab variants
**Expected:** All commands (multi-line backtick continuation, `Invoke-RestMethod` for chat completions, `Select-Object -First 1` for pod selection) execute without syntax errors and produce equivalent output to macOS/Linux variants
**Why human:** Cannot execute PowerShell on macOS. The PowerShell tab variants in the lab guide follow the same structural pattern as lab-05-observability.md (where they were previously verified), but the curl → Invoke-RestMethod translation for the chat completions request in Part 3 Step 7 includes nested JSON quoting that requires live Windows testing.

### Gaps Summary

No blocking gaps. All 9 observable truths are VERIFIED against the codebase and confirmed by orchestrator live-cluster facts. The phase goal — "students can deploy vLLM Pattern B which downloads the model from MinIO into an emptyDir at pod start, contrasting with Pattern A's OCI ImageVolume approach" — is achieved.

Two human verification items remain:
1. Docusaurus build pass (routine documentation-site check)
2. Windows PowerShell command variants (cross-platform QA)

Neither blocks the technical delivery of PACKAGE-02 or PACKAGE-03. They are standard end-of-phase QA items appropriate for human testing.

**Tracking debt (info only):** REQUIREMENTS.md, ROADMAP.md, and STATE.md need status updates to reflect Phase 03 completion. Recommend updating these as part of the next planning step or as a quick fix task.

---

_Verified: 2026-06-15T18:00:00Z_
_Verifier: Claude (gsd-verifier)_
