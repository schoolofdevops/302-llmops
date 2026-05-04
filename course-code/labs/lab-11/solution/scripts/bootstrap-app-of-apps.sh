#!/usr/bin/env bash
# bootstrap-app-of-apps.sh — Apply the root Application that wires every child Application.
#
# DEPENDENCY NOTE (inter-plan):
#   This script depends on 91-app-of-apps.yaml, which is created by plan 04-10 (Wave 3).
#   DO NOT run this script until plan 04-10 has executed and placed
#   course-code/labs/lab-11/solution/k8s/91-app-of-apps.yaml in the repo.
#   Running it before 04-10 will fail with "no such file: 91-app-of-apps.yaml".
#
# After running, ArgoCD takes over: it reads the gitops-repo/ tree and creates
# 5 child Applications under apps/, each of which syncs its bases/<name>/ folder
# into the cluster. This plan only verifies ArgoCD control-plane install (plan 04-04).
set -euo pipefail

NS_ARGOCD="${NS_ARGOCD:-argocd}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_OF_APPS_MANIFEST="${SCRIPT_DIR}/../k8s/91-app-of-apps.yaml"

# ---- Pre-flight: ensure 91-app-of-apps.yaml exists (created by plan 04-10) ----
if [ ! -f "${APP_OF_APPS_MANIFEST}" ]; then
  echo "ERROR: ${APP_OF_APPS_MANIFEST} not found."
  echo "Run plan 04-10 first — it creates the gitops-repo layout and this manifest."
  exit 1
fi

kubectl apply -f "${APP_OF_APPS_MANIFEST}"

echo "Root Application applied. Waiting up to 5 minutes for child Applications to appear…"
COUNT=0
for i in $(seq 1 30); do
  COUNT=$(kubectl get applications -n "${NS_ARGOCD}" --no-headers 2>/dev/null | wc -l | tr -d ' ')
  if [ "${COUNT}" -ge 6 ]; then  # root Application + 5 child Applications
    echo "Found ${COUNT} Applications:"
    kubectl get applications -n "${NS_ARGOCD}"
    exit 0
  fi
  echo "  [${i}/30] Currently ${COUNT} Applications. Waiting 10s…"
  sleep 10
done

echo "ERROR: only ${COUNT} Applications appeared after 5 minutes."
echo "Inspect: kubectl describe application smile-dental-apps -n ${NS_ARGOCD}"
exit 1
