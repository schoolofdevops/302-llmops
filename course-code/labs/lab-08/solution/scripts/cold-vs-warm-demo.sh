#!/usr/bin/env bash
# Cold-vs-warm SandboxWarmPool timing demo (D-06 + RESEARCH.md Focus 3).
# Requires: WarmPool already replicas=2 and a real GROQ_API_KEY (or GOOGLE_API_KEY)
#           in the llm-api-keys Secret.
set -euo pipefail
NS="${NS_AGENT:-llm-agent}"

# Use gdate (GNU) on macOS for nanosecond precision; fall back to date (Linux/GNU).
_now_ns() {
  if command -v gdate >/dev/null 2>&1; then
    gdate +%s%N
  elif date +%s%N 2>&1 | grep -qv N; then
    date +%s%N
  else
    # macOS BSD date: seconds only (millisecond precision not available).
    echo "$(($(date +%s) * 1000000000))"
  fi
}

# Helper: ask the agent and print elapsed wall time.
ask_agent() {
  local label="$1"; local port="$2"
  local body='{"model":"hermes","messages":[{"role":"user","content":"Just respond with the word OK."}],"max_tokens":5,"stream":false}'
  local start; start=$(_now_ns)
  local code
  code=$(curl -s -o /tmp/cw.json -w "%{http_code}" -X POST "http://localhost:${port}/v1/chat/completions" \
        -H "Authorization: Bearer smile-dental-course-key" \
        -H "Content-Type: application/json" -d "${body}" --max-time 180 || echo "000")
  local end; end=$(_now_ns)
  local elapsed; elapsed=$(awk "BEGIN{printf \"%.2f\", (${end}-${start})/1000000000}")
  echo "  ${label}: HTTP ${code} in ${elapsed}s"
}

start_pf() {
  local target="$1"; local port="$2"
  kubectl -n "${NS}" port-forward "${target}" "${port}:8642" >/dev/null 2>&1 &
  echo $!
  sleep 5
}
stop_pf() { kill "$1" 2>/dev/null || true; }

# 1. Capture warm timing first (pool=2)
echo "[1/4] Warm test — WarmPool replicas=2"
WARM_POD=$(kubectl get pod -n "${NS}" -l app=hermes-agent -o jsonpath='{.items[0].metadata.name}')
PF=$(start_pf "pod/${WARM_POD}" 18642)
ask_agent "Warm" 18642
stop_pf "${PF}"

# 2. Drain the pool
echo "[2/4] Scaling WarmPool to 0 (cold setup)..."
kubectl patch sandboxwarmpool hermes-agent-warmpool -n "${NS}" --type merge -p '{"spec":{"replicas":0}}'
# Wait for pods to drain — readyReplicas may be absent (not 0) when fully drained.
kubectl wait pod -n "${NS}" -l agents.x-k8s.io/warm-pool-sandbox \
  --for=delete --timeout=180s 2>/dev/null || true

# 3. Scale back to 2 — now pods schedule fresh = cold path
echo "[3/4] Scaling WarmPool back to 2 (cold timing)..."
kubectl patch sandboxwarmpool hermes-agent-warmpool -n "${NS}" --type merge -p '{"spec":{"replicas":2}}'
COLD_START=$(_now_ns)
kubectl wait sandboxwarmpool/hermes-agent-warmpool -n "${NS}" \
  --for=jsonpath='{.status.readyReplicas}'=2 --timeout=300s
COLD_END=$(_now_ns)
COLD_ELAPSED=$(awk "BEGIN{printf \"%.2f\", (${COLD_END}-${COLD_START})/1000000000}")
echo "  Cold WarmPool refill (0 -> 2 ready): ${COLD_ELAPSED}s"

# 4. First request immediately after refill
COLD_POD=$(kubectl get pod -n "${NS}" -l app=hermes-agent -o jsonpath='{.items[0].metadata.name}')
PF=$(start_pf "pod/${COLD_POD}" 18643)
ask_agent "Cold" 18643
stop_pf "${PF}"

echo
echo "[4/4] Done. Compare the Warm vs Cold timings above."
echo "Expected: Warm ~= 1-3s (LLM API latency only); Cold ~= 30-90s (image cached + hermes startup)."
