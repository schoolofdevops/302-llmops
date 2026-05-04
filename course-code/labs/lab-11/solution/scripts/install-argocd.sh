#!/usr/bin/env bash
# install-argocd.sh — Idempotent ArgoCD Helm install (chart 9.5.11 → ArgoCD v3.3.9).
# Values overrides per RESEARCH.md Standard Stack:
#   - dex.enabled=false, notifications.enabled=false, applicationSet.enabled=false
#     (drop unused subsystems; reduce footprint to ~512MB total)
#   - server.service.type=NodePort, server.service.nodePortHttp=30700 (UI access)
#   - configs.params."server\.insecure"=true (skip TLS for the lab — UI on HTTP via NodePort)
set -euo pipefail

# Resolve repo root (4 dirs up from scripts/ → course-code/labs/lab-11/solution/scripts/)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
[ -f "${REPO_ROOT}/config.env" ] && source "${REPO_ROOT}/config.env"

NS_ARGOCD="${NS_ARGOCD:-argocd}"
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-9.5.11}"
NODEPORT_ARGOCD="${NODEPORT_ARGOCD:-30700}"

# ---- Idempotency guard ----
if helm status argocd -n "${NS_ARGOCD}" >/dev/null 2>&1; then
  echo "ArgoCD already installed in ${NS_ARGOCD}:"
  helm status argocd -n "${NS_ARGOCD}" --short
  echo
  echo "UI: http://localhost:${NODEPORT_ARGOCD}  (run ./argocd-login.sh to get the current password)"
  exit 0
fi

# ---- Add Helm repo ----
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null

# ---- Install ----
helm install argocd argo/argo-cd \
  --version "${ARGOCD_CHART_VERSION}" \
  --namespace "${NS_ARGOCD}" \
  --create-namespace \
  --set "configs.params.server\.insecure=true" \
  --set server.service.type=NodePort \
  --set "server.service.nodePortHttp=${NODEPORT_ARGOCD}" \
  --set dex.enabled=false \
  --set notifications.enabled=false \
  --set applicationSet.enabled=false \
  --wait --timeout 10m

echo
echo "Waiting for ArgoCD server rollout…"
kubectl rollout status deploy/argocd-server -n "${NS_ARGOCD}" --timeout=300s

echo
echo "ArgoCD installed. Initial admin password:"
ADMIN_PWD=$(kubectl -n "${NS_ARGOCD}" get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)
echo "${ADMIN_PWD}"
echo

# ---- Stash password locally for downstream tasks (NOT committed) ----
echo "${ADMIN_PWD}" > /tmp/argocd-admin-pw.txt
echo "Password saved to /tmp/argocd-admin-pw.txt (local-only; not committed to git)"
echo
echo "UI: http://localhost:${NODEPORT_ARGOCD}  (admin / <password above>)"
