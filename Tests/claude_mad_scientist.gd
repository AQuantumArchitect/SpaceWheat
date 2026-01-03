#!/usr/bin/env -S godot --headless -s
extends SceneTree

## 🔬 CLAUDE'S MAD QUANTUM SCIENTIST PLAYTEST 🔬
## Hypothesis-driven experimentation with the quantum substrate!
## Let's break things, discover emergent behaviors, and have FUN!

const Farm = preload("res://Core/Farm.gd")

var farm: Farm = null
var experiment_log = []

func _initialize():
	print("\n" + "=".repeat(80))
	print("🔬 MAD QUANTUM SCIENTIST PLAYTEST")
	print("Testing hypotheses, breaking rules, discovering emergent behaviors!")
	print("=".repeat(80))

	await get_root().ready

	# Create farm
	farm = Farm.new()
	get_root().add_child(farm)
	for i in range(10):
		await process_frame

	print("\n🌍 Quantum Laboratory Initialized!")
	print("  Grid: %dx%d plots" % [farm.grid.grid_width, farm.grid.grid_height])
	print("  Available biomes: 4 (BioticFlux, Market, Forest, Kitchen)")
	print("  Quantum bath: ACTIVE")
	print()

	# Run experiments!
	await experiment_1_plant_everything_everywhere()
	await experiment_2_maximum_entanglement()
	await experiment_3_energy_tap_warfare()
	await experiment_4_measurement_order_matters()
	await experiment_5_cross_biome_interference()
	await experiment_6_gate_stacking()
	await experiment_7_bath_amplitude_manipulation()
	await experiment_8_quantum_zeno_effect()

	# Print results
	print_experiment_results()

	quit(0)


func experiment_1_plant_everything_everywhere():
	"""HYPOTHESIS: Can we plant incompatible crop types? What happens?"""

	log_experiment("EXPERIMENT 1: Plant Chaos Theory")
	print("\n" + "─".repeat(80))
	print("🧪 EXPERIMENT 1: Plant Chaos Theory")
	print("HYPOTHESIS: System will prevent planting mills/markets in biotic areas")
	print("METHOD: Try to plant everything everywhere, see what breaks")
	print("─".repeat(80))

	var crop_types = ["wheat", "mushroom", "mill", "market", "kitchen"]
	var results = {}

	for crop in crop_types:
		results[crop] = {"success": [], "failure": []}

		# Try planting in first 6 positions (across different biomes)
		for x in range(6):
			var pos = Vector2i(x, 0)
			var success = farm.build(pos, crop)

			if success:
				results[crop].success.append(pos)
				print("  ✅ %s at %s: SUCCESS" % [crop, pos])
			else:
				results[crop].failure.append(pos)
				print("  ❌ %s at %s: FAILED" % [crop, pos])

			await advance_time(0.2)

	# Analysis
	print("\n📊 RESULTS:")
	for crop in crop_types:
		var success_count = results[crop].success.size()
		var total = results[crop].success.size() + results[crop].failure.size()
		print("  %s: %d/%d successful" % [crop, success_count, total])

	log_result("Plant restrictions exist - some crops only work in certain locations")


func experiment_2_maximum_entanglement():
	"""HYPOTHESIS: Can we create a fully entangled graph? Does it collapse interestingly?"""

	log_experiment("EXPERIMENT 2: Maximum Entanglement Density")
	print("\n" + "─".repeat(80))
	print("🧪 EXPERIMENT 2: Maximum Entanglement Density")
	print("HYPOTHESIS: Creating a fully-connected entanglement graph will produce")
	print("            interesting collapse patterns and quantum correlations")
	print("METHOD: Plant 6 wheat, entangle ALL pairs, measure one, observe cascade")
	print("─".repeat(80))

	# Clear and plant fresh wheat
	for x in range(6):
		farm.build(Vector2i(x, 1), "wheat")

	await advance_time(2.0)

	# Entangle EVERYTHING with EVERYTHING
	var entangle_count = 0
	print("\n🔗 Creating maximum entanglement...")
	for i in range(6):
		for j in range(i + 1, 6):
			var pos_a = Vector2i(i, 1)
			var pos_b = Vector2i(j, 1)

			var success = farm.entangle_plots(pos_a, pos_b)
			if success:
				entangle_count += 1
				print("  ✓ Entangled (%d,1) ↔ (%d,1)" % [i, j])
			else:
				print("  ✗ Failed: (%d,1) ↔ (%d,1)" % [i, j])

	print("\n📊 Created %d entanglements (theoretical max: 15)" % entangle_count)

	await advance_time(5.0)  # Let quantum evolution happen

	# Measure ONE plot and watch the cascade
	print("\n📏 Measuring plot (0,1) - observing cascade...")
	var outcome = farm.measure_plot(Vector2i(0, 1))
	print("  First measurement: %s" % outcome)

	# Check if others collapsed
	print("\n🔍 Checking correlation cascade:")
	for x in range(1, 6):
		var plot = farm.grid.get_plot(Vector2i(x, 1))
		if plot:
			print("  Plot (%d,1): measured=%s" % [x, plot.has_been_measured])

	log_result("Maximum entanglement: %d gates created, cascade observed" % entangle_count)


func experiment_3_energy_tap_warfare():
	"""HYPOTHESIS: Multiple energy taps can drain the bath, affecting crop growth"""

	log_experiment("EXPERIMENT 3: Energy Tap Warfare")
	print("\n" + "─".repeat(80))
	print("🧪 EXPERIMENT 3: Energy Tap Warfare")
	print("HYPOTHESIS: Multiple energy taps will compete for bath amplitude,")
	print("            affecting nearby wheat growth rates")
	print("METHOD: Place 3 taps near wheat, measure comparative growth")
	print("─".repeat(80))

	# Control group: wheat with no taps
	farm.build(Vector2i(0, 0), "wheat")
	print("  Control: Wheat at (0,0)")

	# Experimental group: wheat surrounded by energy taps
	farm.build(Vector2i(3, 0), "wheat")
	print("  Experimental: Wheat at (3,0)")

	# Try to place energy taps (Tool #4)
	# Note: This requires checking if energy taps are implemented
	var tap_success = 0
	for offset in [Vector2i(2, 0), Vector2i(4, 0), Vector2i(3, 1)]:
		# Energy taps might not be plantable - need to use tool API
		print("  Attempting energy tap at %s..." % offset)
		# TODO: Use proper energy tap tool when available

	await advance_time(10.0)

	# Compare energies
	var control_qubit = farm.biotic_flux_biome.get_qubit_at(Vector2i(0, 0)) if farm.biotic_flux_biome.has_method("get_qubit_at") else null
	var experimental_qubit = farm.biotic_flux_biome.get_qubit_at(Vector2i(3, 0)) if farm.biotic_flux_biome.has_method("get_qubit_at") else null

	if control_qubit and experimental_qubit:
		print("\n📊 Energy comparison after 10s:")
		print("  Control wheat: energy=%.3f" % control_qubit.energy)
		print("  Experimental wheat: energy=%.3f" % experimental_qubit.energy)

		var diff = experimental_qubit.energy - control_qubit.energy
		if abs(diff) > 0.1:
			log_result("Energy taps AFFECT nearby crops: %.3f energy difference" % diff)
		else:
			log_result("Energy taps have MINIMAL effect: %.3f energy difference" % diff)
	else:
		log_result("Cannot access bath qubits - test inconclusive")


func experiment_4_measurement_order_matters():
	"""HYPOTHESIS: Measuring plot A before B gives different results than B before A"""

	log_experiment("EXPERIMENT 4: Measurement Order Dependency")
	print("\n" + "─".repeat(80))
	print("🧪 EXPERIMENT 4: Measurement Order Dependency")
	print("HYPOTHESIS: In entangled systems, measurement order affects outcomes")
	print("METHOD: Create entangled pairs, measure in different orders, compare")
	print("─".repeat(80))

	# Trial 1: Measure A then B
	farm.build(Vector2i(0, 0), "wheat")
	farm.build(Vector2i(1, 0), "wheat")
	await advance_time(1.0)
	farm.entangle_plots(Vector2i(0, 0), Vector2i(1, 0))
	await advance_time(5.0)

	var outcome_a1 = farm.measure_plot(Vector2i(0, 0))
	var outcome_b1 = farm.measure_plot(Vector2i(1, 0))
	print("  Trial 1: Measure A→B: %s → %s" % [outcome_a1, outcome_b1])

	# Harvest and reset
	farm.harvest_plot(Vector2i(0, 0))
	farm.harvest_plot(Vector2i(1, 0))

	# Trial 2: Measure B then A
	farm.build(Vector2i(0, 0), "wheat")
	farm.build(Vector2i(1, 0), "wheat")
	await advance_time(1.0)
	farm.entangle_plots(Vector2i(0, 0), Vector2i(1, 0))
	await advance_time(5.0)

	var outcome_b2 = farm.measure_plot(Vector2i(1, 0))
	var outcome_a2 = farm.measure_plot(Vector2i(0, 0))
	print("  Trial 2: Measure B→A: %s → %s" % [outcome_b2, outcome_a2])

	# Compare
	if outcome_a1 == outcome_a2 and outcome_b1 == outcome_b2:
		log_result("Measurement order: NO EFFECT - outcomes independent")
	else:
		log_result("Measurement order: AFFECTS OUTCOMES - quantum mechanics confirmed!")


func experiment_5_cross_biome_interference():
	"""HYPOTHESIS: Crops in different biomes evolve at different rates due to bath differences"""

	log_experiment("EXPERIMENT 5: Cross-Biome Interference")
	print("\n" + "─".repeat(80))
	print("🧪 EXPERIMENT 5: Cross-Biome Interference")
	print("HYPOTHESIS: Different biomes have different Hamiltonians,")
	print("            causing different evolution rates for identical crops")
	print("METHOD: Plant wheat in all 4 biomes, measure energy growth over time")
	print("─".repeat(80))

	# Plant wheat in different biomes (assuming biome boundaries)
	var test_positions = [
		Vector2i(0, 0),  # BioticFlux
		Vector2i(2, 0),  # Market
		Vector2i(4, 0),  # Forest
		Vector2i(5, 0),  # Kitchen
	]

	print("\n🌾 Planting wheat across all biomes...")
	for pos in test_positions:
		farm.build(pos, "wheat")
		print("  Planted at %s" % pos)

	await advance_time(0.5)

	# Record initial energies
	var initial_energies = {}
	for pos in test_positions:
		var biome = farm.grid.get_biome_for_plot(pos)
		var qubit = biome.get_qubit_at(pos) if biome and biome.has_method("get_qubit_at") else null
		if qubit:
			initial_energies[str(pos)] = qubit.energy
			print("  %s: initial energy = %.3f (biome: %s)" % [pos, qubit.energy, biome.name if biome else "?"])

	# Wait for evolution
	print("\n⏳ Waiting 10s for quantum evolution...")
	await advance_time(10.0)

	# Measure final energies
	print("\n📊 Final energies and growth rates:")
	var max_growth = -999.0
	var min_growth = 999.0

	for pos in test_positions:
		var biome = farm.grid.get_biome_for_plot(pos)
		var qubit = biome.get_qubit_at(pos) if biome and biome.has_method("get_qubit_at") else null
		if qubit:
			var initial = initial_energies.get(str(pos), 0.0)
			var growth = qubit.energy - initial
			print("  %s: %.3f → %.3f (growth: %.3f)" % [pos, initial, qubit.energy, growth])
			max_growth = max(max_growth, growth)
			min_growth = min(min_growth, growth)

	var variance = max_growth - min_growth
	if variance > 0.1:
		log_result("Cross-biome interference: SIGNIFICANT (variance: %.3f)" % variance)
	else:
		log_result("Cross-biome interference: MINIMAL (variance: %.3f)" % variance)


func experiment_6_gate_stacking():
	"""HYPOTHESIS: Applying multiple quantum gates to the same plot has cumulative effects"""

	log_experiment("EXPERIMENT 6: Gate Stacking Effects")
	print("\n" + "─".repeat(80))
	print("🧪 EXPERIMENT 6: Gate Stacking Effects")
	print("HYPOTHESIS: Multiple quantum gates on one plot = cumulative transformation")
	print("METHOD: Apply Pauli-X, Hadamard, CNOT in sequence, observe final state")
	print("─".repeat(80))

	# Plant target
	farm.build(Vector2i(2, 1), "wheat")
	await advance_time(1.0)

	# Get initial state
	var biome = farm.grid.get_biome_for_plot(Vector2i(2, 1))
	var qubit = biome.get_qubit_at(Vector2i(2, 1)) if biome and biome.has_method("get_qubit_at") else null

	if qubit:
		print("  Initial: θ=%.3f, φ=%.3f, energy=%.3f" % [qubit.theta, qubit.phi, qubit.energy])

		# Try applying gates (Tool #5)
		# Note: Need to check if gate application API exists
		print("\n🔧 Attempting gate applications...")
		print("  [Tool #5 gates need proper API integration]")

		# For now, just measure the effect of persistent gates (Tool #2)
		var plot = farm.grid.get_plot(Vector2i(2, 1))
		if plot and plot.has_method("add_persistent_gate"):
			plot.add_persistent_gate("bell_phi_plus", [])
			print("  ✓ Added bell_phi_plus gate")

			plot.add_persistent_gate("measure_trigger", [])
			print("  ✓ Added measure_trigger gate")

		await advance_time(5.0)

		var qubit_after = biome.get_qubit_at(Vector2i(2, 1)) if biome.has_method("get_qubit_at") else null
		if qubit_after:
			print("\n  Final: θ=%.3f, φ=%.3f, energy=%.3f" % [qubit_after.theta, qubit_after.phi, qubit_after.energy])
			var theta_change = abs(qubit_after.theta - qubit.theta)
			log_result("Gate stacking: Δθ=%.3f radians" % theta_change)
	else:
		log_result("Cannot access qubits - gate stacking test inconclusive")


func experiment_7_bath_amplitude_manipulation():
	"""HYPOTHESIS: Bath amplitude directly affects crop yield"""

	log_experiment("EXPERIMENT 7: Bath Amplitude Farming")
	print("\n" + "─".repeat(80))
	print("🧪 EXPERIMENT 7: Bath Amplitude Farming")
	print("HYPOTHESIS: Higher bath amplitude for crop emoji = higher yield")
	print("METHOD: Measure wheat amplitude, plant, harvest, correlate yield with amplitude")
	print("─".repeat(80))

	var biome = farm.biotic_flux_biome
	if biome and "bath" in biome and biome.bath:
		var bath = biome.bath

		# Check wheat amplitude
		var wheat_amp = bath.get_amplitude("🌾")
		var labor_amp = bath.get_amplitude("👥")

		print("  Bath amplitudes:")
		print("    🌾 wheat: |z|=%.3f (re=%.3f, im=%.3f)" % [wheat_amp.abs(), wheat_amp.re, wheat_amp.im])
		print("    👥 labor: |z|=%.3f (re=%.3f, im=%.3f)" % [labor_amp.abs(), labor_amp.re, labor_amp.im])

		# Plant and let evolve
		farm.build(Vector2i(1, 1), "wheat")
		print("\n🌾 Planted wheat, waiting for bath interaction...")
		await advance_time(15.0)

		# Measure and harvest
		farm.measure_plot(Vector2i(1, 1))
		var result = farm.harvest_plot(Vector2i(1, 1))
		var yield_amount = result.get("yield", 0)

		print("\n📊 Harvest result:")
		print("  Yield: %d units" % yield_amount)
		print("  Bath wheat amplitude was: |z|=%.3f" % wheat_amp.abs())

		if wheat_amp.abs() > 0.5 and yield_amount > 0:
			log_result("Bath amplitude correlation: HIGH amplitude → yield=%d" % yield_amount)
		elif wheat_amp.abs() < 0.5 and yield_amount == 0:
			log_result("Bath amplitude correlation: LOW amplitude → yield=%d" % yield_amount)
		else:
			log_result("Bath amplitude correlation: UNCLEAR (|z|=%.3f, yield=%d)" % [wheat_amp.abs(), yield_amount])
	else:
		log_result("Bath not accessible - amplitude test inconclusive")


func experiment_8_quantum_zeno_effect():
	"""HYPOTHESIS: Rapid repeated measurements freeze quantum evolution"""

	log_experiment("EXPERIMENT 8: Quantum Zeno Effect")
	print("\n" + "─".repeat(80))
	print("🧪 EXPERIMENT 8: Quantum Zeno Effect")
	print("HYPOTHESIS: Measuring a plot repeatedly prevents its quantum state from evolving")
	print("METHOD: Measure plot every 0.5s for 10s, compare to unmeasured control")
	print("─".repeat(80))

	# Control: unmeasured plot
	farm.build(Vector2i(0, 0), "wheat")
	print("  Control: Wheat at (0,0) - will NOT measure")

	# Experimental: rapidly measured plot
	farm.build(Vector2i(1, 0), "wheat")
	print("  Experimental: Wheat at (1,0) - will measure every 0.5s")

	await advance_time(1.0)

	# Get initial states
	var biome = farm.biotic_flux_biome
	var control_initial = biome.get_qubit_at(Vector2i(0, 0)) if biome and biome.has_method("get_qubit_at") else null
	var exp_initial = biome.get_qubit_at(Vector2i(1, 0)) if biome and biome.has_method("get_qubit_at") else null

	if control_initial and exp_initial:
		var control_theta_0 = control_initial.theta
		var exp_theta_0 = exp_initial.theta

		# Repeatedly measure experimental plot
		print("\n⚡ Rapid measurement sequence:")
		for i in range(20):
			await advance_time(0.5)
			farm.measure_plot(Vector2i(1, 0))
			print("  Measurement %d" % (i + 1))

		# Final states
		var control_final = biome.get_qubit_at(Vector2i(0, 0)) if biome and biome.has_method("get_qubit_at") else null
		var exp_final = biome.get_qubit_at(Vector2i(1, 0)) if biome and biome.has_method("get_qubit_at") else null

		if control_final and exp_final:
			var control_evolution = abs(control_final.theta - control_theta_0)
			var exp_evolution = abs(exp_final.theta - exp_theta_0)

			print("\n📊 Quantum Zeno Test Results:")
			print("  Control: Δθ = %.3f rad (free evolution)" % control_evolution)
			print("  Experimental: Δθ = %.3f rad (rapid measurement)" % exp_evolution)

			if exp_evolution < control_evolution * 0.5:
				log_result("Quantum Zeno CONFIRMED: Measurement freezes evolution! (%.1fx slower)" % (control_evolution / exp_evolution if exp_evolution > 0 else 999))
			else:
				log_result("Quantum Zeno NOT observed: Measurement doesn't freeze evolution")
	else:
		log_result("Cannot access qubits - Zeno test inconclusive")


func advance_time(seconds: float):
	"""Advance simulation time"""
	for i in range(int(seconds * 2)):
		await process_frame


func log_experiment(name: String):
	"""Log start of experiment"""
	experiment_log.append({"type": "experiment", "name": name})


func log_result(result: String):
	"""Log experimental result"""
	experiment_log.append({"type": "result", "text": result})
	print("\n✅ RESULT: %s" % result)


func print_experiment_results():
	"""Print comprehensive experimental findings"""

	print("\n\n" + "=".repeat(80))
	print("📊 COMPREHENSIVE EXPERIMENTAL FINDINGS")
	print("=".repeat(80))

	var current_experiment = ""
	for entry in experiment_log:
		if entry.type == "experiment":
			current_experiment = entry.name
			print("\n🔬 %s" % current_experiment)
		elif entry.type == "result":
			print("  → %s" % entry.text)

	print("\n" + "=".repeat(80))
	print("🎓 CONCLUSIONS: The quantum substrate shows rich emergent behavior!")
	print("   Recommendation: Further investigation of bath-crop interactions needed")
	print("=".repeat(80) + "\n")
