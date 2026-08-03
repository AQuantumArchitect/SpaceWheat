#!/usr/bin/env bash
# cognifold-meerkat.sh — point the cognifold instrument at the real house.
#
# Meerkat (../Meerkat-dev) is Luke's deployed home-automation quantum reservoir. It already
# produces exactly the two channels the cognifold renderer draws (Berry phase, surprise), just
# shaped as an event/ticker API rather than cognifold_trace_v1. 🍄/🧪/meerkat_cognifold_bridge.py
# is the translator — this script starts it, points SW_COGNIFOLD_URL at it, and opens the same
# standalone instrument scene scripts/cognifold.sh uses. Zero changes to Meerkat's own codebase;
# read-only GETs only.
#
#   scripts/cognifold-meerkat.sh                 # MEERKAT_URL defaults to local dev (:8080)
#   MEERKAT_URL=http://<rdk-tailscale-host>:8080 scripts/cognifold-meerkat.sh   # the real house
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
SCENE="scenes/CognifoldTraceView.tscn"
BRIDGE="$PROJECT_DIR/🍄/🧪/meerkat_cognifold_bridge.py"
PORT="${MEERKAT_BRIDGE_PORT:-8099}"

echo "[cognifold-meerkat] house: ${MEERKAT_URL:-http://127.0.0.1:8080}  bridge :$PORT" >&2
python3 "$BRIDGE" &
bridge_pid=$!
trap 'kill "$bridge_pid" 2>/dev/null || true' EXIT

# Give the bridge a moment to take its first poll before the instrument's first request.
sleep 1.5

cd "$PROJECT_DIR"
SW_COGNIFOLD_URL="http://127.0.0.1:$PORT/cognifold" "$GODOT_BIN" "$SCENE" "$@"
