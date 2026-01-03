extends Node

## Integration Test Runner
## Runs after FarmView is fully initialized, tests real game systems

var test_log = []
var errors_found = []
var warnings_found = []
var farm_view = null
var farm = null
var tests_started = false

func _ready():
	print("\n" + "=".repeat(80))
	print("INTEGRATION TEST - Full Scene Tree Testing")
	print("=".repeat(80))
	print("\n⏳ Waiting for FarmView to initialize...")

	# Get reference to FarmView (our parent)
	farm_view = get_parent()

	# Wait one frame for FarmView to complete initialization
	await get_tree().process_frame

	# Start tests
	_run_integration_tests()


func _run_integration_tests():
	"""Run all integration tests"""
	print("\n✅ FarmView initialized - starting integration tests\n")

	# Get farm reference from FarmView
	if farm_view and farm_view.has_method("get_farm"):
		farm = farm_view.get_farm()
	elif farm_view and "farm" in farm_view:
		farm = farm_view.farm

	if not farm:
		log_error("Cannot get farm reference from FarmView")
		_finish_tests()
		return

	log_test("=== INTEGRATION TESTS ===")

	# Test 1: Autoloads accessible
	test_autoloads_available()

	# Test 2: Biome bath initialization
	test_biome_baths_initialized()

	# Test 3: IconRegistry integration
	test_iconregistry_integration()

	# Test 4: Plant/harvest cycle
	await test_plant_harvest_cycle()

	# Test 5: Quantum mechanics
	await test_quantum_mechanics()

	# Finish
	_finish_tests()


func test_autoloads_available():
	"""Test that critical autoloads are available"""
	log_test("\n### TEST 1: Autoloads Available")

	var icon_registry = get_node_or_null("/root/IconRegistry")
	if icon_registry:
		log_pass("IconRegistry accessible via /root/IconRegistry")
		log_info("  Icons loaded: %d" % icon_registry.icons.size())

		if icon_registry.icons.size() == 29:
			log_pass("IconRegistry has correct icon count (29)")
		else:
			log_warning("IconRegistry has %d icons (expected 29)" % icon_registry.icons.size())
	else:
		log_error("IconRegistry NOT accessible")

	var game_state = get_node_or_null("/root/GameStateManager")
	if game_state:
		log_pass("GameStateManager accessible")
	else:
		log_warning("GameStateManager not found")


func test_biome_baths_initialized():
	"""Test that all biomes have initialized their quantum baths"""
	log_test("\n### TEST 2: Biome Bath Initialization")

	if not farm or not farm.grid or not farm.grid.biomes:
		log_error("Cannot access biomes")
		return

	log_info("Found %d biomes" % farm.grid.biomes.size())

	var all_have_baths = true
	for biome_name in farm.grid.biomes:
		var biome = farm.grid.biomes[biome_name]

		if biome.bath:
			log_pass("%s has bath with %d emojis" % [biome_name, biome.bath.emoji_list.size()])

			# Check bath has icons
			if biome.bath.active_icons and biome.bath.active_icons.size() > 0:
				log_pass("  %s bath has %d active icons" % [biome_name, biome.bath.active_icons.size()])
			else:
				log_warning("  %s bath has no active icons" % biome_name)

			# Check bath has Hamiltonian
			if biome.bath.hamiltonian_sparse and biome.bath.hamiltonian_sparse.size() > 0:
				log_pass("  %s bath has Hamiltonian (%d terms)" % [biome_name, biome.bath.hamiltonian_sparse.size()])
			else:
				log_warning("  %s bath has no Hamiltonian" % biome_name)
		else:
			log_error("%s has NO BATH" % biome_name)
			all_have_baths = false

	if all_have_baths:
		log_pass("ALL biomes have baths initialized ✅")
	else:
		log_error("Some biomes missing baths ❌")


func test_iconregistry_integration():
	"""Test that biomes can access IconRegistry"""
	log_test("\n### TEST 3: IconRegistry Integration")

	var icon_registry = get_node_or_null("/root/IconRegistry")
	if not icon_registry:
		log_error("IconRegistry not available for integration test")
		return

	# Test getting specific icons
	var test_emojis = ["🌾", "🍄", "☀", "🌙", "💰"]
	var found_count = 0

	for emoji in test_emojis:
		var icon = icon_registry.get_icon(emoji)
		if icon:
			found_count += 1
			log_pass("Found icon for %s" % emoji)
		else:
			log_warning("Missing icon for %s" % emoji)

	if found_count == test_emojis.size():
		log_pass("All test icons found in registry")
	else:
		log_warning("Only %d/%d test icons found" % [found_count, test_emojis.size()])


func test_plant_harvest_cycle():
	"""Test planting and harvesting"""
	log_test("\n### TEST 4: Plant/Harvest Cycle")

	# Give resources
	farm.economy.add_resource("💰", 10000, "test")
	farm.economy.add_resource("🌾", 5000, "test")
	farm.economy.add_resource("👥", 1000, "test")

	var test_pos = Vector2i(2, 0)  # BioticFlux plot (U key)

	# Ensure plot is empty
	var plot = farm.grid.get_plot(test_pos)
	if plot and plot.is_planted:
		log_info("Plot already planted, clearing first")
		plot.is_planted = false
		plot.quantum_state = null

	# Assign to BioticFlux biome
	farm.grid.assign_plot_to_biome(test_pos, "BioticFlux")

	# Test planting
	log_info("Attempting to plant wheat at %s" % test_pos)
	var plant_success = farm.build(test_pos, "wheat")

	if plant_success:
		log_pass("Wheat planted successfully")

		# Check plot state
		if plot.is_planted:
			log_pass("Plot marked as planted")
		else:
			log_error("Plot NOT marked as planted")

		# Check quantum state
		if plot.quantum_state:
			log_pass("Plot has quantum state")
			log_info("  Initial radius: %.3f" % plot.quantum_state.radius)
			log_info("  Initial energy: %.3f" % plot.quantum_state.energy)
		else:
			log_error("Plot has NO quantum state")

		# Wait a moment for any initialization
		await get_tree().create_timer(0.1).timeout

		# Test harvesting
		log_info("Attempting to harvest at %s" % test_pos)
		var harvest_result = farm.harvest_plot(test_pos)

		if harvest_result.get("success", false):
			log_pass("Harvest successful")
			log_info("  Energy extracted: %.3f" % harvest_result.get("energy", 0.0))
			log_info("  Outcome: %s" % harvest_result.get("outcome", "?"))

			# Verify plot cleared
			if not plot.is_planted:
				log_pass("Plot cleared after harvest")
			else:
				log_error("Plot still planted after harvest")

			# Verify 10% energy extraction
			var energy = harvest_result.get("energy", 0.0)
			if energy > 0.0 and energy < 0.2:
				log_pass("Energy extraction in expected range (%.3f)" % energy)
			elif energy == 0.0:
				log_warning("No energy extracted (might be expected for fresh plant)")
			else:
				log_warning("Energy seems high (%.3f)" % energy)
		else:
			log_error("Harvest failed")
	else:
		log_error("Failed to plant wheat")


func test_quantum_mechanics():
	"""Test quantum mechanics (entanglement, measurement)"""
	log_test("\n### TEST 5: Quantum Mechanics")

	# Plant two adjacent plots
	var pos_a = Vector2i(2, 0)  # BioticFlux U
	var pos_b = Vector2i(3, 0)  # BioticFlux I

	# Assign to same biome
	farm.grid.assign_plot_to_biome(pos_a, "BioticFlux")
	farm.grid.assign_plot_to_biome(pos_b, "BioticFlux")

	# Plant
	farm.build(pos_a, "wheat")
	farm.build(pos_b, "wheat")

	await get_tree().create_timer(0.1).timeout

	# Test entanglement (Bell gate)
	log_info("Testing Bell gate entanglement")
	var entangle_success = farm.grid.apply_bell_gate(pos_a, pos_b)

	if entangle_success:
		log_pass("Bell gate applied successfully")

		# Check infrastructure entanglement
		var plot_a = farm.grid.get_plot(pos_a)
		var plot_b = farm.grid.get_plot(pos_b)

		if plot_a.plot_infrastructure_entanglements.has(pos_b):
			log_pass("Plot A records entanglement with B")
		else:
			log_error("Plot A does NOT record entanglement")

		if plot_b.plot_infrastructure_entanglements.has(pos_a):
			log_pass("Plot B records entanglement with A")
		else:
			log_error("Plot B does NOT record entanglement")
	else:
		log_error("Bell gate failed")

	# Test measurement
	log_info("Testing measurement")
	var measure_success = farm.measure_plot(pos_a)

	if measure_success:
		log_pass("Measurement successful")

		var plot_a = farm.grid.get_plot(pos_a)
		if plot_a.has_been_measured:
			log_pass("Plot marked as measured")
			log_info("  Outcome: %s" % plot_a.measured_outcome)
		else:
			log_error("Plot NOT marked as measured")
	else:
		log_error("Measurement failed")

	# Clean up
	farm.harvest_plot(pos_a)
	farm.harvest_plot(pos_b)


func _finish_tests():
	"""Complete testing and report results"""
	print("\n" + "=".repeat(80))
	print("INTEGRATION TEST COMPLETE")
	print("=".repeat(80))
	print("\nTests run: %d" % test_log.size())
	print("Errors found: %d" % errors_found.size())
	print("Warnings found: %d" % warnings_found.size())

	if errors_found.size() > 0:
		print("\n🚨 ERRORS:")
		for err in errors_found:
			print("  - %s" % err)

	if warnings_found.size() > 0:
		print("\n⚠️  WARNINGS:")
		for warn in warnings_found:
			print("  - %s" % warn)

	# Save log
	var log_file = FileAccess.open("/tmp/integration_test_log.txt", FileAccess.WRITE)
	if log_file:
		for entry in test_log:
			log_file.store_line(entry)
		log_file.close()
		print("\n📄 Detailed log saved to /tmp/integration_test_log.txt")

	if errors_found.size() == 0:
		print("\n✅ ALL TESTS PASSED!")
		get_tree().quit(0)
	else:
		print("\n❌ SOME TESTS FAILED")
		get_tree().quit(1)


# Logging helpers
func log_test(msg: String):
	print(msg)
	test_log.append(msg)

func log_pass(msg: String):
	var entry = "✅ PASS: %s" % msg
	print(entry)
	test_log.append(entry)

func log_error(msg: String):
	var entry = "❌ ERROR: %s" % msg
	print(entry)
	test_log.append(entry)
	errors_found.append(msg)

func log_warning(msg: String):
	var entry = "⚠️  WARNING: %s" % msg
	print(entry)
	test_log.append(entry)
	warnings_found.append(msg)

func log_info(msg: String):
	var entry = "ℹ️  INFO: %s" % msg
	print(entry)
	test_log.append(entry)
