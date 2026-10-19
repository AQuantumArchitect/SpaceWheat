#!/usr/bin/env bash

# Shared helpers for staging and deploying Windows desktop exports.
# sw_is_wsl / sw_wsl_to_windows_path are defined once in godot_runtime_env.sh — source
# that rather than duplicating them here.
. "${BASH_SOURCE%/*}/godot_runtime_env.sh"

# True on WSL (/mnt/c mounted) — or when WINDOWS_ROOT points somewhere real
# (tests and dry runs deploy into a scratch folder).
sw_windows_fs_available() {
  [ -d /mnt/c ] || { [ -n "${WINDOWS_ROOT:-}" ] && [ -d "$(dirname "$WINDOWS_ROOT")" ]; }
}

# ── The ONE Windows layout (2026-10-18). Every Windows path any script uses is
# derived here; tests/test_windows_paths_single_source.py fails if a script
# spells a /mnt/c/Games path anywhere else.
#
#   C:\Games\SpaceWheat\                  the play folder: exe, DLL, launch/reset/saves
#                                         .bat, README.txt, VERSION.txt
#   C:\Games\SpaceWheat\releases\vX.Y.Z\  archived packages + RELEASE manifest + SHA256,
#                                         written by release.sh, newest 3 kept
#   C:\Games\SpaceWheat\profiling-kit\    staged by stage-profiling-kit.sh
#
# No emoji in the path (bots and tools kept forking a plain-ASCII copy) and no
# separate "staging" folder (it was always a byte copy of the play folder).
sw_windows_root() {
  printf '%s\n' "${WINDOWS_ROOT:-/mnt/c/Games/SpaceWheat}"
}

sw_windows_player_root() {
  printf '%s\n' "${WINDOWS_PLAYER_ROOT:-$(sw_windows_root)}"
}

sw_windows_releases_root() {
  printf '%s\n' "${WINDOWS_RELEASES_ROOT:-$(sw_windows_root)/releases}"
}

sw_windows_profiling_root() {
  printf '%s\n' "${WINDOWS_PROFILING_ROOT:-$(sw_windows_root)/profiling-kit}"
}

# How many archived versions releases/ keeps (GitHub Releases is the permanent record).
SW_WINDOWS_KEEP_RELEASES="${SW_WINDOWS_KEEP_RELEASES:-3}"

sw_windows_can_use_cmd() {
  sw_is_wsl && command -v cmd.exe >/dev/null 2>&1
}

sw_windows_write_launcher() {
  local target_root="$1"
  local version_line="${2:-}"

  if [ -n "$version_line" ]; then
    printf '%s\r\n' "$version_line" > "$target_root/VERSION.txt"
  fi

  cat > "$target_root/saves.bat" <<'EOF'
@echo off
explorer "%APPDATA%\Godot\app_userdata\SpaceWheat - Quantum Farm\saves"
EOF

  cat > "$target_root/README.txt" <<'EOF'
SpaceWheat play folder  (C:\Games\SpaceWheat)
=============================================

Launch:   launch.bat
Reset:    reset.bat     wipes saves + autosaves + tutorial flag
Saves:    saves.bat     opens the real save folder in Explorer
Version:  VERSION.txt   the build this folder holds

Saves are NOT in this folder:
  %APPDATA%\Godot\app_userdata\SpaceWheat - Quantum Farm\saves

releases\       archived packages of the last few versions (zip + RELEASE + SHA256)
profiling-kit\  the Windows-native profiling lane, when staged

Everything here is written by the repo's scripts
(scripts/lib/windows_desktop_deploy.sh). Do not copy builds into other
folders under C:\Games.
EOF

  cat > "$target_root/launch.bat" <<'EOF'
@echo off
setlocal
cd /d "%~dp0"
start "" "%~dp0SpaceWheat.exe"
EOF

  # Playtest reset: Godot keeps user:// under AppData, NOT next to the exe.
  # Wiping only this folder left tutorial_seen / hats / the gold banner alive.
  cat > "$target_root/reset.bat" <<'EOF'
@echo off
setlocal
title SpaceWheat - reset play state
echo.
echo  This wipes saves, autosaves, and the tutorial flag so the next
echo  launch is a fresh Demos (welcome + locked chrome).
echo  Settings and logs stay.
echo.
set USERDIR=%APPDATA%\Godot\app_userdata\SpaceWheat - Quantum Farm
echo  user:// = %USERDIR%
echo.
taskkill /IM SpaceWheat.exe /F >nul 2>&1
if exist "%USERDIR%\saves" (
  rmdir /s /q "%USERDIR%\saves"
  echo  wiped saves\
)
if exist "%USERDIR%\fractal_atlas.json" del /f /q "%USERDIR%\fractal_atlas.json"
if exist "%USERDIR%\operator_cache" rmdir /s /q "%USERDIR%\operator_cache"
if not exist "%USERDIR%\saves" mkdir "%USERDIR%\saves"
echo.
echo  Reset complete. Run launch.bat for a new game.
echo.
pause
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

  sw_windows_fs_available || {
    printf '/mnt/c is not available; cannot write to the Windows filesystem.\n' >&2
    return 1
  }

  # cmd.exe copy only works when the SOURCE is on a Windows-visible drive (/mnt/*).
  # A WSL-home source resolves to a \\wsl.localhost\... UNC path that cmd.exe cannot
  # read ("UNC paths are not supported") — in that case fall through to the cp path,
  # which copies WSL → /mnt/c fine and also writes the launcher.
  local source_is_winfs=0
  case "$source_root" in /mnt/*) source_is_winfs=1 ;; esac

  if sw_windows_can_use_cmd && [ "$source_is_winfs" = "1" ]; then
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

    if [ "$create_launcher" = "1" ]; then
      sw_windows_write_launcher "$target_root" "${SW_DEPLOY_VERSION_LINE:-}"
    fi
  else
    # Never wipe the target: the play folder also holds releases/ and
    # profiling-kit/. Replace exactly the two build files.
    mkdir -p "$target_root"
    cp -f "$source_root/SpaceWheat.exe" \
          "$source_root/libquantummatrix.windows.template_release.x86_64.dll" \
          "$target_root/"
    if [ "$create_launcher" = "1" ]; then
      sw_windows_write_launcher "$target_root" "${SW_DEPLOY_VERSION_LINE:-}"
    fi
  fi

}


# Archive one version's packages into releases/v<version>/ (archives + the
# release manifest + SHA256), then keep only the newest SW_WINDOWS_KEEP_RELEASES.
# Usage: sw_windows_archive_release <version> <package_root>
sw_windows_archive_release() {
  local version="$1"
  local package_root="$2"
  local releases dest
  releases="$(sw_windows_releases_root)"
  dest="$releases/v${version}"

  sw_windows_fs_available || { printf 'no /mnt/c; skipping the Windows archive\n' >&2; return 0; }
  mkdir -p "$dest"
  local f copied=0
  for f in "$package_root"/spacewheat-*-"${version}"*.zip \
           "$package_root"/spacewheat-*-"${version}"*.tar.gz \
           "$package_root"/RELEASE-"${version}"*.md; do
    [ -f "$f" ] || continue
    cp -f "$f" "$dest/"
    copied=$((copied + 1))
  done
  [ "$copied" -gt 0 ] || { printf 'no packages for %s in %s\n' "$version" "$package_root" >&2; return 1; }
  ( cd "$dest" && sha256sum spacewheat-* > SHA256 )

  # Prune: the newest N version folders (by mtime) survive.
  local keep="$SW_WINDOWS_KEEP_RELEASES" n=0 d
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    n=$((n + 1))
    if [ "$n" -gt "$keep" ]; then
      rm -rf -- "$d"
    fi
  done < <(ls -1dt "$releases"/v*/ 2>/dev/null)
}
