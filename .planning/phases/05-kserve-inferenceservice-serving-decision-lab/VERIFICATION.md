---
phase: 05-kserve-inferenceservice-serving-decision-lab
status: pass
verified_at: "2026-06-17"
verifier: gsd-executor (Plan 05-04)
---

# Phase 05 Verification — KServe InferenceService + Serving Decision Lab

**Verified:** 2026-06-17
**Requirements:** SERVE-02, SERVE-04

## Phase Goal

Install KServe v0.18.0 in RawDeployment mode on a KIND cluster, deploy the fine-tuned SmolLM2-135M model via a custom ClusterServingRuntime + InferenceService, expose it at NodePort 30202, then publish Lab 08 (student guide) and Lab 09 (serving-decision reference page). Teardown KServe stack and restore Pattern A for Phase 06.

## Success Criteria Checklist

| SC# | Criterion | Status | Evidence |
|-----|-----------|--------|----------|
| SC-1 | cert-manager v1.16.5 + Gateway API CRDs v1.2.1 + KServe v0.18.0 installed in `kserve` namespace with `deploymentMode=RawDeployment`; Knative + Istio absent | PASS | `helm list -A` from Plan 05-02 showed `cert-manager-v1.16.5` (cert-manager namespace), `kserve-crd-v0.18.0` + `kserve-resources-v0.18.0` (kserve namespace), STATUS=deployed. No knative-serving namespace, no istio-system namespace. `inferenceservice-config` ConfigMap patched with `disableIngressCreation: true` + `disableIstioVirtualHost: true`. |
| SC-2 | Custom CPU ClusterServingRuntime registered; InferenceService `smollm2` reached READY=True; accessible at NodePort 30202 | PASS | Plan 05-03: `kubectl get inferenceservice smollm2 -n llm-serving` returned `READY=True`. Separate `smollm2-nodeport` Service on NodePort 30202 (separate Service required — KServe controller continuously reconciles managed predictor Service to ClusterIP). `curl http://localhost:30202/v1/chat/completions` returned HTTP 200 with valid chat completion (human-confirmed at Plan 05-03 checkpoint). |
| SC-3 | Predictor readiness probe tuned for CPU model load (initialDelaySeconds>=90, failureThreshold>=30); pod did not crashloop on first start | PASS | Plan 05-03: InferenceService YAML at `course-code/labs/lab-08/solution/k8s/20-inferenceservice.yaml` sets `initialDelaySeconds: 90`, `failureThreshold: 30` (390s total budget). Pod reached `1/1 Running` (restart count=0 — no crashloop). Model load time was within the 390s budget. |
| SC-4 | Lab 09 publishes side-by-side comparison table + decision tree for plain vs router vs KServe | PASS | `course-content/docs/labs/lab-09-serving-decision.md` created. Contains Markdown table with Pattern A / Pattern C / Pattern B columns (8 dimensions), ASCII decision tree, and When-to-Use sections for each pattern with links to Lab 04, Lab 07, Lab 08. Docusaurus build passes with `onBrokenLinks: throw`. |
| SC-5 | Lab 08 calls out arm64-on-Mac as a known gate; custom CPU runtime as arm64-tolerant path | PASS | `course-content/docs/labs/lab-08-kserve-inferenceservice.md` contains `:::caution Apple Silicon (arm64) — Read before proceeding` callout explaining `kserve-huggingfaceserver` is amd64-only at v0.18; custom ClusterServingRuntime with `schoolofdevops/vllm-cpu-nonuma:0.9.1` is the arm64-tolerant path. `rg "Apple Silicon" course-content/docs/labs/lab-08-kserve-inferenceservice.md` returns match. |

## Deviations from Plan

| Plan Assumption | Actual | Resolution |
|----------------|--------|------------|
| D-09 (CONTEXT.md): `deploymentMode=Standard` | Installed `deploymentMode=RawDeployment` via Helm flag; `deploymentMode=Standard` would create HTTPRoutes that never reconcile on KIND (no Envoy Gateway controller). RawDeployment is the correct KIND interpretation — confirmed in RESEARCH.md Anti-Patterns + Pitfall 2. InferenceService also carries per-resource annotation `serving.kserve.io/deploymentMode: RawDeployment` as belt-and-suspenders. | Fixed in Plan 05-02 — documented as Rule 1 deviation (wrong behavior if Standard was used: READY would block forever). |
| NodePort 30202 present in kind-config.yaml (CONTEXT.md claim) | 30202 was ABSENT from both solution and starter kind-config.yaml files. Phase 04 GAP-3 only added 30201 (solution only). 30202 was never added. | Fixed in Plan 05-01 (GAP-4): added 30202 to both solution and starter kind-config.yaml, recreated cluster, redeployed Phase 02/03 stack. |
| Open Question 1 (RESEARCH.md): `spec.predictor.initContainers` field existence | CONFIRMED WORKING on live KServe v0.18 cluster. `spec.predictor.initContainers` and `spec.predictor.volumes` are accepted by the KServe v1beta1 InferenceService CRD. The `podSpec` wrapper is NOT required. Field path used: `spec.predictor.initContainers` + `spec.predictor.volumes`. | Resolved in Plan 05-03 (dry-run + live apply confirmed). |
| D-05 annotation (`serving.kserve.io/enable-storage-initialization: "false"`) prevents storage-initializer injection | Primary defense is `spec.predictor.containers` (no `storageUri` → webhook has nothing to act on). The annotation is belt-and-suspenders. In our solution the annotation is present AND `spec.predictor.containers` is used — verified only 1 initContainer (`model-download`) was injected, confirming the combined defense worked. | Both defenses in solution YAML. Primary = spec.predictor.containers pattern; annotation added as belt-and-suspenders per Plan 05-03 YAML. |
| RESEARCH.md NodePort pattern: `kubectl patch svc smollm2-predictor` to NodePort | KServe RawDeployment controller continuously reconciles the managed `smollm2-predictor` Service back to ClusterIP. `kubectl patch` succeeds momentarily but is immediately reverted. | Fixed in Plan 05-03 (Rule 2 auto-fix): created separate `smollm2-nodeport` Service with selector `serving.kserve.io/inferenceservice: smollm2`. This selects predictor pods directly without coupling to the managed Service. |
| ConfigMap patch format (Plan 05-02): minimal `disableIngressCreation: true` only | KServe controller startup validates that `ingressGateway` field is present in the ingress config. Minimal patch omitting `ingressGateway` crashed the controller. Full JSON patch preserving all required fields was required. | Fixed in Plan 05-02 (Rule 1 auto-fix): full JSON ingress config patch with all required fields preserved. |

## Resource Budget

Observed from Plan 05-02/05-03 (kubectl describe nodes — metrics-server not available on this KIND cluster):

| Node | Memory Requests (post-KServe install) | Memory Requests (post-teardown) |
|------|--------------------------------------|---------------------------------|
| control-plane | ~290 Mi (~2%) | ~250 Mi (~2%) |
| worker | ~650 Mi (~6%) | ~300 Mi (~3%) |
| worker2 | ~818 Mi (~8%) | ~400 Mi (~4%) |

**KServe control-plane incremental footprint (cert-manager + controller):** ~700 Mi memory requests (~4 pods: cert-manager, cainjector, cert-manager-webhook, kserve-controller-manager).

**Predictor pod:** 4 Gi memory requests (same as Pattern A and Pattern B backends).

**Post-teardown headroom:** All KServe/cert-manager pods removed. kserve + cert-manager namespaces deleted. Helm releases removed. `vllm-smollm2` restored to 1 replica, `1/1 Running`. Pattern A serving at NodePort 30200 (verified: `curl` returns valid chat completion).

## Phase 05 Artifacts

All artifacts created or updated in Phase 05:

| Artifact | Phase/Plan | Status |
|----------|-----------|--------|
| `course-code/labs/lab-00/solution/setup/kind-config.yaml` | 05-01 | Updated (added 30202) |
| `course-code/labs/lab-00/starter/setup/kind-config.yaml` | 05-01 | Updated (added 30201 + 30202) |
| `course-code/labs/lab-08/solution/k8s/10-clusterservingruntime.yaml` | 05-03 | Created |
| `course-code/labs/lab-08/solution/k8s/20-inferenceservice.yaml` | 05-03 | Created |
| `course-code/labs/lab-08/solution/k8s/25-svc-nodeport.yaml` | 05-03 | Created |
| `course-code/labs/lab-08/starter/k8s/10-clusterservingruntime.yaml` | 05-03 | Created |
| `course-code/labs/lab-08/starter/k8s/20-inferenceservice.yaml` | 05-03 | Created |
| `course-code/labs/lab-08/starter/k8s/25-svc-nodeport.yaml` | 05-03 | Created |
| `course-content/docs/labs/lab-08-kserve-inferenceservice.md` | 05-04 | Created |
| `course-content/docs/labs/lab-09-serving-decision.md` | 05-04 | Created |
| `course-content/sidebars.ts` | 05-04 | Updated (lab-08 + lab-09 entries) |
| `course-code/COURSE_VERSIONS.md` | 05-04 | Updated (cert-manager, Gateway API, KServe rows) |

## Teardown Evidence (D-13)

All steps executed in Plan 05-04 Task 2:

```
kubectl delete inferenceservice smollm2 -n llm-serving → deleted
kubectl delete svc smollm2-nodeport -n llm-serving → deleted
kubectl delete clusterservingruntime vllm-cpu-smollm2 → deleted
helm uninstall kserve -n kserve → release "kserve" uninstalled
helm uninstall kserve-crd -n kserve → release "kserve-crd" uninstalled
kubectl delete -f .../standard-install.yaml → 5 Gateway API CRDs deleted
helm uninstall cert-manager -n cert-manager → release "cert-manager" uninstalled
kubectl delete ns kserve cert-manager → both namespaces deleted

kubectl scale deployment vllm-smollm2 -n llm-serving --replicas=1 → scaled
kubectl rollout status deployment/vllm-smollm2 → successfully rolled out
curl http://localhost:30200/v1/chat/completions → PASS (valid chat completion)
```

Post-teardown cluster state:
- `helm list -A` shows only `minio` (no kserve, kserve-crd, cert-manager)
- `kubectl get ns` shows no kserve or cert-manager namespaces
- `kubectl get deployment vllm-smollm2 -n llm-serving` → DESIRED=1, READY=1
- KServe/cert-manager pods remaining: 0

## Verdict: PASS

Phase 05 goals fully achieved. KServe InferenceService READY=True on live cluster. Lab 08 guide written covering all 8 pitfalls. Lab 09 decision page with comparison table and decision tree published. Docusaurus build passes. KServe stack torn down cleanly. Pattern A restored and serving. Cluster ready for Phase 06.
