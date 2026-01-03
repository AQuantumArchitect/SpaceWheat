extends Node

## Simple game loop test that runs without UI
## Creates Farm directly and plays through one cycle

const Farm = preload("res://Core/Farm.gd")
const QuantumQuestGenerator = preload("res://Core/Quests/QuantumQuestGenerator.gd")
const QuantumQuestEvaluator = preload("res://Core/Quests/QuantumQuestEvaluator.gd")
const QuestCategory = preload("res://Core/Quests/QuestCategory.gd")

var farm: Farm
var evaluator: QuantumQuestEvaluator
var test_timer: float = 0.0
var step: int = 0

func _ready():
	print("\n======================================================================")
	print("SIMPLE GAME LOOP TEST")
	print("======================================================================\n")

	# Create and initialize farm
	print("🌾 Creating farm...")
	farm = Farm.new()
	add_child(farm)

	# Wait one frame for farm to initialize
	await get_tree().process_frame

	if not farm.biome_enabled:
		print("❌ ERROR: Biomes not enabled!")
		get_tree().quit(1)
		return

	print("✅ Farm initialized")
	print("   Grid: %dx%d" % [farm.grid.grid_width, farm.grid.grid_height])
	print("   Biomes: BioticFlux, Market, Forest")
	print("   Starting wheat: %d credits\n" % farm.economy.get_resource("🌾"))

	# Set up quest system
	print("📜 Setting up quests...")
	evaluator = QuantumQuestEvaluator.new()
	add_child(evaluator)
	evaluator.biomes = [farm.biotic_flux_biome]
	evaluator.quest_completed.connect(_on_quest_completed)

	# Generate quest
	var generator = QuantumQuestGenerator.new()
	var context = QuantumQuestGenerator.GenerationContext.new()
	context.player_level = 1
	context.available_emojis = ["🌾", "👥"]
	context.preferred_category = QuestCategory.TUTORIAL

	var quest = generator.generate_quest(context)
	if quest:
		evaluator.activate_quest(quest)
		print("✅ Quest: %s\n" % quest.title)

	# Start test
	set_process(true)

func _process(delta):
	test_timer += delta
	evaluator.evaluate_all_quests(delta)

	match step:
		0:  # Plant (t=0)
			_do_plant()
			step += 1

		1:  # Evolve (wait until t=3)
			if test_timer > 3.0:
				_check_evolution()
				step += 1

		2:  # Measure (t=3)
			_do_measure()
			step += 1

		3:  # Harvest (t=3.1)
			if test_timer > 3.1:
				_do_harvest()
				step += 1

		4:  # Finish (t=5)
			if test_timer > 5.0:
				_finish()
				step += 1
				set_process(false)
				# Force quit
				print("Quitting...")
				await get_tree().create_timer(0.1).timeout
				get_tree().quit(0)

func _do_plant():
	print("\n[t=%.1fs] 🌱 PLANTING wheat at (0,0)..." % test_timer)

	var result = farm.build(Vector2i(0, 0), "wheat")
	if result:
		print("  ✅ Planted successfully")
		print("  💰 Remaining wheat: %d credits" % farm.economy.get_resource("🌾"))
	else:
		print("  ❌ Failed to plant")

func _check_evolution():
	print("\n[t=%.1fs] ⏳ EVOLUTION CHECK..." % test_timer)

	if farm.biotic_flux_biome:
		var theta = farm.biotic_flux_biome.get_observable_theta("🌾", "👥")
		var coherence = farm.biotic_flux_biome.get_observable_coherence("🌾", "👥")
		print("  ⚛️  θ = %.3f rad, coherence = %.3f" % [theta, coherence])

func _do_measure():
	print("\n[t=%.1fs] 📏 MEASURING..." % test_timer)

	var outcome = farm.measure_plot(Vector2i(0, 0))
	print("  📊 Outcome: %s" % outcome)

func _do_harvest():
	print("\n[t=%.1fs] 🚜 HARVESTING..." % test_timer)

	var before = farm.economy.get_resource("🌾")
	var result = farm.harvest_plot(Vector2i(0, 0))

	if result.get("success"):
		var after = farm.economy.get_resource("🌾")
		print("  ✅ Harvested %s" % result.get("outcome"))
		print("  ⚡ Yield: %d credits" % result.get("yield", 0))
		print("  💰 Wheat: %d → %d" % [before, after])
	else:
		print("  ❌ Failed")

func _finish():
	print("\n======================================================================")
	print("TEST COMPLETE")
	print("======================================================================")
	print("\n📊 Final Resources:")
	print("  🌾 Wheat: %d credits" % farm.economy.get_resource("🌾"))
	print("  👥 Labor: %d credits" % farm.economy.get_resource("👥"))

	if evaluator.active_quests.size() > 0:
		print("\n🎯 Quest Status:")
		for quest_id in evaluator.active_quests:
			var quest = evaluator.active_quests[quest_id]
			var status = "COMPLETE" if quest.is_complete() else "IN PROGRESS"
			print("  [%s] %s - %.0f%%" % [status, quest.title, quest.get_completion_percent() * 100])

	print("\n✅ Game loop test finished!\n")

func _on_quest_completed(quest_id: String):
	print("\n🎊 QUEST COMPLETED: %s" % quest_id)
