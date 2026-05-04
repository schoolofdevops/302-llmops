---
sidebar_position: 12
---

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';

# Lab 11: GitOps with ArgoCD

**Day 3 | Duration: ~50 minutes**

{/* Lab 11 — GitOps. App-of-Apps adopts the meaningful subset of the running stack
    under ArgoCD declarative management. D-06 Hybrid scope; D-20 honest scoping note;
    satisfies GITOPS-01 (ArgoCD + App-of-Apps) and GITOPS-02 (git commit triggers sync). */}

## Learning Objectives

By the end of this lab you will:

- Install ArgoCD via Helm chart 9.5.11 (deploys ArgoCD v3.3.9) into namespace `argocd` with a NodePort UI on `:30700`
- Understand the **App-of-Apps** pattern: one root Application creates child Applications, each managing one subsystem
- Adopt the **meaningful subset** of the Day 1+2 stack under GitOps: vLLM, RAG retriever, Chainlit, agent Sandbox, and the Tempo Grafana datasource ConfigMap (D-06 Hybrid scope)
- Use `argocd.argoproj.io/sync-wave` annotations to order syncs (monitoring before workloads, agent before front-door)
- Demonstrate GITOPS-02: change a manifest in `gitops-repo/`, commit, push, watch ArgoCD reconcile the live cluster in ~70 seconds
- Set up an SSH deploy key in the `argo` namespace so Lab 12's pipeline can push back to the gitops-repo

## Prerequisites

- [ ] Lab 10 completed (KEDA + metrics-server installed; vLLM autoscales)
- [ ] A GitHub fork of the companion repo with **write access** (for the deploy-key in Part E and the GITOPS-02 demo in Part F)
- [ ] `git`, `ssh-keygen`, and `base64` available on your shell

:::warning Honest scoping (D-20)
Lab 11 onboards a **meaningful subset** under ArgoCD, not literally all components. Specifically:

- **kube-prometheus-stack** chart stays Helm-managed (size + complexity — out of scope)
- **Tempo + OTEL Collector** Helm releases stay Helm-managed (only their datasource ConfigMap is in gitops)
- **KEDA controller + ScaledObject + HPA** stay imperative (Lab 10 — controllers are infra-of-infra)
- **Argo Workflows controller** stays imperative (Lab 12 will install it imperatively too)
- **Agent Sandbox CRDs** stay imperative (installed in Lab 08); only the CRs (SandboxTemplate, SandboxWarmPool, etc.) are in gitops
- **Secrets** are NEVER in gitops (Hermes API key, Git deploy key, ArgoCD admin)

This is a teaching choice, not a limitation. App-of-Apps as a pattern is shown end-to-end on the workloads layer; refactoring the entire chart-installed stack into GitOps was deemed scope creep. See `gitops-repo/README.md` for the full breakdown.
:::

## Lab Files

```text
course-code/labs/lab-11/solution/
├── scripts/
│   ├── install-argocd.sh            # helm install argo/argo-cd 9.5.11
│   ├── argocd-login.sh              # Optional: argocd CLI login
│   ├── bootstrap-app-of-apps.sh     # kubectl apply the root Application + poll
│   └── demo-promote-vllm-tag.sh     # Part F GITOPS-02 demo (annotation bump + push + observe)
├── k8s/
│   ├── 90-argocd-namespace.yaml
│   ├── 91-app-of-apps.yaml          # The root Application
│   └── 92-ssh-deploy-key-secret.yaml.example  # Template for Lab 12 git-commit-step
└── gitops-repo/                     # What ArgoCD watches
    ├── apps/                        # 5 child Applications (one per subsystem)
    │   ├── monitoring-otel-tempo.yaml   # sync-wave 0
    │   ├── vllm.yaml                    # sync-wave 10
    │   ├── rag-retriever.yaml           # sync-wave 10
    │   ├── agent-sandbox.yaml           # sync-wave 20
    │   └── chainlit.yaml                # sync-wave 30
    ├── bases/                       # K8s manifests each child Application syncs
    │   ├── monitoring/
    │   ├── vllm/
    │   ├── rag-retriever/
    │   ├── chainlit/
    │   └── agent-sandbox/
    └── README.md
```

---

## Part A — Update the gitops-repo URL to your fork

The 5 child Applications and the root Application currently point at `https://github.com/schoolofdevops/302-llmops.git`. If you have forked the companion repo, replace this URL with your fork's URL in all 6 files:

```bash
cd course-code/labs/lab-11/solution
# Find every repoURL reference:
grep -r "repoURL:" gitops-repo/apps/ k8s/91-app-of-apps.yaml
```

Then substitute your fork URL:

```bash
FORK="https://github.com/<your-username>/llmops.git"
for f in gitops-repo/apps/*.yaml k8s/91-app-of-apps.yaml; do
  sed -i.bak "s|https://github.com/.*/302-llmops\.git|${FORK}|" "$f" && rm -f "$f.bak"
done
```

Commit + push to your fork before continuing — ArgoCD will pull from this URL.

```bash
git add gitops-repo/apps/ k8s/91-app-of-apps.yaml
git commit -m "chore(lab-11): update repoURL to fork"
git push
```

:::info Using the upstream repo
If you are working from the upstream `schoolofdevops/302-llmops` repo directly and it is publicly readable, you can skip Part A. ArgoCD can read public repos without credentials. The deploy-key setup in Part E is still required — Lab 12's pipeline pushes back into the repo.
:::

---

## Part B — Install ArgoCD

```bash
bash scripts/install-argocd.sh
```

What this does:

- `helm repo add argo https://argoproj.github.io/argo-helm` (once)
- `helm install argocd argo/argo-cd --version 9.5.11 -n argocd --create-namespace`
- Sets `dex.enabled=false`, `notifications.enabled=false`, `applicationSet.enabled=false` (drops unused subsystems — ~512 MB total instead of ~1 GB)
- Sets `server.service.type=NodePort`, `nodePortHttp=30700` (UI accessible on the host)
- Sets `configs.params."server\.insecure"=true` (skip TLS for the lab)
- Stashes the initial admin password to `/tmp/argocd-admin-pw.txt`

The script exits cleanly if ArgoCD is already installed (helm status guard — idempotent).

:::warning Slow image pulls (quay.io)
The ArgoCD image (`quay.io/argoproj/argocd:v3.3.9`, ~400 MB) can take 10–35 minutes to pull on slower networks. The `helm install --wait --timeout 10m` may time out while the image is still pulling. Recovery:

1. Wait for the pull to finish: `kubectl get pods -n argocd -w` (watch until pods go from `ContainerCreating` to `Running`)
2. `helm uninstall argocd -n argocd`
3. Re-run `bash scripts/install-argocd.sh` — second run completes in < 1 minute (image cached)

For workshop pre-warm: `docker pull quay.io/argoproj/argocd:v3.3.9` before the lab starts.
:::

Confirm ArgoCD is running:

```bash
kubectl get pods -n argocd
# NAME                                              READY   STATUS    RESTARTS
# argocd-application-controller-...                1/1     Running   0
# argocd-repo-server-...                           1/1     Running   0
# argocd-server-...                                1/1     Running   0
# argocd-redis-...                                 1/1     Running   0
```

Open the UI — the initial admin password was printed by the script and saved to `/tmp/argocd-admin-pw.txt`:

```bash
open http://localhost:30700
# Username: admin
# Password: cat /tmp/argocd-admin-pw.txt
```

{/* Live verified 2026-05-04: install-argocd.sh ran cleanly on second attempt (first attempt
    timed out due to 33min quay.io image pull; helm uninstall + re-run took < 30s).
    All 4 core pods Ready: argocd-server, argocd-repo-server, argocd-redis,
    argocd-application-controller. NodePort 30700 confirmed. */}

---

## Part C — Inspect the App-of-Apps tree (before applying)

Inspect the root Application — this is what ties everything together:

```bash
cat k8s/91-app-of-apps.yaml
```

Two things to notice:

1. `spec.source.path: course-code/labs/lab-11/solution/gitops-repo/apps` with `directory.recurse: true` — ArgoCD treats every Application CR found under that path as a child to create.
2. `syncPolicy.automated.prune: true` and `selfHeal: true` — ArgoCD will auto-sync on git changes AND auto-revert manual `kubectl edit` drift.

Look at one child Application — the vLLM one:

```bash
cat gitops-repo/apps/vllm.yaml
```

Three things to notice:

1. `annotations.argocd.argoproj.io/sync-wave: "10"` — ArgoCD honors waves: lower wave syncs first (monitoring=0 before workloads=10 before agent=20 before chainlit=30).
2. `spec.source.path: course-code/labs/lab-11/solution/gitops-repo/bases/vllm` — points at the actual K8s manifests.
3. `spec.destination.namespace: llm-serving` — ArgoCD will apply those manifests into the `llm-serving` namespace.

:::note KIND-local image registry (gitops-repo adaptation)
The manifests in `gitops-repo/bases/` differ from the original lab manifests in two ways, both required for ArgoCD-managed deployments on KIND:

- Image refs use `kind-registry:5001` (not `localhost:5001`). Pods cannot resolve `localhost:5001` — containerd mirrors `kind-registry:5001` to the local registry.
- `imagePullPolicy: IfNotPresent` replaces `Always`. ArgoCD re-applies on every sync; `Always` would cause pods to attempt a pull on every sync, which fails for KIND-local images.

If you build new images (Lab 12), run `kind load docker-image` to push them into the KIND nodes, then bump the image tag in `gitops-repo/bases/vllm/30-deploy-vllm.yaml`.
:::

---

## Part D — Bootstrap the App-of-Apps tree

```bash
bash scripts/bootstrap-app-of-apps.sh
```

The script applies the root Application and polls until 6 Applications are visible (root + 5 children). On this hardware, all 5 child Applications reached `Synced + Healthy` in approximately **2 minutes** from bootstrap start (after the one-time image-pull warm-up; the sync waves — monitoring first, then workloads in parallel, then agent, then chainlit — account for most of that time).

Watch in the UI:

1. Open http://localhost:30700
2. The root Application `smile-dental-apps` appears within 30 seconds
3. Within 1-2 minutes, 5 child Applications appear under it, in wave order: `monitoring-otel-tempo` turns green first (wave 0), then `vllm` + `rag-retriever` in parallel (wave 10), then `agent-sandbox` (wave 20), then `chainlit` (wave 30)

Confirm via CLI:

```bash
kubectl get applications -n argocd
# NAME                     SYNC STATUS   HEALTH STATUS
# smile-dental-apps        Synced        Healthy
# monitoring-otel-tempo    Synced        Healthy
# vllm                     Synced        Healthy
# rag-retriever            Synced        Healthy
# agent-sandbox            Synced        Healthy
# chainlit                 Synced        Healthy
```

If any Application is `OutOfSync`, click into it in the UI to see the diff — or use:

```bash
argocd app diff <name> --grpc-web
```

:::tip Self-heal demo
Try `kubectl edit deploy vllm-smollm2 -n llm-serving` and add a spurious label. Within 3 minutes (one ArgoCD poll cycle), ArgoCD reverts your change. This is the mental shift: the git manifest is the source of truth, not what is currently running.
:::

:::note hermes-secret must exist
The `agent-sandbox` Application syncs the Hermes Deployment, which needs `hermes-secret` (containing your GROQ_API_KEY / GOOGLE_API_KEY). This Secret was created imperatively in Lab 08. If you rebuilt the cluster since Lab 08, re-apply it:

```bash
kubectl apply -f course-code/labs/lab-08/solution/k8s/60-hermes-secret.yaml
```

(Edit in your real API key first — the repo file has a placeholder.)
:::

---

## Part E — Set up the SSH deploy key (for Lab 12)

Lab 12's pipeline writes new image tags back into this gitops-repo. It pushes via SSH using a deploy key you store as a Kubernetes Secret. Set it up now so Lab 12 can proceed without interruption.

```bash
# 1. Generate a key pair (no passphrase — Argo Workflows mounts it via Secret)
ssh-keygen -t ed25519 -f /tmp/argo-deploy-key -N ""
```

```bash
# 2. Print the PUBLIC key — you will paste this into GitHub
cat /tmp/argo-deploy-key.pub
# In your fork's GitHub UI:
#   Settings → Deploy keys → Add deploy key
#   Paste the public key.
#   CHECK "Allow write access" (Lab 12 needs to push).
```

```bash
# 3. Base64-encode the PRIVATE key (flag differs by OS):
```

<Tabs groupId="operating-systems">
  <TabItem value="macos" label="macOS">
    ```bash
    base64 -i /tmp/argo-deploy-key
    ```
  </TabItem>
  <TabItem value="linux" label="Linux">
    ```bash
    base64 -w 0 /tmp/argo-deploy-key
    ```
  </TabItem>
  <TabItem value="windows" label="Windows (Git Bash)">
    ```bash
    base64 -w 0 /tmp/argo-deploy-key
    ```
  </TabItem>
</Tabs>

```bash
# 4. Create the argo namespace (Lab 12 will install Argo Workflows here)
kubectl create namespace argo --dry-run=client -o yaml | kubectl apply -f -

# 5. Copy the template, paste the base64 string, apply
cp k8s/92-ssh-deploy-key-secret.yaml.example k8s/92-ssh-deploy-key-secret.yaml
# Open k8s/92-ssh-deploy-key-secret.yaml and replace
# REPLACE_WITH_BASE64_PRIVATE_KEY with the base64 output from step 3
kubectl apply -f k8s/92-ssh-deploy-key-secret.yaml

# 6. Keep the real key out of git:
echo "course-code/labs/lab-11/solution/k8s/92-ssh-deploy-key-secret.yaml" >> .gitignore
```

Verify the Secret:

```bash
kubectl get secret git-deploy-key -n argo
# NAME             TYPE     DATA   AGE
# git-deploy-key   Opaque   1      5s
```

:::warning The deploy key is for in-cluster use only
The `git-deploy-key` Secret is mounted inside the Argo Workflows `git-commit-step` pod (Lab 12). For your local `git push` commands in this lab, use your normal GitHub credentials (HTTPS token or your regular SSH key). The deploy key is a separate credential scoped to the Argo Workflows runner.
:::

---

## Part F — GITOPS-02 demo: bump a value, commit, watch ArgoCD react

This is the lab's headline moment. Run the demo script:

```bash
bash scripts/demo-promote-vllm-tag.sh
```

What it does:

1. Edits `gitops-repo/bases/vllm/30-deploy-vllm.yaml` to bump a benign annotation (`gitops/deployed-at` to the current UTC timestamp)
2. `git add . && git commit -m "feat(lab-11): demo gitops promotion bump deployed-at=<timestamp>" && git push`
3. Polls every 10 seconds for up to 5 minutes for ArgoCD to reconcile
4. Prints the live cluster annotation when it matches the committed value

On this hardware, the auto-sync took **~70 seconds** end-to-end (git push → ArgoCD detect → live Deployment annotation updated). ArgoCD's default polling interval is 3 minutes; the variation comes from where the polling clock is when you push.

{/* GITOPS-02 live evidence 2026-05-04: bumped gitops/deployed-at to 20260504T124530Z,
    committed, pushed; ArgoCD synced vllm Deployment annotation in 70 seconds auto-poll.
    kubectl get deploy vllm-smollm2 -n llm-serving -o jsonpath='{.metadata.annotations.gitops/deployed-at}'
    returned 20260504T124530Z — end-to-end confirmed. */}

:::tip Force instant sync
If you do not want to wait up to 3 minutes, force a sync from the UI (click **Sync** on the `vllm` Application) or from CLI:

```bash
argocd app sync vllm --grpc-web
```

The sync itself completes in seconds — the only wait is for ArgoCD's periodic polling to detect the git change.
:::

:::warning Why an annotation bump and not a real image tag bump?
We are showing the **mechanic** — git change → ArgoCD detect → cluster reconcile. To bump a real image tag, you need a built model image with that tag. Lab 12 ships the full pipeline that builds the new model image AND bumps the tag automatically. Today we just want to see the wiring.
:::

---

## Part G — Inspect ArgoCD's history

```bash
argocd app history vllm --grpc-web
# REVISION   DEPLOYED                  SOURCE
# 1          2026-05-04 HH:MM:SS       <commit-sha before annotation bump>
# 2          2026-05-04 HH:MM:SS       <commit-sha after annotation bump>   ← your push
```

Each row maps a git commit SHA to a deploy time. **This is the audit trail Lab 13's GUARD-03 governance walkthrough cites** ("model versioning + deploy provenance + OTEL evidence"). Take a screenshot — Lab 13 references Part G of this lab as the deploy-time audit anchor.

---

## Common Pitfalls

| Symptom | Root cause | Fix |
|---------|-----------|-----|
| `vllm` Application reports `OutOfSync` forever | repoURL still points at the upstream repo, not your fork | Re-run Part A's `sed` substitution + commit + push to your fork |
| ArgoCD UI shows "ComparisonError: rpc error... Permission denied (publickey)" | gitops-repo is private and ArgoCD cannot read it | Either make the fork public, OR add a read-only deploy key to ArgoCD via a separate Secret in the `argocd` namespace |
| `agent-sandbox` Application is OutOfSync; status shows `Deployment/chainlit-ui managed by another Application` | The duplicate `40-chainlit-deploy-day2.yaml` was in both `chainlit/` and `agent-sandbox/` bases | Remove `gitops-repo/bases/agent-sandbox/40-chainlit-deploy-day2.yaml` — the canonical copy lives in `bases/chainlit/`. Re-sync the `agent-sandbox` Application. |
| MCP tool pods crash with "secret 'hermes-secret' not found" | `hermes-secret` was created imperatively in Lab 08 and was not re-created after a cluster rebuild | `kubectl apply -f course-code/labs/lab-08/solution/k8s/60-hermes-secret.yaml` (edit in your real GROQ_API_KEY / GOOGLE_API_KEY first) |
| `chainlit` pod CrashLoops with "could not connect to hermes" after sync | sync-wave 30 ran before the agent-sandbox (wave 20) was fully Ready — Chainlit started before Hermes was up | Wait 60 seconds; ArgoCD self-heal reconciles, OR re-sync `chainlit` manually |
| GITOPS-02 demo sat at 5 minutes with no sync | ArgoCD's default 3-min poll missed the window or push did not reach remote | Force sync: `argocd app sync vllm --grpc-web` (or click Sync in the UI); also confirm `git push` succeeded |
| `git push` in demo script returns "Permission denied (publickey)" | Your local git remote uses HTTPS without a stored credential, or the SSH agent does not have the right key | For local pushes, use your normal GitHub credential (token or personal SSH key). The deploy key from Part E is for the in-cluster Argo Workflows step — not for your laptop's git. |

---

## Summary

You now have:

- ArgoCD chart 9.5.11 (server v3.3.9) installed in namespace `argocd`, NodePort 30700
- An App-of-Apps root Application (`smile-dental-apps`) that creates 5 child Applications — all auto-syncing with `prune: true` and `selfHeal: true`
- The Day 1+2 stack's meaningful subset (vLLM, RAG retriever, Chainlit, agent Sandbox, Tempo datasource ConfigMap) under declarative GitOps management
- An SSH deploy-key Secret (`git-deploy-key` in `argo` namespace) ready for Lab 12's pipeline to push image-tag bumps back into this repo
- Live demonstration (GITOPS-02): committing to `gitops-repo/` triggered a cluster reconciliation in ~70 seconds

The mental shift Lab 11 teaches: **"the git manifest is the source of truth, not what is currently running."** Self-heal makes this real — ArgoCD reverts manual `kubectl edit` drift. Lab 13's GUARD-03 governance walkthrough cites your `argocd app history` output as the deploy-time audit trail.

### What is running after Lab 11

| Component | Namespace | State |
|-----------|-----------|-------|
| ArgoCD server | `argocd` | Running (NodePort 30700) |
| ArgoCD Application: `smile-dental-apps` | `argocd` | Synced, Healthy (root) |
| ArgoCD Application: `vllm` | `argocd` | Synced, Healthy (wave 10) |
| ArgoCD Application: `rag-retriever` | `argocd` | Synced, Healthy (wave 10) |
| ArgoCD Application: `agent-sandbox` | `argocd` | Synced, Healthy (wave 20) |
| ArgoCD Application: `chainlit` | `argocd` | Synced, Healthy (wave 30) |
| Secret `git-deploy-key` | `argo` | Created (Lab 12 ready) |

---

## Next Step

Lab 12 installs Argo Workflows and ships a DAG pipeline (data → train → merge → package → eval → commit-tag) that uses the SSH deploy key you set up in Part E to push new image tags into `gitops-repo/bases/vllm/30-deploy-vllm.yaml`. ArgoCD then auto-syncs that change to the cluster — the same ~70-second mechanic you just demonstrated.

Continue to [Lab 12: Pipelines + Eval Gate](./lab-12-pipelines.md).
