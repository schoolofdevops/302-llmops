# Smile Dental — GitOps Repo (Lab 11)

This sub-folder is what ArgoCD watches. Per D-07 (CONTEXT.md), the gitops repo is a
sub-folder of the companion repo so students have one clone and one auth context.

## Layout

```
gitops-repo/
├── apps/                          # ArgoCD Application CRs — one per onboarded subsystem
│   ├── monitoring-otel-tempo.yaml   # sync-wave 0  (must exist before workloads)
│   ├── vllm.yaml                    # sync-wave 10 (LLM serving — Lab 12 promotion target)
│   ├── rag-retriever.yaml           # sync-wave 10 (FAISS retriever)
│   ├── agent-sandbox.yaml           # sync-wave 20 (Hermes + 3 MCP tools + Sandbox CRs)
│   └── chainlit.yaml                # sync-wave 30 (front door — depends on agent-sandbox)
└── bases/                         # K8s manifests each child Application syncs
    ├── monitoring/                  # Grafana Tempo datasource ConfigMap
    ├── vllm/                        # vLLM Deployment + Service
    ├── rag-retriever/               # RAG Retriever Deployment + Service
    ├── chainlit/                    # Chainlit Day-2 Deployment + Service
    └── agent-sandbox/               # Hermes Sandbox + WarmPool + 3 MCP tools + RBAC
```

## What's NOT here (D-06 Hybrid scoping note — D-20)

ArgoCD manages a **meaningful subset**, not literally all components:

- **kube-prometheus-stack** — stays Helm-managed (chart is huge; would explode Lab 11 footprint)
- **Tempo + OTEL Collector** — stay Helm-managed for the same reason; only their Grafana datasource
  ConfigMap is in gitops (see `bases/monitoring/`)
- **KEDA controller + ScaledObject + HPA** — stay imperative (Lab 10 — controllers are infra-of-infra)
- **Argo Workflows controller + WorkflowTemplate + Workflows** — stay imperative (Lab 12)
- **Agent Sandbox CRDs** — installed imperatively in Lab 08 (Open Q5); only the CRs
  (SandboxTemplate, SandboxWarmPool, etc.) are in gitops
- **Secrets** — `hermes-secret` (LLM API key, Lab 08), `argocd-initial-admin-secret`
  (auto-created by Helm), `git-deploy-key` (Lab 11/12 setup) — never in git

This is an intentional teaching choice (D-20): the App-of-Apps pattern is shown end-to-end
on a meaningful subset. Retrofitting all Helm releases into ArgoCD ApplicationSets is a
production enhancement beyond the scope of a single lab day.

## Sync Wave Order

| Wave | Applications | Reason |
|------|-------------|--------|
| 0 | monitoring-otel-tempo | Grafana datasource must exist before workload traces arrive |
| 10 | vllm, rag-retriever | Core serving tier; neither depends on the other |
| 20 | agent-sandbox | Hermes + MCP tools; depends on vllm (for model) and rag-retriever |
| 30 | chainlit | Front door; depends on agent-sandbox (hermes-agent service) |

## Lab 12 SSH deploy-key setup

Lab 12's git-commit-step pushes new image tags into this folder, so it needs write access.
Setup steps are documented in `../k8s/92-ssh-deploy-key-secret.yaml.example`:

1. `ssh-keygen -t ed25519 -f /tmp/argo-deploy-key -N ""`
2. Add `/tmp/argo-deploy-key.pub` to GitHub repo: **Settings → Deploy keys → Add deploy key**
   (CHECK "Allow write access" — the git-commit-step in Lab 12 needs to push)
3. Base64-encode the private key and fill into the Secret template
4. `kubectl apply -f 92-ssh-deploy-key-secret.yaml` (in namespace `argo`)

## GITOPS-02 Promotion Demo (Lab 11)

The demo script `../scripts/demo-promote-vllm-tag.sh` demonstrates the full cycle:

1. Edits `bases/vllm/30-deploy-vllm.yaml` (bumps `gitops/deployed-at` annotation)
2. `git add → git commit → git push`
3. ArgoCD auto-sync detects the change within 3 minutes (default `timeout.reconciliation=180s`)
4. Polls until the live Deployment annotation matches the committed value

For instant sync (no wait): `argocd app sync vllm --grpc-web`

In Lab 12, the pipeline replaces the annotation bump with an actual image tag update —
the mechanic is identical; only the YAML field being edited changes.
