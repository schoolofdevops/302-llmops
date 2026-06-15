#!/usr/bin/env bash
# generate-traffic.sh — Send dental queries to vLLM to populate Grafana metrics
#
# Usage: bash generate-traffic.sh [HOST] [PORT] [ROUNDS]
# Example: bash generate-traffic.sh localhost 30200 3
#
# Sends 10 dental queries per round, pausing between each.
# Default: 3 rounds (~30 requests), takes ~5-10 minutes on CPU.

set -euo pipefail

HOST="${1:-localhost}"
PORT="${2:-30200}"
ROUNDS="${3:-3}"
BASE_URL="http://${HOST}:${PORT}"
MODEL="smollm2-135m-finetuned"
DELAY=5   # seconds between requests (vLLM is CPU-only — give it time)

QUERIES=(
  "How much does teeth whitening cost at Smile Dental?"
  "What is the cancellation policy?"
  "Do you accept EMI payments for dental treatments?"
  "How long does a root canal treatment take?"
  "Which doctor handles orthodontic work?"
  "What are the clinic opening hours?"
  "How much does a dental implant cost?"
  "Can I get teeth cleaning done in one visit?"
  "What should I do after a tooth extraction?"
  "Do you offer treatment for kids?"
)

echo "================================================="
echo " Smile Dental Traffic Generator"
echo "================================================="
echo " Target:  ${BASE_URL}"
echo " Model:   ${MODEL}"
echo " Rounds:  ${ROUNDS}"
echo " Queries: ${#QUERIES[@]} per round"
echo " Delay:   ${DELAY}s between requests"
echo ""
echo " Watch metrics at: http://localhost:30400 (Grafana)"
echo " Prometheus:       http://localhost:30500"
echo "================================================="
echo ""

# Verify vLLM is up before starting
echo "Checking vLLM health..."
if ! curl -sf "${BASE_URL}/health" > /dev/null 2>&1; then
  echo "ERROR: vLLM not reachable at ${BASE_URL}"
  echo "       Check: kubectl get pods -n llm-serving"
  exit 1
fi
echo "vLLM is up. Starting traffic generation..."
echo ""

TOTAL=0
ERRORS=0

for round in $(seq 1 "${ROUNDS}"); do
  echo "--- Round ${round}/${ROUNDS} ---"
  for query in "${QUERIES[@]}"; do
    TOTAL=$((TOTAL + 1))
    echo "[${TOTAL}] ${query}"

    RESPONSE=$(curl -sf \
      -H "Content-Type: application/json" \
      -d "{
        \"model\": \"${MODEL}\",
        \"messages\": [
          {\"role\": \"system\", \"content\": \"You are a helpful assistant for Smile Dental Clinic, Pune.\"},
          {\"role\": \"user\", \"content\": \"${query}\"}
        ],
        \"max_tokens\": 80,
        \"temperature\": 0.3
      }" \
      "${BASE_URL}/v1/chat/completions" 2>/dev/null || echo "ERROR")

    if [[ "${RESPONSE}" == "ERROR" ]]; then
      echo "     FAILED (curl error)"
      ERRORS=$((ERRORS + 1))
    else
      CONTENT=$(echo "${RESPONSE}" | python3 -c \
        "import sys,json; r=json.load(sys.stdin); print(r['choices'][0]['message']['content'][:80].replace('\n',' '))" \
        2>/dev/null || echo "(parse error)")
      echo "     → ${CONTENT}..."
    fi

    sleep "${DELAY}"
  done
  echo ""
done

echo "================================================="
echo " Done: ${TOTAL} requests, ${ERRORS} errors"
echo " Open Grafana to see metrics: http://localhost:30400"
echo "================================================="
