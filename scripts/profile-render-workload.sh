#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-$ROOT_DIR/🍄/🎛️/.godot_tmp/render_profiles_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$OUT_DIR"

WARMUP_FRAMES="${PROFILE_WARMUP_FRAMES:-90}"
SAMPLE_FRAMES="${PROFILE_SAMPLE_FRAMES:-240}"
RENDERING_DRIVER="${RUNTIME_RENDERING_DRIVER:-}"
RENDERING_METHOD="${RUNTIME_RENDERING_METHOD:-}"

FAILED_RUNS=()
REQUESTED_CASES="${PROFILE_WORKLOAD_CASES:-}"

should_run_case() {
	local label="$1"
	if [ -z "$REQUESTED_CASES" ]; then
		return 0
	fi
	if [ "$label" = "12_expanded_4x2" ]; then
		case " $REQUESTED_CASES " in
			*" 09_expanded_4x2 "*) return 0 ;;
		esac
	fi
	case " $REQUESTED_CASES " in
		*" $label "*) return 0 ;;
		*) return 1 ;;
	esac
}

run_case() {
	local label="$1"
	local mode="$2"
	local dense_terminals="$3"
	local multi_biomes="$4"
	local expanded_biomes="${5:-4}"
	local expanded_terminals_per_biome="${6:-2}"
	local log_path="$OUT_DIR/${label}.log"
	local json_path="$OUT_DIR/${label}.json"

	if ! should_run_case "$label"; then
		return 0
	fi

	echo "============================================================"
	echo "RENDER WORKLOAD: $label"
	echo "mode=$mode dense_terminals=$dense_terminals multi_biomes=$multi_biomes expanded=${expanded_biomes}x${expanded_terminals_per_biome}"
	echo "============================================================"

	local cmd=(godot --path "$ROOT_DIR")
	if [ -n "$RENDERING_DRIVER" ]; then
		cmd+=(--rendering-driver "$RENDERING_DRIVER")
	fi
	if [ -n "$RENDERING_METHOD" ]; then
		cmd+=(--rendering-method "$RENDERING_METHOD")
	fi
	cmd+=(
		--
		--runtime-profile-mode="$mode"
		--runtime-profile-output="$json_path"
		--runtime-profile-warmup="$WARMUP_FRAMES"
		--runtime-profile-frames="$SAMPLE_FRAMES"
		--runtime-profile-dense-terminals="$dense_terminals"
		--runtime-profile-multi-biomes="$multi_biomes"
		--runtime-profile-expanded-biomes="$expanded_biomes"
		--runtime-profile-expanded-terminals-per-biome="$expanded_terminals_per_biome"
	)

	set +e
	"${cmd[@]}" 2>&1 | tee "$log_path"
	local status=${PIPESTATUS[0]}
	set -e
	if [ "$status" -ne 0 ]; then
		echo "warning: workload '$label' exited with status $status" | tee -a "$log_path"
		FAILED_RUNS+=("$label:$status")
	fi
	echo
}

echo "SpaceWheat rendered workload profiler"
echo "output: $OUT_DIR"
echo "warmup_frames: $WARMUP_FRAMES"
echo "sample_frames: $SAMPLE_FRAMES"
if [ -n "$RENDERING_DRIVER" ]; then
	echo "rendering driver override: $RENDERING_DRIVER"
fi
if [ -n "$RENDERING_METHOD" ]; then
	echo "rendering method override: $RENDERING_METHOD"
fi
if [ -n "$REQUESTED_CASES" ]; then
	echo "requested cases: $REQUESTED_CASES"
fi
echo

run_case "00_dormant" "dormant" 0 0
run_case "01_single" "single" 1 1
run_case "02_dense_2" "dense" 2 1
run_case "03_dense_4" "dense" 4 1
run_case "04_dense_8" "dense" 8 1
run_case "05_dense_12" "dense" 12 1
run_case "06_multi_2" "multi" 1 2
run_case "07_multi_4" "multi" 1 4
run_case "08_multi_8" "multi" 1 8
run_case "09_expanded_2x1" "expanded" 1 1 2 1
run_case "10_expanded_3x1" "expanded" 1 1 3 1
run_case "11_expanded_4x1" "expanded" 1 1 4 1
run_case "12_expanded_4x2" "expanded" 1 1 4 2
run_case "13_expanded_6x2" "expanded" 1 1 6 2

python3 "$ROOT_DIR/scripts/summarize-render-workload.py" "$OUT_DIR"

if [ "${#FAILED_RUNS[@]}" -gt 0 ]; then
	echo "Profile workloads with non-zero exit: ${FAILED_RUNS[*]}"
	exit 1
fi
