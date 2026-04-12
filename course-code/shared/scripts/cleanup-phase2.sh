#!/usr/bin/env bash
# cleanup-phase2.sh — Remove Day 2 lab workloads (Labs 06-09)
# Removes: Chainlit UI, Chat API, Hermes Agent, K8s Agent Sandbox resources
# Keeps: monitoring stack, namespaces, KIND cluster
#
# Run from course-code repo root:
#   bash shared/scripts/cleanup-phase2.sh
set -euo pipefail

echo "============================================="
echo " LLMOps — Phase 2 Cleanup (after Labs 06-09)"
echo "============================================="
echo ""
echo "This will remove the Chat UI, Chat API, Agent API, and Agent Sandbox resources."
echo "The monitoring stack (Prometheus/Grafana) will be preserved."
echo ""
read -r -p "Proceed? (y/N): " CONFIRM
if [[ ! "${CONFIRM}" =~ ^[Yy]$ ]]; then
  echo "Cleanup cancelled."
  exit 0
fi

# --- llm-app namespace: Chainlit + Chat API + Agent API ---
echo ""
echo "==> Removing Chainlit UI from llm-app..."
kubectl delete deployment,service -l app=chainlit -n llm-app --ignore-not-found=true 2>/dev/null || true

echo "==> Removing Chat API from llm-app..."
kubectl delete deployment,service -l app=chat-api -n llm-app --ignore-not-found=true 2>/dev/null || true

echo "==> Removing Agent API from llm-app..."
kubectl delete deployment,service -l app=agent-api -n llm-app --ignore-not-found=true 2>/dev/null || true
kubectl delete deployment,service -l app=hermes-agent -n llm-app --ignore-not-found=true 2>/dev/null || true

# --- K8s Agent Sandbox CRD resources ---
echo ""
echo "==> Removing Agent Sandbox resources (if installed)..."
kubectl delete sandbox --all -n llm-app --ignore-not-found=true 2>/dev/null || true
kubectl delete sandboxwarmpool --all -n llm-app --ignore-not-found=true 2>/dev/null || true
kubectl delete pods,deployments,services -l app=sandbox-controller -n llm-app --ignore-not-found=true 2>/dev/null || true

# --- Show remaining resource usage ---
echo ""
echo "==> Remaining pods in llm-app (should be empty or only system pods):"
kubectl get pods -n llm-app 2>/dev/null || true

echo ""
echo "============================================="
echo " Phase 2 cleanup complete."
echo " Your cluster is ready for Phase 3 (Labs 09-13)."
echo " Monitoring stack (Prometheus/Grafana) is still running."
echo "============================================="
