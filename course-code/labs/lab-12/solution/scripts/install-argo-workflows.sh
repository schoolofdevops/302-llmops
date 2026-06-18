#!/usr/bin/env bash
# install-argo-workflows.sh — Argo Workflows Helm chart 1.0.13 → server v4.0.5.
# Idempotent. NodePort 30800 for the UI.
#
# Usage: bash install-argo-workflows.sh
#
# NOTE: Uses --skip-crds because the Helm chart's pre-install CRD Job
# (argo-workflows-crd-install) times out on some machines when CRDs already exist
# from a prior install attempt. CRDs are applied separately via kubectl before Helm
# (see "Apply CRDs" step below) — this is safe and idempotent on re-runs.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

# ---- Variables (override via env vars) ----
NS_ARGO="${NS_ARGO:-argo}"
ARGO_WORKFLOWS_CHART_VERSION="${ARGO_WORKFLOWS_CHART_VERSION:-1.0.13}"
ARGO_WORKFLOWS_APP_VERSION="${ARGO_WORKFLOWS_APP_VERSION:-v4.0.5}"
NODEPORT_ARGO_WORKFLOWS="${NODEPORT_ARGO_WORKFLOWS:-30800}"

echo "==> Installing Argo Workflows ${ARGO_WORKFLOWS_CHART_VERSION} in namespace ${NS_ARGO} ..."

# ---- Apply CRDs first (idempotent via server-side apply) ----
# This must run before helm install --skip-crds so the CRDs exist on a fresh cluster.
# On re-runs, server-side apply is a no-op if CRDs are unchanged.
echo "==> Applying Argo Workflows CRDs (${ARGO_WORKFLOWS_APP_VERSION}) ..."
kubectl apply --server-side \
  -f "https://raw.githubusercontent.com/argoproj/argo-workflows/${ARGO_WORKFLOWS_APP_VERSION}/manifests/crds/workflow-crd.yaml" \
  2>/dev/null || true
kubectl apply --server-side \
  -f "https://raw.githubusercontent.com/argoproj/argo-workflows/${ARGO_WORKFLOWS_APP_VERSION}/manifests/crds/workflowtemplate-crd.yaml" \
  2>/dev/null || true
kubectl apply --server-side \
  -f "https://raw.githubusercontent.com/argoproj/argo-workflows/${ARGO_WORKFLOWS_APP_VERSION}/manifests/crds/cronworkflow-crd.yaml" \
  2>/dev/null || true
kubectl apply --server-side \
  -f "https://raw.githubusercontent.com/argoproj/argo-workflows/${ARGO_WORKFLOWS_APP_VERSION}/manifests/crds/clusterworkflowtemplate-crd.yaml" \
  2>/dev/null || true
echo "    CRDs applied."

# ---- Idempotency guard ----
if helm status argo-workflows -n "${NS_ARGO}" >/dev/null 2>&1; then
  echo "    Argo Workflows already installed — skipping install."
  echo "    Run 'helm upgrade argo-workflows argo/argo-workflows ...' to upgrade."
else
  helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
  helm repo update argo >/dev/null

  # --skip-crds: CRDs were applied above via kubectl (server-side apply).
  # This avoids the Helm chart's pre-install CRD Job which can time out if
  # CRDs already exist from a prior attempt.
  helm install argo-workflows argo/argo-workflows \
    --version "${ARGO_WORKFLOWS_CHART_VERSION}" \
    --namespace "${NS_ARGO}" \
    --create-namespace \
    --skip-crds \
    --set server.serviceType=NodePort \
    --set server.serviceNodePort="${NODEPORT_ARGO_WORKFLOWS}" \
    --set "server.authModes={server}" \
    --set workflow.serviceAccount.create=true \
    --set "controller.workflowNamespaces={${NS_ARGO}}" \
    --wait --timeout 5m

  echo "    Argo Workflows installed."
fi

# ---- Wait for deployments ----
echo "==> Waiting for argo-workflows-server ..."
kubectl rollout status deploy/argo-workflows-server -n "${NS_ARGO}" --timeout=180s

echo "==> Waiting for argo-workflows-workflow-controller ..."
kubectl rollout status deploy/argo-workflows-workflow-controller -n "${NS_ARGO}" --timeout=180s

echo ""
echo "Argo Workflows up. UI: http://localhost:${NODEPORT_ARGO_WORKFLOWS}"
echo "  No auth required (authModes=server for lab convenience)."
echo "  kubectl get pods -n ${NS_ARGO}"
