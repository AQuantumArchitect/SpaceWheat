extends SceneTree

## Test Unitary Gate Application (Group 1 QER)
## Verifies that gates actually modify the density matrix

const QuantumGateLibrary = preload("res://Core/QuantumSubstrate/QuantumGateLibrary.gd")

var farm = null
var passed := 0
var failed := 0
var scene_loaded := false
var game_ready := false
var frame_count := 0


func _init():
	print("\n" + "=".repeat(70))
	print("TEST: Unitary Gate Application (1QER)")
	print("=".repeat(70))


func _process(_delta):
	frame_count += 1
	if frame_count == 5 and not scene_loaded:
		_load_scene()


func _load_scene():
	var scene = load("res://scenes/FarmView.tscn")
	if not scene:
		print("FAIL: Could not load FarmView.tscn")
		quit(1)
		return

	var instance = scene.instantiate()
	root.add_child(instance)
	scene_loaded = true

	var boot = root.get_node_or_null("/root/BootManager")
	if boot:
		boot.game_ready.connect(_on_game_ready)


func _on_game_ready():
	if game_ready:
		return
	game_ready = true

	var farm_view = root.get_node_or_null("FarmView")
	if farm_view and "farm" in farm_view:
		farm = farm_view.farm

	if not farm:
		print("FAIL: No farm found")
		quit(1)
		return

	_run_tests()
	_print_summary()
	quit(0 if failed == 0 else 1)


func _run_tests():
	print("\n--- Test Setup ---")

	# Get biome and quantum computer
	var biome = farm.biotic_flux_biome
	if not biome:
		_fail("No BioticFlux biome")
		return

	var qc = biome.quantum_computer
	if not qc:
		_fail("No quantum computer")
		return

	print("Biome: %s" % biome.name)
	print("Quantum Computer: %d qubits" % qc.register_map.num_qubits)
	print("Density matrix: %s" % ("present" if qc.density_matrix else "NULL"))

	if not qc.density_matrix:
		_fail("Density matrix is null")
		return

	# Get initial state
	var initial_trace = qc.density_matrix.trace()
	print("Initial trace: %s" % initial_trace)

	# Test 1: Apply Hadamard to qubit 0
	print("\n--- Test 1: Hadamard Gate (direct) ---")
	var gate_lib = QuantumGateLibrary.new()
	var H = gate_lib.GATES["H"]["matrix"]

	if not H:
		_fail("Could not get Hadamard matrix")
		return

	print("Hadamard matrix: %dx%d" % [H.n, H.n])

	# Get diagonal element before
	var diag_00_before = qc.density_matrix.get_element(0, 0)
	print("rho[0,0] before: %s" % diag_00_before)

	# Apply gate
	var success = qc.apply_gate(0, H)

	if success:
		_pass("apply_gate(0, H) returned true")
	else:
		_fail("apply_gate(0, H) returned false")

	# Get diagonal element after
	var diag_00_after = qc.density_matrix.get_element(0, 0)
	print("rho[0,0] after: %s" % diag_00_after)

	# Check if state changed
	var diff_real = abs(diag_00_after.re - diag_00_before.re)
	var diff_imag = abs(diag_00_after.im - diag_00_before.im)
	print("Change in rho[0,0]: real=%.6f, imag=%.6f" % [diff_real, diff_imag])

	if diff_real > 0.001 or diff_imag > 0.001:
		_pass("Density matrix changed after Hadamard")
	else:
		_fail("Density matrix did NOT change after Hadamard")

	# Check trace preserved
	var final_trace = qc.density_matrix.trace()
	print("Final trace: %s" % final_trace)

	var trace_diff = abs(final_trace.re - initial_trace.re)
	if trace_diff < 0.01:
		_pass("Trace preserved (diff=%.6f)" % trace_diff)
	else:
		_fail("Trace NOT preserved (diff=%.6f)" % trace_diff)

	# Test 2: Test via GateActionHandler (full stack)
	print("\n--- Test 2: Full Stack via GateActionHandler ---")

	var plot_pool = farm.plot_pool
	if not plot_pool:
		print("SKIP: No plot pool")
		return

	var terminal = plot_pool.get_unbound_terminal()
	if not terminal:
		print("SKIP: No unbound terminals")
		return

	# Bind terminal to register 0
	var emoji_pair = {"north": "test_n", "south": "test_s"}
	terminal.bind_to_register(0, biome, emoji_pair)
	terminal.grid_position = Vector2i(0, 0)

	print("Terminal bound: %s at %s, register=%d" % [terminal.terminal_id, terminal.grid_position, terminal.bound_register_id])

	# Verify terminal is findable
	var found = plot_pool.get_terminal_at_grid_pos(Vector2i(0, 0))
	if found:
		_pass("Terminal found at grid (0,0)")
	else:
		_fail("Terminal NOT found at grid (0,0)")
		return

	# Now test via GateActionHandler
	const GateActionHandler = preload("res://UI/Handlers/GateActionHandler.gd")

	var positions: Array[Vector2i] = [Vector2i(0, 0)]
	var diag_before_full = qc.density_matrix.get_element(0, 0)
	print("rho[0,0] before GateActionHandler: %s" % diag_before_full)

	var result = GateActionHandler.apply_hadamard(farm, positions)
	print("GateActionHandler result: %s" % result)

	if result.success:
		_pass("GateActionHandler.apply_hadamard succeeded")
	else:
		_fail("GateActionHandler.apply_hadamard failed: %s" % result.get("message", "unknown"))
		return

	var diag_after_full = qc.density_matrix.get_element(0, 0)
	print("rho[0,0] after GateActionHandler: %s" % diag_after_full)

	var full_diff = abs(diag_after_full.re - diag_before_full.re)
	print("Change: %.6f" % full_diff)

	if full_diff > 0.001:
		_pass("Full stack: Density matrix changed")
	else:
		_fail("Full stack: Density matrix did NOT change")

	# Cleanup
	terminal.unbind()


func _pass(msg: String):
	passed += 1
	print("  PASS: %s" % msg)


func _fail(msg: String):
	failed += 1
	print("  FAIL: %s" % msg)


func _print_summary():
	print("\n" + "=".repeat(70))
	print("SUMMARY: %d passed, %d failed" % [passed, failed])
	print("=".repeat(70))
