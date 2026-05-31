#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-${SCRIPT_DIR}/config/milk_hunt_batch.conf}"
if [[ -f "${CONFIG_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"
fi

RUNS="${RUNS:-${RUNS_DEFAULT:-5}}"
MAX_LOOPS="${MAX_LOOPS:-${MAX_LOOPS_DEFAULT:-220}}"
OUT_DIR="${OUT_DIR:-${OUT_DIR_DEFAULT:-/tmp/milk_hunt_batches}}"
CONSOLE_PROFILE="${CONSOLE_PROFILE:-${CONSOLE_PROFILE_DEFAULT:-quiet}}"
PREP_STARTER_SAVE="${PREP_STARTER_SAVE:-${PREP_STARTER_SAVE_DEFAULT:-0}}"
STARTER_SAVE_SLOT="${STARTER_SAVE_SLOT:-${STARTER_SAVE_SLOT_DEFAULT:-}}"
PROFILE="${PROFILE:-${PROFILE_DEFAULT:-}}"
WORLD_STATE="${WORLD_STATE:-${WORLD_STATE_DEFAULT:-}}"
STRATEGY="${STRATEGY:-${STRATEGY_DEFAULT:-}}"
RUNTIME_PROFILE="${RUNTIME_PROFILE:-${RUNTIME_PROFILE_DEFAULT:-}}"
METRICS_EVERY="${METRICS_EVERY:-${METRICS_EVERY_DEFAULT:-0}}"
RESOURCE_MODE="${RESOURCE_MODE:-${RESOURCE_MODE_DEFAULT:-}}"
SEED_FROM_SLOT="${SEED_FROM_SLOT:-${SEED_FROM_SLOT_DEFAULT:-}}"
PROFILE_SAVE="${PROFILE_SAVE:-${PROFILE_SAVE_DEFAULT:-}}"
PROFILE_SAVE_INDEX="${PROFILE_SAVE_INDEX:-${PROFILE_SAVE_INDEX_DEFAULT:-}}"
STRICT_BIOME_ECONOMY="${STRICT_BIOME_ECONOMY:-${STRICT_BIOME_ECONOMY_DEFAULT:-0}}"
REUSE_LISTENER="${REUSE_LISTENER:-${REUSE_LISTENER_DEFAULT:-1}}"
STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${LOG_FILE:-${OUT_DIR}/batch_launch_${STAMP}.log}"
mkdir -p "$(dirname "${LOG_FILE}")"

echo "[run] starting milk_hunt_batch.py runs=${RUNS} max_loops=${MAX_LOOPS}"
if [[ -n "${PROFILE_SAVE}" ]] && [[ "${PREP_STARTER_SAVE}" == "1" ]]; then
  echo "[run] PROFILE_SAVE is set; skipping starter slot preparation."
elif [[ "${PREP_STARTER_SAVE}" == "1" ]] && [[ -n "${STARTER_SAVE_SLOT}" ]]; then
  if [[ -z "${PROFILE}" ]] && [[ -z "${WORLD_STATE}" ]]; then
    echo "[error] PREP_STARTER_SAVE=1 requires PROFILE or WORLD_STATE." >&2
    exit 2
  fi
  echo "[run] preparing starter save slot=${STARTER_SAVE_SLOT} profile=${PROFILE:-${WORLD_STATE}}"
  starter_args=(--slot "${STARTER_SAVE_SLOT}")
  if [[ -n "${WORLD_STATE}" ]]; then
    starter_args+=(--world-state "${WORLD_STATE}")
  elif [[ -n "${PROFILE}" ]]; then
    starter_args+=(--profile "${PROFILE}")
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
  --console-profile "${CONSOLE_PROFILE}"
)
if [[ -n "${PROFILE_SAVE}" ]]; then
  batch_args+=(--profile-save "${PROFILE_SAVE}")
elif [[ -n "${STARTER_SAVE_SLOT}" ]]; then
  batch_args+=(--load-slot "${STARTER_SAVE_SLOT}")
fi
if [[ -n "${PROFILE_SAVE_INDEX}" ]]; then
  batch_args+=(--profile-save-index "${PROFILE_SAVE_INDEX}")
fi
if [[ -n "${WORLD_STATE}" ]]; then
  batch_args+=(--world-state "${WORLD_STATE}" --seed-slot "${STARTER_SAVE_SLOT:-2}")
elif [[ -n "${PROFILE}" ]] && [[ -z "${PROFILE_SAVE}" ]]; then
  batch_args+=(--profile "${PROFILE}" --seed-slot "${STARTER_SAVE_SLOT:-2}")
fi
if [[ -n "${STRATEGY}" ]]; then
  batch_args+=(--strategy "${STRATEGY}")
fi
if [[ -n "${RUNTIME_PROFILE}" ]]; then
  batch_args+=(--runtime-profile "${RUNTIME_PROFILE}")
fi
if [[ -n "${METRICS_EVERY}" ]]; then
  batch_args+=(--metrics-every "${METRICS_EVERY}")
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
if [[ "${ARCHIVE_RIG_DATA}" == "1" ]]; then
  batch_args+=(--archive-rig-data)
else
  batch_args+=(--no-archive-rig-data)
fi
if [[ "${REUSE_LISTENER}" == "1" ]]; then
  batch_args+=(--reuse-listener)
else
  batch_args+=(--no-reuse-listener)
fi

python3 "${SCRIPT_DIR}/milk_hunt_batch.py" \
  "${batch_args[@]}" \
  | tee -a "${LOG_FILE}"
echo "[run] log written to ${LOG_FILE}"
