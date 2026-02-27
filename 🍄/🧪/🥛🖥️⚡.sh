#!/usr/bin/env bash
set -euo pipefail

# 🥛🖥️⚡ - Visual milk-run slice (single run, non-batch)
# Starts rig listener with a real window, then runs a bounded milk hunt.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
cd "${PROJECT_ROOT}"
source "${PROJECT_ROOT}/scripts/lib/godot_runtime_env.sh"

CONFIG_FILE="${CONFIG_FILE:-${PROJECT_ROOT}/🍄/🎛️/config/milk_hunt_visual.conf}"
if [[ -f "${CONFIG_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"
fi

MAX_LOOPS="${MAX_LOOPS:-${MAX_LOOPS_DEFAULT:-35}}"
SCENARIO_ID="${SCENARIO_ID:-${SCENARIO_ID_DEFAULT:-default}}"
LOAD_SLOT="${LOAD_SLOT:-${LOAD_SLOT_DEFAULT:-}}"
LOAD_ALIAS="${LOAD_ALIAS:-${LOAD_ALIAS_DEFAULT:-}}"
PREP_STARTER_SAVE="${PREP_STARTER_SAVE:-${PREP_STARTER_SAVE_DEFAULT:-0}}"
STARTER_SAVE_SLOT="${STARTER_SAVE_SLOT:-${STARTER_SAVE_SLOT_DEFAULT:-2}}"
PROFILE="${PROFILE:-${PROFILE_DEFAULT:-balanced_survival}}"
MILK_RUNNER="${MILK_RUNNER:-${MILK_RUNNER_DEFAULT:-${PROJECT_ROOT}/🍄/🎛️/dev/milk_hunt_runner_graphics_waits.py}}"
TURN_DELAY_S="${TURN_DELAY_S:-${TURN_DELAY_S_DEFAULT:-}}"
PROBE_DELAY_S="${PROBE_DELAY_S:-${PROBE_DELAY_S_DEFAULT:-}}"
PROBE_EACH_LOOP="${PROBE_EACH_LOOP:-${PROBE_EACH_LOOP_DEFAULT:-}}"
STRICT_BIOME_ECONOMY="${STRICT_BIOME_ECONOMY:-${STRICT_BIOME_ECONOMY_DEFAULT:-1}}"
LISTENER_READY_TIMEOUT_S="${LISTENER_READY_TIMEOUT_S:-${LISTENER_READY_TIMEOUT_S_DEFAULT:-180}}"
LOG_ROOT="${LOG_ROOT:-${LOG_ROOT_DEFAULT:-${PROJECT_ROOT}/logs/milk_visual}}"
STAMP="$(date +%Y%m%d_%H%M%S)"
RUN_LOG="${LOG_ROOT}/milk_visual_run_${STAMP}.log"
LISTENER_LOG="${LOG_ROOT}/milk_visual_listener_${STAMP}.log"
SUMMARY_JSON="${LOG_ROOT}/milk_visual_summary_${STAMP}.json"

mkdir -p "${LOG_ROOT}"

export XDG_ROOT="${XDG_ROOT:-${PROJECT_ROOT}/.godot}"
export XDG_DATA_HOME="${XDG_ROOT}"
export XDG_CONFIG_HOME="${XDG_ROOT}"
export APPLICATION_NAME="${APPLICATION_NAME:-SpaceWheat - Quantum Farm}"
export GODOT_USER_DIR="${GODOT_USER_DIR:-${XDG_ROOT}/godot/app_userdata/${APPLICATION_NAME}}"
export DISABLE_VERBOSE_FILE_LOGGING=1
export RIG_DISABLE_LOOKAHEAD=1
export RIG_DISABLE_MI=1
export RIG_DISABLE_FORCE=1

mkdir -p "${GODOT_USER_DIR}/rig"
rm -f "${GODOT_USER_DIR}/rig/queue.jsonl" "${GODOT_USER_DIR}/rig/results.jsonl"

if [[ "${PREP_STARTER_SAVE}" == "1" ]]; then
  echo "[prep] Seeding slot=${STARTER_SAVE_SLOT} profile=${PROFILE}" | tee -a "${RUN_LOG}"
  python3 "${PROJECT_ROOT}/🍄/🎛️/milk_hunt_seed_save.py" \
    --slot "${STARTER_SAVE_SLOT}" \
    --profile "${PROFILE}" | tee -a "${RUN_LOG}"
  LOAD_SLOT="${STARTER_SAVE_SLOT}"
fi

for pid in $(pgrep -f "Tests/rig_listener.gd" || true); do
  kill "${pid}" || true
done

echo "[run] Launching visual rig listener (windowed, D3D12 GPU)..." | tee -a "${RUN_LOG}"
(
  cd "${PROJECT_ROOT}"
  sw_prepare_runtime_env "interactive"
  sw_godot --path . --rendering-method gl_compatibility --script Tests/rig_listener.gd
) >"${LISTENER_LOG}" 2>&1 &
LISTENER_PID=$!

cleanup() {
  if kill -0 "${LISTENER_PID}" 2>/dev/null; then
    kill "${LISTENER_PID}" || true
  fi
}
trap cleanup EXIT

READY=0
READY_CHECKS=$(( LISTENER_READY_TIMEOUT_S * 5 ))
for _ in $(seq 1 "${READY_CHECKS}"); do
  if grep -q "Rig ready. Waiting for turns in:" "${LISTENER_LOG}" 2>/dev/null; then
    READY=1
    break
  fi
  if ! kill -0 "${LISTENER_PID}" 2>/dev/null; then
    break
  fi
  sleep 0.2
done

if [[ "${READY}" != "1" ]]; then
  echo "[error] Visual listener did not become ready. Tail:" | tee -a "${RUN_LOG}"
  tail -n 80 "${LISTENER_LOG}" | tee -a "${RUN_LOG}" || true
  exit 1
fi

echo "[run] Running milk_hunt_runner (single milk run, visual, max_loops=${MAX_LOOPS})" | tee -a "${RUN_LOG}"
runner_args=(
  --reuse-listener
  --max-loops "${MAX_LOOPS}"
  --summary-path "${SUMMARY_JSON}"
)
if [[ -n "${TURN_DELAY_S}" ]]; then
  runner_args+=(--turn-delay-s "${TURN_DELAY_S}")
fi
if [[ -n "${PROBE_DELAY_S}" ]]; then
  runner_args+=(--probe-delay-s "${PROBE_DELAY_S}")
fi
if [[ "${PROBE_EACH_LOOP}" == "0" ]]; then
  runner_args+=(--no-probe-each-loop)
fi
if [[ "${STRICT_BIOME_ECONOMY}" == "1" ]]; then
  runner_args+=(--strict-biome-economy)
fi
if [[ -n "${LOAD_ALIAS}" ]]; then
  runner_args+=(--load-alias "${LOAD_ALIAS}")
elif [[ -n "${LOAD_SLOT}" ]]; then
  runner_args+=(--load-slot "${LOAD_SLOT}")
else
  runner_args+=(--scenario-id "${SCENARIO_ID}")
fi

set +e
if [[ "${MILK_RUNNER}" == *.sh ]]; then
  "${MILK_RUNNER}" "${runner_args[@]}" | tee -a "${RUN_LOG}"
else
  python3 "${MILK_RUNNER}" "${runner_args[@]}" | tee -a "${RUN_LOG}"
fi
EXIT_CODE=${PIPESTATUS[0]}
set -e
echo "[done] exit=${EXIT_CODE}" | tee -a "${RUN_LOG}"
echo "[done] run_log=${RUN_LOG}" | tee -a "${RUN_LOG}"
echo "[done] listener_log=${LISTENER_LOG}" | tee -a "${RUN_LOG}"
echo "[done] summary=${SUMMARY_JSON}" | tee -a "${RUN_LOG}"
exit "${EXIT_CODE}"
