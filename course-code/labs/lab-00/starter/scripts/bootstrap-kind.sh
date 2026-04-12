#!/usr/bin/env bash
# bootstrap-kind.sh — Create the LLMOps KIND cluster and namespaces
# Run from the course-code repo root: bash labs/lab-00/starter/scripts/bootstrap-kind.sh
set -euo pipefail

CLUSTER_NAME="llmops-kind"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
KIND_CONFIG="${SCRIPT_DIR}/../setup/kind-config.yaml"

echo "============================================="
echo " LLMOps — Bootstrap KIND Cluster"
echo "============================================="
echo ""

# Detect if running from starter (has REPLACE_HOST_PATH) or solution
if /usr/bin/grep -q "REPLACE_HOST_PATH" "${KIND_CONFIG}"; then
  echo "Detected REPLACE_HOST_PATH in kind-config.yaml."
  echo "Please enter the absolute path to your project directory."
  echo "This is the directory where your lab files will live on your machine."
  echo ""
  read -r -p "Project directory path (e.g. /Users/yourname/llmops-project): " HOST_PATH
  if [ -z "$HOST_PATH" ]; then
    echo "ERROR: Path cannot be empty."
    exit 1
  fi
  # Create a temporary config with the path substituted
  TMP_CONFIG=$(mktemp /tmp/kind-config-XXXXX.yaml)
  sed "s|REPLACE_HOST_PATH|${HOST_PATH}|g" "${KIND_CONFIG}" > "${TMP_CONFIG}"
  KIND_CONFIG="${TMP_CONFIG}"
  echo ""
  echo "Using project path: ${HOST_PATH}"
fi

# Check for existing cluster
if kind get clusters 2>/dev/null | /usr/bin/grep -q "${CLUSTER_NAME}"; then
  echo "Cluster ${CLUSTER_NAME} already exists."
  read -r -p "Delete and recreate? (y/N): " CONFIRM
  if [[ "${CONFIRM}" =~ ^[Yy]$ ]]; then
    kind delete cluster --name "${CLUSTER_NAME}"
  else
    echo "Skipping cluster creation. Applying namespaces only."
    kubectl apply -f "${REPO_ROOT}/shared/k8s/namespaces.yaml"
    echo ""
    echo "Namespaces applied. Your cluster is ready."
    exit 0
  fi
fi

echo ""
echo "==> Creating KIND cluster: ${CLUSTER_NAME}"
kind create cluster --config "${KIND_CONFIG}" --wait 5m

echo ""
echo "==> Verifying cluster nodes..."
kubectl get nodes

echo ""
echo "==> Creating namespaces..."
kubectl apply -f "${REPO_ROOT}/shared/k8s/namespaces.yaml"

echo ""
echo "==> Verifying namespaces..."
kubectl get namespaces | /usr/bin/grep -E "llm-serving|llm-app|monitoring|argocd|argo-workflows"

echo ""
echo "============================================="
echo " Cluster ready: ${CLUSTER_NAME}"
echo " Run: kubectl get nodes"
echo "============================================="
