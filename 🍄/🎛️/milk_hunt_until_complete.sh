#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROFILE="${PROFILE:-${1:-solar_gatekeeper}}"
SLOT="${SLOT:-2}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-24}"
LOOPS_PER_ATTEMPT="${LOOPS_PER_ATTEMPT:-89}"
POLICY_ACTIONS_PER_LOOP="${POLICY_ACTIONS_PER_LOOP:-10}"
STOP_ON="${STOP_ON:-pair}" # pair | offer | either
OUTDIR="${OUTDIR:-/tmp/milk_until_complete_${PROFILE}}"

if ! [[ "${SLOT}" =~ ^[0-2]$ ]]; then
  echo "[error] SLOT must be 0, 1, or 2 (got '${SLOT}')."
  exit 4
fi

mkdir -p "${OUTDIR}"

echo "[seed] profile=${PROFILE} slot=${SLOT}"
python3 "${SCRIPT_DIR}/milk_hunt_seed_save.py" \
  --profile "${PROFILE}" \
  --slot "${SLOT}" \
  > "${OUTDIR}/seed.log" 2>&1

attempt=0
total_loops=0
while (( attempt < MAX_ATTEMPTS )); do
  attempt=$((attempt + 1))
  summary="${OUTDIR}/${PROFILE}_attempt_${attempt}.json"
  log="${OUTDIR}/${PROFILE}_attempt_${attempt}.log"
  echo "[run] profile=${PROFILE} attempt=${attempt}/${MAX_ATTEMPTS} loops=${LOOPS_PER_ATTEMPT} total_before=${total_loops}" | tee "${log}"

  cmd=(
    python3 "${SCRIPT_DIR}/milk_hunt_runner.py"
    --load-slot "${SLOT}"
    --save-slot-at-end "${SLOT}"
    --hunter-profile "${PROFILE}"
    --hunter-policy engine_policy
    --strict-biome-economy
    --runtime-profile io_min
    --max-loops "${LOOPS_PER_ATTEMPT}"
    --policy-actions-per-loop "${POLICY_ACTIONS_PER_LOOP}"
    --lindblad-drain-focus
    --lindblad-wait-phrames 10
    --victory-lap
    --console-profile normal
    --summary-path "${summary}"
  )
  if (( attempt > 1 )); then
    cmd+=(--no-policy-reset-on-start)
  fi

  "${cmd[@]}" >> "${log}" 2>&1 || true

  if [[ ! -s "${summary}" ]]; then
    echo "[error] missing/empty summary: ${summary}" | tee -a "${log}"
    exit 3
  fi

  parsed="$(python3 - <<'PY' "${summary}" "${STOP_ON}"
import json,sys
path=sys.argv[1]
stop_on=sys.argv[2]
d=json.load(open(path,"r",encoding="utf-8"))
pair=bool(d.get("found_milk_pair", d.get("found_milk", False)))
offer=bool(d.get("found_milk_offer", False))
if stop_on=="offer":
    found=offer
elif stop_on=="either":
    found=(pair or offer)
else:
    found=pair
loops=int(d.get("loops_completed") or 0)
steps=int((d.get("steps") if d.get("steps") is not None else d.get("turns_executed")) or 0)
err=str(d.get("run_error") or "")
print("1" if found else "0", "1" if pair else "0", "1" if offer else "0", loops, steps, err)
PY
)"
  read -r found pair offer loops steps run_error <<< "${parsed}"
  total_loops=$((total_loops + loops))
  echo "[result] attempt=${attempt} found=${found} pair=${pair} offer=${offer} loops=${loops} steps=${steps} run_error=${run_error:-none} total_loops=${total_loops}" | tee -a "${log}"

  if [[ "${found}" == "1" ]]; then
    echo "[done] profile=${PROFILE} completed at attempt=${attempt} total_loops=${total_loops}" | tee -a "${log}"
    exit 0
  fi
done

echo "[stop] profile=${PROFILE} no completion after ${MAX_ATTEMPTS} attempts (${total_loops} loops)" | tee -a "${OUTDIR}/run.log"
exit 2
