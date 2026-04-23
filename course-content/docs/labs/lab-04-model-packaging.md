---
sidebar_position: 5
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Lab 04: Model Packaging (OCI Image)

**Day 1 | Duration: ~20 minutes**

## Learning Objectives

- Understand OCI artifacts as a distribution mechanism for ML models (not just runnable containers)
- Package the merged Smile Dental SmolLM2-135M model weights as a minimal OCI image using `alpine:3.20`
- Push the model image to the local KIND registry
- Understand how Kubernetes `ImageVolume` mounts model images directly into serving pods

## Why OCI for Model Distribution?

The traditional approach is to store model weights in a PVC (PersistentVolumeClaim) or copy them into the serving container image. Both have drawbacks:

- **PVC**: requires storage provisioner, not easily versioned, hard to distribute
- **Copy into serving image**: the vLLM container image + SmolLM2 weights = 10+ GB, slow to push/pull

**OCI artifacts** solve this differently. OCI (Open Container Initiative) defines a standard not just for runnable containers but for any blob of data. We can build a 520 MB image that contains only the model weights — no Python, no CUDA, no runtime — and push it to any container registry.

Kubernetes 1.34+ with the `ImageVolume` feature gate enabled can mount these images directly into pods as read-only volumes. The vLLM serving pod references the model image as a volume, Kubernetes pulls it to the node, and vLLM reads the model files from `/models/model` at startup. This pattern is:

- **Immutable** — each version of the model gets its own image tag (v1.0.0, v1.1.0, ...)
- **Registry-managed** — the same pull/cache/GC mechanics as container images
- **Minimal** — a 5 MB alpine base + 520 MB model = one lean artifact, no Python runtime in the image

## The alpine:3.20 Strategy

Open `course-code/labs/lab-03/solution/Dockerfile.model-asset`:

```dockerfile
FROM alpine:3.20

# Model files will be mounted by vLLM via ImageVolume at /models/model
COPY merged-model/ /model/

# No CMD or ENTRYPOINT — this image is a data volume, not a runnable service
# vLLM reads from /models (mounted via ImageVolume, see lab-04 Deployment YAML)
```

Key design decisions:
- **`FROM alpine:3.20`** — alpine is ~5 MB. We only need a filesystem layer to hold the model files; no shell commands, no Python, no runtime.
- **`COPY merged-model/ /model/`** — copies all 6 model files into the image at `/model/`.
- **No `CMD` or `ENTRYPOINT`** — this image cannot be run as a container in the traditional sense. It exists purely to distribute data. Kubernetes pulls it and mounts its filesystem.

## How ImageVolume Mounting Works

In the vLLM Deployment YAML (from Lab 04), the volume spec looks like:

```yaml
volumes:
  - name: model
    image:
      reference: kind-registry:5001/smollm2-135m-finetuned:v1.0.0
      pullPolicy: IfNotPresent
```

And the volumeMount in the vLLM container:

```yaml
volumeMounts:
  - name: model
    mountPath: /models
    readOnly: true
```

When the pod starts, Kubernetes pulls `smollm2-135m-finetuned:v1.0.0` to the node, extracts its filesystem layer, and bind-mounts it at `/models` in the vLLM container. vLLM finds the model at `/models/model` (the path that was set as `COPY merged-model/ /model/` in the Dockerfile). The mount is read-only — the model files cannot be modified by the serving container.

## Lab Steps

### Step 1: Verify the merged model exists

The model packaging step depends on the merge step completing successfully in Lab 03:

```bash
ls -lh llmops-project/training/merged-model/
```

Expected output (all files must be present):

```
total 514M
-rw-r--r--  config.json                   ~3KB
-rw-r--r--  generation_config.json         1KB
-rw-r--r--  model.safetensors            514MB
-rw-r--r--  special_tokens_map.json        1KB
-rw-r--r--  tokenizer.json                 2MB
-rw-r--r--  tokenizer_config.json          3KB
```

If `model.safetensors` is missing, the merge step in Lab 03 did not complete. Check the merge container logs and retry.

### Step 2: Run the build script

The build script creates a temporary Docker build context (to avoid sending 500 MB of model files from the wrong directory), builds the image, and pushes it to the KIND registry:

<Tabs groupId="operating-systems">
  <TabItem value="mac" label="macOS / Linux">
  ```bash
  # From repo root
  MERGED_MODEL_DIR="./llmops-project/training/merged-model" \
    bash course-code/labs/lab-03/solution/build_model_image.sh
  ```
  </TabItem>
  <TabItem value="win" label="Windows">
  ```powershell
  # From repo root (Git Bash recommended for this script)
  $env:MERGED_MODEL_DIR = ".\llmops-project\training\merged-model"
  bash course-code/labs/lab-03/solution/build_model_image.sh
  ```
  </TabItem>
</Tabs>

Expected output:

```
Building model OCI image: kind-registry:5001/smollm2-135m-finetuned:v1.0.0
  Source model directory: ./llmops-project/training/merged-model
Building Docker image...
[+] Building 23.4s
Pushing to KIND registry...
The push refers to repository [kind-registry:5001/smollm2-135m-finetuned]
v1.0.0: digest: sha256:abcdef... size: 1234

Done! Model image pushed: kind-registry:5001/smollm2-135m-finetuned:v1.0.0

Next step: Deploy vLLM in Lab 04 using this image as an ImageVolume.
```

:::note Build time
The docker build and push takes 1-3 minutes depending on your machine and disk speed. The 520 MB model files are compressed during push.
:::

### Step 3: Understand what build_model_image.sh does

Open `course-code/labs/lab-03/solution/build_model_image.sh` and trace through it:

1. **Validates** that `MERGED_MODEL_DIR` exists before proceeding (guards against Lab 03 not finishing)
2. **Creates a temp directory** with `mktemp -d` — this is the Docker build context
3. **Copies** `Dockerfile.model-asset` and `merged-model/` into the temp dir
4. **Runs `docker build`** with the Dockerfile, tagging as `kind-registry:5001/smollm2-135m-finetuned:v1.0.0`
5. **Pushes** to `kind-registry:5001` — the local registry that your KIND cluster can access
6. **Cleans up** the temp directory via the `trap 'rm -rf "$BUILD_CONTEXT"' EXIT` pattern

## Verification

Verify the image is in the KIND registry:

```bash
# List images with the model name in the registry
docker images | grep smollm2-135m-finetuned
```

Expected:

```
kind-registry:5001/smollm2-135m-finetuned   v1.0.0   sha256:abc...   3 minutes ago   527MB
```

You can also inspect the image layers to confirm it is just alpine + model files:

```bash
docker history kind-registry:5001/smollm2-135m-finetuned:v1.0.0
```

Expected: two layers — the alpine base (~5 MB) and the COPY layer (~520 MB).

## After This Lab

| Artifact | Location |
|----------|----------|
| Model OCI image | `kind-registry:5001/smollm2-135m-finetuned:v1.0.0` |
| Source model | `llmops-project/training/merged-model/` |

**Continue to Lab 05** to deploy vLLM using this image as an ImageVolume. The Deployment YAML references `kind-registry:5001/smollm2-135m-finetuned:v1.0.0` — if the image is not in the registry, the pod will fail to start with `ImagePullBackOff`.
