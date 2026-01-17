#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Quick verification that Tool 1 (PROBE) is working correctly

const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")

var farm = null
var frame_count = 0
var scene_loaded = false
var tests_done = false
var issues_found = []

func _init():
	print("\n" + "═".repeat(80))
	print("🔵 TOOL 1 (PROBE) VERIFICATION TEST")
	print("═".repeat(80))

func _process(_delta):
	frame_count += 1

	if frame_count == 5 and not scene_loaded:
		print("\n⏳ Loading scene...")
		var scene = load("res://scenes/FarmView.tscn")
		if scene:
			var instance = scene.instantiate()
			root.add_child(instance)
			scene_loaded = true
			var boot_manager = root.get_node_or_null("/root/BootManager")
			if boot_manager:
				boot_manager.game_ready.connect(_on_game_ready)

func _on_game_ready():
	if tests_done:
		return
	tests_done = true

	print("\n✅ Game ready! Starting Tool 1 verification...\n")

	var fv = root.get_node_or_null("FarmView")
	if not fv or not fv.farm:
		print("❌ Farm not found")
		quit(1)
		return

	farm = fv.farm

	await verify_basic_cycle()
	await verify_null_safety()
	await verify_state_validation()

	print("\n" + "═".repeat(80))
	print("✅ TOOL 1 VERIFICATION COMPLETE")
	print("═".repeat(80))
	print("\n📋 ISSUES FOUND: %d" % issues_found.size())
	print("═".repeat(80))
	for issue in issues_found:
		print("  ❌ %s" % issue)
	print("")
	quit()

func log_issue(message: String):
	issues_found.append(message)
	print("  ⚠️  ISSUE: %s" % message)

func verify_basic_cycle():
	"""Verify basic EXPLORE -> MEASURE -> POP cycle works"""
	print("\n[VERIFY 1] Basic EXPLORE -> MEASURE -> POP Cycle")
	print("─".repeat(80))

	var biome = farm.grid.get_biome_for_plot(Vector2i(0, 0))
	if not biome:
		log_issue("Tool 1: No biome at (0,0)")
		return

	print("Testing biome: %s" % biome.get_biome_type())

	# Step 1: EXPLORE
	var e_res = ProbeActions.action_explore(farm.plot_pool, biome)
	if not e_res.success:
		log_issue("Tool 1: EXPLORE failed - %s" % e_res.get('message', 'unknown'))
		return

	var terminal = e_res.terminal
	print("✅ EXPLORE: Terminal %s → Register %d" % [terminal.terminal_id, e_res.register_id])

	# Step 2: MEASURE
	var m_res = ProbeActions.action_measure(terminal, biome)
	if not m_res.success:
		log_issue("Tool 1: MEASURE failed - %s" % m_res.get('message', 'unknown'))
		return

	print("✅ MEASURE: %s (p=%.4f)" % [m_res.outcome, m_res.recorded_probability])

	if not terminal.is_measured:
		log_issue("Tool 1: Terminal not marked measured after MEASURE")

	# Step 3: POP
	var p_res = ProbeActions.action_pop(terminal, farm.plot_pool, farm.economy)
	if not p_res.success:
		log_issue("Tool 1: POP failed - %s" % p_res.get('message', 'unknown'))
		return

	print("✅ POP: Gained %s" % p_res.resource)

	if terminal.is_bound:
		log_issue("Tool 1: Terminal still bound after POP")

	print("✅ Basic cycle verified successfully")

func verify_null_safety():
	"""Verify null input handling"""
	print("\n[VERIFY 2] Null Safety - No Crashes on Null Inputs")
	print("─".repeat(80))

	var biome = farm.grid.get_biome_for_plot(Vector2i(0, 0))

	# Test 1: MEASURE with null terminal
	var m_null = ProbeActions.action_measure(null, biome)
	if m_null.success:
		log_issue("Tool 1: MEASURE(null) should fail but succeeded")
	else:
		print("✅ MEASURE(null) correctly rejected: %s" % m_null.get('message', 'unknown'))

	# Test 2: POP with null terminal
	var p_null = ProbeActions.action_pop(null, farm.plot_pool, farm.economy)
	if p_null.success:
		log_issue("Tool 1: POP(null) should fail but succeeded")
	else:
		print("✅ POP(null) correctly rejected: %s" % p_null.get('message', 'unknown'))

	# Test 3: EXPLORE with null biome
	var e_null = ProbeActions.action_explore(farm.plot_pool, null)
	if e_null.success:
		log_issue("Tool 1: EXPLORE(null) should fail but succeeded")
	else:
		print("✅ EXPLORE(null) correctly rejected: %s" % e_null.get('message', 'unknown'))

	print("✅ Null safety verified - no crashes on null inputs")

func verify_state_validation():
	"""Verify terminal state validation works"""
	print("\n[VERIFY 3] State Machine Validation")
	print("─".repeat(80))

	var biome = farm.grid.get_biome_for_plot(Vector2i(0, 0))

	# Create a fresh terminal
	var e_res = ProbeActions.action_explore(farm.plot_pool, biome)
	if not e_res.success:
		log_issue("Tool 1: Could not create terminal for state validation test")
		return

	var terminal = e_res.terminal

	# Verify BOUND state
	var bound_state = terminal.validate_state()
	if bound_state != "":
		log_issue("Tool 1: Terminal in BOUND state but validation failed: %s" % bound_state)
	else:
		print("✅ Terminal BOUND state validated")

	# Measure it
	var m_res = ProbeActions.action_measure(terminal, biome)
	if not m_res.success:
		log_issue("Tool 1: Could not measure terminal for state validation")
		return

	# Verify MEASURED state
	var measured_state = terminal.validate_state()
	if measured_state != "":
		log_issue("Tool 1: Terminal in MEASURED state but validation failed: %s" % measured_state)
	else:
		print("✅ Terminal MEASURED state validated")

	# POP it
	var p_res = ProbeActions.action_pop(terminal, farm.plot_pool, farm.economy)
	if not p_res.success:
		log_issue("Tool 1: Could not pop terminal")
		return

	# Verify UNBOUND state
	var unbound_state = terminal.validate_state()
	if unbound_state != "":
		log_issue("Tool 1: Terminal in UNBOUND state but validation failed: %s" % unbound_state)
	else:
		print("✅ Terminal UNBOUND state validated")

	print("✅ State machine validation verified")
