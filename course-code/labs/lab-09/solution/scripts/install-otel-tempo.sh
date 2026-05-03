#!/usr/bin/env bash
set -euo pipefail

NS="${NS_MONITORING:-monitoring}"
TEMPO_VERSION="${TEMPO_VERSION:-1.24.4}"
OTEL_VERSION="${OTEL_COLLECTOR_VERSION:-0.153.0}"
HELM_DIR="$(cd "$(dirname "$0")/../helm" && pwd)"

echo "[1/4] Adding Helm repos..."
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null

echo "[2/4] Installing Grafana Tempo (chart ${TEMPO_VERSION})..."
helm upgrade --install tempo grafana/tempo \
  --namespace "${NS}" \
  --version "${TEMPO_VERSION}" \
  --values "${HELM_DIR}/values-tempo.yaml" \
  --wait --timeout 5m

echo "[3/4] Installing OpenTelemetry Collector (chart ${OTEL_VERSION})..."
helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
  --namespace "${NS}" \
  --version "${OTEL_VERSION}" \
  --values "${HELM_DIR}/values-otel-collector.yaml" \
  --wait --timeout 5m

echo "[4/4] Verifying Tempo (StatefulSet) and OTEL Collector (Deployment) are Ready..."
# Tempo single-binary mode is a StatefulSet, not a Deployment.
kubectl rollout status statefulset/tempo -n "${NS}" --timeout=180s
kubectl wait --for=condition=available deployment/otel-collector-opentelemetry-collector -n "${NS}" --timeout=180s
kubectl get svc -n "${NS}" | grep -E 'tempo|otel-collector'
