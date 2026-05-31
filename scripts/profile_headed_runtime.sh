#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib/godot_runtime_env.sh"
OUT_DIR="${1:-$ROOT_DIR/🍄/🎛️/.godot_tmp/runtime_profiles_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$OUT_DIR"
FAILED_MODES=()
PROFILE_HOME="${PROFILE_HOME:-$OUT_DIR/runtime_home}"
PROFILE_CONFIG_HOME="${PROFILE_CONFIG_HOME:-$OUT_DIR/runtime_config}"
PROFILE_DATA_HOME="${PROFILE_DATA_HOME:-$OUT_DIR/runtime_data}"
mkdir -p "$PROFILE_HOME" "$PROFILE_CONFIG_HOME" "$PROFILE_DATA_HOME"

MODES=(dormant single dense multi)
RENDERING_DRIVER="${RUNTIME_RENDERING_DRIVER:-}"
RENDERING_METHOD="${RUNTIME_RENDERING_METHOD:-}"

echo "SpaceWheat headed runtime profiler"
echo "output: $OUT_DIR"
if [ -n "$RENDERING_DRIVER" ]; then
	echo "rendering driver override: $RENDERING_DRIVER"
fi
if [ -n "$RENDERING_METHOD" ]; then
	echo "rendering method override: $RENDERING_METHOD"
fi
echo

sw_prepare_runtime_env "interactive"

for mode in "${MODES[@]}"; do
	echo "============================================================"
	echo "PROFILE MODE: $mode"
	echo "============================================================"
	LOG_PATH="$OUT_DIR/${mode}.log"
	JSON_PATH="$OUT_DIR/${mode}.json"
	CMD=(sw_godot --path "$ROOT_DIR")
	if [ -n "$RENDERING_DRIVER" ]; then
		CMD+=(--rendering-driver "$RENDERING_DRIVER")
	fi
	if [ -n "$RENDERING_METHOD" ]; then
		CMD+=(--rendering-method "$RENDERING_METHOD")
	fi
	CMD+=(
		--
		--runtime-profile-mode="$mode"
		--runtime-profile-output="$JSON_PATH"
		--runtime-profile-warmup="${PROFILE_WARMUP_FRAMES:-90}"
		--runtime-profile-frames="${PROFILE_SAMPLE_FRAMES:-240}"
		--runtime-profile-dense-terminals="${PROFILE_DENSE_TERMINALS:-4}"
		--runtime-profile-multi-biomes="${PROFILE_MULTI_BIOMES:-4}"
		--runtime-profile-expanded-biomes="${PROFILE_EXPANDED_BIOMES:-4}"
		--runtime-profile-expanded-terminals-per-biome="${PROFILE_EXPANDED_TERMINALS_PER_BIOME:-2}"
	)
	set +e
	HOME="$PROFILE_HOME" \
	XDG_CONFIG_HOME="$PROFILE_CONFIG_HOME" \
	XDG_DATA_HOME="$PROFILE_DATA_HOME" \
	"${CMD[@]}" \
		2>&1 | tee "$LOG_PATH"
	status=${PIPESTATUS[0]}
	set -e
	if [ "$status" -ne 0 ]; then
		echo "warning: mode '$mode' exited with status $status" | tee -a "$LOG_PATH"
		FAILED_MODES+=("$mode:$status")
	fi
	echo
done

echo "Profiles written to: $OUT_DIR"
if [ "${#FAILED_MODES[@]}" -gt 0 ]; then
	echo "Profile modes with non-zero exit: ${FAILED_MODES[*]}"
fi
