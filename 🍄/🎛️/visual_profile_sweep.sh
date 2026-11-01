#!/usr/bin/env bash
# visual_profile_sweep.sh — smoke-test every profile through the phrame bridge.
#
# Prerequisites:
#   RIG_PHRAME_BRIDGE=1 ./dev_launch.sh   (in another terminal)
#
# Environment overrides:
#   MAX_LOOPS  — hunt loops per profile (default: 13)
#   SLOT       — save slot used for seeding (default: 2)
#   OUT_DIR    — log directory (default: /tmp/visual_profile_sweep)
#   PROFILES   — space-separated override list (default: all 13)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAX_LOOPS="${MAX_LOOPS:-13}"
SLOT="${SLOT:-2}"
OUT_DIR="${OUT_DIR:-/tmp/visual_profile_sweep}"

mkdir -p "${OUT_DIR}"

# --------------------------------------------------------------------------
# Resolve sentinel path by cd-ing to the script dir (avoids sys.path issues)
# --------------------------------------------------------------------------
SENTINEL_PATH="$(cd "${SCRIPT_DIR}" && python3 -c "from rig_client import RigClient; print(RigClient._bridge_sentinel_path())")"

if [[ ! -f "${SENTINEL_PATH}" ]]; then
    echo "[sweep] ERROR: bridge sentinel not found."
    echo "[sweep]   Expected: ${SENTINEL_PATH}"
    echo "[sweep]   Start the game with: RIG_PHRAME_BRIDGE=1 ./dev_launch.sh"
    exit 1
fi

BRIDGE_PID="$(cat "${SENTINEL_PATH}" | tr -d '[:space:]')"
echo "[sweep] Bridge sentinel OK (PID ${BRIDGE_PID})"
echo "[sweep] Slot: ${SLOT}  Max loops: ${MAX_LOOPS}  Logs: ${OUT_DIR}"

# --------------------------------------------------------------------------
# Profile list (all world_state configs)
# --------------------------------------------------------------------------
if [[ -n "${PROFILES:-}" ]]; then
    read -ra PROFILE_LIST <<< "${PROFILES}"
else
    PROFILE_LIST=(
        arc_coldpath_explorer
        balanced_survival
        biotic_bubble_runner
        biotic_flux_ladder
        fungal_long_horizon
        granary_scout
        injection_biased
        probe_heavy
        quest_push
        scarcity_stress
        solar_gatekeeper
        village_diplomat
        volcanic_bridge
    )
fi

TOTAL="${#PROFILE_LIST[@]}"
PASS=0
FAIL=0
IDX=0

# --------------------------------------------------------------------------
# Per-profile: seed → hunt (bridge stays alive via --reuse-listener / --no-stop)
# --------------------------------------------------------------------------
for profile in "${PROFILE_LIST[@]}"; do
    IDX=$((IDX + 1))
    LOG="${OUT_DIR}/${profile}.log"
    echo ""
    echo "[sweep] [$IDX/$TOTAL] ── ${profile} ────────────────────────────────"
    : > "${LOG}"

    # Read strict_biome_economy from the profile JSON so the runner gets the
    # right injection mode.  Profiles without the field default to strict=true.
    STRICT_FLAG="$(cd "${SCRIPT_DIR}" && python3 -c "
import json, pathlib
p = pathlib.Path('config/world_state/${profile}.json')
d = json.loads(p.read_text()) if p.exists() else {}
print('--strict-biome-economy' if d.get('strict_biome_economy', True) else '--no-strict-biome-economy')
")"
    echo "[sweep] strict_biome_economy flag: ${STRICT_FLAG}"

    # -- Seed ---------------------------------------------------------------
    echo "[sweep] seeding..."
    SEED_OK=0
    cd "${SCRIPT_DIR}" && python3 milk_hunt_seed_save.py \
        --slot "${SLOT}" \
        --profile "${profile}" \
        --reuse-listener \
        2>&1 | tee -a "${LOG}" && SEED_OK=1 || true

    if [[ "${SEED_OK}" -eq 0 ]]; then
        echo "[sweep] SEED FAILED — skipping hunt for ${profile}"
        FAIL=$((FAIL + 1))
        continue
    fi
    echo "[sweep] seed OK"

    # -- Hunt ---------------------------------------------------------------
    echo "[sweep] hunting (${MAX_LOOPS} loops)..."
    HUNT_EXIT=0
    cd "${SCRIPT_DIR}" && python3 milk_hunt_runner.py \
        --reuse-listener \
        --load-slot "${SLOT}" \
        --max-loops "${MAX_LOOPS}" \
        --no-stop \
        "${STRICT_FLAG}" \
        2>&1 | tee -a "${LOG}"; HUNT_EXIT="${PIPESTATUS[0]:-$?}" || true

    # Exit 0 = found milk, Exit 2 = ran fine but no milk in N loops (expected
    # for a short smoke test).  Exit 1/4 = real failures.
    if [[ "${HUNT_EXIT}" -eq 0 || "${HUNT_EXIT}" -eq 2 ]]; then
        echo "[sweep] hunt OK (exit ${HUNT_EXIT})"
        PASS=$((PASS + 1))
    else
        echo "[sweep] HUNT FAILED — ${profile} (exit ${HUNT_EXIT})"
        FAIL=$((FAIL + 1))
    fi
done

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
echo ""
echo "[sweep] ══════════════════════════════════════════════════════"
echo "[sweep] DONE  passed: ${PASS}  failed: ${FAIL}  total: ${TOTAL}"
echo "[sweep] Logs: ${OUT_DIR}"
echo "[sweep] Bridge is still live — close the game window when done."
