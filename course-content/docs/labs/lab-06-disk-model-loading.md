---
sidebar_position: 7
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Lab 06: Disk-Based Model Loading with MinIO + initContainer

**Day 2 | Duration: ~60 minutes**

## Learning Objectives

- Install MinIO as an in-cluster S3-compatible object store
- Upload the fine-tuned Smile Dental model from the training artifact to MinIO
- Deploy vLLM using the initContainer download pattern (Pattern B) with emptyDir, sentinel file, and sha256 verification
- Understand when to use OCI ImageVolume (Pattern A) vs disk-based loading (Pattern B)

## Why Disk-Based Loading?

Lab 03 packaged the model as an OCI image (Pattern A). Pattern A is optimal when the model is small (2 GB or less), stable (rare updates), and a container registry is already part of the deployment pipeline. For larger models (greater than 2 GB) or frequent retraining cycles, copying a new OCI layer for each model version is slow and registry-expensive. Pattern B — disk-based loading via MinIO + initContainer — downloads the model from an S3-compatible object store at pod startup. The trade-off is explicit: every pod restart re-downloads the model, but model updates are as simple as overwriting an S3 object.

## Prerequisites

This lab requires NodePorts 30203, 30900, and 30901 in the KIND cluster `extraPortMappings`. These were added to `kind-config.yaml` in the cluster recreate step at the start of Phase 03 (Day 2). If you still have your Day 1 cluster running (from Labs 00-05), you must recreate it before proceeding:

```bash
kind delete cluster --name llmops-kind
kind create cluster --config course-code/labs/lab-00/solution/setup/kind-config.yaml --name llmops-kind
```

Then re-apply the Day 1 manifests (retriever, vLLM Pattern A, Chainlit) before continuing here.

## Part 1: Install MinIO Object Store

MinIO is an S3-compatible object store that runs inside your Kubernetes cluster. In this lab we install it in standalone mode — a single pod with a local PVC — which is sufficient for a course environment.

:::warning Demo-grade credentials
The credentials used in this lab (`minio` / `minio123`) are hardcoded in the course manifests for simplicity. Never use plaintext credentials in production workloads. In production, store credentials in Kubernetes Secrets or use an external secret manager such as HashiCorp Vault or AWS Secrets Manager.
:::

<Tabs groupId="operating-systems">
<TabItem value="mac" label="macOS / Linux">

```bash
# Step 1: Add the MinIO Helm repository
helm repo add minio-official https://charts.min.io/
helm repo update minio-official

# Step 2: Create a dedicated namespace for MinIO
kubectl create namespace minio

# Step 3: Install MinIO chart 5.4.0 using the course values file
helm install minio minio-official/minio \
  --namespace minio \
  -f course-code/labs/lab-06/solution/k8s/10-minio-values.yaml

# Step 4: Wait for the deployment to roll out
kubectl rollout status deployment/minio -n minio

# Step 5: Verify the S3 API is responding (NodePort 30900)
curl -s http://localhost:30900/minio/health/live
# Expected: HTTP 200 (empty body is normal for the health endpoint)
```

</TabItem>
<TabItem value="windows" label="Windows (PowerShell)">

```powershell
# Step 1: Add the MinIO Helm repository
helm repo add minio-official https://charts.min.io/
helm repo update minio-official

# Step 2: Create a dedicated namespace for MinIO
kubectl create namespace minio

# Step 3: Install MinIO chart 5.4.0 using the course values file
helm install minio minio-official/minio `
  --namespace minio `
  -f course-code/labs/lab-06/solution/k8s/10-minio-values.yaml

# Step 4: Wait for the deployment to roll out
kubectl rollout status deployment/minio -n minio

# Step 5: Verify the S3 API is responding (NodePort 30900)
curl http://localhost:30900/minio/health/live
# Expected: HTTP 200
```

</TabItem>
</Tabs>

**Step 6: Open the MinIO Console**

Open your browser and go to: `http://localhost:30901`

Log in with:
- Username: `minio`
- Password: `minio123`

You should see an empty MinIO dashboard. You'll come back here after the upload step to verify the model bucket was created.

**Expected state after Part 1:**
- 1 pod running in the `minio` namespace (`kubectl get pods -n minio`)
- S3 API accessible on `localhost:30900` (HTTP 200 from health endpoint)
- MinIO Console accessible on `localhost:30901`

## Part 2: Upload the Model to MinIO

The `model-uploader` Job uses the same MinIO client (`mc`) image as the initContainer you'll see in Part 3. It mounts the `llmops-project/` directory that all KIND nodes share via Docker bind-mount, and copies the merged model artifact into a MinIO bucket.

:::note ClusterIP vs NodePort for in-cluster communication
The model-uploader Job uses `http://minio.minio:9000` (the ClusterIP Service DNS name, not `localhost:30900`). NodePorts are for reaching services from your laptop's host network. Pods communicate with each other using ClusterIP addresses and DNS. Remember this distinction when writing your own initContainer scripts.
:::

<Tabs groupId="operating-systems">
<TabItem value="mac" label="macOS / Linux">

```bash
# Step 1: Apply the model-uploader Job
kubectl apply -f course-code/labs/lab-06/solution/k8s/20-job-model-uploader.yaml

# Step 2: Wait for the Job to complete (model upload takes ~30-60 seconds on local KIND)
kubectl wait --for=condition=complete job/model-uploader -n llm-app --timeout=300s

# Step 3: Verify the model files are in MinIO
kubectl run verify-mc --rm -it --restart=Never \
  --image=quay.io/minio/mc:RELEASE.2024-11-21T17-21-54Z \
  -- sh -c "mc alias set minio http://minio.minio:9000 minio minio123 && mc ls minio/models/smollm2-finetuned/"
# Expected: model.safetensors (~513 MB) and config files listed
```

</TabItem>
<TabItem value="windows" label="Windows (PowerShell)">

```powershell
# Step 1: Apply the model-uploader Job
kubectl apply -f course-code/labs/lab-06/solution/k8s/20-job-model-uploader.yaml

# Step 2: Wait for the Job to complete
kubectl wait --for=condition=complete job/model-uploader -n llm-app --timeout=300s

# Step 3: Verify the model files are in MinIO
kubectl run verify-mc --rm -it --restart=Never `
  --image=quay.io/minio/mc:RELEASE.2024-11-21T17-21-54Z `
  -- sh -c "mc alias set minio http://minio.minio:9000 minio minio123 && mc ls minio/models/smollm2-finetuned/"
# Expected: model.safetensors (~513 MB) and config files listed
```

</TabItem>
</Tabs>

You can also verify the upload from the MinIO Console (`http://localhost:30901`) by navigating to Object Browser > models > smollm2-finetuned. You should see `model.safetensors` at approximately 513 MB alongside the tokenizer and config files.

## Part 3: Deploy vLLM with initContainer Download (Pattern B)

Pattern B uses an `initContainer` to download the model before the main vLLM container starts. Here is how the pod works:

1. **initContainer (`model-download`)** runs first. It uses `mc` to download all model files from MinIO into a shared `emptyDir` volume mounted at `/model`. After verifying the `sha256` checksum of `model.safetensors`, it writes a sentinel file at `/model/READY` and exits with code 0.
2. **Main container (`vllm`)** starts only after the initContainer exits successfully. It polls for `/model/READY` before launching the vLLM server, providing a belt-and-suspenders guard against race conditions.
3. The `emptyDir` volume exists only for the lifetime of this pod — you will observe what this means in Part 4.

:::warning Memory Budget — Scale Pattern A First
Running both the Pattern A vLLM pod (OCI ImageVolume) and the Pattern B vLLM pod (emptyDir) simultaneously requires approximately 8 GiB for the two vLLM containers alone, which exceeds the available memory on a 16 GB laptop when combined with the rest of the stack.

Scale Pattern A to zero replicas before deploying Pattern B:

```bash
kubectl scale deployment vllm-smollm2 -n llm-serving --replicas=0
```

The Deployment definition is preserved — you can restore Pattern A any time with `--replicas=1`.
:::

<Tabs groupId="operating-systems">
<TabItem value="mac" label="macOS / Linux">

```bash
# Step 1: Scale Pattern A to 0 replicas to free memory for Pattern B
kubectl scale deployment vllm-smollm2 -n llm-serving --replicas=0

# Step 2: Apply the Pattern B Service and Deployment
kubectl apply -f course-code/labs/lab-06/solution/k8s/30-svc-vllm-disk.yaml
kubectl apply -f course-code/labs/lab-06/solution/k8s/30-deploy-vllm-disk.yaml

# Step 3: Watch the initContainer download the model (~30-60 seconds)
kubectl logs -n llm-serving -l app=vllm-disk -c model-download --follow
# Expected output:
#   Configuring MinIO alias...
#   Downloading model...
#   Verifying sha256...
#   sha256 verified. Writing sentinel...
#   Model download complete.

# Step 4: Watch the main vLLM container start (~2-3 minutes after initContainer)
kubectl logs -n llm-serving -l app=vllm-disk -c vllm --follow

# Step 5: Wait for the Deployment to become ready
kubectl rollout status deployment/vllm-smollm2-disk -n llm-serving --timeout=900s

# Step 6: Test Pattern B health and model list
curl -s http://localhost:30203/health
curl -s http://localhost:30203/v1/models | python3 -m json.tool

# Step 7: Send a chat request to Pattern B
curl -s -X POST http://localhost:30203/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"smollm2-135m-finetuned","messages":[{"role":"user","content":"What dental services do you offer?"}],"max_tokens":50}' | python3 -m json.tool
```

</TabItem>
<TabItem value="windows" label="Windows (PowerShell)">

```powershell
# Step 1: Scale Pattern A to 0 replicas to free memory for Pattern B
kubectl scale deployment vllm-smollm2 -n llm-serving --replicas=0

# Step 2: Apply the Pattern B Service and Deployment
kubectl apply -f course-code/labs/lab-06/solution/k8s/30-svc-vllm-disk.yaml
kubectl apply -f course-code/labs/lab-06/solution/k8s/30-deploy-vllm-disk.yaml

# Step 3: Watch the initContainer download the model (~30-60 seconds)
kubectl logs -n llm-serving -l app=vllm-disk -c model-download --follow

# Step 4: Watch the main vLLM container start
kubectl logs -n llm-serving -l app=vllm-disk -c vllm --follow

# Step 5: Wait for the Deployment to become ready
kubectl rollout status deployment/vllm-smollm2-disk -n llm-serving --timeout=900s

# Step 6: Test Pattern B health and model list
curl http://localhost:30203/health
curl http://localhost:30203/v1/models

# Step 7: Send a chat request to Pattern B
$body = '{"model":"smollm2-135m-finetuned","messages":[{"role":"user","content":"What dental services do you offer?"}],"max_tokens":50}'
Invoke-RestMethod -Uri http://localhost:30203/v1/chat/completions `
  -Method Post -ContentType "application/json" -Body $body | ConvertTo-Json -Depth 5
```

</TabItem>
</Tabs>

Pattern B serves the same `smollm2-135m-finetuned` model on NodePort 30203, while Pattern A (when running) serves on 30200. The model files are identical — the difference is entirely in how they reach the pod.

## Part 4: Observe the Re-Download Trade-Off

`emptyDir` is tied to the Pod lifecycle, not the node. When a pod is deleted, recreated, or evicted, the `emptyDir` is wiped and the model must be downloaded again. This is the deliberate trade-off of Pattern B — and the reason Part 3 took several minutes to start.

<Tabs groupId="operating-systems">
<TabItem value="mac" label="macOS / Linux">

```bash
# Step 1: Note the current pod name
kubectl get pods -n llm-serving -l app=vllm-disk

# Step 2: Delete the pod (the Deployment controller will recreate it immediately)
POD=$(kubectl get pods -n llm-serving -l app=vllm-disk -o name | head -1)
kubectl delete $POD -n llm-serving

# Step 3: Watch the new pod's initContainer download the model again
kubectl logs -n llm-serving -l app=vllm-disk -c model-download --follow
# "Downloading model..." appears again — the 517 MB model re-downloads.
# On the local KIND network this takes ~30-60 seconds.
```

</TabItem>
<TabItem value="windows" label="Windows (PowerShell)">

```powershell
# Step 1: Note the current pod name
kubectl get pods -n llm-serving -l app=vllm-disk

# Step 2: Delete the pod
$pod = kubectl get pods -n llm-serving -l app=vllm-disk -o name | Select-Object -First 1
kubectl delete $pod -n llm-serving

# Step 3: Watch the new pod's initContainer
kubectl logs -n llm-serving -l app=vllm-disk -c model-download --follow
```

</TabItem>
</Tabs>

You should see "Downloading model..." appear again in the new pod's logs. The 517 MB model re-downloads from MinIO in approximately 30-60 seconds on the local KIND network.

This is the key trade-off between Pattern A and Pattern B: Pattern B always downloads fresh on pod start; Pattern A loads from the node's image layer cache after the first pull. For a 517 MB model this is noticeable but manageable. For a 7B or 13B model, the re-download cost becomes significant — which is where a PVC-backed approach becomes important.

In production with a PVC, the model would persist across pod restarts and re-downloads would be avoided. Phase 06 (Argo Workflows) uses a PVC-backed MinIO for the training pipeline artifact store — that is where you would use persistent model storage in a real workflow. For this lab, the `emptyDir` re-download makes the trade-off concrete and observable.

## Part 5: Pattern A vs Pattern B — Decision Guide

Now that you have deployed both patterns, here is when to use each:

| Factor | OCI ImageVolume (Pattern A) | Disk-based / MinIO (Pattern B) |
|--------|-----------------------------|-------------------------------|
| Model size | 2 GB or less (fits in a single OCI layer) | Greater than 2 GB (large models exceed practical OCI layer limits for standard registries) |
| Update cadence | Low (model versions promoted as OCI tags) | High (frequent retraining; uploading to S3 is as fast as copying a file) |
| Registry dependency | Requires a container registry (local or cloud) | Requires an S3-compatible object store (MinIO, AWS S3, GCS) |
| Cold-start behavior | Fast (node caches image layers after first pull) | Slower (re-download on every pod start when using emptyDir) |
| Credential management | Image pull secrets | S3 credentials (env var or Kubernetes Secret) |
| Production choice | Immutable model promotion pipeline | Continuous or frequent model updates; large models where OCI layers are impractical |

**Choose Pattern A (OCI ImageVolume) when:**
- The model is 2 GB or less (a single OCI layer, fits the ImageVolume feature)
- Model versions are immutable and change infrequently (weekly or less)
- You already have a container registry in your deployment pipeline
- Fast cold-start is critical (image layers are node-cached after the first pull)

**Choose Pattern B (MinIO + initContainer) when:**
- The model is greater than 2 GB (exceeds practical OCI layer size for standard registries)
- The model is retrained frequently (daily or more) — uploading a new version to S3 does not require a CI/CD rebuild
- You already operate an S3-compatible object store (MinIO, AWS S3, GCS)
- Model updates should not require rebuilding or pushing a container image

Neither pattern is universally superior. The Smile Dental SmolLM2-135M model is only 517 MB, making Pattern A optimal in terms of cold-start performance. We used Pattern B in this lab to learn the initContainer pattern, which scales naturally to 7B, 13B, and larger models where OCI layers become impractical. Both patterns use the same vLLM serving image and expose the same OpenAI-compatible API — the difference is invisible to the Chainlit UI and to any client consuming the API.

## Lab Summary

- Installed MinIO (chart 5.4.0, standalone mode) as an in-cluster S3-compatible object store with NodePort access for the S3 API (30900) and the console UI (30901)
- Uploaded the merged Smile Dental SmolLM2-135M model (517 MB) from the KIND node's shared project directory to the `models/smollm2-finetuned/` bucket using a one-shot Kubernetes Job
- Deployed `vllm-smollm2-disk` (Pattern B) with an initContainer that downloads the model at pod start, verifies sha256, writes a sentinel file, then hands off to the vLLM main container — serving on NodePort 30203
- Observed the emptyDir re-download trade-off by deleting the pod and watching the initContainer run again, and learned the criteria for choosing between OCI ImageVolume (Pattern A) and disk-based loading (Pattern B)
