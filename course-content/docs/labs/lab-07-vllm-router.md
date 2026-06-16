---
sidebar_position: 8
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Lab 07: vLLM Router — Multi-Pod Serving with Session Routing and KEDA

**Day 2 | Duration: ~75 minutes**

## Learning Objectives

- Deploy the vLLM Production Stack (vllm-stack Helm chart) with a load-balancing router in front of two CPU backend pods
- Configure session-based routing so that multi-turn chat requests from the same user always reach the same backend (KV-cache affinity)
- Verify KEDA autoscaling driven by the `vllm:num_requests_waiting` Prometheus metric
- Understand the three-layer architecture: router → backend pods → MinIO-backed model storage

## Architecture

```
                   NodePort 30201
                        │
                  ┌─────▼──────┐
                  │  lmstack   │   ← routes by x-user-id header
                  │  router    │   ← discovers backends via pod labels
                  └──┬──────┬──┘
                     │      │
           ┌─────────▼──┐  ┌▼──────────┐
           │  vLLM pod  │  │  vLLM pod │   ← serving-engine (CPU)
           │  backend-0 │  │  backend-1│   ← model loaded by initContainer
           └────────────┘  └───────────┘
                  ↑                ↑
           emptyDir /model   emptyDir /model
                  ↑                ↑
           mc cp from MinIO  mc cp from MinIO
                  └──────┬─────────┘
                    MinIO s3://models/smollm2-finetuned/
```

The router:
- Receives all inference requests on port 30201
- Reads the `x-user-id` header and consistently hashes the session ID to a backend pod IP
- Polls each backend's `/metrics` endpoint every 15 seconds to track queue depth
- Does NOT hold model weights — it is a pure HTTP proxy

## Prerequisites

- Lab 06 complete: MinIO running in `minio` namespace with model uploaded to `models/smollm2-finetuned/`
- NodePort 30201 in `kind-config.yaml` extraPortMappings (added in Phase 04 setup)
- kube-prometheus-stack running in `monitoring` namespace (from Lab 05)
- KEDA running in `keda` namespace (installed in Lab 05)

:::caution Apple Silicon (arm64) — Required step before proceeding
`lmcache/lmstack-router:v0.1.11` is an amd64-only image. On Apple Silicon Macs, Docker Desktop must emulate it with Rosetta.

**Enable Rosetta:**  Docker Desktop → Settings → General → check "Use Rosetta for x86_64/amd64 emulation on Apple Silicon" → Apply & Restart.

Then pre-load the image to the local KIND registry:
```bash
docker pull --platform linux/amd64 lmcache/lmstack-router:v0.1.11
docker tag lmcache/lmstack-router:v0.1.11 localhost:5001/lmstack-router:v0.1.11
docker push localhost:5001/lmstack-router:v0.1.11
```

The values file already references `kind-registry:5001/lmstack-router` — this step makes that image available inside the cluster without a registry pull.
:::

## Part 1: Memory Prerequisites

Two vLLM backends each request 4 Gi of RAM. Scale down the other serving patterns before installing the router stack.

```bash
# Scale down Pattern A (OCI image) and Pattern B (disk) to free memory
kubectl scale deployment vllm-smollm2 -n llm-serving --replicas=0
kubectl scale deployment vllm-smollm2-disk -n llm-serving --replicas=0

# Verify both are at 0/0 READY
kubectl get deployment -n llm-serving
```

Expected output:

```
NAME                READY   UP-TO-DATE   AVAILABLE
vllm-smollm2        0/0     0            0
vllm-smollm2-disk   0/0     0            0
```

## Part 2: Add the vllm-stack Helm Repository

```bash
helm repo add vllm https://vllm-project.github.io/production-stack
helm repo update

# Confirm 0.1.11 is available
helm search repo vllm/vllm-stack --versions | head -5
```

## Part 3: Review and Complete the Values File

The values file controls every aspect of the router + backend deployment. Open the starter file and fill in the four TODO blanks:

```bash
cat course-code/labs/lab-07/starter/k8s/00-values-vllm-router.yaml
```

The four blanks to fill:

| Field | Hint |
|-------|------|
| `requestGPU:` | This is a CPU-only cluster — zero GPUs on any node |
| `routingLogic:` | We want the same user to reach the same pod across requests |
| `nodePort:` | Check `kind-config.yaml` — which port was added for the router? |
| `serverAddress:` | Run `kubectl get svc -n monitoring -l app.kubernetes.io/name=prometheus -o name` |

:::info Key decisions explained

**`requestGPU: 0`** — The default in the chart is 1. On a CPU-only KIND cluster, any value greater than 0 causes backends to stay in `Pending` indefinitely because no `nvidia.com/gpu` resource exists on any node. This is the most common misconfiguration.

**`routingLogic: session`** — Session routing hashes the `x-user-id` request header to a consistent backend. The same user always reaches the same pod, preserving the KV cache between turns of a conversation. `roundrobin` distributes evenly but breaks KV-cache affinity. `prefixaware` requires the LMCache controller (out of scope for this lab).

**`nodePort: 30201`** — This field was added in chart version 0.1.11. It does not exist in 0.1.10. If you use 0.1.10, the router service will not be accessible on the host.

**`serverAddress`** — KEDA polls Prometheus to watch the `vllm:num_requests_waiting` metric. The address must match the actual Prometheus Service name (set by the Helm release name). In Lab 05 the release was installed as `kps`, making the address `http://kps-kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090`.
:::

<details>
<summary>Solution: Complete values file</summary>

```yaml
# vllm-stack Helm chart values — Lab 07: vLLM Router + Multi-Pod Serving
# Chart version: 0.1.11  (0.1.11 adds routerSpec.nodePort; do NOT use 0.1.10)
# Router image:  kind-registry:5001/lmstack-router  (pre-pushed from Docker Hub)
#
# CRITICAL — requestGPU must be 0 on this CPU-only KIND cluster.
# Omitting requestGPU (or leaving the default 1) causes backends to stay Pending.

servingEngineSpec:
  runtimeClassName: ""

  serviceMonitor:
    enabled: true
    additionalLabels:
      release: kps     # must match kube-prometheus-stack serviceMonitorSelector

  modelSpec:
  - name: "smollm2"
    repository: "schoolofdevops/vllm-cpu-nonuma"
    tag: "0.9.1"
    modelURL: "/model"

    replicaCount: 2
    requestCPU: 4
    requestMemory: "4Gi"
    requestGPU: 0               # Zero GPU — required for CPU-only KIND

    vllmConfig:
      maxModelLen: 4096
      dtype: "float32"
      maxNumSeqs: 1
      extraArgs:
        - "--disable-frontend-multiprocessing"
        - "--served-model-name=smollm2-135m-finetuned"

    env:
    - name: VLLM_TARGET_DEVICE
      value: "cpu"
    - name: VLLM_CPU_KVCACHE_SPACE
      value: "2"
    - name: OMP_NUM_THREADS
      value: "4"
    - name: VLLM_CPU_OMP_THREADS_BIND
      value: "auto"

    initContainer:
      name: model-download
      image: "quay.io/minio/mc:RELEASE.2024-11-21T17-21-54Z"
      command:
        - sh
        - -c
        - |
          set -euo pipefail
          mc alias set minio http://minio.minio:9000 minio minio123
          mc cp --recursive minio/models/smollm2-finetuned/ /model/
          touch /model/READY
      resources:
        requests:
          cpu: 200m
          memory: 128Mi
          ephemeral-storage: 1Gi
        limits:
          cpu: 500m
          memory: 256Mi
          ephemeral-storage: 2Gi
      mountPvcStorage: false
      extraVolumeMounts:
      - name: model
        mountPath: /model

    extraVolumes:
    - name: model
      emptyDir:
        sizeLimit: 1Gi

    extraVolumeMounts:
    - name: model
      mountPath: /model

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

routerSpec:
  repository: "kind-registry:5001/lmstack-router"
  tag: "v0.1.11"
  imagePullPolicy: "IfNotPresent"
  replicaCount: 1
  routingLogic: "session"
  sessionKey: "x-user-id"
  serviceType: NodePort
  nodePort: 30201
  servicePort: 80
  containerPort: 8000
  engineScrapeInterval: 15
  requestStatsWindow: 60
  resources:
    requests:
      cpu: 400m
      memory: 1000Mi
    limits:
      memory: 1000Mi
  startupProbe:
    initialDelaySeconds: 15
    periodSeconds: 10
    failureThreshold: 12
    timeoutSeconds: 10
  livenessProbe:
    initialDelaySeconds: 30
    failureThreshold: 6
    periodSeconds: 10
    timeoutSeconds: 10
  readinessProbe:
    initialDelaySeconds: 30
    failureThreshold: 6
    periodSeconds: 5
    timeoutSeconds: 10
```

</details>

## Part 4: helm template Dry-Run (Pitfall Prevention)

Before installing, verify the chart renders the initContainer correctly:

```bash
helm template vllm-stack vllm/vllm-stack \
  --version 0.1.11 \
  -f course-code/labs/lab-07/solution/k8s/00-values-vllm-router.yaml \
  -n llm-serving \
  | grep -A 20 "initContainers"
```

You should see a block containing `name: model-download` and `mountPath: /model`. If `initContainers` does not appear, see the Troubleshooting section.

## Part 5: Install vllm-stack

```bash
helm install vllm-stack vllm/vllm-stack \
  --version 0.1.11 \
  --namespace llm-serving \
  --create-namespace \
  -f course-code/labs/lab-07/solution/k8s/00-values-vllm-router.yaml \
  --wait \
  --timeout 600s
```

`--wait` blocks until all pods are Ready. CPU model download (~500 MB from MinIO) plus vLLM startup takes 3–8 minutes. Watch progress in a second terminal:

```bash
kubectl get pods -n llm-serving -w
```

You will see the init container `model-download` complete first, then the main `vllm` container start.

## Part 6: Verify the Deployment

```bash
# Router pod (1 expected)
kubectl get pods -n llm-serving -l app.kubernetes.io/component=router

# Backend pods (2 expected, both 1/1 Running)
kubectl get pods -n llm-serving -l app.kubernetes.io/component=serving-engine

# Endpoint slice showing 2 backend IPs behind the engine service
kubectl get endpoints -n llm-serving

# Router health check at NodePort 30201
curl -s http://localhost:30201/health
# Expected: {"status":"healthy"}
```

## Part 7: Compare Router vs Plain vLLM (Pattern A)

The router is transparent — it forwards requests to backends and returns responses in the same OpenAI-compatible format.

```bash
# Test via router (NodePort 30201)
curl -s http://localhost:30201/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"smollm2-135m-finetuned","messages":[{"role":"user","content":"What is tooth decay?"}],"max_tokens":50}' \
  | python3 -m json.tool

# Test via plain vLLM Pattern A (NodePort 30200) — same response format
curl -s http://localhost:30200/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"smollm2-135m-finetuned","messages":[{"role":"user","content":"What is tooth decay?"}],"max_tokens":50}' \
  | python3 -m json.tool
```

The `model` field in the response will be `smollm2-135m-finetuned` in both cases (controlled by `--served-model-name` in extraArgs).

## Part 8: Session Routing Demo

Get the router pod name and watch its logs while sending requests:

<Tabs groupId="operating-systems">
<TabItem value="mac" label="macOS / Linux">

```bash
# In Terminal 1: follow router logs
ROUTER_POD=$(kubectl get pods -n llm-serving -l app.kubernetes.io/component=router -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n llm-serving "$ROUTER_POD" -f

# In Terminal 2: send 3 requests with the same session ID
SESSION_ID="dental-session-001"
for i in 1 2 3; do
  echo "--- Request $i ---"
  curl -s http://localhost:30201/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "x-user-id: ${SESSION_ID}" \
    -d "{\"model\":\"smollm2-135m-finetuned\",\"messages\":[{\"role\":\"user\",\"content\":\"Dental hygiene step ${i}\"}],\"max_tokens\":30}" \
    | python3 -m json.tool | grep '"content"'
  sleep 2
done
```

</TabItem>
<TabItem value="windows" label="Windows (PowerShell)">

```powershell
# In Terminal 1: follow router logs
$ROUTER_POD = kubectl get pods -n llm-serving -l app.kubernetes.io/component=router -o jsonpath='{.items[0].metadata.name}'
kubectl logs -n llm-serving $ROUTER_POD -f

# In Terminal 2: send 3 requests with the same session ID
$SESSION_ID = "dental-session-001"
1..3 | ForEach-Object {
  Write-Host "--- Request $_ ---"
  $body = "{`"model`":`"smollm2-135m-finetuned`",`"messages`":[{`"role`":`"user`",`"content`":`"Dental hygiene step $_`"}],`"max_tokens`":30}"
  curl -s http://localhost:30201/v1/chat/completions `
    -H "Content-Type: application/json" `
    -H "x-user-id: $SESSION_ID" `
    -d $body
  Start-Sleep -Seconds 2
}
```

</TabItem>
</Tabs>

In the router logs, look for lines like:

```
Routing request f3c89129 with session id dental-session-001 to http://10.244.1.8:8000
Routing request f8aa3aa1 with session id dental-session-001 to http://10.244.1.8:8000
Routing request 5c6f52f4 with session id dental-session-001 to http://10.244.1.8:8000
```

All three requests route to the same backend IP (`10.244.1.8:8000` in this example). The session key `dental-session-001` is consistently hashed to the same backend for the lifetime of that session.

:::note Why both sessions might hit the same backend
With only 2 backends and low load, consistent hashing may map two different session IDs to the same backend. This is correct — session affinity within a session is guaranteed, but cross-session distribution is probabilistic. Under production load with many sessions, the router balances traffic across backends.
:::

## Part 9: KEDA ScaledObject

```bash
kubectl get scaledobject -n llm-serving
kubectl describe scaledobject -n llm-serving
```

What to verify in the output:

| Field | Expected |
|-------|----------|
| `READY` | `True` |
| `ACTIVE` | `False` (no load yet) or `True` (under load) |
| `SCALETARGETNAME` | `vllm-stack-smollm2-deployment-vllm` (backend Deployment, NOT router) |
| `TRIGGERS` | `prometheus` |
| Conditions `ScaledObjectReady` | `True` — no Prometheus connection errors |

The ScaledObject targets the backend Deployment, not the router. The router runs a fixed 1 replica; only backends scale.

## Part 10: Load Test and Scale-Up Observation

Fire concurrent requests to push `vllm:num_requests_waiting` above the threshold of 5:

```bash
# Fire 20 concurrent requests
for i in $(seq 1 20); do
  curl -s http://localhost:30201/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{"model":"smollm2-135m-finetuned","messages":[{"role":"user","content":"Explain dental care in detail"}],"max_tokens":100}' &
done
wait
```

While requests process, poll the replica count every 15 seconds:

```bash
BACKEND_DEPLOY=$(kubectl get scaledobject -n llm-serving -o jsonpath='{.items[0].spec.scaleTargetRef.name}')
for i in $(seq 1 20); do
  echo "$(date +%H:%M:%S) replicas: $(kubectl get deployment -n llm-serving "$BACKEND_DEPLOY" -o jsonpath='{.status.readyReplicas}')"
  sleep 15
done
```

After KEDA triggers, check the scale event:

```bash
kubectl get events -n llm-serving --field-selector reason=SuccessfulRescale
```

Expected:
```
SuccessfulRescale  New size: 3; reason: external metric s0-prometheus above target
```

:::note 3rd pod may stay Pending
On a resource-constrained KIND cluster (2 workers × ~4 CPU), a 3rd vLLM pod requesting 4 CPU will be Pending. KEDA correctly issued the scale command (HPA event confirms it); the cluster simply lacks capacity to schedule the pod. This is expected in a lab environment.
:::

The scale-down cooldown is 360 seconds. You do not need to wait for scale-down before proceeding to teardown.

## Part 11: Resource Budget

Approximate memory usage when all three pods are running on this KIND cluster:

| Pod | Memory (request) |
|-----|-----------------|
| vllm-stack backend × 2 | 4 Gi each |
| lmstack-router | 1000 Mi |
| MinIO | ~256 Mi |
| kube-prometheus-stack | ~1–2 Gi total |
| KEDA | ~200 Mi |

Total: ~11–12 Gi with both backends running. This is why scaling to 3 backends causes the 3rd to stay Pending — 16 GB laptop + Docker Desktop overhead leaves ~12 GB for workloads.

## Part 12: Teardown

:::warning Do not skip teardown
Running Pattern A, Pattern B, and vllm-stack simultaneously exceeds the 16 GB RAM budget. Always tear down Phase 04 before moving to Phase 05.
:::

```bash
# Step 1: Remove vllm-stack (router + backends + KEDA ScaledObject)
helm uninstall vllm-stack -n llm-serving

# Step 2: Wait for all vllm-stack pods to terminate
kubectl get pods -n llm-serving

# Step 3: Restore Pattern A for Phase 05 baseline
kubectl scale deployment vllm-smollm2 -n llm-serving --replicas=1
kubectl rollout status deployment/vllm-smollm2 -n llm-serving --timeout=600s

# Step 4: Verify Pattern A is serving
curl -s http://localhost:30200/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"smollm2-135m-finetuned","messages":[{"role":"user","content":"hello"}],"max_tokens":20}' \
  | python3 -m json.tool | grep '"content"'
```

Expected cluster state after teardown:

```bash
kubectl get deployment -n llm-serving
# NAME                READY   UP-TO-DATE   AVAILABLE
# vllm-smollm2        1/1     1            1        ← Pattern A restored
# vllm-smollm2-disk   0/0     0            0        ← Pattern B still at 0
```

## Lab Summary

In this lab you:

- Deployed the vLLM Production Stack with a stateless HTTP router in front of two CPU backend pods
- Configured session routing so all requests from `x-user-id: dental-session-001` reach the same backend
- Enabled KEDA autoscaling driven by `vllm:num_requests_waiting` from Prometheus
- Observed the router discover and load-balance across backends using pod IP discovery
- Restored the cluster for Phase 05 by uninstalling the router stack and scaling Pattern A back to 1

## Troubleshooting

**Router pod `exec format error` or `ErrImagePull` with `no match for platform in manifest`**

The router image (`lmcache/lmstack-router:v0.1.11`) is amd64-only. On Apple Silicon, you must enable Rosetta and pre-push the image to the local registry as described in the Prerequisites section.

**KEDA ScaledObject `READY: False` — Prometheus connection failed**

Run:
```bash
kubectl get svc -n monitoring -l app.kubernetes.io/name=prometheus -o name
```
The output (`service/kps-kube-prometheus-stack-prometheus`) gives you the correct service name. The `serverAddress` in your values must be `http://<service-name>.monitoring.svc.cluster.local:9090`. Update the values file and run `helm upgrade`.

**Backend pods stuck in `Pending`**

```bash
kubectl describe pod -n llm-serving <pending-pod-name> | grep -A 5 "Events:"
```
If you see `Insufficient nvidia.com/gpu`, your values have `requestGPU` set to a non-zero value. Set `requestGPU: 0` in the values file and run `helm upgrade`.

**`initContainers` block not present in `helm template` output**

The chart's `servingEngineSpec.extraVolumes` / `extraVolumeMounts` schema may have changed between versions. Verify you are using `--version 0.1.11`. If the problem persists with 0.1.11, use the static backend discovery fallback: deploy two backend Deployments manually (reusing the Pattern B manifest from Lab 06) and configure the router with `serviceDiscovery: static`.

**`vllm:num_requests_waiting` absent from Prometheus**

Verify the ServiceMonitor was created and has the correct selector label:
```bash
kubectl get servicemonitor -n llm-serving
kubectl get servicemonitor -n llm-serving vllm-stack-engine-servicemonitor -o yaml | grep "release:"
```
The label `release: kps` must be present. If missing, add `serviceMonitor.additionalLabels.release: kps` under `servingEngineSpec` in your values file.

**`helm install --wait` times out**

The 600s timeout may be tight if model download + vLLM startup takes longer than expected. Cancel and check pod status:
```bash
kubectl get pods -n llm-serving
kubectl logs -n llm-serving <backend-pod> -c model-download
```
If the init container is still running, wait for it to finish, then re-run without `--wait`.
