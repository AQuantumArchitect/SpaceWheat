#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_ROOT="$ROOT_DIR/🍄/🎛️/logs/codex_checks"
PROFILE_SCRIPT="$ROOT_DIR/scripts/profile-render-workload.sh"

CASES="12_expanded_4x2"
WARMUP_FRAMES="120"
SAMPLE_FRAMES="900"
TIMEOUT_S="300"
PACKET_STEPS=""
OUT_NAME=""
DISPLAY_NAME="${DISPLAY:-:0}"
WAYLAND_NAME="${WAYLAND_DISPLAY:-wayland-0}"
RENDERING_DRIVER="${RUNTIME_RENDERING_DRIVER:-}"
RENDERING_METHOD="${RUNTIME_RENDERING_METHOD:-}"
BUBBLE_QUALITY="${SW_BUBBLE_QUALITY:-}"

usage() {
	cat <<'EOF'
Usage: 🍄/🧪/runtime_lag_profile.sh [options]

Options:
  --cases VALUE          Space-separated workload cases (default: 12_expanded_4x2)
  --warmup N            Warmup frames before sampling (default: 120)
  --frames N            Sample frames (default: 900)
  --timeout N           Timeout in seconds (default: 300)
  --packet-steps N      Set SW_MAX_PACKET_STEPS for this run
  --out NAME            Output directory name under 🍄/🎛️/logs/codex_checks
  --display VALUE       DISPLAY for headed Godot (default: current DISPLAY or :0)
  --wayland VALUE       WAYLAND_DISPLAY (default: current WAYLAND_DISPLAY or wayland-0)
  --rendering-driver V  Optional Godot rendering driver override
  --rendering-method V  Optional Godot rendering method override
  --bubble-quality V    Optional bubble quality: low, medium, or high
  -h, --help            Show this help
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--cases)
			CASES="${2:?missing value for --cases}"
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
		--packet-steps)
			PACKET_STEPS="${2:?missing value for --packet-steps}"
			shift 2
			;;
		--out)
			OUT_NAME="${2:?missing value for --out}"
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

if [[ ! -x "$PROFILE_SCRIPT" && ! -f "$PROFILE_SCRIPT" ]]; then
	echo "missing profile script: $PROFILE_SCRIPT" >&2
	exit 3
fi

mkdir -p "$LOG_ROOT"
if [[ -z "$OUT_NAME" ]]; then
	stamp="$(date +%Y%m%d_%H%M%S)"
	safe_cases="${CASES// /_}"
	if [[ -n "$PACKET_STEPS" ]]; then
		OUT_NAME="runtime_lag_${safe_cases}_cap${PACKET_STEPS}_${stamp}"
	else
		OUT_NAME="runtime_lag_${safe_cases}_${stamp}"
	fi
fi
OUT_DIR="$LOG_ROOT/$OUT_NAME"

mkdir -p "$ROOT_DIR/🍄/🎛️/.godot_tmp/home" "$ROOT_DIR/🍄/🎛️/.godot_tmp/runtime" "$OUT_DIR"

export HOME="$ROOT_DIR/🍄/🎛️/.godot_tmp/home"
export XDG_RUNTIME_DIR="$ROOT_DIR/🍄/🎛️/.godot_tmp/runtime"
export DISPLAY="$DISPLAY_NAME"
export WAYLAND_DISPLAY="$WAYLAND_NAME"
export PROFILE_WORKLOAD_CASES="$CASES"
export PROFILE_WARMUP_FRAMES="$WARMUP_FRAMES"
export PROFILE_SAMPLE_FRAMES="$SAMPLE_FRAMES"
export RUNTIME_RENDERING_DRIVER="$RENDERING_DRIVER"
export RUNTIME_RENDERING_METHOD="$RENDERING_METHOD"
export SW_BUBBLE_QUALITY="$BUBBLE_QUALITY"

if [[ -n "$PACKET_STEPS" ]]; then
	export SW_MAX_PACKET_STEPS="$PACKET_STEPS"
else
	unset SW_MAX_PACKET_STEPS || true
fi

echo "SpaceWheat runtime lag profile wrapper"
echo "root: $ROOT_DIR"
echo "out:  $OUT_DIR"
echo "cases: $CASES"
echo "warmup_frames: $WARMUP_FRAMES"
echo "sample_frames: $SAMPLE_FRAMES"
if [[ -n "$PACKET_STEPS" ]]; then
	echo "SW_MAX_PACKET_STEPS: $PACKET_STEPS"
fi
if [[ -n "$BUBBLE_QUALITY" ]]; then
	echo "SW_BUBBLE_QUALITY: $BUBBLE_QUALITY"
fi
echo

timeout "${TIMEOUT_S}s" bash "$PROFILE_SCRIPT" "$OUT_DIR"
