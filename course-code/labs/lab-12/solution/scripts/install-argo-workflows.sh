#!/usr/bin/env bash
# install-argo-workflows.sh — Argo Workflows Helm chart 1.0.13 (server v4.0.5).
# Idempotent: exits 0 if already installed. NodePort 30800 for the UI.
#
# Usage:
#   bash install-argo-workflows.sh
#
# Requires: helm, kubectl pointing at the llmops-kind cluster
set -euo pipefail

# Source central config for pinned versions and namespace vars
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
[ -f "${REPO_ROOT}/course-code/config.env" ] && source "${REPO_ROOT}/course-code/config.env"

NS_ARGO="${NS_ARGO:-argo}"
ARGO_WORKFLOWS_CHART_VERSION="${ARGO_WORKFLOWS_CHART_VERSION:-1.0.13}"
NODEPORT_ARGO_WORKFLOWS="${NODEPORT_ARGO_WORKFLOWS:-30800}"

echo "Installing Argo Workflows chart ${ARGO_WORKFLOWS_CHART_VERSION} in namespace ${NS_ARGO}..."
echo

# Idempotent: skip if already installed
if helm status argo-workflows -n "${NS_ARGO}" >/dev/null 2>&1; then
  echo "Argo Workflows already installed in ${NS_ARGO}:"
  helm status argo-workflows -n "${NS_ARGO}" | grep -E "STATUS|LAST DEPLOYED|CHART"
  echo
  echo "UI available at: http://localhost:${NODEPORT_ARGO_WORKFLOWS}"
  exit 0
fi

# Add Argo Helm repo
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null

# Install with NodePort UI, server auth mode, and controller scoped to argo namespace
helm install argo-workflows argo/argo-workflows \
  --version "${ARGO_WORKFLOWS_CHART_VERSION}" \
  --namespace "${NS_ARGO}" \
  --create-namespace \
  --set server.serviceType=NodePort \
  --set server.serviceNodePort="${NODEPORT_ARGO_WORKFLOWS}" \
  --set "server.authModes={server}" \
  --set workflow.serviceAccount.create=true \
  --set "controller.workflowNamespaces={${NS_ARGO}}" \
  --wait --timeout 5m

echo
echo "Waiting for rollout..."
kubectl rollout status deploy/argo-workflows-server -n "${NS_ARGO}" --timeout=180s
kubectl rollout status deploy/argo-workflows-workflow-controller -n "${NS_ARGO}" --timeout=180s

echo
echo "Argo Workflows installed successfully."
echo "  UI: http://localhost:${NODEPORT_ARGO_WORKFLOWS}"
echo "  Namespace: ${NS_ARGO}"
echo
echo "Next steps:"
echo "  kubectl apply -f k8s/100-argo-workflows-rbac.yaml"
echo "  kubectl apply -f k8s/100-pvc-pipeline-workspace.yaml"
echo "  # Copy llm-api-keys Secret to argo namespace:"
echo "  kubectl get secret llm-api-keys -n llm-agent -o yaml | sed 's/namespace: llm-agent/namespace: argo/' | kubectl apply -f -"
