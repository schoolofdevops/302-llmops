#!/usr/bin/env bash
# wire-guardrails-into-existing-tools.sh — Patch the 3 Phase 3 MCP tool servers
# to register GuardrailMiddleware. Idempotent: skips if the import line is already present.
#
# After running this script, the 3 tool images need to be REBUILT for the change
# to take effect at runtime. The lab page documents this as an extension exercise.
# Lab 13 itself only ships the new insurance_check image (which is born guarded).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
# Verify REPO_ROOT looks correct (should contain course-code directory)
if [ ! -d "${REPO_ROOT}/course-code" ]; then
  # Fallback: try resolving from the current working directory
  REPO_ROOT="$(pwd)"
  while [ "${REPO_ROOT}" != "/" ] && [ ! -d "${REPO_ROOT}/course-code" ]; do
    REPO_ROOT="$(dirname "${REPO_ROOT}")"
  done
fi

PATCH_TARGETS=(
  "${REPO_ROOT}/course-code/labs/lab-07/solution/tools/triage/triage_server.py"
  "${REPO_ROOT}/course-code/labs/lab-07/solution/tools/treatment_lookup/treatment_lookup_server.py"
  "${REPO_ROOT}/course-code/labs/lab-07/solution/tools/book_appointment/book_appointment_server.py"
)

GUARD_IMPORT='from guardrails.middleware import GuardrailMiddleware'
GUARD_REGISTER='mcp.add_middleware(GuardrailMiddleware())'

for f in "${PATCH_TARGETS[@]}"; do
  if [ ! -f "$f" ]; then
    echo "[skip] $f does not exist"
    continue
  fi
  if python3 -c "
import pathlib
src = pathlib.Path('$f').read_text()
exit(0 if '${GUARD_IMPORT}' in src else 1)
" 2>/dev/null; then
    echo "[skip] ${f##*/} already wired"
    continue
  fi
  # Insert import block after the existing 'from tools.otel_setup import setup_tracing' line
  # AND insert the register call right after the FastMCP(...) closing paren / instantiation line.
  python3 - "$f" "${GUARD_IMPORT}" "${GUARD_REGISTER}" <<'PY'
import sys, re, pathlib
path, imp, reg = sys.argv[1], sys.argv[2], sys.argv[3]
p = pathlib.Path(path)
src = p.read_text()

# 1. Add the import after the 'from tools.otel_setup import setup_tracing' line
new = re.sub(
    r"(from tools\.otel_setup import setup_tracing\n)",
    rf"\1{imp}\n",
    src, count=1
)

# 2. Add the registration immediately after the closing ')' of the FastMCP(...) block.
#    The FastMCP block uses multi-line form ending with ')\n'.
#    Use re.DOTALL + lazy match to handle multi-line constructors.
new = re.sub(
    r"(mcp = FastMCP\(.*?\)\n)",
    rf"\1\n# Pitfall 9: register GuardrailMiddleware BEFORE streamable_http_app() (called at module bottom).\n{reg}\n",
    new, count=1, flags=re.DOTALL
)

p.write_text(new)
PY
  if python3 -c "
import pathlib
src = pathlib.Path('$f').read_text()
has_import = '${GUARD_IMPORT}' in src
has_register = '${GUARD_REGISTER}' in src
exit(0 if has_import and has_register else 1)
" 2>/dev/null; then
    echo "[ok]   ${f##*/} wired (import + register)"
  else
    echo "[FAIL] ${f##*/} — patch did not apply cleanly. Inspect manually."
    exit 1
  fi
done

echo
echo "Patched ${#PATCH_TARGETS[@]} tool files. Next step (extension exercise — NOT done by this script):"
echo "  Rebuild each tool image with the new code:"
echo "    cd course-code/labs/lab-07/solution"
echo "    docker build -t kind-registry:5001/mcp-triage:v1.1.0-guarded -f tools/triage/Dockerfile ."
echo "    kind load docker-image kind-registry:5001/mcp-triage:v1.1.0-guarded --name llmops-kind"
echo "    kubectl set image deploy/mcp-triage triage=kind-registry:5001/mcp-triage:v1.1.0-guarded -n llm-agent"
echo "  (Repeat for treatment_lookup port 8020 and book_appointment port 8030.)"
echo
echo "Lab 13 itself ships only the new insurance_check image (which is born guarded)."
