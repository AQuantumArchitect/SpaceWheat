#!/bin/bash
# Build Bundled Operator Cache
# This script builds the operator cache and copies it to res://BundledCache/
# for inclusion in exported game builds.
#
# Usage:
#   bash tools/BuildBundledCache.sh

echo "======================================================================"
echo "BUILDING BUNDLED OPERATOR CACHE"
echo "======================================================================"
echo

# Detect Godot path
if command -v godot &> /dev/null; then
    GODOT="godot"
else
    echo "Error: godot command not found"
    exit 1
fi

# Get paths
USER_CACHE="$HOME/.local/share/godot/app_userdata/SpaceWheat - Quantum Farm/operator_cache"
BUNDLED_CACHE="./BundledCache"

echo "User cache path: $USER_CACHE"
echo "Bundled cache path: $BUNDLED_CACHE"
echo

# Step 1: Clear old bundled cache
echo "[1/4] Clearing old bundled cache..."
rm -rf "$BUNDLED_CACHE"
mkdir -p "$BUNDLED_CACHE"
echo "  ✓ Cleared"

# Step 2: Clear user cache to force rebuild
echo "[2/4] Clearing user cache to force rebuild..."
rm -rf "$USER_CACHE"
echo "  ✓ Cleared"

# Step 3: Boot game to trigger operator building
echo "[3/4] Booting game to build operators..."
echo "       (This may take 1-2 seconds)"
$GODOT --headless --quit-after 5 2>&1 | grep -E "Cache|Building|built" | head -20
echo "  ✓ Game booted"

# Step 4: Copy user cache to bundled location
echo "[4/4] Copying cache to bundled location..."
if [ -d "$USER_CACHE" ]; then
    cp -r "$USER_CACHE"/* "$BUNDLED_CACHE/"
    FILE_COUNT=$(ls -1 "$BUNDLED_CACHE"/*.json 2>/dev/null | wc -l)
    echo "  ✓ Copied $FILE_COUNT files"
else
    echo "  ❌ Error: User cache not found at $USER_CACHE"
    exit 1
fi

# Verify
echo
echo "Verifying bundled cache..."
if [ -f "$BUNDLED_CACHE/manifest.json" ]; then
    BIOME_COUNT=$(grep -o '"[^"]*":' "$BUNDLED_CACHE/manifest.json" | wc -l)
    echo "  ✓ Found manifest with $BIOME_COUNT biomes"

    echo "  → Bundled biomes:"
    grep -o '"[^"]*Biome"' "$BUNDLED_CACHE/manifest.json" | tr -d '"' | sed 's/^/     • /'
else
    echo "  ❌ Error: manifest.json not found"
    exit 1
fi

echo
echo "======================================================================"
echo "✅ BUNDLED CACHE BUILD COMPLETE"
echo "======================================================================"
echo
echo "Next steps:"
echo "  1. The BundledCache/ folder has been created/updated"
echo "  2. Commit BundledCache/ to your repository"
echo "  3. Export your game - BundledCache/ will be included automatically"
echo
echo "Players will now load operators instantly on first boot!"
echo
