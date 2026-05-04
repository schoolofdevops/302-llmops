#!/usr/bin/env bash
# audit-trail-queries.sh — GUARD-03 governance: copy-paste evidence queries.
#
# Each section below is a self-contained query block. Run individual sections to
# produce evidence for an audit — or run the whole script to get a snapshot.
#
# Per D-18 / RESEARCH.md: NO new tooling. Every command here uses what Labs 11
# and 12 already shipped (argocd CLI, git log, kubectl, Tempo HTTP API).
set -euo pipefail

NS_ARGOCD="${NS_ARGOCD:-argocd}"
NS_MONITORING="${NS_MONITORING:-monitoring}"
APP="${APP:-vllm}"

echo "============================================================"
echo "  GUARD-03 — Governance audit snapshot"
echo "  Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "============================================================"

# ----------------------------------------------------------------------------
# Pillar 1: Model versioning — git history of model-version commits
# ----------------------------------------------------------------------------
echo
echo "[Pillar 1] Model versioning — Lab 12 image-tag commit history"
echo "------------------------------------------------------------"
echo "Last 10 model-version bumps in the gitops-repo:"
git log --oneline --grep="ci(lab-12): bump model-version" -n 10 \
  course-code/labs/lab-11/solution/gitops-repo/bases/vllm/30-deploy-vllm.yaml \
  2>/dev/null || echo "  (no model-version commits yet — run Lab 12 PASS path first)"

echo
echo "To inspect a specific commit:    git show <SHA>"
echo "To see the model-version tag:    grep gitops/model-version <file-after-checkout>"

# ----------------------------------------------------------------------------
# Pillar 2: GitOps deploy-time provenance — ArgoCD Application history
# ----------------------------------------------------------------------------
echo
echo "[Pillar 2] GitOps provenance — ArgoCD Application history"
echo "------------------------------------------------------------"
if command -v argocd >/dev/null 2>&1; then
  echo "argocd app history ${APP}:"
  argocd app history "${APP}" --grpc-web 2>/dev/null \
    || echo "  (argocd CLI present but not logged in; run scripts/argocd-login.sh)"
else
  echo "(argocd CLI not installed — using kubectl fallback)"
  kubectl get application "${APP}" -n "${NS_ARGOCD}" \
    -o jsonpath='{range .status.history[*]}revision={.revision}{"\t"}deployedAt={.deployedAt}{"\n"}{end}' \
    2>/dev/null \
    || echo "  (no Application history — run Lab 11 + Lab 12 PASS path first)"
fi

# ----------------------------------------------------------------------------
# Pillar 3: OTEL runtime compliance evidence
# ----------------------------------------------------------------------------
echo
echo "[Pillar 3] OTEL compliance evidence — Tempo trace selectors"
echo "------------------------------------------------------------"
echo "TraceQL selector for insurance_check spans (last 1 hour):"
echo "  { resource.service.name = \"mcp-insurance-check\" }"
echo
echo "TraceQL selector for guardrail-blocked queries:"
echo "  { resource.service.name =~ \"mcp-.*\" && status = error }"
echo
echo "Open Grafana Explore (Tempo datasource) to run these:"
NODEPORT_GRAFANA="${NODEPORT_GRAFANA:-30500}"
echo "  http://localhost:${NODEPORT_GRAFANA}/explore?left=%7B%22datasource%22:%22Tempo%22%7D"
echo
echo "Or query Tempo directly via kubectl port-forward (if you prefer scripted):"
echo "  kubectl port-forward -n ${NS_MONITORING} svc/tempo 3200:3200 &"
echo "  curl -s 'http://localhost:3200/api/search?q=%7Bresource.service.name%3D%22mcp-insurance-check%22%7D'"

echo
echo "============================================================"
echo "  Snapshot complete. Save this output to your audit log."
echo "============================================================"
