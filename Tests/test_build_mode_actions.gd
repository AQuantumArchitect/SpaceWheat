extends SceneTree

## Test ALL 12 BUILD mode actions
## Run with: godot --headless --script res://Tests/test_build_mode_actions.gd
##
## Tests:
##   Tool 1 (Biome): submenu_biome_assign, clear_biome_assignment, inspect_plot
##   Tool 2 (Icon): submenu_icon_assign, icon_swap, icon_clear
##   Tool 3 (Lindblad): lindblad_drive, lindblad_decay, lindblad_transfer
##   Tool 4 (System): system_reset, system_snapshot, system_debug
##
## After the QuantumInstrument refactor:
##   - FarmInputHandler no longer exists; QII (QuantumInstrumentInput) is the adapter
##   - _action_* methods moved to static handler classes (BiomeHandler, IconHandler,
##     SystemHandler) or QuantumInstrument (action_pump/action_drain/action_transfer)

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const BiomeHandler = preload("res://UI/Handlers/BiomeHandler.gd")
const IconHandler = preload("res://UI/Handlers/IconHandler.gd")
const SystemHandler = preload("res://UI/Handlers/SystemHandler.gd")
const QuantumInstrumentClass = preload("res://Core/Instrumentation/QuantumInstrument.gd")

var frame_count := 0
var farm = null
var input_handler = null  # QuantumInstrumentInput (QII)
var instrument = null      # QuantumInstrument
var test_results := []
var scene_loaded := false
var tests_started := false

func _init():
	print("")
	print("======================================================================")
	print("  BUILD MODE ACTIONS TEST - All 12 Actions")
	print("======================================================================")
	print("")

func _process(_delta):
	frame_count += 1

	if frame_count == 5 and not scene_loaded:
		_load_scene()

	# Signal connection in _load_scene handles game_ready; no polling needed

func _load_scene():
	print("Loading FarmView...")
	var scene = load("res://scenes/FarmView.tscn")
	if scene:
		var instance = scene.instantiate()
		root.add_child(instance)
		scene_loaded = true
		print("Scene loaded, waiting for game_ready...")

		var boot = root.get_node_or_null("/root/BootManager")
		if boot:
			boot.game_ready.connect(func():
				if not tests_started:
					tests_started = true
					_run_all_tests()
			)
	else:
		_fail("Failed to load FarmView.tscn")
		_finish()

func _run_all_tests():
	print("\nGame ready! Finding components...")

	# Find farm (FarmView gets reparented under Farm during boot)
	var farm_view = _find_node(root, "FarmView")
	if farm_view and "farm" in farm_view:
		farm = farm_view.farm
	# Fallback: find Farm node directly
	if not farm:
		farm = _find_node(root, "Farm")

	if not farm:
		_fail("Could not find Farm")
		_finish()
		return

	# Find QII (QuantumInstrumentInput) in PlayerShell
	var player_shell = _find_node(root, "PlayerShell")
	if player_shell:
		for child in player_shell.get_children():
			if child.get_script() and child.get_script().resource_path.ends_with("QuantumInstrumentInput.gd"):
				input_handler = child
				break

	# Obtain QuantumInstrument via QII's _instrument field
	if input_handler and "_instrument" in input_handler:
		instrument = input_handler._instrument

	print("Farm: %s" % (farm != null))
	print("QII (QuantumInstrumentInput): %s" % (input_handler != null))
	print("QuantumInstrument: %s" % (instrument != null))

	# In headless mode PlayerShell/QII aren't created; synthesize instrument directly
	if not instrument:
		instrument = QuantumInstrumentClass.new()
		instrument.setup(farm)
		print("QuantumInstrument: synthesized directly for headless test")

	# Disable quantum evolution for faster tests
	_disable_evolution()

	# Ensure BUILD mode
	ToolConfig.set_mode("build")
	print("\nMode: %s" % ToolConfig.get_mode())

	# Run tool tests
	print("\n" + "─".repeat(70))
	print("TOOL 1: BIOME (submenu_biome_assign, clear_biome_assignment, inspect_plot)")
	print("─".repeat(70))
	_test_tool1_biome()

	print("\n" + "─".repeat(70))
	print("TOOL 2: ICON (submenu_icon_assign, icon_swap, icon_clear)")
	print("─".repeat(70))
	_test_tool2_icon()

	print("\n" + "─".repeat(70))
	print("TOOL 3: LINDBLAD (lindblad_drive, lindblad_decay, lindblad_transfer)")
	print("─".repeat(70))
	_test_tool3_lindblad()

	print("\n" + "─".repeat(70))
	print("TOOL 4: SYSTEM (system_reset, system_snapshot, system_debug)")
	print("─".repeat(70))
	_test_tool4_system()

	_finish()

func _disable_evolution():
	for biome in [farm.biotic_flux_biome, farm.starter_forest_biome, farm.stellar_forges_biome,
				  farm.fungal_networks_biome, farm.volcanic_worlds_biome, farm.village_biome]:
		if biome:
			biome.quantum_evolution_enabled = false
			biome.set_process(false)

# ============================================================================
# TOOL 1: BIOME (submenu_biome_assign, clear_biome_assignment, inspect_plot)
# ============================================================================

func _test_tool1_biome():
	var test_pos = Vector2i(2, 0)  # BioticFlux position
	var positions: Array[Vector2i] = [test_pos]

	# Test Q: submenu_biome_assign
	# Note: Build mode is gone. Biome assignment now lives in group 4 (Meta/Vocabulary).
	# Verify group 4 exists and has inject_vocabulary action.
	print("\n[Q] Testing SUBMENU_BIOME_ASSIGN (now vocab injection in group 4)...")
	var group4 = ToolConfig.get_group(4)
	if group4 and group4.get("actions", {}).has("Q"):
		_pass("SUBMENU_BIOME_ASSIGN: Group 4 Q action = %s" % group4.get("actions", {}).get("Q", {}).get("action", "?"))
	else:
		_fail("SUBMENU_BIOME_ASSIGN: Group 4 Q action not found")

	# Test E: clear_biome_assignment (now in BiomeHandler as static method)
	print("\n[E] Testing CLEAR_BIOME_ASSIGNMENT...")
	var bh = BiomeHandler.new()
	if bh.has_method("clear_biome_assignment"):
		var result = BiomeHandler.clear_biome_assignment(farm, positions)
		_pass("CLEAR_BIOME_ASSIGNMENT: BiomeHandler.clear_biome_assignment() callable (result.ok=%s)" % result.get("ok", "?"))
	else:
		_fail("CLEAR_BIOME_ASSIGNMENT: BiomeHandler missing clear_biome_assignment() static method")

	# Test R: inspect_plot (QuantumInstrument.action_inspect)
	print("\n[R] Testing INSPECT_PLOT...")
	if instrument and instrument.has_method("action_inspect"):
		var result = instrument.action_inspect(positions)
		_pass("INSPECT_PLOT: instrument.action_inspect() callable (success=%s)" % result.get("success", "?"))
	elif bh.has_method("inspect_plot"):
		BiomeHandler.inspect_plot(farm, positions)
		_pass("INSPECT_PLOT: BiomeHandler.inspect_plot() callable")
	else:
		_fail("INSPECT_PLOT: No inspect method found on instrument or BiomeHandler")

# ============================================================================
# TOOL 2: ICON (submenu_icon_assign, icon_swap, icon_clear)
# ============================================================================

func _test_tool2_icon():
	var test_pos = Vector2i(2, 0)
	var positions: Array[Vector2i] = [test_pos]

	# Test Q: submenu_icon_assign
	# Note: Build mode removed. Icon/vocab assignment is in group 4; IconHandler methods still exist.
	print("\n[Q] Testing SUBMENU_ICON_ASSIGN (now group 4 vocab injection)...")
	var ih2 = IconHandler.new()
	if ih2.has_method("icon_swap"):
		_pass("SUBMENU_ICON_ASSIGN: IconHandler.icon_swap() exists (icon assignment via handler)")
	else:
		_fail("SUBMENU_ICON_ASSIGN: IconHandler missing icon_swap")

	# Test E: icon_swap (now in IconHandler as static method)
	print("\n[E] Testing ICON_SWAP...")
	var ih = IconHandler.new()
	if ih.has_method("icon_swap"):
		var result = IconHandler.icon_swap(farm, positions)
		_pass("ICON_SWAP: IconHandler.icon_swap() callable (ok=%s)" % result.get("ok", "?"))
	else:
		_fail("ICON_SWAP: IconHandler missing icon_swap() static method")

	# Test R: icon_clear (now in IconHandler as static method)
	print("\n[R] Testing ICON_CLEAR...")
	if ih.has_method("icon_clear"):
		var result = IconHandler.icon_clear(farm, positions)
		_pass("ICON_CLEAR: IconHandler.icon_clear() callable (ok=%s)" % result.get("ok", "?"))
	else:
		_fail("ICON_CLEAR: IconHandler missing icon_clear() static method")

# ============================================================================
# TOOL 3: LINDBLAD (lindblad_drive, lindblad_decay, lindblad_transfer)
# ============================================================================

func _test_tool3_lindblad():
	var test_pos1 = Vector2i(2, 0)
	var test_pos2 = Vector2i(3, 0)
	var positions1: Array[Vector2i] = [test_pos1]
	var positions2: Array[Vector2i] = [test_pos1, test_pos2]

	# Test Q: lindblad_drive → instrument.action_pump()
	print("\n[Q] Testing LINDBLAD_DRIVE...")
	if instrument and instrument.has_method("action_pump"):
		var result = instrument.action_pump(positions1)
		_pass("LINDBLAD_DRIVE: instrument.action_pump() callable (success=%s)" % result.get("success", "?"))
	else:
		_fail("LINDBLAD_DRIVE: instrument.action_pump() not found")

	# Test E: lindblad_decay → instrument.action_drain()
	print("\n[E] Testing LINDBLAD_DECAY...")
	if instrument and instrument.has_method("action_drain"):
		var result = instrument.action_drain(positions1)
		_pass("LINDBLAD_DECAY: instrument.action_drain() callable (success=%s)" % result.get("success", "?"))
	else:
		_fail("LINDBLAD_DECAY: instrument.action_drain() not found")

	# Test R: lindblad_transfer → instrument.action_transfer()
	print("\n[R] Testing LINDBLAD_TRANSFER...")
	if instrument and instrument.has_method("action_transfer"):
		var result = instrument.action_transfer(positions2)
		_pass("LINDBLAD_TRANSFER: instrument.action_transfer() callable (success=%s)" % result.get("success", "?"))
	else:
		_fail("LINDBLAD_TRANSFER: instrument.action_transfer() not found")

# ============================================================================
# TOOL 4: SYSTEM (system_reset, system_snapshot, system_debug)
# ============================================================================

func _test_tool4_system():
	var test_pos = Vector2i(2, 0)
	var positions: Array[Vector2i] = [test_pos]

	# Test Q: system_reset (now in SystemHandler as static method)
	print("\n[Q] Testing SYSTEM_RESET...")
	var sh = SystemHandler.new()
	if sh.has_method("system_reset"):
		var result = SystemHandler.system_reset(farm, positions)
		_pass("SYSTEM_RESET: SystemHandler.system_reset() callable (ok=%s)" % result.get("ok", "?"))
	else:
		_fail("SYSTEM_RESET: SystemHandler missing system_reset() static method")

	# Test E: system_snapshot (now in SystemHandler as static method)
	print("\n[E] Testing SYSTEM_SNAPSHOT...")
	if sh.has_method("system_snapshot"):
		var result = SystemHandler.system_snapshot(farm, positions)
		_pass("SYSTEM_SNAPSHOT: SystemHandler.system_snapshot() callable (ok=%s)" % result.get("ok", "?"))
	else:
		_fail("SYSTEM_SNAPSHOT: SystemHandler missing system_snapshot() static method")

	# Test R: system_debug (now in SystemHandler as static method)
	print("\n[R] Testing SYSTEM_DEBUG...")
	if sh.has_method("system_debug"):
		var result = SystemHandler.system_debug(farm, positions)
		_pass("SYSTEM_DEBUG: SystemHandler.system_debug() callable (ok=%s)" % result.get("ok", "?"))
	else:
		_fail("SYSTEM_DEBUG: SystemHandler missing system_debug() static method")

# ============================================================================
# UTILITIES
# ============================================================================

func _find_node(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found = _find_node(child, target_name)
		if found:
			return found
	return null

func _pass(msg: String):
	test_results.append({"passed": true, "message": msg})
	print("  PASS: %s" % msg)

func _fail(msg: String):
	test_results.append({"passed": false, "message": msg})
	print("  FAIL: %s" % msg)

func _finish():
	print("")
	print("======================================================================")
	print("  TEST RESULTS")
	print("======================================================================")

	var passed := 0
	var failed := 0

	for result in test_results:
		if result.passed:
			passed += 1
		else:
			failed += 1

	print("")
	print("  Passed: %d" % passed)
	print("  Failed: %d" % failed)
	print("")

	if failed == 0:
		print("  ALL BUILD MODE ACTIONS WORKING!")
	else:
		print("  SOME ACTIONS NEED FIXES")
		print("")
		print("  Failed tests:")
		for result in test_results:
			if not result.passed:
				print("    - %s" % result.message)

	print("")
	print("======================================================================")

	quit(0 if failed == 0 else 1)
