#!/usr/bin/env bash
# run-loadgen.sh — Delete existing hey Job (if any) and submit a new 3-minute load test
# Usage: bash run-loadgen.sh [a|b|c]
#   a = Pattern A: plain vLLM Deployment (vllm-smollm2) — DEFAULT
#   b = Pattern B: vllm-stack router (lmstack-router)
#   c = Pattern C: KServe InferenceService predictor (smollm2-predictor)
#
# Prerequisites:
#   kubectl must be configured and pointing to the llmops-kind cluster
#   The target serving pattern must be running (check with kubectl get pods -n llm-serving)

set -euo pipefail

PATTERN="${1:-a}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${PATTERN}" in
  a|A)
    JOB_MANIFEST="${SCRIPT_DIR}/../k8s/81-loadgen-job-hey-pattern-a.yaml"
    JOB_NAME="vllm-loadgen-pattern-a"
    ;;
  b|B)
    JOB_MANIFEST="${SCRIPT_DIR}/../k8s/81-loadgen-job-hey-pattern-b.yaml"
    JOB_NAME="vllm-loadgen-pattern-b"
    ;;
  c|C)
    JOB_MANIFEST="${SCRIPT_DIR}/../k8s/81-loadgen-job-hey-pattern-c.yaml"
    JOB_NAME="vllm-loadgen-pattern-c"
    ;;
  *)
    echo "Usage: $0 [a|b|c]"
    echo "  a = Pattern A: plain vLLM Deployment (default)"
    echo "  b = Pattern B: vllm-stack router"
    echo "  c = Pattern C: KServe InferenceService predictor"
    exit 1
    ;;
esac

echo "Cleaning up any existing load test job for Pattern ${PATTERN}..."
kubectl delete job "${JOB_NAME}" -n llm-serving --ignore-not-found=true

echo "Submitting load test for Pattern ${PATTERN}..."
kubectl apply -f "${JOB_MANIFEST}"

echo ""
echo "Load test submitted for Pattern ${PATTERN}. Watch scale-up in separate terminals:"
echo ""
echo "  # Watch pod scaling:"
echo "  kubectl get pods -n llm-serving -w"
echo ""
echo "  # Watch KEDA ScaledObjects:"
echo "  kubectl get scaledobject -n llm-serving -w"
echo ""
echo "  # Watch HPA activity (includes KEDA-managed HPA):"
echo "  kubectl get hpa -n llm-serving -w"
echo ""
echo "The load test runs for 180 seconds with 4 concurrent connections."
echo "Expected: second pod starts within ~30-45s of metric crossing threshold."
echo "The Job auto-deletes after 600s (spec.ttlSecondsAfterFinished: 600)."
