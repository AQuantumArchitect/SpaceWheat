#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNS="${RUNS:-5}"
MAX_LOOPS="${MAX_LOOPS:-220}"
OUT_DIR="${OUT_DIR:-/tmp/milk_hunt_batches}"
PREP_STARTER_SAVE="${PREP_STARTER_SAVE:-0}"
STARTER_SAVE_SLOT="${STARTER_SAVE_SLOT:-}"
STARTER_RESOURCES="${STARTER_RESOURCES:-👥:250,🌾:250,🍞:120,❄️:120,🌱:120,⚙:120,🔥:120}"
PROFILE="${PROFILE:-}"
RESOURCE_MODE="${RESOURCE_MODE:-}"
SEED_FROM_SLOT="${SEED_FROM_SLOT:-}"
LOAD_ALIAS="${LOAD_ALIAS:-}"
STRICT_BIOME_ECONOMY="${STRICT_BIOME_ECONOMY:-0}"
REUSE_LISTENER="${REUSE_LISTENER:-0}"
STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${LOG_FILE:-${OUT_DIR}/batch_launch_${STAMP}.log}"
mkdir -p "$(dirname "${LOG_FILE}")"

echo "[run] starting milk_hunt_batch.py runs=${RUNS} max_loops=${MAX_LOOPS}"
if [[ "${PREP_STARTER_SAVE}" == "1" ]] && [[ -n "${STARTER_SAVE_SLOT}" ]]; then
  echo "[run] preparing starter save slot=${STARTER_SAVE_SLOT} profile=${PROFILE:-<none>} resources=${STARTER_RESOURCES}"
  starter_args=(--slot "${STARTER_SAVE_SLOT}")
  if [[ -n "${PROFILE}" ]]; then
    starter_args+=(--profile "${PROFILE}")
  else
    IFS=',' read -r -a _starter_parts <<< "${STARTER_RESOURCES}"
    for part in "${_starter_parts[@]}"; do
      starter_args+=(--resource "${part}")
    done
  fi
  if [[ -n "${RESOURCE_MODE}" ]]; then
    starter_args+=(--resource-mode "${RESOURCE_MODE}")
  fi
  if [[ -n "${SEED_FROM_SLOT}" ]]; then
    starter_args+=(--load-slot "${SEED_FROM_SLOT}")
  fi
  python3 "${SCRIPT_DIR}/milk_hunt_seed_save.py" \
    "${starter_args[@]}" | tee "${LOG_FILE}"
fi

batch_args=(
  --runs "${RUNS}"
  --max-loops "${MAX_LOOPS}"
  --output-dir "${OUT_DIR}"
)
if [[ -n "${LOAD_ALIAS}" ]]; then
  batch_args+=(--load-alias "${LOAD_ALIAS}")
elif [[ -n "${STARTER_SAVE_SLOT}" ]]; then
  batch_args+=(--load-slot "${STARTER_SAVE_SLOT}")
fi
if [[ -n "${PROFILE}" ]]; then
  batch_args+=(--profile "${PROFILE}" --seed-slot "${STARTER_SAVE_SLOT:-2}")
fi
if [[ -n "${SEED_FROM_SLOT}" ]]; then
  batch_args+=(--seed-from-slot "${SEED_FROM_SLOT}")
fi
if [[ -n "${RESOURCE_MODE}" ]]; then
  batch_args+=(--resource-mode "${RESOURCE_MODE}")
fi
if [[ "${STRICT_BIOME_ECONOMY}" == "1" ]]; then
  batch_args+=(--strict-biome-economy)
fi
if [[ "${REUSE_LISTENER}" == "1" ]]; then
  batch_args+=(--reuse-listener)
fi

python3 "${SCRIPT_DIR}/milk_hunt_batch.py" \
  "${batch_args[@]}" \
  | tee -a "${LOG_FILE}"
echo "[run] log written to ${LOG_FILE}"
