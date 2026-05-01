#!/usr/bin/env bash
# bootstrap-kind.sh — Create the LLMOps KIND cluster and namespaces
# Run from the course-code repo root: bash labs/lab-00/starter/scripts/bootstrap-kind.sh
set -euo pipefail

CLUSTER_NAME="llmops-kind"
REGISTRY_NAME="kind-registry"
REGISTRY_PORT=5001
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
KIND_CONFIG="${SCRIPT_DIR}/../setup/kind-config.yaml"

echo "============================================="
echo " LLMOps — Bootstrap KIND Cluster"
echo "============================================="
echo ""

# --- /etc/hosts: make kind-registry resolvable on the host ---
if ! /usr/bin/grep -q "kind-registry" /etc/hosts 2>/dev/null; then
  echo "==> Adding 127.0.0.1 kind-registry to /etc/hosts (requires sudo)..."
  echo "127.0.0.1 kind-registry" | sudo tee -a /etc/hosts > /dev/null
  echo "Added 127.0.0.1 kind-registry to /etc/hosts"
else
  echo "==> kind-registry already in /etc/hosts"
fi
echo ""

# --- Local Container Registry ---
echo "==> Setting up local container registry (kind-registry:${REGISTRY_PORT})..."
if docker ps --format '{{.Names}}' 2>/dev/null | /usr/bin/grep -q "^${REGISTRY_NAME}$"; then
  echo "Registry already running: ${REGISTRY_NAME}"
else
  docker run -d \
    --name "${REGISTRY_NAME}" \
    --restart=always \
    -p "${REGISTRY_PORT}:${REGISTRY_PORT}" \
    -e "REGISTRY_HTTP_ADDR=0.0.0.0:${REGISTRY_PORT}" \
    registry:2
  echo "Registry started: ${REGISTRY_NAME} on port ${REGISTRY_PORT}"
fi
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
  TMP_CONFIG=$(mktemp /tmp/kind-config-XXXXXXXX)
  # Note: no .yaml suffix — macOS mktemp requires X's at end
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
echo "==> Connecting registry to KIND network..."
docker network connect kind "${REGISTRY_NAME}" 2>/dev/null || echo "Registry already connected to KIND network"

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
