#!/usr/bin/env -S godot --headless -s
extends SceneTree

## 📐 PLAYSTYLE 2: THE PERFECTIONIST
## Strategy: Precise planning, optimal entanglement, maximum efficiency
## Philosophy: "Every qubit matters"

const Farm = preload("res://Core/Farm.gd")

var farm: Farm = null
var efficiency_score = 0
var actions_taken = 0
var wasted_actions = 0

func _initialize():
	print("\n" + "=".repeat(80))
	print("📐✨ PLAYSTYLE TEST: THE PERFECTIONIST")
	print("Philosophy: Precise planning, optimal yields, zero waste!")
	print("=".repeat(80))

	await get_root().ready

	# Create farm
	farm = Farm.new()
	get_root().add_child(farm)
	for i in range(10):
		await process_frame

	# Register with save system
	var gsm = get_root().get_node_or_null("GameStateManager")
	if gsm:
		gsm.active_farm = farm
		print("✅ Registered with GameStateManager")

	print("\n📐 Starting perfectionist gameplay session...")
	print("  Strategy: Geometric patterns, optimal entanglement, precise timing!")

	# PERFECTIONIST SESSION
	await perfectionist_session_1()

	# SAVE GAME
	print("\n💾 SAVING PERFECTIONIST STATE...")
	if gsm:
		var save_success = gsm.save_game(2)  # Slot 2 = Perfectionist
		if save_success:
			print("✅ Perfect state saved to slot 2!")
		else:
			print("❌ Save failed!")

	# Print perfectionist statistics
	print_perfectionist_stats()

	quit(0)


func perfectionist_session_1():
	"""Perfectionist farming: geometric patterns, optimal entanglement, precise measurements"""

	print("\n✨ PERFECTIONIST SESSION 1: The Perfect Grid")

	# PHASE 1: Plant in perfect 2x3 pattern
	print("\n🌾 PHASE 1: Planting perfect 2×3 wheat grid")
	var wheat_grid = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)
	]

	for pos in wheat_grid:
		farm.build(pos, "wheat")
		actions_taken += 1
		print("  ✓ Wheat at %s" % pos)

	await advance_time(2.0)

	# PHASE 2: Create optimal entanglement pattern
	print("\n🔗 PHASE 2: Creating optimal entanglement lattice")
	print("  Pattern: Horizontal + vertical connections")

	# Horizontal entanglement
	for y in range(2):
		for x in range(2):
			var pos_a = Vector2i(x, y)
			var pos_b = Vector2i(x + 1, y)
			var success = farm.entangle_plots(pos_a, pos_b)
			actions_taken += 1
			if success:
				efficiency_score += 10
				print("  ✓ Horizontal: %s ↔ %s" % [pos_a, pos_b])
			else:
				wasted_actions += 1

	# Vertical entanglement
	for x in range(3):
		var pos_a = Vector2i(x, 0)
		var pos_b = Vector2i(x, 1)
		var success = farm.entangle_plots(pos_a, pos_b)
		actions_taken += 1
		if success:
			efficiency_score += 10
			print("  ✓ Vertical: %s ↔ %s" % [pos_a, pos_b])
		else:
			wasted_actions += 1

	# Wait for optimal evolution time
	print("\n⏱️ PHASE 3: Waiting for optimal quantum evolution (5.0s)")
	await advance_time(5.0)

	# PHASE 4: Measure in optimal order (top-left to bottom-right)
	print("\n📏 PHASE 4: Measuring in optimal order (raster scan)")

	for y in range(2):
		for x in range(3):
			var pos = Vector2i(x, y)
			var outcome = farm.measure_plot(pos)
			actions_taken += 1
			print("  ✓ Measured %s: %s" % [pos, outcome])

			# Precise wait time between measurements
			await advance_time(0.5)

	# PHASE 5: Harvest in same optimal order
	print("\n🚜 PHASE 5: Harvesting in optimal order")

	var total_yield = 0
	for y in range(2):
		for x in range(3):
			var pos = Vector2i(x, y)
			var result = farm.harvest_plot(pos)
			actions_taken += 1
			var yield_val = result.get("yield", 0)
			total_yield += yield_val
			efficiency_score += yield_val * 2  # Double points for perfect harvest
			print("  ✓ Harvested %s: yield=%d" % [pos, yield_val])

	print("\n📊 Total yield from perfect grid: %d" % total_yield)

	# PHASE 6: Plant mushroom cluster in perfect pattern
	print("\n🍄 PHASE 6: Planting perfect mushroom cluster")
	var mushroom_cluster = [
		Vector2i(3, 0), Vector2i(4, 0),
		Vector2i(3, 1), Vector2i(4, 1)
	]

	for pos in mushroom_cluster:
		farm.build(pos, "mushroom")
		actions_taken += 1
		print("  ✓ Mushroom at %s" % pos)

	# Create perfect 2x2 entanglement
	print("\n🔗 Creating perfect 2×2 entanglement:")
	var mushroom_pairs = [
		[Vector2i(3, 0), Vector2i(4, 0)],
		[Vector2i(3, 1), Vector2i(4, 1)],
		[Vector2i(3, 0), Vector2i(3, 1)],
		[Vector2i(4, 0), Vector2i(4, 1)]
	]

	for pair in mushroom_pairs:
		var success = farm.entangle_plots(pair[0], pair[1])
		actions_taken += 1
		if success:
			efficiency_score += 10
			print("  ✓ Entangled %s ↔ %s" % [pair[0], pair[1]])
		else:
			wasted_actions += 1

	print("\n✅ Perfect session complete!")


func advance_time(seconds: float):
	"""Advance simulation time"""
	for i in range(int(seconds * 2)):
		await process_frame


func print_perfectionist_stats():
	"""Print perfectionist farming statistics"""

	print("\n" + "=".repeat(80))
	print("📐 PERFECTIONIST STATISTICS")
	print("=".repeat(80))

	print("\n📊 Performance:")
	print("  Actions taken: %d" % actions_taken)
	print("  Wasted actions: %d" % wasted_actions)
	print("  Efficiency score: %d" % efficiency_score)
	print("  Efficiency per action: %.2f" % (float(efficiency_score) / max(1, actions_taken)))

	var waste_percent = (float(wasted_actions) / max(1, actions_taken)) * 100
	print("  Waste percentage: %.1f%%" % waste_percent)

	print("\n🎮 Playstyle:")
	print("  Strategy: GEOMETRIC PERFECTION")
	print("  Planning: MAXIMUM")
	print("  Precision: ABSOLUTE")

	if waste_percent < 5.0:
		print("\n🏆 ACHIEVEMENT: Nearly Perfect! (<5% waste)")

	print("\n💾 Save file location: user://saves/slot_2.tres")
	print("=".repeat(80) + "\n")
