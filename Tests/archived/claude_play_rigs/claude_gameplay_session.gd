#!/usr/bin/env -S godot --headless -s
extends SceneTree

## CLAUDE GAMEPLAY SESSION - Full Quest + Vocabulary Test
## Uses v2 architecture (ProbeActions + Terminal system)
##
## Run: godot --headless --script Tests/claude_gameplay_session.gd
##
## Goals:
## 1. Harvest resources using 1QER tools (EXPLORE/MEASURE/POP)
## 2. Accept and complete quests
## 3. Learn new vocabulary from quest rewards
## 4. Track all progress and report statistics

const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")

# Game references
var farm = null
var biotic_flux = null
var plot_pool = null
var economy = null
var quest_manager = null
var game_state_manager = null

# Session stats
var session_stats = {
	"harvest_cycles": 0,
	"explore_success": 0,
	"measure_success": 0,
	"pop_success": 0,
	"resources_harvested": {},
	"quests_accepted": 0,
	"quests_completed": 0,
	"vocabulary_before": [],
	"vocabulary_after": [],
	"vocabulary_learned": []
}

# Config
const MAX_CYCLES = 100  # Harvest cycles to run
const CYCLES_BETWEEN_QUEST_CHECK = 10  # Check quests every N cycles

var scene_loaded = false
var game_ready = false
var frame_count = 0


func _init():
	print("")
	print("═".repeat(80))
	print("  🎮 CLAUDE GAMEPLAY SESSION")
	print("  Full Quest + Vocabulary Learning Playtest")
	print("═".repeat(80))
	print("")


func _process(_delta):
	frame_count += 1

	if frame_count == 5 and not scene_loaded:
		_load_scene()


func _load_scene():
	print("📦 Loading FarmView...")
	var scene = load("res://scenes/FarmView.tscn")
	if scene:
		var instance = scene.instantiate()
		root.add_child(instance)
		scene_loaded = true

		var boot = root.get_node_or_null("/root/BootManager")
		if boot:
			boot.game_ready.connect(_on_game_ready)
			print("✅ Connected to BootManager.game_ready")
	else:
		print("❌ Failed to load FarmView.tscn")
		quit(1)


func _on_game_ready():
	if game_ready:
		return
	game_ready = true

	print("\n🎯 Game ready! Starting gameplay session...\n")

	_find_components()

	if not _validate_components():
		quit(1)
		return

	# Record initial vocabulary
	_record_initial_vocabulary()

	# Run gameplay session
	await _run_gameplay_session()

	# Print final report
	_print_final_report()

	quit(0)


func _find_components():
	var farm_view = root.get_node_or_null("FarmView")
	if farm_view and "farm" in farm_view:
		farm = farm_view.farm
		economy = farm.economy if farm else null
		biotic_flux = farm.biotic_flux_biome if farm else null
		plot_pool = farm.terminal_pool if farm else null

	# Find quest manager (it's in PlayerShell)
	var player_shell = _find_node(root, "PlayerShell")
	if player_shell and "quest_manager" in player_shell:
		quest_manager = player_shell.quest_manager

	if not quest_manager:
		quest_manager = _find_node(root, "QuestManager")

	# Find game state manager
	game_state_manager = root.get_node_or_null("/root/GameStateManager")

	# Connect quest manager to economy
	if quest_manager and economy:
		if quest_manager.has_method("connect_to_economy"):
			quest_manager.connect_to_economy(economy)
			print("✅ Connected QuestManager to economy")

	print("📋 Components found:")
	print("   Farm: %s" % (farm != null))
	print("   Economy: %s" % (economy != null))
	print("   BioticFlux: %s" % (biotic_flux != null))
	print("   PlotPool: %s" % (plot_pool != null))
	print("   QuestManager: %s" % (quest_manager != null))
	print("   GameStateManager: %s" % (game_state_manager != null))


func _validate_components() -> bool:
	if not farm or not economy or not biotic_flux or not plot_pool:
		print("❌ Missing critical components for gameplay")
		return false
	return true


func _find_node(parent: Node, target_name: String) -> Node:
	if parent.name == target_name:
		return parent
	for child in parent.get_children():
		var result = _find_node(child, target_name)
		if result:
			return result
	return null


func _record_initial_vocabulary():
	if game_state_manager and "current_state" in game_state_manager:
		var state = game_state_manager.current_state
		if state and state.has_method("get_known_emojis"):
			session_stats["vocabulary_before"] = state.get_known_emojis().duplicate()

	print("\n📚 Initial vocabulary: %d emojis" % session_stats["vocabulary_before"].size())
	if session_stats["vocabulary_before"].size() > 0:
		print("   %s" % ", ".join(session_stats["vocabulary_before"].slice(0, 10)))
		if session_stats["vocabulary_before"].size() > 10:
			print("   ... and %d more" % (session_stats["vocabulary_before"].size() - 10))


func _run_gameplay_session():
	print("\n" + "─".repeat(80))
	print("🚀 STARTING GAMEPLAY SESSION (%d cycles)" % MAX_CYCLES)
	print("─".repeat(80))

	# Print initial resources
	_print_resources("Initial")

	# Check for available quests at start
	await _check_and_accept_quests()

	# Main gameplay loop
	for cycle in range(MAX_CYCLES):
		session_stats["harvest_cycles"] += 1

		# Run one harvest cycle (EXPLORE → MEASURE → POP)
		var result = await _run_harvest_cycle(cycle)

		# Check quests periodically
		if (cycle + 1) % CYCLES_BETWEEN_QUEST_CHECK == 0:
			await _check_quest_completion()
			await _check_and_accept_quests()

		# Brief pause for quantum evolution
		await _wait_frames(2)

		# Progress indicator
		if (cycle + 1) % 20 == 0:
			print("\n📊 Progress: %d/%d cycles | Resources:" % [cycle + 1, MAX_CYCLES])
			_print_resources_compact()

	# Final quest check
	await _check_quest_completion()

	# Record final vocabulary
	_record_final_vocabulary()


func _run_harvest_cycle(cycle: int) -> Dictionary:
	var result = {"success": false, "emoji": "", "credits": 0}

	# EXPLORE
	var explore_result = ProbeActions.action_explore(plot_pool, biotic_flux)
	if not explore_result or not explore_result.success:
		return result

	session_stats["explore_success"] += 1
	var terminal = explore_result.terminal

	# MEASURE
	var measure_result = ProbeActions.action_measure(terminal, biotic_flux)
	if not measure_result or not measure_result.success:
		return result

	session_stats["measure_success"] += 1

	# POP
	var pop_result = ProbeActions.action_pop(terminal, plot_pool, economy)
	if not pop_result or not pop_result.success:
		return result

	session_stats["pop_success"] += 1

	# Track harvested resource (key is "resource" not "emoji")
	var emoji = pop_result.get("resource", "")
	var credits = pop_result.get("credits", 0)

	if emoji != "":
		if not session_stats["resources_harvested"].has(emoji):
			session_stats["resources_harvested"][emoji] = 0
		session_stats["resources_harvested"][emoji] += int(credits)

	result = {"success": true, "emoji": emoji, "credits": credits}
	return result


func _check_and_accept_quests():
	if not quest_manager:
		return

	# Get active quest count - if we already have quests, skip
	var active_count = 0
	if quest_manager.has_method("get_active_quest_count"):
		active_count = quest_manager.get_active_quest_count()

	if active_count >= 2:  # Don't overload with quests
		return

	# Generate a quest offer using proper faction format
	# bits is a 5-element array: [b0, b1, b2, b3, b4]
	var faction = {
		"name": "🌾 Wheat Farmers' Guild",
		"bits": [randi() % 2, randi() % 2, 0, randi() % 2, randi() % 2],  # Common faction (bit 2 = 0)
		"signature": ["🌾", "👥", "🌻"],  # Faction emoji signature
		"description": "Agricultural collective"
	}
	var resources = ["🌾", "🍄", "🍂", "☀", "🌙", "💀"]

	if quest_manager.has_method("offer_quest"):
		var quest = quest_manager.offer_quest(faction, "BioticFlux", resources)

		if not quest.is_empty():
			if quest_manager.has_method("accept_quest"):
				var accepted = quest_manager.accept_quest(quest)
				if accepted:
					session_stats["quests_accepted"] += 1
					var title = quest.get("title", quest.get("body", "Unknown"))
					var required = quest.get("resource", "?")
					var qty = quest.get("quantity", 0)
					print("📜 Accepted quest: %s (need %d %s)" % [title, qty, required])


func _check_quest_completion():
	if not quest_manager:
		return

	if not quest_manager.has_method("get_active_quests"):
		return

	var active = quest_manager.get_active_quests()

	for quest in active:
		var quest_id = quest.get("id", -1)
		if quest_id < 0:
			continue

		# Check if quest can be completed
		if quest_manager.has_method("check_quest_completion"):
			var can_complete = quest_manager.check_quest_completion(quest_id)

			if can_complete:
				var title = quest.get("title", quest.get("body", "Unknown"))
				var required = quest.get("resource", "?")
				var qty = quest.get("quantity", 0)
				print("🎯 Quest ready to complete: %s (have enough %s)" % [title, required])

				if quest_manager.has_method("complete_quest"):
					var completed = quest_manager.complete_quest(quest_id)
					if completed:
						session_stats["quests_completed"] += 1
						print("🏆 Completed quest: %s" % title)


func _record_final_vocabulary():
	if game_state_manager and "current_state" in game_state_manager:
		var state = game_state_manager.current_state
		if state and state.has_method("get_known_emojis"):
			session_stats["vocabulary_after"] = state.get_known_emojis().duplicate()

	# Calculate learned vocabulary
	for emoji in session_stats["vocabulary_after"]:
		if emoji not in session_stats["vocabulary_before"]:
			session_stats["vocabulary_learned"].append(emoji)


func _print_resources(label: String):
	if not economy:
		return

	print("\n💰 %s Resources:" % label)
	var resources_str = ""
	for emoji in economy.emoji_credits.keys():
		var credits = economy.emoji_credits[emoji]
		var units = credits / EconomyConstants.QUANTUM_TO_CREDITS
		if units > 0 or credits > 0:
			resources_str += "%s:%d " % [emoji, units]

	if resources_str == "":
		print("   (empty)")
	else:
		print("   %s" % resources_str)


func _print_resources_compact():
	if not economy:
		return

	var resources_str = ""
	for emoji in economy.emoji_credits.keys():
		var credits = economy.emoji_credits[emoji]
		var units = credits / EconomyConstants.QUANTUM_TO_CREDITS
		if units > 0:
			resources_str += "%s:%d " % [emoji, units]

	if resources_str != "":
		print("   %s" % resources_str)


func _wait_frames(n: int):
	for i in range(n):
		await process_frame


func _print_final_report():
	print("\n")
	print("═".repeat(80))
	print("  📊 GAMEPLAY SESSION REPORT")
	print("═".repeat(80))

	print("\n🎯 HARVEST STATISTICS:")
	print("   Cycles completed: %d" % session_stats["harvest_cycles"])
	print("   EXPLORE success: %d (%d%%)" % [
		session_stats["explore_success"],
		100 * session_stats["explore_success"] / max(1, session_stats["harvest_cycles"])
	])
	print("   MEASURE success: %d (%d%%)" % [
		session_stats["measure_success"],
		100 * session_stats["measure_success"] / max(1, session_stats["harvest_cycles"])
	])
	print("   POP success: %d (%d%%)" % [
		session_stats["pop_success"],
		100 * session_stats["pop_success"] / max(1, session_stats["harvest_cycles"])
	])

	print("\n💰 RESOURCES HARVESTED:")
	if session_stats["resources_harvested"].is_empty():
		print("   (none)")
	else:
		var total_credits = 0
		for emoji in session_stats["resources_harvested"]:
			var credits = session_stats["resources_harvested"][emoji]
			total_credits += credits
			var units = credits / EconomyConstants.QUANTUM_TO_CREDITS
			print("   %s: %d credits (%d units)" % [emoji, credits, units])
		print("   ─────────────────")
		print("   Total: %d credits" % total_credits)

	_print_resources("Final")

	print("\n📜 QUEST STATISTICS:")
	print("   Quests accepted: %d" % session_stats["quests_accepted"])
	print("   Quests completed: %d" % session_stats["quests_completed"])

	print("\n📚 VOCABULARY:")
	print("   Before: %d emojis" % session_stats["vocabulary_before"].size())
	print("   After: %d emojis" % session_stats["vocabulary_after"].size())
	print("   Learned: %d new emojis" % session_stats["vocabulary_learned"].size())
	if session_stats["vocabulary_learned"].size() > 0:
		print("   New: %s" % ", ".join(session_stats["vocabulary_learned"]))

	print("\n" + "═".repeat(80))

	# Verdict
	var success_rate = 100 * session_stats["pop_success"] / max(1, session_stats["harvest_cycles"])
	if success_rate >= 90:
		print("✅ VERDICT: EXCELLENT - %d%% harvest success rate" % success_rate)
	elif success_rate >= 70:
		print("✓ VERDICT: GOOD - %d%% harvest success rate" % success_rate)
	else:
		print("⚠️ VERDICT: NEEDS ATTENTION - %d%% harvest success rate" % success_rate)

	print("═".repeat(80))
