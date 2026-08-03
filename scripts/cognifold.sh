#!/usr/bin/env bash
# cognifold.sh — point the instrument at a live belief world on the hearth.
#
# The cognifold renderer is a general-purpose reasoning-transparency instrument:
# it renders any `cognifold_trace_v1` payload, game or not. Until now the only
# way to aim it at a live world was an undocumented env var buried in a
# doc-comment (Core/Visualization/CognifoldTraceView.gd:7-11). This is the door.
#
#   scripts/cognifold.sh spacewheat-self     # the game's own mind, via the hive
#   scripts/cognifold.sh meta-membrane       # the mesh's beliefs about itself
#   scripts/cognifold.sh --list              # what's actually being served
#
# Runs the standalone instrument scene — it does NOT touch the shipped game's
# renderer, so this is independent of the gated 3D-default merge (#361).
#
# This script owns NO wire of its own. The base URL, the CRLF-stripped API key
# (LAW #1: an unstripped \r corrupts the header block silently, giving a 200
# with appended=0), and every request live in 🍄/🧪/hearth_client.py — the one
# authority all three hearth callers in this repo share.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PROJECT_DIR/scripts/lib/godot_runtime_env.sh"
GODOT_BIN="$(sw_godot_bin)"
SCENE="scenes/CognifoldTraceView.tscn"
HEARTH="$PROJECT_DIR/🍄/🧪/hearth_client.py"

usage() { sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

world="${1:-}"
case "$world" in
  ""|-h|--help) usage; exit 0 ;;
esac

if [ "$world" = "--list" ]; then
  # Read-only: which worlds the hearth is actually serving right now.
  exec python3 "$HEARTH" worlds
fi

# Fail loudly HERE if the world is dark, rather than opening a window that is
# empty for a reason the viewer cannot distinguish from "a very calm world".
# `endpoint` probes the trace and prints its URL only if it is really served;
# it says on stderr whether the world is unserved or the whole field is dark.
if ! url="$(python3 "$HEARTH" endpoint "$world" cognifold)"; then
  echo "[cognifold] try: scripts/cognifold.sh --list" >&2
  exit 2
fi
key="$(python3 "$HEARTH" key)"

echo "[cognifold] live: $world  (poll ${SW_COGNIFOLD_POLL_S:-2.0}s)"
cd "$PROJECT_DIR"
SW_COGNIFOLD_URL="$url" UMWELTD_API_KEY="$key" exec "$GODOT_BIN" "$SCENE" "${@:2}"
