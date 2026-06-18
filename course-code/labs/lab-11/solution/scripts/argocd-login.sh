#!/usr/bin/env bash
# argocd-login.sh — Fetch initial admin password and log in to ArgoCD CLI.
set -euo pipefail

NS_ARGOCD="${NS_ARGOCD:-argocd}"
NODEPORT_ARGOCD="${NODEPORT_ARGOCD:-30700}"

echo "==> Fetching ArgoCD initial admin password from secret..."
PASS=$(kubectl -n "${NS_ARGOCD}" get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)

echo "==> Logging in to ArgoCD at localhost:${NODEPORT_ARGOCD} ..."
argocd login "localhost:${NODEPORT_ARGOCD}" \
  --username admin \
  --password "${PASS}" \
  --insecure

echo ""
echo "==> Logged in. Listing Applications:"
argocd app list
