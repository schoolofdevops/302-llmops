#!/usr/bin/env bash
# argocd-login.sh — Optional: log in via argocd CLI for instructor demos.
# Lab walkthrough uses kubectl + the UI; this script is a convenience for
# instructors who prefer `argocd app sync <name>` over Refresh-in-UI.
set -euo pipefail

NS_ARGOCD="${NS_ARGOCD:-argocd}"
NODEPORT_ARGOCD="${NODEPORT_ARGOCD:-30700}"

if ! command -v argocd >/dev/null 2>&1; then
  echo "argocd CLI not installed."
  echo "  macOS:  brew install argocd"
  echo "  Linux:  see https://argo-cd.readthedocs.io/en/stable/cli_installation/"
  exit 1
fi

# ---- Use cached password if available ----
if [ -f /tmp/argocd-admin-pw.txt ]; then
  PASSWORD=$(cat /tmp/argocd-admin-pw.txt)
else
  PASSWORD=$(kubectl -n "${NS_ARGOCD}" get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' | base64 -d)
fi

argocd login "localhost:${NODEPORT_ARGOCD}" \
  --username admin \
  --password "${PASSWORD}" \
  --insecure \
  --grpc-web

echo
argocd app list
