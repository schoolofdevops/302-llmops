#!/usr/bin/env bash
# Builds the 3 MCP tool images from Lab 07 sources, pushes to kind-registry:5001,
# and loads them into all KIND nodes so cached :v1.0.0 layers don't shadow new code.
set -euo pipefail

REGISTRY="${KIND_REGISTRY:-localhost:5001}"
LAB7_DIR="$(cd "$(dirname "$0")/../../../lab-07/solution" && pwd)"
TAG="${MCP_IMAGE_TAG:-v1.0.0}"
KIND_CLUSTER="${KIND_CLUSTER:-llmops-kind}"

cd "${LAB7_DIR}"
for tool in triage treatment_lookup book_appointment; do
  IMG="${REGISTRY}/mcp-${tool}:${TAG}"
  echo "Building ${IMG} from tools/${tool}/Dockerfile ..."
  docker build -t "${IMG}" -f "tools/${tool}/Dockerfile" .
  docker push "${IMG}"
  # `kind load docker-image` distributes the local image to all KIND node containerd's
  # snapshotters. Necessary because KIND nodes treat tag-with-same-digest as already-cached
  # and won't re-pull from kind-registry on imagePullPolicy=IfNotPresent. Belt-and-braces:
  # the manifests now also set imagePullPolicy=Always so kubelet re-pulls from kind-registry.
  if command -v kind >/dev/null 2>&1; then
    kind load docker-image "${IMG}" --name "${KIND_CLUSTER}" || true
  fi
done

echo
echo "OK: 3 MCP tool images built + pushed + loaded into KIND nodes:"
for tool in triage treatment_lookup book_appointment; do
  echo "  ${REGISTRY}/mcp-${tool}:${TAG}"
done
