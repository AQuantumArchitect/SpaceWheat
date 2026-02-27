#!/usr/bin/env bash

# Shared runtime environment bootstrap for SpaceWheat Godot launches.
# Keeps launch behavior consistent across local dev and test scripts.

sw_is_wsl() {
  grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null
}

sw_configure_wsl_display() {
  if [ -d "/mnt/wslg/runtime-dir" ]; then
    export XDG_RUNTIME_DIR="/mnt/wslg/runtime-dir"
  fi
  : "${WAYLAND_DISPLAY:=wayland-0}"
  : "${DISPLAY:=:0}"
  export WAYLAND_DISPLAY
  export DISPLAY
}

sw_configure_wsl_gpu() {
  export GALLIUM_DRIVER="${GALLIUM_DRIVER:-d3d12}"
  export MESA_D3D12_DEFAULT_ADAPTER_NAME="${MESA_D3D12_DEFAULT_ADAPTER_NAME:-Intel}"
  unset LIBGL_ALWAYS_SOFTWARE
  unset MESA_LOADER_DRIVER_OVERRIDE
}

sw_detect_audio_driver() {
  local mode="${1:-interactive}"
  local pulse_candidate=""
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

  # Try PulseAudio only if it is immediately reachable.
  if [ -S "/mnt/wslg/PulseServer" ]; then
    pulse_candidate="unix:/mnt/wslg/PulseServer"
  elif [ -n "${PULSE_SERVER:-}" ]; then
    pulse_candidate="${PULSE_SERVER}"
  fi

  if [ -n "${pulse_candidate}" ] && command -v pactl >/dev/null 2>&1; then
    if timeout 1s pactl -s "${pulse_candidate}" info >/dev/null 2>&1; then
      export PULSE_SERVER="${pulse_candidate}"
      SW_GODOT_AUDIO_DRIVER="PulseAudio"
      return 0
    fi
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
  local args=("$@")
  local has_audio_arg=0
  local arg
  for arg in "${args[@]}"; do
    if [ "${arg}" = "--audio-driver" ]; then
      has_audio_arg=1
      break
    fi
  done

  if [ "${has_audio_arg}" -eq 0 ]; then
    command godot --audio-driver "${SW_GODOT_AUDIO_DRIVER:-Dummy}" "${args[@]}"
  else
    command godot "${args[@]}"
  fi
}
