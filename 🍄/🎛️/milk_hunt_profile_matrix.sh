#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${OUT_DIR:-/tmp/milk_profile_runs}"
PROFILES=("granary_scout" "arc_coldpath_explorer" "solar_gatekeeper" "village_diplomat" "biotic_bubble_runner")
STARTER_SLOT="${STARTER_SLOT:-2}"
MAX_LOOPS="${MAX_LOOPS:-13}"
RUNS="${RUNS:-1}"

mkdir -p "${OUT_DIR}"

for profile in "${PROFILES[@]}"; do
  LOG_DIR="${OUT_DIR}/${profile}"
  mkdir -p "${LOG_DIR}"
  echo "[matrix] profile=${profile} max_loops=${MAX_LOOPS}"
  PROFILE="${profile}" \
  STARTER_SAVE_SLOT="${STARTER_SLOT}" \
  LOG_FILE="${LOG_DIR}/run.log" \
  RUNS="${RUNS}" \
  MAX_LOOPS="${MAX_LOOPS}" \
  PREP_STARTER_SAVE=1 \
    "${SCRIPT_DIR}/🧭🥛🧪🚜.sh" > "${LOG_DIR}/batch_stdout.log" 2>&1
  latest_summary="$(find /tmp/milk_hunt_batches -type f -name batch_summary.json -printf '%T@ %p\n' | sort -n | tail -n1 | cut -d' ' -f2-)"
  if [[ -n "${latest_summary}" ]]; then
    cp "${latest_summary}" "${LOG_DIR}/summary.json"
  fi
done
