extends Node

## AutoPlayer - Automated gameplay testing
## Attach this to FarmView scene to automatically play the game

const QuantumQuestGenerator = preload("res://Core/Quests/QuantumQuestGenerator.gd")
const QuantumQuestEvaluator = preload("res://Core/Quests/QuantumQuestEvaluator.gd")
const QuestCategory = preload("res://Core/Quests/QuestCategory.gd")

var farm: Node = null
var quest_evaluator: QuantumQuestEvaluator = null
var step: int = 0
var time_elapsed: float = 0.0
var test_complete: bool = false

func _ready():
	print("\n🤖 AutoPlayer initialized")
	print("   Will start playing in 1 second...")

	# Wait a moment for farm to fully initialize
	await get_tree().create_timer(1.0).timeout

	# Find farm
	farm = _find_farm()
	if not farm:
		print("❌ ERROR: Could not find Farm node")
		return

	print("   ✅ Found farm: %s" % farm.name)
	print("   ✅ Biomes: %s" % ("enabled" if farm.biome_enabled else "disabled"))

	# Set up quest system
	_setup_quest_system()

	# Start playing
	set_process(true)
	print("\n🎮 Starting automated gameplay...")

func _process(delta):
	if test_complete:
		return

	time_elapsed += delta

	# Execute steps at specific times
	match step:
		0:  # Plant wheat at t=0
			_step_plant_wheat()
			step += 1

		1:  # Wait for evolution (t=2s)
			if time_elapsed > 2.0:
				_step_check_evolution()
				step += 1

		2:  # Measure at t=4s
			if time_elapsed > 4.0:
				_step_measure()
				step += 1

		3:  # Harvest at t=6s
			if time_elapsed > 6.0:
				_step_harvest()
				step += 1

		4:  # Check quest completion at t=8s
			if time_elapsed > 8.0:
				_step_check_quest()
				step += 1

		5:  # Finish at t=10s
			if time_elapsed > 10.0:
				_finish_test()
				step += 1
				test_complete = true

	# Continuously evaluate quests
	if quest_evaluator:
		quest_evaluator.evaluate_all_quests(delta)

func _setup_quest_system():
	print("\n📜 Setting up quest system...")
	quest_evaluator = QuantumQuestEvaluator.new()
	add_child(quest_evaluator)

	# Register biomes
	if farm.biome_enabled:
		quest_evaluator.biomes = [
			farm.biotic_flux_biome,
			farm.market_biome,
			farm.forest_biome
		]
		print("   ✅ Registered 3 biomes with evaluator")

	# Generate a simple quest
	var generator = QuantumQuestGenerator.new()
	var context = QuantumQuestGenerator.GenerationContext.new()
	context.player_level = 1
	context.available_emojis = ["🌾", "👥", "🍄", "🍂"]
	context.preferred_category = QuestCategory.TUTORIAL
	context.difficulty_preference = 0.2

	var quest = generator.generate_quest(context)
	if quest:
		quest_evaluator.activate_quest(quest)
		print("   ✅ Quest activated: %s" % quest.title)
		quest_evaluator.quest_completed.connect(_on_quest_completed)
	else:
		print("   ⚠️  Failed to generate quest")

func _step_plant_wheat():
	print("\n🌱 STEP 1 (t=%.1fs): Planting wheat..." % time_elapsed)

	var wheat_before = farm.economy.get_resource("🌾")
	print("   💰 Wheat before: %d credits" % wheat_before)

	var planted = farm.build(Vector2i(0, 0), "wheat")

	if planted:
		var wheat_after = farm.economy.get_resource("🌾")
		print("   ✅ Planted at (0, 0)")
		print("   💰 Wheat after: %d credits (cost: %d)" % [wheat_after, wheat_before - wheat_after])

		# Check quantum state
		var plot = farm.grid.get_plot(Vector2i(0, 0))
		if plot and plot.quantum_state:
			print("   ⚛️  Quantum state:")
			print("      North: %s, South: %s" % [plot.quantum_state.north_pole, plot.quantum_state.south_pole])
			print("      θ = %.3f rad" % plot.quantum_state.theta)
	else:
		print("   ❌ Failed to plant")

func _step_check_evolution():
	print("\n⏳ STEP 2 (t=%.1fs): Checking evolution..." % time_elapsed)

	if farm.biotic_flux_biome:
		var theta = farm.biotic_flux_biome.get_observable_theta("🌾", "👥")
		var coherence = farm.biotic_flux_biome.get_observable_coherence("🌾", "👥")
		var amp_wheat = farm.biotic_flux_biome.get_observable_amplitude("🌾")

		print("   ⚛️  Observable values:")
		print("      θ(🌾↔👥) = %.3f rad (%.1f°)" % [theta, rad_to_deg(theta)])
		print("      coherence = %.3f" % coherence)
		print("      amp(🌾) = %.3f" % amp_wheat)

func _step_measure():
	print("\n📏 STEP 3 (t=%.1fs): Measuring..." % time_elapsed)

	var outcome = farm.measure_plot(Vector2i(0, 0))
	print("   📊 Measurement outcome: %s" % outcome)

func _step_harvest():
	print("\n🚜 STEP 4 (t=%.1fs): Harvesting..." % time_elapsed)

	var wheat_before = farm.economy.get_resource("🌾")
	var result = farm.harvest_plot(Vector2i(0, 0))

	if result.get("success", false):
		var wheat_after = farm.economy.get_resource("🌾")
		print("   ✅ Harvest successful")
		print("   📦 Outcome: %s" % result.get("outcome", "?"))
		print("   ⚡ Yield: %d credits" % result.get("yield", 0))
		print("   💰 Wheat: %d → %d credits" % [wheat_before, wheat_after])
	else:
		print("   ❌ Harvest failed")

func _step_check_quest():
	print("\n🎯 STEP 5 (t=%.1fs): Checking quest..." % time_elapsed)

	if quest_evaluator and quest_evaluator.active_quests.size() > 0:
		for quest_id in quest_evaluator.active_quests:
			var quest = quest_evaluator.active_quests[quest_id]
			var progress = quest.get_completion_percent()
			print("   📊 Quest: %s" % quest.title)
			print("   📈 Progress: %.1f%%" % (progress * 100))

			if quest.is_complete():
				print("   🎉 QUEST COMPLETED!")
			else:
				print("   ⏳ Still in progress...")

func _finish_test():
	print("\n" + "=" * 70)
	print("TEST COMPLETE")
	print("=" * 70)
	print("\n📊 Final State:")
	print("   🌾 Wheat: %d credits" % farm.economy.get_resource("🌾"))
	print("   👥 Labor: %d credits" % farm.economy.get_resource("👥"))

	if quest_evaluator:
		print("\n🎯 Quest Status:")
		for quest_id in quest_evaluator.active_quests:
			var quest = quest_evaluator.active_quests[quest_id]
			var status = "✅ COMPLETE" if quest.is_complete() else "⏳ IN PROGRESS"
			print("   %s %s (%.1f%%)" % [status, quest.title, quest.get_completion_percent() * 100])

	print("\n✅ Automated gameplay test finished!")
	print("   You can now take over manual control or close the game.\n")

func _on_quest_completed(quest_id: String):
	print("\n🎊 🎊 🎊 QUEST COMPLETED: %s 🎊 🎊 🎊" % quest_id)

func _find_farm() -> Node:
	"""Recursively search for Farm node in scene tree"""
	return _find_node_by_class(get_tree().root, "Farm")

func _find_node_by_class(node: Node, class_name: String) -> Node:
	"""Recursively find first node with given class"""
	if node.get_class() == class_name or (node.get_script() and node.get_script().get_global_name() == class_name):
		return node

	for child in node.get_children():
		var result = _find_node_by_class(child, class_name)
		if result:
			return result

	return null
