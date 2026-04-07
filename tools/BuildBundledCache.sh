#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
GODOT_BIN="${GODOT_BIN:-godot}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
    echo "Error: Godot binary not found. Set GODOT_BIN or add godot to PATH." >&2
    exit 1
fi

cd "$PROJECT_DIR"
"$GODOT_BIN" --headless --path . --script tools/BuildBundledCache.gd
