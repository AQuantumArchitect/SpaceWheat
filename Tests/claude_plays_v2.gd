#!/usr/bin/env -S godot --headless -s
extends SceneTree

## CLAUDE PLAYS v2 - Full Toolset Gameplay Session (Simulation Tools)
##
## Uses the complete v2 tool architecture:
##   Tool 1: PROBE (Explore/Measure/Pop)
##   Tool 2: GATES (X/H/Ry + Z/S/T via F-cycling)
##   Tool 3: ENTANGLE (CNOT/SWAP/CZ + Bell/Disentangle/Inspect via F-cycling)
##   Tool 4: INDUSTRY (Mill/Market/Kitchen)
##
## Run: godot --headless --script Tests/claude_plays_v2.gd
##
## Demonstrates:
## 1. Core harvest loop (EXPLORE → MEASURE → POP)
## 2. Strategic gate use for resource conversion
## 3. Entanglement creation and measurement correlation
## 4. Quest completion with targeted resource gathering

const Farm = preload("res://Core/Farm.gd")
const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")
const ProbeHandler = preload("res://UI/Handlers/ProbeHandler.gd")
const GateActionHandler = preload("res://UI/Handlers/GateActionHandler.gd")
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const QuestManager = preload("res://Core/Quests/QuestManager.gd")
const GameState = preload("res://Core/GameState/GameState.gd")
const LindbladBuilder = preload("res://Core/QuantumSubstrate/LindbladBuilder.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const QuantumInstrumentInput = preload("res://UI/Core/QuantumInstrumentInput.gd")
const SAVE_SLOT = 0

# Game references
var farm = null
var biotic_flux = null
var plot_pool = null
var economy = null
var quest_manager = null
var quantum_input = null

# Session stats
var session_stats = {
	"harvest_cycles": 0,
	"explore_success": 0,
	"measure_success": 0,
	"pop_success": 0,
	"gates_applied": {
		"X": 0, "H": 0, "Ry": 0,
		"Z": 0, "S": 0, "T": 0,
		"CNOT": 0, "SWAP": 0, "CZ": 0,
		"Bell": 0
	},
	"resources_harvested": {},
	"entanglements_created": 0,
	"quests_accepted": 0,
	"quests_completed": 0
}

# Config
const MAX_CYCLES = 50
const USE_GATES_PROBABILITY = 0.3  # 30% chance to use gates before measure
const USE_ENTANGLE_PROBABILITY = 0.1  # 10% chance to create entanglement

var grid_positions: Array[Vector2i] = []
var grid_position_index: int = 0
var entangle_positions: Array[Vector2i] = []
var entangle_position_index: int = 0
var last_injected_pair: Dictionary = {}


func _init():
	print("")
	print("═".repeat(80))
	print("  🤖 CLAUDE PLAYS v2")
	print("  Full Toolset Gameplay Session")
	print("═".repeat(80))
	print("")
	print("Tools available:")
	print("  1. PROBE 🔬: Explore → Measure → Pop")
	print("  2. GATES ⚡: X (flip), H (superpose), Ry (tune)")
	print("  3. ENTANGLE 🔗: CNOT, SWAP, CZ, Bell pairs")
	print("  4. INDUSTRY 🏭: Mill, Market, Kitchen")
	print("")
	call_deferred("_bootstrap")


func _bootstrap():
	print("🧪 Bootstrapping headless farm (no UI)...")

	farm = Farm.new()
	root.add_child(farm)

	for i in range(10):
		await process_frame

	if farm.has_method("rebuild_all_biome_operators"):
		farm.rebuild_all_biome_operators()
	if farm.has_method("finalize_setup"):
		farm.finalize_setup()
	if farm.has_method("enable_simulation"):
		farm.enable_simulation()

	economy = farm.economy if farm else null
	biotic_flux = farm.biotic_flux_biome if farm else null
	plot_pool = farm.plot_pool if farm else null

	_initialize_positions()

	if not _validate_components():
		quit(1)
		return

	await _ensure_quantum_input()
	_setup_quest_and_vocab()
	_harvest_new_vocab_pairs(3)
	_explore_vocab_space(3)
	await _inject_vocab_and_dissipation()
	await _run_bioticflux_wheat_drain_cycle()

	if _save_game_and_quit():
		return

	print("\n🎯 Game ready! Starting v2 gameplay session...\n")
	await _run_gameplay_session()
	_print_final_report()
	quit(0)


func _validate_components() -> bool:
	return farm != null and economy != null and biotic_flux != null and plot_pool != null


func _run_gameplay_session():
	print("\n" + "─".repeat(80))
	print("🚀 STARTING v2 GAMEPLAY SESSION (%d cycles)" % MAX_CYCLES)
	print("─".repeat(80))

	_print_resources("Initial")

	for cycle in range(MAX_CYCLES):
		session_stats["harvest_cycles"] += 1

		# Decide strategy for this cycle
		var use_gates = randf() < USE_GATES_PROBABILITY
		var use_entangle = randf() < USE_ENTANGLE_PROBABILITY

		# Run harvest cycle with optional tool use
		await _run_smart_harvest_cycle(cycle, use_gates, use_entangle)

		await _wait_frames(2)

		# Progress indicator
		if (cycle + 1) % 10 == 0:
			print("\n📊 Progress: %d/%d | Gates: %d | Entangle: %d" % [
				cycle + 1, MAX_CYCLES,
				_total_gates_applied(),
				session_stats["entanglements_created"]
			])
			_print_resources_compact()


func _run_smart_harvest_cycle(cycle: int, use_gates: bool, use_entangle: bool) -> Dictionary:
	"""Run a harvest cycle with optional gate/entanglement use."""
	var result = {"success": false}

	# ═══════════════════════════════════════════════════════════════
	# TOOL 1: PROBE - Explore
	# ═══════════════════════════════════════════════════════════════
	var pos = _next_position()
	var explore_result = ProbeHandler.explore(farm, plot_pool, [pos])
	if not explore_result or not explore_result.success:
		return result

	session_stats["explore_success"] += 1
	var terminal = plot_pool.get_terminal_at_grid_pos(pos)
	if not terminal:
		return result

	# ═══════════════════════════════════════════════════════════════
	# TOOL 2: GATES - Optional probability manipulation
	# ═══════════════════════════════════════════════════════════════
	if use_gates and terminal.is_bound and not terminal.is_measured:
		var gate_choice = randi() % 3
		match gate_choice:
			0:  # X gate - flip probabilities
				if _apply_gate_to_terminal(terminal, "X"):
					session_stats["gates_applied"]["X"] += 1
					print("  ⚡ Applied X gate (flip)")
			1:  # H gate - create superposition
				if _apply_gate_to_terminal(terminal, "H"):
					session_stats["gates_applied"]["H"] += 1
					print("  🌀 Applied H gate (superpose)")
			2:  # Ry gate - partial rotation
				if _apply_ry_gate_to_terminal(terminal, PI / 4):
					session_stats["gates_applied"]["Ry"] += 1
					print("  🎚️ Applied Ry gate (tune)")

	# ═══════════════════════════════════════════════════════════════
	# TOOL 3: ENTANGLE - Optional entanglement (need 2 terminals)
	# ═══════════════════════════════════════════════════════════════
	if use_entangle:
		if _try_entangle_pair():
				session_stats["entanglements_created"] += 1
				session_stats["gates_applied"]["Bell"] += 1
				print("  💑 Created Bell pair!")

	# ═══════════════════════════════════════════════════════════════
	# TOOL 1: PROBE - Measure
	# ═══════════════════════════════════════════════════════════════
	var measure_result = ProbeActions.action_measure(terminal, biotic_flux)
	if not measure_result or not measure_result.success:
		return result

	session_stats["measure_success"] += 1

	# ═══════════════════════════════════════════════════════════════
	# TOOL 1: PROBE - Pop/Harvest
	# ═══════════════════════════════════════════════════════════════
	var pop_result = ProbeActions.action_pop(terminal, plot_pool, economy)
	if not pop_result or not pop_result.success:
		return result

	session_stats["pop_success"] += 1
	_track_resource(pop_result)

	result = {"success": true}
	return result


func _track_resource(pop_result: Dictionary):
	"""Track harvested resource in stats."""
	var emoji = pop_result.get("resource", "")
	var credits = pop_result.get("credits", 0)
	if emoji != "":
		if not session_stats["resources_harvested"].has(emoji):
			session_stats["resources_harvested"][emoji] = 0
		session_stats["resources_harvested"][emoji] += int(credits)


func _apply_gate_to_terminal(terminal, gate_name: String) -> bool:
	"""Apply a 1-qubit gate using the handler pipeline."""
	if not terminal.is_bound or terminal.is_measured:
		return false

	var pos = terminal.grid_position
	if pos == Vector2i(-1, -1):
		return false

	var positions: Array[Vector2i] = [pos]
	var result: Dictionary = {}

	match gate_name:
		"X":
			result = GateActionHandler.apply_pauli_x(farm, positions)
		"H":
			result = GateActionHandler.apply_hadamard(farm, positions)
		_:
			return false

	return result.get("success", false)


func _apply_ry_gate_to_terminal(terminal, theta: float) -> bool:
	"""Apply Ry rotation gate (handler default)."""
	if not terminal.is_bound or terminal.is_measured:
		return false

	var pos = terminal.grid_position
	if pos == Vector2i(-1, -1):
		return false

	var positions: Array[Vector2i] = [pos]
	var result = GateActionHandler.apply_ry_gate(farm, positions)
	return result.get("success", false)


func _create_bell_pair(terminal1, terminal2) -> bool:
	"""Create Bell pair via handler pipeline."""
	if not terminal1 or not terminal2:
		return false

	var pos_a = terminal1.grid_position
	var pos_b = terminal2.grid_position
	if pos_a == Vector2i(-1, -1) or pos_b == Vector2i(-1, -1):
		return false

	var positions: Array[Vector2i] = [pos_a, pos_b]
	var result = GateActionHandler.create_bell_pair(farm, positions)
	return result.get("success", false)


func _try_entangle_pair() -> bool:
	var pair = _next_entangle_pair()
	if pair.is_empty():
		return false

	var terminal_a = _ensure_active_terminal(pair[0])
	var terminal_b = _ensure_active_terminal(pair[1])
	if not terminal_a or not terminal_b:
		return false

	return _create_bell_pair(terminal_a, terminal_b)


func _ensure_active_terminal(pos: Vector2i):
	var terminal = plot_pool.get_terminal_at_grid_pos(pos)
	if terminal and terminal.is_measured:
		ProbeActions.action_pop(terminal, plot_pool, economy)
		terminal = null

	if not terminal:
		var explore_result = ProbeHandler.explore(farm, plot_pool, [pos])
		if not explore_result or not explore_result.success:
			return null
		terminal = plot_pool.get_terminal_at_grid_pos(pos)

	if terminal and terminal.is_bound and not terminal.is_measured:
		return terminal

	return null


func _total_gates_applied() -> int:
	var total = 0
	for gate in session_stats["gates_applied"]:
		total += session_stats["gates_applied"][gate]
	return total


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
	print("   %s" % (resources_str if resources_str != "" else "(empty)"))


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
		print("   💰 %s" % resources_str)


func _wait_frames(n: int):
	for i in range(n):
		await process_frame


func _initialize_positions():
	grid_positions.clear()
	entangle_positions.clear()
	grid_position_index = 0
	entangle_position_index = 0

	var grid_width = farm.grid.grid_width if farm and farm.grid else 6
	var grid_height = farm.grid.grid_height if farm and farm.grid else 4

	for y in range(grid_height):
		for x in range(grid_width):
			grid_positions.append(Vector2i(x, y))

	# Use first biome row for entanglement (BioticFlux)
	for x in range(grid_width):
		entangle_positions.append(Vector2i(x, 0))


func _next_position() -> Vector2i:
	if grid_positions.is_empty():
		return Vector2i.ZERO
	var pos = grid_positions[grid_position_index % grid_positions.size()]
	grid_position_index += 1
	return pos


func _next_entangle_pair() -> Array[Vector2i]:
	if entangle_positions.size() < 2:
		return []
	var pos_a = entangle_positions[entangle_position_index % entangle_positions.size()]
	var pos_b = entangle_positions[(entangle_position_index + 1) % entangle_positions.size()]
	entangle_position_index = (entangle_position_index + 2) % entangle_positions.size()
	return [pos_a, pos_b]


func _setup_quest_and_vocab():
	print("\n🧭 Quest/Vocab access check")

	var gsm = root.get_node_or_null("/root/GameStateManager")
	if gsm:
		if gsm.current_state == null:
			if gsm.has_method("new_game"):
				gsm.new_game("default")
			else:
				gsm.current_state = GameState.new()
		gsm.active_farm = farm
	else:
		print("⚠️ GameStateManager not available; vocab will be local only")

	quest_manager = QuestManager.new()
	root.add_child(quest_manager)
	quest_manager.connect_to_economy(economy)
	quest_manager.connect_to_biome(biotic_flux)

	_print_vocab_snapshot("Initial")

	var offers = quest_manager.offer_all_faction_quests(biotic_flux)
	print("📜 Quest offers available: %d" % offers.size())
	if offers.is_empty():
		return

	var quest = offers[0]
	var required = quest.get("resource", "")
	var qty = quest.get("quantity", 0)
	var faction = quest.get("faction", "Unknown")
	print("🧪 Sample quest: %s wants %d %s" % [faction, qty, required])

	if required != "" and qty > 0:
		if economy.get_resource(required) < qty:
			var deficit = qty - economy.get_resource(required)
			economy.add_resource(required, deficit, "quest_test_boost")

		if quest_manager.accept_quest(quest):
			session_stats["quests_accepted"] += 1
			if quest_manager.complete_quest(quest["id"]):
				session_stats["quests_completed"] += 1
				_print_vocab_snapshot("After Quest")


func _print_vocab_snapshot(label: String):
	var gsm = root.get_node_or_null("/root/GameStateManager")
	if not gsm or not gsm.current_state:
		print("📖 %s vocab: (unavailable)" % label)
		return

	var pairs = gsm.current_state.known_pairs
	var emojis = gsm.current_state.get_known_emojis()
	print("📖 %s vocab: %d emojis, %d pairs" % [label, emojis.size(), pairs.size()])


func _ensure_quantum_input():
	if quantum_input:
		return

	quantum_input = QuantumInstrumentInput.new()
	root.add_child(quantum_input)
	await process_frame
	quantum_input.inject_farm(farm)
	_set_quantum_input_selection("BioticFlux", 0)
	ToolConfig.select_group(4)


func _set_quantum_input_selection(biome_name: String, plot_idx: int) -> void:
	if not quantum_input:
		return
	quantum_input.current_selection = {
		"plot_idx": plot_idx,
		"biome": biome_name,
		"direction": 0
	}


func _harvest_new_vocab_pairs(max_pairs: int) -> void:
	if not quest_manager or not economy or not biotic_flux:
		return

	var gsm = root.get_node_or_null("/root/GameStateManager")
	if not gsm or not gsm.current_state:
		return

	var before_pairs = gsm.current_state.known_pairs.size()
	var harvested = 0

	var offers = quest_manager.offer_all_faction_quests(biotic_flux)
	for quest in offers:
		if harvested >= max_pairs:
			break

		var required = quest.get("resource", "")
		var qty = quest.get("quantity", 0)
		if required != "" and qty > 0:
			var have = economy.get_resource(required)
			if have < qty:
				economy.add_resource(required, qty - have, "vocab_harvest_boost")

		if quest_manager.accept_quest(quest):
			session_stats["quests_accepted"] += 1
			if required != "" and qty > 0:
				if quest_manager.complete_quest(quest["id"]):
					session_stats["quests_completed"] += 1
					harvested += 1

	var after_pairs = gsm.current_state.known_pairs.size()
	if harvested > 0:
		print("📖 Harvested %d vocab pairs (pairs: %d → %d)" % [harvested, before_pairs, after_pairs])


func _explore_vocab_space(max_injections: int):
	if not quantum_input or not biotic_flux or not economy:
		return

	ToolConfig.select_group(4)
	_set_quantum_input_selection("BioticFlux", 0)

	var budget = EconomyConstants.VOCAB_INJECTION_BASE_COST * max_injections
	economy.add_resource("💰", budget, "vocab_injection_seed")

	print("\n🧭 Exploring vocabulary space (up to %d injections)" % max_injections)
	_print_vocab_space("Before injection", biotic_flux)

	for i in range(max_injections):
		var result = _inject_vocab_via_action()
		if not result.success:
			print("⚠️ Injection failed: %s" % result.get("message", result.get("error", "unknown")))
			break

		last_injected_pair = {
			"north": result.get("north_emoji", ""),
			"south": result.get("south_emoji", "")
		}
		print("✅ Injected vocab %s/%s into %s" % [
			result.get("north_emoji", "?"),
			result.get("south_emoji", "?"),
			result.get("biome", "biome")
		])

	_print_vocab_space("After injection", biotic_flux)


func _inject_vocab_via_action() -> Dictionary:
	if not quantum_input:
		return {"success": false, "error": "no_quantum_input"}

	ToolConfig.select_group(4)
	_set_quantum_input_selection("BioticFlux", 0)
	return quantum_input._action_inject_vocabulary()


func _print_vocab_space(label: String, biome) -> void:
	var gsm = root.get_node_or_null("/root/GameStateManager")
	if not gsm or not gsm.current_state or not biome or not biome.quantum_computer:
		print("📖 %s vocab space: (unavailable)" % label)
		return

	var injected: Array[String] = []
	var pending: Array[String] = []

	for pair in gsm.current_state.known_pairs:
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north == "" or south == "":
			continue
		var in_biome = biome.quantum_computer.register_map.has(north) or biome.quantum_computer.register_map.has(south)
		var label_pair = "%s/%s" % [north, south]
		if in_biome:
			injected.append(label_pair)
		else:
			pending.append(label_pair)

	print("📖 %s vocab space: %d injected, %d pending" % [label, injected.size(), pending.size()])
	print("   injected: %s" % _format_pair_list(injected, 6))
	print("   pending: %s" % _format_pair_list(pending, 6))


func _format_pair_list(pairs: Array, limit: int) -> String:
	if pairs.is_empty():
		return "(none)"

	var shown: Array = []
	for i in range(min(limit, pairs.size())):
		shown.append(pairs[i])

	var text = ", ".join(shown)
	if pairs.size() > limit:
		text += " ..."
	return text


func _save_game_and_quit() -> bool:
	var gsm = root.get_node_or_null("/root/GameStateManager")
	if not gsm:
		print("⚠️ GameStateManager not found; skipping save")
		return false

	if gsm.save_game(SAVE_SLOT):
		print("💾 Saved game to slot %d" % (SAVE_SLOT + 1))
	else:
		print("⚠️ Save failed for slot %d" % (SAVE_SLOT + 1))
		return false

	quit(0)
	return true
func _inject_vocab_and_dissipation():
	print("\n🧪 Vocab injection + 2Q Lindblad dissipation")
	if not biotic_flux or not biotic_flux.quantum_computer:
		print("⚠️ BioticFlux not ready; skipping")
		return

	var gsm = root.get_node_or_null("/root/GameStateManager")
	if not gsm or not gsm.current_state:
		print("⚠️ GameState not ready; skipping")
		return

	var qc = biotic_flux.quantum_computer
	var pair: Dictionary = {}
	var injected = false

	if not last_injected_pair.is_empty():
		pair = last_injected_pair
		injected = true
	else:
		var action_result = _inject_vocab_via_action()
		if action_result.get("success", false):
			injected = true
			pair = {
				"north": action_result.get("north_emoji", ""),
				"south": action_result.get("south_emoji", "")
			}
			last_injected_pair = pair
			print("✅ Injected pair %s/%s into BioticFlux (via 4Q action)" % [
				pair.get("north", ""), pair.get("south", "")
			])
		else:
			pair = _pick_injectable_pair(gsm.current_state.known_pairs, qc)
			if pair.is_empty():
				print("⚠️ No injectable vocab pair found; using most recent pair for dissipation only")
				pair = _pick_recent_pair(gsm.current_state.known_pairs)

	if pair.is_empty():
		print("⚠️ No vocab pair available; skipping dissipation test")
		return

	var target_emoji = _pick_target_emoji(pair, qc)
	if target_emoji == "":
		print("⚠️ Target emoji not available in biome; skipping dissipation test")
		return

	var source_emoji = _pick_source_emoji_for_lindblad(target_emoji, qc)
	if source_emoji == "":
		print("⚠️ No suitable source emoji for 2Q Lindblad; skipping")
		return

	var source_q = qc.qubit(source_emoji)
	var target_q = qc.qubit(target_emoji)
	if source_q == target_q:
		print("⚠️ Source/target on same qubit; 2Q Lindblad not possible")
		return

	var before = _snapshot_quantum_state(qc, source_emoji, target_emoji)
	_print_quantum_snapshot("Before dissipation", before)

	var added = _add_2q_lindblad_jump(qc, source_emoji, target_emoji, 0.25)
	if not added:
		print("⚠️ Failed to add Lindblad operator")
		return

	var prev_paused = biotic_flux.evolution_paused
	biotic_flux.evolution_paused = true
	for i in range(10):
		qc.evolve(0.2)
	biotic_flux.evolution_paused = prev_paused

	var after = _snapshot_quantum_state(qc, source_emoji, target_emoji)
	_print_quantum_snapshot("After dissipation", after)

	if injected:
		var reg_id = qc.qubit(target_emoji)
		_try_harvest_register(reg_id, target_emoji, 3)

	var after_harvest = _snapshot_quantum_state(qc, source_emoji, target_emoji)
	_print_quantum_snapshot("After harvest", after_harvest)


func _run_bioticflux_wheat_drain_cycle():
	print("\n🧪 Persistent Lindblad drain (BioticFlux wheat)")
	if not farm or not biotic_flux or not quantum_input:
		print("⚠️ Missing farm/biotic_flux/quantum_input; skipping")
		return

	var qc = biotic_flux.quantum_computer
	if not qc:
		print("⚠️ BioticFlux quantum computer not ready; skipping")
		return

	var pos = Vector2i(0, 0)
	var plot = farm.grid.get_plot(pos)
	if plot and not plot.is_planted:
		plot.north_emoji = "🌾"
		plot.south_emoji = "🍄"
		plot.is_planted = true

	_set_quantum_input_selection("BioticFlux", 0)

	var before = qc.get_population("🌾")
	var result = quantum_input._action_drain()
	print("  Drain enabled: %s" % result.get("success", false))

	await _wait_frames(30)

	var after = qc.get_population("🌾")
	print("  Wheat population: %.4f → %.4f" % [before, after])


func _pick_injectable_pair(pairs: Array, qc) -> Dictionary:
	for i in range(pairs.size() - 1, -1, -1):
		var pair = pairs[i]
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north == "" or south == "":
			continue
		if qc.register_map.has(north) or qc.register_map.has(south):
			continue
		return {"north": north, "south": south}
	return {}


func _pick_recent_pair(pairs: Array) -> Dictionary:
	for i in range(pairs.size() - 1, -1, -1):
		var pair = pairs[i]
		if pair.get("north", "") != "" and pair.get("south", "") != "":
			return {"north": pair.get("north", ""), "south": pair.get("south", "")}
	return {}


func _pick_target_emoji(pair: Dictionary, qc) -> String:
	var north = pair.get("north", "")
	var south = pair.get("south", "")
	if north != "" and qc.register_map.has(north):
		return north
	if south != "" and qc.register_map.has(south):
		return south
	return ""


func _pick_source_emoji_for_lindblad(target_emoji: String, qc) -> String:
	var target_q = qc.qubit(target_emoji)
	var preferred = ["☀", "🌙", "🌾", "🍄", "🍂", "💀"]
	for emoji in preferred:
		if qc.register_map.has(emoji) and qc.qubit(emoji) != target_q:
			return emoji
	for emoji in qc.register_map.coordinates.keys():
		if qc.qubit(emoji) != target_q:
			return emoji
	return ""


func _add_2q_lindblad_jump(qc, source_emoji: String, target_emoji: String, rate: float) -> bool:
	var source_q = qc.qubit(source_emoji)
	var source_p = qc.pole(source_emoji)
	var target_q = qc.qubit(target_emoji)
	var target_p = qc.pole(target_emoji)

	if source_q == -1 or target_q == -1:
		return false

	var amplitude = Complex.new(sqrt(rate), 0.0)
	var op = LindbladBuilder._build_jump(
		source_q, source_p,
		target_q, target_p,
		amplitude,
		qc.register_map.num_qubits
	)

	if op == null:
		return false

	var operators = qc.lindblad_operators.duplicate()
	operators.append(op)
	qc.set_lindblad_operators(operators)
	print("⚡ Added 2Q Lindblad: %s → %s (γ=%.2f)" % [source_emoji, target_emoji, rate])
	return true


func _snapshot_quantum_state(qc, source_emoji: String, target_emoji: String) -> Dictionary:
	var source_q = qc.qubit(source_emoji)
	var target_q = qc.qubit(target_emoji)
	var snapshot = {
		"source": source_emoji,
		"target": target_emoji,
		"p_source": qc.get_population(source_emoji),
		"p_target": qc.get_population(target_emoji),
		"purity": qc.get_purity(),
		"trace": qc.get_trace(),
		"mutual": -1.0
	}
	if source_q != -1 and target_q != -1 and source_q != target_q:
		snapshot["mutual"] = qc.get_mutual_information(source_q, target_q)
	return snapshot


func _print_quantum_snapshot(label: String, snapshot: Dictionary) -> void:
	print("\n📡 %s" % label)
	print("   P(%s)=%.4f | P(%s)=%.4f" % [
		snapshot.get("source", "?"), snapshot.get("p_source", 0.0),
		snapshot.get("target", "?"), snapshot.get("p_target", 0.0)
	])
	print("   purity=%.4f trace=%.4f" % [
		snapshot.get("purity", 0.0),
		snapshot.get("trace", 0.0)
	])
	if snapshot.get("mutual", -1.0) >= 0.0:
		print("   mutual_info=%.4f bits" % snapshot.get("mutual", 0.0))


func _try_harvest_register(register_id: int, target_emoji: String, attempts: int) -> void:
	for i in range(attempts):
		var terminal = plot_pool.get_unbound_terminal()
		if not terminal:
			print("⚠️ No free terminals for harvest")
			return

		var pair = biotic_flux.get_register_emoji_pair(register_id)
		if pair.is_empty():
			print("⚠️ Register %d has no emoji pair" % register_id)
			return

		if not plot_pool.bind_terminal(terminal, register_id, biotic_flux, pair):
			print("⚠️ Failed to bind terminal for harvest")
			return

		var measure = ProbeActions.action_measure(terminal, biotic_flux)
		if not measure or not measure.success:
			print("⚠️ Measure failed during harvest")
			return

		var pop = ProbeActions.action_pop(terminal, plot_pool, economy)
		if pop and pop.success:
			print("🍞 Harvested %s (attempt %d/%d)" % [pop.resource, i + 1, attempts])
			if pop.resource == target_emoji:
				return

func _print_final_report():
	print("\n")
	print("═".repeat(80))
	print("  📊 CLAUDE PLAYS v2 - SESSION REPORT")
	print("═".repeat(80))

	print("\n🔬 TOOL 1: PROBE (Core Loop)")
	print("   Cycles: %d" % session_stats["harvest_cycles"])
	print("   EXPLORE: %d (%d%%)" % [
		session_stats["explore_success"],
		100 * session_stats["explore_success"] / max(1, session_stats["harvest_cycles"])
	])
	print("   MEASURE: %d (%d%%)" % [
		session_stats["measure_success"],
		100 * session_stats["measure_success"] / max(1, session_stats["harvest_cycles"])
	])
	print("   POP: %d (%d%%)" % [
		session_stats["pop_success"],
		100 * session_stats["pop_success"] / max(1, session_stats["harvest_cycles"])
	])

	print("\n⚡ TOOL 2: GATES (1-Qubit)")
	print("   X (Flip): %d" % session_stats["gates_applied"]["X"])
	print("   H (Superpose): %d" % session_stats["gates_applied"]["H"])
	print("   Ry (Tune): %d" % session_stats["gates_applied"]["Ry"])

	print("\n🔗 TOOL 3: ENTANGLE (2-Qubit)")
	print("   Bell Pairs: %d" % session_stats["gates_applied"]["Bell"])
	print("   Total Entanglements: %d" % session_stats["entanglements_created"])

	print("\n💰 RESOURCES HARVESTED:")
	var total_credits = 0
	for emoji in session_stats["resources_harvested"]:
		var credits = session_stats["resources_harvested"][emoji]
		total_credits += credits
		var units = credits / EconomyConstants.QUANTUM_TO_CREDITS
		print("   %s: %d credits (%d units)" % [emoji, credits, units])
	print("   ─────────────────")
	print("   Total: %d credits" % total_credits)

	_print_resources("Final Economy")

	print("\n" + "═".repeat(80))
	var success_rate = 100 * session_stats["pop_success"] / max(1, session_stats["harvest_cycles"])
	if success_rate >= 90:
		print("✅ VERDICT: EXCELLENT - %d%% harvest success, %d gates applied" % [success_rate, _total_gates_applied()])
	elif success_rate >= 70:
		print("✓ VERDICT: GOOD - %d%% harvest success" % success_rate)
	else:
		print("⚠️ VERDICT: NEEDS ATTENTION - %d%% harvest success" % success_rate)
	print("═".repeat(80))
