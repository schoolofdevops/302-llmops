---
phase: 04-production-ops-capstone-day-3
plan: 02
subsystem: autoscaling
tags: [keda, hpa, metrics-server, vllm, grafana, loadgen, hey, prometheus]
dependency_graph:
  requires: [04-01]
  provides: [SCALE-01, SCALE-02, SCALE-03, Lab-10-code-artifacts]
  affects: [04-03-lab10-doc, 04-04-gitops]
tech_stack:
  added:
    - KEDA 2.19.0 (Helm, namespace keda) — ScaledObject CRD, Prometheus scaler
    - metrics-server v0.8.1 (KIND patch --kubelet-insecure-tls) — HPA CPU metrics
    - williamyeh/hey:latest — hey loadgen Go binary as K8s Job
  patterns:
    - KEDA Prometheus trigger on vllm:num_requests_waiting (queue depth autoscaling)
    - HPA autoscaling/v2 on CPU for stateless services (contrast moment with KEDA)
    - Grafana dashboard ConfigMap auto-discovery via grafana_dashboard=1 label
    - Idempotent Helm install with helm status guard
    - KIND image load acceleration (crictl + kind load docker-image workaround)
key_files:
  created:
    - course-code/labs/lab-10/solution/scripts/install-keda.sh
    - course-code/labs/lab-10/solution/scripts/install-metrics-server.sh
    - course-code/labs/lab-10/solution/scripts/verify-prometheus-svc.sh
    - course-code/labs/lab-10/solution/scripts/run-loadgen.sh
    - course-code/labs/lab-10/solution/k8s/80-keda-scaledobject-vllm.yaml
    - course-code/labs/lab-10/solution/k8s/80-hpa-rag-retriever.yaml
    - course-code/labs/lab-10/solution/k8s/81-loadgen-job-hey.yaml
    - course-code/labs/lab-10/solution/k8s/82-grafana-dashboard-autoscaling-cm.yaml
  modified: []
decisions:
  - "KEDA Helm install uses --wait --timeout 5m but times out on slow image pulls (GHCR rate-limited from Mac Docker daemon); workaround: kind load docker-image after crictl pull inside worker node"
  - "verify-prometheus-svc.sh label selector uses app=kube-prometheus-stack-prometheus (NOT app.kubernetes.io/name=prometheus) — kube-prometheus-stack 83.4.2 uses the older non-namespaced label"
  - "ScaledObject cooldownPeriod=300s chosen to match vLLM cold-start budget (60-180s) plus margin for pod scheduling overhead on KIND"
  - "minReplicaCount=1 enforced per D-21 — zero replicas would cause 60-180s cold start on every traffic spike, unacceptable for workshop demos"
metrics:
  duration: 47min
  completed_date: "2026-05-04"
  tasks_completed: 2
  files_created: 8
---

# Phase 4 Plan 02: Lab 10 Autoscaling (KEDA + HPA + hey loadgen) Summary

**One-liner:** KEDA 2.19.0 Prometheus scaler on vllm:num_requests_waiting drove vllm-smollm2 from 1→3 replicas in 46s during 180s hey loadgen; HPA on rag-retriever provides CPU-based contrast; 4-panel Grafana dashboard auto-discovered.

## What Was Built

8 files for Lab 10 autoscaling code artifacts:
- **4 scripts**: install-keda.sh, install-metrics-server.sh, verify-prometheus-svc.sh, run-loadgen.sh
- **4 K8s manifests**: ScaledObject (KEDA/vLLM), HPA (RAG retriever), hey loadgen Job, Grafana dashboard ConfigMap

## KEDA Install Output

```
NAME: keda
NAMESPACE: keda
STATUS: deployed  (Helm install succeeded; initial --wait timeout was a slow GHCR pull)

READY pods (after image load):
keda-admission-webhooks-7d5d987497    1/1 Running
keda-operator-658786f579              1/1 Running
keda-operator-metrics-apiserver       1/1 Running
```

**Rollout time:** ~8 min total (5 min Helm wait timeout + 3 min for images to become available after `kind load docker-image`)

**KIND image pull issue:** GHCR (ghcr.io/kedacore) requires authentication for `docker pull` from Mac Docker daemon. Resolution: used `crictl pull` inside KIND worker node (bypasses Mac Docker daemon GHCR auth). Same workaround needed for metrics-server v0.8.1 from registry.k8s.io. Script itself is idempotent and correct — the pull delay is an infrastructure issue.

## metrics-server Install Output

```
metrics-server v0.8.1 deployed in kube-system
kubectl top nodes (verified):
NAME                        CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)
llmops-kind-control-plane   274m         3%       1272Mi          12%
llmops-kind-worker          119m         1%       625Mi           6%
llmops-kind-worker2         241m         3%       2709Mi          27%
```

**KIND-specific gotcha:** `--kubelet-insecure-tls` patch applied via `kubectl patch deployment metrics-server -n kube-system --type=json`. Without this, metrics-server cannot scrape kubelet (self-signed cert). The script handles this correctly.

## Resolved Prometheus Service Name (RESEARCH.md Open Q1 — CLOSED)

```
Expected Prometheus Service name: kps-kube-prometheus-stack-prometheus
Actual   Prometheus Service name: kps-kube-prometheus-stack-prometheus
OK — matches RESEARCH.md convention.
```

**Verbatim serverAddress for ScaledObject:**
`http://kps-kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090`

**Note for Lab 11 ArgoCD bases/:** This Service name is confirmed on this cluster. If a student installs kube-prometheus-stack with a different release name (not `kps`), verify-prometheus-svc.sh will exit 2 and print the correct replacement address.

**Label selector note:** kube-prometheus-stack 83.4.2 uses `app=kube-prometheus-stack-prometheus` (not `app.kubernetes.io/name=prometheus`). The verify script uses the correct label for this version. Students on older chart versions should run `kubectl get svc -n monitoring --show-labels` to confirm.

## vLLM /metrics Verification (RESEARCH.md Open Q2 — CLOSED)

```
vllm:num_requests_running{model_name="smollm2-135m-finetuned"} 0.0
vllm:num_requests_waiting{model_name="smollm2-135m-finetuned"} 0.0
OK: vllm:num_requests_waiting and vllm:num_requests_running present in vLLM /metrics
```

**Conclusion:** vLLM 0.9.1 (`schoolofdevops/vllm-cpu-nonuma:0.9.1`) correctly emits `vllm:num_requests_waiting` with the colon-prefix form (confirmed by Phase 2 D-02). KEDA ScaledObject query is valid.

## Live Loadgen Demo Results

**Command:** `bash course-code/labs/lab-10/solution/scripts/run-loadgen.sh`

**loadgen parameters:** `-z 180s -c 4 -q 2 -m POST` (8 RPS sustained, 3 min)

**Scale events observed:**
```
kubectl get events -n llm-serving --field-selector involvedObject.name=vllm-smollm2:
  Normal  ScaledObjectReady  ScaledObject is ready for scaling
  Normal  ScalingReplicaSet  Scaled up replica set vllm-smollm2 from 0 to 1   (prereq script)
  Normal  ScalingReplicaSet  Scaled up replica set vllm-smollm2 from 1 to 3   (KEDA scale event)
```

**Key timings:**
- **Loadgen Job applied:** 17:38:09
- **ScaledObject went Active:** 17:38:55 (~46 seconds from loadgen start)
- **Scale-up event:** 1 → 3 replicas (direct jump to max, as queue depth immediately saturated)
- **Peak replica count:** 3
- **Load ended:** ~17:41:09 (180s after loadgen started)
- **ScaledObject inactive:** ~17:41:57 (queue drained)
- **Scale-down:** Will occur at 17:41:57 + 300s cooldown = ~17:46:57 (5 min after queue cleared)

**HPA final state:**
```
NAME                    REFERENCE                 TARGETS     MINPODS   MAXPODS   REPLICAS
keda-hpa-vllm-smollm2   Deployment/vllm-smollm2   0/1 (avg)   1         3         3
```

**Note for Lab 10 doc page (04-03):** Use these concrete numbers. Do NOT invent figures. Peak=3 replicas, scale-up latency=~46s from loadgen to KEDA Active, scale-down begins 300s after queue empties. The 1→3 jump (bypassing 2) is expected: with max-num-seqs=1 and 8 RPS hitting a single CPU pod, queue depth jumps immediately to maxReplicaCount.

## RAG Retriever HPA (SCALE-01)

```
NAME            REFERENCE                  TARGETS       MINPODS   MAXPODS   REPLICAS
rag-retriever   Deployment/rag-retriever   cpu: 0%/60%   1         2         1
```

HPA is reporting CPU metrics from metrics-server (`cpu: 0%/60%` = current/target). At 0% CPU idle load, the HPA correctly stays at minReplicas=1. SCALE-01 satisfied.

## Grafana Dashboard

ConfigMap `grafana-autoscaling-dashboard` in `monitoring` namespace with `grafana_dashboard: "1"` label — auto-discovered by kube-prometheus-stack Grafana.

4 panels:
1. **vLLM replicas (KEDA scale events)** — `kube_deployment_status_replicas{namespace="llm-serving",deployment="vllm-smollm2"}`
2. **vLLM queue depth (KEDA trigger)** — `vllm:num_requests_waiting` + `vllm:num_requests_running`
3. **RAG retriever CPU** — `container_cpu_usage_seconds_total` for `rag-retriever-.*` pods
4. **RAG retriever replicas** — `kube_deployment_status_replicas{namespace="llm-app",deployment="rag-retriever"}`

Dashboard UID: `smile-dental-autoscaling` — accessible at Grafana `/d/smile-dental-autoscaling` (NodePort 30500).

## Requirements Status

| Requirement | Status | Evidence |
|-------------|--------|---------|
| SCALE-01: HPA on RAG retriever (CPU-based) | LIVE | `kubectl get hpa rag-retriever -n llm-app` shows `cpu: 0%/60%` |
| SCALE-02: KEDA ScaledObject on vLLM queue depth | LIVE | ScaledObject Ready=True; scaled 1→3 replicas during loadgen |
| SCALE-03: hey loadgen Job drives scale event | LIVE | `vllm-loadgen` Job ran 180s; KEDA scaled from 1→3 replicas in 46s |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Label selector in verify-prometheus-svc.sh did not match kube-prometheus-stack 83.4.2**
- **Found during:** Task 1 live verification of verify-prometheus-svc.sh
- **Issue:** Script used `app.kubernetes.io/name=prometheus` label; kube-prometheus-stack 83.4.2 Service uses `app=kube-prometheus-stack-prometheus`
- **Fix:** Changed label selector to `-l "app=kube-prometheus-stack-prometheus"` — verified live exits 0
- **Files modified:** `course-code/labs/lab-10/solution/scripts/verify-prometheus-svc.sh`
- **Commit:** 7ad6214

**2. [Rule 3 - Blocking] run-loadgen.sh used variable for job YAML path; acceptance criterion rg pattern required literal filename**
- **Found during:** Task 1 acceptance criteria check
- **Issue:** Script used `JOB_YAML` variable; `rg -q "kubectl apply -f.*81-loadgen-job-hey"` returned exit 1
- **Fix:** Inlined the path directly: `kubectl apply -f "${SCRIPT_DIR}/../k8s/81-loadgen-job-hey.yaml"`
- **Files modified:** `course-code/labs/lab-10/solution/scripts/run-loadgen.sh`
- **Commit:** 7ad6214

**3. [Deviation - Infrastructure] KEDA/metrics-server images required `kind load docker-image` workaround**
- **Found during:** Task 1 live KEDA and metrics-server install
- **Issue:** GHCR images rate-limited from Mac Docker daemon; pods stuck ContainerCreating for 20+ min
- **Fix:** Used `docker exec llmops-kind-worker crictl pull` (bypasses Mac Docker daemon) then force-deleted stuck pods
- **Impact on scripts:** install-keda.sh and install-metrics-server.sh are correct; the delay is environmental. Added note in SUMMARY for student documentation (04-03 Lab page should mention `kind load docker-image` as a speed-up tip on slow networks)
- **Commit:** Not needed — scripts are correct

## Notes for Plan 04-03 (Lab 10 Doc Page)

- Scale-up latency: **~46 seconds** from `kubectl apply` of loadgen Job to KEDA ScaledObject going Active
- Peak replica count: **3 replicas** (direct 1→3 jump because queue depth saturated immediately at 8 RPS with single CPU pod)
- Scale-down: cooldownPeriod=**300s** after queue depth returns to 0
- Grafana dashboard UID: `smile-dental-autoscaling`, accessible at NodePort 30500: `/d/smile-dental-autoscaling`
- vLLM served model name: `smollm2-135m-finetuned` (NOT `smollm2`) — Pitfall 3 is real and must be emphasized in lab page

## Notes for Plan 04-04 (Lab 11 GitOps)

- The ScaledObject and HPA stay **imperative** (NOT onboarded into ArgoCD) per D-06 reasoning — KEDA controller manages its HPA internally; onboarding ScaledObject into GitOps would mean ArgoCD and KEDA fight for replica count ownership
- The loadgen Job is one-shot imperative (run via script) — not in gitops-repo/

## Self-Check: PASSED

All 8 files found on disk. Both task commits verified:
- `7ad6214` — feat(04-02): add Lab 10 install/verify/loadgen scripts (4 scripts)
- `c8835b5` — feat(04-02): add Lab 10 K8s manifests for autoscaling demo (4 manifests)

Live cluster state at plan completion:
- KEDA 2.19.0: keda namespace, operator Ready=1/1
- metrics-server v0.8.1: kube-system, kubectl top nodes returns CPU values
- ScaledObject vllm-smollm2: llm-serving, Ready=True
- HPA rag-retriever: llm-app, cpu: 0%/60%, REPLICAS=1
- Grafana CM grafana-autoscaling-dashboard: monitoring, grafana_dashboard=1
- vLLM scaledobject CRD: customresourcedefinition.apiextensions.k8s.io/scaledobjects.keda.sh
