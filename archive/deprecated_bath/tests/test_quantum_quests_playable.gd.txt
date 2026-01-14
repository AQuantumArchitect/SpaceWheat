extends Control

## Interactive test for quantum quest system with bath-first biomes
## Press SPACE to manipulate quantum state and complete quests

const BiomeBase = preload("res://Core/Environment/BiomeBase.gd")
const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const QuantumBath = preload("res://Core/QuantumSubstrate/QuantumBath.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const QuantumQuestGenerator = preload("res://Core/Quests/QuantumQuestGenerator.gd")
const QuantumQuestEvaluator = preload("res://Core/Quests/QuantumQuestEvaluator.gd")
const QuestCategory = preload("res://Core/Quests/QuestCategory.gd")

@onready var info_label = $Info

var biome: BiomeBase
var evaluator: QuantumQuestEvaluator
var generator: QuantumQuestGenerator
var active_quests: Array = []
var manipulation_count: int = 0

func _ready():
	print("🎮 Quantum Quest Test - Interactive Mode")
	print("=========================================")

	# Create biome in bath mode
	biome = BioticFluxBiome.new()
	add_child(biome)

	# Wait for biome to initialize
	await get_tree().process_frame

	if not biome.use_bath_mode or not biome.bath:
		_display_error("❌ BioticFluxBiome is not in bath mode!")
		return

	print("✅ Biome created in bath mode")
	print("   Bath emojis: %s" % str(biome.bath.emoji_list))

	# Create some projections (simulate planted plots)
	var pos1 = Vector2i(0, 0)
	var pos2 = Vector2i(1, 0)
	biome.create_projection(pos1, "🌾", "💀")
	biome.create_projection(pos2, "🍄", "🍂")

	print("✅ Created 2 projections:")
	print("   Position %s: 🌾↔💀 (wheat/labor)" % pos1)
	print("   Position %s: 🍄↔🍂 (mushroom/detritus)" % pos2)

	# Create quest system
	generator = QuantumQuestGenerator.new()
	evaluator = QuantumQuestEvaluator.new()
	evaluator.biomes = [biome]

	# Connect signals
	evaluator.quest_progress_updated.connect(_on_quest_progress)
	evaluator.quest_completed.connect(_on_quest_completed)
	evaluator.objective_completed.connect(_on_objective_completed)

	print("✅ Quest system initialized")

	# Generate some test quests
	_generate_test_quests()

	# Start evaluation loop
	set_process(true)
	_update_display()

func _generate_test_quests():
	"""Generate 3 simple quests for testing"""
	print("\n📜 Generating test quests...")

	var context = QuantumQuestGenerator.GenerationContext.new()
	context.player_level = 1
	context.available_emojis = ["🌾", "💀", "🍄", "🍂"]
	context.faction_bits = 0b000000000001  # Agricultural
	context.difficulty_preference = 0.3  # Easy quests

	# Quest 1: Tutorial - achieve theta
	context.preferred_category = QuestCategory.TUTORIAL
	var quest1 = generator.generate_quest(context)
	if quest1:
		evaluator.activate_quest(quest1)
		active_quests.append(quest1)
		print("  ✓ Quest 1: %s" % quest1.title)

	# Quest 2: Basic challenge
	context.preferred_category = QuestCategory.BASIC_CHALLENGE
	var quest2 = generator.generate_quest(context)
	if quest2:
		evaluator.activate_quest(quest2)
		active_quests.append(quest2)
		print("  ✓ Quest 2: %s" % quest2.title)

	# Quest 3: Discovery
	context.preferred_category = QuestCategory.DISCOVERY
	var quest3 = generator.generate_quest(context)
	if quest3:
		evaluator.activate_quest(quest3)
		active_quests.append(quest3)
		print("  ✓ Quest 3: %s" % quest3.title)

	print("✅ Generated %d quests" % active_quests.size())

func _process(delta):
	# Evaluate quests each frame
	evaluator.evaluate_all_quests(delta)

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_manipulate_quantum_state()
			KEY_R:
				_reset_test()
			KEY_I:
				_print_current_state()
			KEY_ESCAPE:
				get_tree().quit()

func _manipulate_quantum_state():
	"""Rotate quantum state to change observables"""
	if not biome or not biome.bath:
		return

	manipulation_count += 1

	print("\n⚡ Manipulating quantum state (action #%d)" % manipulation_count)

	# Rotate amplitudes slightly (simulating player actions)
	for i in range(biome.bath.amplitudes.size()):
		var amp = biome.bath.amplitudes[i]
		var angle = 0.1 * manipulation_count  # Rotate gradually

		# Apply rotation matrix
		var cos_a = cos(angle)
		var sin_a = sin(angle)
		var new_re = amp.re * cos_a - amp.im * sin_a
		var new_im = amp.re * sin_a + amp.im * cos_a

		biome.bath.amplitudes[i] = Complex.new(new_re, new_im)

	# Renormalize
	biome.bath.normalize()

	# Update projections
	biome.update_projections()

	# Print new state
	print("  New bath state:")
	for i in range(biome.bath.emoji_list.size()):
		var emoji = biome.bath.emoji_list[i]
		var amp = biome.bath.amplitudes[i]
		print("    %s: amp=%.3f, phase=%.3f rad" % [emoji, amp.abs(), amp.arg()])

	# Print observable values
	var theta_wheat = biome.get_observable_theta("🌾", "💀")
	var coherence_wheat = biome.get_observable_coherence("🌾", "💀")
	print("  Observables:")
	print("    θ(🌾↔💀) = %.3f rad (%.1f°)" % [theta_wheat, rad_to_deg(theta_wheat)])
	print("    coherence(🌾↔💀) = %.3f" % coherence_wheat)

	_update_display()

func _reset_test():
	"""Reset everything"""
	print("\n🔄 Resetting test...")
	manipulation_count = 0

	# Clear quests
	for quest in active_quests:
		evaluator.deactivate_quest(quest.quest_id)
	active_quests.clear()

	# Reset bath to uniform state
	if biome and biome.bath:
		biome.bath.initialize_uniform()
		biome.update_projections()

	# Generate new quests
	_generate_test_quests()
	_update_display()
	print("✅ Reset complete")

func _print_current_state():
	"""Print detailed state information"""
	print("\n📊 Current State:")
	print("  Manipulation count: %d" % manipulation_count)
	print("  Active quests: %d" % active_quests.size())

	for quest in active_quests:
		var progress = quest.get_completion_percent()
		print("\n  Quest: %s" % quest.title)
		print("    Progress: %.1f%%" % (progress * 100))
		print("    Status: %s" % quest.status)

		for i in range(quest.objectives.size()):
			var obj = quest.objectives[i]
			var obj_progress = quest.progress.get(i, {})
			var completed = obj_progress.get("completed", false)
			print("    Objective %d: %s [%s]" % [
				i + 1,
				obj.get_summary(),
				"✅" if completed else "⏳"
			])

func _update_display():
	"""Update info label with current state"""
	var text = "[b]🎮 Quantum Quest Test - Interactive Mode[/b]\n\n"

	text += "[color=yellow]Controls:[/color]\n"
	text += "  [b]SPACE[/b] - Manipulate quantum state\n"
	text += "  [b]I[/b] - Print detailed info to console\n"
	text += "  [b]R[/b] - Reset test\n"
	text += "  [b]ESC[/b] - Quit\n\n"

	text += "[color=cyan]Bath State:[/color]\n"
	if biome and biome.bath:
		for i in range(min(4, biome.bath.emoji_list.size())):
			var emoji = biome.bath.emoji_list[i]
			var amp = biome.bath.amplitudes[i]
			text += "  %s: amp=%.3f, φ=%.2f rad\n" % [emoji, amp.abs(), amp.arg()]

	text += "\n[color=lime]Projections:[/color]\n"
	if biome:
		var theta1 = biome.get_observable_theta("🌾", "💀")
		var coh1 = biome.get_observable_coherence("🌾", "💀")
		text += "  🌾↔💀: θ=%.2f rad, coherence=%.3f\n" % [theta1, coh1]

		var theta2 = biome.get_observable_theta("🍄", "🍂")
		var coh2 = biome.get_observable_coherence("🍄", "🍂")
		text += "  🍄↔🍂: θ=%.2f rad, coherence=%.3f\n" % [theta2, coh2]

	text += "\n[color=magenta]Active Quests:[/color]\n"
	if active_quests.is_empty():
		text += "  [i]No active quests[/i]\n"
	else:
		for quest in active_quests:
			var progress = quest.get_completion_percent()
			var status_color = "white"
			if quest.status == "completed":
				status_color = "green"
			elif quest.status == "failed":
				status_color = "red"

			text += "  [color=%s]%s[/color]\n" % [status_color, quest.title]
			text += "  Progress: [b]%.1f%%[/b]\n" % (progress * 100)

			# Show objectives
			for i in range(min(2, quest.objectives.size())):
				var obj = quest.objectives[i]
				var obj_progress = quest.progress.get(i, {})
				var completed = obj_progress.get("completed", false)
				var icon = "✅" if completed else "⏳"
				text += "    %s %s\n" % [icon, obj.get_summary()]

	text += "\n[color=gray]Manipulations: %d[/color]" % manipulation_count

	if info_label:
		info_label.text = text

func _display_error(message: String):
	"""Display error message"""
	if info_label:
		info_label.text = "[b][color=red]ERROR[/color][/b]\n\n" + message
	print(message)

# Signal handlers
func _on_quest_progress(quest_id: String, progress: float):
	print("📈 Quest progress: %s -> %.1f%%" % [quest_id, progress * 100])
	_update_display()

func _on_quest_completed(quest_id: String):
	print("✅ QUEST COMPLETED: %s" % quest_id)
	_update_display()

func _on_objective_completed(quest_id: String, obj_index: int):
	print("✓ Objective %d completed in quest %s" % [obj_index, quest_id])
	_update_display()
