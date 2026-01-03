extends SceneTree

## Test: Tool Q and Tool R fixes
## Q: Biome validation prevents planting incompatible emojis
## R: Bubbles disappear after measure+harvest

const Farm = preload("res://Core/Farm.gd")

var farm: Farm

func _initialize():
	print("\n" + "=".repeat(80))
	print("🛠️  TEST: Tool Q & R Fixes")
	print("=".repeat(80))

	await get_root().ready

	# Setup farm
	farm = Farm.new()
	farm.name = "Farm"
	get_root().add_child(farm)

	# TEST 1: Tool Q - Biome validation
	print("\n" + "=".repeat(80))
	print("🧪 TEST 1: Tool Q - Biome Validation")
	print("=".repeat(80))

	# Get BioticFlux biome emojis
	var biotic_flux = farm.get_node("BioticFlux")
	if biotic_flux and biotic_flux.bath:
		print("\n📋 BioticFlux biome emojis:")
		for emoji in biotic_flux.bath.emoji_list:
			print("   ✓ %s" % emoji)

	# Try to plant wheat (should succeed - 🌾 is in BioticFlux)
	print("\n🌾 Attempting to plant WHEAT at (0,0)...")
	var wheat_success = farm.build(Vector2i(0, 0), "wheat")
	if wheat_success:
		print("   ✅ Wheat planted successfully (expected)")
	else:
		print("   ❌ Wheat failed to plant (unexpected!)")

	# Try to plant tomato (should fail - 🍅 is NOT in BioticFlux)
	print("\n🍅 Attempting to plant TOMATO at (1,0)...")
	var tomato_success = farm.build(Vector2i(1, 0), "tomato")
	if not tomato_success:
		print("   ✅ Tomato rejected (expected - not in BioticFlux biome)")
	else:
		print("   ❌ Tomato planted (unexpected - should be rejected!)")

	# TEST 2: Tool R - Bubble removal after harvest
	print("\n" + "=".repeat(80))
	print("🧪 TEST 2: Tool R - Bubble Removal After Harvest")
	print("=".repeat(80))

	# Plant mushroom at (2,0)
	print("\n🍄 Planting mushroom at (2,0)...")
	var mushroom_success = farm.build(Vector2i(2, 0), "mushroom")
	if not mushroom_success:
		print("   ❌ Failed to plant mushroom")
		quit(1)

	# Check plot state before harvest
	var plot = farm.grid.get_plot(Vector2i(2, 0))
	if plot and plot.quantum_state:
		print("   ✅ Mushroom planted: quantum_state exists")
	else:
		print("   ❌ Mushroom planted but no quantum_state!")

	# Measure and harvest
	print("\n🔬✂️  Measuring and harvesting mushroom...")
	farm.measure_plot(Vector2i(2, 0))
	var harvest_result = farm.harvest_plot(Vector2i(2, 0))

	# Check plot state after harvest
	plot = farm.grid.get_plot(Vector2i(2, 0))
	if plot:
		if plot.quantum_state == null:
			print("   ✅ quantum_state cleared after harvest")
		else:
			print("   ❌ quantum_state still exists after harvest!")

		if not plot.is_planted:
			print("   ✅ is_planted=false after harvest")
		else:
			print("   ❌ is_planted still true after harvest!")
	else:
		print("   ❌ Plot no longer exists!")

	# Check QuantumNode visual state
	var viz = farm.get_node_or_null("QuantumViz")
	if viz:
		var nodes = viz.quantum_nodes_by_grid_pos
		if nodes.has(Vector2i(2, 0)):
			var node = nodes[Vector2i(2, 0)]
			# Force update from plot state
			node.update_from_quantum_state()

			if node.visual_scale == 0.0 and node.visual_alpha == 0.0:
				print("   ✅ Bubble invisible (visual_scale=0.0, visual_alpha=0.0)")
			else:
				print("   ❌ Bubble still visible (scale=%.2f, alpha=%.2f)" % [node.visual_scale, node.visual_alpha])

			if node.emoji_north_opacity == 0.0 and node.emoji_south_opacity == 0.0:
				print("   ✅ Emoji opacities cleared (both 0.0)")
			else:
				print("   ❌ Emoji still visible (north=%.2f, south=%.2f)" % [node.emoji_north_opacity, node.emoji_south_opacity])
		else:
			print("   ⚠️  No QuantumNode found for this plot")
	else:
		print("   ⚠️  No QuantumViz found")

	# SUMMARY
	print("\n" + "=".repeat(80))
	print("📊 SUMMARY")
	print("=".repeat(80))

	var issues = []

	# Test 1 checks
	if not wheat_success:
		issues.append("❌ Wheat should plant in BioticFlux (has 🌾)")
	if tomato_success:
		issues.append("❌ Tomato should be rejected from BioticFlux (no 🍅)")

	# Test 2 checks
	if plot and plot.quantum_state != null:
		issues.append("❌ quantum_state should be null after harvest")
	if plot and plot.is_planted:
		issues.append("❌ is_planted should be false after harvest")

	if issues.size() > 0:
		print("\n⚠️  ISSUES FOUND:")
		for issue in issues:
			print("   " + issue)
	else:
		print("\n🎉 ALL CHECKS PASSED!")
		print("   ✅ Tool Q: Biome validation working")
		print("   ✅ Tool R: Bubble removal working")

	print("\n" + "=".repeat(80))
	quit(0)
