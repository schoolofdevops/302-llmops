#!/usr/bin/env bash
# install-keda.sh — Install KEDA 2.19.0 for Lab 10 autoscaling
# Chart: kedacore/keda 2.19.0
# Namespace: keda
#
# Usage: bash install-keda.sh
# Run from the repo root or any directory.

set -euo pipefail

# --- Repo root detection (PATTERNS.md pattern) ---
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

# Source optional config.env for overrides
[ -f "${REPO_ROOT}/config.env" ] && source "${REPO_ROOT}/config.env"

NS_KEDA="${NS_KEDA:-keda}"
KEDA_VERSION="${KEDA_VERSION:-2.19.0}"

echo "=== Installing KEDA ${KEDA_VERSION} for Lab 10 autoscaling ==="
echo "  Namespace: ${NS_KEDA}"
echo "  Version:   ${KEDA_VERSION}"
echo ""

# Idempotency guard: skip if already installed
if helm status keda -n "${NS_KEDA}" >/dev/null 2>&1; then
  echo "KEDA already installed in namespace ${NS_KEDA} — skipping."
  helm status keda -n "${NS_KEDA}" | grep -E "STATUS:|REVISION:"
  exit 0
fi

# Add Helm repo
helm repo add kedacore https://kedacore.github.io/charts 2>/dev/null || true
helm repo update kedacore

# Install
helm install keda kedacore/keda \
  --version "${KEDA_VERSION}" \
  --namespace "${NS_KEDA}" \
  --create-namespace \
  --wait \
  --timeout 5m

echo ""
echo "=== Verifying KEDA operator rollout ==="
kubectl rollout status deploy/keda-operator -n "${NS_KEDA}" --timeout=180s

echo ""
echo "=== KEDA pods ==="
kubectl get pods -n "${NS_KEDA}"

echo ""
echo "=== KEDA ${KEDA_VERSION} installed ==="
echo "  keda-operator, keda-metrics-apiserver, keda-admission-webhooks are Running"
