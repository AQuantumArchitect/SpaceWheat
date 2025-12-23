#!/bin/bash
# Test entanglement line visualization

echo "🔗 Testing Entanglement Lines..."
echo ""
echo "This will:"
echo "  1. Show the farm UI"
echo "  2. Auto-plant 4 wheat plots"
echo "  3. Auto-create entanglements between them"
echo "  4. Display shimmering blue/purple lines"
echo ""
echo "You should see animated lines connecting the planted plots!"
echo ""

# Create test script that auto-plants and entangles
cat > /tmp/test_entanglement_auto.gd << 'EOF'
extends SceneTree

func _init():
	# Load the FarmView scene
	var farm_scene = load("res://scenes/FarmView.tscn")
	var farm = farm_scene.instantiate()
	root.add_child(farm)

	# Wait a bit for everything to initialize
	await get_tree().create_timer(0.5).timeout

	print("\n🌱 Auto-planting wheat in a 2x2 grid...")

	# Plant wheat at (1,1), (1,2), (2,1), (2,2)
	var positions = [
		Vector2i(1, 1),
		Vector2i(1, 2),
		Vector2i(2, 1),
		Vector2i(2, 2)
	]

	for pos in positions:
		if farm.economy.buy_seed():
			farm.farm_grid.plant_wheat(pos)
			print("  ✅ Planted at %s" % str(pos))

	await get_tree().create_timer(0.5).timeout

	print("\n🔗 Creating entanglements...")

	# Create entanglements in a square pattern
	var entanglements = [
		[Vector2i(1, 1), Vector2i(1, 2)],  # Top edge
		[Vector2i(1, 2), Vector2i(2, 2)],  # Right edge
		[Vector2i(2, 2), Vector2i(2, 1)],  # Bottom edge
		[Vector2i(2, 1), Vector2i(1, 1)],  # Left edge
		[Vector2i(1, 1), Vector2i(2, 2)],  # Diagonal 1
		[Vector2i(1, 2), Vector2i(2, 1)]   # Diagonal 2
	]

	for pair in entanglements:
		var success = farm.farm_grid.create_entanglement(pair[0], pair[1])
		if success:
			print("  ✅ Entangled %s ↔ %s" % [str(pair[0]), str(pair[1])])
			farm.entanglement_lines.force_refresh()
		else:
			print("  ⚠️  Failed to entangle %s ↔ %s (max 3 per plot)" % [str(pair[0]), str(pair[1])])

	await get_tree().create_timer(0.5).timeout

	print("\n✨ Watch the shimmering quantum connections!")
	print("   Blue/purple lines should be animating between plots")
	print("")
	print("Press Ctrl+C or close window to exit")
	print("")

	# Update UI
	farm._update_ui()
EOF

# Run the test (--path points to project root)
timeout 60 godot --path .. --script /tmp/test_entanglement_auto.gd 2>&1 &

PID=$!
sleep 2

if ps -p $PID > /dev/null; then
	echo "✅ Test is running!"
	wait $PID
else
	echo "❌ Test failed to start"
	exit 1
fi
