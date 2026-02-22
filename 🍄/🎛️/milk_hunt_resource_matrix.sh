#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE="${PROFILE:-balanced_survival}"
SLOT="${SLOT:-2}"
RESOURCE_LEVELS="${RESOURCE_LEVELS:-1,2,4,8,16}"
RUNS="${RUNS:-1}"
MAX_LOOPS="${MAX_LOOPS:-40}"
OUT_DIR="${OUT_DIR:-/tmp/milk_run_resource_matrix}"

mkdir -p "${OUT_DIR}"

PRIMARY_EMOJIS=( "🍞" "❄️" "👥" "🌾" "🌱" "⚙" "🔥" )

for level in ${RESOURCE_LEVELS//,/ }; do
  LEVEL_DIR="${OUT_DIR}/level_${level}"
  mkdir -p "${LEVEL_DIR}"
  echo "[matrix] level=${level} slot=${SLOT} resetting resources"
  RESOURCE_ARGS=()
  for emoji in "${PRIMARY_EMOJIS[@]}"; do
    RESOURCE_ARGS+=(--resource "${emoji}:${level}")
  done

  python3 "${SCRIPT_DIR}/milk_hunt_seed_save.py" \
    --slot "${SLOT}" \
    --profile "${PROFILE}" \
    --resource-mode set \
    "${RESOURCE_ARGS[@]}" \
    > "${LEVEL_DIR}/seed_stdout.log"

  python3 "${SCRIPT_DIR}/milk_hunt_batch.py" \
    --runs "${RUNS}" \
    --max-loops "${MAX_LOOPS}" \
    --output-dir "${LEVEL_DIR}" \
    --load-slot "${SLOT}" \
    --profile "${PROFILE}" \
    > "${LEVEL_DIR}/batch_stdout.log"

  summary_path="$(find "${LEVEL_DIR}" -name batch_summary.json -print -quit)"
  if [[ -n "${summary_path}" ]]; then
    cp "${summary_path}" "${LEVEL_DIR}/summary.json"
  fi

  echo "[matrix] level=${level} summary -> ${LEVEL_DIR}/summary.json"
done
