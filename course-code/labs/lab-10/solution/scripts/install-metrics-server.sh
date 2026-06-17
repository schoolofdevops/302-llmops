#!/usr/bin/env bash
# install-metrics-server.sh — Install metrics-server for HPA (KIND requires --kubelet-insecure-tls patch)
# Source: https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# Namespace: kube-system
#
# KIND clusters use self-signed kubelet TLS certs — metrics-server must bypass verification.
# The --kubelet-insecure-tls flag is added via kubectl patch after install.
#
# Usage: bash install-metrics-server.sh

set -euo pipefail

echo "=== Installing metrics-server for HPA support ==="
echo ""

# Idempotency guard: skip if already installed
if kubectl get deployment metrics-server -n kube-system >/dev/null 2>&1; then
  echo "metrics-server already installed — checking readiness..."
  kubectl get deployment metrics-server -n kube-system
  echo "Skipping reinstall."
  exit 0
fi

echo "==> Applying metrics-server manifests..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

echo ""
echo "==> Patching metrics-server for KIND (--kubelet-insecure-tls)..."
kubectl patch deployment metrics-server -n kube-system \
  --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

echo ""
echo "==> Waiting for metrics-server rollout..."
kubectl rollout status deploy/metrics-server -n kube-system --timeout=180s

echo ""
echo "==> Verifying kubectl top nodes..."
kubectl top nodes

echo ""
echo "=== metrics-server installed ==="
echo "  HPA can now use CPU/memory metrics from the Kubernetes Metrics API."
echo "  KEDA Prometheus scaler uses Prometheus directly (not metrics-server)."
