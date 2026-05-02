---
sidebar_position: 1
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Lab 00: Cluster Setup

**Day 1 | Duration: ~30 minutes**

## Learning Objectives

- Create a 3-node KIND cluster with ImageVolume feature gates enabled
- Create the five namespaces used throughout the course
- Verify the cluster is healthy and ready for workloads

---

## Step 1: Install required tools

You need these tools installed before starting. Run `preflight-check.sh` in Step 3 to verify everything is present.

| Tool | Version | Install |
|------|---------|---------|
| **Docker Desktop** | 4.x+ | [docker.com/get-started](https://www.docker.com/get-started/) |
| **kind** | 0.23+ | `brew install kind` / [kind.sigs.k8s.io](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) |
| **kubectl** | 1.29+ | `brew install kubectl` / [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |
| **helm** | 3.x | `brew install helm` / [helm.sh](https://helm.sh/docs/intro/install/) |
| **git** | any | pre-installed on macOS/Linux |

:::warning Docker Desktop memory setting
Go to **Docker Desktop → Settings → Resources → Memory** and set it to at least **12 GB**. The vLLM serving pod (Lab 05) needs 5 GB by itself. With the KIND cluster, registry, and other pods running, 12 GB is the safe minimum.
:::

---

## Step 2: Clone the course repository

```bash
git clone https://github.com/schoolofdevops/302-llmops.git
cd 302-llmops
```

Create the project workspace directory first. This is where training data, model checkpoints, and merged models will be stored — the KIND cluster mounts it into all nodes at `/mnt/project`. It is git-ignored so your learner artifacts never pollute the repo.

```bash
mkdir -p llmops-project
```

:::important All commands from this point assume you are inside the `302-llmops/` directory (the repository root). Do not `cd` into subdirectories unless a step explicitly says so.
:::

---

## Step 3: Run the preflight check

The preflight check verifies that all required tools are installed, Docker has enough memory, and no conflicting ports are in use.

<Tabs groupId="operating-systems">
  <TabItem value="macos" label="macOS / Linux">

```bash
bash course-code/labs/lab-00/starter/scripts/preflight-check.sh
```

  </TabItem>
  <TabItem value="windows" label="Windows">

```powershell
.\course-code\labs\lab-00\starter\scripts\preflight-check.ps1
```

  </TabItem>
</Tabs>

Expected output (all PASS or WARN — no FAIL):

```
=============================================
 LLMOps Course — Preflight Check
=============================================

==> System: Darwin
==> Checking Docker...
[PASS] Docker is running
[PASS] Docker memory: 16GB (recommended >= 12GB)
[PASS] Disk space: 45GB available on Docker root

==> Checking required tools...
[PASS] kind found: /usr/local/bin/kind
[PASS] kubectl found: /usr/local/bin/kubectl
[PASS] helm found: /usr/local/bin/helm
[PASS] docker found: /usr/local/bin/docker

==> Checking port availability...
[PASS] Port 80 is available
[PASS] Port 8000 is available
[PASS] Port 30000 is available
[PASS] Port 32000 is available

==> Checking for stale KIND clusters...
[PASS] No stale llmops-kind cluster found

=============================================
==> Preflight summary: 10 passed, 0 warnings, 0 failed
=============================================
Your environment is ready. Proceed to Lab 00: Cluster Setup.
```

If you see **[FAIL]** items, fix them before continuing. **[WARN]** items (e.g., memory at 8 GB instead of 12 GB) will not block this lab but may cause issues in Labs 04–06.

---

## Step 4: Bootstrap the KIND cluster

The bootstrap script does four things in order:
1. Adds `127.0.0.1 kind-registry` to `/etc/hosts` (requires sudo — you will be prompted once)
2. Starts the local container registry (`kind-registry:5001`)
3. Creates the 3-node KIND cluster with ImageVolume feature gates
4. Creates the 5 course namespaces

<Tabs groupId="operating-systems">
  <TabItem value="macos" label="macOS / Linux">

```bash
bash course-code/labs/lab-00/starter/scripts/bootstrap-kind.sh
```

  </TabItem>
  <TabItem value="windows" label="Windows">

```bash
bash course-code/labs/lab-00/starter/scripts/bootstrap-kind.sh
```

  </TabItem>
</Tabs>

The script will prompt you for your project directory path:

```
Detected REPLACE_HOST_PATH in kind-config.yaml.
Please enter the absolute path to your project directory.
This is the directory where your lab files will live on your machine.

Project directory path (e.g. /Users/yourname/llmops-project):
```

Enter the **absolute path** to the `llmops-project` directory you created in Step 2. To get the absolute path:

```bash
# Run this to see the full path to your current directory
pwd
# Output example: /Users/yourname/courses/llmops/302-llmops
# Your llmops-project absolute path would be:
# /Users/yourname/courses/llmops/302-llmops/llmops-project
```

:::tip
On macOS/Linux you can also use `$(pwd)/llmops-project` but type the full path to avoid any issues.
:::

Expected output after bootstrap completes (~3-5 minutes):

```
=============================================
 LLMOps — Bootstrap KIND Cluster
=============================================

==> Adding 127.0.0.1 kind-registry to /etc/hosts (requires sudo)...
Password:
Added 127.0.0.1 kind-registry to /etc/hosts

==> Setting up local container registry (kind-registry:5001)...
Registry started: kind-registry on port 5001

==> Creating KIND cluster: llmops-kind
Creating cluster "llmops-kind" ...
 ✓ Ensuring node image (kindest/node:v1.34.0) 🖼
 ✓ Preparing nodes 📦 📦 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-llmops-kind"

==> Connecting registry to KIND network...
==> Verifying cluster nodes...
NAME                          STATUS   ROLES           AGE   VERSION
llmops-kind-control-plane     Ready    control-plane   30s   v1.34.0
llmops-kind-worker            Ready    <none>          10s   v1.34.0
llmops-kind-worker2           Ready    <none>          10s   v1.34.0

==> Creating namespaces...
namespace/llm-serving created
namespace/llm-app created
namespace/monitoring created
namespace/argocd created
namespace/argo-workflows created

=============================================
 Cluster ready: llmops-kind
 Run: kubectl get nodes
=============================================
```

---

## Step 5: Verify

```bash
# 3 nodes, all Ready
kubectl get nodes
```

Expected:
```
NAME                          STATUS   ROLES           AGE   VERSION
llmops-kind-control-plane     Ready    control-plane   2m    v1.34.0
llmops-kind-worker            Ready    <none>          2m    v1.34.0
llmops-kind-worker2           Ready    <none>          2m    v1.34.0
```

```bash
# All 5 course namespaces present
kubectl get namespaces | grep -E "llm-serving|llm-app|monitoring|argocd|argo-workflows"
```

Expected:
```
argocd              Active   1m
argo-workflows      Active   1m
llm-app             Active   1m
llm-serving         Active   1m
monitoring          Active   1m
```

```bash
# Registry reachable from host
curl -s http://kind-registry:5001/v2/
# Expected: {}
```

---

## Troubleshooting

**`kind-registry: Name or service not known`**
The bootstrap script adds `kind-registry` to `/etc/hosts` via sudo. If this step was skipped or failed, add it manually:
```bash
echo "127.0.0.1 kind-registry" | sudo tee -a /etc/hosts
```

**Nodes stuck in `NotReady`**
Wait 30 seconds and re-run `kubectl get nodes`. The CNI plugin needs a moment after cluster creation.

**`ERROR: Merged model directory not found`** (in later labs)
Make sure you entered the correct absolute path during bootstrap. The cluster must be able to mount `llmops-project/` at `/mnt/project`. Verify with:
```bash
kubectl run test-mount --image=busybox --restart=Never --rm -it \
  --overrides='{"spec":{"nodeName":"llmops-kind-worker"}}' \
  -- ls /mnt/project
# Should show: (empty or existing files)
```

---

## After This Lab

| Resource | State |
|----------|-------|
| KIND cluster `llmops-kind` | Running, 3 nodes, ImageVolume enabled |
| Local registry | `kind-registry:5001` |
| Namespaces | `llm-serving`, `llm-app`, `monitoring`, `argocd`, `argo-workflows` |
| Project workspace | `./llmops-project/` (mounted at `/mnt/project` in all nodes) |

**Continue to Lab 01** to generate the Smile Dental synthetic training dataset.
