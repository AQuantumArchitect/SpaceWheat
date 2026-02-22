extends SceneTree

## Test: Verify that different biomes have distinct quantum dynamics.
##
## Checks that:
##   1. StarterForest and Village biomes both load
##   2. They operate on different Hilbert space sizes (different num_qubits)
##   3. Exploring each biome binds a terminal to that biome
##   4. Terminals from different biomes have different bound_biome_name
##
## Run with: godot --headless --script res://Tests/test_biome_dynamics.gd

const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")

var frame_count := 0
var scene_loading := false
var tests_started := false
var test_results := []
var passed := 0
var failed := 0


func _process(_delta):
	frame_count += 1
	if frame_count == 5 and not scene_loading:
		scene_loading = true
		_load_scene()


func _load_scene():
	var scene = load("res://scenes/FarmView.tscn")
	if not scene:
		_fail("Could not load FarmView.tscn")
		_finish()
		return
	root.add_child(scene.instantiate())
	var boot = root.get_node_or_null("/root/BootManager")
	if boot:
		boot.game_ready.connect(func():
			if not tests_started:
				tests_started = true
				_run_tests()
		)
	else:
		_fail("BootManager not found")
		_finish()


func _run_tests():
	print("\n" + "=".repeat(70))
	print("  BIOME DYNAMICS TEST")
	print("=".repeat(70))

	var farm = _find_node(root, "Farm")
	if not farm:
		_fail("Could not find Farm node")
		_finish()
		return

	# ─── Test 1: Both biomes present ───────────────────────────────────────
	var sf: Object = farm.get("starter_forest_biome")
	var vl: Object = farm.get("village_biome")

	if sf:
		_pass("StarterForest biome loaded")
	else:
		_fail("StarterForest biome not found on Farm")

	if vl:
		_pass("Village biome loaded")
	else:
		_fail("Village biome not found on Farm")

	if not sf or not vl:
		_finish()
		return

	# ─── Test 2: Biomes have different Hilbert space sizes ─────────────────
	# num_qubits lives on quantum_computer.register_map, not quantum_computer directly
	var sf_qubits: int = _get_num_qubits(sf)
	var vl_qubits: int = _get_num_qubits(vl)

	if sf_qubits > 0 and vl_qubits > 0:
		if sf_qubits != vl_qubits:
			_pass("Biomes have different Hilbert spaces: StarterForest=%d qubits, Village=%d qubits" % [sf_qubits, vl_qubits])
		else:
			_fail("Both biomes share the same Hilbert space size (%d qubits) — dynamics may be identical" % sf_qubits)
	else:
		_fail("Could not read num_qubits from biomes (SF=%d, VL=%d)" % [sf_qubits, vl_qubits])

	# ─── Test 3: Explore both biomes ───────────────────────────────────────
	farm.economy.add_resource("🍞", 200, "test_setup")

	var sf_result = ProbeActions.action_explore(farm.terminal_pool, sf, farm.economy)
	if sf_result.get("success", false):
		_pass("Explored StarterForest successfully")
	else:
		_fail("Explore StarterForest failed: %s" % sf_result.get("reason", "?"))

	var vl_result = ProbeActions.action_explore(farm.terminal_pool, vl, farm.economy)
	if vl_result.get("success", false):
		_pass("Explored Village successfully")
	else:
		_fail("Explore Village failed: %s" % vl_result.get("reason", "?"))

	# ─── Test 4: Terminals bound to distinct biomes ─────────────────────────
	var sf_terminals = farm.terminal_pool.get_terminals_in_biome(sf.name)
	var vl_terminals = farm.terminal_pool.get_terminals_in_biome(vl.name)

	if sf_terminals.size() > 0:
		_pass("StarterForest has %d bound terminal(s)" % sf_terminals.size())
	else:
		_fail("No terminals bound to StarterForest after explore")

	if vl_terminals.size() > 0:
		_pass("Village has %d bound terminal(s)" % vl_terminals.size())
	else:
		_fail("No terminals bound to Village after explore")

	# ─── Test 5: Terminals carry correct biome name ────────────────────────
	var sf_t = sf_terminals[0] if sf_terminals.size() > 0 else null
	var vl_t = vl_terminals[0] if vl_terminals.size() > 0 else null

	if sf_t and sf_t.bound_biome_name == sf.name:
		_pass("StarterForest terminal.bound_biome_name = '%s'" % sf_t.bound_biome_name)
	elif sf_t:
		_fail("StarterForest terminal has wrong biome_name='%s' (expected '%s')" % [sf_t.bound_biome_name, sf.name])

	if vl_t and vl_t.bound_biome_name == vl.name:
		_pass("Village terminal.bound_biome_name = '%s'" % vl_t.bound_biome_name)
	elif vl_t:
		_fail("Village terminal has wrong biome_name='%s' (expected '%s')" % [vl_t.bound_biome_name, vl.name])

	if sf_t and vl_t and sf_t.bound_biome_name != vl_t.bound_biome_name:
		_pass("Terminals are in distinct biomes — different dynamics guaranteed")
	elif sf_t and vl_t:
		_fail("Both terminals claim the same biome — biome routing is broken")

	_finish()


# ─── Utilities ───────────────────────────────────────────────────────────────

func _get_num_qubits(biome: Object) -> int:
	var qc = biome.get("quantum_computer")
	if qc == null:
		return -1
	var rm = qc.get("register_map")
	if rm == null:
		return -1
	return rm.num_qubits


func _find_node(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found = _find_node(child, target_name)
		if found:
			return found
	return null


func _pass(msg: String):
	passed += 1
	print("  PASS: %s" % msg)


func _fail(msg: String):
	failed += 1
	print("  FAIL: %s" % msg)


func _finish():
	print("\n" + "=".repeat(70))
	print("  RESULTS: %d passed, %d failed" % [passed, failed])
	print("=".repeat(70))
	quit(0 if failed == 0 else 1)
