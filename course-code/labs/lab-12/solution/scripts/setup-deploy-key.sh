#!/usr/bin/env bash
# setup-deploy-key.sh — Create the git-deploy-key Secret in the argo namespace.
# Reads the student's SSH private key (default: ~/.ssh/id_ed25519 or ~/.ssh/id_rsa).
# The promote step of the WorkflowTemplate uses this key to push annotation bumps
# to the gitops repo, closing the E2E loop automatically (D-12).
#
# Usage: bash setup-deploy-key.sh [path/to/private/key]
set -euo pipefail

KEY_PATH="${1:-${HOME}/.ssh/id_ed25519}"

# ---- Fallback to id_rsa if id_ed25519 not found ----
if [ ! -f "${KEY_PATH}" ]; then
  KEY_PATH="${HOME}/.ssh/id_rsa"
fi

# ---- Guard: key must exist ----
if [ ! -f "${KEY_PATH}" ]; then
  echo "ERROR: no SSH key found at ${KEY_PATH}"
  echo "Generate one with: ssh-keygen -t ed25519 -C 'argo-promote'"
  echo "Then add the public key (${KEY_PATH}.pub) as a Deploy Key on your GitHub fork."
  exit 1
fi

echo "==> Using SSH key: ${KEY_PATH}"

# ---- Idempotency: remove old Secret if it exists ----
kubectl delete secret git-deploy-key -n argo --ignore-not-found=true

# ---- Create Secret ----
kubectl create secret generic git-deploy-key \
  --from-file=ssh-privatekey="${KEY_PATH}" \
  -n argo

echo ""
echo "Secret git-deploy-key created in argo namespace."
echo ""
echo "IMPORTANT: Add the public key (${KEY_PATH}.pub) as a Deploy Key to your GitHub repo:"
echo "  cat ${KEY_PATH}.pub   (copy this output)"
echo "  GitHub repo → Settings → Deploy keys → Add deploy key → Paste key → Allow write access"
echo ""
echo "After adding the deploy key, update the GITOPS_REPO_SSH_URL in:"
echo "  course-code/labs/lab-12/solution/k8s/101-workflowtemplate-pipeline.yaml"
echo "  Replace: git@github.com:<student-fork>/302-llmops.git"
echo "  With your actual fork SSH URL, then re-apply with kubectl apply -f."
