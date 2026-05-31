#!/usr/bin/env bash
set -euo pipefail

## create_starter_template.sh - DRY Resource Management
##
## Creates the canonical starter template at user://saves/new_game_easy.tres
## This becomes the SINGLE SOURCE OF TRUTH for all resource initialization.
##
## DRY Principle:
##   1. Define resources ONCE in config/starter_resources.json
##   2. Run this script to generate user://saves/new_game_easy.tres
##   3. All new games, profiles, and tests auto-load from template
##   4. Update resources → regenerate → everything updates!
##
## Usage:
##   🎛️/create_starter_template.sh
##   🎛️/create_starter_template.sh --verify  # Check existing template
##   🎛️/create_starter_template.sh --dry-run # Show what would be created

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
CONFIG_FILE="${SCRIPT_DIR}/config/starter_resources.json"
XDG_ROOT="${XDG_ROOT:-${PROJECT_ROOT}/.godot}"
APP_NAME="${APPLICATION_NAME:-SpaceWheat - Quantum Farm}"
USER_DIR="${XDG_ROOT}/godot/app_userdata/${APP_NAME}"
SAVE_DIR="${USER_DIR}/saves"
TEMPLATE_FILE="${SAVE_DIR}/new_game_easy.tres"
TEMP_SLOT=0

DRY_RUN=0
VERIFY_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --verify) VERIFY_ONLY=1 ;;
    *) echo "Unknown arg: $arg"; exit 1 ;;
  esac
done

echo "┌─────────────────────────────────────────────────────┐"
echo "│ DRY Starter Template Generator                      │"
echo "└─────────────────────────────────────────────────────┘"
echo ""
echo "Config: $CONFIG_FILE"
echo "Target: $TEMPLATE_FILE"
echo ""

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ Config file not found: $CONFIG_FILE"
  exit 1
fi

if [[ "$VERIFY_ONLY" == "1" ]]; then
  echo "[verify] Checking existing template..."
  if [[ -f "$TEMPLATE_FILE" ]]; then
    echo "✅ Template exists: $TEMPLATE_FILE"
    echo ""
    echo "Modified: $(stat -c %y "$TEMPLATE_FILE" 2>/dev/null || stat -f %Sm "$TEMPLATE_FILE" 2>/dev/null)"
    echo "Size: $(stat -c %s "$TEMPLATE_FILE" 2>/dev/null || stat -f %z "$TEMPLATE_FILE" 2>/dev/null) bytes"
    exit 0
  else
    echo "❌ Template does not exist: $TEMPLATE_FILE"
    echo "Run without --verify to create it"
    exit 1
  fi
fi

# Parse resources from JSON
echo "[1/4] Parsing resources from config..."
RESOURCE_ARGS=()
while IFS= read -r line; do
  emoji=$(echo "$line" | cut -d: -f1)
  amount=$(echo "$line" | cut -d: -f2)
  if [[ -n "$emoji" ]] && [[ -n "$amount" ]]; then
    RESOURCE_ARGS+=(--resource "${emoji}:${amount}")
    echo "  - ${emoji}: ${amount}"
  fi
done < <(python3 -c "import json; data=json.load(open('$CONFIG_FILE')); [print(f'{k}:{v}') for k,v in data.get('resources', {}).items()]")

# Parse known icons
ICON_ARGS=()
while IFS= read -r line; do
  if [[ -n "$line" ]]; then
    ICON_ARGS+=(--known-icon "$line")
    echo "  - Icon: $line"
  fi
done < <(python3 -c "import json; data=json.load(open('$CONFIG_FILE')); [print(f'{p[\"north\"]}:{p[\"south\"]}') for p in data.get('known_icons', [])]")

# Parse biomes
BIOME_ARGS=()
while IFS= read -r biome; do
  if [[ -n "$biome" ]]; then
    BIOME_ARGS+=(--unlock-biome "$biome")
  fi
done < <(python3 -c "import json; data=json.load(open('$CONFIG_FILE')); [print(b) for b in data.get('unlocked_biomes', [])]")

ACTIVE_BIOME=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('active_biome', 'Village'))")

if [[ "$DRY_RUN" == "1" ]]; then
  echo ""
  echo "[dry-run] Would create template with:"
  echo "  Resources: ${#RESOURCE_ARGS[@]} items"
  echo "  Icons: ${#ICON_ARGS[@]} items"
  echo "  Biomes: ${#BIOME_ARGS[@]} + active: $ACTIVE_BIOME"
  echo "  Target: $TEMPLATE_FILE"
  exit 0
fi

echo ""
echo "[2/4] Creating save in slot $TEMP_SLOT..."
export XDG_ROOT="$XDG_ROOT"
export XDG_DATA_HOME="$XDG_ROOT"
export XDG_CONFIG_HOME="$XDG_ROOT"
export APPLICATION_NAME="$APP_NAME"
python3 "${SCRIPT_DIR}/milk_hunt_seed_save.py" \
  --slot "$TEMP_SLOT" \
  --resource-mode set \
  "${RESOURCE_ARGS[@]}" \
  "${ICON_ARGS[@]}" \
  "${BIOME_ARGS[@]}" \
  --active-biome "$ACTIVE_BIOME"

# Check both possible locations (PROJECT_ROOT and /tmp)
TEMP_SAVE="${SAVE_DIR}/save_slot_${TEMP_SLOT}.tres"
TMP_SAVE="/tmp/sw_godot_milk_hunt/godot/app_userdata/${APP_NAME}/saves/save_slot_${TEMP_SLOT}.tres"

if [[ -f "$TEMP_SAVE" ]]; then
  SOURCE_SAVE="$TEMP_SAVE"
elif [[ -f "$TMP_SAVE" ]]; then
  SOURCE_SAVE="$TMP_SAVE"
  echo "  (using temp location: /tmp/sw_godot_milk_hunt/...)"
else
  echo "❌ Failed to create temporary save"
  echo "  Checked: $TEMP_SAVE"
  echo "  Checked: $TMP_SAVE"
  exit 1
fi

echo ""
echo "[3/4] Copying to template location..."
mkdir -p "$SAVE_DIR"
cp "$SOURCE_SAVE" "$TEMPLATE_FILE"

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "❌ Failed to create template: $TEMPLATE_FILE"
  exit 1
fi

echo ""
echo "[4/4] Verifying template..."
if python3 -c "import sys; sys.exit(0 if open('$TEMPLATE_FILE', 'rb').read()[:4] == b'RSRC' else 1)"; then
  echo "✅ Template is valid Godot resource"
else
  echo "⚠️  Warning: Template may not be a valid resource file"
fi

echo ""
echo "┌─────────────────────────────────────────────────────┐"
echo "│ ✅ DRY Starter Template Created                     │"
echo "└─────────────────────────────────────────────────────┘"
echo ""
echo "Template: $TEMPLATE_FILE"
echo "Source:   $CONFIG_FILE"
echo ""
echo "This template is now the SINGLE SOURCE OF TRUTH for:"
echo "  ✓ All new games (auto-loaded)"
echo "  ✓ All test scenarios (via load_new_game_template)"
echo "  ✓ All profile seeds (via --load-slot or template)"
echo ""
echo "To update resources system-wide:"
echo "  1. Edit: $CONFIG_FILE"
echo "  2. Run:  $0"
echo "  3. Done! All systems updated."
echo ""
