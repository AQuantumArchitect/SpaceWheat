#!/usr/bin/env -S godot --headless -s
extends SceneTree

## 🎲 PLAYSTYLE 1: THE CHAOS FARMER
## Strategy: Random actions, maximum entropy, unpredictable behavior
## Philosophy: "What's the worst that could happen?"

const Farm = preload("res://Core/Farm.gd")
const GameStateManager = preload("res://Core/GameState/GameStateManager.gd")

var farm: Farm = null
var gsm: GameStateManager = null
var chaos_score = 0
var actions_taken = 0

func _initialize():
	print("\n" + "=".repeat(80))
	print("🎲💥 PLAYSTYLE TEST: THE CHAOS FARMER")
	print("Philosophy: Random actions, maximum entropy, break things!")
	print("=".repeat(80))

	await get_root().ready

	# Create GameStateManager
	gsm = GameStateManager.new()
	get_root().add_child(gsm)
	await process_frame

	# Create farm
	farm = Farm.new()
	get_root().add_child(farm)
	for i in range(10):
		await process_frame

	# Register with save system
	gsm.active_farm = farm
	print("✅ Registered with GameStateManager")

	print("\n🎲 Starting chaotic gameplay session...")
	print("  Strategy: Plant randomly, entangle everything, measure chaos!")

	# CHAOS SESSION
	await chaos_session_1()

	# SAVE GAME
	print("\n💾 SAVING CHAOS FARMER STATE...")
	var save_success = gsm.save_game(1)  # Slot 1 = Chaos Farmer
	if save_success:
		print("✅ Chaos state saved to slot 1!")
	else:
		print("❌ Save failed!")

	# Print chaos statistics
	print_chaos_stats()

	quit(0)


func chaos_session_1():
	"""Chaotic farming: plant random crops, entangle randomly, measure unpredictably"""

	print("\n🌪️ CHAOS SESSION 1: Random Planting Frenzy")

	var crops = ["wheat", "mushroom"]
	var all_positions = []

	# Collect all valid positions
	for x in range(6):
		for y in range(2):
			all_positions.append(Vector2i(x, y))

	# Shuffle positions
	all_positions.shuffle()

	# Plant 8 random crops
	print("\n🌾 Planting 8 random crops in random locations:")
	for i in range(8):
		var pos = all_positions[i]
		var crop = crops[randi() % crops.size()]
		farm.build(pos, crop)
		actions_taken += 1
		print("  Planted %s at %s" % [crop, pos])

	await advance_time(2.0)

	# Create random entanglement web
	print("\n🔗 Creating chaotic entanglement web:")
	all_positions.shuffle()

	for i in range(6):
		var pos_a = all_positions[i]
		var pos_b = all_positions[(i + 1) % all_positions.size()]

		var success = farm.entangle_plots(pos_a, pos_b)
		if success:
			chaos_score += 10
			actions_taken += 1
			print("  ⚡ Entangled %s ↔ %s" % [pos_a, pos_b])

	await advance_time(5.0)

	# Measure in RANDOM order (maximum chaos!)
	print("\n📏 Measuring in random order (chaos maximization):")
	all_positions.shuffle()

	for i in range(min(4, all_positions.size())):
		var pos = all_positions[i]
		var outcome = farm.measure_plot(pos)
		actions_taken += 1
		print("  Measured %s: %s" % [pos, outcome])

		# Random wait time between measurements
		await advance_time(randf() * 2.0)

	# Harvest randomly
	print("\n🚜 Harvesting random plots:")
	all_positions.shuffle()

	for i in range(min(3, all_positions.size())):
		var pos = all_positions[i]
		var result = farm.harvest_plot(pos)
		actions_taken += 1
		var yield_val = result.get("yield", 0)
		chaos_score += yield_val
		print("  Harvested %s: yield=%d" % [pos, yield_val])

	# WEIRD INTERACTION: Try to entangle empty plots
	print("\n👻 Trying to entangle EMPTY plots (what happens?):")
	var empty_pos_a = Vector2i(5, 1)
	var empty_pos_b = Vector2i(4, 1)
	var weird_result = farm.entangle_plots(empty_pos_a, empty_pos_b)
	actions_taken += 1
	print("  Result: %s" % ("SUCCESS?!" if weird_result else "Failed (as expected)"))

	# WEIRD INTERACTION: Try to harvest before measuring
	print("\n⚠️ Trying to harvest without measuring (Schrödinger's harvest):")
	var unmeasured_pos = Vector2i(2, 1)
	if farm.grid.get_plot(unmeasured_pos):
		var harvest_result = farm.harvest_plot(unmeasured_pos)
		actions_taken += 1
		print("  Unmeasured harvest yield: %d" % harvest_result.get("yield", 0))
		chaos_score += 5  # Bonus for doing weird stuff


func advance_time(seconds: float):
	"""Advance simulation time"""
	for i in range(int(seconds * 2)):
		await process_frame


func print_chaos_stats():
	"""Print chaos farming statistics"""

	print("\n" + "=".repeat(80))
	print("🎲 CHAOS FARMER STATISTICS")
	print("=".repeat(80))

	print("\n📊 Performance:")
	print("  Actions taken: %d" % actions_taken)
	print("  Chaos score: %d" % chaos_score)
	print("  Chaos per action: %.2f" % (float(chaos_score) / max(1, actions_taken)))

	print("\n🎮 Playstyle:")
	print("  Strategy: MAXIMUM ENTROPY")
	print("  Planning: NONE")
	print("  Fun factor: INFINITE")

	print("\n💾 Save file location: user://saves/slot_1.tres")
	print("=".repeat(80) + "\n")
