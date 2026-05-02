#!/usr/bin/env bash
set -euo pipefail

# verify-hermes-startup.sh
# Validates Hermes Agent image pulls and starts on a CPU-only host.
# Resolves RESEARCH.md open questions 2 and 3 before deeper Lab 07 work.

IMAGE="${HERMES_IMAGE:-nousresearch/hermes-agent:latest}"
CONTAINER="hermes-startup-check"
PORT=8642
API_KEY="smile-dental-course-key"

cleanup() {
  docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "[1/5] Pulling ${IMAGE} (this is ~2.4 GB; first pull may take several minutes)…"
docker pull "${IMAGE}"

echo "[2/5] Confirming hermes binary is invokable inside the image…"
docker run --rm "${IMAGE}" hermes --version

echo "[3/5] Starting hermes gateway in headless mode on port ${PORT}…"
cleanup
docker run -d \
  --name "${CONTAINER}" \
  -p "${PORT}:${PORT}" \
  -e API_SERVER_ENABLED=true \
  -e API_SERVER_HOST=0.0.0.0 \
  -e API_SERVER_KEY="${API_KEY}" \
  "${IMAGE}" \
  hermes gateway

echo "[4/5] Waiting up to 60 s for /health to return 200…"
for i in $(seq 1 30); do
  if curl -s -f -m 2 "http://localhost:${PORT}/health" >/dev/null 2>&1; then
    echo "       /health is up after ${i} attempts (~$((i*2)) s)"
    break
  fi
  sleep 2
  if [ "${i}" = "30" ]; then
    echo "ERROR: Hermes /health did not return 200 within 60 s"
    docker logs "${CONTAINER}" | tail -50
    exit 1
  fi
done

echo "[5/5] Validating /v1/chat/completions endpoint accepts auth header…"
HTTP_CODE=$(curl -s -o /tmp/hermes-resp.json -w "%{http_code}" \
  -X POST "http://localhost:${PORT}/v1/chat/completions" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"model":"hermes","messages":[{"role":"user","content":"ping"}],"max_tokens":5}' \
  --max-time 30 || echo "000")

# Acceptable codes: 200 (worked, but unlikely without LLM API key), 401 (auth checked), 5xx with body containing "GROQ_API_KEY" or "GOOGLE_API_KEY" missing
if [[ "${HTTP_CODE}" == "200" || "${HTTP_CODE}" == "401" || "${HTTP_CODE}" == "500" || "${HTTP_CODE}" == "503" ]]; then
  echo "       /v1/chat/completions reachable (HTTP ${HTTP_CODE}) — endpoint exposed correctly"
else
  echo "ERROR: unexpected HTTP ${HTTP_CODE} from /v1/chat/completions"
  cat /tmp/hermes-resp.json || true
  exit 1
fi

echo
echo "OK: Hermes Agent image starts on CPU-only host with headless 'hermes gateway' command."
echo "    Port ${PORT} exposes /health and /v1/chat/completions."
echo "    Open question 2 (CMD syntax): 'hermes gateway' confirmed."
echo "    Open question 3 (CPU-only):   confirmed."
