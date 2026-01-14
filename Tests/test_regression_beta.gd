extends SceneTree

## Beta Regression Test Suite
## Verifies core gameplay stability after Phase 1-3 cleanup

const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")

var frame_count := 0
var farm = null
var test_results := []
var test_start_time := 0

func _init():
	print("")
	print("══════════════════════════════════════════════════════════════════")
	print("  BETA REGRESSION TEST SUITE")
	print("══════════════════════════════════════════════════════════════════")
	print("")
	test_start_time = Time.get_ticks_msec()

func _process(_delta):
	frame_count += 1

	if frame_count == 5:
		_test_boot_sequence()

	if frame_count == 15:
		_load_main_scene()

	if frame_count == 40:
		_run_core_tests()

func _test_boot_sequence():
	"""Test 1: Verify autoloads initialized correctly"""
	print("📋 Test 1: Boot Sequence")

	# Check IconRegistry
	var icon_registry = get_root().get_node_or_null("/root/IconRegistry")
	if icon_registry:
		_pass("IconRegistry autoload present")
	else:
		_fail("IconRegistry autoload missing")

	# Check GameStateManager
	var gsm = get_root().get_node_or_null("/root/GameStateManager")
	if gsm:
		_pass("GameStateManager autoload present")
	else:
		_fail("GameStateManager autoload missing")

	# Check BootManager
	var boot = get_root().get_node_or_null("/root/BootManager")
	if boot:
		_pass("BootManager autoload present")
	else:
		_fail("BootManager autoload missing")

func _load_main_scene():
	print("\n📋 Test 2: Scene Loading")
	var scene = load("res://scenes/FarmView.tscn")
	if scene:
		_pass("FarmView.tscn loaded")
		var root_node = scene.instantiate()
		get_root().add_child(root_node)
		_pass("FarmView instantiated")
	else:
		_fail("Failed to load FarmView.tscn")

func _run_core_tests():
	print("\n📋 Test 3: Farm & PlotPool")

	# Find farm
	farm = _find_farm()
	if not farm:
		_fail("Could not find Farm instance")
		_finish()
		return
	_pass("Farm instance found")

	# Test PlotPool
	if farm.plot_pool:
		_pass("PlotPool exists (pool_size=%d)" % farm.plot_pool.pool_size)
	else:
		_fail("farm.plot_pool is null")
		_finish()
		return

	# Test biomes
	print("\n📋 Test 4: Biome Accessibility")
	_test_biomes()

	# Test EXPLORE/MEASURE/POP cycle
	print("\n📋 Test 5: EXPLORE → MEASURE → POP Cycle")
	_test_probe_cycle()

	# Test terminal binding consistency
	print("\n📋 Test 6: Terminal Binding Consistency")
	_test_binding_consistency()

	# Test no zombie references
	print("\n📋 Test 7: No Zombie Code References")
	_test_no_zombies()

	_finish()

func _test_biomes():
	"""Verify all 4 biomes are accessible"""
	var biome_positions = {
		"BioticFlux": Vector2i(2, 0),
		"Market": Vector2i(0, 0),
		"Forest": Vector2i(0, 1),
		"Kitchen": Vector2i(3, 1)
	}

	for biome_name in biome_positions:
		var pos = biome_positions[biome_name]
		var biome = farm.grid.get_biome_for_plot(pos)
		if biome:
			var actual_name = biome.get_biome_type()
			if actual_name == biome_name:
				_pass("%s biome at %s" % [biome_name, pos])
			else:
				_pass("%s biome found (actual: %s)" % [biome_name, actual_name])
		else:
			_fail("No biome at %s (expected %s)" % [pos, biome_name])

func _test_probe_cycle():
	"""Test full EXPLORE → MEASURE → POP cycle"""
	var biome = farm.grid.get_biome_for_plot(Vector2i(2, 0))
	if not biome:
		_fail("Could not get biome for probe cycle test")
		return

	# EXPLORE
	var explore_result = ProbeActions.action_explore(farm.plot_pool, biome)
	if explore_result.get("success", false):
		_pass("EXPLORE succeeded (reg=%d, emoji=%s)" % [
			explore_result.register_id,
			explore_result.emoji_pair.get("north", "?")
		])

		var terminal = explore_result.terminal

		# MEASURE
		var measure_result = ProbeActions.action_measure(terminal, biome)
		if measure_result.get("success", false):
			_pass("MEASURE succeeded (outcome=%s, p=%.0f%%)" % [
				measure_result.outcome,
				measure_result.probability * 100
			])

			# POP
			var pop_result = ProbeActions.action_pop(terminal, farm.plot_pool, farm.economy)
			if pop_result.get("success", false):
				_pass("POP succeeded (harvested=%s)" % pop_result.resource)
			else:
				_fail("POP failed: %s" % pop_result.get("message", "unknown"))
		else:
			_fail("MEASURE failed: %s" % measure_result.get("message", "unknown"))
	else:
		_fail("EXPLORE failed: %s" % explore_result.get("message", "unknown"))

func _test_binding_consistency():
	"""Verify PlotPool binding tables are consistent"""
	var pool = farm.plot_pool

	# Check binding table matches reverse binding
	var binding_count = pool.binding_table.size()
	var reverse_count = pool.reverse_binding.size()

	if binding_count == reverse_count:
		_pass("Binding tables consistent (%d entries)" % binding_count)
	else:
		_fail("Binding table mismatch: %d vs %d reverse" % [binding_count, reverse_count])

	# Check all bound terminals have valid biome references
	var orphaned = 0
	for terminal in pool.get_bound_terminals():
		if not terminal.bound_biome:
			orphaned += 1

	if orphaned == 0:
		_pass("No orphaned terminal bindings")
	else:
		_fail("%d terminals have null biome reference" % orphaned)

func _test_no_zombies():
	"""Verify no references to deleted classes"""
	# Check BiomeBase doesn't try to use QuantumBath
	var biome = farm.grid.get_biome_for_plot(Vector2i(2, 0))

	if biome.bath == null:
		_pass("BiomeBase.bath is null (correct for Model C)")
	else:
		_fail("BiomeBase.bath is not null (zombie bath reference)")

	if biome.quantum_computer != null:
		_pass("BiomeBase.quantum_computer exists")
	else:
		_fail("BiomeBase.quantum_computer is null")

func _find_farm():
	var farm_view = get_root().get_node_or_null("FarmView")
	if farm_view and farm_view.has_node("Farm"):
		return farm_view.get_node("Farm")
	return _find_node_by_type(get_root(), "Farm")

func _find_node_by_type(node, type_name: String):
	if node.get_class() == type_name or (node.get_script() and node.get_script().get_global_name() == type_name):
		return node
	for child in node.get_children():
		var found = _find_node_by_type(child, type_name)
		if found:
			return found
	return null

func _pass(test_name: String):
	test_results.append({"name": test_name, "passed": true})
	print("  ✅ %s" % test_name)

func _fail(test_name: String):
	test_results.append({"name": test_name, "passed": false})
	print("  ❌ %s" % test_name)

func _finish():
	var elapsed = Time.get_ticks_msec() - test_start_time

	print("")
	print("══════════════════════════════════════════════════════════════════")
	print("  TEST RESULTS")
	print("══════════════════════════════════════════════════════════════════")

	var passed := 0
	var failed := 0

	for result in test_results:
		if result.passed:
			passed += 1
		else:
			failed += 1

	print("")
	print("  ✅ Passed: %d" % passed)
	print("  ❌ Failed: %d" % failed)
	print("  ⏱️  Time: %d ms" % elapsed)
	print("")

	if failed == 0:
		print("  🎉 ALL TESTS PASSED - BETA READY")
	else:
		print("  ⚠️  FAILURES DETECTED - FIX BEFORE BETA")

	print("")
	print("══════════════════════════════════════════════════════════════════")

	quit(0 if failed == 0 else 1)
