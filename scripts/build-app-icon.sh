#!/usr/bin/env bash
# Rebuild every shipped form of the application icon, in dependency order.
#
# Run this after touching tools/build_app_icon.py, or after any change to the
# values it reads from the live game — QuantumField3D's background colour,
# visual_themes.json's accent/player-faction hue/line palette, or the wheat
# glyph in Assets/emoji_svg/. The generator hard-fails rather than guessing if
# any of those move, so a red run here means the icon and the game have
# drifted apart and one of them needs a decision.
#
# Outputs (all committed):
#   Assets/icon.svg          project icon — editor, window, Linux, itch
#   Assets/icon_small.svg    simplified art for frames <= 48px
#   Assets/icon_raster/*.png 11 sizes, rasterised by Godot's own ThorVG
#   Assets/icon.ico          7-frame Windows icon (.exe, taskbar, Explorer)
#
# Wiring lives in project.godot (config/icon, config/windows_native_icon) and
# export_presets.cfg (application/icon, console_wrapper_icon, the three
# progressive_web_app/icon_* fields). Those are set once and are not touched
# by this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$SCRIPT_DIR")"
cd "$REPO"

source "$SCRIPT_DIR/lib/godot_runtime_env.sh"
GODOT="$(sw_godot_bin)"

echo "== 1/4  author SVGs from the game's own palette =="
python3 tools/build_app_icon.py

echo
echo "== 2/4  rasterise via Godot (ThorVG) =="
"$GODOT" --headless --path . -s tools/rasterize_app_icon.gd

echo
echo "== 3/4  pack Windows .ico =="
python3 tools/build_app_icon.py --pack-ico

echo
echo "== 4/4  reimport so Godot picks up the new art =="
"$GODOT" --headless --path . --import >/dev/null 2>&1

echo
echo "icon rebuilt. Verify with: python3 -m pytest tests/test_app_icon_wiring.py -q"
