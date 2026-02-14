#!/bin/bash
set -euo pipefail

PROJECT_ROOT="/home/tehcr33d/ws/SpaceWheat"
cd "$PROJECT_ROOT"

LOG_DIR="$PROJECT_ROOT/logs/quest_overlay"
TEST_LOG_DIR="$PROJECT_ROOT/Tests/logs"
mkdir -p "$LOG_DIR" "$TEST_LOG_DIR"
STAMP="$(date +"%Y%m%d_%H%M%S")"
OUT_LOG="$LOG_DIR/quest_overlay_probe_graphical_${STAMP}.log"

export VERBOSE_LOG_PATH="$TEST_LOG_DIR"

{
  echo "[RUN] Quest overlay probe (graphical)"
  echo "[RUN] started=$(date -Is)"
  echo "[RUN] command=timeout 120 godot --log-file $TEST_LOG_DIR/godot.log --path . --script Tests/test_quest_overlay_probe.gd"
  timeout 120 godot --log-file "$TEST_LOG_DIR/godot.log" --path . --script Tests/test_quest_overlay_probe.gd
  echo "[RUN] exit=0"
} 2>&1 | tee "$OUT_LOG"

echo "[RUN] log_file=$OUT_LOG"
