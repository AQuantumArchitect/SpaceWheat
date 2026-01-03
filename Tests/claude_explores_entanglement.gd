extends SceneTree

## 🔗 CLAUDE EXPLORES ENTANGLEMENT - Quantum Farmer Achievement Hunt!
## Goal: Create first entanglement and test the system

const Farm = preload("res://Core/Farm.gd")

var farm: Farm
var current_turn: int = 0
var game_time: float = 0.0

# Statistics
var entanglements_created: int = 0
var entanglement_attempts: int = 0


func _initialize():
	print("\n" + "=".repeat(80))
	print("🔗 CLAUDE EXPLORES ENTANGLEMENT - Quantum Farmer Quest!")
	print("=".repeat(80))
	print("Mission:")
	print("  1. Unlock 'Quantum Farmer' (1 entanglement)")
	print("  2. Test entanglement mechanics")
	print("  3. Hunt for bugs in the entanglement system")
	print("  4. Document any weird behavior")
	print("=".repeat(80) + "\n")

	await get_root().ready
	await _setup_game()

	print("\n📋 STRATEGY: Plant adjacent plots and entangle them")
	print("   - Plant 2 wheat plots side by side")
	print("   - Entangle them")
	print("   - Verify entanglement tracking")
	print("   - Test measurement cascade (if implemented)\n")

	# Play turn-based exploration
	var max_turns = 20
	while current_turn < max_turns:
		await _play_turn()

		# Check for Quantum Farmer completion
		if farm.goals.progress["entanglement_count"] >= 1:
			print("\n" + "=".repeat(80))
			print("🎉 QUANTUM FARMER UNLOCKED! 🎉")
			print("=".repeat(80))
			print("Total turns: %d" % current_turn)
			print("Entanglements created: %d" % entanglements_created)
			print("Entanglement attempts: %d" % entanglement_attempts)
			print("Success rate: %.1f%%" % (100.0 * entanglements_created / max(1, entanglement_attempts)))
			print("=".repeat(80) + "\n")
			break

	# Final report
	_print_final_report()

	quit(0)


func _setup_game():
	print("Setting up game world...")

	# Create farm
	farm = Farm.new()
	get_root().add_child(farm)
	for i in range(10):
		await process_frame

	print("✅ Game world ready!")
	print("📊 Starting resources: 🌾%d 👥%d\n" % [
		farm.economy.get_resource("🌾"),
		farm.economy.get_resource("👥")
	])


func _play_turn():
	"""Play one exploration turn"""
	current_turn += 1

	if current_turn % 5 == 1:
		print("──────────────────────────────────────────────────────────────────────")
		print("🎮 TURN %d" % current_turn)
		print("──────────────────────────────────────────────────────────────────────")

	_decide_action()
	await process_frame


func _decide_action():
	"""Entanglement exploration strategy"""
	var wheat_credits = farm.economy.get_resource("🌾")
	var labor_credits = farm.economy.get_resource("👥")

	print("\n🎮 Turn %d: 🌾%d 👥%d" % [current_turn, wheat_credits, labor_credits])

	# Turn 1-2: Plant two adjacent plots
	if current_turn == 1:
		print("   🌱 Planting wheat at (0,0)")
		var success = farm.build(Vector2i(0, 0), "wheat")
		print("   Result: %s" % ("✅ Success" if success else "❌ Failed"))

	elif current_turn == 2:
		print("   🌱 Planting wheat at (1,0)")
		var success = farm.build(Vector2i(1, 0), "wheat")
		print("   Result: %s" % ("✅ Success" if success else "❌ Failed"))

	# Turn 3: Wait for some quantum evolution
	elif current_turn == 3:
		print("   ⏳ Waiting 30s for quantum evolution...")
		_advance_all_biomes(30.0)
		_debug_plot_state(Vector2i(0, 0))
		_debug_plot_state(Vector2i(1, 0))

	# Turn 4: ENTANGLE THE PLOTS!
	elif current_turn == 4:
		print("   🔗 Attempting entanglement: (0,0) ↔ (1,0)")
		entanglement_attempts += 1

		var success = farm.entangle_plots(Vector2i(0, 0), Vector2i(1, 0), "phi_plus")

		if success:
			entanglements_created += 1
			print("   ✅ ENTANGLEMENT CREATED!")
			print("   📊 Goals entanglement_count: %d" % farm.goals.progress["entanglement_count"])
		else:
			print("   ❌ ENTANGLEMENT FAILED!")
			print("   📊 Checking why...")
			_debug_entanglement_failure(Vector2i(0, 0), Vector2i(1, 0))

	# Turn 5: Verify entanglement persists
	elif current_turn == 5:
		print("   🔍 Verifying entanglement...")
		_verify_entanglement(Vector2i(0, 0), Vector2i(1, 0))

	# Turn 6: Wait more, see if entanglement affects growth
	elif current_turn == 6:
		print("   ⏳ Waiting 30s more (testing entangled evolution)...")
		_advance_all_biomes(30.0)
		_debug_plot_state(Vector2i(0, 0))
		_debug_plot_state(Vector2i(1, 0))

	# Turn 7: Measure first plot
	elif current_turn == 7:
		print("   🔬 Measuring plot (0,0)")
		var outcome = farm.measure_plot(Vector2i(0, 0))
		print("   Outcome: %s" % outcome)
		print("   📊 Checking correlation with partner...")
		_debug_plot_state(Vector2i(1, 0))

	# Turn 8: Measure second plot (test correlation)
	elif current_turn == 8:
		print("   🔬 Measuring plot (1,0)")
		var outcome = farm.measure_plot(Vector2i(1, 0))
		print("   Outcome: %s" % outcome)
		print("   📊 Testing Bell correlation...")
		_test_bell_correlation(Vector2i(0, 0), Vector2i(1, 0))

	# Turn 9-10: Harvest and test entanglement cleanup
	elif current_turn == 9:
		print("   ✂️  Harvesting plot (0,0)")
		var result = farm.harvest_plot(Vector2i(0, 0))
		if result.get("success"):
			print("   Yield: %s → +%d credits" % [result.get("outcome"), result.get("yield")])
		print("   📊 Does entanglement persist after harvest?")
		_verify_entanglement(Vector2i(0, 0), Vector2i(1, 0))

	elif current_turn == 10:
		print("   ✂️  Harvesting plot (1,0)")
		var result = farm.harvest_plot(Vector2i(1, 0))
		if result.get("success"):
			print("   Yield: %s → +%d credits" % [result.get("outcome"), result.get("yield")])
		print("   📊 Entanglement should be broken now...")
		_verify_entanglement(Vector2i(0, 0), Vector2i(1, 0))

	# Turn 11+: Try entangling MORE plots (test limits)
	elif current_turn == 11:
		print("   🌱 Planting 4 plots in a square")
		farm.build(Vector2i(0, 0), "wheat")
		farm.build(Vector2i(1, 0), "wheat")
		farm.build(Vector2i(0, 1), "wheat")
		farm.build(Vector2i(1, 1), "wheat")
		_advance_all_biomes(30.0)

	elif current_turn == 12:
		print("   🔗 Creating entanglement network (square)")
		entanglement_attempts += 4
		var e1 = farm.entangle_plots(Vector2i(0, 0), Vector2i(1, 0))
		var e2 = farm.entangle_plots(Vector2i(1, 0), Vector2i(1, 1))
		var e3 = farm.entangle_plots(Vector2i(1, 1), Vector2i(0, 1))
		var e4 = farm.entangle_plots(Vector2i(0, 1), Vector2i(0, 0))
		entanglements_created += [e1, e2, e3, e4].count(true)
		print("   Created: %d/4 entanglements" % [e1, e2, e3, e4].count(true))
		print("   📊 Total entanglement_count: %d" % farm.goals.progress["entanglement_count"])

	else:
		print("   ⏸️  Waiting... (exploring completed)")


func _advance_all_biomes(seconds: float):
	"""Advance quantum evolution in all biomes"""
	for biome_name in farm.grid.biomes.keys():
		var biome = farm.grid.biomes[biome_name]
		biome.advance_simulation(seconds)
	game_time += seconds


func _debug_plot_state(pos: Vector2i):
	"""Print detailed plot state for debugging"""
	var plot = farm.grid.get_plot(pos)
	if not plot:
		print("     ⚠️  Plot %s does not exist!" % pos)
		return

	print("     🔍 Plot %s: planted=%s, measured=%s" % [pos, plot.is_planted, plot.has_been_measured])

	if plot.quantum_state:
		print("        Quantum: radius=%.3f, theta=%.2f, phi=%.2f" % [
			plot.quantum_state.radius,
			plot.quantum_state.theta,
			plot.quantum_state.phi
		])
		print("        Semantic: %s" % plot.get_dominant_emoji())

	if plot.plot_infrastructure_entanglements.size() > 0:
		print("        Infrastructure entanglements: %d" % plot.plot_infrastructure_entanglements.size())
		for partner_pos in plot.plot_infrastructure_entanglements:
			print("          → %s" % partner_pos)


func _debug_entanglement_failure(pos_a: Vector2i, pos_b: Vector2i):
	"""Debug why entanglement failed"""
	var plot_a = farm.grid.get_plot(pos_a)
	var plot_b = farm.grid.get_plot(pos_b)

	if not plot_a:
		print("      ❌ Plot A does not exist!")
	else:
		print("      Plot A: planted=%s, quantum_state=%s" % [plot_a.is_planted, plot_a.quantum_state != null])

	if not plot_b:
		print("      ❌ Plot B does not exist!")
	else:
		print("      Plot B: planted=%s, quantum_state=%s" % [plot_b.is_planted, plot_b.quantum_state != null])


func _verify_entanglement(pos_a: Vector2i, pos_b: Vector2i):
	"""Check if entanglement exists"""
	var plot_a = farm.grid.get_plot(pos_a)
	var plot_b = farm.grid.get_plot(pos_b)

	if not plot_a or not plot_b:
		print("      ⚠️  One or both plots don't exist")
		return

	var a_has_b = plot_a.plot_infrastructure_entanglements.has(pos_b)
	var b_has_a = plot_b.plot_infrastructure_entanglements.has(pos_a)

	if a_has_b and b_has_a:
		print("      ✅ Entanglement infrastructure exists: %s ↔ %s" % [pos_a, pos_b])
	elif a_has_b or b_has_a:
		print("      ⚠️  Asymmetric entanglement! A→B=%s, B→A=%s" % [a_has_b, b_has_a])
	else:
		print("      ❌ No entanglement found")


func _test_bell_correlation(pos_a: Vector2i, pos_b: Vector2i):
	"""Check if measurements are correlated (phi_plus should give same outcome)"""
	var plot_a = farm.grid.get_plot(pos_a)
	var plot_b = farm.grid.get_plot(pos_b)

	if not plot_a or not plot_b:
		print("      ⚠️  Can't test correlation - plots missing")
		return

	if not plot_a.has_been_measured or not plot_b.has_been_measured:
		print("      ⚠️  Can't test correlation - not both measured")
		return

	var outcome_a = plot_a.measured_outcome
	var outcome_b = plot_b.measured_outcome

	print("      🔬 Measurement correlation:")
	print("         Plot A outcome: %s" % outcome_a)
	print("         Plot B outcome: %s" % outcome_b)

	if outcome_a == outcome_b:
		print("         ✅ CORRELATED (phi_plus behavior correct!)")
	else:
		print("         ⚠️  ANTI-CORRELATED (expected phi_plus to match)")


func _print_final_report():
	print("\n" + "=".repeat(80))
	print("📊 ENTANGLEMENT EXPLORATION COMPLETE - FINAL REPORT")
	print("=".repeat(80))

	# Resources
	var wheat = farm.economy.get_resource("🌾")
	var labor = farm.economy.get_resource("👥")
	print("\n💰 Final Resources:")
	print("   🌾 Wheat: %d credits" % wheat)
	print("   👥 Labor: %d credits" % labor)

	# Entanglement statistics
	print("\n🔗 Entanglement Statistics:")
	print("   Total attempts: %d" % entanglement_attempts)
	print("   Successful: %d" % entanglements_created)
	print("   Success rate: %.1f%%" % (100.0 * entanglements_created / max(1, entanglement_attempts)))
	print("   Goal progress: %d entanglements" % farm.goals.progress["entanglement_count"])

	# Goals
	print("\n🎯 Goals Progress:")
	for i in range(farm.goals.goals.size()):
		var goal = farm.goals.goals[i]
		var progress_type = goal["type"]
		var current_val = 0

		if progress_type == "harvest_count":
			current_val = farm.goals.progress["harvest_count"]
		elif progress_type == "total_wheat_harvested":
			current_val = farm.goals.progress["total_wheat_harvested"]
		elif progress_type == "wheat_inventory":
			current_val = wheat
		elif progress_type == "entanglement_count":
			current_val = farm.goals.progress["entanglement_count"]

		var target = goal["target"]
		var progress_pct = 100.0 * current_val / target
		var status = "✅" if current_val >= target else "🔄"
		print("   %s %s: %d/%d (%.1f%%)" % [status, goal["title"], current_val, target, progress_pct])

	print("\n" + "=".repeat(80))
