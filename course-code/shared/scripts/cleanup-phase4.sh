#!/usr/bin/env bash
# cleanup-phase4.sh — End of Day 3 teardown.
# Removes KEDA, ArgoCD, Argo Workflows, and the per-lab CRs Phase 4 created.
# Day 1+2 stack (vLLM, RAG, Chainlit, agent Sandbox, Prometheus, Grafana, Tempo, OTEL collector)
# is LEFT RUNNING. Run cleanup-phase3.sh next to remove Day 2.
#
# Pattern follows Phase 1 D-15/D-16:
#   - Per-CRD `kubectl delete --ignore-not-found` (avoid script aborts on missing CRs)
#   - `helm status <release> -n <ns> >/dev/null 2>&1` guard around `helm uninstall`
#     (avoid script abort when a release was never installed).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "${REPO_ROOT}/config.env"

NS_KEDA="${NS_KEDA:-keda}"
NS_ARGOCD="${NS_ARGOCD:-argocd}"
NS_ARGO="${NS_ARGO:-argo}"
NS_SERVING="${NS_SERVING:-llm-serving}"
NS_APP="${NS_APP:-llm-app}"

echo "[1/5] Deleting Phase 4 custom resources (autoscalers, workflows, applications)…"
kubectl delete scaledobject vllm-smollm2 -n "${NS_SERVING}" --ignore-not-found
kubectl delete hpa rag-retriever -n "${NS_APP}" --ignore-not-found
kubectl delete job vllm-loadgen -n "${NS_SERVING}" --ignore-not-found
kubectl delete workflowtemplate llm-pipeline -n "${NS_ARGO}" --ignore-not-found
kubectl delete workflows --all -n "${NS_ARGO}" --ignore-not-found
kubectl delete applications --all -n "${NS_ARGOCD}" --ignore-not-found
kubectl delete pvc pipeline-workspace -n "${NS_ARGO}" --ignore-not-found

echo "[2/5] Uninstalling Helm releases (with helm-status guard)…"
for release_ns in "argocd:${NS_ARGOCD}" "argo-workflows:${NS_ARGO}" "keda:${NS_KEDA}"; do
  release="${release_ns%:*}"
  ns="${release_ns#*:}"
  if helm status "${release}" -n "${ns}" >/dev/null 2>&1; then
    echo "       uninstalling ${release} from ${ns}…"
    helm uninstall "${release}" -n "${ns}"
  else
    echo "       ${release} not present in ${ns} — skipping."
  fi
done

echo "[3/5] Removing metrics-server (installed imperatively in Lab 10)…"
kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml --ignore-not-found

echo "[4/5] Deleting Phase 4 namespaces (only if empty after Helm uninstall)…"
kubectl delete namespace "${NS_KEDA}" --ignore-not-found
kubectl delete namespace "${NS_ARGOCD}" --ignore-not-found
kubectl delete namespace "${NS_ARGO}" --ignore-not-found

echo "[5/5] Done. Day 1+2 stack left running."
echo "      Run shared/scripts/cleanup-phase3.sh next if you also want to remove Day 2."
