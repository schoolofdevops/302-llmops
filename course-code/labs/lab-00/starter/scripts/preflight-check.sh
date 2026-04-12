#!/usr/bin/env bash
# preflight-check.sh — LLMOps Course Environment Validation
# Run this before Lab 00: bash scripts/preflight-check.sh
set -euo pipefail

PASS=0; WARN=0; FAIL=0

pass() { echo "[PASS] $1"; ((PASS++)) || true; }
warn() { echo "[WARN] $1"; ((WARN++)) || true; }
fail() { echo "[FAIL] $1"; ((FAIL++)) || true; }

echo "============================================="
echo " LLMOps Course — Preflight Check"
echo "============================================="

# OS detection
OS=$(uname -s 2>/dev/null || echo "Windows")
echo ""
echo "==> System: $OS"

# --- Docker Desktop ---
echo ""
echo "==> Checking Docker..."
if ! docker info >/dev/null 2>&1; then
  fail "Docker is not running. Start Docker Desktop first, then re-run this script."
else
  pass "Docker is running"

  # Memory check
  MEM_BYTES=$(docker system info --format '{{.MemTotal}}' 2>/dev/null || echo 0)
  MEM_GB=$(( MEM_BYTES / 1073741824 ))
  if [ "$MEM_GB" -ge 12 ]; then
    pass "Docker memory: ${MEM_GB}GB (recommended >= 12GB)"
  elif [ "$MEM_GB" -ge 8 ]; then
    warn "Docker memory: ${MEM_GB}GB (minimum met; recommend 12GB for Labs 04-09 — go to Docker Desktop > Resources > Memory)"
  else
    fail "Docker memory: ${MEM_GB}GB (below 8GB minimum — increase in Docker Desktop > Settings > Resources > Memory)"
  fi

  # Disk space check (Docker's available storage)
  DF_GB=$(df -BG "$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || echo /)" 2>/dev/null | awk 'NR==2 {gsub(/G/,""); print $4}' || echo 0)
  if [ "${DF_GB:-0}" -ge 20 ] 2>/dev/null; then
    pass "Disk space: ${DF_GB}GB available on Docker root"
  else
    warn "Disk space: Could not confirm >= 20GB available. Ensure your disk has at least 20GB free."
  fi
fi

# --- Required Tools ---
echo ""
echo "==> Checking required tools..."
for tool in kind kubectl helm docker; do
  if command -v "$tool" >/dev/null 2>&1; then
    pass "$tool found: $(command -v "$tool")"
  else
    fail "$tool not found — see prerequisites page at https://llmops.schoolofdevops.com/docs/setup/prerequisites"
  fi
done

# --- Port Availability ---
echo ""
echo "==> Checking port availability..."
for port in 80 8000 30000 32000; do
  if lsof -i ":${port}" >/dev/null 2>&1; then
    warn "Port ${port} is in use — may conflict with course lab services. Stop the conflicting service before starting Lab 00."
  else
    pass "Port ${port} is available"
  fi
done

# --- Stale KIND Cluster Check ---
echo ""
echo "==> Checking for stale KIND clusters..."
if command -v kind >/dev/null 2>&1; then
  EXISTING=$(kind get clusters 2>/dev/null || true)
  if echo "$EXISTING" | grep -q "llmops-kind"; then
    warn "Stale cluster found: llmops-kind already exists. If you are starting fresh, delete it first: kind delete cluster --name llmops-kind"
  else
    pass "No stale llmops-kind cluster found"
  fi
fi

# --- Summary ---
echo ""
echo "============================================="
echo "==> Preflight summary: ${PASS} passed, ${WARN} warnings, ${FAIL} failed"
echo "============================================="

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "Fix the [FAIL] items above before proceeding to Lab 00."
  exit 1
fi

if [ "$WARN" -gt 0 ]; then
  echo ""
  echo "Review the [WARN] items above. Warnings will not block Lab 00 but may cause issues in later labs."
fi

echo ""
echo "Your environment is ready. Proceed to Lab 00: Cluster Setup."
