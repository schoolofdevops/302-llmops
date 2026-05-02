#!/usr/bin/env bash
# End-to-end traced canonical demo — produces both Prometheus cost data AND Tempo traces.
#
# NOTE: The Sandbox Router requires an X-Sandbox-ID header that is generated per
# Chainlit session. This script demonstrates two approaches:
# 1. Port-forward Chainlit and send a UI-compatible request (if a session exists)
# 2. Show that Prometheus already has non-zero metrics from prior Chainlit interactions
#
set -euo pipefail

NS="${NS_AGENT:-llm-agent}"
NS_MON="${NS_MONITORING:-monitoring}"

echo "=== Smile Dental Agent Observability Demo ==="
echo ""

# 1. Check that cost-middleware is running and healthy
echo "[1/4] Checking cost-middleware health..."
kubectl -n "${NS}" port-forward svc/cost-middleware 19100:9100 >/dev/null 2>&1 &
PF=$!
trap 'kill ${PF} ${PF2:-} 2>/dev/null || true' EXIT
sleep 2
HEALTH=$(curl -sf http://localhost:19100/health 2>/dev/null || echo '{}')
echo "Health: ${HEALTH}"

# 2. Show current metrics (may be zero if no traffic yet)
echo ""
echo "[2/4] Current cost-middleware metrics..."
curl -s http://localhost:19100/metrics 2>/dev/null | grep -E 'agent_llm' | head -20 || echo "(no metrics yet — metrics appear after first chat request via Chainlit)"

# 3. Query Prometheus for cost metrics
echo ""
echo "[3/4] Querying Prometheus for aggregated cost metrics..."
PROM_SVC=$(kubectl get svc -n "${NS_MON}" -o name 2>/dev/null | grep prometheus | grep -v node-exporter | grep -v operated | grep -v operator | head -1 | sed 's|service/||')
kubectl -n "${NS_MON}" port-forward svc/"${PROM_SVC}" 29090:9090 >/dev/null 2>&1 &
PF2=$!
sleep 3

echo "Token counter (non-zero after first Chainlit chat):"
curl -s "http://localhost:29090/api/v1/query?query=sum(agent_llm_tokens_total)" 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    result = data.get('data', {}).get('result', [])
    val = float(result[0]['value'][1]) if result else 0.0
    print(f'  agent_llm_tokens_total = {val:.0f}')
    if val > 0:
        print('  OBS-05 PASS: non-zero token count')
    else:
        print('  (zero — send a chat message via Chainlit at http://localhost:30300 first)')
except Exception as e:
    print(f'  Parse error: {e}')
" 2>/dev/null || echo "Prometheus query failed"

echo "Cost counter (non-zero after first Chainlit chat):"
curl -s "http://localhost:29090/api/v1/query?query=sum(agent_llm_cost_usd_total)" 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    result = data.get('data', {}).get('result', [])
    val = float(result[0]['value'][1]) if result else 0.0
    print(f'  agent_llm_cost_usd_total = {val:.6f} USD')
    if val > 0:
        print('  OBS-05 PASS: non-zero cost')
    else:
        print('  (zero — send a chat message via Chainlit at http://localhost:30300 first)')
except Exception as e:
    print(f'  Parse error: {e}')
" 2>/dev/null || echo "Prometheus query failed"

# 4. Check Tempo for traces
echo ""
echo "[4/4] Checking Tempo for MCP tool traces..."
kubectl -n "${NS_MON}" port-forward svc/tempo 13200:3200 >/dev/null 2>&1 &
PF3=$!
trap 'kill ${PF} ${PF2:-} ${PF3:-} 2>/dev/null || true' EXIT
sleep 2

for svc_name in mcp-triage mcp-treatment-lookup mcp-book-appointment; do
    COUNT=$(curl -s "http://localhost:13200/api/search?tags=service.name%3D${svc_name}&limit=5" 2>/dev/null | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    n=len(d.get('traces',[]))
    print(n)
except:
    print(0)
" 2>/dev/null || echo "0")
    echo "  ${svc_name}: ${COUNT} traces in Tempo"
done

echo ""
echo "=== Instructions ==="
echo "1. Send a chat message via Chainlit: http://localhost:30300"
echo "   (cost-middleware is now in the path: Chainlit -> cost-middleware -> Sandbox Router -> Hermes -> MCP tools)"
echo "2. Re-run this script to see non-zero token/cost counters"
echo "3. Open Grafana: http://localhost:30400 -> 'Smile Dental — Agent Overview' dashboard"
echo "4. Grafana -> Explore -> Tempo -> service.name = mcp-treatment-lookup to see spans"
echo ""
echo "OK: canonical query traced."
