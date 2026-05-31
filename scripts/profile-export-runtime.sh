#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/lib/godot_runtime_env.sh"

EXPORT_DIR="${1:-}"
OUT_DIR="${2:-/tmp/spacewheat_export_profiles_$(date +%Y%m%d_%H%M%S)}"
PROFILE_HOME="${PROFILE_HOME:-$OUT_DIR/runtime_home}"
PROFILE_CONFIG_HOME="${PROFILE_CONFIG_HOME:-$OUT_DIR/runtime_config}"
PROFILE_DATA_HOME="${PROFILE_DATA_HOME:-$OUT_DIR/runtime_data}"
WINDOWS_SMOKE_TIMEOUT_S="${WINDOWS_SMOKE_TIMEOUT_S:-420}"

if [ -z "$EXPORT_DIR" ]; then
	echo "usage: $0 <desktop-export-dir> [output-dir]" >&2
	exit 1
fi

mkdir -p "$OUT_DIR" "$PROFILE_HOME" "$PROFILE_CONFIG_HOME" "$PROFILE_DATA_HOME"
FAILED_MODES=()

MODES=(dormant single dense multi)
RENDERING_DRIVER="${RUNTIME_RENDERING_DRIVER:-}"
RENDERING_METHOD="${RUNTIME_RENDERING_METHOD:-}"
PROFILE_WARMUP_FRAMES="${PROFILE_WARMUP_FRAMES:-90}"
PROFILE_SAMPLE_FRAMES="${PROFILE_SAMPLE_FRAMES:-240}"
PROFILE_DISPLAY_MODE="${PROFILE_DISPLAY_MODE:-auto}"

LINUX_BIN="$EXPORT_DIR/SpaceWheat.x86_64"
WINDOWS_BIN="$EXPORT_DIR/SpaceWheat.exe"
PLATFORM=""
BIN=""

if [ -x "$LINUX_BIN" ]; then
	PLATFORM="linux"
	BIN="$LINUX_BIN"
elif [ -f "$WINDOWS_BIN" ]; then
	PLATFORM="windows"
	BIN="$WINDOWS_BIN"
else
	echo "missing desktop export executable in: $EXPORT_DIR" >&2
	exit 1
fi

echo "SpaceWheat exported runtime profiler"
echo "export: $EXPORT_DIR"
echo "platform: $PLATFORM"
echo "output: $OUT_DIR"
if [ -n "$RENDERING_DRIVER" ]; then
	echo "rendering driver override: $RENDERING_DRIVER"
fi
if [ -n "$RENDERING_METHOD" ]; then
	echo "rendering method override: $RENDERING_METHOD"
fi
echo

resolve_profile_display_mode() {
	local platform="$1"

	case "$PROFILE_DISPLAY_MODE" in
		headed|headless)
			printf '%s\n' "$PROFILE_DISPLAY_MODE"
			return 0
			;;
		auto)
			;;
		*)
			echo "invalid PROFILE_DISPLAY_MODE: $PROFILE_DISPLAY_MODE (use auto, headed, or headless)" >&2
			exit 1
			;;
	esac

	if [ "$platform" = "linux" ]; then
		if [ -n "${DISPLAY:-}" ]; then
			if command -v xdpyinfo >/dev/null 2>&1 && timeout 1s xdpyinfo >/dev/null 2>&1; then
				printf 'headed\n'
				return 0
			fi
			if ! sw_is_wsl; then
				printf 'headed\n'
				return 0
			fi
		fi
		if ! sw_is_wsl && [ -n "${WAYLAND_DISPLAY:-}" ] && [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" ]; then
			printf 'headed\n'
			return 0
		fi
		printf 'headless\n'
		return 0
	fi

	printf 'headed\n'
}

PROFILE_DISPLAY_MODE_RESOLVED="$(resolve_profile_display_mode "$PLATFORM")"
echo "display mode: $PROFILE_DISPLAY_MODE_RESOLVED"

run_linux_mode() {
	local mode="$1"
	local log_path="$2"
	local json_path="$3"
	local cmd=("$BIN")

	if [ "$PROFILE_DISPLAY_MODE_RESOLVED" = "headless" ]; then
		cmd+=(--headless)
	fi
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
		--runtime-profile-warmup="$PROFILE_WARMUP_FRAMES"
		--runtime-profile-frames="$PROFILE_SAMPLE_FRAMES"
	)

	set +e
	HOME="$PROFILE_HOME" \
	XDG_CONFIG_HOME="$PROFILE_CONFIG_HOME" \
	XDG_DATA_HOME="$PROFILE_DATA_HOME" \
	"${cmd[@]}" 2>&1 | tee "$log_path"
	local status=${PIPESTATUS[0]}
	set -e
	return "$status"
}

run_windows_mode() {
	local mode="$1"
	local log_path="$2"
	local json_path="$3"
	local windows_exe windows_log windows_json ps_args ps_cmd

	command -v powershell.exe >/dev/null 2>&1 || {
		echo "powershell.exe is required to profile a Windows export from WSL" >&2
		return 1
	}

	windows_exe="$(sw_wsl_to_windows_path "$BIN")"
	windows_log="$(sw_wsl_to_windows_path "$log_path")"
	windows_json="$(sw_wsl_to_windows_path "$json_path")"

	# Build PS argument array - avoids cmd.exe UNC CWD limitation
	ps_args="'$windows_exe'"
	if [ "$PROFILE_DISPLAY_MODE_RESOLVED" = "headless" ]; then
		ps_args="$ps_args, '--headless'"
	fi
	if [ -n "$RENDERING_DRIVER" ]; then
		ps_args="$ps_args, '--rendering-driver', '$RENDERING_DRIVER'"
	fi
	if [ -n "$RENDERING_METHOD" ]; then
		ps_args="$ps_args, '--rendering-method', '$RENDERING_METHOD'"
	fi
	ps_args="$ps_args, '--', '--runtime-profile-mode=$mode', '--runtime-profile-output=$windows_json', '--runtime-profile-warmup=$PROFILE_WARMUP_FRAMES', '--runtime-profile-frames=$PROFILE_SAMPLE_FRAMES'"

	ps_cmd="\$p = Start-Process -FilePath $ps_args -Wait -PassThru -RedirectStandardOutput '$windows_log' -RedirectStandardError '$windows_log'; exit \$p.ExitCode"

	set +e
	powershell.exe -NoProfile -NonInteractive -Command "$ps_cmd" >/dev/null 2>&1
	local status=$?
	set -e

	if [ -f "$log_path" ]; then
		cat "$log_path"
	fi
	return "$status"
}

for mode in "${MODES[@]}"; do
	echo "============================================================"
	echo "EXPORT PROFILE MODE: $mode"
	echo "============================================================"
	LOG_PATH="$OUT_DIR/${mode}.log"
	JSON_PATH="$OUT_DIR/${mode}.json"

	if [ "$PLATFORM" = "linux" ]; then
		run_linux_mode "$mode" "$LOG_PATH" "$JSON_PATH"
		status=$?
	else
		run_windows_mode "$mode" "$LOG_PATH" "$JSON_PATH"
		status=$?
	fi

	if [ "$status" -ne 0 ]; then
		echo "warning: mode '$mode' exited with status $status" | tee -a "$LOG_PATH"
		FAILED_MODES+=("$mode:$status")
	fi
	if [ ! -f "$JSON_PATH" ]; then
		echo "warning: mode '$mode' did not produce $JSON_PATH" | tee -a "$LOG_PATH"
		FAILED_MODES+=("$mode:no_json")
	fi
	echo
done

echo "Profiles written to: $OUT_DIR"
if [ "${#FAILED_MODES[@]}" -gt 0 ]; then
	echo "Profile modes with non-zero exit: ${FAILED_MODES[*]}"
	exit 1
fi
