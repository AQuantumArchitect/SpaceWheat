#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Fractal atlas control-flow — action_inject_icon_pair → enter_icon → ascend_fractal.
##
## Replaces test_fractal_atlas_mirror.py, which only reimplemented FractalAtlas.child_id's
## hash in Python and tested that copy against itself — it never touched Godot, so it could
## not have caught (and did not catch) a real bug: a patch spliced the fractal-registration
## block into action_inject_icon_pair at the wrong indentation, so it (1) ran unconditionally
## even when the injection itself failed, phantom-registering a fractal child world for an
## icon pair that was never actually added to the biome, and (2) nested north_emoji/
## south_emoji/cost/the story-notify call inside "if _fw:", silently dropping them from a
## SUCCESSFUL injection's result whenever the fractal service was unavailable. Fixed in
## QuantumInstrument.gd this session; this test exercises the real code path so it can't
## silently regress again.
##
## Run with: godot --headless -s tests/test_fractal_atlas_injection.gd


var _fail := 0


func _init() -> void:
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ %s" % msg)
	else:
		print("  ❌ %s" % msg)
		_fail += 1


func _run() -> void:
	print("\n======================================================================")
	print("TEST: Fractal atlas — inject_icon_pair → enter_icon → ascend_fractal")
	print("======================================================================\n")

	# --- Pure FractalAtlas.child_id assertions (no farm needed) — the real GDScript
	# class this time, not a Python reimplementation of its hash. ---
	print("[FractalAtlas] child_id determinism (real class, not a mirror):")
	var FA = load("res://Core/Instrumentation/FractalAtlas.gd")
	var id_a: String = FA.child_id("world:campaign:StarterForest", 0, "☀", "⚡")
	var id_a2: String = FA.child_id("world:campaign:StarterForest", 0, "☀", "⚡")
	var id_b: String = FA.child_id("world:campaign:StarterForest", 1, "☀", "⚡")
	_check(id_a == id_a2, "child_id is stable for identical inputs")
	_check(id_a.begins_with("icon:"), "child_id carries the icon: prefix")
	_check(id_a != id_b, "child_id differs by register_id")

	# --- Boot a farm with StarterForest (same boot sequence as test_vantage_strike.gd) ---
	var gsm = root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		printerr("no gsm"); quit(2); return
	var state = gsm.save_load.new_game()
	if state == null:
		printerr("no state"); quit(3); return
	state.unlocked_biomes.clear()
	state.unlocked_biomes.append("StarterForest")
	state.unexplored_biome_pool.clear()
	state.active_biome_name = "StarterForest"
	gsm.current_state = state
	gsm.current_scenario_id = "new_game_easy"

	var observation_frame = root.get_node_or_null("/root/ObservationFrame")
	if observation_frame:
		observation_frame.BIOME_ORDER.clear()
		observation_frame.BIOME_ORDER.append("StarterForest")
		if observation_frame.has_method("set_neutral_biome"):
			observation_frame.set_neutral_biome("StarterForest")
	var abm = root.get_node_or_null("/root/ActiveBiomeManager")
	if abm and abm.has_method("set_biome_order"):
		abm.set_biome_order(["StarterForest"])
		if abm.has_method("set_active_biome"):
			abm.set_active_biome("StarterForest")

	gsm.active_farm = gsm.session_lifecycle.create_farm()
	var farm = gsm.active_farm
	await gsm.session_lifecycle.await_farm_ready(farm)
	var boot_manager = root.get_node_or_null("/root/BootManager")
	if boot_manager == null:
		printerr("no boot manager"); quit(4); return
	var biome_boot = boot_manager.boot_initial_biomes(farm, state)
	if not biome_boot.get("success", false):
		printerr("biome boot failed: %s" % str(biome_boot)); quit(4); return
	if farm.has_method("finalize_initial_biome_boot") and not farm.finalize_initial_biome_boot():
		printerr("farm biome finalization failed"); quit(4); return
	await gsm.apply_state_to_game(state)

	var frames := 0
	while frames < 30 and (farm == null or farm.grid == null or farm.economy == null):
		await process_frame
		frames += 1

	if farm.instrument == null:
		var QI = load("res://Core/Instrumentation/QuantumInstrument.gd")
		var inst = QI.new()
		inst.setup(farm)
		farm.set_instrument(inst)

	print("\n[Runtime] Boot:")
	_check(farm.grid != null and farm.economy != null and farm.instrument != null, "farm + economy + instrument ready")

	for i in range(10):
		await process_frame

	var biome = farm.grid.get_biome("StarterForest")
	_check(biome != null, "StarterForest biome resolved")
	if biome == null:
		_finish(); return
	var real_qc = biome.quantum_computer

	# --- Fund the real inject_icon cost (10🌱 + 4× south emoji) so the preflight gate
	# passes and we actually reach expand_quantum_system, same funding shape as
	# 🍄/🧪/fractal_drive.py's live drive. ---
	farm.instrument.set_resource("🌱", 50)
	farm.instrument.set_resource("⚡", 50)
	farm.instrument.set_resource("❄️", 50)

	# --- 1. Snapshot the atlas node count before a forced failure. Must run BEFORE the
	# successful injection below: StarterForest starts at 5/6 qubits (max_biome_qubits=6),
	# so once a successful injection fills the last slot, action_inject_icon_pair's
	# qubit_cap_reached check fires ahead of expand_quantum_system on every later call,
	# masking the no_quantum_computer branch this block exists to exercise (found live —
	# the original ordering always observed "qubit_cap_reached", never the intended branch). ---
	var atlas_before = farm.instrument.action_fractal_atlas()
	var nodes_before: int = int((atlas_before.get("atlas", {}).get("nodes", {}) as Dictionary).size())

	# --- 2. FORCED FAILURE: null the biome's quantum_computer so expand_quantum_system
	# hits its own documented "no_quantum_computer" failure branch — a real failure path,
	# not a mock. A failed injection must NOT phantom-register a fractal child (bug #1). ---
	print("\n[inject_icon_pair] forced failure (biome.quantum_computer = null):")
	biome.quantum_computer = null
	var fail_result = farm.instrument.action_inject_icon_pair("StarterForest", {"north": "🔥", "south": "❄️"})
	biome.quantum_computer = real_qc  # restore immediately — don't leave the farm broken
	_check(not bool(fail_result.get("success", true)), "forced failure reports success=false")
	_check(str(fail_result.get("error", "")) == "no_quantum_computer", "failure reason is the real no_quantum_computer branch")

	var atlas_after = farm.instrument.action_fractal_atlas()
	var nodes_after: int = int((atlas_after.get("atlas", {}).get("nodes", {}) as Dictionary).size())
	_check(nodes_after == nodes_before, "a FAILED injection registers no fractal child (bug #1 regression guard: %d -> %d nodes" % [nodes_before, nodes_after])

	# --- 3. SUCCESSFUL injection: every promised result field must be present. ---
	print("\n[inject_icon_pair] successful injection:")
	var ok_result = farm.instrument.action_inject_icon_pair("StarterForest", {"north": "☀", "south": "⚡"})
	_check(bool(ok_result.get("success", false)), "injection succeeds with funded resources")
	_check(ok_result.has("north_emoji") and str(ok_result.get("north_emoji", "")) == "☀", "result carries north_emoji (bug #2 regression guard)")
	_check(ok_result.has("south_emoji") and str(ok_result.get("south_emoji", "")) == "⚡", "result carries south_emoji (bug #2 regression guard)")
	_check(ok_result.has("cost"), "result carries cost (bug #2 regression guard)")
	_check(ok_result.has("fractal_child_id"), "result carries fractal_child_id when the fractal service is live")
	var injected_register: int = int(ok_result.get("qubit_index", -1))
	_check(injected_register >= 0, "injection reports a real qubit_index")

	# --- 4. NEW gate: enter_icon must refuse an icon that's merely been injected/
	# discovered (bug scenario this gate exists to close). Injection ALREADY calls
	# farm.discover_icon, so a known_icons-keyed gate would be vacuously true —
	# this must fail on the SEPARATE incorporated_icons ledger instead. ---
	print("\n[enter_icon] incorporation gate — refuses on injection-only icon:")
	var gated_result = farm.instrument.action_enter_icon("StarterForest", injected_register)
	_check(not bool(gated_result.get("success", true)), "enter_icon refuses before deliberate incorporation")
	_check(str(gated_result.get("error", "")) == "not_incorporated", "refusal reason is not_incorporated")

	# --- 5. Real ripening-incorporation ritual (Icon-hat R) on the injected register.
	# Force-ripen the Berry-phase entry (0-threshold track) instead of faking the
	# whole quantum walk — is_ripe only needs accumulated >= threshold, and
	# start_tracking seeds accumulated at 0.0. ---
	print("\n[incorporate] real ripening-incorporation ritual:")
	real_qc.berry_register.start_tracking(injected_register)
	real_qc.berry_register.set_ripe_threshold(injected_register, 0.0)
	var incorporate_result = farm.instrument.action_incorporate(injected_register)
	_check(bool(incorporate_result.get("success", false)), "action_incorporate succeeds on the force-ripened register")
	# already_known, NOT new_icon: action_inject_icon_pair above already called
	# farm.discover_icon on ☀/⚡ (injection always auto-discovers), so this
	# incorporate hits the "re-harvest" branch — which is exactly the case
	# Step 1's gate must still ledger into incorporated_icons (the whole point
	# is that discovery alone must NOT be enough to open the fractal world).
	_check(bool(incorporate_result.get("already_known", false)), "☀/⚡ was already known from injection (re-harvest branch — the case the gate exists for)")
	var ledgered := false
	for pair in farm.incorporated_icons:
		if str(pair.get("north", "")) == "☀" and str(pair.get("south", "")) == "⚡":
			ledgered = true
			break
	_check(ledgered, "farm.incorporated_icons ledgers ☀/⚡ after the ritual")

	# --- 6. Cost + enter_icon / ascend_fractal round trip, now that the icon is
	# genuinely incorporated. Fund generously past the depth-scaled entry cost. ---
	farm.instrument.set_resource("🌱", 200)
	farm.instrument.set_resource("⚡", 200)
	var wallet_before_enter: int = int(farm.economy.get_resource_units("⚡"))
	print("\n[enter_icon / ascend_fractal] descend then ascend (incorporated + funded):")
	var enter_result = farm.instrument.action_enter_icon("StarterForest", injected_register)
	_check(bool(enter_result.get("success", false)), "enter_icon succeeds once incorporated and funded")
	_check(enter_result.has("cost") and not (enter_result.get("cost", {}) as Dictionary).is_empty(), "enter_icon result carries the depth-scaled cost")
	var wallet_after_enter: int = int(farm.economy.get_resource_units("⚡"))
	_check(wallet_after_enter < wallet_before_enter, "enter_icon actually charged the south-emoji cost (was free before this pass)")
	var child_biome_name: String = str(enter_result.get("biome_name", ""))
	_check(child_biome_name != "" and abm != null and str(abm.get_active_biome()) == child_biome_name, "descend switches the active biome to the child world")

	var ascend_result = farm.instrument.action_ascend_fractal()
	_check(bool(ascend_result.get("success", false)), "ascend_fractal succeeds back out of the child world")
	_check(abm != null and str(abm.get_active_biome()) == "StarterForest", "ascend restores StarterForest as the active biome")
	var wallet_after_ascend: int = int(farm.economy.get_resource_units("⚡"))
	_check(wallet_after_ascend == wallet_after_enter, "ascend_fractal charges nothing (stays completely free)")

	_finish()


func _finish() -> void:
	print("\n======================================================================")
	if _fail == 0:
		print("RESULT: ✅ ALL FRACTAL ATLAS CHECKS PASSED")
	else:
		print("RESULT: ❌ %d CHECK(S) FAILED" % _fail)
	print("======================================================================\n")
	quit(1 if _fail > 0 else 0)
