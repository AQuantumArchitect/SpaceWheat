#!/bin/bash
# profile-export-runtime.sh — measure a DESKTOP EXPORT's frame cost.
#
# Drives the exported binary through the same lane a player's build has:
# SW_PERF_LOG (Core/Debug/PerfSampler.gd), which is compiled into the pack. The
# game samples every frame, writes one JSON report, and quits on its own.
#
# It used to pass `--runtime-profile-mode=…` and friends. Nothing in this
# repository has ever parsed those flags — the only script that could was
# tests/test_headed_runtime_profile.gd, which read PROFILE_* ENV VARS instead,
# was never invoked by anything, and is excluded from every export preset
# anyway. So this lane launched an exported game, waited, and then reported the
# absence of its own output as a failure ("mode 'dense' did not produce
# dense.json"). It has been rewritten around a parser that actually ships, and
# the phantom-flag cluster around it deleted.
#
# THE NUMBERS FROM THIS SCRIPT ARE ONLY AS GOOD AS THE RENDERER UNDER THEM.
# Inside WSL there is no GPU passthrough: a headed run lands on llvmpipe and the
# fps it reports is a software rasteriser's. Every report carries
# `environment.software_rendering_suspected` and a `trustworthy` verdict for
# exactly this reason; this script refuses to summarise a run as a result when
# that flag is set. Real numbers come from the Windows-side kit — see
# docs/performance/PROFILING.md.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib/godot_runtime_env.sh"

EXPORT_DIR="${1:-}"
OUT_DIR="${2:-/tmp/spacewheat_export_profiles_$(date +%Y%m%d_%H%M%S)}"
PROFILE_HOME="${PROFILE_HOME:-$OUT_DIR/runtime_home}"
PROFILE_CONFIG_HOME="${PROFILE_CONFIG_HOME:-$OUT_DIR/runtime_config}"
PROFILE_DATA_HOME="${PROFILE_DATA_HOME:-$OUT_DIR/runtime_data}"

# Warmup is generous because it has to cover the whole boot: pck mount, biome
# discovery, first scene build, and — in the loaded scenarios — a full save
# rebuild. Percentiles taken across that would describe loading, not playing.
WARMUP_S="${PROFILE_WARMUP_SECONDS:-20}"
SAMPLE_S="${PROFILE_SAMPLE_SECONDS:-30}"
UNCAP="${PROFILE_UNCAP_FPS:-0}"

if [ -z "$EXPORT_DIR" ]; then
	cat >&2 <<'EOF'
usage: profile-export-runtime.sh <desktop-export-dir> [output-dir]

env:
  PROFILE_WARMUP_SECONDS   boot grace before sampling (default 20)
  PROFILE_SAMPLE_SECONDS   measurement window        (default 30)
  PROFILE_UNCAP_FPS=1      lift vsync/max_fps to see headroom (SW_UNCAP_FPS)
  PROFILE_SCENARIOS        space-separated subset of: title fresh endgame
EOF
	exit 1
fi

# Each scenario is a different amount of game, because SpaceWheat's cost scales
# with how much world is alive — not with which menu is open.
#   title    the title card; the renderer's floor, almost no physics
#   fresh    a new campaign (SW_AUTOSTART); Act-0 load, three biomes
#   endgame  a late-act save (SW_LOAD_PATH); six biomes, the full coupling graph
# The gap between `fresh` and `endgame` is the number that decides whether a
# long game stays playable.
SCENARIOS="${PROFILE_SCENARIOS:-title fresh endgame}"
ENDGAME_SAVE="${PROFILE_ENDGAME_SAVE:-$ROOT_DIR/🍄/🧪/checkpoints/endrun_ending.tres}"

mkdir -p "$OUT_DIR" "$PROFILE_HOME" "$PROFILE_CONFIG_HOME" "$PROFILE_DATA_HOME"
FAILED=()

LINUX_BIN="$EXPORT_DIR/SpaceWheat.x86_64"
WINDOWS_BIN="$EXPORT_DIR/SpaceWheat.exe"
if [ -x "$LINUX_BIN" ]; then
	PLATFORM="linux"; BIN="$LINUX_BIN"
elif [ -f "$WINDOWS_BIN" ]; then
	PLATFORM="windows"; BIN="$WINDOWS_BIN"
else
	echo "missing desktop export executable in: $EXPORT_DIR" >&2
	exit 1
fi

echo "SpaceWheat exported runtime profiler"
echo "export:    $EXPORT_DIR ($PLATFORM)"
echo "output:    $OUT_DIR"
echo "window:    ${WARMUP_S}s warmup + ${SAMPLE_S}s sample"
echo "scenarios: $SCENARIOS"
echo

scenario_env() {
	# Prints `KEY=VALUE` lines for the scenario's extra environment.
	case "$1" in
		title) ;;
		fresh) echo "SW_AUTOSTART=1" ;;
		endgame)
			echo "SW_AUTOSTART=1"
			echo "SW_LOAD_PATH=$ENDGAME_SAVE"
			;;
		*) echo "unknown scenario: $1" >&2; return 1 ;;
	esac
}

run_linux() {
	local json="$1"; shift
	local -a env_pairs=("$@")
	set +e
	env HOME="$PROFILE_HOME" \
		XDG_CONFIG_HOME="$PROFILE_CONFIG_HOME" \
		XDG_DATA_HOME="$PROFILE_DATA_HOME" \
		SW_PERF_LOG="$json" \
		SW_PERF_WARMUP_SECONDS="$WARMUP_S" \
		SW_PERF_SECONDS="$SAMPLE_S" \
		SW_UNCAP_FPS="$UNCAP" \
		SW_DEBUG_READOUT=0 \
		"${env_pairs[@]}" \
		"$BIN"
	local status=$?
	set -e
	return "$status"
}

run_windows() {
	# Start-Process cannot inherit an env assignment made by `env`, and cmd.exe
	# refuses a UNC working directory, so the variables are set on the
	# PowerShell process itself and inherited by the child.
	local json="$1"; shift
	command -v powershell.exe >/dev/null 2>&1 || {
		echo "powershell.exe is required to profile a Windows export from WSL" >&2
		return 1
	}
	local win_exe win_json setters=""
	win_exe="$(sw_wsl_to_windows_path "$BIN")"
	win_json="$(sw_wsl_to_windows_path "$json")"

	setters+="\$env:SW_PERF_LOG='$win_json'; "
	setters+="\$env:SW_PERF_WARMUP_SECONDS='$WARMUP_S'; "
	setters+="\$env:SW_PERF_SECONDS='$SAMPLE_S'; "
	setters+="\$env:SW_UNCAP_FPS='$UNCAP'; "
	setters+="\$env:SW_DEBUG_READOUT='0'; "
	local pair key value
	for pair in "$@"; do
		key="${pair%%=*}"; value="${pair#*=}"
		if [ "$key" = "SW_LOAD_PATH" ]; then
			value="$(sw_wsl_to_windows_path "$value")"
		fi
		setters+="\$env:$key='$value'; "
	done

	set +e
	powershell.exe -NoProfile -NonInteractive -Command \
		"$setters \$p = Start-Process -FilePath '$win_exe' -Wait -PassThru; exit \$p.ExitCode" \
		>/dev/null 2>&1
	local status=$?
	set -e
	return "$status"
}

for scenario in $SCENARIOS; do
	echo "============================================================"
	echo "SCENARIO: $scenario"
	echo "============================================================"
	JSON="$OUT_DIR/${scenario}.json"
	rm -f "$JSON"

	mapfile -t EXTRA < <(scenario_env "$scenario")
	if [ "$scenario" = "endgame" ] && [ ! -f "$ENDGAME_SAVE" ]; then
		echo "skipped — no save at $ENDGAME_SAVE"
		FAILED+=("$scenario:no_save")
		echo
		continue
	fi

	status=0
	if [ "$PLATFORM" = "linux" ]; then
		run_linux "$JSON" "${EXTRA[@]}" || status=$?
	else
		run_windows "$JSON" "${EXTRA[@]}" || status=$?
	fi
	[ "$status" -eq 0 ] || FAILED+=("$scenario:exit$status")

	if [ ! -f "$JSON" ]; then
		echo "no report at $JSON — the build has no PerfSampler (pre-2026-08-12 pack?)"
		FAILED+=("$scenario:no_report")
	else
		python3 - "$JSON" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
s, e = d.get("steady_state", {}), d.get("environment", {})
if not s:
    print("  no steady-state frames sampled"); raise SystemExit
print("  %-22s %s" % ("adapter", e.get("video_adapter") or "(none)"))
print("  %-22s %.1f mean / %.1f p50 / %.1f 1%% low  (%d frames)" % (
    "fps", s["fps_mean"], s["fps_p50"], s["fps_1pct_low"], s["frames"]))
print("  %-22s %.1f p50 / %.1f p95 / %.1f max" % (
    "frame ms", s["frame_ms_p50"], s["frame_ms_p95"], s["frame_ms_max"]))
print("  %-22s %s" % ("trustworthy", d.get("trustworthy")))
for c in d.get("caveats", []):
    print("    ! " + c)
PY
	fi
	echo
done

echo "Reports written to: $OUT_DIR"
if [ "${#FAILED[@]}" -gt 0 ]; then
	echo "Scenarios with problems: ${FAILED[*]}"
	exit 1
fi
