#!/usr/bin/env bash
# run-loadgen.sh — Apply the hey loadgen Job and observe KEDA scale events.
# Tail Job logs + watch Deployment replicas alongside; pause for 5 minutes total
# (3 min loadgen + 2 min cooldown observation).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
# shellcheck disable=SC1091
[ -f "${REPO_ROOT}/config.env" ] && source "${REPO_ROOT}/config.env"

NS_SERVING="${NS_SERVING:-llm-serving}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

kubectl delete job vllm-loadgen -n "${NS_SERVING}" --ignore-not-found
kubectl apply -f "${SCRIPT_DIR}/../k8s/81-loadgen-job-hey.yaml"

echo "Loadgen Job applied. Replica count over the next ~5 minutes:"
echo "(open Grafana to /d/smile-dental-autoscaling for the live pod-count + queue-depth panel pair)"
echo

for i in $(seq 1 20); do
  REPLICAS=$(kubectl get deploy vllm-smollm2 -n "${NS_SERVING}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  WAIT=$(kubectl get scaledobject vllm-smollm2 -n "${NS_SERVING}" -o jsonpath='{.status.conditions[?(@.type=="Active")].status}' 2>/dev/null || echo "?")
  echo "[$(date +%H:%M:%S)] vllm-smollm2 replicas=${REPLICAS}  scaledobject_active=${WAIT}"
  sleep 15
done

echo
echo "Loadgen Job + observation window finished. Final state:"
kubectl get scaledobject vllm-smollm2 -n "${NS_SERVING}"
kubectl get hpa keda-hpa-vllm-smollm2 -n "${NS_SERVING}" 2>/dev/null || true
kubectl get deploy vllm-smollm2 -n "${NS_SERVING}"
