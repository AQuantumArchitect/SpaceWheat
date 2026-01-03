#!/bin/bash
# Test plot/oval alignment with visual verification

echo "=== PLOT/OVAL ALIGNMENT TEST ==="
echo ""
echo "1. Boot game and capture positioning debug..."
timeout 8 godot --path /home/tehcr33d/ws/SpaceWheat 2>&1 | tee /tmp/alignment_debug.log

echo ""
echo "2. Extracting biome oval calculations..."
grep "🟢 BiomeLayoutCalculator" /tmp/alignment_debug.log -A3

echo ""
echo "3. Extracting plot positioning calculations..."
grep "🔵 Biome" /tmp/alignment_debug.log -A3

echo ""
echo "4. Comparing scaling factors..."
echo "Expected: Both should use scale based on BASE_REFERENCE_RADIUS=300.0"
grep "viewport_scale\|scale=" /tmp/alignment_debug.log | head -10

echo ""
echo "5. Extracting first 3 tile positions..."
grep "📍 Tile grid" /tmp/alignment_debug.log | head -3

echo ""
echo "=== ANALYSIS ==="
echo "Check that:"
echo "  ✓ Scaling factors match (0.84 for 1280×720)"
echo "  ✓ Biome centers match between systems"
echo "  ✓ Tile positions are inside oval boundaries"
echo ""
echo "Visual test: Take screenshot and verify plots are inside ovals!"
