# Phase 06: Production Operations Layer — Verification

```
Status: Pending verification
Phase: 06-production-operations-layer
Plans: 06-01, 06-02, 06-03, 06-04
Last updated: 2026-06-18
```

This document lists measurable acceptance criteria for every component delivered in Phase 06.
Each row specifies the check, the command to run, and the expected output.

---

## OPS-01 — Autoscaling (Plans 06-01 and 06-02)

| ID | Check | Command | Expected | Status |
|----|-------|---------|----------|--------|
| V-01 | KIND cluster has NodePorts 30700 + 30800 | `rg "containerPort: 3070" course-code/labs/lab-00/solution/setup/kind-config.yaml` | Match found (port mapping present) | [ ] |
| V-02 | kube-prometheus-stack running | `kubectl get pods -n monitoring --field-selector=status.phase=Running` | ≥3 Running pods | [ ] |
| V-03 | KEDA running | `kubectl get pods -n keda --field-selector=status.phase=Running` | ≥3 Running pods | [ ] |
| V-04 | metrics-server working | `kubectl top nodes` | Outputs CPU + MEMORY rows (no error) | [ ] |
| V-05 | Pattern A KEDA ScaledObject READY=True | `kubectl get scaledobject vllm-smollm2 -n llm-serving -o jsonpath='{.status.conditions[?(@.type=="Active")].status}'` | `True` | [ ] |
| V-06 | Pattern B KEDA ScaledObject present | `kubectl get scaledobject -n llm-serving` | chart-created ScaledObject present (name: lmstack-smollm2-scaledobject) with READY=True | [ ] |
| V-07 | Pattern C KEDA ScaledObject READY=True | `kubectl get scaledobject smollm2-predictor-keda -n llm-serving -o jsonpath='{.status.conditions[?(@.type=="Active")].status}'` | `True` | [ ] |
| V-08 | HPA on rag-retriever configured | `kubectl get hpa rag-retriever -n llm-app` | HPA resource present (CPU 60%) | [ ] |
| V-09 | Load test triggers Pattern A scale-up | `kubectl get pods -n llm-serving` (run after hey loadgen Job) | ≥2 `vllm-smollm2-*` pods while load is active | [ ] |

---

## OPS-02 — GitOps (Plan 06-03)

| ID | Check | Command | Expected | Status |
|----|-------|---------|----------|--------|
| V-10 | ArgoCD running | `kubectl get pods -n argocd --field-selector=status.phase=Running` | ≥3 Running pods | [ ] |
| V-11 | ArgoCD UI accessible | `curl -s http://localhost:30700` | Non-empty HTML response | [ ] |
| V-12 | App-of-Apps manifest present | `kubectl get application smile-dental-apps -n argocd` | Application resource exists | [ ] |
| V-13 | gitops/ structure complete | `ls course-code/labs/lab-11/solution/gitops/apps/` | 4 files: `vllm.yaml minio.yaml chainlit.yaml observability.yaml` | [ ] |

---

## OPS-03 — Argo Workflows + E2E Loop (Plan 06-04)

| ID | Check | Command | Expected | Status |
|----|-------|---------|----------|--------|
| V-14 | Argo Workflows running | `kubectl get pods -n argo --field-selector=status.phase=Running` | ≥2 Running pods (server + controller) | [ ] |
| V-15 | Argo Workflows UI accessible | `curl -s http://localhost:30800` | Non-empty HTML response | [ ] |
| V-16 | WorkflowTemplate has 5 steps (with promote) | `rg "promote" course-code/labs/lab-12/solution/k8s/101-workflowtemplate-pipeline.yaml` | Match found (promote step present) | [ ] |
| V-17 | WorkflowTemplate has no eval gate | `rg "^[^#]*eval" course-code/labs/lab-12/solution/k8s/101-workflowtemplate-pipeline.yaml` | No matches (eval gate removed per D-11) | [ ] |
| V-18 | WorkflowTemplate uses alpine/git for promote | `rg "alpine/git" course-code/labs/lab-12/solution/k8s/101-workflowtemplate-pipeline.yaml` | Match found | [ ] |
| V-19 | Workflow CR has generateName | `rg "generateName: llm-pipeline-" course-code/labs/lab-12/solution/k8s/102-workflow-run.yaml` | Match found | [ ] |
| V-20 | SSH deploy key Secret exists | `kubectl get secret git-deploy-key -n argo` | Secret resource exists (Opaque type) | [ ] |
| V-21 | E2E loop is fully automated | `rg "single git push" course-content/docs/labs/lab-12-argo-workflows.md` | Match found in doc | [ ] |
| V-22 | Workflow run was triggered | `kubectl get workflow -n argo` | Shows ≥1 Workflow; Phase=Succeeded or Failed (executed, not pending) | [ ] |

---

## Lab Content

| ID | Check | Command | Expected | Status |
|----|-------|---------|----------|--------|
| V-23 | lab-10-autoscaling.md covers all 3 KEDA patterns | `rg "Pattern C" course-content/docs/labs/lab-10-autoscaling.md` | Match found | [ ] |
| V-24 | lab-11-gitops-argocd.md exists with ≥200 lines | `wc -l course-content/docs/labs/lab-11-gitops-argocd.md` | ≥200 | [ ] |
| V-25 | lab-12-argo-workflows.md exists with ≥200 lines | `wc -l course-content/docs/labs/lab-12-argo-workflows.md` | ≥200 | [ ] |
| V-26 | Docusaurus build with all 3 lab pages | `cd course-content && npm run build` | Exit 0, no broken links | [ ] |

---

## Quick Verification Script

Run all checks in one pass:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Phase 06 Verification ==="

echo ""
echo "--- OPS-01: Autoscaling ---"
echo "V-02 kube-prometheus-stack:"
kubectl get pods -n monitoring --field-selector=status.phase=Running --no-headers | wc -l
echo "V-03 KEDA:"
kubectl get pods -n keda --field-selector=status.phase=Running --no-headers | wc -l
echo "V-04 metrics-server:"
kubectl top nodes | head -3
echo "V-05 Pattern A ScaledObject:"
kubectl get scaledobject vllm-smollm2 -n llm-serving -o jsonpath='{.status.conditions[?(@.type=="Active")].status}' 2>/dev/null || echo "NOT FOUND"
echo "V-07 Pattern C ScaledObject:"
kubectl get scaledobject smollm2-predictor-keda -n llm-serving -o jsonpath='{.status.conditions[?(@.type=="Active")].status}' 2>/dev/null || echo "NOT FOUND"
echo "V-08 HPA rag-retriever:"
kubectl get hpa rag-retriever -n llm-app --no-headers 2>/dev/null || echo "NOT FOUND"

echo ""
echo "--- OPS-02: GitOps ---"
echo "V-10 ArgoCD pods:"
kubectl get pods -n argocd --field-selector=status.phase=Running --no-headers | wc -l
echo "V-11 ArgoCD UI:"
curl -s http://localhost:30700 | head -c 100
echo "V-12 App-of-Apps:"
kubectl get application smile-dental-apps -n argocd --no-headers 2>/dev/null || echo "NOT FOUND"

echo ""
echo "--- OPS-03: Argo Workflows ---"
echo "V-14 Argo Workflows pods:"
kubectl get pods -n argo --field-selector=status.phase=Running --no-headers | wc -l
echo "V-15 Argo UI:"
curl -s http://localhost:30800 | head -c 100
echo "V-16 WorkflowTemplate promote step:"
rg "promote" course-code/labs/lab-12/solution/k8s/101-workflowtemplate-pipeline.yaml | head -3
echo "V-20 git-deploy-key Secret:"
kubectl get secret git-deploy-key -n argo --no-headers 2>/dev/null || echo "NOT FOUND"
echo "V-22 Workflow runs:"
kubectl get workflow -n argo --no-headers 2>/dev/null || echo "NONE"

echo ""
echo "--- Lab Content ---"
echo "V-23 Pattern C in lab-10:"
rg "Pattern C" course-content/docs/labs/lab-10-autoscaling.md | head -2
echo "V-24 lab-11 line count:"
wc -l course-content/docs/labs/lab-11-gitops-argocd.md
echo "V-25 lab-12 line count:"
wc -l course-content/docs/labs/lab-12-argo-workflows.md

echo ""
echo "=== Run 'cd course-content && npm run build' separately to verify Docusaurus build ==="
```
