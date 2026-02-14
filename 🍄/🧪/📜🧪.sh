#!/bin/bash
set -euo pipefail

PROJECT_ROOT="/home/tehcr33d/ws/SpaceWheat"
cd "$PROJECT_ROOT"

LOG_DIR="$PROJECT_ROOT/logs/quest_overlay"
mkdir -p "$LOG_DIR"
STAMP="$(date +"%Y%m%d_%H%M%S")"
OUT_LOG="$LOG_DIR/quest_overlay_probe_${STAMP}.log"

{
  echo "[RUN] Quest overlay probe"
  echo "[RUN] started=$(date -Is)"
  echo "[RUN] command=timeout 90 bash launch_game.sh --script Tests/test_quest_overlay_probe.gd"
  timeout 90 bash launch_game.sh --script Tests/test_quest_overlay_probe.gd
  echo "[RUN] exit=0"
} 2>&1 | tee "$OUT_LOG"

echo "[RUN] log_file=$OUT_LOG"
