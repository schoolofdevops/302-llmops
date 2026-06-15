---
phase: 03-disk-based-model-loading-minio-initcontainer
plan: "03"
subsystem: lab-06-manifests
tags: [vllm, initcontainer, emptydir, minio, pattern-b, disk-based, nodeport, sha256, sentinel]
dependency_graph:
  requires: ["03-02"]
  provides: ["lab-06/solution/k8s/30-deploy-vllm-disk.yaml", "lab-06/solution/k8s/30-svc-vllm-disk.yaml", "lab-06/starter/k8s/30-deploy-vllm-disk.yaml", "lab-06/starter/k8s/30-svc-vllm-disk.yaml"]
  affects: ["llm-serving namespace", "NodePort 30203", "lab-06 guide", "phase-04-router"]
tech_stack:
  added:
    - "quay.io/minio/mc:RELEASE.2024-11-21T17-21-54Z — initContainer image for model download"
    - "Kubernetes emptyDir volume with sizeLimit for ephemeral model storage"
    - "sha256sum verification in initContainer shell script (sentinel-gated)"
  patterns:
    - "initContainer + emptyDir model download with sha256 verification and sentinel gate"
    - "Shell sentinel-wait loop in main container (until [ -f /model/READY ])"
    - "emptyDir sizeLimit: 1Gi with ephemeral-storage requests/limits on both containers"
    - "cut -d' ' -f1 for sha256sum parsing (awk absent in mc Alpine image)"
    - "Memory budget gate: scale Pattern A to 0 before deploying Pattern B"
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
  - "nodeName removed from Pattern B Deployment — emptyDir + MinIO ClusterIP requires no node pin unlike Pattern A hostPath"
  - "sha256 parsing uses cut -d' ' -f1 not awk — mc image lacks awk; cut is POSIX and always present"
metrics:
  duration: "~45 minutes"
  completed: "2026-06-15"
  tasks_completed: 2
  tasks_total: 2
  files_created: 4
  files_modified: 0
---

# Phase 03 Plan 03: vllm-smollm2-disk Deployment and Service Manifests Summary

**One-liner:** Pattern B vllm-smollm2-disk with MinIO initContainer, sha256-gated sentinel, and emptyDir re-download teaching moment fully deployed and verified at NodePort 30203.

## Accomplishments

- Created four Kubernetes manifest files (solution + starter) for Pattern B vLLM disk-based deployment using MinIO initContainer
- Deployed vllm-smollm2-disk to llm-serving namespace; initContainer downloaded 6 files (516.52 MiB at 313 MiB/s), verified sha256 (4a946ea7...), wrote /model/READY sentinel, vLLM started and served at NodePort 30203
- Confirmed emptyDir re-download teaching moment: pod delete triggered full initContainer re-run on replacement pod; demonstrates emptyDir trade-off vs OCI ImageVolume

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

## Task Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create vllm-smollm2-disk Deployment and Service manifests (solution + starter) | 3cb4071 | 4 files created |
| 2 | Deploy Pattern B vLLM, verify initContainer flow, observe emptyDir re-download | checkpoint:human-verify — approved | cluster verification |

**Orchestrator fix commits:** cb87449 (removed nodeName), b4fc8d6 (awk → cut)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed spurious nodeName: llmops-kind-worker from Pattern B Deployment**
- **Found during:** Task 2 (deployment verification by orchestrator)
- **Issue:** Executor generated `nodeName: llmops-kind-worker` in the Deployment spec. Pattern B uses emptyDir + MinIO ClusterIP and has no dependency on a specific node. The pin was copied from Pattern A context but is semantically incorrect for Pattern B (Pattern A needed it for hostPath bind-mount; Pattern B does not).
- **Fix:** nodeName field removed from spec.template.spec by orchestrator.
- **Files modified:** course-code/labs/lab-06/solution/k8s/30-deploy-vllm-disk.yaml
- **Verification:** Pod scheduled successfully without node pin; rollout completed.
- **Committed in:** cb87449 (orchestrator fix commit)

**2. [Rule 1 - Bug] Replaced awk with cut for sha256sum output parsing in initContainer script**
- **Found during:** Task 2 (initContainer log observation)
- **Issue:** initContainer script used `sha256sum /model/model.safetensors | awk '{print $1}'` to extract the hash. The quay.io/minio/mc image (Alpine-based) does not ship awk, causing the sha256 verification step to fail.
- **Fix:** Changed to `sha256sum /model/model.safetensors | cut -d' ' -f1`. cut is POSIX-standard and present in all Alpine-based images.
- **Files modified:** course-code/labs/lab-06/solution/k8s/30-deploy-vllm-disk.yaml
- **Verification:** initContainer logs showed "sha256 verified. Writing sentinel..." after fix.
- **Committed in:** b4fc8d6 (orchestrator fix commit)

---

**Total deviations:** 2 auto-fixed (2 Rule 1 bugs from manifest generation)
**Impact on plan:** Both fixes corrected manifest correctness issues discovered during live deployment. No scope creep. Plan intent fully delivered.

## Verification Results (Task 2)

All acceptance criteria met per orchestrator sign-off:

- Pattern A (vllm-smollm2) scaled to 0 before Pattern B deployment (memory budget respected)
- initContainer logs confirmed: "Downloading model from MinIO..." (6 files, 516.52 MiB at 313 MiB/s) → "sha256 verified. Writing sentinel..." → "Model download complete."
- `kubectl rollout status deployment/vllm-smollm2-disk -n llm-serving` → successfully rolled out
- `curl http://localhost:30203/health` → HTTP 200
- `curl http://localhost:30203/v1/models` → JSON with id: "smollm2-135m-finetuned"
- Pod deleted → replacement pod initContainer immediately started re-downloading (emptyDir ephemeral lifecycle confirmed as teaching moment)

## Threat Surface Scan

No new security surface introduced beyond what is documented in the plan's threat model:
- T-03-05 mitigated: sha256 verification before sentinel write ensures integrity
- T-03-06 accepted: minio/minio123 credentials in manifest — course-grade, lab text must note demo-grade
- T-03-07 mitigated: sizeLimit:1Gi + ephemeral-storage requests/limits on both containers
- T-03-SC mitigated: quay.io/minio/mc pinned to exact dated tag (RELEASE.2024-11-21T17-21-54Z)

## Known Stubs

None. The manifests are complete and deployable for the solution. The starter intentionally blanks the initContainer script and sentinel loop for pedagogical purposes — this is by design, not a stub that blocks functionality.

## Next Phase Readiness

- Pattern B (disk-based loading via MinIO initContainer) fully operational at NodePort 30203
- Both solution/ and starter/ manifests committed; starter/ has script bodies blanked for lab exercise
- emptyDir trade-off vs OCI ImageVolume demonstrated; ready to be documented in Lab 06 guide
- Phase 03 plan 04 (lab guide authoring for Lab 06) can proceed using these manifests as verified reference
- Pattern A should be scaled back to 1 replica after Pattern B demo: `kubectl scale deployment vllm-smollm2 -n llm-serving --replicas=1`

## Self-Check: PASSED

Files exist:
- FOUND: course-code/labs/lab-06/solution/k8s/30-deploy-vllm-disk.yaml
- FOUND: course-code/labs/lab-06/solution/k8s/30-svc-vllm-disk.yaml
- FOUND: course-code/labs/lab-06/starter/k8s/30-deploy-vllm-disk.yaml
- FOUND: course-code/labs/lab-06/starter/k8s/30-svc-vllm-disk.yaml

Commits verified: 3cb4071 (feat — Task 1), cb87449 (fix — nodeName removal), b4fc8d6 (fix — awk→cut)
