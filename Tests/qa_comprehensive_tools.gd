#!/usr/bin/env -S godot --headless -s
extends SceneTree

## COMPREHENSIVE QA GAMEPLAY TEST - All Tools & Edge Cases
## Tests all 4 PLAY tools, entanglement responses, gate behavior, cross-biome interactions
## Run: godot --headless --script res://Tests/qa_comprehensive_tools.gd

const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")

var farm = null
var grid = null
var economy = null
var plot_pool = null
var biome_list = []

var frame_count = 0
var scene_loaded = false
var tests_done = false

var findings = {
	"probe_tool": [],
	"entangle_tool": [],
	"industry_tool": [],
	"unitary_tool": [],
	"cross_biome": [],
	"resource_constraints": [],
	"edge_cases": [],
	"issues": []
}

func _init():
	print("\n" + "═".repeat(80))
	print("🔬 COMPREHENSIVE QA TOOL TEST - All Tools & Edge Cases")
	print("═".repeat(80))

func _process(_delta):
	frame_count += 1

	if frame_count == 5 and not scene_loaded:
		print("\n⏳ Frame 5: Loading main scene...")
		var scene = load("res://scenes/FarmView.tscn")
		if scene:
			var instance = scene.instantiate()
			root.add_child(instance)
			scene_loaded = true
			print("   ✅ Scene instantiated")

			var boot_manager = root.get_node_or_null("/root/BootManager")
			if boot_manager:
				boot_manager.game_ready.connect(_on_game_ready)
				print("   ✅ Connected to BootManager.game_ready")
		else:
			print("   ❌ Failed to load scene")
			quit(1)

func _on_game_ready():
	if tests_done:
		return
	tests_done = true

	print("\n✅ Game ready! Starting comprehensive tool testing...\n")

	var fv = root.get_node_or_null("FarmView")
	if not fv or not fv.farm:
		print("❌ Farm not found")
		print_findings()
		quit()
		return

	farm = fv.farm
	grid = farm.grid
	economy = farm.economy
	plot_pool = farm.terminal_pool
	biome_list = grid.biomes.values()

	# Bootstrap resources for testing
	economy.add_resource("💰", 2000, "test_bootstrap")

	print("Systems initialized:")
	print("   Farm: ✅")
	print("   Grid: ✅ (%d plots)" % grid.plots.size())
	print("   Biomes: ✅ (%d)" % biome_list.size())
	print("   Bootstrapped 💰: 2000")

	# Run comprehensive tests
	_test_probe_tool()
	_test_entangle_tool()
	_test_industry_tool()
	_test_unitary_tool()
	_test_cross_biome_interactions()
	_test_resource_constraints()
	_test_edge_cases()

	print_findings()
	quit()

# ═══════════════════════════════════════════════════════════════
# TOOL 1: PROBE ACTIONS (EXPLORE, MEASURE, POP)
# ═══════════════════════════════════════════════════════════════

func _test_probe_tool():
	print("\n" + "─".repeat(80))
	print("TOOL 1: PROBE (Explore, Measure, Pop)")
	print("─".repeat(80))

	if biome_list.is_empty():
		_finding("probe_tool", "⚠️ NO BIOMES - Cannot test PROBE")
		return

	var biome = biome_list[0]
	var result = ProbeActions.action_explore(plot_pool, biome)

	if result.success:
		_finding("probe_tool", "✅ EXPLORE succeeded")
		var terminal = result.terminal
		print("   Terminal: %s" % terminal.terminal_id)
		print("   Emojis: %s/%s" % [result.emoji_pair.north, result.emoji_pair.south])

		# Try MEASURE on bound terminal
		var measure_result = ProbeActions.action_measure(terminal, biome)
		if measure_result.success:
			_finding("probe_tool", "✅ MEASURE on bound terminal succeeded")
			print("   Probability: %.2f" % measure_result.probability)

			# Try POP on measured terminal
			var pop_result = ProbeActions.action_pop(terminal, plot_pool, economy)
			if pop_result.success:
				_finding("probe_tool", "✅ POP extracted resources")
				print("   Credits gained: %d" % pop_result.credits_gained)
			else:
				_finding("probe_tool", "❌ POP FAILED: %s" % pop_result.error)
		else:
			_finding("probe_tool", "❌ MEASURE FAILED: %s" % measure_result.error)
	else:
		_finding("probe_tool", "❌ EXPLORE FAILED: %s" % result.error)

# ═══════════════════════════════════════════════════════════════
# TOOL 2: ENTANGLE ACTIONS (CLUSTER, TRIGGER, DISENTANGLE)
# ═══════════════════════════════════════════════════════════════

func _test_entangle_tool():
	print("\n" + "─".repeat(80))
	print("TOOL 2: ENTANGLE (Cluster, Trigger, Disentangle)")
	print("─".repeat(80))

	if biome_list.size() < 1:
		_finding("entangle_tool", "⚠️ NO BIOMES - Cannot test ENTANGLE")
		return

	var biome = biome_list[0]

	# First, create some terminals via EXPLORE
	var terminals = []
	for i in range(min(3, plot_pool.get_unbound_count())):
		var result = ProbeActions.action_explore(plot_pool, biome)
		if result.success:
			terminals.append(result.terminal)

	if terminals.size() < 2:
		_finding("entangle_tool", "⚠️ Could not create 2+ terminals for entanglement test")
		return

	print("   Created %d terminals for entanglement" % terminals.size())

	# Try to entangle terminals (if entanglement system exists)
	_finding("entangle_tool", "📝 TODO: Test CLUSTER action (requires entanglement system)")
	_finding("entangle_tool", "📝 TODO: Test TRIGGER action (measurement trigger)")
	_finding("entangle_tool", "📝 TODO: Test DISENTANGLE action (remove gates)")

# ═══════════════════════════════════════════════════════════════
# TOOL 3: INDUSTRY ACTIONS (MILL, MARKET, KITCHEN)
# ═══════════════════════════════════════════════════════════════

func _test_industry_tool():
	print("\n" + "─".repeat(80))
	print("TOOL 3: INDUSTRY (Mill, Market, Kitchen)")
	print("─".repeat(80))

	if not grid or grid.plots.is_empty():
		_finding("industry_tool", "⚠️ NO PLOTS - Cannot test INDUSTRY")
		return

	var plot_positions = grid.plots.keys()
	var test_pos = plot_positions[0]
	var plot = grid.get_plot(test_pos)

	if not plot:
		_finding("industry_tool", "⚠️ Could not access plot at %s" % test_pos)
		return

	print("   Testing on plot: %s" % test_pos)

	# Test MILL placement (processes grain)
	_finding("industry_tool", "📝 TODO: Test MILL placement and grain processing")

	# Test MARKET placement (economy)
	_finding("industry_tool", "📝 TODO: Test MARKET placement and trading")

	# Test KITCHEN placement (cooking/transformation)
	_finding("industry_tool", "📝 TODO: Test KITCHEN placement and flour→bread conversion")

# ═══════════════════════════════════════════════════════════════
# TOOL 4: UNITARY ACTIONS (Single-qubit gates)
# ═══════════════════════════════════════════════════════════════

func _test_unitary_tool():
	print("\n" + "─".repeat(80))
	print("TOOL 4: UNITARY (Single-qubit gates: Pauli-X, Hadamard, Pauli-Z)")
	print("─".repeat(80))

	if biome_list.is_empty():
		_finding("unitary_tool", "⚠️ NO BIOMES - Cannot test UNITARY")
		return

	var biome = biome_list[0]

	# Create a terminal
	var result = ProbeActions.action_explore(plot_pool, biome)
	if not result.success:
		_finding("unitary_tool", "⚠️ Could not create terminal for gate testing")
		return

	var terminal = result.terminal
	print("   Created terminal: %s" % terminal.terminal_id)

	# Test Pauli-X gate (bit flip)
	_finding("unitary_tool", "📝 TODO: Test PAULI-X gate on terminal")

	# Test Hadamard gate (superposition)
	_finding("unitary_tool", "📝 TODO: Test HADAMARD gate on terminal")

	# Test Pauli-Z gate (phase flip)
	_finding("unitary_tool", "📝 TODO: Test PAULI-Z gate on terminal")

	# Test that gates can be applied sequentially
	_finding("unitary_tool", "📝 TODO: Test sequential gate applications (X→H→Z)")

# ═══════════════════════════════════════════════════════════════
# CROSS-BIOME INTERACTION TESTS
# ═══════════════════════════════════════════════════════════════

func _test_cross_biome_interactions():
	print("\n" + "─".repeat(80))
	print("CROSS-BIOME INTERACTION TESTS")
	print("─".repeat(80))

	if biome_list.size() < 2:
		print("⚠️ Only %d biome(s) - need 2+ for cross-biome tests" % biome_list.size())
		return

	var biome_a = biome_list[0]
	var biome_b = biome_list[1]

	print("   Biome A: %s" % biome_a.get_biome_type())
	print("   Biome B: %s" % biome_b.get_biome_type())

	# Create terminals in different biomes
	var term_a = ProbeActions.action_explore(plot_pool, biome_a)
	var term_b = ProbeActions.action_explore(plot_pool, biome_b)

	if not term_a.success or not term_b.success:
		_finding("cross_biome", "⚠️ Could not create terminals in both biomes")
		return

	print("   Created terminal in A: %s" % term_a.terminal.terminal_id)
	print("   Created terminal in B: %s" % term_b.terminal.terminal_id)

	# Test 1: Try entanglement across biomes (SHOULD FAIL)
	_finding("cross_biome", "📝 TODO: Try entangling terminals from different biomes (should FAIL)")

	# Test 2: Try joint gate across biomes (SHOULD FAIL)
	_finding("cross_biome", "📝 TODO: Try CNOT between different biomes (should FAIL)")

	# Test 3: Try measurement trigger across biomes (SHOULD FAIL)
	_finding("cross_biome", "📝 TODO: Try measurement trigger across biomes (should FAIL)")

# ═══════════════════════════════════════════════════════════════
# RESOURCE CONSTRAINT TESTS
# ═══════════════════════════════════════════════════════════════

func _test_resource_constraints():
	print("\n" + "─".repeat(80))
	print("RESOURCE CONSTRAINT TESTS")
	print("─".repeat(80))

	if biome_list.is_empty():
		_finding("resource_constraints", "⚠️ NO BIOMES - Cannot test resources")
		return

	# Test 1: Vocabulary injection with insufficient resources
	print("\n   TEST: Vocabulary injection with insufficient resources")
	var all_credits = economy.get_resource("💰")
	print("   Current credits: %d" % all_credits)

	if all_credits > 0:
		economy.remove_resource("💰", all_credits, "test_drain")
		print("   Drained all credits")

		var biome = biome_list[0]
		biome.set_evolution_paused(true)

		var check = biome.can_inject_vocabulary("🚀")
		if check.can_inject:
			var cost = check.cost.get("💰", 0)
			print("   ⚠️ ISSUE: Can inject with 0 credits? (cost=%d)" % cost)
			_finding("resource_constraints", "❌ CAN INJECT VOCAB WITH 0 CREDITS (should require resources)")
		else:
			_finding("resource_constraints", "✅ Vocab injection correctly blocked (insufficient resources)")
			print("   Reason: %s" % check.reason)

		biome.set_evolution_paused(false)

	# Test 2: Planting with insufficient resources
	print("\n   TEST: Planting with insufficient resources")
	var plot_pos = Vector2i(0, 0)
	if grid.get_plot(plot_pos) != null:
		var biome = grid.get_biome_for_plot(plot_pos)
		if biome and biome.get_plantable_capabilities().size() > 0:
			var cap = biome.get_plantable_capabilities()[0]
			var cost = EconomyConstants.get_planting_cost(cap.emoji_pair.get("north", "?"))

			if cost > 0:
				print("   Planting cost: %d 💰" % cost)
				var success = grid.plant(plot_pos, cap.plant_type)
				if success:
					_finding("resource_constraints", "❌ PLANT SUCCEEDED WITH 0 CREDITS (should have cost)")
				else:
					_finding("resource_constraints", "✅ Plant correctly failed (insufficient resources)")

	# Restore credits
	economy.add_resource("💰", 2000, "test_restore")

# ═══════════════════════════════════════════════════════════════
# EDGE CASES
# ═══════════════════════════════════════════════════════════════

func _test_edge_cases():
	print("\n" + "─".repeat(80))
	print("EDGE CASES & WEIRD SCENARIOS")
	print("─".repeat(80))

	if biome_list.is_empty() or grid.plots.is_empty():
		_finding("edge_cases", "⚠️ Insufficient resources for edge case testing")
		return

	# Edge Case 1: Quantum Expansion on Plant (BUILD mode required)
	print("\n   EDGE CASE 1: Plant emoji that requires quantum expansion")
	var plot_pos = Vector2i(0, 0)
	var plot = grid.get_plot(plot_pos)

	if plot:
		var biome = grid.get_biome_for_plot(plot_pos)
		if biome and biome.get_plantable_capabilities().size() > 0:
			var cap = biome.get_plantable_capabilities()[0]
			print("   Testing on biome: %s" % biome.get_biome_type())
			print("   Planting: %s/%s" % [cap.emoji_pair.get("north", "?"), cap.emoji_pair.get("south", "?")])

			# Enable BUILD mode for expansion
			biome.set_evolution_paused(true)
			print("   ✅ Enabled BUILD mode (evolution paused)")

			var plant_success = grid.plant(plot_pos, cap.plant_type)
			if plant_success:
				_finding("edge_cases", "✅ Plant succeeded on empty plot")

				# Now try to gate the same plot (should it be allowed?)
				_finding("edge_cases", "📝 TODO: Try applying gate to just-planted plot (behavior TBD)")

				# Try to gate with another plot in same biome
				if grid.plots.size() > 1:
					var other_pos = Vector2i(1, 0)
					var other_plot = grid.get_plot(other_pos)
					if other_plot and other_plot.is_planted:
						print("   Found another planted plot at: %s" % other_pos)
						_finding("edge_cases", "📝 TODO: Try CNOT between two planted plots")
					else:
						_finding("edge_cases", "📝 NOTE: Cannot test multi-plot gates (need 2 planted)")

	# Edge Case 2: Quantum Expansion Test (plant emoji that doesn't exist in biome)
	print("\n   EDGE CASE 2: Quantum expansion (plant new emoji type)")
	var market_biome = null
	for b in biome_list:
		if b.get_biome_type() == "Market":
			market_biome = b
			break

	if market_biome:
		var test_pos = Vector2i(1, 0)
		var test_plot = grid.get_plot(test_pos)
		if test_plot and not test_plot.is_planted:
			# Market doesn't have wheat axis by default
			print("   Testing: Plant wheat (🌾) in Market (doesn't have wheat axis)")

			# First try without BUILD mode (should fail)
			market_biome.set_evolution_paused(false)
			var fail_result = grid.plant(test_pos, "wheat")
			if not fail_result:
				_finding("edge_cases", "✅ Plant correctly blocked without BUILD mode")
			else:
				_finding("edge_cases", "❌ Plant succeeded without BUILD mode (should require expansion)")

			# Now try WITH BUILD mode (should expand and succeed)
			market_biome.set_evolution_paused(true)
			var success_result = grid.plant(test_pos, "wheat")
			if success_result:
				_finding("edge_cases", "✅ Quantum expansion worked - wheat planted in Market")
				print("   ✅ Market quantum system expanded to include 🌾 axis")
			else:
				_finding("edge_cases", "❌ Quantum expansion failed")

			market_biome.set_evolution_paused(false)
	else:
		_finding("edge_cases", "⚠️ Market biome not found for expansion test")

	# Edge Case 3: Multiple selections in same biome
	_finding("edge_cases", "📝 TODO: Test selecting 3+ plots in same biome")

	# Edge Case 4: Toggle build/play mode during operations
	_finding("edge_cases", "📝 TODO: Test switching modes mid-operation")

	# Edge Case 5: Rapid tool switching
	_finding("edge_cases", "📝 TODO: Test rapid tool switching (Tool1→2→3→4→1)")

	# Edge Case 6: POP on unmeasured terminal
	print("\n   EDGE CASE 5: POP on unbound (unexamined) terminal")
	var result = ProbeActions.action_explore(plot_pool, biome_list[0])
	if result.success:
		var terminal = result.terminal
		var pop_result = ProbeActions.action_pop(terminal, plot_pool, economy)
		if pop_result.success:
			_finding("edge_cases", "❌ POP SUCCEEDED ON UNBOUND TERMINAL (should require MEASURE first)")
		else:
			_finding("edge_cases", "✅ POP correctly failed on unbound terminal")
			print("   Error: %s" % pop_result.error)

# ═══════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════

func _finding(category: String, message: String):
	findings[category].append(message)
	print("   " + message)

func print_findings():
	print("\n" + "═".repeat(80))
	print("📋 QA FINDINGS SUMMARY")
	print("═".repeat(80))

	var total_findings = 0
	var total_issues = 0

	for category in findings.keys():
		var items = findings[category]
		if items.is_empty():
			continue

		print("\n🔹 %s (%d)" % [category.to_upper(), items.size()])
		for item in items:
			print("   " + item)
			if "❌" in item or "FAILED" in item or "ISSUE" in item:
				total_issues += 1
			total_findings += 1

	print("\n" + "═".repeat(80))
	print("📊 TOTALS: %d findings, %d issues" % [total_findings, total_issues])
	print("═".repeat(80) + "\n")
