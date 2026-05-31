#!/usr/bin/env bash

# Shared helpers for deciding when native build artifacts are stale.

sw_latest_mtime_for_paths() {
  local latest=0
  local path file mtime

  for path in "$@"; do
    if [ -d "$path" ]; then
      while IFS= read -r -d '' file; do
        mtime="$(stat -c '%Y' "$file" 2>/dev/null || printf '0')"
        if [ "$mtime" -gt "$latest" ]; then
          latest="$mtime"
        fi
      done < <(find "$path" -type f -print0)
    elif [ -f "$path" ]; then
      mtime="$(stat -c '%Y' "$path" 2>/dev/null || printf '0')"
      if [ "$mtime" -gt "$latest" ]; then
        latest="$mtime"
      fi
    fi
  done

  printf '%s\n' "$latest"
}

sw_output_is_stale() {
  local output="$1"
  shift

  if [ ! -e "$output" ]; then
    return 0
  fi

  local output_mtime input_mtime
  output_mtime="$(stat -c '%Y' "$output" 2>/dev/null || printf '0')"
  input_mtime="$(sw_latest_mtime_for_paths "$@")"

  [ "$input_mtime" -gt "$output_mtime" ]
}

