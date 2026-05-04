#!/usr/bin/env bash
# dry-run-eval.sh — Run run_eval.py on the FIRST 5 items of eval-set.jsonl.
# Closes RESEARCH.md Open Q4: validates DeepEval+Groq rate-limit math before
# committing to a full 12-item run inside Argo Workflows.
#
# Usage:
#   export LLM_BASE_URL=https://api.groq.com/openai/v1
#   export GROQ_API_KEY=gsk_...
#   bash dry-run-eval.sh
#
# Optional:
#   VLLM_URL=http://localhost:30200 VLLM_MODEL=smollm2-135m-finetuned bash dry-run-eval.sh
set -euo pipefail

DRYRUN_LIMIT=5
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOL="${SCRIPT_DIR}/.."

# Validate required env vars
: "${LLM_BASE_URL:?need LLM_BASE_URL=https://api.groq.com/openai/v1}"
: "${GROQ_API_KEY:?need GROQ_API_KEY (free-tier OK)}"
: "${LLM_MODEL:=llama-3.3-70b-versatile}"

# Make a 5-item slice of eval-set.jsonl into a temp file
TMP_EVAL=$(mktemp /tmp/dryrun-eval-XXXXXX.jsonl)
trap 'rm -f "${TMP_EVAL}"' EXIT
head -n "${DRYRUN_LIMIT}" "${SOL}/eval/eval-set.jsonl" > "${TMP_EVAL}"

echo "Dry-run with first ${DRYRUN_LIMIT} eval items (timing + rate-limit check)..."
echo "  LLM_BASE_URL : ${LLM_BASE_URL}"
echo "  LLM_MODEL    : ${LLM_MODEL}"
echo "  VLLM_URL     : ${VLLM_URL:-http://localhost:30200}"
echo "  Eval file    : ${TMP_EVAL}"
echo

cd "${SOL}"
PYTHONPATH=. python3 -m deepeval_local.run_eval \
  --eval-set "${TMP_EVAL}" \
  --out /tmp/dryrun-eval-pass.txt \
  --threshold 0.7 \
  --sleep 2.0 \
  --vllm-url "${VLLM_URL:-http://localhost:30200}" \
  --vllm-model "${VLLM_MODEL:-smollm2-135m-finetuned}"

EXIT=$?
echo
echo "Dry-run finished with exit ${EXIT}."
echo "Gate output: $(cat /tmp/dryrun-eval-pass.txt 2>/dev/null || echo 'file missing')"
echo
echo "Rate-limit check:"
echo "  ${DRYRUN_LIMIT} cases x 2 LLM calls each = $((DRYRUN_LIMIT * 2)) Groq API calls"
echo "  At 2.0s sleep between cases: ~$((DRYRUN_LIMIT * 2))s elapsed (plus LLM latency)"
echo "  Free tier: 30 RPM -- 10 calls in ~30s is safely under limit."
echo "  For full 12-case run: 24 calls @ 2.0s sleep = ~1-2 min total."
