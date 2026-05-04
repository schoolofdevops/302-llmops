#!/usr/bin/env bash
# build-and-load-images.sh — Build the insurance_check MCP tool image and
# kind-load it (Pitfall 4 — KIND nodes can't pull from localhost:5001 without this).
#
# Lab 13 ships ONE new image (insurance_check). Wiring guardrails into the 3
# existing tools (triage/treatment_lookup/book_appointment) is documented as an
# extension exercise; this script focuses on the capstone artifact.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
# Verify REPO_ROOT looks correct (should contain course-code directory)
if [ ! -d "${REPO_ROOT}/course-code" ]; then
  # Fallback: try resolving from the current working directory
  REPO_ROOT="$(pwd)"
  while [ "${REPO_ROOT}" != "/" ] && [ ! -d "${REPO_ROOT}/course-code" ]; do
    REPO_ROOT="$(dirname "${REPO_ROOT}")"
  done
fi
LAB13_SOL="${REPO_ROOT}/course-code/labs/lab-13/solution"

IMAGE="kind-registry:5001/smile-dental-insurance-check:v1.0.0"
KIND_CLUSTER="${KIND_CLUSTER:-llmops-kind}"

echo "[1/3] Building image ${IMAGE}..."
docker build -t "${IMAGE}" \
  -f "${LAB13_SOL}/tools/insurance_check/Dockerfile" \
  "${LAB13_SOL}"

echo "[2/3] Loading image into KIND cluster ${KIND_CLUSTER} (Pitfall 4)..."
kind load docker-image "${IMAGE}" --name "${KIND_CLUSTER}"

echo "[3/3] Done. Image is now resolvable on KIND nodes."
docker images | grep smile-dental-insurance-check | head -1
