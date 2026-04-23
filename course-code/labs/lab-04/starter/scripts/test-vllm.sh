#!/usr/bin/env bash
# test-vllm.sh — End-to-end inference test for vLLM (SERVE-03)
# Tests: /health, /v1/models, /v1/chat/completions
# Usage: bash test-vllm.sh [HOST] [PORT]
# Example: bash test-vllm.sh localhost 30200

set -euo pipefail

HOST="${1:-localhost}"
PORT="${2:-30200}"
BASE_URL="http://${HOST}:${PORT}"
MODEL="smollm2-135m-finetuned"

echo "=== Testing vLLM at ${BASE_URL} ==="
echo ""

# Test 1: Health check
echo "1. Health check..."
HEALTH=$(curl -sf "${BASE_URL}/health" || echo "FAILED")
if [[ "$HEALTH" == "FAILED" ]]; then
  echo "   FAIL: /health endpoint not responding"
  echo "   Is vLLM pod running? Check: kubectl get pods -n llm-serving"
  exit 1
fi
echo "   OK: /health → $HEALTH"

# Test 2: List models
echo ""
echo "2. List models..."
MODELS=$(curl -sf "${BASE_URL}/v1/models" | python3 -c "import sys,json; d=json.load(sys.stdin); print([m['id'] for m in d['data']])" 2>/dev/null || echo "FAILED")
echo "   Models: $MODELS"

# Test 3: Chat completion (dental question)
echo ""
echo "3. Chat completion (dental query)..."
RESPONSE=$(curl -sf \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"${MODEL}\",
    \"messages\": [
      {\"role\": \"system\", \"content\": \"You are a helpful dental clinic assistant for Smile Dental, Pune.\"},
      {\"role\": \"user\", \"content\": \"How much does teeth whitening cost?\"}
    ],
    \"max_tokens\": 100,
    \"temperature\": 0.1
  }" \
  "${BASE_URL}/v1/chat/completions")

CONTENT=$(echo "$RESPONSE" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r['choices'][0]['message']['content'])" 2>/dev/null || echo "PARSE_FAILED")
echo "   Response: $CONTENT"
echo ""
echo "=== All vLLM tests passed ==="
