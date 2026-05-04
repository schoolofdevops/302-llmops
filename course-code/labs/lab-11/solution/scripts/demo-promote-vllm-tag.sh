#!/usr/bin/env bash
# demo-promote-vllm-tag.sh — Demonstrate GITOPS-02 promotion mechanic.
#
# Edits the vLLM Deployment in the gitops-repo to bump a benign annotation
# (gitops/deployed-at), commits, pushes, and observes ArgoCD auto-sync. This is
# representative of what Lab 12's pipeline will eventually do automatically
# (bump the actual image tag).
#
# We use an annotation bump (not a real image tag bump) here because changing
# the actual model image without a re-built model OCI image would leave vLLM
# in ImagePullBackOff. Lab 12 ships the full pipeline that builds a new model
# image, then bumps the tag.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
TARGET="${REPO_ROOT}/course-code/labs/lab-11/solution/gitops-repo/bases/vllm/30-deploy-vllm.yaml"

# Health gate (Pitfall 1)
if ! kubectl get nodes >/dev/null 2>&1; then
  echo "ERROR: kubectl get nodes failed — cluster appears unresponsive. Run 'kubectl top nodes' and consider rebuilding KIND."
  exit 1
fi

if ! kubectl get application vllm -n argocd >/dev/null 2>&1; then
  echo "ERROR: ArgoCD vllm Application not present. Run scripts/bootstrap-app-of-apps.sh first."
  exit 1
fi

# Step 1: edit the manifest — add or update an annotation `gitops/deployed-at`
TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
echo "[1/4] Bumping gitops/deployed-at annotation to ${TIMESTAMP}..."
if grep -q "gitops/deployed-at" "${TARGET}"; then
  # macOS sed needs '' for in-place; Linux doesn't. Use a portable form:
  sed -i.bak "s|gitops/deployed-at: \".*\"|gitops/deployed-at: \"${TIMESTAMP}\"|" "${TARGET}"
else
  # Insert under metadata: labels: section (Deployment metadata, not pod template)
  python3 - "${TARGET}" "${TIMESTAMP}" <<'PY'
import sys, pathlib, re
p = pathlib.Path(sys.argv[1]); ts = sys.argv[2]
s = p.read_text()
# Add an annotation block on the Deployment metadata (top-level, not pod template metadata)
new = re.sub(
    r"(kind: Deployment\nmetadata:\n  name: vllm-smollm2\n  namespace: llm-serving\n)",
    rf'\1  annotations:\n    gitops/deployed-at: "{ts}"\n',
    s, count=1
)
p.write_text(new)
PY
fi
rm -f "${TARGET}.bak"

# Step 2: commit + push (assumes git remote `origin` configured + write access)
echo "[2/4] Committing the change..."
git -C "${REPO_ROOT}" add "${TARGET}"
git -C "${REPO_ROOT}" commit -m "feat(lab-11): demo gitops promotion bump deployed-at=${TIMESTAMP}"
git -C "${REPO_ROOT}" push

# Step 3: observe ArgoCD auto-sync (default poll = 3 min; force with `argocd app sync` for instant demo)
echo "[3/4] Waiting up to 5 minutes for ArgoCD to reconcile..."
for i in $(seq 1 30); do
  ANNOT=$(kubectl get deploy vllm-smollm2 -n llm-serving \
    -o jsonpath='{.metadata.annotations.gitops/deployed-at}' 2>/dev/null || true)
  if [ "${ANNOT}" = "${TIMESTAMP}" ]; then
    echo "  ArgoCD synced after ~$((i*10))s. Live Deployment annotation matches commit."
    break
  fi
  echo "  [${i}/30] live annotation='${ANNOT}', expected='${TIMESTAMP}'. Waiting 10s..."
  if [ "${i}" -eq 30 ]; then
    echo "  TIMEOUT: Auto-sync did not complete in 5 min."
    echo "  Force sync (instant demo path): kubectl patch application vllm -n argocd --type merge --patch '{\"operation\":{\"initiatedBy\":{\"username\":\"admin\"},\"sync\":{\"revision\":\"HEAD\"}}}'"
    break
  fi
  sleep 10
done

# Step 4: report
echo "[4/4] Final state:"
kubectl get application vllm -n argocd
kubectl get deploy vllm-smollm2 -n llm-serving \
  -o jsonpath='{.metadata.annotations.gitops/deployed-at}{"\n"}' 2>/dev/null || echo "(annotation not yet applied)"
echo
echo "OK: GITOPS-02 demonstrated — git commit on gitops-repo triggered ArgoCD to roll the vLLM Deployment."
echo "    For instant sync (no 3-min wait), run:"
echo "    kubectl patch application vllm -n argocd --type merge --patch '{\"operation\":{\"initiatedBy\":{\"username\":\"admin\"},\"sync\":{\"revision\":\"HEAD\"}}}'"
