#!/usr/bin/env bash
# install-argocd.sh — Idempotent ArgoCD Helm install (chart 9.5.11 → ArgoCD v3.3.9).
# NodePort 30700, server.insecure=true, dex/notifications/applicationSet disabled.
# Run from anywhere — REPO_ROOT is detected automatically.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

NS_ARGOCD="${NS_ARGOCD:-argocd}"
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-9.5.11}"
NODEPORT_ARGOCD="${NODEPORT_ARGOCD:-30700}"

echo "==> Installing ArgoCD ${ARGOCD_CHART_VERSION} in namespace ${NS_ARGOCD} on NodePort ${NODEPORT_ARGOCD}"

# Idempotency guard: skip if already installed
if helm status argocd -n "${NS_ARGOCD}" >/dev/null 2>&1; then
  echo "ArgoCD already installed (helm status argocd returned 0). Skipping install."
  echo "To upgrade: helm upgrade argocd argo/argo-cd -n ${NS_ARGOCD} --version ${ARGOCD_CHART_VERSION}"
  exit 0
fi

# Add and update Helm repo
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update argo

# Install ArgoCD with course-grade value overrides
helm install argocd argo/argo-cd \
  --version "${ARGOCD_CHART_VERSION}" \
  --namespace "${NS_ARGOCD}" \
  --create-namespace \
  --set configs.params."server\.insecure"=true \
  --set server.service.type=NodePort \
  --set server.service.nodePortHttp="${NODEPORT_ARGOCD}" \
  --set dex.enabled=false \
  --set notifications.enabled=false \
  --set applicationSet.enabled=false \
  --wait --timeout 10m

# Verify rollout
kubectl rollout status deploy/argocd-server -n "${NS_ARGOCD}" --timeout=300s

# Print initial admin password
PASS=$(kubectl -n "${NS_ARGOCD}" get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)

echo ""
echo "========================================================"
echo "ArgoCD installed successfully!"
echo "  Chart version : ${ARGOCD_CHART_VERSION}"
echo "  App version   : ArgoCD v3.3.9"
echo "  Namespace     : ${NS_ARGOCD}"
echo "  Initial admin password: ${PASS}"
echo "  UI: http://localhost:${NODEPORT_ARGOCD}  (admin / ${PASS})"
echo "========================================================"
