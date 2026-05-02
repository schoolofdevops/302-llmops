#!/usr/bin/env bash
# Resolves RESEARCH.md Open Q1: is the GCR-hosted Sandbox Router image pullable without GCP credentials?
# Run BEFORE install-agent-sandbox.sh — sets the path for the rest of Lab 08.
set -euo pipefail

IMAGE="${SANDBOX_ROUTER_IMAGE:-us-central1-docker.pkg.dev/k8s-staging-images/agent-sandbox/sandbox-router:latest-main}"
MODE_FILE="${1:-/tmp/lab08-router-mode}"

echo "[1/2] Trying to pull Sandbox Router image: ${IMAGE}"
if docker pull "${IMAGE}" 2>&1 | tee /tmp/lab08-router-pull.log; then
  echo "[2/2] PULL SUCCEEDED — using GCR-hosted Router (Service-based gateway)."
  echo "ROUTER_MODE=gcr" > "${MODE_FILE}"
  echo
  echo "Result: Lab 08 will deploy 50-sandbox-router.yaml (Service path)."
  exit 0
else
  echo "[2/2] PULL FAILED — falling back to kubectl port-forward gateway path."
  echo "ROUTER_MODE=port-forward" > "${MODE_FILE}"
  echo
  echo "Result: Lab 08 will SKIP 50-sandbox-router.yaml and instead use 'kubectl port-forward' against a Sandbox pod's service."
  echo "Reason: $(tail -1 /tmp/lab08-router-pull.log)"
  exit 0
fi
