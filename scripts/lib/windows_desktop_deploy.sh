#!/usr/bin/env bash

# Shared helpers for staging and deploying Windows desktop exports.

sw_is_wsl() {
  grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null
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

sw_windows_fs_available() {
  [ -d /mnt/c ]
}

sw_windows_stage_root() {
  printf '%s\n' "${WINDOWS_STAGE_ROOT:-/mnt/c/Games/SpaceWheat Builds}"
}

sw_windows_player_root() {
  printf '%s\n' "${WINDOWS_PLAYER_ROOT:-/mnt/c/Games/🌾🚀🌌SpaceWheat}"
}

sw_windows_can_use_cmd() {
  sw_is_wsl && command -v cmd.exe >/dev/null 2>&1
}

sw_windows_write_launcher() {
  local target_root="$1"

  cat > "$target_root/launch.bat" <<'EOF'
@echo off
setlocal
cd /d "%~dp0"
start "" "%~dp0SpaceWheat.exe"
EOF
}

sw_windows_copy_file_via_windows() {
  local source_file="$1"
  local target_file="$2"
  local rc

  cmd.exe /C "copy /Y $source_file $target_file"
  rc=$?
  case "$rc" in
    0|1)
      return 0
      ;;
    *)
      return "$rc"
      ;;
  esac
}

sw_windows_deploy_tree() {
  local source_root="$1"
  local target_root="$2"
  local create_launcher="${3:-0}"

  [ -d "$source_root" ] || {
    printf 'Missing Windows export folder: %s\n' "$source_root" >&2
    return 1
  }

  [ -f "$source_root/SpaceWheat.exe" ] || {
    printf 'Missing Windows exe in source: %s/SpaceWheat.exe\n' "$source_root" >&2
    return 1
  }

  [ -f "$source_root/libquantummatrix.windows.template_release.x86_64.dll" ] || {
    printf 'Missing Windows native DLL in source: %s\n' "$source_root" >&2
    return 1
  }

  [ -d /mnt/c ] || {
    printf '/mnt/c is not available; cannot write to the Windows filesystem.\n' >&2
    return 1
  }

  if sw_windows_can_use_cmd; then
    local source_win target_win

    source_win="$(sw_wsl_to_windows_path "$source_root")"
    target_win="$(sw_wsl_to_windows_path "$target_root")"

    cmd.exe /C "if not exist \"$target_win\" mkdir \"$target_win\""

    sw_windows_copy_file_via_windows \
      "${source_win}\\SpaceWheat.exe" \
      "${target_win}\\SpaceWheat.exe" || return $?

    sw_windows_copy_file_via_windows \
      "${source_win}\\libquantummatrix.windows.template_release.x86_64.dll" \
      "${target_win}\\libquantummatrix.windows.template_release.x86_64.dll" || return $?
  else
    rm -rf "$target_root"
    mkdir -p "$target_root"
    cp -f "$source_root"/* "$target_root/"
    if [ "$create_launcher" = "1" ]; then
      sw_windows_write_launcher "$target_root"
    fi
  fi

}
