#!/usr/bin/env bash
# Builds the 3 MCP tool images from Lab 07 sources and pushes to kind-registry:5001.
set -euo pipefail

REGISTRY="${KIND_REGISTRY:-localhost:5001}"
LAB7_DIR="$(cd "$(dirname "$0")/../../../lab-07/solution" && pwd)"
TAG="${MCP_IMAGE_TAG:-v1.0.0}"

cd "${LAB7_DIR}"
for tool in triage treatment_lookup book_appointment; do
  IMG="${REGISTRY}/mcp-${tool}:${TAG}"
  echo "Building ${IMG} from tools/${tool}/Dockerfile ..."
  docker build -t "${IMG}" -f "tools/${tool}/Dockerfile" .
  docker push "${IMG}"
done

echo
echo "OK: 3 MCP tool images built + pushed:"
for tool in triage treatment_lookup book_appointment; do
  echo "  ${REGISTRY}/mcp-${tool}:${TAG}"
done
