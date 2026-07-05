#!/usr/bin/env bash

# Shared runtime environment bootstrap for SpaceWheat Godot launches.
# Keeps launch behavior consistent across local dev and test scripts.

sw_is_wsl() {
  grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null
}

sw_godot_bin() {
  printf '%s\n' "${SW_GODOT_BIN:-${GODOT_BIN:-godot}}"
}

sw_is_windows_godot_target() {
  local bin
  bin="$(sw_godot_bin)"
  case "$bin" in
    *.exe|*.EXE) return 0 ;;
    /mnt/[a-zA-Z]/*) return 0 ;;
    \\\\wsl.localhost\\*|[a-zA-Z]:\\*) return 0 ;;
    *) return 1 ;;
  esac
}

sw_wsl_to_windows_path() {
  local path="$1"
  local distro="${WSL_DISTRO_NAME:-Ubuntu}"
  local drive tail

  case "$path" in
    /mnt/[a-zA-Z]/*)
      drive="${path:5:1}"
      tail="${path:7}"
      tail="${tail//\//\\}"
      printf '%s\n' "${drive^^}:\\${tail}"
      ;;
    /*)
      tail="${path//\//\\}"
      printf '%s\n' "\\\\wsl.localhost\\${distro}${tail}"
      ;;
    *)
      printf '%s\n' "$path"
      ;;
  esac
}

sw_should_convert_arg_key() {
  case "$1" in
    --path|--script|--editor-settings-path|--runtime-profile-output|--summary-path|--output|--output-dir|--out-dir|--log-file)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

sw_convert_arg_value_if_needed() {
  local key="$1"
  local value="$2"

  if sw_is_wsl && sw_is_windows_godot_target && sw_should_convert_arg_key "$key"; then
    case "$value" in
      /*)
        sw_wsl_to_windows_path "$value"
        return 0
        ;;
    esac
  fi

  printf '%s\n' "$value"
}

sw_rewrite_godot_args_for_target() {
  local rewritten=()
  local arg key value

  while [ "$#" -gt 0 ]; do
    arg="$1"
    shift

    case "$arg" in
      --path|--script|--editor-settings-path|--runtime-profile-output|--summary-path|--output|--output-dir|--out-dir|--log-file)
        if [ "$#" -gt 0 ]; then
          value="$(sw_convert_arg_value_if_needed "$arg" "$1")"
          rewritten+=("$arg" "$value")
          shift
        else
          rewritten+=("$arg")
        fi
        ;;
      --*=*)
        key="${arg%%=*}"
        value="${arg#*=}"
        if sw_should_convert_arg_key "$key"; then
          value="$(sw_convert_arg_value_if_needed "$key" "$value")"
          rewritten+=("${key}=${value}")
        else
          rewritten+=("$arg")
        fi
        ;;
      *)
        rewritten+=("$arg")
        ;;
    esac
  done

  printf '%s\0' "${rewritten[@]}"
}

sw_configure_wsl_display() {
  local runtime_dir="/run/user/$(id -u)"

  if [ -d "$runtime_dir" ] && [ -S "$runtime_dir/wayland-0" ]; then
    export XDG_RUNTIME_DIR="$runtime_dir"
  elif [ -d "/mnt/wslg/runtime-dir" ]; then
    export XDG_RUNTIME_DIR="/mnt/wslg/runtime-dir"
  fi
  : "${WAYLAND_DISPLAY:=wayland-0}"
  export WAYLAND_DISPLAY

  # Prefer native Wayland on WSLg by default, but preserve any pre-existing
  # X11 DISPLAY so Xvfb and explicit X11 sessions can flow through.
  if [ "${SW_FORCE_X11:-0}" = "1" ]; then
    : "${DISPLAY:=:0}"
    export DISPLAY
  elif [ -n "${DISPLAY:-}" ]; then
    export DISPLAY
  else
    unset DISPLAY
  fi
}

sw_configure_wsl_gpu() {
  export GALLIUM_DRIVER="${GALLIUM_DRIVER:-d3d12}"
  export MESA_D3D12_DEFAULT_ADAPTER_NAME="${MESA_D3D12_DEFAULT_ADAPTER_NAME:-AUTO}"
  unset LIBGL_ALWAYS_SOFTWARE

  # Let callers opt into zink or another loader override without hard-coding it
  # into every launcher.
  if [ -n "${SW_WSL_MESA_DRIVER_OVERRIDE:-}" ] && [ -z "${MESA_LOADER_DRIVER_OVERRIDE:-}" ]; then
    export MESA_LOADER_DRIVER_OVERRIDE="${SW_WSL_MESA_DRIVER_OVERRIDE}"
  fi
}

sw_detect_audio_driver() {
  local mode="${1:-interactive}"
  local pulse_candidate=""
  local pulse_socket=""
  SW_GODOT_AUDIO_DRIVER=""

  if [ -n "${SW_FORCE_AUDIO_DRIVER:-}" ]; then
    SW_GODOT_AUDIO_DRIVER="${SW_FORCE_AUDIO_DRIVER}"
    return 0
  fi

  # Headless test/automation should stay deterministic and silent.
  if [ "${mode}" = "headless" ]; then
    SW_GODOT_AUDIO_DRIVER="Dummy"
    return 0
  fi

  # Try PulseAudio on WSLg first. Do not require pactl to be installed:
  # the socket itself is enough to make a real launch attempt, and raw WSL
  # shells often lack pactl even when PulseServer is available.
  if [ -S "/mnt/wslg/PulseServer" ]; then
    pulse_socket="/mnt/wslg/PulseServer"
  elif [ -n "${PULSE_SERVER:-}" ]; then
    pulse_candidate="${PULSE_SERVER}"
  fi

  if [ -n "${pulse_socket}" ]; then
    pulse_candidate="unix:${pulse_socket}"
    if [ -n "${SW_ASSUME_WSLG_PULSE:-}" ] && [ "${SW_ASSUME_WSLG_PULSE}" = "1" ]; then
      export PULSE_SERVER="${pulse_candidate}"
      SW_GODOT_AUDIO_DRIVER="PulseAudio"
      return 0
    fi
  fi

  if [ -n "${pulse_candidate}" ] && command -v pactl >/dev/null 2>&1; then
    if timeout 1s pactl -s "${pulse_candidate}" info >/dev/null 2>&1; then
      # Server is up — but WSLg's RDP sink may still be disconnected (no output
      # device).  Count RUNNING/IDLE sinks; SUSPENDED-only means no audio path.
      local active_sinks
      active_sinks=$(timeout 1s pactl -s "${pulse_candidate}" list sinks short 2>/dev/null \
        | grep -cE "(RUNNING|IDLE)") || active_sinks=0
      if [ "${active_sinks}" -gt 0 ]; then
        export PULSE_SERVER="${pulse_candidate}"
        SW_GODOT_AUDIO_DRIVER="PulseAudio"
        return 0
      else
        echo "[launch] WSLg PulseAudio server up but RDP sink disconnected (no active sinks); using Dummy audio" >&2
        echo "[launch] To restore audio: run 'wsl --shutdown' from PowerShell, then reopen WSL" >&2
      fi
    fi
  elif [ -n "${pulse_socket}" ]; then
    echo "[launch] WSLg Pulse socket present but pactl not installed; using Dummy audio" >&2
    echo "[launch] For audio: sudo apt install pulseaudio-utils" >&2
  fi

  # No reliable audio backend found in this shell: fail safe to dummy.
  SW_GODOT_AUDIO_DRIVER="Dummy"
}

sw_prepare_runtime_env() {
  local mode="${1:-interactive}"

  if sw_is_wsl; then
    sw_configure_wsl_display
    # Keep GPU path enabled for both GUI/editor unless caller already overrides.
    if [ "${mode}" != "headless" ]; then
      sw_configure_wsl_gpu
    fi
  fi

  sw_detect_audio_driver "${mode}"
  export SW_GODOT_AUDIO_DRIVER

  if [ "${SW_PRINT_AUDIO_CHOICE:-1}" = "1" ]; then
    echo "[launch] Godot audio driver: ${SW_GODOT_AUDIO_DRIVER}"
  fi
}

sw_godot() {
  local raw_args=("$@")
  local args=()
  local has_audio_arg=0
  local arg

  while IFS= read -r -d '' arg; do
    args+=("$arg")
  done < <(sw_rewrite_godot_args_for_target "${raw_args[@]}")

  for arg in "${args[@]}"; do
    if [ "${arg}" = "--audio-driver" ]; then
      has_audio_arg=1
      break
    fi
  done

  # SW_GODOT_EXEC=1: replace the shell with godot instead of spawning a child.
  # Launchers whose last act is running godot (🟢.sh) set this so that killing
  # the launcher kills godot — a terminated shell otherwise ORPHANS its godot
  # child, and orphaned rig listeners run full physics forever (real incident:
  # leaked pytest listeners saturating the disk until reboot).
  if [ "${has_audio_arg}" -eq 0 ]; then
    if [ "${SW_GODOT_EXEC:-0}" = "1" ]; then
      exec "$(sw_godot_bin)" --audio-driver "${SW_GODOT_AUDIO_DRIVER:-Dummy}" "${args[@]}"
    fi
    command "$(sw_godot_bin)" --audio-driver "${SW_GODOT_AUDIO_DRIVER:-Dummy}" "${args[@]}"
  else
    if [ "${SW_GODOT_EXEC:-0}" = "1" ]; then
      exec "$(sw_godot_bin)" "${args[@]}"
    fi
    command "$(sw_godot_bin)" "${args[@]}"
  fi
}


# Write the canonical WSL-aware Linux launcher into an export dir. Single source for
# both build-desktop-local.sh and build-linux-release.sh (the launcher was duplicated,
# and the release copy was a brittle one-liner with no WSL display/audio handling).
sw_write_linux_launcher() {
  local out_dir="$1"
  local exe="${2:-SpaceWheat.x86_64}"
  cat > "${out_dir}/launch.sh" <<LAUNCH
#!/usr/bin/env bash
set -euo pipefail
cd "\$(dirname "\$0")"

if grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; then
    runtime_dir="/run/user/\$(id -u)"
    if [ -d "\$runtime_dir" ] && [ -S "\$runtime_dir/wayland-0" ]; then
        export XDG_RUNTIME_DIR="\$runtime_dir"
    elif [ -d "/mnt/wslg/runtime-dir" ]; then
        export XDG_RUNTIME_DIR="/mnt/wslg/runtime-dir"
    fi
    : "\${WAYLAND_DISPLAY:=wayland-0}"
    export WAYLAND_DISPLAY
    if [ "\${SW_FORCE_X11:-0}" = "1" ]; then
        : "\${DISPLAY:=:0}"; export DISPLAY
    elif [ -n "\${DISPLAY:-}" ]; then
        export DISPLAY
    else
        unset DISPLAY
    fi
    audio_driver="\${SW_FORCE_AUDIO_DRIVER:-}"
    if [ -z "\$audio_driver" ] && [ -S "/mnt/wslg/PulseServer" ] && command -v pactl >/dev/null 2>&1; then
        if timeout 1s pactl -s "unix:/mnt/wslg/PulseServer" info >/dev/null 2>&1; then
            export PULSE_SERVER="unix:/mnt/wslg/PulseServer"
            audio_driver="PulseAudio"
        fi
    fi
    [ -z "\$audio_driver" ] && audio_driver="Dummy"
    exec ./${exe} --audio-driver "\$audio_driver" "\$@"
fi

exec ./${exe} "\$@"
LAUNCH
  chmod +x "${out_dir}/launch.sh"
}
