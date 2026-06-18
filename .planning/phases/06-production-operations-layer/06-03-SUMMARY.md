---
phase: 06-production-operations-layer
plan: "03"
subsystem: gitops
tags:
  - argocd
  - app-of-apps
  - gitops
  - model-promotion
  - lab-11
dependency_graph:
  requires:
    - 06-01-SUMMARY.md
    - 06-02-SUMMARY.md
  provides:
    - "ArgoCD 9.5.11 (v3.3.9) running in argocd namespace, UI on NodePort 30700"
    - "App-of-Apps root Application (smile-dental-apps) managing 4 child Applications"
    - "gitops/ directory structure: apps/ (4 child Application YAMLs) + bases/ (4 component dirs)"
    - "Model promotion demo script (demo-promote-vllm-annotation.sh)"
    - "Lab 11 instructional content: 423-line lab-11-gitops-argocd.md"
  affects:
    - "06-04-PLAN.md (Argo Workflows DAG + E2E loop — ArgoCD remains running)"
tech_stack:
  added:
    - "ArgoCD 9.5.11 (Helm chart argo/argo-cd, deploys ArgoCD v3.3.9)"
    - "ArgoCD Application CRD (argoproj.io/v1alpha1)"
    - "App-of-Apps pattern: root Application + 4 child Applications"
  patterns:
    - "Idempotent Helm install with helm-status guard (install-argocd.sh)"
    - "ARGOCD_REPO_URL env var substituted by bootstrap script (sed -i)"
    - "Sync waves: wave 0 (minio, observability), wave 10 (vllm, chainlit)"
    - "GitOps promotion via Deployment annotation bump (gitops/model-version)"
key_files:
  created:
    - course-code/labs/lab-11/solution/scripts/install-argocd.sh
    - course-code/labs/lab-11/solution/scripts/argocd-login.sh
    - course-code/labs/lab-11/solution/scripts/bootstrap-app-of-apps.sh
    - course-code/labs/lab-11/solution/scripts/demo-promote-vllm-annotation.sh
    - course-code/labs/lab-11/solution/k8s/90-argocd-namespace.yaml
    - course-code/labs/lab-11/solution/k8s/91-app-of-apps.yaml
    - course-code/labs/lab-11/starter/k8s/90-argocd-namespace.yaml
    - course-code/labs/lab-11/starter/k8s/91-app-of-apps.yaml
    - course-code/labs/lab-11/solution/gitops/apps/vllm.yaml
    - course-code/labs/lab-11/solution/gitops/apps/minio.yaml
    - course-code/labs/lab-11/solution/gitops/apps/chainlit.yaml
    - course-code/labs/lab-11/solution/gitops/apps/observability.yaml
    - course-code/labs/lab-11/solution/gitops/bases/vllm/30-deploy-vllm.yaml
    - course-code/labs/lab-11/solution/gitops/bases/vllm/30-svc-vllm.yaml
    - course-code/labs/lab-11/solution/gitops/bases/chainlit/40-deploy-chainlit.yaml
    - course-code/labs/lab-11/solution/gitops/bases/chainlit/40-svc-chainlit.yaml
    - course-code/labs/lab-11/solution/gitops/bases/minio/10-minio-values.yaml
    - course-code/labs/lab-11/solution/gitops/bases/observability/50-servicemonitor-vllm.yaml
    - course-content/docs/labs/lab-11-gitops-argocd.md
  modified:
    - course-content/sidebars.ts
decisions:
  - "gitops/ directory lives inside course-code/labs/lab-11/ (D-07 locked): ArgoCD repoURL points to GitHub HTTPS URL — file:// cannot work from in-cluster ArgoCD pod"
  - "App-of-Apps scope: Pattern A only (D-08 locked) — 4 child Applications (vllm, minio, chainlit, observability)"
  - "Model promotion mechanism (D-09): gitops/model-version annotation bump in 30-deploy-vllm.yaml triggers rolling restart via ArgoCD sync"
  - "Sync waves: minio+observability at wave 0; vllm+chainlit at wave 10 — ensures storage ready before serving"
  - "ArgoCD install: dex/notifications/applicationSet disabled to reduce memory footprint on KIND"
metrics:
  duration: "~40 minutes"
  completed: "2026-06-18"
  tasks_completed: 2
  files_created: 19
  files_modified: 1
---

# Phase 06 Plan 03: ArgoCD App-of-Apps + Lab 11 GitOps Summary

ArgoCD 9.5.11 installed and verified on NodePort 30700; complete gitops/ structure (App-of-Apps root + 4 child Applications + base manifests for vllm/chainlit/minio/observability); model promotion demo script; 423-line Lab 11 doc page covering ArgoCD install, App-of-Apps pattern, Pitfall-2 (file:// warning), sync waves, and model promotion demo.

## What Was Built

### Task 1: ArgoCD install + gitops/ directory structure (commit: 096ae94)

**Install scripts (course-code/labs/lab-11/solution/scripts/):**

- **install-argocd.sh**: Idempotent Helm install of `argo/argo-cd` 9.5.11 (ArgoCD v3.3.9). Idempotency guard: `helm status argocd`. Five value overrides: `dex.enabled=false`, `notifications.enabled=false`, `applicationSet.enabled=false`, `server.service.type=NodePort`, `server.service.nodePortHttp=30700`, `configs.params."server.insecure"=true`. Waits with `--timeout 10m` and verifies rollout.
- **argocd-login.sh**: Fetches initial admin password from `argocd-initial-admin-secret` and calls `argocd login localhost:30700 --insecure`.
- **bootstrap-app-of-apps.sh**: Requires `ARGOCD_REPO_URL` env var. Uses `sed "s|<ARGOCD_REPO_URL>|${ARGOCD_REPO_URL}|g"` to substitute placeholder in the root Application YAML and all 4 child Application YAMLs before applying with kubectl.

**Kubernetes manifests (course-code/labs/lab-11/solution/k8s/):**

- **90-argocd-namespace.yaml**: `Namespace argocd` with `app.kubernetes.io/name: argocd` label.
- **91-app-of-apps.yaml** (solution): Root Application `smile-dental-apps` watching `course-code/labs/lab-11/gitops/apps` with `directory.recurse: true`. Placeholder `<ARGOCD_REPO_URL>` for bootstrap substitution. Automated sync with `prune: true`, `selfHeal: true`, `CreateNamespace=true`.
- **91-app-of-apps.yaml** (starter): Same structure with `# TODO: replace with your GitHub fork URL` comment instead of the placeholder.

**Child Applications (gitops/apps/):**

| File | App Name | Namespace | Sync Wave | Path |
|------|----------|-----------|-----------|------|
| vllm.yaml | vllm | llm-serving | 10 | gitops/bases/vllm |
| minio.yaml | minio | minio | 0 | gitops/bases/minio |
| chainlit.yaml | chainlit | llm-app | 10 | gitops/bases/chainlit |
| observability.yaml | observability | monitoring | 0 | gitops/bases/observability |

All carry `<ARGOCD_REPO_URL>` placeholder; all have `automated: {prune: true, selfHeal: true}` sync policy.

**Base manifests (gitops/bases/):**

- `vllm/30-deploy-vllm.yaml`: Copied from lab-04, added `metadata.annotations.gitops/model-version: "initial"` (the promotion target field).
- `vllm/30-svc-vllm.yaml`, `chainlit/40-*.yaml`: Exact copies from lab-04.
- `minio/10-minio-values.yaml`: Exact copy from lab-06.
- `observability/50-servicemonitor-vllm.yaml`: Exact copy from lab-05.

**Live verification:**
- `kubectl get pods -n argocd`: 5 pods Running (server, application-controller, applicationset-controller, redis, repo-server)
- `kubectl get deploy argocd-server -n argocd -o jsonpath='{.status.readyReplicas}'`: `1`
- `curl http://localhost:30700`: Returns ArgoCD HTML UI

### Task 2: Model promotion demo script + Lab 11 doc page (commit: a302fe6)

**demo-promote-vllm-annotation.sh**: Generates timestamp, uses `sed -i.bak` (macOS-safe) to replace `gitops/model-version: ".*"` with `gitops/model-version: "run-${TIMESTAMP}"` in `30-deploy-vllm.yaml`. Removes `.bak` artifact, stages, commits with `"demo: bump vllm model-version to run-${TIMESTAMP}"`, then prints exact commands for push + sync + rollout verification.

**lab-11-gitops-argocd.md** (423 lines, 7 parts):

1. **Part 1 — Install ArgoCD**: Script invocation, pod verification, admin password fetch, UI access at `http://localhost:30700`
2. **Part 2 — Repo Structure**: Full directory tree of `gitops/` layout; App-of-Apps pattern explanation; `:::caution` block documenting Pitfall-2 (ArgoCD cannot use `file://` from in-cluster pod — must use HTTPS GitHub URL)
3. **Part 3 — Configure + Apply**: Fork/push steps, `ARGOCD_REPO_URL` env var, `bootstrap-app-of-apps.sh`, manual sed-substitution alternative, `:::note` explaining sync waves
4. **Part 4 — Inspect Sync Status**: `argocd app list`, `argocd app get vllm`, `kubectl describe application`, checking initial annotation
5. **Part 5 — Model Promotion Demo**: Concept explanation, `demo-promote-vllm-annotation.sh`, `git push`, `argocd app sync vllm`, `kubectl rollout status`, verification via `kubectl describe` + `curl /v1/models`; `:::note` on 3-minute polling interval
6. **Part 6 — Patterns B/C callout**: `:::info` block noting this lab covers Pattern A only (D-08); how to extend to Pattern B/C
7. **Part 7 — Teardown**: Cascade-delete via `kubectl delete -f k8s/`; note that ArgoCD itself stays for Lab 12

**sidebars.ts**: Added `labs/lab-11-gitops-argocd` to the Labs category.

**Docusaurus build**: `npm run build` exits 0 with no errors.

## Deviations from Plan

None — plan executed exactly as written. All files match the spec in the plan's `<action>` blocks. ArgoCD installed successfully on first run.

## Known Stubs

None — all manifests reference real cluster resources. The `<ARGOCD_REPO_URL>` placeholder in YAMLs is intentional (not a stub) — it is substituted at runtime by the bootstrap script. The `gitops/bases/minio/10-minio-values.yaml` is a Helm values reference file (not a Kubernetes manifest); MinIO itself is already running in the cluster from the Plan 06-01 install.

## Threat Flags

None — all file modifications are version-controlled YAML configs and documentation. The `<ARGOCD_REPO_URL>` placeholder prevents accidental credential commit. The lab explicitly documents using HTTPS for public forks and directs students to configure GitHub PAT secrets for private repos. ArgoCD admin password is fetched from a Kubernetes Secret (not hardcoded).

## Self-Check: PASSED

Files exist:
- course-code/labs/lab-11/solution/scripts/install-argocd.sh: FOUND (contains "9.5.11", "30700", "dex.enabled=false", "helm status argocd")
- course-code/labs/lab-11/solution/scripts/argocd-login.sh: FOUND
- course-code/labs/lab-11/solution/scripts/bootstrap-app-of-apps.sh: FOUND (substitutes ARGOCD_REPO_URL in root + all child Apps)
- course-code/labs/lab-11/solution/scripts/demo-promote-vllm-annotation.sh: FOUND (contains "gitops/model-version", "git commit")
- course-code/labs/lab-11/solution/k8s/90-argocd-namespace.yaml: FOUND
- course-code/labs/lab-11/solution/k8s/91-app-of-apps.yaml: FOUND (contains "gitops/apps", "smile-dental-apps")
- course-code/labs/lab-11/starter/k8s/91-app-of-apps.yaml: FOUND (contains "# TODO")
- course-code/labs/lab-11/solution/gitops/apps/vllm.yaml: FOUND (wave 10, llm-serving, ARGOCD_REPO_URL placeholder)
- course-code/labs/lab-11/solution/gitops/apps/minio.yaml: FOUND (wave 0, minio, ARGOCD_REPO_URL placeholder)
- course-code/labs/lab-11/solution/gitops/apps/chainlit.yaml: FOUND (wave 10, llm-app, ARGOCD_REPO_URL placeholder)
- course-code/labs/lab-11/solution/gitops/apps/observability.yaml: FOUND (wave 0, monitoring, ARGOCD_REPO_URL placeholder)
- course-code/labs/lab-11/solution/gitops/bases/vllm/30-deploy-vllm.yaml: FOUND (contains gitops/model-version: "initial")
- course-code/labs/lab-11/solution/gitops/bases/vllm/30-svc-vllm.yaml: FOUND
- course-code/labs/lab-11/solution/gitops/bases/chainlit/40-deploy-chainlit.yaml: FOUND
- course-code/labs/lab-11/solution/gitops/bases/chainlit/40-svc-chainlit.yaml: FOUND
- course-code/labs/lab-11/solution/gitops/bases/minio/10-minio-values.yaml: FOUND
- course-code/labs/lab-11/solution/gitops/bases/observability/50-servicemonitor-vllm.yaml: FOUND
- course-content/docs/labs/lab-11-gitops-argocd.md: FOUND (423 lines)

Commits verified:
- 096ae94: feat(06-03): ArgoCD 9.5.11 install scripts + App-of-Apps gitops/ structure
- a302fe6: feat(06-03): model promotion demo script + lab-11-gitops-argocd.md (423 lines, 7 parts)

Live cluster state verified:
- kubectl get pods -n argocd: 5 pods Running
- kubectl get deploy argocd-server -n argocd -o jsonpath='{.status.readyReplicas}': 1
- curl http://localhost:30700: ArgoCD UI HTML returned
- wc -l course-content/docs/labs/lab-11-gitops-argocd.md: 423 (≥200 requirement met)
- cd course-content && npm run build: exit 0, no errors
