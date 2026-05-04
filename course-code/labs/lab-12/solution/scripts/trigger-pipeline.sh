#!/usr/bin/env bash
# trigger-pipeline.sh — Submit the llm-pipeline Workflow and stream status.
#
# Usage:
#   bash trigger-pipeline.sh                # PASS path (threshold=0.7, real eval)
#   bash trigger-pipeline.sh --force-fail   # FAIL path (threshold=0.99 — almost guaranteed to fail)
#
# EVAL-02 demo mechanic:
#   PASS path: eval writes 'true' -> commit-tag step runs -> ArgoCD syncs vLLM
#   FAIL path: eval writes 'false' -> commit-tag step has when: false -> SKIPPED -> no git commit
set -euo pipefail

NS_ARGO="${NS_ARGO:-argo}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${SCRIPT_DIR}/../k8s/101-workflowtemplate-llm-pipeline.yaml"

THRESHOLD="0.7"
if [[ "${1:-}" == "--force-fail" ]]; then
  THRESHOLD="0.99"
  echo "FAIL path: setting threshold=0.99 — eval will fail; commit-tag step will be SKIPPED."
  echo "(This demonstrates EVAL-02: the quality gate blocks deployment on regression.)"
else
  echo "PASS path: setting threshold=0.7 — eval should pass; commit-tag step will run."
fi
echo

# Ensure the WorkflowTemplate is up-to-date before submitting
kubectl apply -f "${TEMPLATE}" -n "${NS_ARGO}"
echo

# Submit a one-shot Workflow with overridden threshold parameter
WORKFLOW_NAME=$(kubectl create -f - -o jsonpath='{.metadata.name}' <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: llm-pipeline-
  namespace: ${NS_ARGO}
spec:
  workflowTemplateRef:
    name: llm-pipeline
  arguments:
    parameters:
    - name: threshold
      value: "${THRESHOLD}"
EOF
)

echo "Submitted Workflow: ${WORKFLOW_NAME}"
echo
echo "Streaming status (Ctrl-C to detach; Workflow keeps running):"

# Poll for up to 20 minutes (eval can take ~2-3 min for 12 cases at 2s sleep)
for i in $(seq 1 120); do
  PHASE=$(kubectl get workflow "${WORKFLOW_NAME}" -n "${NS_ARGO}" \
    -o jsonpath='{.status.phase}' 2>/dev/null || echo "?")
  printf "\r[%s] phase=%-12s  (attempt %d/120)" "$(date +%H:%M:%S)" "${PHASE}" "${i}"
  if [[ "${PHASE}" == "Succeeded" || "${PHASE}" == "Failed" || "${PHASE}" == "Error" ]]; then
    echo
    break
  fi
  sleep 10
done

echo
echo "--- Final Workflow state ---"
kubectl get workflow "${WORKFLOW_NAME}" -n "${NS_ARGO}"
echo
echo "--- Node breakdown (task name / phase / outputs) ---"
kubectl get workflow "${WORKFLOW_NAME}" -n "${NS_ARGO}" \
  -o jsonpath='{.status.nodes}' 2>/dev/null \
  | python3 -m json.tool 2>/dev/null \
  | python3 -c "
import sys, json
nodes = json.load(sys.stdin)
for n in nodes.values():
    display = n.get('displayName', n.get('id', ''))
    phase = n.get('phase', '?')
    outputs = n.get('outputs', {}).get('parameters', [])
    out_str = ', '.join(f\"{p['name']}={p.get('value','?')}\" for p in outputs) if outputs else ''
    print(f'  {display:<20} {phase:<12} {out_str}')
" 2>/dev/null || echo "  (node detail unavailable)"

echo
# Show whether commit-tag was skipped or ran
EVAL_PASS=$(kubectl get workflow "${WORKFLOW_NAME}" -n "${NS_ARGO}" \
  -o jsonpath='{.status.nodes}' 2>/dev/null \
  | python3 -c "
import sys, json
nodes = json.load(sys.stdin)
for n in nodes.values():
    if 'eval' in n.get('displayName', '').lower():
        params = n.get('outputs', {}).get('parameters', [])
        for p in params:
            if p['name'] == 'pass':
                print(p.get('value', '?'))
                sys.exit(0)
print('unknown')
" 2>/dev/null || echo "unknown")

COMMIT_PHASE=$(kubectl get workflow "${WORKFLOW_NAME}" -n "${NS_ARGO}" \
  -o jsonpath='{.status.nodes}' 2>/dev/null \
  | python3 -c "
import sys, json
nodes = json.load(sys.stdin)
for n in nodes.values():
    if 'commit' in n.get('displayName', '').lower():
        print(n.get('phase', '?'))
        sys.exit(0)
print('not-found')
" 2>/dev/null || echo "unknown")

echo "eval output (pass): ${EVAL_PASS}"
echo "commit-tag phase:   ${COMMIT_PHASE}"
echo
if [[ "${EVAL_PASS}" == "true" && "${COMMIT_PHASE}" == "Succeeded" ]]; then
  echo "PASS PATH COMPLETE: eval=true -> commit-tag ran -> check ArgoCD for auto-sync within 3 min."
  echo "  kubectl describe application vllm -n argocd | grep -A5 'Last Sync'"
elif [[ "${EVAL_PASS}" == "false" && "${COMMIT_PHASE}" =~ ^(Skipped|Omitted|not-found)$ ]]; then
  echo "FAIL PATH COMPLETE: eval=false -> commit-tag SKIPPED -> no git commit -> vLLM unchanged."
  echo "  (This is EVAL-02: the quality gate blocked deployment.)"
else
  echo "Status: eval=${EVAL_PASS}, commit-tag=${COMMIT_PHASE}"
fi
