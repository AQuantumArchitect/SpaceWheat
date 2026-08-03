#!/usr/bin/env bash
# cognifold-bar.sh — point the cognifold instrument at the BAR quantum brains.
#
# The Verdance's Ashes campaign AI runs a dual umwelt manifold (6 proxy mood axes + 8
# campaign design axes) that until 2026-08-03 had no field rendering anywhere.
# verdance_cognifold_bridge.py (lives WITH the BAR tooling, per its workspace's own
# single-source-of-truth rule) re-reads outbox/manifold_gym.latest.json and republishes it
# as cognifold_trace_v1 — this script starts it, points SW_COGNIFOLD_URL at it, and opens
# the same standalone instrument scene scripts/cognifold.sh and cognifold-meerkat.sh use.
# Read-only: the bridge never writes to the workspace.
#
#   scripts/cognifold-bar.sh
#   VERDANCE_WORKSPACE=/path/to/BAR_Verdance_Workspace scripts/cognifold-bar.sh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
SCENE="scenes/CognifoldTraceView.tscn"
WORKSPACE="${VERDANCE_WORKSPACE:-/mnt/c/Users/Luke Spooner/Documents/BAR_Verdance_Workspace}"
BRIDGE="$WORKSPACE/tools/quantum_bar_ai/verdance_cognifold_bridge.py"
PORT="${VERDANCE_BRIDGE_PORT:-8098}"

echo "[cognifold-bar] workspace: $WORKSPACE  bridge :$PORT" >&2
VERDANCE_WORKSPACE="$WORKSPACE" python3 "$BRIDGE" &
bridge_pid=$!
trap 'kill "$bridge_pid" 2>/dev/null || true' EXIT

# Give the bridge a moment to take its first poll before the instrument's first request.
sleep 1.5

cd "$PROJECT_DIR"
SW_COGNIFOLD_URL="http://127.0.0.1:$PORT/cognifold" "$GODOT_BIN" "$SCENE" "$@"
