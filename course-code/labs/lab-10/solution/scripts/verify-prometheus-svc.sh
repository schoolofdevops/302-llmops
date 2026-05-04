#!/usr/bin/env bash
# verify-prometheus-svc.sh — Resolve the actual kube-prometheus-stack Prometheus
# Service name on THIS cluster. Plan 04-02 expects `kps-kube-prometheus-stack-prometheus`
# (RESEARCH.md convention) but if the kube-prometheus-stack chart was renamed/upgraded,
# the Service name may differ. Run this BEFORE applying 80-keda-scaledobject-vllm.yaml.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
# shellcheck disable=SC1091
[ -f "${REPO_ROOT}/config.env" ] && source "${REPO_ROOT}/config.env"

NS_MONITORING="${NS_MONITORING:-monitoring}"

EXPECTED="kps-kube-prometheus-stack-prometheus"

ACTUAL=$(kubectl get svc -n "${NS_MONITORING}" \
  -l "app=kube-prometheus-stack-prometheus" \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [ -z "${ACTUAL}" ]; then
  echo "ERROR: no Prometheus Service found in namespace ${NS_MONITORING}."
  echo "       List all Services: kubectl get svc -n ${NS_MONITORING}"
  exit 1
fi

echo "Expected Prometheus Service name: ${EXPECTED}"
echo "Actual   Prometheus Service name: ${ACTUAL}"

if [ "${ACTUAL}" = "${EXPECTED}" ]; then
  echo "OK — matches RESEARCH.md convention. ScaledObject can use the convention name verbatim."
else
  echo "MISMATCH — update 80-keda-scaledobject-vllm.yaml triggers[0].metadata.serverAddress"
  echo "to: http://${ACTUAL}.${NS_MONITORING}.svc.cluster.local:9090"
  exit 2
fi
