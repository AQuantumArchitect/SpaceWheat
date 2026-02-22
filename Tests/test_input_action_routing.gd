#!/usr/bin/env -S godot --headless -s
## QuantumInstrument Action Routing Test Suite
## Tests the unified game mechanics API (QuantumInstrument) in headless mode.
##
## After the refactor, all action routing goes through QuantumInstrument.
## FarmInputHandler no longer exists; QII is a thin keyboard adapter.

extends SceneTree

const QuantumInstrument = preload("res://Core/Instrumentation/QuantumInstrument.gd")

# Test results
var tests_passed: int = 0
var tests_failed: int = 0

func _sep(char: String, count: int) -> String:
	var result = ""
	for _i in range(count):
		result += char
	return result

func _initialize():
	print("\n" + _sep("=", 80))
	print("⌨️  QUANTUM INSTRUMENT ACTION ROUTING TEST SUITE")
	print(_sep("=", 80) + "\n")

	print("🧪 RUNNING TESTS\n")
	_test_initial_state()
	_test_selection_routing()
	_test_plot_checking()
	_test_tool_group_switching()
	_test_gate_dispatch_table()
	_test_state_snapshot_restore()
	_test_signal_emission()

	_report_results()

	quit(0 if tests_failed == 0 else 1)


func _test_initial_state():
	"""TEST 1: QuantumInstrument boots with expected default state"""
	print("📍 TEST 1: Initial State")
	print(_sep("─", 80))

	var instrument = QuantumInstrument.new()

	_assert(instrument.current_biome == "", "current_biome should be empty")
	_assert(instrument.current_plot_idx == -1, "current_plot_idx should be -1")
	_assert(instrument.current_tool_group == 3, "current_tool_group should default to 3")
	_assert(not instrument.is_in_submenu(), "should not be in submenu initially")
	_assert(instrument.checked_plots.size() == 0, "checked_plots should be empty")

	tests_passed += 1
	print("✅ TEST 1 PASSED\n")


func _test_selection_routing():
	"""TEST 2: Plot and biome selection routes through instrument state"""
	print("📍 TEST 2: Selection Routing")
	print(_sep("─", 80))

	var instrument = QuantumInstrument.new()

	# Select a plot
	var result = instrument.select_plot(2, "BioticFlux", Vector2i(1, 1))
	_assert(result.selection_changed, "selection should have changed")
	_assert(result.new_idx == 2, "new_idx should be 2")
	_assert(instrument.current_plot_idx == 2, "current_plot_idx should be 2")
	_assert(instrument.current_biome == "BioticFlux", "current_biome should be BioticFlux")
	print("   ✅ Plot selection updates state correctly")

	# Select same plot (no change)
	var result2 = instrument.select_plot(2, "BioticFlux", Vector2i(1, 1))
	_assert(not result2.selection_changed, "selection should not change for same plot")
	print("   ✅ Duplicate selection returns selection_changed=false")

	# Switch biome
	var result3 = instrument.select_plot(0, "StarterForest", Vector2i(0, 0))
	_assert(result3.selection_changed, "biome switch should trigger selection_changed")
	_assert(instrument.current_biome == "StarterForest", "biome should update")
	print("   ✅ Biome switch updates state")

	tests_passed += 1
	print("✅ TEST 2 PASSED\n")


func _test_plot_checking():
	"""TEST 3: Multi-select checkbox toggling"""
	print("📍 TEST 3: Plot Checking (Multi-Select)")
	print(_sep("─", 80))

	var instrument = QuantumInstrument.new()

	# Check first plot
	var r1 = instrument.toggle_plot_check(Vector2i(0, 0))
	_assert(r1.is_checked, "plot (0,0) should be checked")
	_assert(r1.checked_count == 1, "checked_count should be 1")
	print("   ✅ First check works")

	# Check second plot
	var r2 = instrument.toggle_plot_check(Vector2i(1, 1))
	_assert(r2.is_checked, "plot (1,1) should be checked")
	_assert(r2.checked_count == 2, "checked_count should be 2")
	print("   ✅ Second check adds to count")

	# Uncheck first
	var r3 = instrument.toggle_plot_check(Vector2i(0, 0))
	_assert(not r3.is_checked, "plot (0,0) should be unchecked")
	_assert(r3.checked_count == 1, "checked_count should decrease to 1")
	print("   ✅ Toggle uncheck works")

	# Clear all
	instrument.clear_checked_plots()
	_assert(instrument.checked_plots.size() == 0, "all plots should be cleared")
	print("   ✅ clear_checked_plots() clears all")

	# set_checked_plots round-trip
	var positions: Array[Vector2i] = [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]
	instrument.set_checked_plots(positions)
	var retrieved = instrument.get_checked_plots()
	_assert(retrieved.size() == 3, "set/get round-trip should preserve 3 plots")
	print("   ✅ set/get checked_plots round-trip works")

	tests_passed += 1
	print("✅ TEST 3 PASSED\n")


func _test_tool_group_switching():
	"""TEST 4: Tool group switching"""
	print("📍 TEST 4: Tool Group Switching")
	print(_sep("─", 80))

	var instrument = QuantumInstrument.new()

	_assert(instrument.current_tool_group == 3, "default tool group should be 3")

	var r1 = instrument.set_tool_group(1)
	_assert(r1.changed, "switching to group 1 should mark changed=true")
	_assert(r1.group == 1, "result.group should be 1")
	_assert(instrument.current_tool_group == 1, "current_tool_group should update")
	print("   ✅ Switch to group 1")

	# Same group → no change
	var r2 = instrument.set_tool_group(1)
	_assert(not r2.changed, "setting same group should return changed=false")
	print("   ✅ Same group returns changed=false")

	instrument.set_tool_group(4)
	_assert(instrument.current_tool_group == 4, "can switch to group 4")
	print("   ✅ Switch to group 4")

	tests_passed += 1
	print("✅ TEST 4 PASSED\n")


func _test_gate_dispatch_table():
	"""TEST 5: Gate dispatch table contains all expected gates"""
	print("📍 TEST 5: Gate Dispatch Table")
	print(_sep("─", 80))

	var instrument = QuantumInstrument.new()

	var expected_gates = [
		"pauli_x", "pauli_y", "pauli_z",
		"hadamard", "s_gate", "t_gate", "sdg", "tdg",
		"rx", "ry", "rz",
		"cnot", "cz", "swap",
		"bell", "ghz", "cluster"
	]

	# Check the dispatch table directly (const accessible on instance)
	var missing_gates: Array = []
	for gate in expected_gates:
		if not instrument._GATE_DISPATCH.has(gate):
			missing_gates.append(gate)

	_assert(missing_gates.is_empty(), "All %d gates should be in _GATE_DISPATCH (missing: %s)" % [
		expected_gates.size(), str(missing_gates)
	])
	print("   ✅ All %d gates in dispatch table" % expected_gates.size())

	# gate_inject without farm returns structured no_farm error (not a crash)
	var result = instrument.gate_inject("hadamard", [])
	_assert(result.get("error") == "no_farm", "gate_inject without farm should return error=no_farm")
	print("   ✅ gate_inject without farm returns structured error (not crash)")

	# Unknown gate is absent from dispatch table
	_assert(not instrument._GATE_DISPATCH.has("not_a_real_gate"), "unknown gate should not be in dispatch table")
	print("   ✅ Unknown gate correctly absent from dispatch table")

	tests_passed += 1
	print("✅ TEST 5 PASSED\n")


func _test_state_snapshot_restore():
	"""TEST 6: State snapshot and restore round-trip"""
	print("📍 TEST 6: State Snapshot/Restore")
	print(_sep("─", 80))

	var instrument = QuantumInstrument.new()

	# Set up state
	instrument.select_plot(3, "TestBiome", Vector2i(2, 2))
	instrument.toggle_plot_check(Vector2i(0, 0))
	instrument.toggle_plot_check(Vector2i(1, 1))
	instrument.set_tool_group(2)

	var snapshot = instrument.get_state_snapshot()
	_assert(snapshot.current_plot_idx == 3, "snapshot.current_plot_idx should be 3")
	_assert(snapshot.current_biome == "TestBiome", "snapshot.current_biome should be TestBiome")
	_assert(snapshot.checked_plots.size() == 2, "snapshot.checked_plots should have 2 items")
	_assert(snapshot.current_tool_group == 2, "snapshot.current_tool_group should be 2")
	print("   ✅ Snapshot captures full state")

	# Restore to fresh instrument
	var instrument2 = QuantumInstrument.new()
	instrument2.restore_state(snapshot)

	_assert(instrument2.current_plot_idx == 3, "restored plot_idx should be 3")
	_assert(instrument2.current_biome == "TestBiome", "restored biome should be TestBiome")
	_assert(instrument2.checked_plots.size() == 2, "restored checked_plots should have 2 items")
	_assert(instrument2.current_tool_group == 2, "restored tool_group should be 2")
	print("   ✅ Restore round-trip preserves all state")

	tests_passed += 1
	print("✅ TEST 6 PASSED\n")


func _test_signal_emission():
	"""TEST 7: action_performed and selection_changed signals fire"""
	print("📍 TEST 7: Signal Emission")
	print(_sep("─", 80))

	var instrument = QuantumInstrument.new()

	var selection_signals: Array = []
	var check_signals: Array = []
	instrument.selection_changed.connect(func(idx, biome): selection_signals.append([idx, biome]))
	instrument.plot_check_changed.connect(func(pos, checked): check_signals.append([pos, checked]))

	# selection_changed fires when plot changes
	instrument.select_plot(1, "BioticFlux", Vector2i(0, 0))
	_assert(selection_signals.size() == 1, "selection_changed should fire on plot change")
	_assert(selection_signals[0][0] == 1, "signal should carry plot_idx=1")
	print("   ✅ selection_changed fires on plot selection")

	# No signal if selecting same plot
	instrument.select_plot(1, "BioticFlux", Vector2i(0, 0))
	_assert(selection_signals.size() == 1, "no duplicate signal on same selection")
	print("   ✅ No duplicate signal for unchanged selection")

	# plot_check_changed fires on toggle
	instrument.toggle_plot_check(Vector2i(2, 0))
	_assert(check_signals.size() == 1, "plot_check_changed should fire on check")
	_assert(check_signals[0][1] == true, "signal should carry is_checked=true")
	print("   ✅ plot_check_changed fires on plot check")

	instrument.toggle_plot_check(Vector2i(2, 0))
	_assert(check_signals.size() == 2, "plot_check_changed fires on uncheck too")
	_assert(check_signals[1][1] == false, "uncheck signal carries is_checked=false")
	print("   ✅ plot_check_changed fires on plot uncheck")

	tests_passed += 1
	print("✅ TEST 7 PASSED\n")


func _assert(condition: bool, msg: String):
	if not condition:
		print("   ❌ ASSERT FAILED: %s" % msg)
		tests_failed += 1
		_report_results()
		quit(1)


func _report_results():
	var separator = _sep("=", 80)

	print("\n" + separator)
	print("📊 QUANTUM INSTRUMENT ACTION ROUTING RESULTS")
	print(separator)

	print("\n✅ Passed: %d" % tests_passed)
	print("❌ Failed: %d" % tests_failed)
	print("📊 Total:  %d" % (tests_passed + tests_failed))

	print("\n" + separator)
	if tests_failed == 0:
		print("✅ ALL TESTS PASSED - QuantumInstrument routing layer works!")
	else:
		print("❌ SOME TESTS FAILED")
	print(separator + "\n")
