#!/usr/bin/env bash
# install-metrics-server.sh — Install Kubernetes metrics-server with KIND patch.
# metrics-server is required for HPA on CPU (SCALE-01). KIND uses self-signed kubelet
# certs, so we add --kubelet-insecure-tls.
set -euo pipefail

if kubectl get deployment metrics-server -n kube-system >/dev/null 2>&1; then
  echo "metrics-server already installed."
  exit 0
fi

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch: add --kubelet-insecure-tls (KIND kubelet uses self-signed cert)
kubectl patch deployment metrics-server -n kube-system --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}
]'

echo "Waiting for metrics-server to roll out..."
kubectl rollout status deploy/metrics-server -n kube-system --timeout=180s

# Verify metrics API works
echo "Validating: kubectl top nodes (may take ~30s for first scrape)..."
for i in $(seq 1 12); do
  if kubectl top nodes >/dev/null 2>&1; then
    echo "metrics-server OK after ${i} attempts."
    kubectl top nodes
    exit 0
  fi
  sleep 5
done
echo "ERROR: kubectl top nodes did not return values after 60s. Check: kubectl logs -n kube-system deploy/metrics-server"
exit 1
