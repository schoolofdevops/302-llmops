---
sidebar_position: 11
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Lab 11: GitOps with ArgoCD App-of-Apps

**Day 3 | Duration: ~60 minutes**

## Learning Objectives

- Install ArgoCD 9.5.11 (ArgoCD v3.3.9) in the `argocd` namespace accessible at `http://localhost:30700`
- Configure an App-of-Apps root Application that manages four child Applications (vllm, minio, chainlit, observability)
- Demonstrate the GitOps model promotion loop: bump an annotation in Git, push, watch ArgoCD sync and trigger a rolling restart

## Architecture

```
                        GitHub Fork (HTTPS)
                              │
                  ┌───────────▼──────────────┐
                  │   ArgoCD (argocd ns)      │
                  │   polls every 3 minutes   │
                  └───────────┬──────────────┘
                              │ detects diff
                  ┌───────────▼──────────────┐
                  │  smile-dental-apps        │  ← Root App-of-Apps
                  │  (watches gitops/apps/)   │
                  └──┬──────┬──────┬────┬────┘
                     │      │      │    │
              ┌──────▼──┐ ┌─▼──┐ ┌▼──┐ └──▼──────────┐
              │  vllm   │ │minio│ │ chainlit│ │ observability│
              │wave: 10 │ │wave:0│ │wave:10 │ │  wave: 0    │
              │llm-serving│ │minio│ │llm-app│ │  monitoring │
              └──────────┘ └─────┘ └───────┘ └────────────┘
                 ↑ gitops/bases/vllm/    gitops/bases/chainlit/ etc.
```

**Sync wave ordering:** minio (wave 0) and observability (wave 0) deploy first to ensure
model storage is ready; vllm (wave 10) and chainlit (wave 10) deploy after.

## Prerequisites

- Lab 10 complete: KEDA, kube-prometheus-stack 83.4.2, and metrics-server installed
- NodePort 30700 in `kind-config.yaml` extraPortMappings (added in Phase 06 setup — Lab 00)
- At least 14 GB Docker Desktop memory allocation: ArgoCD adds ~512 MB on top of the Lab 10 stack

:::warning RAM budget
Lab 11 adds ArgoCD (~512 MB) on top of the existing Lab 10 stack. Verify Docker Desktop memory allocation is at least 14 GB before starting:

```bash
kubectl top nodes
```

If memory usage is above 80%, scale down unused workloads before continuing.
:::

## Part 1: Install ArgoCD

Run the idempotent install script. It adds the `argo` Helm repo, installs ArgoCD chart 9.5.11
(ArgoCD v3.3.9), and configures the server with a NodePort at 30700.

```bash
bash course-code/labs/lab-11/solution/scripts/install-argocd.sh
```

The script disables several optional components to minimise memory footprint:

| Component | Setting | Reason |
|-----------|---------|--------|
| dex | `dex.enabled=false` | SSO not needed for lab |
| notifications | `notifications.enabled=false` | Reduces footprint |
| applicationSet | `applicationSet.enabled=false` | Not used in this lab |
| TLS | `configs.params."server.insecure"=true` | Plain HTTP on NodePort 30700 |
| Server type | `server.service.type=NodePort` + `nodePortHttp=30700` | Accessible from host |

**Verify ArgoCD pods:**

```bash
kubectl get pods -n argocd
```

Expected output:

```
NAME                                               READY   STATUS    RESTARTS   AGE
argocd-application-controller-0                    1/1     Running   0          2m
argocd-redis-6896d94f98-xxxxx                      1/1     Running   0          2m
argocd-repo-server-6c7c865bdd-xxxxx                1/1     Running   0          2m
argocd-server-6d47fb95df-xxxxx                     1/1     Running   0          2m
```

**Fetch the initial admin password:**

The install script prints the password at the end. You can also retrieve it any time:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

**Access the UI:** Open `http://localhost:30700` in your browser and log in as `admin` with the
password above.

## Part 2: Understanding the GitOps Repo Structure

This lab uses a **subdirectory inside the companion course-code repository** as the GitOps source.
ArgoCD will watch `course-code/labs/lab-11/gitops/` in your GitHub fork.

```
course-code/labs/lab-11/
├── gitops/
│   ├── apps/                          ← Root App-of-Apps watches this directory
│   │   ├── vllm.yaml                  ← Child Application for Pattern A
│   │   ├── minio.yaml                 ← Child Application for MinIO
│   │   ├── chainlit.yaml              ← Child Application for Chainlit UI
│   │   └── observability.yaml         ← Child Application for ServiceMonitor
│   └── bases/
│       ├── vllm/
│       │   ├── 30-deploy-vllm.yaml    ← vLLM Deployment (has gitops/model-version annotation)
│       │   └── 30-svc-vllm.yaml       ← vLLM NodePort Service
│       ├── chainlit/
│       │   ├── 40-deploy-chainlit.yaml
│       │   └── 40-svc-chainlit.yaml
│       ├── minio/
│       │   └── 10-minio-values.yaml   ← MinIO Helm values (reference only)
│       └── observability/
│           └── 50-servicemonitor-vllm.yaml
├── solution/
│   ├── k8s/
│   │   ├── 90-argocd-namespace.yaml
│   │   └── 91-app-of-apps.yaml        ← Root Application manifest
│   └── scripts/
│       ├── install-argocd.sh
│       ├── argocd-login.sh
│       ├── bootstrap-app-of-apps.sh
│       └── demo-promote-vllm-annotation.sh
└── starter/
    └── k8s/
        └── 91-app-of-apps.yaml        ← Starter with TODO placeholder
```

**App-of-Apps pattern explained:**

The root Application (`smile-dental-apps`) watches the `gitops/apps/` directory and creates
Kubernetes `Application` resources for every YAML file found there. Each child Application then
watches its own `gitops/bases/<component>/` directory and syncs the Kubernetes manifests inside it.

This two-level hierarchy lets you manage the entire application stack through a single ArgoCD entry
point while keeping each component's manifests independently version-controlled.

:::caution ArgoCD cannot use `file://` URLs on KIND

The ArgoCD **server runs as a pod inside the cluster**. It cannot access the host filesystem.
Setting `repoURL: file:///path/to/repo` will fail silently — ArgoCD will report an `InvalidSpec`
error because the path does not exist from the pod's perspective.

**Students must push the `course-code` repository (or their fork of `302-llmops`) to GitHub**
before configuring the Application. ArgoCD needs an HTTPS remote URL it can reach from within
the KIND cluster.

Use `https://github.com/<your-fork>/302-llmops.git` — no authentication required for public forks.
For private forks, configure a GitHub Personal Access Token as a repository credential in ArgoCD.
:::

:::note App-of-Apps vs. individual Applications
You can always apply individual Application YAMLs without the App-of-Apps root. The two-level
structure is a best practice for managing multiple components in one place, but it is not required.
For a quick test you can apply `gitops/apps/vllm.yaml` directly with `kubectl apply -f`.
:::

## Part 3: Configure Repo URL and Apply App-of-Apps

### Step 1 — Push the course repo to your GitHub fork

If you have not already forked `schoolofdevops/302-llmops`, do so now:

1. Fork `https://github.com/schoolofdevops/302-llmops` to your GitHub account
2. Add the fork as a remote and push:

```bash
git remote add myfork https://github.com/<your-github-username>/302-llmops.git
git push myfork main
```

### Step 2 — Set `ARGOCD_REPO_URL`

```bash
export ARGOCD_REPO_URL=https://github.com/<your-github-username>/302-llmops.git
```

Replace `<your-github-username>` with your actual GitHub username.

### Step 3 — Apply the App-of-Apps

Run the bootstrap script. It substitutes `<ARGOCD_REPO_URL>` in both the root Application
YAML and all four child Application YAMLs before applying them:

```bash
bash course-code/labs/lab-11/solution/scripts/bootstrap-app-of-apps.sh
```

Alternatively, apply manually:

```bash
# Apply root Application (substitute URL first)
sed "s|<ARGOCD_REPO_URL>|${ARGOCD_REPO_URL}|g" \
  course-code/labs/lab-11/solution/k8s/91-app-of-apps.yaml | kubectl apply -f -

# Apply all 4 child Applications (each carries the same placeholder)
for f in course-code/labs/lab-11/solution/gitops/apps/*.yaml; do
  sed "s|<ARGOCD_REPO_URL>|${ARGOCD_REPO_URL}|g" "$f" | kubectl apply -f -
done
```

**Verify the Applications were created:**

```bash
kubectl get application -n argocd
```

Expected output (after ArgoCD's first sync cycle — may take up to 3 minutes):

```
NAME                SYNC STATUS   HEALTH STATUS
chainlit            Synced        Healthy
minio               Synced        Healthy
observability       Synced        Healthy
smile-dental-apps   Synced        Healthy
vllm                Synced        Healthy
```

:::note Sync waves in action
ArgoCD processes sync waves in ascending order:

- **Wave 0** — `minio` and `observability` sync first. MinIO provides model storage; the
  ServiceMonitor ensures Prometheus scrapes vLLM from the start.
- **Wave 10** — `vllm` and `chainlit` sync only after wave-0 resources are healthy.

This ordering prevents vLLM from starting before its model storage is available.
:::

**View the tree in the ArgoCD UI:**

Open `http://localhost:30700`, navigate to "Applications". You will see `smile-dental-apps` as the
root, with four child Applications branching from it: vllm, minio, chainlit, observability.

## Part 4: Inspect Sync Status

Use the ArgoCD CLI (if installed) or `kubectl` to inspect sync state:

```bash
# List all Applications
argocd app list

# Get detailed sync status for vllm
argocd app get vllm

# Inspect via kubectl
kubectl get application -n argocd
kubectl describe application vllm -n argocd
```

Check that the managed resources are healthy:

```bash
# Verify vLLM Deployment is running
kubectl get deploy vllm-smollm2 -n llm-serving

# Verify the gitops/model-version annotation (the promotion target)
kubectl describe deploy vllm-smollm2 -n llm-serving | grep model-version
```

Expected annotation on the initial deploy:

```
Annotations:  gitops/model-version: initial
```

## Part 5: Model Promotion Demo

GitOps promotion means changing a manifest value in Git — ArgoCD notices the diff during its next
poll cycle and applies it to the cluster. For model versioning, this lab uses a Deployment
annotation as the "version handle".

**The promotion mechanism:**

```
1. Edit gitops/bases/vllm/30-deploy-vllm.yaml
   Change: gitops/model-version: "initial"
   To:     gitops/model-version: "run-20260618-090000"

2. git commit + git push

3. ArgoCD polls GitHub (every ~3 min) → detects annotation change → syncs

4. Kubernetes applies the updated Deployment → rolling restart of vllm-smollm2

5. New pod comes up with the bumped annotation
```

**Run the demo script** (from the repo root):

```bash
bash course-code/labs/lab-11/solution/scripts/demo-promote-vllm-annotation.sh
```

The script:
1. Generates a timestamp (`run-YYYYMMDD-HHMMSS`)
2. Updates the `gitops/model-version` annotation in `30-deploy-vllm.yaml`
3. Commits the change

**Push to GitHub:**

```bash
git push origin HEAD
```

**Trigger ArgoCD sync immediately** (instead of waiting 3 minutes):

```bash
argocd app sync vllm
```

**Watch the rolling restart:**

```bash
kubectl rollout status deploy/vllm-smollm2 -n llm-serving --timeout=300s
```

**Verify the annotation was applied to the running Deployment:**

```bash
kubectl describe deploy vllm-smollm2 -n llm-serving | grep model-version
```

Expected output (with your timestamp):

```
Annotations:  gitops/model-version: run-20260618-090000
```

**Verify the API is still serving:**

```bash
curl http://localhost:30200/v1/models
```

The response should list `smollm2-135m-finetuned` — same endpoint, updated deployment.

:::note ArgoCD 3-minute polling interval
ArgoCD's default sync interval is **3 minutes** when watching a GitHub remote.
The `argocd app sync <name>` command shortcircuits the wait and triggers an immediate sync.

For instructor-led demos, always use `argocd app sync` after pushing to avoid 3-minute pauses.

**GitHub webhooks** (push-triggered sync) require a public ingress endpoint — out of scope for
this KIND lab. The polling-based approach shown here is equivalent for learning purposes.
:::

## Part 6: Patterns B and C with ArgoCD

:::info Managing Patterns B and C with ArgoCD
This lab manages **Pattern A only** (D-08 scope decision). The App-of-Apps approach for
Pattern B (vLLM Router) and Pattern C (KServe) is identical — create child Applications
pointing to `gitops/bases/vllm-router/` or `gitops/bases/kserve/`, and add the same
sync-wave annotations.

This lab focuses on Pattern A to demonstrate the full GitOps promotion loop without the
complexity of managing all three patterns simultaneously on a resource-constrained KIND cluster.
Each pattern adds 4–5 GB of RAM; running all three concurrently exceeds a typical 16 GB laptop.

For production deployments with adequate resources, all three patterns can be managed by a single
App-of-Apps using the same structure shown here.
:::

## Part 7: Teardown

Delete the App-of-Apps. Because `finalizers: [resources-finalizer.argocd.argoproj.io]` is set,
ArgoCD will cascade-delete all managed resources (Deployments, Services, ServiceMonitors) before
removing the Application objects.

```bash
kubectl delete -f course-code/labs/lab-11/solution/k8s/
```

**Verify resources were removed:**

```bash
kubectl get deploy -n llm-serving
kubectl get deploy -n llm-app
kubectl get servicemonitor -n monitoring
```

**Note:** The ArgoCD Helm release itself (in the `argocd` namespace) is **not** deleted by the
above command. ArgoCD remains running for Lab 12 (the Argo Workflows E2E loop reuses it).

To remove ArgoCD entirely (only if not continuing to Lab 12):

```bash
helm uninstall argocd -n argocd
kubectl delete namespace argocd
```

## Lab Summary

| GitOps Component | What ArgoCD Manages | Sync Mechanism |
|-----------------|---------------------|----------------|
| Root Application (`smile-dental-apps`) | 4 child Applications in `argocd` namespace | Watches `gitops/apps/`, `recurse: true` |
| `vllm` Application (wave 10) | `vllm-smollm2` Deployment + NodePort Service in `llm-serving` | Watches `gitops/bases/vllm/` |
| `minio` Application (wave 0) | MinIO Helm values reference in `minio` namespace | Watches `gitops/bases/minio/` |
| `chainlit` Application (wave 10) | `chainlit-ui` Deployment + NodePort Service in `llm-app` | Watches `gitops/bases/chainlit/` |
| `observability` Application (wave 0) | `vllm-monitor` ServiceMonitor in `monitoring` | Watches `gitops/bases/observability/` |
| Model promotion demo | `gitops/model-version` annotation bump triggers rolling restart | `git commit + git push` → ArgoCD poll → kubectl apply |

**Key takeaways:**

- GitOps means the Git repository is the single source of truth for cluster state
- ArgoCD enforces `selfHeal: true` — manual `kubectl apply` changes are reverted on the next sync
- Sync waves (`argocd.argoproj.io/sync-wave`) control deployment ordering across dependent services
- The App-of-Apps pattern scales: add a new component by adding one YAML file to `gitops/apps/`
