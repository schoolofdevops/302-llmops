#!/usr/bin/env bash
# generate-traffic-full.sh — Send dental queries through the full RAG + vLLM pipeline
#
# Calls the RAG retriever and vLLM in sequence, exactly as Chainlit does internally.
# This populates all metrics except the two Chainlit-level counters
# (chat_requests_total, chat_latency_seconds) — use the browser UI for those.
#
# Usage: bash generate-traffic-full.sh [HOST] [RETRIEVER_PORT] [VLLM_PORT] [ROUNDS]
# Example: bash generate-traffic-full.sh localhost 30100 30200 3

set -euo pipefail

HOST="${1:-localhost}"
RETRIEVER_PORT="${2:-30100}"
VLLM_PORT="${3:-30200}"
ROUNDS="${4:-3}"

RETRIEVER_URL="http://${HOST}:${RETRIEVER_PORT}"
VLLM_URL="http://${HOST}:${VLLM_PORT}"
MODEL="smollm2-135m-finetuned"
TOP_K=3
DELAY=5   # seconds between requests

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
echo " Smile Dental Full Pipeline Traffic Generator"
echo "================================================="
echo " Retriever: ${RETRIEVER_URL}"
echo " vLLM:      ${VLLM_URL}"
echo " Rounds:    ${ROUNDS}  |  Queries: ${#QUERIES[@]} per round  |  Delay: ${DELAY}s"
echo ""
echo " Panels populated:"
echo "   ✓ TTFT, TPOT, E2E Latency, Token Throughput"
echo "   ✓ Active & Queued Requests (KEDA signal)"
echo "   ✓ KV Cache Utilization"
echo "   ✓ RAG Retriever Query Rate"
echo "   ~ Chat Rate + Chat Latency: use browser at http://${HOST}:30300"
echo ""
echo " Watch metrics at: http://localhost:30400 (Grafana)"
echo "================================================="
echo ""

# Verify services are up
echo "Checking RAG retriever..."
if ! curl -sf "${RETRIEVER_URL}/health" > /dev/null 2>&1; then
  echo "ERROR: RAG retriever not reachable at ${RETRIEVER_URL}"
  echo "       Check: kubectl get pods -n llm-app -l app=rag-retriever"
  exit 1
fi

echo "Checking vLLM..."
if ! curl -sf "${VLLM_URL}/health" > /dev/null 2>&1; then
  echo "ERROR: vLLM not reachable at ${VLLM_URL}"
  echo "       Check: kubectl get pods -n llm-serving"
  exit 1
fi
echo "Both services up. Starting traffic..."
echo ""

TOTAL=0
ERRORS=0

for round in $(seq 1 "${ROUNDS}"); do
  echo "--- Round ${round}/${ROUNDS} ---"
  for query in "${QUERIES[@]}"; do
    TOTAL=$((TOTAL + 1))
    echo "[${TOTAL}] ${query}"

    # Step 1: RAG retrieval
    HITS=$(curl -sf \
      -H "Content-Type: application/json" \
      -d "{\"query\": \"${query}\", \"k\": ${TOP_K}}" \
      "${RETRIEVER_URL}/search" 2>/dev/null || echo "ERROR")

    if [[ "${HITS}" == "ERROR" ]]; then
      echo "     RETRIEVER FAILED"
      ERRORS=$((ERRORS + 1))
      continue
    fi

    # Build context from hits
    CONTEXT=$(echo "${HITS}" | python3 -c "
import sys, json
hits = json.load(sys.stdin).get('hits', [])
parts = []
for h in hits:
    parts.append('Section: ' + h.get('section', '') + '\n' + h.get('text', ''))
print('\n\n'.join(parts[:3]))
" 2>/dev/null || echo "")

    NUM_HITS=$(echo "${HITS}" | python3 -c "
import sys, json; print(len(json.load(sys.stdin).get('hits', [])))
" 2>/dev/null || echo "0")

    # Step 2: vLLM with RAG context
    SYSTEM_PROMPT="You are a helpful assistant for Smile Dental Clinic, Pune. Answer questions about dental treatments, pricing (in INR), appointment policies, and general dental health. Be concise, accurate, and friendly.

Context:
${CONTEXT}"

    RESPONSE=$(curl -sf \
      -H "Content-Type: application/json" \
      -d "{
        \"model\": \"${MODEL}\",
        \"messages\": [
          {\"role\": \"system\", \"content\": $(echo "${SYSTEM_PROMPT}" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")},
          {\"role\": \"user\", \"content\": \"${query}\"}
        ],
        \"max_tokens\": 100,
        \"temperature\": 0.1
      }" \
      "${VLLM_URL}/v1/chat/completions" 2>/dev/null || echo "ERROR")

    if [[ "${RESPONSE}" == "ERROR" ]]; then
      echo "     vLLM FAILED"
      ERRORS=$((ERRORS + 1))
    else
      CONTENT=$(echo "${RESPONSE}" | python3 -c \
        "import sys,json; r=json.load(sys.stdin); print(r['choices'][0]['message']['content'][:80].replace('\n',' '))" \
        2>/dev/null || echo "(parse error)")
      echo "     [${NUM_HITS} docs] → ${CONTENT}..."
    fi

    sleep "${DELAY}"
  done
  echo ""
done

echo "================================================="
echo " Done: ${TOTAL} requests, ${ERRORS} errors"
echo " Open Grafana: http://localhost:30400"
echo "================================================="
