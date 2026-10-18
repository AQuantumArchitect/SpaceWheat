extends "res://tests/smoke_test_base.gd"

## Captain [7] R = Chart (owner decision): story biomes are reached through a
## deliberate, NON-random Captain action that still costs the chart price.
## Boots a real farm (StarterForest) and drives the real Farm.discover_biome:
##   - no open door        → R is the random Add Biome (draws from the pool)
##   - woodlot_door open, 🦅 < 21 → R refuses, names holdings vs need, spends 0
##   - woodlot_door open, 🦅 ≥ 21 → R loads Woodlot (not a draw), spends 🦅×21
##   - chip/label reads "Chart Woodlot" while R will chart (mouse chip parity)
##   - two doors open → the first in story-flag file order is charted
##   - a resolved door no longer charts
## Run: godot --headless --script tests/captain_chart_smoke.gd

const ToolConfigScript = preload("res://Core/GameState/ToolConfig.gd")
const CaptainChips = preload("res://Core/UI/CaptainChipResolvers.gd")


class QMStub:
	extends Node
	var flags: Array = []
	var resolved: Dictionary = {}

	func get_all_story_flags() -> Array:
		return flags

	func flag_door_is_resolved(flag_id: String) -> bool:
		return bool(resolved.get(flag_id, false))


func _init() -> void:
	call_deferred("_run")


func _eagles(farm) -> int:
	return int(floor(float(farm.economy.get_resource("🦅"))))


func _set_eagles(farm, n: int) -> void:
	var have := _eagles(farm)
	if have < n:
		farm.economy.add_resource("🦅", n - have, "chart_smoke")
	elif have > n:
		farm.economy.remove_resource("🦅", have - n, "chart_smoke")


func _run() -> void:
	print("\n=== Captain chart smoke ===")
	var gsm = root.get_node_or_null("/root/GameStateManager")
	var observation_frame = root.get_node_or_null("/root/ObservationFrame")
	var boot_manager = root.get_node_or_null("/root/BootManager")
	if gsm == null or observation_frame == null or boot_manager == null:
		_fail("autoloads available")
		_finish("Captain chart smoke")
		return

	# Story flags in file order; a stub QM stands in for the shell-owned one.
	var qm := QMStub.new()
	qm.name = "QuestManager"
	var flags_res: Dictionary = preload("res://Core/Config/JsonFileLoader.gd").load_json(
			"res://Core/Quests/data/story_flags.json", {"context": "chart_smoke"})
	qm.flags = flags_res.get("data", []) if flags_res.get("data") is Array else []
	root.add_child(qm)
	_check(qm.flags.size() > 0, "story_flags.json loaded (%d flags)" % qm.flags.size())
	_check(str(CampaignRuntime.charts().get("woodlot_door", "")) == "Woodlot",
		"runtime charts woodlot_door → Woodlot")
	_check(int(CampaignRuntime.chart_cost().get("🦅", 0)) == 21, "chart cost is 🦅×21")

	var state = gsm.save_load.new_game()
	state.unlocked_biomes.clear()
	state.unlocked_biomes.append("StarterForest")
	state.active_biome_name = "StarterForest"
	gsm.current_state = state
	gsm.current_scenario_id = "new_game_easy"
	observation_frame.BIOME_ORDER.clear()
	observation_frame.BIOME_ORDER.append("StarterForest")
	if observation_frame.has_method("set_neutral_biome"):
		observation_frame.set_neutral_biome("StarterForest")
	var abm = root.get_node_or_null("/root/ActiveBiomeManager")
	if abm and abm.has_method("set_biome_order"):
		abm.set_biome_order(["StarterForest"])
		abm.set_active_biome("StarterForest")

	gsm.active_farm = gsm.session_lifecycle.create_farm()
	var farm = gsm.active_farm
	await gsm.session_lifecycle.await_farm_ready(farm)
	var biome_boot = boot_manager.boot_initial_biomes(farm, state)
	if not biome_boot.get("success", false):
		_fail("biome boot: %s" % str(biome_boot))
		_finish("Captain chart smoke")
		return
	if farm.has_method("finalize_initial_biome_boot"):
		farm.finalize_initial_biome_boot()
	await gsm.apply_state_to_game(state)
	var frames := 0
	while frames < 30 and (farm.grid == null or farm.economy == null):
		await process_frame
		frames += 1
	_check(farm.economy != null, "farm economy ready")

	# apply_state_to_game may restore flags/biomes from the fresh state — reset.
	farm.story_flags_fired.clear()
	observation_frame.BIOME_ORDER.clear()
	observation_frame.BIOME_ORDER.append("StarterForest")
	if abm and abm.has_method("set_biome_order"):
		abm.set_biome_order(["StarterForest"])

	# Curated random pool: loadable side biomes only (no chart biome in it).
	var chart_biomes: Array = CampaignRuntime.charts().values()
	var pool: Array[String] = []
	for b in observation_frame.ALL_BIOMES:
		var bn := str(b)
		if bn != "StarterForest" and not chart_biomes.has(bn) and pool.size() < 3:
			pool.append(bn)
	gsm.current_state.unexplored_biome_pool = pool.duplicate()
	_check(pool.size() >= 1, "side-biome pool %s" % str(pool))

	# --- 1. No open door: R is today's random Add Biome -------------------
	_check(farm.chart_target().is_empty(), "no fired door → nothing to chart")
	var r_info: Dictionary = ChipResolverRegistry.resolve(
			ToolConfigScript.get_action("captain", "R"), ChipContext.new(null, -1, false, farm))
	_check(str(r_info.get("label", "")) == "Add Biome", "chip reads Add Biome with no open door")
	_set_eagles(farm, 30)
	var before := _eagles(farm)
	var r1: Dictionary = farm.discover_biome()
	var drawn := str(r1.get("biome_name", ""))
	_check(bool(r1.get("success", false)), "random discovery succeeds: %s" % str(r1.get("message", "")))
	_check(pool.has(drawn), "random draw came from the side pool (%s)" % drawn)
	_check(not bool(r1.get("charted", false)), "random discovery is not a chart")
	_check(before - _eagles(farm) == 21, "Add Biome spent its 🦅×21 (%d→%d)" % [before, _eagles(farm)])

	# --- 2. woodlot_door open, 🦅 short: refuse, spend nothing -------------
	farm.story_flags_fired["woodlot_door"] = 0
	_check(farm.chart_target_biome() == "Woodlot", "woodlot_door open → chart target Woodlot")
	_set_eagles(farm, 10)
	var gate: Dictionary = farm.can_discover_biome()
	_check(not bool(gate.get("ok", true)), "chart gate refuses at 🦅×10")
	_check(bool(gate.get("chart_short", false)), "refusal is a chart shortfall")
	var msg := str(gate.get("message", ""))
	_check("Chart Woodlot" in msg and "🦅×21" in msg and "you hold 🦅×10" in msg,
		"refusal names need vs held: %s" % msg)
	_check(not ActionValidator.can_execute_action_name("discover_biome", farm, [], Vector2i(-1, -1)),
		"validator greys Captain R while short")
	var r2: Dictionary = farm.discover_biome()
	_check(not bool(r2.get("success", true)) and bool(r2.get("blocked", false)), "short chart is blocked")
	_check(_eagles(farm) == 10, "short chart spent nothing")
	_check(not observation_frame.get_unlocked_biomes().has("Woodlot"), "Woodlot not loaded on refusal")

	# --- 3. woodlot_door open, 🦅 ≥ 21: chart Woodlot deterministically ----
	_set_eagles(farm, 30)
	r_info = ChipResolverRegistry.resolve(
			ToolConfigScript.get_action("captain", "R"), ChipContext.new(null, -1, false, farm))
	_check(str(r_info.get("label", "")) == "Chart Woodlot", "chip reads Chart Woodlot (%s)" % str(r_info.get("label", "")))
	_check(str(r_info.get("action", "")) == "discover_biome", "chip still dispatches discover_biome")
	_check(int((r_info.get("cost", {}) as Dictionary).get("🦅", 0)) == 21, "chip advertises 🦅×21")
	var r3: Dictionary = farm.discover_biome()
	_check(bool(r3.get("success", false)), "chart succeeds: %s" % str(r3.get("message", "")))
	_check(str(r3.get("biome_name", "")) == "Woodlot", "chart loaded Woodlot, not a random biome")
	_check(bool(r3.get("charted", false)), "result is marked charted")
	_check(_eagles(farm) == 9, "chart spent 🦅×21 (30→%d)" % _eagles(farm))
	_check(observation_frame.get_unlocked_biomes().has("Woodlot"), "Woodlot is on the spindle")
	_check(not observation_frame.get_unexplored_biomes().has("Woodlot"), "Woodlot left the unexplored pool")
	_check(farm.chart_target().is_empty(), "loaded door biome no longer charts")

	# --- 4. two doors open: first in story-flag file order ----------------
	farm.story_flags_fired["lantern_door"] = 0
	farm.story_flags_fired["spring_door"] = 0
	_check(farm.chart_target_biome() == "FreshwaterSpring",
		"spring_door precedes lantern_door in file order (%s)" % farm.chart_target_biome())
	_check(CaptainChips.chart_patch(farm).get("label", "") == "Chart FreshwaterSpring",
		"controls/caption patch names the same biome")

	# --- 5. resolved doors stop charting ----------------------------------
	qm.resolved["spring_door"] = true
	_check(farm.chart_target_biome() == "Lanternfall", "resolved spring_door → next open door")
	qm.resolved["lantern_door"] = true
	_check(farm.chart_target().is_empty(), "all doors resolved → R back to random Add Biome")

	_finish("Captain chart smoke")
