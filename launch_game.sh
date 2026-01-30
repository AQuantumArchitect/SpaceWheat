#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(realpath "$0")")"

# Optional: export any env vars (e.g., for headless testing)
# export GODOT_HEADLESS=1

# Prepare log directory
LOG_DIR="$(pwd)/Tests/logs"
mkdir -p "$LOG_DIR"
# Override VerboseConfig log path so Godot doesn’t try to write to user://
export VERBOSE_LOG_PATH="$LOG_DIR"
# Launch Godot with the project, directing logs to Tests/logs/godot.log
godot --headless --log-file "$LOG_DIR/godot.log" --path . "$@"
