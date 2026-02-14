#!/usr/bin/env bash
set -euo pipefail

# 🥛🏃 - Emoji entrypoint for milk_hunt_runner.py and scan helpers.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "${1:-}" == "scan" ]]; then
  shift
  if [[ $# -eq 0 ]]; then
    set -- results
  fi
  exec python3 "${SCRIPT_DIR}/milk_hunt_scan.py" "$@"
fi

exec python3 "${SCRIPT_DIR}/milk_hunt_runner.py" "$@"
