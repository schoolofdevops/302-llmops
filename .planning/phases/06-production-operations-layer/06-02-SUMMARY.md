---
phase: 06-production-operations-layer
plan: "02"
subsystem: autoscaling
tags:
  - keda
  - hpa
  - kserve
  - pattern-a
  - pattern-b
  - pattern-c
  - hey-loadgen
  - grafana-dashboard
dependency_graph:
  requires:
    - 06-01-SUMMARY.md
  provides:
    - "KEDA ScaledObject for Pattern A (vllm-smollm2) READY=True in llm-serving"
    - "KEDA ScaledObject for Pattern C (smollm2-predictor-keda) READY=True in llm-serving"
    - "HPA for rag-retriever (CPU 60%) in llm-app"
    - "ServiceMonitor for KServe predictor in monitoring"
    - "hey load generator Jobs for all 3 patterns in course-code/labs/lab-10/solution/k8s/"
    - "Grafana dashboard ConfigMap (autoscaling-demo) in monitoring"
    - "run-loadgen.sh multi-pattern load generator script"
    - "lab-10-autoscaling.md: 529-line lab guide with 8 parts"
  affects:
    - "06-03-PLAN.md (ArgoCD lab — lab-10 manifests define the teardown baseline)"
tech_stack:
  added:
    - KEDA ScaledObject (keda.sh/v1alpha1) targeting vllm:num_requests_waiting Prometheus metric
    - HPA (autoscaling/v2) CPU-based for rag-retriever
    - ServiceMonitor (monitoring.coreos.com/v1) for KServe predictor pods
    - hey load generator (williamyeh/hey:latest) as Kubernetes Job
  patterns:
    - "KEDA Prometheus scaler: serverAddress = kps-kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090"
    - "KServe autoscalerClass=external annotation: disables built-in HPA to allow KEDA"
    - "vllm:num_requests_waiting colon prefix (vLLM 0.9.1+) not underscore"
    - "minReplicaCount: 1 avoids cold-start on CPU-bound vLLM"
    - "Pattern B ScaledObject is chart-managed (keda.enabled: true in vllm-stack values) — no standalone YAML"
key_files:
  created:
    - course-code/labs/lab-10/solution/k8s/80-keda-scaledobject-pattern-a.yaml
    - course-code/labs/lab-10/solution/k8s/80-keda-scaledobject-pattern-c.yaml
    - course-code/labs/lab-10/solution/k8s/80-hpa-chat-api.yaml
    - course-code/labs/lab-10/solution/k8s/80-servicemonitor-kserve-predictor.yaml
    - course-code/labs/lab-10/solution/k8s/81-loadgen-job-hey-pattern-a.yaml
    - course-code/labs/lab-10/solution/k8s/81-loadgen-job-hey-pattern-b.yaml
    - course-code/labs/lab-10/solution/k8s/81-loadgen-job-hey-pattern-c.yaml
    - course-code/labs/lab-10/solution/k8s/82-grafana-dashboard-autoscaling-cm.yaml
    - course-code/labs/lab-10/starter/k8s/80-keda-scaledobject-pattern-a.yaml
    - course-code/labs/lab-10/starter/k8s/80-keda-scaledobject-pattern-c.yaml
    - course-code/labs/lab-10/starter/k8s/80-hpa-chat-api.yaml
    - course-code/labs/lab-10/starter/k8s/80-servicemonitor-kserve-predictor.yaml
    - course-code/labs/lab-10/solution/scripts/run-loadgen.sh
    - course-content/docs/labs/lab-10-autoscaling.md
  modified:
    - course-content/sidebars.ts
    - course-content/docusaurus.config.ts
decisions:
  - "Pattern B ScaledObject is chart-managed: keda.enabled: true in vllm-stack values — no standalone YAML; chart name is lmstack-smollm2-scaledobject"
  - "KServe autoscalerClass=external required before KEDA ScaledObject for Pattern C: KServe RawDeployment auto-creates HPA; KEDA admission webhook blocks second ScaledObject"
  - "vllm:num_requests_waiting colon prefix (not underscore) confirmed for vLLM 0.9.1"
  - "HPA targets rag-retriever in llm-app (from Lab 01); it is a course-wide deployment that exists when Lab 01 is complete"
  - "KServe inferenceservice-config patch must include full ingress JSON with ingressGateway field; disableIngressCreation alone causes InternalError"
metrics:
  duration: "~60 minutes"
  completed: "2026-06-17"
  tasks_completed: 3
  files_created: 14
  files_modified: 2
---

# Phase 06 Plan 02: HPA + KEDA Autoscaling for All 3 Serving Patterns Summary

KEDA ScaledObjects for Pattern A (vllm-smollm2) and Pattern C (smollm2-predictor via KServe); HPA for rag-retriever; hey load generator Jobs for all 3 patterns; Grafana dashboard ConfigMap; run-loadgen.sh multi-pattern script; 529-line lab-10-autoscaling.md guide covering all 8 parts.

## What Was Built

### Task 1: Pattern A manifests + apply to cluster (commit: 7d300a6)

Four solution files written and applied to the live cluster:

**80-keda-scaledobject-pattern-a.yaml**: KEDA ScaledObject for `vllm-smollm2` Deployment in `llm-serving`. Uses `vllm:num_requests_waiting{model_name="smollm2-135m-finetuned"}` with threshold=1, minReplicaCount=1, maxReplicaCount=3, pollingInterval=15s, cooldownPeriod=300s. Applied to cluster: `READY=True` confirmed.

**80-hpa-chat-api.yaml**: HPA for `rag-retriever` Deployment in `llm-app` namespace (CPU-based, 60% utilization target). Applied to cluster: HPA resource created.

**81-loadgen-job-hey-pattern-a.yaml**: hey load generator Job targeting `http://vllm-smollm2.llm-serving.svc.cluster.local:8000/v1/completions` with `-z 180s -c 4 -q 2`. Model name `smollm2-135m-finetuned` matches `--served-model-name` in deploy-vllm.yaml.

**82-grafana-dashboard-autoscaling-cm.yaml**: ConfigMap with `grafana_dashboard: "1"` label for auto-import. Two panels: "vLLM Requests Waiting" (`vllm:num_requests_waiting`) and "Replica Count" (`kube_deployment_status_replicas{deployment="vllm-smollm2"}`).

Starter files with TODO blanks: `80-keda-scaledobject-pattern-a.yaml` (query, threshold) and `80-hpa-chat-api.yaml` (averageUtilization).

### Task 2: Pattern B + C reinstall + manifests (commit: 961bdb4)

**Pattern B (vllm-stack reinstall):**
- Reinstalled `vllm/vllm-stack` 0.1.11 with `00-values-vllm-router.yaml` (keda.enabled=true)
- Chart auto-created ScaledObject `lmstack-smollm2-scaledobject` with READY=True
- Chart ScaledObject targets `lmstack-smollm2-deployment-vllm` (chart-managed Deployment)
- No standalone Pattern B ScaledObject YAML (Pitfall 5 — chart owns it)
- Chart torn down after evidence collected to free resources for Pattern C

**Pattern C (KServe reinstall + manifests):**
- Reinstalled cert-manager v1.16.5, Gateway API CRDs v1.2.1, KServe CRDs + resources v0.18.0
- Fixed inferenceservice-config patch: full JSON required (bare disableIngressCreation alone causes InternalError on controller reconciler)
- Annotated InferenceService with `autoscalerClass=external` to disable KServe's built-in HPA (required before KEDA ScaledObject apply)
- Applied `80-servicemonitor-kserve-predictor.yaml` and `80-keda-scaledobject-pattern-c.yaml`
- KEDA ScaledObject `smollm2-predictor-keda` confirmed READY=True

**Files written:**
- `80-keda-scaledobject-pattern-c.yaml`: ScaledObject for KServe predictor `smollm2-predictor` (threshold=5, cooldown=360s)
- `80-servicemonitor-kserve-predictor.yaml`: ServiceMonitor selecting `serving.kserve.io/inferenceservice: smollm2` pods
- `81-loadgen-job-hey-pattern-b.yaml`: hey Job targeting `lmstack-router.llm-serving.svc.cluster.local:8000`
- `81-loadgen-job-hey-pattern-c.yaml`: hey Job targeting `smollm2-nodeport.llm-serving.svc.cluster.local:30202`
- Starter files for Pattern C with TODO blanks

### Task 3: Pattern A load test + run-loadgen.sh + Lab 10 doc page (commit: 25dc2a5)

**Pattern A load test evidence:**
- `hey` Job submitted against Pattern A; KEDA ScaledObject `Active=True` observed
- Multiple `vllm-smollm2-*` pods created in `OutOfCpu` state — confirms KEDA scale trigger fired (expected behavior: cluster is resource-constrained, 1 vLLM pod consumes all available 4 CPUs)
- HPA `keda-hpa-vllm-smollm2` showed `3/1 (avg)` (3 queued requests vs threshold=1) confirming metric capture

**run-loadgen.sh**: Idempotent script accepting `a|b|c` argument; deletes existing Job, submits new hey Job from relative path; prints watch commands.

**lab-10-autoscaling.md**: 529-line lab guide with 8 parts:
1. Reinstall prerequisites (install-kps.sh, install-keda.sh, install-metrics-server.sh)
2. HPA on rag-retriever with HPA vs KEDA decision table
3. KEDA Pattern A ScaledObject with key field callouts
4. Load test Pattern A with expected timing sequence and OutOfCpu explanation
5. KEDA Pattern B (caution: chart-managed ScaledObject, no standalone YAML)
6. KEDA Pattern C (KServe prerequisite callout + autoscalerClass=external workaround)
7. Resource budget table
8. Teardown instructions

**Docusaurus:** Added `labs/lab-10-autoscaling` to `sidebars.ts`; removed stale redirect from `docusaurus.config.ts`; build exits 0 with no errors.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] KServe inferenceservice-config patch caused InternalError on predictor reconciliation**

- **Found during:** Task 2 — KServe Pattern C install
- **Issue:** `kubectl patch configmap/inferenceservice-config --type=merge -p '{"data":{"ingress":...}}'` replaced the entire `ingress` key with a bare `{"disableIngressCreation":true}` object, losing the required `ingressGateway` field. KServe controller logged: `InternalError: fails to create NewRawKubeReconciler for predictor: invalid ingress config - ingressGateway is required`
- **Fix:** Applied JSON patch with the full required ingress config including `ingressGateway`, `kserveIngressGateway`, `ingressDomain`, `domainTemplate`, and `urlScheme` fields alongside `disableIngressCreation: true`; restarted KServe controller to pick up the fix
- **Files modified:** None (live cluster ConfigMap patched; course documentation updated in lab-10-autoscaling.md Part 6)
- **Commit:** Inline during Task 2; note added to 80-keda-scaledobject-pattern-c.yaml

**2. [Rule 2 - Missing Critical] KServe auto-creates HPA blocking KEDA ScaledObject admission**

- **Found during:** Task 2 — attempting to apply 80-keda-scaledobject-pattern-c.yaml
- **Issue:** KServe RawDeployment mode automatically creates an HPA (`smollm2-predictor`) targeting the predictor Deployment. KEDA's admission webhook (`vscaledobject.kb.io`) denied the ScaledObject: `the workload 'smollm2-predictor' of type 'apps/v1.Deployment' is already managed by the hpa 'smollm2-predictor'`
- **Fix:** Annotated InferenceService: `kubectl annotate inferenceservice smollm2 -n llm-serving serving.kserve.io/autoscalerClass=external` — removes the KServe-managed HPA, allowing KEDA to manage scaling
- **Files modified:** 80-keda-scaledobject-pattern-c.yaml — added prerequisite comment block documenting the annotation requirement
- **Commit:** 961bdb4 (comment in YAML file); knowledge embedded in lab-10-autoscaling.md Part 6

**3. [Rule 3 - Blocking] Stale redirect for lab-10-autoscaling in docusaurus.config.ts**

- **Found during:** Task 3 — Docusaurus build warning
- **Issue:** `docusaurus.config.ts` contained a redirect `{from: '/docs/labs/lab-10-autoscaling', to: 'https://github.com/schoolofdevops/303-agentops'}` from the Phase 01 content migration. Now that the actual lab-10 page exists, the redirect overrides it and Docusaurus warns about it
- **Fix:** Removed the stale redirect entry; build now exits 0 with no warnings
- **Files modified:** course-content/docusaurus.config.ts
- **Commit:** 25dc2a5

### Known Constraints (not bugs)

**Pattern B standalone ScaledObject YAML deliberately omitted:** The vllm-stack chart manages its own ScaledObject. A standalone 80-keda-scaledobject-pattern-b.yaml was not created — this is correct per RESEARCH.md Pitfall 5 and the plan's explicit instruction. The lab guide documents this in a `:::caution` block.

**OutOfCpu pods during Pattern A load test:** On a 2-worker KIND cluster with 8 CPU total, Pattern A (4 CPU request) + Pattern C predictor (4 CPU request) already consume both workers' allocatable CPU. KEDA correctly fired the scale trigger; additional pods entered `OutOfCpu` state because the cluster lacked capacity to schedule them. This is expected and documented in the lab guide as a learning point (not a bug).

## Known Stubs

None — all manifests apply real cluster resources. All content references correct versions (vLLM 0.9.1, KEDA 2.19.0, kube-prometheus-stack 83.4.2).

## Threat Flags

None — all changes are version-controlled YAML manifests and documentation. No new network endpoints introduced beyond what was planned. The KEDA ScaledObjects are cluster-internal (Prometheus→KEDA→HPA chain, all within cluster DNS). The hey Jobs are in-cluster load generators with no external exposure.

## Self-Check: PASSED

Files exist:
- course-code/labs/lab-10/solution/k8s/80-keda-scaledobject-pattern-a.yaml: FOUND (contains "vllm:num_requests_waiting" and "kps-kube-prometheus-stack-prometheus")
- course-code/labs/lab-10/solution/k8s/80-keda-scaledobject-pattern-c.yaml: FOUND (contains "smollm2-predictor" and "kps-kube-prometheus-stack-prometheus")
- course-code/labs/lab-10/solution/k8s/80-hpa-chat-api.yaml: FOUND (contains "rag-retriever" and "averageUtilization: 60")
- course-code/labs/lab-10/solution/k8s/80-servicemonitor-kserve-predictor.yaml: FOUND (contains "release: kps" and "serving.kserve.io/inferenceservice: smollm2")
- course-code/labs/lab-10/solution/k8s/81-loadgen-job-hey-pattern-a.yaml: FOUND (contains "williamyeh/hey:latest" and "smollm2-135m-finetuned")
- course-code/labs/lab-10/solution/k8s/81-loadgen-job-hey-pattern-b.yaml: FOUND (contains "williamyeh/hey:latest" and "lmstack-router")
- course-code/labs/lab-10/solution/k8s/81-loadgen-job-hey-pattern-c.yaml: FOUND (contains "williamyeh/hey:latest" and "smollm2-nodeport")
- course-code/labs/lab-10/solution/k8s/82-grafana-dashboard-autoscaling-cm.yaml: FOUND
- course-code/labs/lab-10/starter/k8s/80-keda-scaledobject-pattern-a.yaml: FOUND (contains TODO blanks)
- course-code/labs/lab-10/starter/k8s/80-hpa-chat-api.yaml: FOUND (contains TODO blank)
- course-code/labs/lab-10/starter/k8s/80-keda-scaledobject-pattern-c.yaml: FOUND (contains TODO blanks)
- course-code/labs/lab-10/starter/k8s/80-servicemonitor-kserve-predictor.yaml: FOUND (contains TODO blank)
- course-code/labs/lab-10/solution/scripts/run-loadgen.sh: FOUND (executable)
- course-content/docs/labs/lab-10-autoscaling.md: FOUND (529 lines)

Commits verified:
- 7d300a6: feat(06-02): Lab 10 Pattern A manifests — KEDA ScaledObject, HPA, hey loadgen, Grafana dashboard
- 961bdb4: feat(06-02): Lab 10 Pattern B+C manifests — KEDA ScaledObjects, ServiceMonitor, hey load jobs
- 25dc2a5: feat(06-02): Lab 10 run-loadgen.sh + lab-10-autoscaling.md (529 lines, 8 parts)

Live cluster state verified:
- kubectl get scaledobject vllm-smollm2 -n llm-serving: READY=True
- kubectl get scaledobject smollm2-predictor-keda -n llm-serving: READY=True
- kubectl get hpa rag-retriever -n llm-app: HPA exists (CPU <unknown>/60% — rag-retriever not deployed in test cluster but HPA resource created)
- cd course-content && npm run build: exit 0, no errors
