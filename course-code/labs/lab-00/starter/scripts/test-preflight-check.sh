#!/usr/bin/env bash
# test-preflight-check.sh — Unit tests for preflight-check.sh
# Run with: bash scripts/test-preflight-check.sh
# These tests use mocking to validate behavior without requiring real tools

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFLIGHT="${SCRIPT_DIR}/preflight-check.sh"
PASS_COUNT=0
FAIL_COUNT=0

assert_contains() {
  local test_name="$1"
  local output="$2"
  local pattern="$3"
  if echo "$output" | grep -q "$pattern"; then
    echo "[TEST PASS] $test_name"
    ((PASS_COUNT++)) || true
  else
    echo "[TEST FAIL] $test_name"
    echo "  Expected pattern: $pattern"
    echo "  Actual output:"
    echo "$output" | head -20 | sed 's/^/    /'
    ((FAIL_COUNT++)) || true
  fi
}

assert_exit_code() {
  local test_name="$1"
  local actual="$2"
  local expected="$3"
  if [ "$actual" -eq "$expected" ]; then
    echo "[TEST PASS] $test_name"
    ((PASS_COUNT++)) || true
  else
    echo "[TEST FAIL] $test_name — expected exit $expected, got $actual"
    ((FAIL_COUNT++)) || true
  fi
}

echo "============================="
echo " Preflight Script Tests"
echo "============================="
echo ""

# Verify preflight script exists (should fail before GREEN phase)
if [ ! -f "$PREFLIGHT" ]; then
  echo "[TEST FAIL] preflight-check.sh does not exist yet (expected in RED phase)"
  ((FAIL_COUNT++)) || true
  echo ""
  echo "============================="
  echo "==> Test summary: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
  echo "============================="
  exit 1
fi

# --- Test 1: Script has correct shebang ---
SHEBANG=$(head -1 "$PREFLIGHT")
if echo "$SHEBANG" | grep -q "#!/usr/bin/env bash"; then
  echo "[TEST PASS] Shebang is correct"
  ((PASS_COUNT++)) || true
else
  echo "[TEST FAIL] Shebang expected '#!/usr/bin/env bash', got '$SHEBANG'"
  ((FAIL_COUNT++)) || true
fi

# --- Test 2: Script has strict mode ---
if grep -q "set -euo pipefail" "$PREFLIGHT"; then
  echo "[TEST PASS] Strict mode (set -euo pipefail) present"
  ((PASS_COUNT++)) || true
else
  echo "[TEST FAIL] Missing: set -euo pipefail"
  ((FAIL_COUNT++)) || true
fi

# --- Test 3: Script uses docker system info for memory ---
if grep -q "docker system info --format" "$PREFLIGHT"; then
  echo "[TEST PASS] Uses docker system info --format for memory check"
  ((PASS_COUNT++)) || true
else
  echo "[TEST FAIL] Missing docker system info --format for memory detection"
  ((FAIL_COUNT++)) || true
fi

# --- Test 4: Script checks for llmops-kind stale cluster ---
if grep -q "llmops-kind" "$PREFLIGHT"; then
  echo "[TEST PASS] Checks for stale llmops-kind cluster"
  ((PASS_COUNT++)) || true
else
  echo "[TEST FAIL] Missing stale cluster check for llmops-kind"
  ((FAIL_COUNT++)) || true
fi

# --- Test 5: Script has Preflight summary line ---
if grep -q "Preflight summary" "$PREFLIGHT"; then
  echo "[TEST PASS] Summary line present"
  ((PASS_COUNT++)) || true
else
  echo "[TEST FAIL] Missing: Preflight summary line"
  ((FAIL_COUNT++)) || true
fi

# --- Test 6: Script runs on this machine (Docker must be running) ---
echo ""
echo "--- Functional tests (require Docker running) ---"
if docker info >/dev/null 2>&1; then
  OUTPUT=$(bash "$PREFLIGHT" 2>&1) || EXIT_CODE=$?
  EXIT_CODE=${EXIT_CODE:-0}

  assert_contains "Docker running check shows [PASS]" "$OUTPUT" "\[PASS\] Docker is running"
  assert_contains "Summary line printed" "$OUTPUT" "Preflight summary:"
  assert_contains "Summary has passed count" "$OUTPUT" "passed"
  assert_exit_code "Script exits 0 when Docker running and tools present" "$EXIT_CODE" 0
else
  echo "[SKIP] Docker not running — skipping functional tests"
fi

# --- Test 7: Memory boundary check (using grep on script logic) ---
# Validate script has correct GB thresholds
if grep -q "ge 12" "$PREFLIGHT" && grep -q "ge 8" "$PREFLIGHT"; then
  echo "[TEST PASS] Memory thresholds 8GB and 12GB present in script"
  ((PASS_COUNT++)) || true
else
  echo "[TEST FAIL] Missing memory threshold checks (8GB, 12GB)"
  ((FAIL_COUNT++)) || true
fi

# --- Test 8: Port checks present ---
for port in 80 8000 30000 32000; do
  if grep -q "$port" "$PREFLIGHT"; then
    echo "[TEST PASS] Port $port check present"
    ((PASS_COUNT++)) || true
  else
    echo "[TEST FAIL] Missing port $port check"
    ((FAIL_COUNT++)) || true
  fi
done

echo ""
echo "============================="
echo "==> Test summary: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
echo "============================="

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
