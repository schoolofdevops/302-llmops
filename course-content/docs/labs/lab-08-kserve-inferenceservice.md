---
sidebar_position: 9
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Lab 08: KServe InferenceService — Production Model Serving with Custom Runtime

**Day 2 | Duration: ~90 minutes**

## Learning Objectives

- Install KServe v0.18.0 in RawDeployment mode on a KIND cluster (cert-manager + Gateway API CRDs + KServe Helm charts)
- Register a custom `ClusterServingRuntime` wrapping the `schoolofdevops/vllm-cpu-nonuma:0.9.1` CPU image
- Deploy an `InferenceService` that downloads the fine-tuned model from MinIO via an emptyDir initContainer and reaches `READY: True`
- Expose the InferenceService predictor at NodePort 30202 using a separate NodePort Service (the correct pattern for KIND)
- Understand why KServe is a third serving pattern alongside plain Deployment (Pattern A) and vLLM Router (Pattern C)

## Architecture

```
                 NodePort 30202
                      │
            ┌─────────▼──────────┐
            │  smollm2-nodeport  │  ← Separate NodePort Service (our creation)
            │  Service (port 80) │    selects pods via KServe label
            └─────────┬──────────┘
                      │
            ┌─────────▼──────────┐
            │  smollm2-predictor │  ← Deployment managed by KServe controller
            │  Pod (llm-serving) │    KServe owns this Service (ClusterIP)
            └──┬─────────────────┘
               │
       ┌───────▼───────┐
       │  model-download│  ← initContainer: mc cp from MinIO
       │  initContainer │    models/smollm2-finetuned/ → /mnt/model
       │  (runs first)  │    writes /mnt/model/READY sentinel
       └───────────────┘
               │ emptyDir /mnt/model
       ┌───────▼───────┐
       │ kserve-container │  ← schoolofdevops/vllm-cpu-nonuma:0.9.1
       │  (vLLM server)   │    polls for /mnt/model/READY, then serves on port 8000
       └──────────────────┘
               ↑
    ClusterServingRuntime: vllm-cpu-smollm2
    (defines the container spec cluster-wide;
     KServe controller merges with InferenceService)

KServe control-plane (kserve namespace):
  ├─ kserve-controller-manager (watches InferenceService CRDs)
  ├─ kserve-webhook-server (mutating admission webhook)
  └─ cert-manager (cert provisioner for webhook TLS)
```

## Prerequisites

- Lab 07 complete: Pattern A (`vllm-smollm2`) scaled to 0, Pattern B (`vllm-smollm2-disk`) scaled to 0, MinIO running in `minio` namespace with model at `models/smollm2-finetuned/`
- NodePort 30202 in `kind-config.yaml` extraPortMappings (added in Phase 05 setup)
- At least 8 GB free RAM on the KIND cluster (KServe control-plane adds ~1–1.5 GB; predictor pod requests 4 Gi)

:::caution Apple Silicon (arm64) — Read before proceeding

The built-in KServe HuggingFace serving runtime (`kserve-huggingfaceserver`) is **amd64-only** at KServe v0.18. If you attempt to use the default runtime on Apple Silicon, the predictor pod will fail with `exec format error` or `ImagePullBackOff`.

This lab uses a **custom `ClusterServingRuntime`** wrapping `schoolofdevops/vllm-cpu-nonuma:0.9.1` — a stripped-down CPU-only vLLM image that is already verified to work on arm64 via Docker Desktop Rosetta emulation (first validated in Lab 07).

**Enable Rosetta (if not already enabled from Lab 07):** Docker Desktop → Settings → General → check "Use Rosetta for x86_64/amd64 emulation on Apple Silicon" → Apply & Restart.

No additional image pre-pull is needed — `schoolofdevops/vllm-cpu-nonuma:0.9.1` was already cached on your KIND cluster during Lab 07.
:::

:::warning RAM budget — verify before starting
KServe control-plane (controller + cert-manager pods) adds approximately 1–1.5 GB of memory requests. The predictor pod requests 4 Gi. Verify your cluster has at least 8 GB free before proceeding.

```bash
kubectl top nodes
```

If memory is above 80%, scale down any remaining workloads before continuing.
:::

## Part 1: Memory Prerequisites

Scale down Pattern A and Pattern B before installing KServe. The KServe predictor pod will need 4 Gi of RAM.

```bash
# Scale down Pattern A (plain Deployment) and Pattern B (disk-loading) to free memory
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

## Part 2: Install cert-manager v1.16.5

KServe's admission webhooks require valid TLS certificates. cert-manager provisions and rotates these certificates automatically. Minimum version for KServe v0.18.0 is cert-manager v1.15.0; this lab pins v1.16.5 (latest stable in the v1.16 series).

<Tabs groupId="operating-systems">
<TabItem value="mac" label="macOS / Linux">

```bash
# Add jetstack Helm repo (official cert-manager source)
helm repo add jetstack https://charts.jetstack.io --force-update

# Install cert-manager with CRDs
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.16.5 \
  --set crds.enabled=true

# Wait for cert-manager webhook to become ready (CRITICAL — Pitfall 8)
# KServe install will fail if webhook is not healthy
kubectl rollout status deployment/cert-manager-webhook \
  -n cert-manager --timeout=120s
```

</TabItem>
<TabItem value="windows" label="Windows (PowerShell)">

```powershell
# Add jetstack Helm repo
helm repo add jetstack https://charts.jetstack.io --force-update

# Install cert-manager with CRDs
helm install cert-manager jetstack/cert-manager `
  --namespace cert-manager `
  --create-namespace `
  --version v1.16.5 `
  --set crds.enabled=true

# Wait for webhook to be ready
kubectl rollout status deployment/cert-manager-webhook `
  -n cert-manager --timeout=120s
```

</TabItem>
</Tabs>

Expected output after the rollout wait:

```
deployment "cert-manager-webhook" successfully rolled out
```

Verify all three cert-manager pods are running:

```bash
kubectl get pods -n cert-manager
# Expected: cert-manager, cert-manager-cainjector, cert-manager-webhook — all 1/1 Running
```

:::info Why the webhook rollout wait matters
`helm install` returns after the cert-manager Deployment is created, not after the webhook is healthy. cert-manager webhooks take 30–60 seconds to become operational on KIND. If you proceed to KServe install immediately, KServe's admission webhooks fail to register, and the controller does not start correctly. The `kubectl rollout status` command blocks until cert-manager-webhook is ready. Do not skip it.
:::

## Part 3: Install Gateway API CRDs v1.2.1

KServe v0.18 requires Gateway API CRDs to be present. This lab installs the CRDs only — no gateway controller is needed because we will disable HTTPRoute creation in the next step.

```bash
# Install Gateway API CRDs (standard channel — 5 CRDs)
# --server-side is required for large CRDs that exceed client-side size limits
kubectl apply --server-side \
  -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml
```

Verify the 5 CRDs were installed:

```bash
kubectl get crd | grep gateway.networking.k8s.io
```

Expected:

```
gatewayclasses.gateway.networking.k8s.io
gateways.gateway.networking.k8s.io
grpcroutes.gateway.networking.k8s.io
httproutes.gateway.networking.k8s.io
referencegrants.gateway.networking.k8s.io
```

:::info Why --server-side?
Gateway API CRDs are large files (>256 KB). The default client-side apply buffers the entire object in memory before sending it to the API server. For large objects this exceeds kubectl's client-side size limit and fails with `metadata.annotations: Too long`. Server-side apply sends the object as a stream — no client-side size limit applies.
:::

## Part 4: Install KServe v0.18.0

KServe ships as two OCI Helm charts on `ghcr.io`:

1. `kserve-crd` — the CustomResourceDefinitions (must install first)
2. `kserve-resources` — the KServe controller and webhooks

<Tabs groupId="operating-systems">
<TabItem value="mac" label="macOS / Linux">

```bash
# Step 1: Install KServe CRDs
helm install kserve-crd oci://ghcr.io/kserve/charts/kserve-crd \
  --version v0.18.0 \
  --namespace kserve \
  --create-namespace

# Step 2: Install KServe controller (RawDeployment mode for KIND)
helm install kserve oci://ghcr.io/kserve/charts/kserve-resources \
  --version v0.18.0 \
  --namespace kserve \
  --set kserve.controller.deploymentMode=RawDeployment
```

</TabItem>
<TabItem value="windows" label="Windows (PowerShell)">

```powershell
# Step 1: Install KServe CRDs
helm install kserve-crd oci://ghcr.io/kserve/charts/kserve-crd `
  --version v0.18.0 `
  --namespace kserve `
  --create-namespace

# Step 2: Install KServe controller (RawDeployment mode for KIND)
helm install kserve oci://ghcr.io/kserve/charts/kserve-resources `
  --version v0.18.0 `
  --namespace kserve `
  --set kserve.controller.deploymentMode=RawDeployment
```

</TabItem>
</Tabs>

:::info OCI Helm chart install fails with 401 or 403?
Some Helm versions require an explicit OCI session before pulling from `ghcr.io`. Run:

```bash
docker logout ghcr.io
```

This clears any stale credentials that block the anonymous pull. Then retry the `helm install` command. If it still fails, pull the chart locally first:

```bash
helm pull oci://ghcr.io/kserve/charts/kserve-crd --version v0.18.0
helm pull oci://ghcr.io/kserve/charts/kserve-resources --version v0.18.0
```
:::

Verify the KServe controller is running:

```bash
kubectl get pods -n kserve
# Expected: kserve-controller-manager with 2/2 Running (manager + kube-rbac-proxy containers)
```

:::info RawDeployment vs Standard
KServe supports two deployment modes:

- **Standard mode** creates an HTTPRoute for each InferenceService and relies on a Gateway API controller (e.g., Envoy Gateway) to reconcile it. KIND has no built-in gateway controller, so HTTPRoutes are created but never reconciled — the InferenceService READY condition blocks forever.
- **RawDeployment mode** creates a Kubernetes Deployment and ClusterIP Service for each predictor, with no HTTPRoute. READY tracks pod readiness only. This is the correct mode for KIND and resource-constrained clusters.

Setting `deploymentMode=RawDeployment` via Helm flag configures the controller's global default. The InferenceService YAML in Part 7 also carries a per-resource annotation as belt-and-suspenders.
:::

## Part 5: Patch inferenceservice-config ConfigMap

KServe's global configuration is stored in the `inferenceservice-config` ConfigMap in the `kserve` namespace. By default, KServe attempts to create HTTPRoutes (ingress) for each InferenceService. On KIND, there is no Gateway API controller to reconcile these routes — this blocks the InferenceService READY condition indefinitely.

Patch the ConfigMap to disable ingress creation:

```bash
kubectl patch configmap/inferenceservice-config -n kserve \
  --type=merge \
  -p '{
    "data": {
      "ingress": "{\"enableGatewayApi\":false,\"kserveIngressGateway\":\"kserve/kserve-ingress-gateway\",\"ingressGateway\":\"knative-serving/knative-ingress-gateway\",\"localGateway\":\"knative-serving/knative-local-gateway\",\"localGatewayService\":\"knative-local-gateway.istio-system.svc.cluster.local\",\"ingressDomain\":\"example.com\",\"ingressClassName\":\"istio\",\"domainTemplate\":\"{{ .Name }}-{{ .Namespace }}.{{ .IngressDomain }}\",\"urlScheme\":\"http\",\"disableIstioVirtualHost\":true,\"disableIngressCreation\":true}"
    }
  }'
```

Then restart the KServe controller to pick up the change:

```bash
kubectl rollout restart deployment/kserve-controller-manager -n kserve
kubectl rollout status deployment/kserve-controller-manager -n kserve --timeout=120s
```

:::info Why the full JSON?
KServe validates the ingress config object on startup and requires certain fields to be present (notably `ingressGateway`). A minimal patch that sets only `disableIngressCreation: true` causes the controller to crash with `invalid ingress config - ingressGateway is required`. The patch above preserves all required fields while adding `"disableIngressCreation": true` and `"disableIstioVirtualHost": true`.
:::

## Part 6: Review and Complete the ClusterServingRuntime

A `ClusterServingRuntime` defines the container image, command, args, and environment variables for a serving runtime. It is cluster-scoped — once registered, any InferenceService in any namespace can reference it.

Open the starter file and fill in the TODO blanks:

```bash
cat course-code/labs/lab-08/starter/k8s/10-clusterservingruntime.yaml
```

The blanks to fill:

| Field | Hint |
|-------|------|
| `image:` | The CPU-optimized vLLM image verified in Lab 07 (schoolofdevops/...) |
| `VLLM_TARGET_DEVICE` value | This is a CPU-only cluster |
| `VLLM_CPU_KVCACHE_SPACE` value | KV-cache space in GB — keep it low (2) to avoid OOM on KIND nodes |
| `OMP_NUM_THREADS` value | Match the CPU request count (4) |
| `VLLM_CPU_OMP_THREADS_BIND` value | Let vLLM auto-detect thread binding |
| cpu/memory requests and limits | Same as the Phase 04 backends (4 CPU / 4Gi req, 4 CPU / 5Gi limit) |

:::info Key decisions explained

**Container name must be `kserve-container`** — KServe's mutating admission webhook identifies the serving container by this exact name. If you use any other name, the webhook cannot inject sidecar resources correctly and the InferenceService will not reconcile.

**`autoSelect: false`** — This prevents KServe from automatically selecting this runtime for InferenceServices that don't explicitly reference it. Because this lab uses `spec.predictor.containers` (not `spec.predictor.model.runtime`), the ClusterServingRuntime is not referenced at deploy time — it defines a convention, not a binding. Auto-select off prevents accidental runtime mismatches.

**`--disable-frontend-multiprocessing`** — Required for CPU mode. Without this flag, vLLM spawns a subprocess for the API frontend, which causes OOM on resource-constrained KIND nodes.
:::

<details>
<summary>Solution: Complete ClusterServingRuntime</summary>

```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: ClusterServingRuntime
metadata:
  name: vllm-cpu-smollm2
spec:
  supportedModelFormats:
    - name: vllm-cpu
      version: "1"
      autoSelect: false   # explicit runtime reference required — avoids auto-select mismatches
  containers:
    - name: kserve-container  # REQUIRED: must be "kserve-container" for KServe webhook recognition
      image: schoolofdevops/vllm-cpu-nonuma:0.9.1
      command:
        - python3
        - -m
        - vllm.entrypoints.openai.api_server
      args:
        - --model=/mnt/model
        - --host=0.0.0.0
        - --port=8000
        - --max-model-len=4096
        - --served-model-name=smollm2-135m-finetuned
        - --dtype=float32
        - --disable-frontend-multiprocessing
        - --max-num-seqs=1
      env:
        - name: VLLM_TARGET_DEVICE
          value: "cpu"
        - name: VLLM_CPU_KVCACHE_SPACE
          value: "2"
        - name: OMP_NUM_THREADS
          value: "4"
        - name: VLLM_CPU_OMP_THREADS_BIND
          value: "auto"
      resources:
        requests:
          cpu: "4"
          memory: 4Gi
        limits:
          cpu: "4"
          memory: 5Gi
      ports:
        - containerPort: 8000
          protocol: TCP
```

</details>

Apply the ClusterServingRuntime:

```bash
kubectl apply -f course-code/labs/lab-08/solution/k8s/10-clusterservingruntime.yaml

# Verify it is registered
kubectl get clusterservingruntime
# Expected: vllm-cpu-smollm2   true    <age>
```

## Part 7: Review and Complete the InferenceService

The `InferenceService` is the CRD that KServe watches to create a predictor Deployment, ClusterIP Service, and (when configured) routing objects. In RawDeployment mode with ingress creation disabled, KServe creates only the Deployment and ClusterIP Service.

Open the starter file:

```bash
cat course-code/labs/lab-08/starter/k8s/20-inferenceservice.yaml
```

The blanks to fill:

| Field | Hint |
|-------|------|
| `serving.kserve.io/deploymentMode` annotation | Per-resource enforcement of the mode set globally via ConfigMap |
| `serving.kserve.io/enable-storage-initialization` annotation | Disable the storage-initializer sidecar (not compatible with our stripped-down image) |
| `initContainers[0].image` | The same mc (MinIO client) image used in Lab 06 |
| `initialDelaySeconds` in readinessProbe | CPU vLLM takes 90–180s to load model — how long before the first probe attempt? |
| `failureThreshold` in readinessProbe | How many consecutive failures before the probe gives up? |

:::info Key design: `spec.predictor.containers` not `spec.predictor.model`

This InferenceService uses `spec.predictor.containers` (the custom predictor pattern) instead of `spec.predictor.model` (the managed model pattern). Here is why:

- `spec.predictor.model` with a `storageUri` triggers KServe's storage-initializer sidecar, which attempts to download the model from an S3/GCS URI using credentials. The stripped-down `schoolofdevops/vllm-cpu-nonuma:0.9.1` image has no `/mnt/models` path and our MinIO instance uses plain HTTP (not the S3 protocol KServe expects). The storage-initializer would fail.
- `spec.predictor.containers` tells KServe "I am providing the complete container spec." No storageUri → no storage-initializer injection. The emptyDir initContainer (same pattern as Lab 06) downloads the model before vLLM starts.

The field path `spec.predictor.initContainers` (not `spec.predictor.podSpec.initContainers`) is confirmed working on KServe v0.18 live cluster — no `podSpec` wrapper required.
:::

:::info Probe tuning for CPU model load

CPU vLLM takes **90–180 seconds** to load the 135M parameter model. Default Kubernetes readiness probe settings assume fast startup:
- Default: `initialDelaySeconds: 10`, `failureThreshold: 3` → pod marked failed after 10+3×10 = 40 seconds
- Required: `initialDelaySeconds: 90`, `failureThreshold: 30` → 90+30×10 = 390 second budget

Without this tuning, the predictor pod enters `CrashLoopBackOff` within 2 minutes — before the model has finished loading.
:::

<details>
<summary>Solution: Complete InferenceService</summary>

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: smollm2
  namespace: llm-serving
  annotations:
    serving.kserve.io/deploymentMode: RawDeployment
    serving.kserve.io/enable-storage-initialization: "false"
spec:
  predictor:
    initContainers:
      - name: model-download
        image: quay.io/minio/mc:RELEASE.2024-11-21T17-21-54Z
        command:
          - sh
          - -c
          - |
            set -euo pipefail
            echo "Configuring MinIO alias..."
            mc alias set minio http://minio.minio:9000 minio minio123
            echo "Downloading model from MinIO..."
            mc cp --recursive minio/models/smollm2-finetuned/ /mnt/model/
            touch /mnt/model/READY
            echo "Model download complete."
        resources:
          requests:
            cpu: 200m
            memory: 128Mi
            ephemeral-storage: 1Gi
          limits:
            cpu: 500m
            memory: 256Mi
            ephemeral-storage: 2Gi
        volumeMounts:
          - name: model
            mountPath: /mnt/model
    containers:
      - name: kserve-container
        image: schoolofdevops/vllm-cpu-nonuma:0.9.1
        command:
          - sh
          - -c
          - |
            until [ -f /mnt/model/READY ]; do
              echo "Waiting for model download..."; sleep 2;
            done
            exec python3 -m vllm.entrypoints.openai.api_server \
              --model=/mnt/model \
              --host=0.0.0.0 \
              --port=8000 \
              --max-model-len=4096 \
              --served-model-name=smollm2-135m-finetuned \
              --dtype=float32 \
              --disable-frontend-multiprocessing \
              --max-num-seqs=1
        env:
          - name: VLLM_TARGET_DEVICE
            value: "cpu"
          - name: VLLM_CPU_KVCACHE_SPACE
            value: "2"
          - name: OMP_NUM_THREADS
            value: "4"
          - name: VLLM_CPU_OMP_THREADS_BIND
            value: "auto"
        ports:
          - containerPort: 8000
            name: http
        resources:
          requests:
            cpu: "4"
            memory: 4Gi
          limits:
            cpu: "4"
            memory: 5Gi
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 90
          periodSeconds: 10
          failureThreshold: 30
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 180
          periodSeconds: 15
          failureThreshold: 10
        volumeMounts:
          - name: model
            mountPath: /mnt/model
    volumes:
      - name: model
        emptyDir:
          sizeLimit: 1Gi
```

</details>

Apply the InferenceService:

```bash
kubectl apply -f course-code/labs/lab-08/solution/k8s/20-inferenceservice.yaml
```

## Part 8: Watch InferenceService Reach READY=True

The InferenceService will transition through several states before reaching READY:

```bash
# Watch the InferenceService status (Ctrl+C when READY=True)
kubectl get inferenceservice smollm2 -n llm-serving --watch
```

Expected progression:

```
NAME       READY   PREV   LATEST   URL   AGE
smollm2    False                         10s
smollm2    False                         30s
smollm2    True           100            8m
```

The READY=True transition typically occurs **5–10 minutes** after apply on a KIND cluster. This time is dominated by model download from MinIO (~500 MB) and vLLM model load into memory.

Watch the pod lifecycle in a separate terminal:

```bash
kubectl get pods -n llm-serving -l serving.kserve.io/inferenceservice=smollm2 -w
```

You will see:
1. `Init:0/1` — model-download initContainer running
2. `PodInitializing` — initContainer completed, main container starting
3. `Running` — vLLM started, loading model (readinessProbe not yet passing)
4. `1/1 Running` — readinessProbe passed, pod is Ready

Once the InferenceService shows `READY=True`, inspect the created resources:

```bash
# KServe-managed Deployment
kubectl get deployment -n llm-serving -l serving.kserve.io/inferenceservice=smollm2

# KServe-managed Service (ClusterIP — do NOT patch this)
kubectl get svc smollm2-predictor -n llm-serving
```

## Part 9: Apply the NodePort Service

KServe's RawDeployment controller manages the `smollm2-predictor` ClusterIP Service. If you patch it to NodePort, the KServe controller immediately reconciles it back to ClusterIP. The patch does not persist.

The correct approach is to create a **separate** NodePort Service that selects the predictor pods directly via the KServe label:

```bash
# Review the NodePort Service
cat course-code/labs/lab-08/solution/k8s/25-svc-nodeport.yaml
```

The service uses selector `serving.kserve.io/inferenceservice: smollm2` — this label is set by KServe on all predictor pods automatically. This selects the correct pods without coupling to the generated pod-name hash.

Apply the NodePort Service:

```bash
kubectl apply -f course-code/labs/lab-08/solution/k8s/25-svc-nodeport.yaml

# Verify
kubectl get svc smollm2-nodeport -n llm-serving
# Expected: TYPE=NodePort, PORT(S)=80:30202/TCP
```

## Part 10: Verify the Deployment

Verify the model list endpoint responds:

```bash
curl -s http://localhost:30202/v1/models | python3 -m json.tool
```

Expected:

```json
{
    "object": "list",
    "data": [
        {
            "id": "smollm2-135m-finetuned",
            "object": "model",
            ...
        }
    ]
}
```

Send a chat completions request:

<Tabs groupId="operating-systems">
<TabItem value="mac" label="macOS / Linux">

```bash
curl -s http://localhost:30202/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "smollm2-135m-finetuned",
    "messages": [{"role": "user", "content": "What is a root canal?"}],
    "max_tokens": 50
  }' | python3 -m json.tool | grep '"content"'
```

</TabItem>
<TabItem value="windows" label="Windows (PowerShell)">

```powershell
$body = '{"model":"smollm2-135m-finetuned","messages":[{"role":"user","content":"What is a root canal?"}],"max_tokens":50}'
curl -s http://localhost:30202/v1/chat/completions `
  -H "Content-Type: application/json" `
  -d $body | python3 -m json.tool | Select-String '"content"'
```

</TabItem>
</Tabs>

Expected: a non-empty `"content"` field with a dental-related response from the fine-tuned SmolLM2 model.

## Part 11: Resource Budget

Approximate memory request footprint when the KServe stack is running:

| Component | Namespace | Memory Requests |
|-----------|-----------|----------------|
| cert-manager (3 pods) | cert-manager | ~300 Mi total |
| kserve-controller-manager | kserve | ~400 Mi |
| smollm2 predictor pod | llm-serving | 4 Gi |
| MinIO | minio | ~256 Mi |
| KServe stack total | — | ~5 Gi |

KServe control-plane (cert-manager + controller) adds approximately 700 Mi in memory requests on top of the predictor pod's 4 Gi. Compare this to Pattern C (vLLM Router): the router alone adds ~1 Gi plus two 4 Gi backend pods = ~9 Gi total for Pattern C vs ~5 Gi for Pattern B (one predictor). KServe's overhead is the control-plane, not the serving pods.

## Part 12: Teardown

:::warning Do not skip teardown
Phase 06 (Production Operations Layer) installs KEDA, ArgoCD, Argo Workflows, and the full observability stack on this same KIND cluster. Running Pattern B (KServe) alongside Phase 06 components will exceed the 16 GB RAM budget. The teardown in this section is **required** before beginning Phase 06.
:::

Run teardown steps in order:

```bash
# Step 1: Delete the InferenceService (removes KServe-managed Deployment + Service)
kubectl delete inferenceservice smollm2 -n llm-serving --ignore-not-found

# Step 2: Delete the separate NodePort Service
kubectl delete svc smollm2-nodeport -n llm-serving --ignore-not-found

# Step 3: Delete the ClusterServingRuntime
kubectl delete clusterservingruntime vllm-cpu-smollm2 --ignore-not-found

# Step 4: Uninstall KServe controller
helm uninstall kserve -n kserve

# Step 5: Uninstall KServe CRDs chart
helm uninstall kserve-crd -n kserve

# Step 6: Remove Gateway API CRDs
kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml \
  --ignore-not-found

# Step 7: Uninstall cert-manager
helm uninstall cert-manager -n cert-manager

# Step 8: Delete the namespaces
kubectl delete ns kserve cert-manager --ignore-not-found
```

After namespace deletion completes, restore Pattern A for Phase 06:

```bash
# Restore Pattern A to 1 replica
kubectl scale deployment vllm-smollm2 -n llm-serving --replicas=1

# Wait for rollout
kubectl rollout status deployment/vllm-smollm2 -n llm-serving --timeout=600s

# Verify Pattern A is serving
curl -s http://localhost:30200/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"smollm2-135m-finetuned","messages":[{"role":"user","content":"hello"}],"max_tokens":20}' \
  | python3 -m json.tool | grep '"content"'
```

Verify cluster headroom is restored:

```bash
kubectl top nodes
# Expected: each node memory < 50% (room for Phase 06 components)

kubectl get ns | grep -E '(kserve|cert-manager)'
# Expected: empty output (both namespaces deleted)

helm list -A
# Expected: NO kserve, kserve-crd, cert-manager releases
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

- Installed KServe v0.18.0 in RawDeployment mode (cert-manager → Gateway API CRDs → KServe CRDs → KServe controller → ConfigMap patch)
- Understood why RawDeployment is required for KIND (no Gateway API controller → Standard mode blocks InferenceService READY state)
- Registered a `ClusterServingRuntime` as the reusable serving container spec for the `schoolofdevops/vllm-cpu-nonuma:0.9.1` CPU image
- Deployed an `InferenceService` using `spec.predictor.containers` to bypass the storage-initializer sidecar and control the full pod spec
- Applied D-11 probe tuning (`initialDelaySeconds: 90`, `failureThreshold: 30`) to prevent CrashLoopBackOff during CPU model load
- Exposed the InferenceService at NodePort 30202 using a separate Service (because KServe continuously reconciles its managed Service back to ClusterIP)
- Compared this CRD-based serving lifecycle with Pattern A (plain Deployment) and Pattern C (vLLM Router) — see Lab 09 for the full decision tree

## Troubleshooting

**InferenceService stays at READY=False after 15 minutes**

```bash
kubectl describe inferenceservice smollm2 -n llm-serving | grep -A 10 "Conditions:"
```

If you see `RoutesReady: False`, the `inferenceservice-config` patch from Part 5 was not applied or the controller was not restarted. Verify:

```bash
kubectl get configmap inferenceservice-config -n kserve -o jsonpath='{.data.ingress}' | python3 -m json.tool | grep disableIngressCreation
# Expected: "disableIngressCreation": true
```

If missing, reapply the patch from Part 5 and restart the controller.

**Predictor pod in `CrashLoopBackOff` within 2 minutes**

Default readiness probe settings cause the pod to be killed before the model loads. Verify the probe settings in your InferenceService YAML:

```bash
kubectl get inferenceservice smollm2 -n llm-serving -o jsonpath='{.spec.predictor.containers[0].readinessProbe}'
# Expected: initialDelaySeconds=90, failureThreshold=30
```

If the values are wrong, delete the InferenceService and reapply with the correct probe settings from the solution file.

**Storage-initializer sidecar injected alongside model-download initContainer**

```bash
kubectl get pod -n llm-serving -l serving.kserve.io/inferenceservice=smollm2 \
  -o jsonpath='{.items[0].spec.initContainers[*].name}'
# Expected: model-download (only one initContainer)
# Problem sign: storage-initializer appears alongside model-download
```

This happens when `spec.predictor.model` is used instead of `spec.predictor.containers`. The storage-initializer webhook does not trigger for `spec.predictor.containers` because there is no `storageUri`. Delete the InferenceService, verify your YAML uses the correct field path, and reapply.

**OCI 403 on `helm install kserve-crd`**

Stale Docker credentials for `ghcr.io` block anonymous pulls. Run:

```bash
docker logout ghcr.io
# Then retry the helm install command
```

**ClusterServingRuntime not selected — "no runtime found for modelFormat"**

This error appears when using `spec.predictor.model.runtime:` with a wrong runtime name, or when `autoSelect: true` but no runtime matches. This lab uses `spec.predictor.containers` directly — the ClusterServingRuntime is NOT referenced in the InferenceService. If you see this error, your YAML accidentally uses `spec.predictor.model` instead of `spec.predictor.containers`.

**`exec format error` or `ImagePullBackOff` on the predictor pod**

```bash
kubectl describe pod -n llm-serving -l serving.kserve.io/inferenceservice=smollm2 \
  | grep -A 5 "Events:"
```

If you see `exec format error` or `no matching manifest for linux/arm64`, you are using a different image than `schoolofdevops/vllm-cpu-nonuma:0.9.1`. The built-in `kserve-huggingfaceserver` image is amd64-only at KServe v0.18. Ensure your ClusterServingRuntime uses the custom CPU image and Docker Desktop Rosetta is enabled.

**cert-manager webhook not ready — KServe install fails**

```bash
kubectl get pods -n cert-manager
# If cert-manager-webhook is not 1/1 Running, wait and retry
kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=120s
```

Do not run `helm install kserve-crd` until cert-manager-webhook shows `1/1 Running`.

**NodePort 30202 accessible but READY=False**

The READY condition tracks pod readiness, not NodePort accessibility. The separate `smollm2-nodeport` Service routes traffic directly to the predictor pods — even while the InferenceService READY condition is transitioning. If you can curl NodePort 30202 and get responses, the service is working correctly even if READY is still False (the InferenceService READY transition may lag pod readiness by a few seconds).
