#!/usr/bin/env -S godot --headless -s
## Mechanics Exploration Test
## Systematically test all game mechanics and log errors
##
## Tests:
## 1. Basic farm setup and grid
## 2. Planting mechanics
## 3. Entanglement (Bell pairs and clusters)
## 4. Measurement mechanics
## 5. Harvesting
## 6. Building (mills, markets, kitchens)
## 7. Energy system
## 8. Economy transformations

extends SceneTree

const Farm = preload("res://Core/Farm.gd")

var farm: Farm
var errors: Array = []
var warnings: Array = []
var passes: Array = []

func _initialize():
	print("\n" + "═".repeat(100))
	print("🔬 MECHANICS EXPLORATION TEST")
	print("═".repeat(100) + "\n")

	_test_farm_setup()
	_test_planting_mechanics()
	_test_entanglement_mechanics()
	_test_measurement_mechanics()
	_test_building_mechanics()
	_test_energy_system()

	_report_findings()
	quit(0)


func _test_farm_setup():
	print("TEST 1: FARM SETUP")
	print("─".repeat(100))

	farm = Farm.new()
	farm._ready()

	if farm:
		_log_pass("Farm created successfully")
	else:
		_log_error("Farm creation failed")
		return

	if farm.grid:
		_log_pass("FarmGrid exists")
	else:
		_log_error("FarmGrid is null")
		return

	if farm.grid.plots.size() > 0:
		_log_pass("Grid has plots: %d" % farm.grid.plots.size())
	else:
		_log_error("Grid has no plots")

	if farm.economy:
		_log_pass("Economy initialized")
		print("   Resources: Wheat=%d, Labor=%d, Credits=%d" % [farm.economy.wheat_inventory, farm.economy.labor_inventory, farm.economy.credits])
	else:
		_log_error("Economy is null")

	# Add starting resources
	farm.economy.add_wheat(100)
	farm.economy.add_labor(20)

	print()


func _test_planting_mechanics():
	print("TEST 2: PLANTING MECHANICS")
	print("─".repeat(100))

	if not farm:
		_log_error("Farm not initialized for planting test")
		return

	# Test 1: Plant single plot
	var pos = Vector2i(0, 0)
	var result = farm.build(pos, "wheat")

	if result:
		_log_pass("Plant wheat at %s" % pos)
	else:
		_log_error("Failed to plant wheat at %s" % pos)
		return

	# Verify plot state
	var plot = farm.get_plot(pos)
	if plot and plot.is_planted:
		_log_pass("Plot marked as planted")
	else:
		_log_error("Plot not marked as planted")

	if plot and plot.quantum_state:
		_log_pass("Quantum state injected: energy=%.4f" % plot.quantum_state.energy)
	else:
		_log_error("Quantum state not injected")

	# Test 2: Plant multiple plots
	var positions = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	for pos2 in positions:
		if farm.build(pos2, "wheat"):
			_log_pass("Plant wheat at %s" % pos2)
		else:
			_log_error("Failed to plant wheat at %s" % pos2)

	print()


func _test_entanglement_mechanics():
	print("TEST 3: ENTANGLEMENT MECHANICS")
	print("─".repeat(100))

	if not farm:
		_log_error("Farm not initialized for entanglement test")
		return

	# Make sure we have planted plots
	var plot1_pos = Vector2i(0, 0)
	var plot2_pos = Vector2i(1, 0)
	var plot3_pos = Vector2i(2, 0)

	var plot1 = farm.get_plot(plot1_pos)
	var plot2 = farm.get_plot(plot2_pos)
	var plot3 = farm.get_plot(plot3_pos)

	if not plot1 or not plot2:
		_log_error("Required plots not found for entanglement test")
		return

	# Test Bell pair entanglement
	print("  Testing Bell pair entanglement (2 qubits)...")
	var pair_result = farm.entangle_pair(plot1_pos, plot2_pos)

	if pair_result:
		_log_pass("Bell pair entanglement created: %s ↔ %s" % [plot1_pos, plot2_pos])

		# Check if plots are marked as entangled
		if plot1.entangled_plots.has(plot2_pos):
			_log_pass("Plot1 recognizes entanglement with Plot2")
		else:
			_log_error("Plot1 does NOT recognize entanglement with Plot2")

		if plot2.entangled_plots.has(plot1_pos):
			_log_pass("Plot2 recognizes entanglement with Plot1")
		else:
			_log_error("Plot2 does NOT recognize entanglement with Plot1")
	else:
		_log_error("Failed to create Bell pair entanglement")

	# Test cluster entanglement (3 qubits)
	print("\n  Testing GHZ cluster entanglement (3 qubits)...")
	if plot3:
		var cluster_result = farm.entangle_cluster(plot1_pos, plot2_pos, plot3_pos)
		if cluster_result:
			_log_pass("GHZ cluster entanglement created: %s ↔ %s ↔ %s" % [plot1_pos, plot2_pos, plot3_pos])
		else:
			_log_warn("GHZ cluster entanglement failed (may not be implemented)")

	print()


func _test_measurement_mechanics():
	print("TEST 4: MEASUREMENT MECHANICS")
	print("─".repeat(100))

	if not farm:
		_log_error("Farm not initialized for measurement test")
		return

	var test_pos = Vector2i(0, 0)
	var plot = farm.get_plot(test_pos)

	if not plot or not plot.quantum_state:
		_log_error("Cannot test measurement without planted plot")
		return

	# Test measurement
	var energy_before = plot.quantum_state.energy if plot.quantum_state else 0
	var measurement = farm.measure_plot(test_pos)

	if measurement is Dictionary and measurement.size() > 0:
		_log_pass("Measurement successful: %s" % measurement)
	elif measurement is String and measurement != "":
		_log_pass("Measurement successful: %s" % measurement)
	else:
		_log_error("Measurement returned empty result")

	print()


func _test_building_mechanics():
	print("TEST 5: BUILDING MECHANICS")
	print("─".repeat(100))

	if not farm:
		_log_error("Farm not initialized for building test")
		return

	# Test mill placement
	print("  Testing mill placement...")
	var mill_pos = Vector2i(4, 0)
	var mill_result = farm.build(mill_pos, "mill")

	if mill_result:
		_log_pass("Mill placed at %s" % mill_pos)
	else:
		_log_error("Failed to place mill at %s" % mill_pos)

	# Test market placement
	print("  Testing market placement...")
	var market_pos = Vector2i(5, 0)
	var market_result = farm.build(market_pos, "market")

	if market_result:
		_log_pass("Market placed at %s" % market_pos)
	else:
		_log_error("Failed to place market at %s" % market_pos)

	# Test kitchen placement (needs 3 entangled plots)
	print("  Testing kitchen placement...")
	var kitchen_result = farm.build(Vector2i(3, 0), "kitchen")

	if kitchen_result:
		_log_pass("Kitchen placed (single or triplet)")
	else:
		_log_warn("Kitchen placement failed (may require triplet setup)")

	# Test energy tap
	print("  Testing energy tap placement...")
	var tap_pos = Vector2i(4, 1)
	var tap_result = farm.build(tap_pos, "energy_tap")

	if tap_result:
		_log_pass("Energy tap placed at %s" % tap_pos)
	else:
		_log_warn("Energy tap placement failed (may need specific setup)")

	print()


func _test_energy_system():
	print("TEST 6: ENERGY SYSTEM")
	print("─".repeat(100))

	if not farm or not farm.grid:
		_log_error("Farm not initialized for energy test")
		return

	# Check biotic flux biome
	if farm.biotic_flux_biome:
		_log_pass("BioticFlux biome available")
		print("   Temperature: %.0f K" % farm.biotic_flux_biome.temperature)
	else:
		_log_error("BioticFlux biome not found")
		return

	# Test energy injection
	var inject_pos = Vector2i(0, 0)
	var plot = farm.get_plot(inject_pos)

	if plot and plot.quantum_state:
		var energy_before = plot.quantum_state.energy
		var inject_result = farm.inject_energy(inject_pos, 0.5)
		var energy_after = plot.quantum_state.energy

		if energy_after > energy_before:
			_log_pass("Energy injection increased qubit energy: %.4f → %.4f" % [energy_before, energy_after])
		else:
			_log_warn("Energy injection did not increase energy (result=%s)" % inject_result)

	# Test energy drain
	if plot and plot.quantum_state:
		var energy_before = plot.quantum_state.energy
		var drain_result = farm.drain_energy(inject_pos, 0.1)
		var energy_after = plot.quantum_state.energy

		if energy_after < energy_before:
			_log_pass("Energy drain decreased qubit energy: %.4f → %.4f" % [energy_before, energy_after])
		else:
			_log_warn("Energy drain did not decrease energy (result=%s)" % drain_result)

	print()


func _report_findings():
	print("\n" + "=".repeat(100))
	print("📊 TEST RESULTS SUMMARY")
	print("=".repeat(100))

	print("\n✅ PASSES: %d" % passes.size())
	if passes.size() <= 10:
		for msg in passes:
			print("   ✓ %s" % msg)
	else:
		print("   [%d items - showing first 10]" % passes.size())
		for i in range(min(10, passes.size())):
			print("   ✓ %s" % passes[i])

	print("\n⚠️  WARNINGS: %d" % warnings.size())
	for msg in warnings:
		print("   ⚠ %s" % msg)

	print("\n❌ ERRORS: %d" % errors.size())
	for msg in errors:
		print("   ✗ %s" % msg)

	print("\n" + "=".repeat(100))
	if errors.size() == 0:
		print("🎉 ALL TESTS PASSED!")
	else:
		print("⚠️  ISSUES FOUND - SEE ERROR LIST ABOVE")
	print("=".repeat(100) + "\n")


func _log_pass(msg: String):
	passes.append(msg)
	print("   ✓ %s" % msg)


func _log_warn(msg: String):
	warnings.append(msg)
	print("   ⚠ %s" % msg)


func _log_error(msg: String):
	errors.append(msg)
	print("   ✗ %s" % msg)
