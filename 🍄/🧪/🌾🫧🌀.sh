#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/godot_runtime_env.sh"
LOG_ROOT="$ROOT_DIR/🍄/🎛️/logs/codex_checks"
OUT_NAME=""
WARMUP_FRAMES="${PROFILE_WARMUP_FRAMES:-60}"
SAMPLE_FRAMES="${PROFILE_SAMPLE_FRAMES:-240}"
TIMEOUT_S="${PROFILE_TIMEOUT_S:-240}"
DISPLAY_NAME="${DISPLAY:-:0}"
WAYLAND_NAME="${WAYLAND_DISPLAY:-wayland-0}"
RENDERING_DRIVER="${RUNTIME_RENDERING_DRIVER:-}"
RENDERING_METHOD="${RUNTIME_RENDERING_METHOD:-}"
BUBBLE_QUALITY="${SW_BUBBLE_QUALITY:-low}"
PACKET_STEPS="${SW_MAX_PACKET_STEPS:-8}"
START_INDEX=0
MAX_RUNGS=0

usage() {
	cat <<'EOF'
Usage: 🍄/🧪/🌾🫧🌀.sh [options]

Runs a Fibonacci escalation sweep for biome stress:
  dormant sanity
  1 terminal / 1 biome
  2 terminals / 1 biome
  3 terminals / 2 biomes
  5 terminals / 3 biomes
  ...

Options:
  --out NAME            Output directory under 🍄/🎛️/logs/codex_checks
  --warmup N            Warmup frames per rung (default: 60)
  --frames N            Sample frames per rung (default: 240)
  --timeout N           Timeout seconds per rung (default: 240)
  --display VALUE       DISPLAY for headed Godot
  --wayland VALUE       WAYLAND_DISPLAY for headed Godot
  --rendering-driver V  Optional Godot rendering driver override
  --rendering-method V  Optional Godot rendering method override
  --bubble-quality V    Bubble quality override (default: low)
  --packet-steps N      SW_MAX_PACKET_STEPS override (default: 8)
  --start-index N       Skip the first N Fibonacci ladder rungs
  --max-rungs N         Run at most N Fibonacci ladder rungs
  -h, --help            Show this help
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--out)
			OUT_NAME="${2:?missing value for --out}"
			shift 2
			;;
		--warmup)
			WARMUP_FRAMES="${2:?missing value for --warmup}"
			shift 2
			;;
		--frames)
			SAMPLE_FRAMES="${2:?missing value for --frames}"
			shift 2
			;;
		--timeout)
			TIMEOUT_S="${2:?missing value for --timeout}"
			shift 2
			;;
		--display)
			DISPLAY_NAME="${2:?missing value for --display}"
			shift 2
			;;
		--wayland)
			WAYLAND_NAME="${2:?missing value for --wayland}"
			shift 2
			;;
		--rendering-driver)
			RENDERING_DRIVER="${2:?missing value for --rendering-driver}"
			shift 2
			;;
		--rendering-method)
			RENDERING_METHOD="${2:?missing value for --rendering-method}"
			shift 2
			;;
		--bubble-quality)
			BUBBLE_QUALITY="${2:?missing value for --bubble-quality}"
			shift 2
			;;
		--packet-steps)
			PACKET_STEPS="${2:?missing value for --packet-steps}"
			shift 2
			;;
		--start-index)
			START_INDEX="${2:?missing value for --start-index}"
			shift 2
			;;
		--max-rungs)
			MAX_RUNGS="${2:?missing value for --max-rungs}"
			shift 2
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			echo "unknown option: $1" >&2
			usage >&2
			exit 2
			;;
	esac
done

mkdir -p "$LOG_ROOT" "$ROOT_DIR/🍄/🎛️/.godot_tmp/home" "$ROOT_DIR/🍄/🎛️/.godot_tmp/runtime"

if [[ -z "$OUT_NAME" ]]; then
	OUT_NAME="fibonacci_biome_ladder_$(date +%Y%m%d_%H%M%S)"
fi
OUT_DIR="$LOG_ROOT/$OUT_NAME"
mkdir -p "$OUT_DIR"

export HOME="$ROOT_DIR/🍄/🎛️/.godot_tmp/home"
export XDG_RUNTIME_DIR="$ROOT_DIR/🍄/🎛️/.godot_tmp/runtime"
export DISPLAY="$DISPLAY_NAME"
export WAYLAND_DISPLAY="$WAYLAND_NAME"
export SW_BUBBLE_QUALITY="$BUBBLE_QUALITY"
export SW_MAX_PACKET_STEPS="$PACKET_STEPS"

sw_prepare_runtime_env "interactive"

AVAILABLE_BIOMES="$(
	python3 - <<'PY'
import json
from pathlib import Path
data = json.loads(Path("Core/Biomes/data/biomes.json").read_text())
count = 0
for biome in data:
    name = str(biome.get("name", ""))
    if name and not name.startswith("_"):
        count += 1
print(count)
PY
)"

FIB_TERMINALS=(1 2 3 5 8 13 21 34 55 89)
FIB_BIOMES=(1 1 2 3 5 8 13 21 34 55)

echo "SpaceWheat Fibonacci biome ladder"
echo "root: $ROOT_DIR"
echo "out:  $OUT_DIR"
echo "available_biomes: $AVAILABLE_BIOMES"
echo "warmup_frames: $WARMUP_FRAMES"
echo "sample_frames: $SAMPLE_FRAMES"
echo "SW_MAX_PACKET_STEPS: $PACKET_STEPS"
echo "SW_BUBBLE_QUALITY: $BUBBLE_QUALITY"
echo

run_case() {
	local label="$1"
	local mode="$2"
	local ladder_biomes="${3:-0}"
	local ladder_terminals="${4:-0}"
	local json_path="$OUT_DIR/${label}.json"
	local log_path="$OUT_DIR/${label}.log"

	echo "============================================================"
	echo "FIB LADDER: $label"
	if [[ "$mode" == "dormant" ]]; then
		echo "mode=dormant"
	else
		echo "mode=ladder requested_terminals=$ladder_terminals requested_biomes=$ladder_biomes"
	fi
	echo "============================================================"

	local cmd=(sw_godot --path "$ROOT_DIR")
	if [[ -n "$RENDERING_DRIVER" ]]; then
		cmd+=(--rendering-driver "$RENDERING_DRIVER")
	fi
	if [[ -n "$RENDERING_METHOD" ]]; then
		cmd+=(--rendering-method "$RENDERING_METHOD")
	fi
	cmd+=(--
		--runtime-profile-mode="$mode"
		--runtime-profile-output="$json_path"
		--runtime-profile-warmup="$WARMUP_FRAMES"
		--runtime-profile-frames="$SAMPLE_FRAMES"
	)
	if [[ "$mode" == "ladder" ]]; then
		cmd+=(
			--runtime-profile-ladder-biomes="$ladder_biomes"
			--runtime-profile-ladder-terminals="$ladder_terminals"
		)
	fi

	set +e
	timeout "${TIMEOUT_S}s" "${cmd[@]}" 2>&1 | tee "$log_path"
	local status=${PIPESTATUS[0]}
	set -e
	if [[ "$status" -ne 0 ]]; then
		echo "warning: case '$label' exited with status $status" | tee -a "$log_path"
		return "$status"
	fi
	return 0
}

run_case "L00_dormant_sanity" "dormant"

actual_count_from_json() {
	local json_path="$1"
	python3 - "$json_path" <<'PY'
import json, sys
path = sys.argv[1]
data = json.loads(open(path).read())
print(len(data.get("scenario", {}).get("explored", [])))
PY
}

cases_run=0
for idx in "${!FIB_TERMINALS[@]}"; do
	if (( idx < START_INDEX )); then
		continue
	fi
	if (( MAX_RUNGS > 0 && cases_run >= MAX_RUNGS )); then
		break
	fi

	requested_terminals="${FIB_TERMINALS[$idx]}"
	requested_biomes="${FIB_BIOMES[$idx]}"
	if (( requested_biomes > AVAILABLE_BIOMES )); then
		requested_biomes="$AVAILABLE_BIOMES"
	fi

	label="$(printf 'L%02d_fib_%02dt_%02db' "$((idx + 1))" "$requested_terminals" "$requested_biomes")"
	run_case "$label" "ladder" "$requested_biomes" "$requested_terminals"

	actual_explored="$(actual_count_from_json "$OUT_DIR/${label}.json")"
	echo "resolved_explored=$actual_explored requested=$requested_terminals"
	echo

	cases_run=$((cases_run + 1))
	if (( actual_explored < requested_terminals )); then
		echo "saturation reached at $label (resolved $actual_explored < requested $requested_terminals)"
		break
	fi
done

python3 "$ROOT_DIR/scripts/summarize-render-workload.py" "$OUT_DIR"
