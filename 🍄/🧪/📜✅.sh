#!/bin/bash
set -euo pipefail

# 📜✅ - Script/parse verification gate without `--check-only`.
# Uses a short headless boot in a writable XDG root and fails on compile/script errors.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

mkdir -p "${LOG_ROOT}/verification"
STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${LOG_ROOT}/verification/script_gate_${STAMP}.log"

echo "Script Gate"
echo "==========================="
echo "Booting headless for script verification..."
echo "Log: ${LOG_FILE}"

sw_prepare_runtime_env "headless"
prepare_godot_user_dir

set +e
timeout 45s sw_godot --headless --path . --quit >"${LOG_FILE}" 2>&1
EXIT_CODE=$?
set -e

cat "${LOG_FILE}"

if rg -n "SCRIPT ERROR:|Parse Error:|Compile Error:|Failed to load script" "${LOG_FILE}" >/dev/null 2>&1; then
  echo ""
  echo "❌ Script gate failed: compile/parse errors detected"
  rg -n "SCRIPT ERROR:|Parse Error:|Compile Error:|Failed to load script" "${LOG_FILE}"
  exit 2
fi

if [ "${EXIT_CODE}" -ne 0 ] && [ "${EXIT_CODE}" -ne 124 ]; then
  echo ""
  echo "❌ Script gate failed: godot exit code ${EXIT_CODE}"
  exit "${EXIT_CODE}"
fi

echo ""
echo "✅ Script gate passed"
