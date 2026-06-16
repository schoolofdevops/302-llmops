# Phase 5: KServe InferenceService + Serving Decision Lab - Context

**Gathered:** 2026-06-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Deploy the same fine-tuned smollm2-135m model via KServe `InferenceService` (Standard/RawDeployment mode, no Knative, no Istio) on the existing KIND cluster. Then publish a standalone serving-decision lab page comparing all three serving patterns (plain Deployment, vLLM Router, KServe) with a decision tree.

Phase delivers:
- Lab 08: KServe InferenceService install + deploy + verify (NodePort 30202)
- Lab 09: Serving Decision Lab (comparison table + decision tree, separate page)
- Teardown: full KServe uninstall + Pattern A restore

Out of scope: autoscaling (Phase 06), GitOps (Phase 06), latency/resource benchmarks.

</domain>

<decisions>
## Implementation Decisions

### Serving Runtime Image
- **D-01:** Use `schoolofdevops/vllm-cpu-nonuma:0.9.1` in the `ClusterServingRuntime` — already verified on KIND arm64 in Phase 04, already cached on the cluster. Do NOT use upstream `vllm/vllm-openai-cpu` (unverified on arm64, extra pull step). Note in lab guide that this is a stripped-down CPU-only image.
- **D-02:** ClusterServingRuntime container args/env must include the full Phase 04 CPU tuning set: `--disable-frontend-multiprocessing`, `VLLM_TARGET_DEVICE=cpu`, `VLLM_CPU_KVCACHE_SPACE=2`, `OMP_NUM_THREADS=4`, `VLLM_CPU_OMP_THREADS_BIND=auto`. Confirmed stable on KIND from Phase 04.
- **D-03:** Resource requests for the InferenceService predictor should be minimal — same lean footprint as the original program. The KIND cluster is 16GB RAM; KServe control-plane already consumes ~1GB. Keep predictor requests at 4 CPU / 4Gi RAM (same as Phase 04 backends) but document that students may need to adjust based on available headroom.

### Model Source
- **D-04:** Model is loaded via an **emptyDir initContainer** (mc cp from MinIO at `minio.minio:9000`, bucket `models/smollm2-finetuned/`) — same pattern as Phase 03/04. The `schoolofdevops/vllm-cpu-nonuma:0.9.1` image is stripped down and does not support KServe's storage initializer sidecar.
- **D-05:** Disable KServe's storage initializer on the InferenceService via annotation: `serving.kserve.io/enable-storage-initialization: "false"`. This prevents an unwanted storage-initializer sidecar from being injected.
- **D-06:** The InferenceService `storageUri` field can be omitted (or set to a local path like `/mnt/model`) since the initContainer downloads the model to an emptyDir volume mounted at `/mnt/model` before the predictor container starts.

### Lab Structure
- **D-07:** Two separate pages: **Lab 08** = KServe InferenceService (install + runtime + InferenceService + verify), **Lab 09** = Serving Decision Lab (comparison table + decision tree). Separate pages allow students to reference the decision page independently.
- **D-08:** Lab 09 decision page content: side-by-side comparison table (lines of YAML, scaling primitive, storage approach, cluster overhead/RAM footprint, complexity), plus a decision tree for choosing plain Deployment vs vLLM Router vs KServe. Validated against students' actual experience from Labs 04, 07, 08. No latency/resource benchmarks.

### KServe Installation
- **D-09:** Install order: cert-manager v1.16.x first, then Gateway API CRDs v1.2.1, then KServe v0.18.0 via OCI Helm chart in `kserve` namespace with `deploymentMode=Standard`. Knative and Istio must NOT be installed.
- **D-10:** ARM64 callout required in Lab 08: built-in `kserve-huggingfaceserver` image is amd64-only at v0.18 — the custom ClusterServingRuntime with `schoolofdevops/vllm-cpu-nonuma:0.9.1` is the arm64-tolerant path for this lab.
- **D-11:** Probe tuning in InferenceService predictor spec: `initialDelaySeconds: 90`, `failureThreshold: 30` (matches ROADMAP Pitfall 11 note — prevents crashloop on CPU model load startup).

### NodePort
- **D-12:** InferenceService served at NodePort 30202 (already reserved in kind-config.yaml from Phase 04 gap-fix). No cluster recreation needed for this phase.

### Teardown
- **D-13:** Full teardown at end of Lab 08: uninstall KServe Helm release, delete cert-manager CRDs and Gateway API CRDs, restore `vllm-smollm2` (Pattern A) to `replicas=1`. Phase 06 installs whatever it needs fresh.

### Claude's Discretion
- Exact Helm chart names/repos for cert-manager, Gateway API, KServe OCI chart — researcher to identify current stable sources for v1.16.x, v1.2.1, v0.18.0.
- Whether a `ClusterServingRuntime` or namespace-scoped `ServingRuntime` is preferable for lab simplicity.
- Exact `InferenceService` YAML structure (containers override vs modelFormat vs storageUri pattern for RawDeployment with custom runtime).
- Whether the InferenceService exposes via a Service of type NodePort directly or requires a manual Service patch (KServe Standard mode behavior with `deploymentMode=RawDeployment`).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Requirements
- `.planning/REQUIREMENTS.md` — SERVE-02 (KServe lab), SERVE-04 (decision lab)
- `.planning/ROADMAP.md` §Phase 05 — goal, success criteria, pitfall notes

### Prior Phase Context (what's already deployed)
- `course-code/labs/lab-07/solution/k8s/00-values-vllm-router.yaml` — Phase 04 CPU tuning values (D-02 env vars reference)
- `course-code/labs/lab-06/solution/k8s/` — disk-loading pattern, emptyDir initContainer (D-04 pattern reference)

### Existing Lab Guides (structural reference)
- `course-content/docs/labs/lab-07-vllm-router.md` — Lab 07 structure: ARM64 callout format, details block for solution values, session demo tabs format. Use as template for Lab 08.
- `course-content/sidebars.ts` — must add Lab 08 and Lab 09 entries

### Course Infrastructure
- `course-code/COURSE_VERSIONS.md` — must update with cert-manager, Gateway API, KServe versions
- `course-code/labs/lab-00/solution/setup/kind-config.yaml` — NodePort 30202 already present (from Phase 04 gap-fix GAP-3 fix); verify before planning

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `course-code/labs/lab-06/solution/k8s/` — emptyDir initContainer pattern (mc cp from MinIO) directly reusable in InferenceService predictor pod spec
- `course-code/labs/lab-07/solution/k8s/00-values-vllm-router.yaml` — CPU env-var set (VLLM_TARGET_DEVICE, VLLM_CPU_KVCACHE_SPACE, OMP_NUM_THREADS) to copy into ClusterServingRuntime

### Established Patterns
- ARM64 image pre-pull: `docker pull --platform linux/amd64 ... && docker tag ... kind-registry:5001/... && docker push ...` — used in Phase 04 for lmstack-router; may apply if any KServe controller images are amd64-only
- Lab guide structure: Prerequisites callout → Architecture → Install steps → Verify → Teardown → Troubleshooting (see lab-07-vllm-router.md)
- `<details>` block for solution YAML, starter scaffold in main body

### Integration Points
- `course-content/sidebars.ts` — add `labs/lab-08-kserve-inferenceservice` and `labs/lab-09-serving-decision`
- `course-code/labs/lab-08/` and `lab-09/` directories to create (solution/ + starter/)
- NodePort 30202 already mapped in kind-config.yaml

</code_context>

<specifics>
## Specific Ideas

- "Minimal resources like original program" — KServe control-plane components (controller, webhook) should use lean resource requests; do not over-provision. Keep predictor at same size as Phase 04 backends (4 CPU / 4Gi RAM).
- The decision lab (Lab 09) should feel like a reference card students can bookmark — clean table, clear decision tree, grounded in the labs they just completed (not abstract theory).

</specifics>

<deferred>
## Deferred Ideas

- Latency/resource benchmarks across three patterns — deferred; would require all three patterns running simultaneously which doesn't fit 16GB RAM budget.
- KServe KEDA autoscaling integration — deferred to Phase 06 (OPS-01 validates all three patterns).
- KServe with MinIO S3 via storage initializer (S3 creds + ServiceAccount annotation) — deferred; stripped-down image doesn't support it, and emptyDir pattern is simpler for lab.

</deferred>

---

*Phase: 5-kserve-inferenceservice-serving-decision-lab*
*Context gathered: 2026-06-16*
