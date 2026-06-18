---
sidebar_position: 12
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Lab 12: Argo Workflows — LLM Training Pipeline + Fully Automated E2E Loop

**Day 3 | Duration: ~90 minutes**

:::warning RAM budget
Lab 12 adds Argo Workflows (~300 MB) and runs a training pipeline DAG. All prior Day 3
components (kube-prometheus-stack, KEDA, ArgoCD) should remain running for the E2E loop.
Total footprint: ~12-14 GB. Verify Docker Desktop allocation ≥14 GB:

```bash
kubectl top nodes
```
:::

## Learning Objectives

- Install Argo Workflows 1.0.13 in the `argo` namespace and access the UI at `http://localhost:30800`
- Run a 5-step LLM training DAG (`data-gen → build-index → train → merge → promote`) using a shared PVC workspace — no MinIO required for artifact passing
- Demonstrate the **fully automated E2E LLMOps loop**: a single `git push` triggers the complete chain (ArgoCD applies Workflow CR → Argo executes DAG → `promote` step commits annotation bump via SSH deploy key → ArgoCD redeploys `vllm-smollm2`) without any manual student intervention

## Architecture

```
                                  [single git push]
                                        │
                              ┌─────────▼──────────┐
                              │      ArgoCD         │
                              │   (NodePort 30700)  │
                              │  detects gitops/    │
                              │  pipeline/ change   │
                              └─────────┬──────────┘
                                        │ applies Workflow CR
                              ┌─────────▼──────────┐
                              │   Argo Workflows    │
                              │  (NodePort 30800)   │
                              │  executes 5-step DAG│
                              └────┬───┬────┬───┬──┘
                                   │   │    │   │
                        data-gen   │   │    │   │  promote
                      build-index  │   │    │   │  (alpine/git)
                            train  │   │    │   │  git clone →
                            merge  │   │    │   │  sed bump →
                                   │   │    │   │  git push
                                   └───┴────┴───┘
                                                │
                                     ┌──────────▼──────────┐
                                     │  annotation bumped   │
                                     │  in 30-deploy-vllm  │
                                     └──────────┬──────────┘
                                                │ ArgoCD detects diff
                                     ┌──────────▼──────────┐
                                     │   vllm-smollm2      │
                                     │   rolling restart    │
                                     │   (new model live)   │
                                     └─────────────────────┘
```

---

## Part 1 — Install Argo Workflows

```bash
bash course-code/labs/lab-12/solution/scripts/install-argo-workflows.sh
```

The script is idempotent — safe to run multiple times. It:
- Adds the `argo` Helm repo and installs chart version `1.0.13` (Argo Workflows v4.0.5)
- Exposes the UI on **NodePort 30800**
- Uses `authModes=server` — **no auth required** for lab convenience

:::caution Production note
`authModes=server` disables authentication entirely. This is fine on a local KIND cluster
accessible only on `localhost`. Production deployments **must** use OIDC or SSO.
See the [Argo Workflows auth docs](https://argo-workflows.readthedocs.io/en/latest/argo-server-auth-mode/).
:::

**Verify Argo Workflows is running:**

```bash
kubectl get pods -n argo
```

Expected output:

```
NAME                                                  READY   STATUS    RESTARTS   AGE
argo-workflows-server-xxxxxxxxx-xxxxx                 1/1     Running   0          2m
argo-workflows-workflow-controller-xxxxxxxxx-xxxxx    1/1     Running   0          2m
```

**Access the UI:**

Open **http://localhost:30800** — the Argo Workflows dashboard should load immediately with no login prompt.

---

## Part 2 — SSH Deploy Key Setup (required for automated promote step)

The `promote` step in the LLM pipeline DAG uses an SSH deploy key to push an annotation bump
back to your gitops repo. This is the mechanism that makes the E2E loop **fully automated** —
no manual `git commit` or `kubectl annotate` is needed after the initial `git push`.

### Why SSH and not HTTPS?

The `promote` step runs inside a Kubernetes pod using the `alpine/git` image. Authenticating
with GitHub via HTTPS would require storing a PAT token in a Secret and configuring
`git config credential.helper`. SSH deploy keys are simpler: one Secret, one volume mount,
and the key has write scope limited to a single repo.

### Step 1 — Generate an SSH key (if you don't have one)

```bash
ssh-keygen -t ed25519 -C "argo-promote-key"
# Accept default path: ~/.ssh/id_ed25519
# Leave passphrase empty (Argo pod cannot prompt for passphrase)
```

### Step 2 — Add the public key to your GitHub fork

```bash
cat ~/.ssh/id_ed25519.pub
# Copy the output
```

Then:
1. Go to your GitHub fork of `302-llmops`
2. **Settings → Deploy keys → Add deploy key**
3. Paste the public key
4. Check **"Allow write access"** (required for the promote step to push)
5. Click **Add key**

:::caution SSH key permissions
The promote step copies the Secret to `/root/.ssh/id_rsa` with `chmod 600`. SSH will reject
keys with world-readable permissions (error: `WARNING: UNPROTECTED PRIVATE KEY FILE!`).
The script handles this automatically — the Secret `defaultMode: 0600` and the shell `chmod 600`
in the promote container ensure correct permissions.
:::

### Step 3 — Create the Kubernetes Secret

```bash
bash course-code/labs/lab-12/solution/scripts/setup-deploy-key.sh
# Uses ~/.ssh/id_ed25519 by default (falls back to ~/.ssh/id_rsa)
```

Or manually:

```bash
kubectl create secret generic git-deploy-key \
  --from-file=ssh-privatekey=~/.ssh/id_ed25519 \
  -n argo
```

Verify:

```bash
kubectl get secret git-deploy-key -n argo
```

### Step 4 — Update the GITOPS_REPO_SSH_URL in the WorkflowTemplate

Open `course-code/labs/lab-12/solution/k8s/101-workflowtemplate-pipeline.yaml` and replace
the placeholder in the `promote-step` template:

```yaml
        env:
          - name: GITOPS_REPO_SSH_URL
            # Replace <student-fork> with your GitHub username:
            value: "git@github.com:<student-fork>/302-llmops.git"
```

Example (if your GitHub username is `jdoe`):

```yaml
            value: "git@github.com:jdoe/302-llmops.git"
```

Re-apply the WorkflowTemplate after editing:

```bash
kubectl apply -f course-code/labs/lab-12/solution/k8s/101-workflowtemplate-pipeline.yaml
```

---

## Part 3 — Understanding the LLM Pipeline DAG

### 5-Step DAG Overview

```
data-gen → build-index → train → merge → promote
```

| Step | Template | Image | What it does |
|------|----------|-------|--------------|
| `data-gen` | `run-step` | `python:3.11-slim` | Generates synthetic dental clinic Q&A pairs; writes JSONL to `/workspace/` |
| `build-index` | `run-step` | `python:3.11-slim` | Builds FAISS index from generated data; saves index to `/workspace/` |
| `train` | `run-step` | `python:3.11-slim` | LoRA fine-tuning on SmolLM2-135M; saves adapter weights to `/workspace/` |
| `merge` | `run-step` | `python:3.11-slim` | Merges LoRA adapter into base model; saves merged model to `/workspace/` |
| `promote` | `promote-step` | `alpine/git:latest` | Clones gitops repo via SSH; bumps `gitops/model-version` annotation; commits + pushes |

### Shared PVC Workspace Pattern

All steps 1-4 share the same `PersistentVolumeClaim` (`pipeline-workspace`, 5Gi) mounted
at `/workspace`. This replaces MinIO/S3 for inter-step artifact passing:

```
step 1 → writes /workspace/data/training.jsonl
step 2 → reads /workspace/data/ → writes /workspace/index/
step 3 → reads /workspace/data/ → writes /workspace/adapter/
step 4 → reads /workspace/adapter/ → writes /workspace/merged-model/
step 5 → reads nothing from PVC → clones gitops, pushes annotation bump
```

:::info Why nodeSelector?
All steps use `nodeSelector: kubernetes.io/hostname: llmops-kind-worker`. This is
**required** when using `accessModes: ReadWriteOnce` (RWO) on KIND. RWO PVCs can only
be mounted on a single node at a time. Pinning all DAG steps to the same worker node
prevents `Multi-Attach error` when steps run concurrently or the scheduler picks
a different node.
:::

:::info No eval gate
The eval gate (DeepEval model quality checks) from v0.19.0 has been moved to the
`303-AgentOps` course. The LLMOps pipeline here teaches **orchestration** — data flow,
artifact passing, and the GitOps promotion loop. Evaluation of response quality is an
AgentOps concern that requires agent infrastructure (tools, memory, trace logging).
:::

### The Promote Step — Key Innovation for D-12

The `promote` step is what makes this E2E loop **fully automated**. Instead of a manual
annotation bump, the `alpine/git` container:

1. Reads the SSH deploy key from the `git-deploy-key` Secret (mounted as a volume)
2. Clones your gitops repo over SSH
3. Runs `sed` to bump `gitops/model-version: "run-<TIMESTAMP>"` in `30-deploy-vllm.yaml`
4. Commits with message: `ops: automated promote — model-version run-<TIMESTAMP> [skip ci]`
5. Pushes to `origin HEAD`

ArgoCD detects the annotation diff on its next poll (≤3 minutes) and triggers a rolling
restart of `vllm-smollm2`. The initContainer then pulls the new merged model from MinIO.

---

## Part 4 — Apply Pipeline Manifests

```bash
# Shared PVC for inter-step artifact passing
kubectl apply -f course-code/labs/lab-12/solution/k8s/100-pvc-pipeline-workspace.yaml

# ServiceAccount + Role (scoped secrets access) + RoleBinding
kubectl apply -f course-code/labs/lab-12/solution/k8s/100-argo-workflows-rbac.yaml

# 5-step WorkflowTemplate (after updating GITOPS_REPO_SSH_URL)
kubectl apply -f course-code/labs/lab-12/solution/k8s/101-workflowtemplate-pipeline.yaml
```

Verify the WorkflowTemplate is registered:

```bash
kubectl get workflowtemplate -n argo
```

Expected:

```
NAME           AGE
llm-pipeline   10s
```

---

## Part 5 — Trigger the Pipeline

### Option A — Via script (recommended)

```bash
bash course-code/labs/lab-12/solution/scripts/trigger-pipeline.sh
```

### Option B — Via kubectl directly

```bash
kubectl create -f course-code/labs/lab-12/solution/k8s/102-workflow-run.yaml
```

:::note kubectl create vs kubectl apply
We use `kubectl create` (not `apply`) because the Workflow CR uses `generateName`.
Each run creates a new unique Workflow resource (e.g., `llm-pipeline-qctzs`).
`kubectl apply` would fail on a `generateName` resource because it requires
`metadata.name` to track state. Use `kubectl create` for every pipeline run.
:::

### Watch the Pipeline

**CLI:**

```bash
# Watch Workflow phase
kubectl get workflow -n argo -w

# Stream logs from all step pods
kubectl logs -n argo -l workflows.argoproj.io/workflow -f --tail=50
```

**Argo Workflows UI:**

Open **http://localhost:30800** → click the Workflow in the left panel → observe the
5-node DAG execution in real time. Each node turns green (Succeeded) as it completes.

**Sample output (kubectl get workflow):**

```
NAME                   STATUS      AGE
llm-pipeline-qctzs    Running     30s
llm-pipeline-qctzs    Succeeded   4m12s
```

**Expected behavior (demo mode):**

In the lab, the Python scripts at `/workspace/scripts/0*.py` don't exist — steps 1-4
will show `Error` (exit 2: file not found). The DAG execution structure is what matters
for this lab. The promote step will succeed if your SSH deploy key is configured correctly.

For a real training pipeline, copy your scripts to the worker node's hostPath and mount
them into the PVC before triggering the workflow.

---

## Part 6 — E2E Loop: Fully Automated Chain

This section demonstrates the **complete automated LLMOps loop**. A single `git push`
triggers the entire chain — no manual annotation bump, no manual ArgoCD sync trigger,
no manual kubectl commands.

### Concept Diagram

```
Student git push
      │
      ▼
  GitHub fork (gitops/pipeline/102-workflow-run.yaml added)
      │
      ▼ ArgoCD polls (≤3 min) or argocd app sync
  ArgoCD detects new file in gitops/pipeline/
      │
      ▼ kubectl create (CreateOnly sync option)
  Argo Workflows controller picks up Workflow CR
      │
      ▼ executes 5-step DAG
  data-gen → build-index → train → merge
      │
      ▼ promote step (alpine/git)
  git clone → sed bump model-version → git commit → git push
      │
      ▼ ArgoCD polls (≤3 min) or argocd app sync vllm
  ArgoCD detects annotation change in 30-deploy-vllm.yaml
      │
      ▼ rolling restart
  vllm-smollm2 pod restarts → initContainer downloads merged model from MinIO
      │
      ▼
  New model is live → curl localhost:30200/v1/models
```

### Step 1 — Add the Workflow CR to your gitops pipeline directory

```bash
mkdir -p course-code/labs/lab-11/solution/gitops/pipeline/

cp course-code/labs/lab-12/solution/k8s/102-workflow-run.yaml \
   course-code/labs/lab-11/solution/gitops/pipeline/
```

### Step 2 — Commit and push to your GitHub fork

```bash
git add course-code/labs/lab-11/solution/gitops/pipeline/

git commit -m "ops: add pipeline Workflow CR to trigger LLM retrain"

git push origin HEAD
```

### Step 3 — ArgoCD picks up the change and triggers the Workflow

Force an immediate sync (optional — ArgoCD polls every 3 minutes automatically):

```bash
argocd app sync smile-dental-apps
```

Watch the Workflow execute:

```bash
kubectl get workflow -n argo -w
```

### Step 4 — Wait for the promote step to complete

When the `promote` step finishes, it pushes an annotation bump to your gitops repo.
ArgoCD will detect the annotation change:

```bash
# Force sync of the vllm Application (or wait ≤3 min for automatic poll)
argocd app sync vllm

# Watch the rolling restart
kubectl rollout status deploy/vllm-smollm2 -n llm-serving --timeout=120s
```

### Step 5 — Verify the new model is live

```bash
# vLLM API shows updated model
curl http://localhost:30200/v1/models

# Check the annotation was bumped by the promote step
kubectl describe deploy vllm-smollm2 -n llm-serving | grep model-version

# Verify the promote commit in git log
git log --oneline course-code/labs/lab-11/solution/gitops/bases/vllm/
# Should show: "ops: automated promote — model-version run-<TIMESTAMP> [skip ci]"
```

:::note Automatic vs manual sync
ArgoCD polls every 3 minutes. The promote step commits immediately after the `merge`
step completes. For a faster live demo, run `argocd app sync vllm` after the promote
step finishes rather than waiting for the automatic poll.
:::

:::info What makes this fully automated (D-12)
A single student action — `git push` with the Workflow CR in `gitops/pipeline/` — triggers
the complete LLMOps chain:
1. ArgoCD applies the Workflow CR (CreateOnly sync option prevents re-submission)
2. Argo Workflows runs the 5-step DAG
3. The `promote` step pushes the annotation bump automatically via the SSH deploy key
4. ArgoCD redeploys `vllm-smollm2` with the new model

No manual annotation bump is needed at any step. The SSH deploy key gives the promote step
write access to exactly one repo — yours — with the minimum required privilege.
:::

---

## Part 7 — Teardown

```bash
# Delete all lab-12 Kubernetes resources
kubectl delete -f course-code/labs/lab-12/solution/k8s/

# Remove the SSH deploy key Secret
kubectl delete secret git-deploy-key -n argo --ignore-not-found=true

# Optionally uninstall Argo Workflows (needed if this is the last lab)
helm uninstall argo-workflows -n argo

# Optionally uninstall ArgoCD (needed if this is the last lab)
helm uninstall argocd -n argocd

# Note: kube-prometheus-stack + KEDA can stay running
# Observability and autoscaling remain useful for ongoing cluster inspection
```

---

## Lab 12 Summary

| What you did | Result |
|---|---|
| Installed Argo Workflows 1.0.13 | UI running at http://localhost:30800 |
| Applied `llm-pipeline` WorkflowTemplate | 5-step DAG registered in argo namespace |
| Created `git-deploy-key` Secret | SSH key available to promote step container |
| Triggered pipeline with `kubectl create` | Workflow CR submitted; DAG executed |
| Wired `102-workflow-run.yaml` into gitops/pipeline/ | Single git push now triggers full chain |

## Phase 06 Summary — Production Operations Layer

You have now completed **Phase 06: Production Operations Layer** — the final phase of the
**LLMOps & Kubernetes** course. Here is everything deployed across Day 3:

| Component | Namespace | Port | What it provides |
|-----------|-----------|------|-----------------|
| kube-prometheus-stack 83.4.2 | monitoring | 30090 | Prometheus + Grafana dashboards |
| KEDA 2.19.0 | keda | — | Event-driven autoscaling (3 patterns) |
| metrics-server | kube-system | — | CPU/memory metrics for HPA |
| ArgoCD 9.5.11 | argocd | 30700 | GitOps continuous delivery (App-of-Apps) |
| Argo Workflows 1.0.13 | argo | 30800 | DAG-based LLM pipeline orchestration |

**The full LLMOps lifecycle on Kubernetes:**

```
Lab 00  → KIND cluster + registry
Lab 01  → Synthetic data + RAG retriever (FAISS + FastAPI)
Lab 02  → CPU LoRA fine-tuning (SmolLM2-135M + PEFT)
Lab 03  → OCI model packaging (ImageVolume)
Lab 04  → Pattern A: plain vLLM Deployment + Chainlit UI
Lab 05  → Observability: Prometheus + Grafana + ServiceMonitor
Lab 06  → Pattern A (disk): MinIO model storage + initContainer
Lab 07  → Pattern B: vLLM Router multi-pod serving
Lab 08  → Pattern C: KServe InferenceService + ClusterServingRuntime
Lab 09  → Serving pattern selection guide
Lab 10  → Autoscaling: KEDA (3 patterns) + HPA + load testing
Lab 11  → GitOps: ArgoCD App-of-Apps + model promotion
Lab 12  → Automated pipeline: Argo Workflows DAG + SSH promote + E2E loop
```

You have built a production-grade LLM serving platform from scratch — data generation,
fine-tuning, three serving patterns, observability, autoscaling, GitOps, and fully
automated model retraining — all on CPU-only Kubernetes running on your laptop.

For the next course in this series (**AgentOps on Kubernetes** — `303-agentops`), the
foundation continues with agentic tool-calling, DeepEval quality gates, MCP servers,
Kubernetes Agent Sandbox, and OTEL trace observability.

**Reference:** See [Lab 09 — Serving Pattern Decision Guide](./lab-09-serving-decision) for
a summary of when to choose Pattern A (plain vLLM), Pattern B (vLLM Router), or
Pattern C (KServe InferenceService).
