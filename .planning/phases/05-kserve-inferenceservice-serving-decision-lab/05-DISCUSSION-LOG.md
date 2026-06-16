# Phase 5: KServe InferenceService + Serving Decision Lab - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-16
**Phase:** 5-kserve-inferenceservice-serving-decision-lab
**Areas discussed:** vLLM serving runtime image, Model source for InferenceService, Decision lab structure, Phase 05 teardown scope

---

## vLLM Serving Runtime Image

| Option | Description | Selected |
|--------|-------------|----------|
| schoolofdevops/vllm-cpu-nonuma:0.9.1 | Already verified on KIND arm64 Phase 04. Cached on cluster. No extra pull step. | ✓ |
| vllm/vllm-openai-cpu (upstream) | Matches ROADMAP spec. Requires arm64 pre-pull workaround. Unverified. | |

**User's choice:** `schoolofdevops/vllm-cpu-nonuma:0.9.1`
**Notes:** User confirmed this is "a stripped down version of image" — the stripped-down nature means it does NOT support KServe's storage initializer sidecar. This decision cascades to the model source choice. CPU env-var set from Phase 04 (VLLM_TARGET_DEVICE=cpu, VLLM_CPU_KVCACHE_SPACE=2, OMP_NUM_THREADS=4) carries forward into ClusterServingRuntime.

---

## Model Source for InferenceService

| Option | Description | Selected |
|--------|-------------|----------|
| MinIO S3 via KServe storage initializer | storageUri: s3://... Reuses Phase 03 MinIO. Teaches KServe native storage. Requires S3 creds + ServiceAccount. | |
| emptyDir initContainer | mc cp from MinIO into emptyDir, same as Phase 03/04. Familiar pattern. | ✓ |
| OCI ImageVolume from Phase 03 | storageUri pointing to OCI image from Lab 03. No creds needed. | |

**User's choice:** emptyDir initContainer
**Notes:** Confirmed by the stripped-down image note — the image doesn't support KServe's storage initializer. Disable storage initializer via `serving.kserve.io/enable-storage-initialization: "false"` annotation. User also mentioned: "we also want to use kserve with minimal resources like original program" — resource requests should be lean.

---

## Decision Lab Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Separate page (Lab 08 + Lab 09) | KServe lab separate from decision comparison page. Clean navigation. | ✓ |
| Combined in Lab 08 | KServe install + decision table in one page. Shorter nav but long page. | |

**Content depth chosen:**

| Option | Description | Selected |
|--------|-------------|----------|
| Comparison table + decision tree | Lines of YAML, scaling primitive, storage, cluster overhead, decision tree. | ✓ |
| Table + tree + latency/resource benchmarks | Adds actual kubectl top / load test numbers. | |

**User's choice:** Separate pages, table + tree only (no benchmarks)
**Notes:** Lab 09 should feel like a reference card students can bookmark. Grounded in labs 04, 07, 08.

---

## Phase 05 Teardown Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Full KServe teardown, restore Pattern A | Uninstall KServe + cert-manager + Gateway API. Restore vllm-smollm2 to replicas=1. Phase 06 starts fresh. | ✓ |
| Leave KServe running for Phase 06 | Skip teardown. Phase 06 OPS-01 validates against live KServe. Saves reinstall time. | |

**User's choice:** Full teardown, restore Pattern A
**Notes:** Consistent with Phase 04 approach. Phase 06 will reinstall what it needs.

---

## Claude's Discretion

- Exact Helm chart names/repos for cert-manager v1.16.x, Gateway API v1.2.1, KServe v0.18.0 OCI chart
- ClusterServingRuntime vs namespace-scoped ServingRuntime — whichever is simpler for lab
- Exact InferenceService YAML structure for RawDeployment with custom runtime + disabled storage initializer
- Whether NodePort 30202 is exposed via KServe-managed Service or requires manual patch

## Deferred Ideas

- KServe + MinIO S3 via storage initializer (stripped-down image blocks this; teach in v1.1 if a full image is used)
- Latency/resource benchmarks across three patterns (requires simultaneous deployment; exceeds 16GB budget)
- KServe KEDA autoscaling — Phase 06 OPS-01
