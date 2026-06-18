#!/usr/bin/env bash
# bootstrap-app-of-apps.sh — Apply the root App-of-Apps Application and all child Application
# YAMLs. Requires ARGOCD_REPO_URL to be set to your GitHub fork URL.
# Run from the repo root OR from the solution/scripts/ directory — paths are resolved automatically.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="${SCRIPT_DIR}/../k8s"
GITOPS_APPS_DIR="${SCRIPT_DIR}/../gitops/apps"

# Require ARGOCD_REPO_URL
if [ -z "${ARGOCD_REPO_URL:-}" ]; then
  echo "ERROR: ARGOCD_REPO_URL is not set."
  echo "  Set it to your GitHub fork URL, e.g.:"
  echo "  export ARGOCD_REPO_URL=https://github.com/<your-fork>/302-llmops.git"
  exit 1
fi

echo "==> Using ARGOCD_REPO_URL=${ARGOCD_REPO_URL}"

# Apply namespace for ArgoCD (idempotent)
kubectl apply -f "${K8S_DIR}/90-argocd-namespace.yaml"

# Apply root App-of-Apps Application (substitute <ARGOCD_REPO_URL> placeholder)
echo "==> Applying root App-of-Apps Application..."
sed "s|<ARGOCD_REPO_URL>|${ARGOCD_REPO_URL}|g" \
  "${K8S_DIR}/91-app-of-apps.yaml" | kubectl apply -f -

# Apply all 4 child Application YAMLs (each also carries the <ARGOCD_REPO_URL> placeholder)
echo "==> Applying child Applications from ${GITOPS_APPS_DIR} ..."
for child_yaml in "${GITOPS_APPS_DIR}"/*.yaml; do
  echo "    Applying $(basename "${child_yaml}") ..."
  sed "s|<ARGOCD_REPO_URL>|${ARGOCD_REPO_URL}|g" "${child_yaml}" | kubectl apply -f -
done

echo ""
echo "==> Waiting for root Application to become Available..."
kubectl wait --for=condition=Available application/smile-dental-apps \
  -n argocd --timeout=300s 2>/dev/null || echo "App syncing (may take a few minutes)..."

echo ""
echo "==> Current Application list:"
argocd app list 2>/dev/null || kubectl get application -n argocd
