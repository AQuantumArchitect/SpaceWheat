#!/usr/bin/env -S godot --headless -s
extends SceneTree

## CLAUDE QUEST PROGRESSION TEST
##
## Tests the complete quest → vocabulary → faction unlock loop:
##   1. Start with initial vocabulary (🌾, 👥)
##   2. Get quest offers from accessible factions
##   3. Accept and complete quests
##   4. Receive vocabulary rewards
##   5. Unlock new factions with expanded vocabulary
##   6. Complete quests for newly accessible factions
##
## Run: godot --headless --script Tests/claude_quest_progression.gd

const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")
const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")
const GameState = preload("res://Core/GameState/GameState.gd")
const GameStateManagerScript = preload("res://Core/GameState/GameStateManager.gd")

# Game references
var game_state_manager = null  # Autoload reference
var farm = null
var biotic_flux = null
var plot_pool = null
var economy = null
var quest_manager = null

# Test stats
var test_stats = {
	"initial_vocab_size": 0,
	"final_vocab_size": 0,
	"initial_factions_accessible": 0,
	"final_factions_accessible": 0,
	"quests_offered": 0,
	"quests_accepted": 0,
	"quests_completed": 0,
	"vocab_pairs_learned": [],
	"factions_unlocked": [],
	"harvest_cycles": 0,
	"resources_harvested": {}
}

# Config
const MAX_HARVEST_CYCLES = 100  # Max harvests to accumulate resources
const TARGET_QUESTS_COMPLETED = 5  # Try to complete this many quests
const RESOURCE_TARGET_MULTIPLIER = 2  # Harvest 2x needed resources

var scene_loaded = false
var game_ready = false
var frame_count = 0


func _init():
	print("")
	print("═".repeat(80))
	print("  🎯 CLAUDE QUEST PROGRESSION TEST")
	print("  Complete Quest → Vocabulary → Faction Unlock Loop")
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
	else:
		print("❌ Failed to load scene")
		quit(1)


func _on_game_ready():
	if game_ready:
		return
	game_ready = true
	print("\n🎯 Game ready! Starting quest progression test...\n")

	_find_components()
	if not _validate_components():
		quit(1)
		return

	await _run_quest_progression_test()
	_print_final_report()
	quit(0)


func _find_components():
	# Get autoloads
	game_state_manager = root.get_node_or_null("/root/GameStateManager")

	var farm_view = root.get_node_or_null("FarmView")
	if farm_view and "farm" in farm_view:
		farm = farm_view.farm
		economy = farm.economy if farm else null
		biotic_flux = farm.biotic_flux_biome if farm else null
		plot_pool = farm.terminal_pool if farm else null

	var player_shell = _find_node(root, "PlayerShell")
	if player_shell and "quest_manager" in player_shell:
		quest_manager = player_shell.quest_manager
		if quest_manager and economy and quest_manager.has_method("connect_to_economy"):
			quest_manager.connect_to_economy(economy)
		if quest_manager and biotic_flux and quest_manager.has_method("connect_to_biome"):
			quest_manager.connect_to_biome(biotic_flux)

	print("📋 Components: Farm=%s Economy=%s BioticFlux=%s PlotPool=%s QuestManager=%s GSM=%s" % [
		farm != null, economy != null, biotic_flux != null, plot_pool != null, quest_manager != null, game_state_manager != null])


func _validate_components() -> bool:
	return farm != null and economy != null and biotic_flux != null and plot_pool != null and quest_manager != null and game_state_manager != null


func _find_node(parent: Node, target_name: String) -> Node:
	if parent.name == target_name:
		return parent
	for child in parent.get_children():
		var result = _find_node(child, target_name)
		if result:
			return result
	return null


func _run_quest_progression_test():
	print("\n" + "─".repeat(80))
	print("🚀 STARTING QUEST PROGRESSION TEST")
	print("─".repeat(80))

	# ═══════════════════════════════════════════════════════════════════════════
	# PHASE 1: Initialize player vocabulary
	# ═══════════════════════════════════════════════════════════════════════════
	print("\n📖 PHASE 1: Initialize vocabulary")

	# Ensure GameStateManager has a current state
	if not game_state_manager.current_state:
		game_state_manager.current_state = GameState.new()

	# Set initial vocabulary (🌾 and 👥 as per design)
	game_state_manager.current_state.known_pairs = [
		{"north": "🌾", "south": "👥"},
	]

	# Also add starting pairs from BioticFlux biome
	var biotic_pairs = [
		{"north": "☀", "south": "🌙"},
		{"north": "🌾", "south": "🍄"},
		{"north": "🍂", "south": "💀"}
	]
	for pair in biotic_pairs:
		game_state_manager.discover_pair(pair.north, pair.south)

	var initial_known = game_state_manager.current_state.get_known_emojis()
	test_stats["initial_vocab_size"] = initial_known.size()
	print("   Initial vocabulary: %s (%d emojis)" % [
		", ".join(initial_known),
		test_stats["initial_vocab_size"]
	])

	# ═══════════════════════════════════════════════════════════════════════════
	# PHASE 2: Check accessible factions
	# ═══════════════════════════════════════════════════════════════════════════
	print("\n🏛️ PHASE 2: Check accessible factions")

	var accessible = game_state_manager.get_accessible_factions()
	test_stats["initial_factions_accessible"] = accessible.size()
	print("   Accessible factions: %d" % accessible.size())
	for faction in accessible.slice(0, 5):  # Show first 5
		var sig = faction.get("sig", [])
		print("   - %s %s" % ["".join(sig.slice(0, 3)), faction.get("name", "?")])
	if accessible.size() > 5:
		print("   ... and %d more" % (accessible.size() - 5))

	# ═══════════════════════════════════════════════════════════════════════════
	# PHASE 3: Get quest offers and select one
	# ═══════════════════════════════════════════════════════════════════════════
	print("\n📜 PHASE 3: Get quest offers")

	var completed_count = 0
	var attempts = 0
	var max_attempts = TARGET_QUESTS_COMPLETED * 3  # Allow some failures

	while completed_count < TARGET_QUESTS_COMPLETED and attempts < max_attempts:
		attempts += 1

		# Get fresh quest offers
		var all_quests = quest_manager.offer_all_faction_quests(biotic_flux)
		test_stats["quests_offered"] += all_quests.size()

		if all_quests.is_empty():
			print("   ⚠️ No quest offers available!")
			break

		# Filter to delivery quests only (easier to test programmatically)
		var delivery_quests = all_quests.filter(func(q):
			return q.get("type", 0) == 0  # DELIVERY type
		)

		if delivery_quests.is_empty():
			print("   ⚠️ No delivery quests available, trying any quest...")
			delivery_quests = all_quests

		# Pick a quest (prefer ones with resources we can harvest)
		var selected_quest = _select_feasible_quest(delivery_quests)
		if selected_quest.is_empty():
			print("   ⚠️ No feasible quest found")
			continue

		print("\n   Quest %d: %s from %s" % [
			completed_count + 1,
			selected_quest.get("body", "?"),
			selected_quest.get("faction", "?")
		])

		# Show reward preview
		var reward_north = selected_quest.get("reward_vocab_north", "")
		var reward_south = selected_quest.get("reward_vocab_south", "")
		if reward_north != "" or reward_south != "":
			print("   Reward: %s/%s vocabulary pair" % [reward_north, reward_south])

		# ═══════════════════════════════════════════════════════════════════════
		# PHASE 4: Accept quest
		# ═══════════════════════════════════════════════════════════════════════
		if not quest_manager.accept_quest(selected_quest):
			print("   ❌ Failed to accept quest")
			continue

		test_stats["quests_accepted"] += 1
		print("   ✓ Quest accepted")

		# ═══════════════════════════════════════════════════════════════════════
		# PHASE 5: Harvest resources to fulfill quest
		# ═══════════════════════════════════════════════════════════════════════
		var required_emoji = selected_quest.get("resource", "")
		var required_qty = selected_quest.get("quantity", 1)
		var required_credits = required_qty * EconomyConstants.QUANTUM_TO_CREDITS * RESOURCE_TARGET_MULTIPLIER

		print("   Harvesting %s (need %d credits)..." % [required_emoji, required_credits])

		var harvest_success = await _harvest_until_resource(required_emoji, required_credits)
		if not harvest_success:
			print("   ⚠️ Could not harvest enough %s, skipping quest" % required_emoji)
			quest_manager.fail_quest(selected_quest["id"], "insufficient_resources")
			continue

		var current_amount = economy.get_resource(required_emoji)
		print("   ✓ Harvested %s: %d credits" % [required_emoji, current_amount])

		# ═══════════════════════════════════════════════════════════════════════
		# PHASE 6: Complete quest and receive vocabulary
		# ═══════════════════════════════════════════════════════════════════════
		var vocab_before = game_state_manager.current_state.get_known_emojis().duplicate()

		if quest_manager.complete_quest(selected_quest["id"]):
			test_stats["quests_completed"] += 1
			completed_count += 1
			print("   ✓ Quest completed!")

			# Check for new vocabulary
			var vocab_after = game_state_manager.current_state.get_known_emojis()
			var new_emojis = vocab_after.filter(func(e): return e not in vocab_before)
			if new_emojis.size() > 0:
				print("   📖 Learned: %s" % ", ".join(new_emojis))
				test_stats["vocab_pairs_learned"].append({
					"north": reward_north,
					"south": reward_south,
					"faction": selected_quest.get("faction", "?")
				})

			# Check for newly accessible factions
			var new_accessible = game_state_manager.get_accessible_factions()
			var newly_unlocked = new_accessible.filter(func(f): return f not in accessible)
			if newly_unlocked.size() > 0:
				print("   🔓 Unlocked %d new faction(s)!" % newly_unlocked.size())
				for faction in newly_unlocked:
					test_stats["factions_unlocked"].append(faction.get("name", "?"))
					print("      - %s" % faction.get("name", "?"))
				accessible = new_accessible
		else:
			print("   ❌ Failed to complete quest")

		await _wait_frames(5)

	# ═══════════════════════════════════════════════════════════════════════════
	# PHASE 7: Final vocabulary and faction check
	# ═══════════════════════════════════════════════════════════════════════════
	print("\n📊 PHASE 7: Final state")

	var final_known = game_state_manager.current_state.get_known_emojis()
	test_stats["final_vocab_size"] = final_known.size()
	var final_accessible = game_state_manager.get_accessible_factions()
	test_stats["final_factions_accessible"] = final_accessible.size()

	print("   Final vocabulary: %d emojis" % test_stats["final_vocab_size"])
	print("   Known emojis: %s" % ", ".join(final_known))
	print("   Final accessible factions: %d" % test_stats["final_factions_accessible"])


func _select_feasible_quest(quests: Array) -> Dictionary:
	"""Select a quest that we can feasibly complete (harvestable resources)."""
	# Harvestable emojis from BioticFlux biome
	var harvestable = ["☀", "🌙", "🌾", "🍄", "🍂", "💀"]

	for quest in quests:
		var required = quest.get("resource", "")
		if required in harvestable:
			return quest

	# Fallback: return first quest
	return quests[0] if quests.size() > 0 else {}


func _harvest_until_resource(target_emoji: String, target_credits: int) -> bool:
	"""Harvest until we have enough of target resource."""
	var cycles = 0

	while cycles < MAX_HARVEST_CYCLES:
		cycles += 1
		test_stats["harvest_cycles"] += 1

		# Check if we have enough
		var current = economy.get_resource(target_emoji)
		if current >= target_credits:
			return true

		# Run harvest cycle
		var result = await _run_harvest_cycle()
		if result.has("resource"):
			var emoji = result["resource"]
			if not test_stats["resources_harvested"].has(emoji):
				test_stats["resources_harvested"][emoji] = 0
			test_stats["resources_harvested"][emoji] += result.get("credits", 0)

		await _wait_frames(1)

	# Check one more time
	return economy.get_resource(target_emoji) >= target_credits


func _run_harvest_cycle() -> Dictionary:
	"""Run a single explore → measure → pop cycle."""
	var result = {}

	# Explore
	var explore_result = ProbeActions.action_explore(plot_pool, biotic_flux)
	if not explore_result or not explore_result.success:
		return result

	var terminal = explore_result.terminal

	# Measure
	var measure_result = ProbeActions.action_measure(terminal, biotic_flux)
	if not measure_result or not measure_result.success:
		return result

	# Pop
	var pop_result = ProbeActions.action_pop(terminal, plot_pool, economy)
	if pop_result and pop_result.success:
		result = {
			"resource": pop_result.get("resource", ""),
			"credits": pop_result.get("credits", 0)
		}

	return result


func _wait_frames(n: int):
	for i in range(n):
		await process_frame


func _print_final_report():
	print("\n")
	print("═".repeat(80))
	print("  📊 QUEST PROGRESSION TEST - FINAL REPORT")
	print("═".repeat(80))

	print("\n📖 VOCABULARY PROGRESSION")
	print("   Initial: %d emojis" % test_stats["initial_vocab_size"])
	print("   Final: %d emojis" % test_stats["final_vocab_size"])
	print("   Growth: +%d emojis" % (test_stats["final_vocab_size"] - test_stats["initial_vocab_size"]))

	print("\n🏛️ FACTION ACCESS")
	print("   Initially accessible: %d factions" % test_stats["initial_factions_accessible"])
	print("   Finally accessible: %d factions" % test_stats["final_factions_accessible"])
	print("   Newly unlocked: %d factions" % test_stats["factions_unlocked"].size())
	if test_stats["factions_unlocked"].size() > 0:
		print("   Unlocked: %s" % ", ".join(test_stats["factions_unlocked"]))

	print("\n📜 QUEST ACTIVITY")
	print("   Quests offered: %d" % test_stats["quests_offered"])
	print("   Quests accepted: %d" % test_stats["quests_accepted"])
	print("   Quests completed: %d" % test_stats["quests_completed"])

	print("\n📖 VOCABULARY LEARNED")
	for pair in test_stats["vocab_pairs_learned"]:
		print("   %s/%s from %s" % [pair.north, pair.south, pair.faction])

	print("\n🌾 RESOURCES HARVESTED")
	print("   Total harvest cycles: %d" % test_stats["harvest_cycles"])
	for emoji in test_stats["resources_harvested"]:
		print("   %s: %d credits" % [emoji, test_stats["resources_harvested"][emoji]])

	print("\n" + "═".repeat(80))
	var vocab_growth = test_stats["final_vocab_size"] - test_stats["initial_vocab_size"]
	var faction_unlock = test_stats["factions_unlocked"].size()
	var quests_done = test_stats["quests_completed"]

	if quests_done >= TARGET_QUESTS_COMPLETED and vocab_growth > 0:
		print("✅ VERDICT: EXCELLENT - Completed %d quests, learned %d emojis, unlocked %d factions" % [
			quests_done, vocab_growth, faction_unlock
		])
	elif quests_done > 0 and vocab_growth > 0:
		print("✓ VERDICT: GOOD - Completed %d quests with vocabulary growth" % quests_done)
	elif quests_done > 0:
		print("⚠️ VERDICT: PARTIAL - Completed %d quests but no vocabulary growth" % quests_done)
	else:
		print("❌ VERDICT: FAILED - No quests completed")
	print("═".repeat(80))
