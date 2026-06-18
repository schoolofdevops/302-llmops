#!/usr/bin/env bash
# trigger-pipeline.sh — Submit a one-shot Workflow run using the llm-pipeline WorkflowTemplate.
# Shows generated Workflow name and watch command.
#
# Usage: bash trigger-pipeline.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_CR="${SCRIPT_DIR}/../k8s/102-workflow-run.yaml"

echo "==> Submitting Workflow from: ${WORKFLOW_CR}"
# Use kubectl create (not apply) — generateName creates a unique name per run.
# kubectl apply would fail with "must specify metadata.name" for generateName resources.
kubectl create -f "${WORKFLOW_CR}"

echo ""
echo "Workflow submitted. Watch progress:"
echo "  kubectl get workflow -n argo -w"
echo "  kubectl logs -n argo -l workflows.argoproj.io/workflow -f --tail=50"
echo ""
echo "Argo Workflows UI: http://localhost:30800"
echo "  Click the workflow in the left panel to see the 5-node DAG."
