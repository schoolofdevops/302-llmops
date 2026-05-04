#!/usr/bin/env bash
# install-keda.sh — Install KEDA 2.19.0 via Helm into namespace keda.
# Idempotent: if release already exists, prints status and exits 0.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
# shellcheck disable=SC1091
[ -f "${REPO_ROOT}/config.env" ] && source "${REPO_ROOT}/config.env"

NS_KEDA="${NS_KEDA:-keda}"
KEDA_VERSION="${KEDA_VERSION:-2.19.0}"

if helm status keda -n "${NS_KEDA}" >/dev/null 2>&1; then
  echo "KEDA already installed in ${NS_KEDA}:"
  helm status keda -n "${NS_KEDA}"
  exit 0
fi

helm repo add kedacore https://kedacore.github.io/charts >/dev/null
helm repo update kedacore >/dev/null

helm install keda kedacore/keda \
  --version "${KEDA_VERSION}" \
  --namespace "${NS_KEDA}" \
  --create-namespace \
  --wait --timeout 5m

echo "Waiting for keda-operator pod to reach Ready=True..."
kubectl rollout status deploy/keda-operator -n "${NS_KEDA}" --timeout=180s
kubectl get pods -n "${NS_KEDA}"
