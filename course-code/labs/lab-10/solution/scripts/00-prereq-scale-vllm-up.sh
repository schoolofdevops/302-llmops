#!/usr/bin/env bash
# 00-prereq-scale-vllm-up.sh — Lab 10 first action.
#
# Phase 3 D-19/D-20 scaled vllm-smollm2 to replicas=0 at the end of Lab 06 to keep KIND
# lean while Day 2 used the cloud LLM. Lab 10 needs vLLM running again so KEDA has a
# Deployment to scale. This script reverses the wind-down (D-05).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
# shellcheck disable=SC1091
[ -f "${REPO_ROOT}/config.env" ] && source "${REPO_ROOT}/config.env"

NS_SERVING="${NS_SERVING:-llm-serving}"
# Deployment name is fixed — the same vllm-smollm2 Deployment from Lab 04 (D-05)
DEPLOY="vllm-smollm2"

echo "[1/3] Scaling vllm-smollm2 back to 1 replica in namespace ${NS_SERVING}…"
# Equivalent: kubectl scale deploy vllm-smollm2 --replicas=1 -n llm-serving
kubectl scale deploy "${DEPLOY}" --replicas=1 -n "${NS_SERVING}"

echo "[2/3] Waiting up to 4 minutes for rollout (CPU model load is 60-180s)…"
kubectl rollout status deploy "${DEPLOY}" -n "${NS_SERVING}" --timeout=240s

echo "[3/3] Confirming vLLM /health responds…"
POD=$(kubectl get pod -n "${NS_SERVING}" -l app=vllm -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n "${NS_SERVING}" "${POD}" -- \
  python3 -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8000/health', timeout=5).read().decode())" \
  || { echo "ERROR: vLLM /health did not respond. Inspect: kubectl logs -n ${NS_SERVING} ${POD}"; exit 1; }

echo
echo "OK: vLLM is back up. Proceed with the Lab 10 walkthrough."
echo "Reminder (D-21): if your KIND is tight on memory, scale agent Sandbox WarmPool to 1 replica:"
echo "  kubectl scale sandboxwarmpool hermes-agent-pool --replicas=1 -n llm-agent"
