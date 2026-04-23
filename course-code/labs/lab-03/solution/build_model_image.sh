#!/usr/bin/env bash
# build_model_image.sh — Build and push model OCI image to KIND local registry
#
# Prerequisites:
#   - merged-model/ directory exists in PROJECT_DIR/training/merged-model/
#   - KIND cluster is running with kind-registry:5001 available
#   - Source config.env before running (for MODEL_IMAGE_TAG)
#
# Usage:
#   source course-code/config.env
#   bash build_model_image.sh

set -euo pipefail

# Load config if not already sourced
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ENV="${SCRIPT_DIR}/../../../config.env"
if [[ -f "$CONFIG_ENV" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_ENV"
fi

# Defaults
MODEL_IMAGE_TAG="${MODEL_IMAGE_TAG:-v1.0.0}"
MERGED_MODEL_DIR="${MERGED_MODEL_DIR:-./llmops-project/training/merged-model}"
REGISTRY="kind-registry:5001"
IMAGE_NAME="smollm2-135m-finetuned"
FULL_TAG="${REGISTRY}/${IMAGE_NAME}:${MODEL_IMAGE_TAG}"

echo "Building model OCI image: ${FULL_TAG}"
echo "  Source model directory: ${MERGED_MODEL_DIR}"

# Validate merged model exists
if [[ ! -d "${MERGED_MODEL_DIR}" ]]; then
  echo "ERROR: Merged model directory not found: ${MERGED_MODEL_DIR}"
  echo "       Run merge_lora.py (Lab 02) first"
  exit 1
fi

# Copy Dockerfile and merged-model to a build context directory
BUILD_CONTEXT="$(mktemp -d)"
trap 'rm -rf "$BUILD_CONTEXT"' EXIT

cp "$(dirname "$0")/Dockerfile.model-asset" "${BUILD_CONTEXT}/Dockerfile.model-asset"
cp -r "${MERGED_MODEL_DIR}" "${BUILD_CONTEXT}/merged-model"

echo "Building Docker image..."
docker build \
  -f "${BUILD_CONTEXT}/Dockerfile.model-asset" \
  -t "${FULL_TAG}" \
  "${BUILD_CONTEXT}"

echo "Pushing to KIND registry..."
docker push "${FULL_TAG}"

echo ""
echo "Done! Model image pushed: ${FULL_TAG}"
echo ""
echo "Next step: Deploy vLLM in Lab 04 using this image as an ImageVolume."
