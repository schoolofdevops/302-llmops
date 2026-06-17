#!/usr/bin/env bash
# install-kps.sh — Reinstall kube-prometheus-stack for Lab 10 (absent after cluster recreate)
# Chart: prometheus-community/kube-prometheus-stack 83.4.2
# Grafana: NodePort 30090 | Prometheus: NodePort 30500
#
# NOTE: Lab 10 uses Grafana on 30090 (different from Lab 06 which uses 30400).
# The 30090 slot is already mapped in kind-config.yaml from cluster setup.
#
# Usage: bash install-kps.sh
# Run from any directory — script uses absolute Helm chart references.

set -euo pipefail

NAMESPACE="monitoring"
RELEASE="kps"
CHART="prometheus-community/kube-prometheus-stack"
CHART_VERSION="83.4.2"

echo "=== Reinstalling kube-prometheus-stack for Lab 10 ==="
echo "  Namespace:  ${NAMESPACE}"
echo "  Release:    ${RELEASE}"
echo "  Grafana:    http://localhost:30090 (admin/prom-operator)"
echo "  Prometheus: http://localhost:30500"
echo ""

# Add Helm repo (idempotent)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update prometheus-community

# Install / upgrade (idempotent)
helm upgrade --install "${RELEASE}" "${CHART}" \
  --version "${CHART_VERSION}" \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30090 \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30500 \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=prom-operator \
  --set alertmanager.enabled=false \
  --wait \
  --timeout 5m

echo ""
echo "=== kube-prometheus-stack installed (release=kps) ==="
echo "  Grafana:    http://localhost:30090  (user: admin, pass: prom-operator)"
echo "  Prometheus: http://localhost:30500"
echo ""
echo "KEDA ScaledObject serverAddress:"
echo "  http://kps-kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090"
echo ""
echo "Next: Apply ServiceMonitors from lab-05 observability manifests:"
echo "  kubectl apply -f course-code/labs/lab-05/solution/k8s/observability/"
