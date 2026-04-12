#!/usr/bin/env bash
# cleanup-phase3.sh — Remove Day 3 lab workloads (Labs 09-13)
# Removes: Prometheus/Grafana (kube-prometheus-stack), ArgoCD, Argo Workflows
# This is the final cleanup — leaves only the KIND cluster and namespaces.
#
# Run from course-code repo root:
#   bash shared/scripts/cleanup-phase3.sh
set -euo pipefail

echo "============================================="
echo " LLMOps — Phase 3 Cleanup (after Labs 09-13)"
echo "============================================="
echo ""
echo "This will uninstall: Prometheus/Grafana, ArgoCD, Argo Workflows."
echo "The KIND cluster and namespaces will be preserved."
echo ""
read -r -p "Proceed? (y/N): " CONFIRM
if [[ ! "${CONFIRM}" =~ ^[Yy]$ ]]; then
  echo "Cleanup cancelled."
  exit 0
fi

# --- Prometheus + Grafana ---
echo ""
echo "==> Uninstalling kube-prometheus-stack from monitoring namespace..."
if helm status prometheus -n monitoring >/dev/null 2>&1; then
  helm uninstall prometheus -n monitoring
  echo "  kube-prometheus-stack removed."
else
  echo "  kube-prometheus-stack not found — skipping."
fi

# Clean up CRDs left by kube-prometheus-stack
echo "==> Removing Prometheus Operator CRDs (if present)..."
kubectl delete crd prometheuses.monitoring.coreos.com --ignore-not-found=true 2>/dev/null || true
kubectl delete crd alertmanagers.monitoring.coreos.com --ignore-not-found=true 2>/dev/null || true
kubectl delete crd servicemonitors.monitoring.coreos.com --ignore-not-found=true 2>/dev/null || true
kubectl delete crd podmonitors.monitoring.coreos.com --ignore-not-found=true 2>/dev/null || true
kubectl delete crd prometheusrules.monitoring.coreos.com --ignore-not-found=true 2>/dev/null || true

# --- ArgoCD ---
echo ""
echo "==> Uninstalling ArgoCD from argocd namespace..."
if helm status argocd -n argocd >/dev/null 2>&1; then
  helm uninstall argocd -n argocd
  echo "  ArgoCD removed."
else
  echo "  ArgoCD not found — skipping."
fi

# --- Argo Workflows ---
echo ""
echo "==> Uninstalling Argo Workflows from argo-workflows namespace..."
if helm status argo-workflows -n argo-workflows >/dev/null 2>&1; then
  helm uninstall argo-workflows -n argo-workflows
  echo "  Argo Workflows removed."
else
  echo "  Argo Workflows not found — skipping."
fi

# --- Clean up any remaining workloads ---
echo ""
echo "==> Removing remaining workloads from all course namespaces..."
for ns in llm-serving llm-app monitoring argocd argo-workflows; do
  kubectl delete pods,deployments,services,configmaps,secrets,jobs \
    -n "${ns}" --ignore-not-found=true 2>/dev/null || true
done

echo ""
echo "==> Remaining pods (should be empty or namespace-level system pods):"
kubectl get pods --all-namespaces 2>/dev/null | grep -E "llm-|monitoring|argocd|argo-workflows" || echo "(none)"

echo ""
echo "============================================="
echo " Phase 3 cleanup complete."
echo " KIND cluster llmops-kind is still running."
echo " Run 'kind delete cluster --name llmops-kind' to remove the cluster entirely."
echo "============================================="
