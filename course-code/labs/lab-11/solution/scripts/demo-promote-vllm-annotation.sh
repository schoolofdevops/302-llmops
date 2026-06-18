#!/usr/bin/env bash
# demo-promote-vllm-annotation.sh — Bump gitops/model-version annotation in vLLM manifest
# to trigger ArgoCD sync and rolling restart. Run from the repo root.
#
# What this demonstrates:
#   1. Edit a manifest value in git (the annotation bump)
#   2. Commit and push
#   3. ArgoCD detects the diff (default poll: 3 min; or argocd app sync to force)
#   4. ArgoCD applies the updated Deployment → Kubernetes rolls out the updated pod
set -euo pipefail

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TARGET_FILE="course-code/labs/lab-11/solution/gitops/bases/vllm/30-deploy-vllm.yaml"

if [ ! -f "${TARGET_FILE}" ]; then
  echo "ERROR: Cannot find ${TARGET_FILE}. Run this script from the repository root."
  exit 1
fi

echo "==> Bumping gitops/model-version to run-${TIMESTAMP} in ${TARGET_FILE}"

# Substitute the annotation value (macOS sed creates .bak; remove immediately)
sed -i.bak "s/gitops\/model-version: \".*\"/gitops\/model-version: \"run-${TIMESTAMP}\"/" "${TARGET_FILE}"
rm "${TARGET_FILE}.bak"

# Show the diff
echo ""
echo "==> Git diff (annotation bump):"
git diff "${TARGET_FILE}"

# Stage and commit
git add "${TARGET_FILE}"
git commit -m "demo: bump vllm model-version to run-${TIMESTAMP}"

echo ""
echo "==> Committed. Now push to trigger ArgoCD sync:"
echo "    git push origin HEAD"
echo ""
echo "==> Then watch ArgoCD apply the change (choose one):"
echo "    argocd app sync vllm                           # force immediate sync"
echo "    kubectl get app vllm -n argocd -w             # watch sync status"
echo ""
echo "==> After sync, verify the rolling restart:"
echo "    kubectl rollout status deploy/vllm-smollm2 -n llm-serving --timeout=300s"
echo "    kubectl describe deploy vllm-smollm2 -n llm-serving | grep model-version"
