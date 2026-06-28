#!/usr/bin/env bash
# Dump ranked warnings: gdlint (static style), Godot boot, or a real GAMEPLAY drive.
#
# Usage: ./check_warnings.sh [MODE]
#   --gdlint            static lint only (fast, no Godot)          [default]
#   --count             total gdlint problem count only
#   --boot              headless boot; tally ALL WARNING:/ERROR: by source
#   --runtime           headless GAMEPLAY drive (exercises logic; viz skipped)
#   --runtime-headed    headed GAMEPLAY drive (renders the viz stack — the real player path)
#
# --runtime / --runtime-headed are the ones that match what a human sees running `godot`:
# they grep for every WARNING:/ERROR:/SCRIPT ERROR (not 3 hand-picked patterns) over an
# actual play session, and rank them by the `at:` source line so each is traceable.

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VENV=".venv/bin/gdlint"
PROJECT_ROOT="$PWD"

# Tally every native WARNING:/ERROR:/SCRIPT ERROR in a log, then rank by source location.
# Godot prints the message then an indented "     at: func (file.cpp:NN)" line — we pair
# each warning/error with the source that follows it.
tally_warnings() {
  local log="$1"
  echo "=== severity histogram ==="
  grep -oE "^(WARNING|ERROR|SCRIPT ERROR|USER WARNING|USER ERROR):" "$log" 2>/dev/null \
    | sort | uniq -c | sort -rn
  echo
  echo "=== distinct messages (ranked by count) ==="
  grep -E "^(WARNING|ERROR|SCRIPT ERROR|USER WARNING|USER ERROR):" "$log" 2>/dev/null \
    | sed -E 's/[0-9]+/N/g' | sort | uniq -c | sort -rn | head -40
  echo
  echo "=== source locations (at:) ==="
  grep -E "^\s+at: " "$log" 2>/dev/null \
    | sed -E 's/^\s+at: //; s/:[0-9]+\)/)/' | sort | uniq -c | sort -rn | head -40
  echo
  local total
  total=$(grep -cE "^(WARNING|ERROR|SCRIPT ERROR|USER WARNING|USER ERROR):" "$log" 2>/dev/null)
  echo "TOTAL native warnings/errors: ${total:-0}"
  echo "Full log: $log"
}

case "$1" in
  --godot)  # legacy alias: lint-code tally from a quick boot
    godot --headless --quit 2>&1 \
      | grep -oE "SHADOWED_[A-Z_]+|CONFUSABLE_[A-Z_]+|UNUSED_[A-Z_]+|RETURN_VALUE_DISCARDED" \
      | sort | uniq -c | sort -rn
    ;;

  --boot)
    LOG="${WARN_LOG:-/tmp/sw_boot_warnings.txt}"
    echo "Booting headless (full output → $LOG) ..."
    godot --headless --audio-driver Dummy --path "$PROJECT_ROOT" --quit > "$LOG" 2>&1
    tally_warnings "$LOG"
    ;;

  --runtime|--runtime-headed)
    LOG="${WARN_LOG:-/tmp/sw_runtime_warnings.txt}"
    HEADED=""
    [ "$1" = "--runtime-headed" ] && HEADED="--headed"
    echo "Driving GAMEPLAY (${1#--}) — listener log → $LOG ..."
    : > "$LOG"  # truncate (start_listener opens in append mode)
    # The driver starts the listener with its stderr pointed at $LOG, drives the visual
    # sweep, then stops. RIG_DISABLE_LOOKAHEAD=0 inside the driver runs the live C++ engine.
    if [ -n "$HEADED" ]; then
      DISPLAY="${DISPLAY:-:0}" python3 "🍄/🧪/warnings_drive.py" $HEADED --log "$LOG" || true
    else
      python3 "🍄/🧪/warnings_drive.py" --log "$LOG" || true
    fi
    echo
    tally_warnings "$LOG"
    ;;

  --count)
    find . -name "*.gd" -not -path "./.venv/*" -not -path "./.godot/*" \
      | xargs "$VENV" 2>&1 | grep -c "^.*\.gd"
    ;;

  *)
    find . -name "*.gd" -not -path "./.venv/*" -not -path "./.godot/*" \
      | xargs "$VENV" 2>&1
    ;;
esac
