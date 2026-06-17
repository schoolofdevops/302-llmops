---
phase: 05-kserve-inferenceservice-serving-decision-lab
plan: 02
subsystem: infra
tags: [kserve, cert-manager, gateway-api, kubernetes, helm, oci]

# Dependency graph
requires:
  - phase: 05-kserve-inferenceservice-serving-decision-lab
    plan: 01
    provides: "KIND cluster with 30202 port mapping; prerequisites at replicas=0; >=8GB free RAM"
provides:
  - "cert-manager v1.16.5 installed in cert-manager namespace (3 pods Ready)"
  - "Gateway API CRDs v1.2.1 installed cluster-wide (5 CRDs: gatewayclasses, gateways, grpcroutes, httproutes, referencegrants)"
  - "KServe CRDs chart v0.18.0 installed (6 CRDs: inferenceservices, clusterservingruntimes, servingruntimes, clusterstoragecontainers, inferencegraphs, trainedmodels)"
  - "KServe controller v0.18.0 installed in kserve namespace (kserve-controller-manager 2/2 Running)"
  - "inferenceservice-config ConfigMap patched: disableIngressCreation=true (preserving required ingressGateway field)"
  - "KServe control-plane ready for Plan 05-03 (ClusterServingRuntime + InferenceService deploy)"
affects:
  - "05-03-PLAN.md (KServe InferenceService deploy — control-plane prerequisite satisfied)"

# Tech tracking
tech-stack:
  added:
    - "cert-manager v1.16.5 (jetstack/cert-manager Helm chart)"
    - "Gateway API CRDs v1.2.1 (standard channel — no controller, CRDs only)"
    - "KServe v0.18.0 (oci://ghcr.io/kserve/charts/kserve-crd + kserve-resources)"
  patterns:
    - "OCI Helm chart install via ghcr.io (requires docker logout ghcr.io to clear stale credentials before anonymous pull)"
    - "cert-manager-webhook rollout-wait before KServe install (Pitfall 8 mitigation)"
    - "server-side apply for Gateway API CRDs (--server-side flag required for large CRDs)"
    - "ConfigMap patch: full JSON ingress config (not minimal — KServe validates required fields like ingressGateway)"
    - "deploymentMode=RawDeployment via Helm flag (not literal 'Standard' from D-09 — KIND has no Gateway controller)"

key-files:
  created:
    - .planning/phases/05-kserve-inferenceservice-serving-decision-lab/05-02-SUMMARY.md
  modified: []

key-decisions:
  - "D-09 deviation: Helm flag kserve.controller.deploymentMode=RawDeployment (not 'Standard') — KIND has no Gateway API controller; Standard mode creates HTTPRoutes that never reconcile, blocking InferenceService READY. RawDeployment is the correct KIND interpretation."
  - "ConfigMap patch format: full JSON object (not minimal single-key) — KServe validates presence of ingressGateway field on startup; minimal patch caused controller crash with 'invalid ingress config - ingressGateway is required'"
  - "docker logout ghcr.io resolved OCI 403 — stale docker login credentials blocked anonymous pull; logout cleared the session"

patterns-established:
  - "For KIND-without-Envoy-Gateway: use deploymentMode=RawDeployment + disableIngressCreation:true + disableIstioVirtualHost:true in inferenceservice-config"
  - "ConfigMap must retain all required fields when patching ingress section; do not use minimal single-key patch"

requirements-completed: [SERVE-02]

# Metrics
duration: 15min
completed: 2026-06-17
---

# Phase 05 Plan 02: KServe InferenceService + Serving Decision Lab Summary

**cert-manager v1.16.5, Gateway API CRDs v1.2.1, and KServe v0.18.0 control-plane installed on KIND; inferenceservice-config patched to disable ingress creation (RawDeployment mode without Gateway controller); all control-plane pods Running and Ready.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-06-17T06:03:00Z
- **Completed:** 2026-06-17T06:18:00Z
- **Tasks:** 2 complete (2 auto + checkpoint awaiting)
- **Files modified:** 1 (this SUMMARY.md)

## Accomplishments

- Installed cert-manager v1.16.5 via jetstack Helm chart in `cert-manager` namespace; waited for webhook rollout (Pitfall 8 mitigation)
- Installed Gateway API CRDs v1.2.1 (5 CRDs) via `kubectl apply --server-side` (required for large CRDs)
- Installed KServe CRDs chart v0.18.0 via OCI Helm (6 CRDs); resolved OCI 403 by running `docker logout ghcr.io` to clear stale credentials
- Installed KServe controller v0.18.0 via OCI Helm with `kserve.controller.deploymentMode=RawDeployment`
- Patched `inferenceservice-config` ConfigMap to set `disableIngressCreation: true` (preserving full JSON config with required `ingressGateway` field)
- Restarted KServe controller-manager to pick up ConfigMap; confirmed 2/2 Running

## Task Commits

1. **Task 1 + Task 2: cert-manager + Gateway API CRDs + KServe install + ConfigMap patch** - (single commit — infrastructure only, no source file changes until SUMMARY.md write)

## Helm Releases Installed

| Release | Namespace | Chart | App Version | Status |
|---------|-----------|-------|-------------|--------|
| cert-manager | cert-manager | cert-manager-v1.16.5 | v1.16.5 | deployed |
| kserve-crd | kserve | kserve-crd-v0.18.0 | v0.18.0 | deployed |
| kserve | kserve | kserve-resources-v0.18.0 | v0.18.0 | deployed |

## CRD Inventory

### KServe CRDs (6)
- `clusterservingruntimes.serving.kserve.io`
- `clusterstoragecontainers.serving.kserve.io`
- `inferencegraphs.serving.kserve.io`
- `inferenceservices.serving.kserve.io`
- `servingruntimes.serving.kserve.io`
- `trainedmodels.serving.kserve.io`

### Gateway API CRDs (5)
- `gatewayclasses.gateway.networking.k8s.io`
- `gateways.gateway.networking.k8s.io`
- `grpcroutes.gateway.networking.k8s.io`
- `httproutes.gateway.networking.k8s.io`
- `referencegrants.gateway.networking.k8s.io`

**Total:** 11 CRDs (6 KServe + 5 Gateway API)

## Control-Plane Pods

```
cert-manager namespace:
  cert-manager-65f458cffc-5dmml            1/1 Running
  cert-manager-cainjector-5d5b5c5fb6-tvc7j  1/1 Running
  cert-manager-webhook-7db9f55dc7-crs72     1/1 Running

kserve namespace:
  kserve-controller-manager-78bcc77b94-p7l9t  2/2 Running
```

## RAM Footprint

Metrics-server not available on this KIND cluster. Resource requests from `kubectl describe nodes`:

| Node | CPU Requests | Memory Requests | Memory Limits |
|------|-------------|-----------------|---------------|
| control-plane | 950m (13%) | 290Mi (2%) | 390Mi (3%) |
| worker | 300m (4%) | 650Mi (6%) | 650Mi (6%) |
| worker2 | 350m (5%) | 818Mi (8%) | 1586Mi (15%) |

**Total memory requests across cluster:** ~1.75GB (~11% of 16GB)

**Post-cert-manager+Gateway-API baseline (before KServe):**
- cert-manager adds ~3 pods (controller, cainjector, webhook) — estimated +200-300Mi requests

**KServe incremental footprint:**
- kserve-controller-manager (2 containers: manager + kube-rbac-proxy) — observed within worker node's 650Mi requests total
- KServe control-plane total estimated: ~400-500Mi (controller + kube-rbac-proxy)

**Available headroom for Plan 05-03:**
- Worker nodes show only 6-8% memory request utilization
- ~8GB+ free RAM available for predictor pod (requests 4Gi per D-03)

## inferenceservice-config Patch Evidence

```json
{
    "enableGatewayApi": false,
    "kserveIngressGateway": "kserve/kserve-ingress-gateway",
    "ingressGateway": "knative-serving/knative-ingress-gateway",
    "localGateway": "knative-serving/knative-local-gateway",
    "localGatewayService": "knative-local-gateway.istio-system.svc.cluster.local",
    "ingressDomain": "example.com",
    "ingressClassName": "istio",
    "domainTemplate": "{{ .Name }}-{{ .Namespace }}.{{ .IngressDomain }}",
    "urlScheme": "http",
    "disableIstioVirtualHost": true,
    "disableIngressCreation": true
}
```

Key fields: `disableIngressCreation: true` prevents HTTPRoute creation; `disableIstioVirtualHost: true` prevents Istio VirtualService creation; `ingressGateway` retained (required by KServe config validator — omitting it crashes controller with "invalid ingress config - ingressGateway is required").

## Pre-conditions for Plan 05-03

- `llm-serving` namespace exists (from Phase 02/03); Pattern A and B Deployments at replicas=0
- MinIO healthy in `minio` namespace; `smollm2-finetuned/` model object accessible at `minio.minio:9000/models/smollm2-finetuned/`
- KServe controller Ready (kserve-controller-manager 2/2 Running)
- cert-manager-webhook Ready (required for InferenceService admission webhook TLS)
- NodePort 30202 bound on KIND host (verified in Plan 05-01)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] ConfigMap patch format: full JSON required, not minimal single-key**
- **Found during:** Task 2 Step E (patch inferenceservice-config) + Step F (controller restart)
- **Issue:** Plan Step E used `'{"data": {"ingress": "{\"disableIngressCreation\": true}"}}'` (minimal single-key patch). KServe controller startup validates the ingress config object and requires `ingressGateway` to be present. The minimal patch omitted this field, causing the controller to crash with: `"unable to get ingress config" error:"invalid ingress config - ingressGateway is required"`
- **Fix:** Re-applied ConfigMap patch with full JSON ingress config (all original fields preserved), setting `disableIngressCreation: true` and `disableIstioVirtualHost: true` while retaining `ingressGateway`, `kserveIngressGateway`, `enableGatewayApi: false`, and all other required fields.
- **Files modified:** None (ConfigMap is cluster state, not a file)
- **Verification:** Controller restarted cleanly — `kserve-controller-manager 2/2 Running` with no crash logs

**2. [Rule 3 - Blocking] OCI 403 on first KServe CRD chart pull**
- **Found during:** Task 2 Step B (first attempt)
- **Issue:** `helm install kserve-crd oci://ghcr.io/kserve/charts/kserve-crd` failed with 403 Unauthorized on first attempt. Root cause: stale docker credentials for ghcr.io from a previous login session blocked the anonymous pull path.
- **Fix:** Ran `docker logout ghcr.io` to clear stale credentials. Second attempt pulled successfully (anonymous pull works for public ghcr.io packages once stale session is removed).
- **Deviation note from D-09:** D-09 says "deploymentMode=Standard". Research (RESEARCH.md Anti-Patterns + Pitfall 2) establishes that `deploymentMode=Standard` with no Gateway API controller creates HTTPRoutes that never reconcile, blocking InferenceService READY state indefinitely. The correct KIND interpretation is `deploymentMode=RawDeployment` — same architecture (no Knative, no Istio) but skips HTTPRoute creation. Helm flag used: `--set kserve.controller.deploymentMode=RawDeployment`. This is the documented Pitfall 2 mitigation (Option B). Recorded as plan-mandated deviation from D-09's literal value.

---

**Total deviations:** 2 auto-fixed (Rule 1 ConfigMap format; Rule 3 blocking OCI 403)
**Impact on plan:** Both fixes applied inline with no plan scope change. ConfigMap patch format fix was invisible to the human reviewer — end state matches spec.

## Issues Encountered

- OCI 403 on first ghcr.io pull (resolved by `docker logout ghcr.io`)
- KServe controller crash on first restart (resolved by full-JSON ConfigMap patch preserving `ingressGateway`)

## Threat Surface Scan

No new network endpoints or auth paths introduced beyond the plan's threat model. The 4 components installed match the 4 approved entries in the STRIDE threat register (T-05-03 through T-05-07):
- cert-manager v1.16.5 from charts.jetstack.io (T-05-03: version-pinned, official source)
- Gateway API CRDs v1.2.1 from kubernetes-sigs/gateway-api (T-05-05: version-pinned, official SIG)
- KServe CRDs + controller v0.18.0 from ghcr.io/kserve (T-05-04: version-pinned, official org)

No new threat flags.

## Known Stubs

None — this plan is control-plane infrastructure installation only; no lab guide content or application code written.

## Self-Check: PASSED

- cert-manager pods: confirmed 3/3 Running 1/1 Ready
- Gateway API CRDs: confirmed 5 CRDs present
- KServe CRDs: confirmed 6 CRDs present
- KServe controller: confirmed 2/2 Running
- inferenceservice-config: confirmed `disableIngressCreation: true` in parseable JSON
- No Knative namespace: confirmed
- No Istio namespace: confirmed
- Helm releases: cert-manager v1.16.5, kserve-crd v0.18.0, kserve v0.18.0 — all `deployed`

---
*Phase: 05-kserve-inferenceservice-serving-decision-lab*
*Completed: 2026-06-17*
