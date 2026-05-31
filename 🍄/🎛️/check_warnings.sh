#!/usr/bin/env bash
# Dump ranked GDScript warnings using gdlint (static) + Godot headless (runtime).
# Usage: ./check_warnings.sh [--gdlint | --godot | --count]
#   --gdlint  static analysis only (fast, no Godot needed)
#   --godot   headless runtime only (catches runtime parse errors)
#   --count   print total count only
# Default: gdlint only

cd /home/primearchitect/ws/SpaceWheat
VENV=".venv/bin/gdlint"

case "$1" in
  --godot)
    godot --headless --quit 2>&1 \
      | grep -oE "SHADOWED_[A-Z_]+|CONFUSABLE_[A-Z_]+|UNUSED_[A-Z_]+|RETURN_VALUE_DISCARDED" \
      | sort | uniq -c | sort -rn
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
