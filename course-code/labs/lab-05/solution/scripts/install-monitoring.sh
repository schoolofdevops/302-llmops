#!/usr/bin/env bash
# install-monitoring.sh — Install kube-prometheus-stack for Lab 06 observability
# Chart: prometheus-community/kube-prometheus-stack 83.4.2
# Grafana: NodePort 30400 | Prometheus: NodePort 30500
#
# Usage: bash install-monitoring.sh

set -euo pipefail

NAMESPACE="monitoring"
RELEASE="kps"
CHART="prometheus-community/kube-prometheus-stack"
CHART_VERSION="83.4.2"

echo "=== Installing kube-prometheus-stack ==="
echo "  Namespace: ${NAMESPACE}"
echo "  Grafana:   http://localhost:30400 (admin/prom-operator)"
echo "  Prometheus: http://localhost:30500"
echo ""

# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install / upgrade
helm upgrade --install "${RELEASE}" "${CHART}" \
  --version "${CHART_VERSION}" \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30400 \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30500 \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=prom-operator \
  --set alertmanager.enabled=false \
  --wait \
  --timeout 5m

echo ""
echo "=== kube-prometheus-stack installed ==="
echo "  Grafana:    http://localhost:30400  (user: admin, pass: prom-operator)"
echo "  Prometheus: http://localhost:30500"
echo ""
echo "Next: Apply ServiceMonitors from k8s/observability/"
echo "  kubectl apply -f course-code/labs/lab-06/solution/k8s/observability/"
