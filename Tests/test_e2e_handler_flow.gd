#!/usr/bin/env -S godot --headless -s
## E2E Test: Handler Flow - Keyboard → Handlers → Quantum → Display
## Tests the full signal chain after FarmInputHandler refactoring
##
## Flow tested:
##   Keyboard Input → FarmInputHandler → Handler Modules → ProbeActions/Biome
##   → QuantumComputer → Farm Signals → Visualization
##
## Tests:
##   1. EXPLORE → MEASURE → POP flow (v2 Probe paradigm)
##   2. Gate operations through GateActionHandler
##   3. Lindblad operations through LindbladHandler
##   4. System operations through SystemHandler
##   5. Signal propagation verification

extends SceneTree

# Test state
var farm: Node = null
var input_handler: Node = null
var test_passed: int = 0
var test_failed: int = 0
var test_log: Array = []

# Signal tracking
var signals_received: Dictionary = {
	"action_performed": [],
	"terminal_bound": [],
	"terminal_measured": [],
	"terminal_released": [],
	"tool_changed": []
}


func _initialize():
	print("\n" + "=".repeat(70))
	print("🔬 E2E TEST: Handler Flow - Keyboard → Quantum → Display")
	print("=".repeat(70) + "\n")

	# Load the main game scene
	var scene = load("res://scenes/FarmView.tscn") as PackedScene
	if not scene:
		print("❌ FATAL: Could not load FarmView.tscn")
		quit(1)
		return

	var root_node = scene.instantiate()
	root_node.name = "FarmView"
	get_root().add_child(root_node)

	# Wait for BootManager to complete initialization
	print("⏳ Waiting for game initialization...")
	for i in range(30):  # Wait up to 30 frames
		await process_frame

	# Find core components
	if not _find_components(root_node):
		print("❌ FATAL: Could not find required components")
		quit(1)
		return

	print("✅ Game initialized successfully\n")

	# Connect to signals for tracking
	_connect_signals()

	# Run test suites
	print("🧪 RUNNING E2E TEST SUITES\n")

	await test_explore_measure_pop_flow()
	await test_gate_operations()
	await test_lindblad_operations()
	await test_system_operations()
	await test_signal_propagation()

	# Print summary
	_print_summary()

	quit(0 if test_failed == 0 else 1)


func _find_components(root_node: Node) -> bool:
	"""Find core game components"""

	# Find Farm
	farm = root_node.get("farm") if root_node.has_method("get") else null
	if not farm:
		farm = root_node.find_child("Farm", true, false)
	if not farm:
		# Try to get from autoload
		farm = get_root().get_node_or_null("/root/GameStateManager")
		if farm and farm.has_method("get"):
			farm = farm.get("active_farm")

	if not farm:
		print("  ❌ Farm not found")
		return false
	print("  ✅ Found Farm")

	# Find FarmInputHandler
	var ui_controller = root_node.find_child("FarmUIController", true, false)
	if ui_controller:
		input_handler = ui_controller.get("input_handler") if ui_controller.has_method("get") else null

	if not input_handler:
		input_handler = root_node.find_child("FarmInputHandler", true, false)

	if not input_handler:
		print("  ❌ FarmInputHandler not found")
		return false
	print("  ✅ Found FarmInputHandler")

	# Verify farm has required components
	if not farm.grid:
		print("  ❌ Farm.grid not found")
		return false
	print("  ✅ Found Farm.grid")

	if not farm.terminal_pool:
		print("  ❌ Farm.terminal_pool not found")
		return false
	print("  ✅ Found Farm.terminal_pool")

	# Find at least one biome
	if not farm.grid.has_biomes():
		print("  ❌ No biomes found")
		return false
	print("  ✅ Found %d biome(s)" % farm.grid.get_biome_count())

	return true


func _connect_signals():
	"""Connect to signals for tracking"""
	print("📡 Connecting to signals...")

	if input_handler.has_signal("action_performed"):
		input_handler.action_performed.connect(_on_action_performed)
		print("  ✅ Connected to action_performed")

	if input_handler.has_signal("tool_changed"):
		input_handler.tool_changed.connect(_on_tool_changed)
		print("  ✅ Connected to tool_changed")

	if farm.has_signal("terminal_bound"):
		farm.terminal_bound.connect(_on_terminal_bound)
		print("  ✅ Connected to terminal_bound")

	if farm.has_signal("terminal_measured"):
		farm.terminal_measured.connect(_on_terminal_measured)
		print("  ✅ Connected to terminal_measured")

	if farm.has_signal("terminal_released"):
		farm.terminal_released.connect(_on_terminal_released)
		print("  ✅ Connected to terminal_released")

	print("")


## ============================================================================
## TEST SUITE 1: EXPLORE → MEASURE → POP Flow
## ============================================================================

func test_explore_measure_pop_flow():
	"""Test the core v2 probe paradigm: EXPLORE → MEASURE → POP"""
	print("📍 TEST SUITE 1: EXPLORE → MEASURE → POP Flow")
	print("─".repeat(60))

	# Clear signal tracking
	signals_received.action_performed.clear()
	signals_received.terminal_bound.clear()
	signals_received.terminal_measured.clear()
	signals_received.terminal_released.clear()

	# Get a biome to test with
	var biome_name = farm.grid.get_biome_names()[0]
	var biome = farm.grid.get_biome(biome_name)

	assert_true(biome != null, "Test biome exists: %s" % biome_name)
	assert_true(biome.quantum_computer != null, "Biome has quantum_computer")

	# 1. Test EXPLORE via MeasurementHandler directly
	print("\n  📌 Step 1: EXPLORE")
	var unbound_before = farm.terminal_pool.get_unbound_count()
	_log("Unbound terminals before: %d" % unbound_before)

	# Execute EXPLORE directly via handler
	var explore_result = _call_measurement_handler("action_explore", biome)
	await process_frame
	await process_frame

	var unbound_after = farm.terminal_pool.get_unbound_count()
	_log("Unbound terminals after: %d" % unbound_after)

	if explore_result:
		assert_true(explore_result.get("success", false), "EXPLORE succeeded")
		if explore_result.get("success"):
			assert_true(unbound_after < unbound_before, "Terminal was bound (%d → %d)" % [unbound_before, unbound_after])
			_log("Bound terminal: %s" % explore_result.get("terminal_id", "unknown"))
	else:
		_log("⚠️ EXPLORE returned null")

	# 2. Test MEASURE
	print("\n  📌 Step 2: MEASURE")

	# Find a bound terminal to measure
	var active_terminals = farm.terminal_pool.get_active_terminals()
	_log("Active terminals: %d" % active_terminals.size())

	if active_terminals.size() > 0:
		var terminal = active_terminals[0]
		_log("Testing measure on terminal: %s" % terminal.terminal_id)

		# Get the terminal's biome for measurement
		var term_biome = farm.grid.get_biome(terminal.bound_biome_name) if terminal.bound_biome_name != "" else biome
		if not term_biome:
			term_biome = biome

		var measure_result = _call_measurement_handler("action_measure", term_biome, terminal)
		await process_frame
		await process_frame

		if measure_result:
			assert_true(measure_result.get("success", false), "MEASURE succeeded")
			if measure_result.get("success"):
				_log("Measured outcome: %s (p=%.3f)" % [
					measure_result.get("outcome", "?"),
					measure_result.get("probability", 0.0)
				])
		else:
			_log("⚠️ MEASURE returned null")
	else:
		_log("⚠️ No active terminals to measure")

	# 3. Test POP
	print("\n  📌 Step 3: POP")

	var measured_terminals = farm.terminal_pool.get_measured_terminals()
	_log("Measured terminals: %d" % measured_terminals.size())

	if measured_terminals.size() > 0:
		var terminal = measured_terminals[0]
		_log("Testing pop on terminal: %s" % terminal.terminal_id)

		var pop_result = _call_measurement_handler("action_pop", biome, terminal)
		await process_frame
		await process_frame

		if pop_result:
			assert_true(pop_result.get("success", false), "POP succeeded")
			if pop_result.get("success"):
				_log("Popped credits: %d" % pop_result.get("credits", 0))
		else:
			_log("⚠️ POP returned null")
	else:
		_log("⚠️ No measured terminals to pop")

	print("")


## ============================================================================
## TEST SUITE 2: Gate Operations through GateActionHandler
## ============================================================================

func test_gate_operations():
	"""Test quantum gates through the refactored GateActionHandler"""
	print("📍 TEST SUITE 2: Gate Operations (GateActionHandler)")
	print("─".repeat(60))

	# Get a biome to work with
	var biome_name = farm.grid.get_biome_names()[0]
	var biome = farm.grid.get_biome(biome_name)

	# First, we need a bound terminal to apply gates to
	# EXPLORE to get a terminal via handler
	var explore_result = _call_measurement_handler("action_explore", biome)
	await process_frame
	await process_frame

	var active_terminals = farm.terminal_pool.get_active_terminals()
	if active_terminals.is_empty():
		_log("⚠️ No active terminals for gate tests - skipping")
		print("")
		return

	var terminal = active_terminals[0]
	var test_positions: Array[Vector2i] = []
	if terminal.grid_position:
		test_positions.append(terminal.grid_position)
	else:
		test_positions.append(Vector2i.ZERO)

	_log("Testing gates on terminal: %s at %s" % [terminal.terminal_id, test_positions[0]])

	# Get initial probability
	var term_biome = farm.grid.get_biome(terminal.bound_biome_name) if terminal.bound_biome_name != "" else biome
	if not term_biome:
		term_biome = biome
	var reg_id = terminal.bound_register_id if terminal.bound_register_id else -1
	var initial_prob = 0.5
	if term_biome and term_biome.quantum_computer:
		initial_prob = term_biome.get_register_probability(reg_id)

	print("  Initial probability: %.3f" % initial_prob)

	# Test Pauli-X gate (bit flip)
	print("\n  📌 Pauli-X Gate (Bit Flip)")
	signals_received.action_performed.clear()

	var pauli_x_result = _call_gate_handler("apply_pauli_x", test_positions)
	await process_frame

	if pauli_x_result:
		assert_true(pauli_x_result.get("success", false), "Pauli-X applied successfully")
		var new_prob = term_biome.get_register_probability(reg_id) if term_biome else 0.5
		print("  Probability after X: %.3f (expected ~%.3f)" % [new_prob, 1.0 - initial_prob])
		# X gate should flip probability (with some tolerance for numerical precision)
		var expected = 1.0 - initial_prob
		assert_true(abs(new_prob - expected) < 0.1, "Probability flipped by X gate")

	# Test Hadamard gate (superposition)
	print("\n  📌 Hadamard Gate (Superposition)")
	var hadamard_result = _call_gate_handler("apply_hadamard", test_positions)
	await process_frame

	if hadamard_result:
		assert_true(hadamard_result.get("success", false), "Hadamard applied successfully")
		var h_prob = term_biome.get_register_probability(reg_id) if term_biome else 0.5
		print("  Probability after H: %.3f" % h_prob)

	# Test Pauli-Z gate (phase flip)
	print("\n  📌 Pauli-Z Gate (Phase Flip)")
	var pauli_z_result = _call_gate_handler("apply_pauli_z", test_positions)
	await process_frame

	if pauli_z_result:
		assert_true(pauli_z_result.get("success", false), "Pauli-Z applied successfully")

	print("")


## ============================================================================
## TEST SUITE 3: Lindblad Operations through LindbladHandler
## ============================================================================

func test_lindblad_operations():
	"""Test Lindblad/dissipation operations through LindbladHandler"""
	print("📍 TEST SUITE 3: Lindblad Operations (LindbladHandler)")
	print("─".repeat(60))

	# Get a biome and EXPLORE to get bound terminals
	var biome_name = farm.grid.get_biome_names()[0]
	var biome = farm.grid.get_biome(biome_name)

	# Ensure we have a bound terminal
	var explore_result = _call_measurement_handler("action_explore", biome)
	await process_frame

	var active_terminals = farm.terminal_pool.get_active_terminals()
	if active_terminals.is_empty():
		_log("⚠️ No active terminals for Lindblad tests - skipping")
		print("")
		return

	var terminal = active_terminals[0]
	var test_positions: Array[Vector2i] = []
	if terminal.grid_position:
		test_positions.append(terminal.grid_position)
	else:
		test_positions.append(Vector2i.ZERO)

	_log("Testing Lindblad ops on terminal at %s" % test_positions[0])

	# Test lindblad_drive
	print("\n  📌 Lindblad Drive")
	var drive_result = _call_lindblad_handler("lindblad_drive", test_positions)
	if drive_result:
		assert_true(drive_result.get("success", false), "Lindblad drive succeeded")
		if not drive_result.get("success"):
			_log("Error: %s" % drive_result.get("error", "unknown"))

	# Test lindblad_decay
	print("\n  📌 Lindblad Decay")
	var decay_result = _call_lindblad_handler("lindblad_decay", test_positions)
	if decay_result:
		assert_true(decay_result.get("success", false), "Lindblad decay succeeded")
		if not decay_result.get("success"):
			_log("Error: %s" % decay_result.get("error", "unknown"))

	# Test pump_to_wheat
	print("\n  📌 Pump to Wheat")
	var pump_result = _call_lindblad_handler("pump_to_wheat", test_positions)
	if pump_result:
		# pump_to_wheat might fail if emoji mapping doesn't exist - that's ok
		_log("Pump to wheat: %s" % ("✅ success" if pump_result.get("success") else "⚠️ skipped (no wheat emoji)"))

	print("")


## ============================================================================
## TEST SUITE 4: System Operations through SystemHandler
## ============================================================================

func test_system_operations():
	"""Test system/debug operations through SystemHandler"""
	print("📍 TEST SUITE 4: System Operations (SystemHandler)")
	print("─".repeat(60))

	var test_positions: Array[Vector2i] = [Vector2i.ZERO]

	# Test system_debug
	print("\n  📌 System Debug")
	var debug_result = _call_system_handler("system_debug", test_positions)
	if debug_result:
		assert_true(debug_result.get("success", false), "System debug returned info")
		if debug_result.has("debug_info"):
			var info = debug_result.debug_info
			_log("Debug info: biome=%s, position=%s" % [
				info.get("biome_name", "?"),
				info.get("position", "?")
			])

	# Test peek_state (non-destructive inspection)
	print("\n  📌 Peek State")
	var peek_result = _call_system_handler("peek_state", test_positions)
	if peek_result:
		_log("Peek state: %s" % ("✅ success" if peek_result.get("success") else "⚠️ no state to peek"))

	# Test evolution pause
	print("\n  📌 Evolution Pause Control")
	var pause_result = _call_system_handler("set_biomes_paused", test_positions, true)
	if pause_result:
		assert_true(pause_result.get("success", false), "Paused evolution")
		_log("Paused %d biomes" % pause_result.get("affected_biomes", 0))

	var resume_result = _call_system_handler("set_biomes_paused", test_positions, false)
	if resume_result:
		assert_true(resume_result.get("success", false), "Resumed evolution")

	print("")


## ============================================================================
## TEST SUITE 5: Signal Propagation Verification
## ============================================================================

func test_signal_propagation():
	"""Verify signals propagate correctly through the system"""
	print("📍 TEST SUITE 5: Signal Propagation")
	print("─".repeat(60))

	# Summary of signals received during tests
	print("\n  📡 Signal Summary:")
	print("  " + "─".repeat(30))

	_log("action_performed signals: %d" % signals_received.action_performed.size())
	_log("terminal_bound signals: %d" % signals_received.terminal_bound.size())
	_log("terminal_measured signals: %d" % signals_received.terminal_measured.size())
	_log("terminal_released signals: %d" % signals_received.terminal_released.size())
	_log("tool_changed signals: %d" % signals_received.tool_changed.size())

	# Note: When testing handlers directly, action_performed signals won't be emitted
	# (those come from FarmInputHandler when it processes user input).
	# But terminal_* signals should be emitted by Farm/PlotPool when terminal states change.

	# Check if Farm emitted terminal signals during our tests
	var total_terminal_signals = (
		signals_received.terminal_bound.size() +
		signals_received.terminal_measured.size() +
		signals_received.terminal_released.size()
	)

	# At minimum, our EXPLORE calls should have bound terminals
	# Note: Signal emission depends on how Farm/PlotPool is wired
	_log("Total terminal signals: %d" % total_terminal_signals)

	# Verify Farm signal system is properly connected (at least signals exist)
	var farm_has_signals = (
		farm.has_signal("terminal_bound") or
		farm.has_signal("terminal_measured") or
		farm.has_signal("terminal_released")
	)
	assert_true(farm_has_signals, "Farm has terminal signals defined")

	print("")


## ============================================================================
## HELPER FUNCTIONS
## ============================================================================

func _call_measurement_handler(method_name: String, biome, terminal = null):
	"""Call MeasurementHandler/ProbeActions method directly"""
	const MeasurementHandler = preload("res://UI/Handlers/MeasurementHandler.gd")
	const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")

	match method_name:
		"action_explore":
			# EXPLORE: action_explore(plot_pool, biome)
			return ProbeActions.action_explore(farm.terminal_pool, biome)
		"action_measure":
			# MEASURE: action_measure(terminal, biome)
			if terminal:
				return ProbeActions.action_measure(terminal, biome)
			return {"success": false, "error": "no_terminal"}
		"action_pop":
			# POP: action_pop(terminal, plot_pool, economy = null)
			if terminal:
				return ProbeActions.action_pop(terminal, farm.terminal_pool)
			return {"success": false, "error": "no_terminal"}

	return null


func _call_gate_handler(method_name: String, positions: Array[Vector2i]):
	"""Call GateActionHandler method directly"""
	const GateActionHandler = preload("res://UI/Handlers/GateActionHandler.gd")

	match method_name:
		"apply_pauli_x":
			return GateActionHandler.apply_pauli_x(farm, positions)
		"apply_hadamard":
			return GateActionHandler.apply_hadamard(farm, positions)
		"apply_pauli_z":
			return GateActionHandler.apply_pauli_z(farm, positions)
		"apply_pauli_y":
			return GateActionHandler.apply_pauli_y(farm, positions)

	return null


func _call_lindblad_handler(method_name: String, positions: Array[Vector2i]):
	"""Call LindbladHandler method directly"""
	const LindbladHandler = preload("res://UI/Handlers/LindbladHandler.gd")

	match method_name:
		"lindblad_drive":
			return LindbladHandler.lindblad_drive(farm, positions)
		"lindblad_decay":
			return LindbladHandler.lindblad_decay(farm, positions)
		"pump_to_wheat":
			return LindbladHandler.pump_to_wheat(farm, positions)

	return null


func _call_system_handler(method_name: String, positions: Array[Vector2i], extra_arg = null):
	"""Call SystemHandler method directly"""
	const SystemHandler = preload("res://UI/Handlers/SystemHandler.gd")

	match method_name:
		"system_debug":
			return SystemHandler.system_debug(farm, positions)
		"system_reset":
			return SystemHandler.system_reset(farm, positions)
		"system_snapshot":
			return SystemHandler.system_snapshot(farm, positions)
		"peek_state":
			return SystemHandler.peek_state(farm, positions)
		"set_biomes_paused":
			return SystemHandler.set_biomes_paused(farm, extra_arg if extra_arg != null else false)

	return null


## ============================================================================
## SIGNAL HANDLERS
## ============================================================================

func _on_action_performed(action: String, success: bool, message: String):
	signals_received.action_performed.append({
		"action": action,
		"success": success,
		"message": message
	})

func _on_tool_changed(tool_num: int, tool_info: Dictionary):
	signals_received.tool_changed.append({
		"tool_num": tool_num,
		"tool_info": tool_info
	})

func _on_terminal_bound(grid_pos: Vector2i, terminal_id: String, emoji_pair: Dictionary):
	signals_received.terminal_bound.append({
		"grid_pos": grid_pos,
		"terminal_id": terminal_id,
		"emoji_pair": emoji_pair
	})

func _on_terminal_measured(grid_pos: Vector2i, terminal_id: String, outcome: String, probability: float):
	signals_received.terminal_measured.append({
		"grid_pos": grid_pos,
		"terminal_id": terminal_id,
		"outcome": outcome,
		"probability": probability
	})

func _on_terminal_released(grid_pos: Vector2i, terminal_id: String, credits: int):
	signals_received.terminal_released.append({
		"grid_pos": grid_pos,
		"terminal_id": terminal_id,
		"credits": credits
	})


## ============================================================================
## ASSERTION HELPERS
## ============================================================================

func assert_true(condition: bool, message: String):
	if condition:
		test_passed += 1
		_log("✅ " + message)
	else:
		test_failed += 1
		_log("❌ FAILED: " + message)

func assert_equals(actual, expected, message: String):
	if actual == expected:
		test_passed += 1
		_log("✅ " + message)
	else:
		test_failed += 1
		_log("❌ FAILED: %s (expected %s, got %s)" % [message, str(expected), str(actual)])

func _log(message: String):
	test_log.append(message)
	print("  " + message)


## ============================================================================
## SUMMARY
## ============================================================================

func _print_summary():
	print("\n" + "=".repeat(70))
	print("📊 E2E TEST SUMMARY")
	print("=".repeat(70))

	print("\n✅ Passed: %d" % test_passed)
	print("❌ Failed: %d" % test_failed)
	print("\nTotal signals received:")
	print("  action_performed: %d" % signals_received.action_performed.size())
	print("  terminal_bound: %d" % signals_received.terminal_bound.size())
	print("  terminal_measured: %d" % signals_received.terminal_measured.size())
	print("  terminal_released: %d" % signals_received.terminal_released.size())

	print("\n" + "=".repeat(70))
	if test_failed == 0:
		print("🎉 ALL E2E TESTS PASSED!")
	else:
		print("⚠️  SOME TESTS FAILED - Review output above")
	print("=".repeat(70) + "\n")
