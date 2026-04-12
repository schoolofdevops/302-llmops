#!/usr/bin/env bash
# cleanup-phase1.sh — Remove Day 1 lab workloads (Labs 00-05)
# Removes: KServe InferenceService, vLLM, RAG Retriever
# Keeps: namespaces, KIND cluster, monitoring stack
#
# Run from course-code repo root:
#   bash shared/scripts/cleanup-phase1.sh
set -euo pipefail

echo "============================================="
echo " LLMOps — Phase 1 Cleanup (after Labs 00-05)"
echo "============================================="
echo ""
echo "This will remove vLLM, KServe InferenceService, and RAG Retriever workloads."
echo "Namespaces and the KIND cluster will be preserved."
echo ""
read -r -p "Proceed? (y/N): " CONFIRM
if [[ ! "${CONFIRM}" =~ ^[Yy]$ ]]; then
  echo "Cleanup cancelled."
  exit 0
fi

# --- llm-serving namespace: vLLM + KServe ---
echo ""
echo "==> Removing KServe InferenceService from llm-serving..."
kubectl delete inferenceservice --all -n llm-serving --ignore-not-found=true 2>/dev/null || true

echo "==> Removing vLLM Deployment and Service from llm-serving..."
kubectl delete deployment,service,replicaset -l app=vllm -n llm-serving --ignore-not-found=true 2>/dev/null || true
kubectl delete deployment,service,replicaset -l app.kubernetes.io/name=vllm -n llm-serving --ignore-not-found=true 2>/dev/null || true

echo "==> Removing all remaining workloads from llm-serving..."
kubectl delete pods,deployments,services,replicasets,jobs,configmaps -n llm-serving --ignore-not-found=true 2>/dev/null || true

# --- llm-app namespace: RAG Retriever ---
echo ""
echo "==> Removing RAG Retriever from llm-app..."
kubectl delete deployment,service -l app=rag-retriever -n llm-app --ignore-not-found=true 2>/dev/null || true
kubectl delete deployment,service -l app=retriever -n llm-app --ignore-not-found=true 2>/dev/null || true

# --- Show remaining resource usage ---
echo ""
echo "==> Remaining pods (should be empty or only system pods):"
kubectl get pods -n llm-serving 2>/dev/null || true
kubectl get pods -n llm-app 2>/dev/null || true

echo ""
echo "==> Cluster resource usage after cleanup:"
kubectl top nodes 2>/dev/null || echo "(metrics-server not installed — skipping resource usage)"

echo ""
echo "============================================="
echo " Phase 1 cleanup complete."
echo " Your cluster is ready for Phase 2 (Labs 06-09)."
echo "============================================="
