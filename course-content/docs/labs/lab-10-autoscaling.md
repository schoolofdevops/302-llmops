---
sidebar_position: 10
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Lab 10: Autoscaling — HPA + KEDA for All Serving Patterns

**Day 3 | Duration: ~90 minutes**

## Learning Objectives

- Reinstall kube-prometheus-stack, KEDA, and metrics-server after the cluster recreate in Lab 08
- Configure CPU-based HPA for the stateless `rag-retriever` FastAPI service
- Deploy KEDA `ScaledObject` resources for all three serving patterns using the `vllm:num_requests_waiting` Prometheus metric
- Run `hey` load generator Jobs to demonstrate scale-up for each pattern
- Understand when to use CPU HPA vs KEDA queue-depth scaling and why they differ for LLM workloads

## Architecture

```
       ┌───────────────────────────┐
       │   Prometheus (kps)        │  ← scrapes vllm:num_requests_waiting
       │   monitoring namespace    │
       └──────────┬────────────────┘
                  │  serverAddress
       ┌──────────▼────────────────┐
       │   KEDA operator           │  ← polls Prometheus every 15s
       │   keda namespace          │    fires scale trigger when > threshold
       └──────────┬────────────────┘
                  │  ScaledObject
       ┌──────────▼──────────────────────────────────────┐
       │  Pattern A: vllm-smollm2 Deployment             │
       │  Pattern B: lmstack-smollm2 Deployment (chart)  │
       │  Pattern C: smollm2-predictor Deployment (KServe)│
       └─────────────────────────────────────────────────┘
```

:::warning RAM budget — verify before starting
This lab exercises all 3 serving patterns sequentially. Running more than one vLLM Deployment simultaneously exceeds the 16 GB RAM budget. Tear down each pattern after its KEDA section before bringing up the next.

Verify Docker Desktop memory allocation before starting:

```bash
kubectl top nodes
```

Expected: workers showing < 8 GB memory in use before starting.
:::

## Prerequisites

- Lab 07 complete: MinIO running, model artifact at `s3://models/smollm2-finetuned/`
- Lab 07 complete: Pattern A (`vllm-smollm2`) deployed in `llm-serving`
- NodePorts 30090 (Grafana), 30500 (Prometheus), 30200 (Pattern A vLLM), 30201 (Pattern B router), 30202 (Pattern C KServe) in `kind-config.yaml`

---

## Part 1: Reinstall Observability + KEDA

The cluster was recreated in Lab 08 (Pattern C KServe setup). This wiped kube-prometheus-stack, KEDA, and metrics-server. Reinstall all three before applying autoscaling resources.

```bash
# Install kube-prometheus-stack (Grafana + Prometheus)
bash course-code/labs/lab-10/solution/scripts/install-kps.sh

# Install KEDA
bash course-code/labs/lab-10/solution/scripts/install-keda.sh

# Install metrics-server (required for CPU HPA)
bash course-code/labs/lab-10/solution/scripts/install-metrics-server.sh
```

Verify all three are running:

```bash
# Prometheus and Grafana
kubectl get pods -n monitoring | grep -E "prometheus|grafana"

# KEDA operator
kubectl get pods -n keda

# metrics-server
kubectl top nodes   # should return CPU/memory values
```

Expected Grafana URL: [http://localhost:30090](http://localhost:30090) (admin / admin).

---

## Part 2: HPA on rag-retriever (CPU-based)

:::info HPA vs KEDA — choosing the right autoscaling signal

| Question | Answer | Implies |
|----------|--------|---------|
| Is the service stateless and safe to scale horizontally? | Yes (rag-retriever is a FastAPI FAISS service) | HPA is appropriate |
| Does CPU correlate reliably with load? | Yes (embedding + vector search is CPU-bound) | CPU HPA works |
| Is there a semantic queue-depth metric? | No (HTTP requests are answered immediately) | KEDA Prometheus trigger not needed |

For **vLLM inference**: CPU can be fully saturated while a long-running batch is in progress — a new request will queue and CPU won't spike until the batch finishes. The `vllm:num_requests_waiting` metric fires the moment a request enters the queue, giving a much earlier and more reliable scale signal than CPU utilization.

**Rule of thumb:** Stateless APIs → CPU HPA. LLM inference with queuing semantics → KEDA on queue depth.
:::

Apply the HPA:

```bash
kubectl apply -f course-code/labs/lab-10/solution/k8s/80-hpa-chat-api.yaml
```

Inspect:

```bash
kubectl get hpa -n llm-app
kubectl top pods -n llm-app
```

Expected output:

```
NAME            REFERENCE                  TARGETS              MINPODS   MAXPODS   REPLICAS
rag-retriever   Deployment/rag-retriever   cpu: 12%/60%         1         2         1
```

The HPA will scale `rag-retriever` from 1 to 2 replicas if average CPU utilization across pods exceeds 60%.

---

## Part 3: KEDA ScaledObject — Pattern A (plain vLLM Deployment)

Pattern A is the `vllm-smollm2` Deployment deployed in Lab 04 (plain `apps/v1 Deployment`, no KServe, no router).

Review the ScaledObject:

```yaml
# course-code/labs/lab-10/solution/k8s/80-keda-scaledobject-pattern-a.yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: vllm-smollm2
  namespace: llm-serving
spec:
  scaleTargetRef:
    name: vllm-smollm2       # Must match the Deployment name exactly
  minReplicaCount: 1
  maxReplicaCount: 3
  pollingInterval: 15         # Poll Prometheus every 15 seconds
  cooldownPeriod: 300         # Wait 5 minutes before scaling down
  triggers:
    - type: prometheus
      metadata:
        serverAddress: "http://kps-kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090"
        query: 'sum(vllm:num_requests_waiting{model_name="smollm2-135m-finetuned"})'
        threshold: "1"        # Scale up on the FIRST queued request
        metricName: "vllm_requests_waiting"
```

:::note Key design decisions

**`vllm:num_requests_waiting` (colon, NOT underscore):** vLLM 0.9.1+ uses colon-prefix metric names. The old naming (`vllm_request_ttft_seconds`) was used in vLLM < 0.15. Using the wrong separator returns empty results from Prometheus and KEDA never triggers.

**`minReplicaCount: 1`:** Avoids cold-start penalty. Scale-to-zero would mean no pods available to receive requests; the first request would wait 60-180s for model load. Keep at least 1 replica warm.

**`threshold: "1"`:** Fire the scale trigger as soon as a single request queues. For a CPU-bound vLLM instance, any queue depth means the current replica is saturated.

**`serverAddress`:** Must include the Helm release name prefix `kps-` (from `helm install kps ...` in install-kps.sh). Verify with: `kubectl get svc -n monitoring | grep prometheus`
:::

Apply and verify:

```bash
kubectl apply -f course-code/labs/lab-10/solution/k8s/80-keda-scaledobject-pattern-a.yaml

# Verify READY=True (takes ~15s for first Prometheus poll)
kubectl get scaledobject vllm-smollm2 -n llm-serving

# Inspect conditions
kubectl describe scaledobject vllm-smollm2 -n llm-serving
```

Expected:

```
NAME           SCALETARGETKIND      SCALETARGETNAME   MIN   MAX   READY   ACTIVE
vllm-smollm2   apps/v1.Deployment   vllm-smollm2      1     3     True    False
```

`ACTIVE=False` means no requests are queued yet. It will flip to `True` during the load test.

Also apply the Grafana dashboard:

```bash
kubectl apply -f course-code/labs/lab-10/solution/k8s/82-grafana-dashboard-autoscaling-cm.yaml
```

Open Grafana → Dashboards → "Autoscaling Demo" to see the two panels: requests waiting and replica count.

---

## Part 4: Load Test — Pattern A Scale-Up Evidence

Run the 3-minute hey load test against Pattern A:

```bash
bash course-code/labs/lab-10/solution/scripts/run-loadgen.sh a
```

In a separate terminal, watch the scale-up:

```bash
# Watch pod scheduling in real time
kubectl get pods -n llm-serving -w

# Watch ScaledObjects (in another terminal)
kubectl get scaledobject -n llm-serving -w
```

### Expected sequence

| Time | Event |
|------|-------|
| 0s | hey Job starts, 4 concurrent connections, 2 RPS each |
| ~5-15s | `vllm:num_requests_waiting` metric crosses threshold=1 |
| ~15-30s | KEDA polls Prometheus, fires scale trigger (HPA desiredReplicas=2) |
| ~30-45s | Second `vllm-smollm2-*` pod appears in `Pending` or `ContainerCreating` |
| ~90-180s | Pod reaches `Running` state (SmolLM2-135M loads in ~90s on CPU) |
| 180s | hey Job completes |
| +300s | Cooldown expires; KEDA scales back to minReplicaCount=1 |

Verify `ACTIVE=True` during load:

```bash
kubectl get scaledobject vllm-smollm2 -n llm-serving -o jsonpath='{.status.conditions[?(@.type=="Active")].status}'
# Expected: True
```

:::note 3rd pod may stay Pending or OutOfCpu
On a resource-constrained KIND cluster (2 workers, ~8 CPU total), a 3rd vLLM pod requesting `cpu: 4` will be `Pending` or `OutOfCpu`. KEDA correctly issued the scale command — Kubernetes cannot schedule it given the resource constraint.

`maxReplicaCount: 3` is intentional for production-scale demonstration. On a real cluster with adequate nodes, the 3rd pod would schedule normally.

This is expected course behavior, not an error.
:::

After the 3-minute test, observe scale-down:

```bash
# After ~300s (cooldownPeriod), KEDA scales back to 1
kubectl get pods -n llm-serving
```

---

## Part 5: KEDA — Pattern B (vLLM Router — chart-managed ScaledObject)

:::caution Do NOT apply a separate ScaledObject YAML for Pattern B

The `vllm-stack` Helm chart creates its own `ScaledObject` when `keda.enabled: true` in the values file. Applying a standalone `ScaledObject` targeting the same Deployment (`lmstack-smollm2-deployment-vllm`) will conflict with the chart-managed resource and cause unpredictable behavior.

**For Pattern B, KEDA is managed entirely by the Helm chart.** Your only action is to reinstall the chart with the correct values.
:::

First, scale down Pattern A to free memory:

```bash
# KEDA will fight you if you just kubectl scale — it will scale it back
# Temporarily set minReplicaCount to 0 by deleting the ScaledObject first:
kubectl delete scaledobject vllm-smollm2 -n llm-serving
kubectl scale deployment vllm-smollm2 -n llm-serving --replicas=0
```

Reinstall the vllm-stack Helm chart with `keda.enabled: true`:

:::note Prerequisite: lmstack-router image in local registry
On Apple Silicon (arm64), the `lmstack-router` image must be pre-pushed to the local KIND registry before reinstalling. See Lab 07 Apple Silicon prerequisites.
:::

```bash
helm upgrade --install lmstack vllm/vllm-stack --version 0.1.11 \
  --values course-code/labs/lab-07/solution/k8s/00-values-vllm-router.yaml \
  -n llm-serving --create-namespace
```

The `keda` section in the values file:

```yaml
keda:
  enabled: true
  minReplicaCount: 2
  maxReplicaCount: 3
  pollingInterval: 15
  cooldownPeriod: 360
  triggers:
    - type: prometheus
      metadata:
        serverAddress: "http://kps-kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090"
        metricName: "vllm:num_requests_waiting"
        query: 'sum(vllm:num_requests_waiting{model_name="smollm2-135m-finetuned"})'
        threshold: "5"
```

Verify the chart-created ScaledObject:

```bash
kubectl get scaledobject -n llm-serving
```

Expected (chart creates the ScaledObject automatically):

```
NAME                           SCALETARGETKIND      SCALETARGETNAME                   MIN   MAX   READY
lmstack-smollm2-scaledobject   apps/v1.Deployment   lmstack-smollm2-deployment-vllm   2     3     True
```

Run the Pattern B load test:

```bash
bash course-code/labs/lab-10/solution/scripts/run-loadgen.sh b
```

Watch backend pods scale up:

```bash
kubectl get pods -n llm-serving -w
# Observe lmstack-smollm2-deployment-vllm-* pods increasing from 2 to 3
```

After verifying scale-up, tear down Pattern B before Part 6:

```bash
helm uninstall lmstack -n llm-serving
```

---

## Part 6: KEDA — Pattern C (KServe InferenceService predictor)

:::info Prerequisites for Pattern C
Pattern C requires KServe + cert-manager, which were torn down at the end of Lab 08. Reinstall using the Lab 08 install sequence before this section.

See Lab 08 Part 1 for the exact install commands:
- cert-manager v1.16.5
- Gateway API CRDs v1.2.1
- KServe CRDs v0.18.0
- KServe resources v0.18.0 (RawDeployment mode)
- KServe inferenceservice-config patch (disableIngressCreation + ingressGateway)
- ClusterServingRuntime + InferenceService + smollm2-nodeport Service
:::

After KServe + smollm2 InferenceService is running:

```bash
# Verify smollm2-predictor Deployment was created by KServe
kubectl get deploy smollm2-predictor -n llm-serving
```

:::caution KServe creates its own HPA — you must disable it before applying the KEDA ScaledObject
KServe RawDeployment mode automatically creates an HPA for each predictor. KEDA's admission webhook will reject a ScaledObject that targets a Deployment already managed by an HPA.

Before applying the KEDA ScaledObject for Pattern C, annotate the InferenceService to use the external autoscaler:

```bash
kubectl annotate inferenceservice smollm2 -n llm-serving \
  serving.kserve.io/autoscalerClass=external
```

This removes the KServe-managed HPA, allowing KEDA to manage scaling instead. Verify:

```bash
kubectl get hpa -n llm-serving
# The smollm2-predictor HPA should be gone
```
:::

#### Pitfall: KServe predictor Deployment name

KServe auto-names the predictor Deployment as `<inferenceservice-name>-predictor`. For the `smollm2` InferenceService, the Deployment is named `smollm2-predictor` — **NOT** `smollm2` and NOT `vllm-smollm2`.

Apply ServiceMonitor first to let Prometheus discover the predictor:

```bash
kubectl apply -f course-code/labs/lab-10/solution/k8s/80-servicemonitor-kserve-predictor.yaml

# Wait ~60s for Prometheus to scrape the new target
# Verify: curl http://localhost:30500/api/v1/targets | python3 -m json.tool | grep smollm2
```

Review the Pattern C ScaledObject:

```yaml
# course-code/labs/lab-10/solution/k8s/80-keda-scaledobject-pattern-c.yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: smollm2-predictor-keda
  namespace: llm-serving
spec:
  scaleTargetRef:
    name: smollm2-predictor    # KServe auto-names: <isvc-name>-predictor
  minReplicaCount: 1
  maxReplicaCount: 3
  pollingInterval: 15
  cooldownPeriod: 360          # Longer cooldown: initContainer model download adds time
  triggers:
    - type: prometheus
      metadata:
        serverAddress: "http://kps-kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090"
        query: 'sum(vllm:num_requests_waiting{model_name="smollm2-135m-finetuned"})'
        threshold: "5"         # Higher threshold: allow some queue before triggering
        metricName: "vllm_requests_waiting_kserve"
```

Apply the ScaledObject:

```bash
kubectl apply -f course-code/labs/lab-10/solution/k8s/80-keda-scaledobject-pattern-c.yaml

kubectl get scaledobject smollm2-predictor-keda -n llm-serving
```

Expected:

```
NAME                     SCALETARGETKIND      SCALETARGETNAME     MIN   MAX   READY   ACTIVE
smollm2-predictor-keda   apps/v1.Deployment   smollm2-predictor   1     3     True    False
```

Run the Pattern C load test:

```bash
bash course-code/labs/lab-10/solution/scripts/run-loadgen.sh c
```

Watch scale-up:

```bash
kubectl get pods -n llm-serving -w
# Observe smollm2-predictor-* pods scaling from 1 to 2+
```

Verify READY=True, Active=True during load:

```bash
kubectl get scaledobject smollm2-predictor-keda -n llm-serving
kubectl get scaledobject smollm2-predictor-keda -n llm-serving \
  -o jsonpath='{.status.conditions[?(@.type=="Active")].status}'
# Expected: True
```

---

## Part 7: Resource Budget

Check cluster resource usage after running all three patterns:

```bash
kubectl top nodes
kubectl top pods -n llm-serving
kubectl top pods -n monitoring
```

Expected footprint with Pattern A running (steady state):

| Component | Namespace | CPU | Memory |
|-----------|-----------|-----|--------|
| vllm-smollm2 (1 pod) | llm-serving | ~2000m | ~4 Gi |
| kube-prometheus-stack | monitoring | ~300m | ~1.5 Gi |
| KEDA (3 pods) | keda | ~50m | ~200 Mi |
| cert-manager (Pattern C only) | cert-manager | ~50m | ~200 Mi |
| KServe controller (Pattern C only) | kserve | ~100m | ~200 Mi |

:::caution Run one pattern at a time
Each vLLM Deployment requests 4 CPU / 4 Gi RAM. A 2-worker KIND cluster with 8 CPU / 16 GB total can sustain one vLLM pod comfortably. Running Pattern A + Pattern B simultaneously causes backends to go `Pending` or `OutOfCpu`.

Always tear down the current pattern before starting the next one.
:::

---

## Part 8: Teardown

Delete all Lab 10 autoscaling resources:

```bash
# Delete KEDA ScaledObjects + HPA + ServiceMonitor + Grafana dashboard
kubectl delete -f course-code/labs/lab-10/solution/k8s/

# Note: This also deletes the Grafana dashboard ConfigMap and ServiceMonitor
```

Leave the following running for Labs 11 and 12:

- `kube-prometheus-stack` (monitoring namespace) — needed for GitOps observability
- `KEDA` (keda namespace) — needed if you want autoscaling in Lab 11/12
- `metrics-server` (kube-system) — needed for any HPA

```bash
# Verify what's still running after teardown
kubectl get pods -n monitoring | grep -E "prometheus|grafana"
kubectl get pods -n keda
kubectl top nodes
```

---

## Lab Summary

### What was covered

| Topic | Detail |
|-------|--------|
| CPU HPA | rag-retriever FastAPI service scales on CPU 60% target — appropriate for stateless compute-bound APIs |
| KEDA Pattern A | Standalone ScaledObject on `vllm-smollm2` Deployment; `vllm:num_requests_waiting` threshold=1; hey load test demonstrated scale-up trigger |
| KEDA Pattern B | Chart-managed ScaledObject (keda.enabled=true in vllm-stack values); no standalone YAML needed; same metric, threshold=5 |
| KEDA Pattern C | Standalone ScaledObject on KServe predictor `smollm2-predictor`; requires `autoscalerClass=external` annotation to disable KServe's built-in HPA |
| Scale-up evidence | hey -z 180s -c 4 -q 2 triggers KEDA Active=True; second pod scheduled (Pending on resource-constrained KIND; Running on a production cluster) |
| Scale-down | cooldownPeriod (300-360s) prevents thrash after load drops |
| Grafana | `82-grafana-dashboard-autoscaling-cm.yaml` auto-imported via grafana_dashboard: "1" label — shows requests waiting + replica count side by side |

### Key distinction: HPA vs KEDA for LLM workloads

```
CPU HPA          →  measure resource consumption  →  scale when resources are full
KEDA Prometheus  →  measure work queue depth       →  scale when work is backlogged
```

For vLLM, queue depth is the superior signal: it fires before CPU becomes the bottleneck (model inference is not purely CPU-linear), and it avoids the false-negative where CPU stays low while a batch is actively running (blocking new requests from being serviced).
