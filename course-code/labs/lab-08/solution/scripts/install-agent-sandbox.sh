#!/usr/bin/env bash
# Idempotent install of Kubernetes Agent Sandbox v0.4.3 on a KIND cluster.
set -euo pipefail

VERSION="${SANDBOX_VERSION:-v0.4.3}"
NS_AGENT="${NS_AGENT:-llm-agent}"
NS_SYS="agent-sandbox-system"

echo "[1/5] Installing Agent Sandbox core CRDs + controller (${VERSION})..."
kubectl apply -f "https://github.com/kubernetes-sigs/agent-sandbox/releases/download/${VERSION}/manifest.yaml"

echo "[2/5] Installing Agent Sandbox extension CRDs (SandboxTemplate, SandboxWarmPool, SandboxClaim)..."
kubectl apply -f "https://github.com/kubernetes-sigs/agent-sandbox/releases/download/${VERSION}/extensions.yaml"

echo "[3/5] Waiting for controller Deployment to become Available (timeout 180 s)..."
# NOTE: v0.4.3 uses 'agent-sandbox-controller' (not '...-manager' from older docs)
CONTROLLER_DEPLOY=$(kubectl get deploy -n "${NS_SYS}" -o jsonpath='{.items[0].metadata.name}')
kubectl wait --for=condition=available "deployment/${CONTROLLER_DEPLOY}" \
  -n "${NS_SYS}" --timeout=180s

echo "[4/5] Verifying CRDs are registered..."
for crd in sandboxes.agents.x-k8s.io sandboxtemplates.extensions.agents.x-k8s.io \
           sandboxwarmpools.extensions.agents.x-k8s.io sandboxclaims.extensions.agents.x-k8s.io; do
  kubectl get crd "${crd}" -o jsonpath='{.metadata.name}{" "}{.spec.versions[0].name}{"\n"}'
done

echo "[5/5] Creating ${NS_AGENT} namespace..."
kubectl apply -f "$(dirname "$0")/../k8s/00-namespace.yaml"

echo
echo "OK: Agent Sandbox ${VERSION} controller is Ready (deployment: ${CONTROLLER_DEPLOY}), CRDs are registered, and ${NS_AGENT} namespace exists."
