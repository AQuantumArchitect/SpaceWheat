extends SceneTree

## Automated playtest script - tests game mechanics systematically
## CRITICAL: Waits for autoloads to be ready before running tests

var test_log = []
var errors_found = []
var warnings_found = []
var autoloads_ready = false
var check_count = 0

func _init():
	print("\n" + "=".repeat(80))
	print("AUTOMATED PLAYTEST - SIMULATION & MECHANICS FOCUS")
	print("=".repeat(80))
	print("\n⏳ Waiting for autoloads to initialize...")

	# CRITICAL: Wait for autoloads to be ready before running tests
	# Tests that run before autoloads will fail!


func _process(delta):
	"""Process loop to wait for autoloads"""
	if not autoloads_ready:
		_check_autoloads_ready()
	# Once ready, tests run and quit() is called


func _check_autoloads_ready():
	"""Check if critical autoloads are ready"""
	check_count += 1

	var icon_registry = root.get_node_or_null("IconRegistry")

	if icon_registry and icon_registry.icons.size() > 0:
		print("✅ IconRegistry ready with %d icons (checked %d times)" % [icon_registry.icons.size(), check_count])
		autoloads_ready = true

		# NOW run tests (autoloads are ready!)
		_run_tests_after_autoloads()
	elif check_count > 300:  # 5 seconds timeout at 60fps
		print("❌ TIMEOUT: IconRegistry not ready after 5 seconds")
		quit(1)


func _run_tests_after_autoloads():
	"""Run all tests after autoloads are confirmed ready"""
	print("✅ All autoloads ready - starting tests\n")

	run_all_tests()

	print("\n" + "=".repeat(80))
	print("PLAYTEST COMPLETE")
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

	# Save detailed log
	var log_file = FileAccess.open("/tmp/automated_playtest_log.txt", FileAccess.WRITE)
	if log_file:
		for entry in test_log:
			log_file.store_line(entry)
		log_file.close()
		print("\n📄 Detailed log saved to /tmp/automated_playtest_log.txt")

	quit()


func run_all_tests():
	log_test("=== STARTING AUTOMATED PLAYTEST ===")

	# Test 1: Farm initialization
	test_farm_initialization()

	# Test 2: Resource economy
	test_resource_economy()

	# Test 3: Plant/Harvest cycle
	test_plant_harvest_cycle()

	# Test 4: Tool mechanics
	test_tool_mechanics()

	# Test 5: Quantum mechanics
	test_quantum_mechanics()

	# Test 6: Biome mechanics
	test_biome_mechanics()

	# Test 7: Balance checks
	test_balance()


func test_farm_initialization():
	log_test("\n### TEST 1: Farm Initialization")

	var Farm = load("res://Core/Farm.gd")
	if not Farm:
		log_error("Failed to load Farm.gd")
		return

	var farm = Farm.new()
	farm._ready()

	# Check farm initialized correctly
	if not farm.grid:
		log_error("Farm.grid is null after initialization")
	else:
		log_pass("Farm grid initialized")

	if not farm.economy:
		log_error("Farm.economy is null after initialization")
	else:
		log_pass("Farm economy initialized")

	# Check initial resources (use emoji-credits API)
	var credits = farm.economy.get_resource("💰")  # Legacy credits emoji
	log_info("Starting credits: %d" % credits)

	if credits <= 0:
		log_warning("Starting credits is %d (should be > 0 for playability)" % credits)

	# Also check wheat
	var wheat = farm.economy.get_resource("🌾")
	log_info("Starting wheat: %d" % (wheat / 10))  # Convert to units

	# Check grid size
	var plot_count = farm.grid.plots.size()
	log_info("Grid has %d plots" % plot_count)

	if plot_count == 0:
		log_error("Grid has no plots!")
	else:
		log_pass("Grid has plots: %d" % plot_count)

	farm.queue_free()


func test_resource_economy():
	log_test("\n### TEST 2: Resource Economy")

	var FarmEconomy = load("res://Core/GameMechanics/FarmEconomy.gd")
	var economy = FarmEconomy.new()
	economy._ready()

	# Test resource operations (use emoji-credits API)
	var initial = economy.get_resource("💰")
	economy.add_resource("💰", 100, "test")
	var after_add = economy.get_resource("💰")

	if after_add != initial + 100:
		log_error("Resource addition failed: expected %d, got %d" % [initial + 100, after_add])
	else:
		log_pass("Resource addition works")

	economy.remove_resource("💰", 50, "test")
	var after_spend = economy.get_resource("💰")

	if after_spend != after_add - 50:
		log_error("Resource spending failed: expected %d, got %d" % [after_add - 50, after_spend])
	else:
		log_pass("Resource spending works")

	# Test emoji resources
	economy.add_emoji_resource("🌾", 10)
	var wheat_count = economy.get_emoji_count("🌾")

	if wheat_count != 10:
		log_error("Emoji resource addition failed: expected 10, got %d" % wheat_count)
	else:
		log_pass("Emoji resource tracking works")

	economy.queue_free()


func test_plant_harvest_cycle():
	log_test("\n### TEST 3: Plant/Harvest Cycle")

	var Farm = load("res://Core/Farm.gd")
	var farm = Farm.new()
	farm._ready()

	# Give starting resources
	farm.economy.add_resource("💰", 10000, "test setup")  # 1000 units = 10000 credits

	var test_pos = Vector2i(1, 1)

	# Test planting
	log_info("Attempting to plant wheat at %s" % test_pos)
	var plant_success = farm.build("wheat", test_pos)

	if not plant_success:
		log_error("Failed to plant wheat (might be cost issue)")
	else:
		log_pass("Wheat planted successfully")

	# Check plot state
	var plot = farm.grid.get_plot(test_pos)
	if not plot:
		log_error("Plot not found after planting")
	elif not plot.is_planted:
		log_error("Plot not marked as planted after build()")
	else:
		log_pass("Plot correctly marked as planted")

	# Check quantum state
	if plot and plot.quantum_state:
		log_pass("Plot has quantum state")
		log_info("  Quantum radius: %.3f" % plot.quantum_state.radius)
		log_info("  Quantum energy: %.3f" % plot.quantum_state.energy)
	elif plot:
		log_error("Plot has no quantum state after planting")

	# Test harvesting
	if plant_success and plot and plot.is_planted:
		log_info("Attempting to harvest at %s" % test_pos)
		var harvest_result = farm.harvest_plot(test_pos)

		if not harvest_result.get("success", false):
			log_error("Harvest failed: %s" % harvest_result)
		else:
			log_pass("Harvest successful")
			log_info("  Energy extracted: %.3f" % harvest_result.get("energy", 0.0))
			log_info("  Outcome: %s" % harvest_result.get("outcome", "?"))
			log_info("  Yield: %d" % harvest_result.get("yield", 0))

		# Check plot cleared
		if plot.is_planted:
			log_error("Plot still marked as planted after harvest")
		else:
			log_pass("Plot correctly cleared after harvest")

		# Check energy extraction (should be 10% of radius)
		if harvest_result.get("success", false):
			var energy = harvest_result.get("energy", 0.0)
			if energy > 0.2:
				log_warning("Energy extraction seems high (%.3f) - expected ~0.1 for 10%% extraction" % energy)
			elif energy < 0.05:
				log_warning("Energy extraction seems low (%.3f) - might indicate balance issue" % energy)
			else:
				log_pass("Energy extraction in expected range (%.3f)" % energy)

	farm.queue_free()


func test_tool_mechanics():
	log_test("\n### TEST 4: Tool Mechanics")

	var Farm = load("res://Core/Farm.gd")
	var farm = Farm.new()
	farm._ready()

	farm.economy.add_resource("💰", 10000, "test setup")

	# Test all build types
	var build_types = ["wheat", "mushroom", "gate", "energy_tap"]
	var test_positions = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]

	for i in range(build_types.size()):
		var build_type = build_types[i]
		var pos = test_positions[i]

		log_info("Testing build type: %s at %s" % [build_type, pos])
		var success = farm.build(build_type, pos)

		if success:
			log_pass("Build type '%s' works" % build_type)
		else:
			log_warning("Build type '%s' failed (might be biome incompatibility)" % build_type)

	farm.queue_free()


func test_quantum_mechanics():
	log_test("\n### TEST 5: Quantum Mechanics")

	var Farm = load("res://Core/Farm.gd")
	var farm = Farm.new()
	farm._ready()

	farm.economy.add_resource("💰", 10000, "test setup")

	# Plant two adjacent plots for entanglement testing
	var pos_a = Vector2i(1, 1)
	var pos_b = Vector2i(2, 1)

	farm.build("wheat", pos_a)
	farm.build("wheat", pos_b)

	# Test Bell gate (entanglement)
	log_info("Testing Bell gate entanglement")
	var entangle_success = farm.grid.apply_bell_gate(pos_a, pos_b)

	if entangle_success:
		log_pass("Bell gate application successful")

		# Check entanglement state
		var plot_a = farm.grid.get_plot(pos_a)
		var plot_b = farm.grid.get_plot(pos_b)

		if plot_a and plot_b:
			if plot_a.plot_infrastructure_entanglements.has(pos_b):
				log_pass("Plot A records entanglement with B")
			else:
				log_error("Plot A does not record entanglement")

			if plot_b.plot_infrastructure_entanglements.has(pos_a):
				log_pass("Plot B records entanglement with A")
			else:
				log_error("Plot B does not record entanglement")
	else:
		log_error("Bell gate application failed")

	# Test measurement
	log_info("Testing measurement")
	var measure_success = farm.measure_plot(pos_a)

	if measure_success:
		log_pass("Measurement successful")
		var plot = farm.grid.get_plot(pos_a)
		if plot and plot.has_been_measured:
			log_pass("Plot correctly marked as measured")
			log_info("  Measured outcome: %s" % plot.measured_outcome)
		else:
			log_error("Plot not marked as measured")
	else:
		log_error("Measurement failed")

	farm.queue_free()


func test_biome_mechanics():
	log_test("\n### TEST 6: Biome Mechanics")

	var Farm = load("res://Core/Farm.gd")
	var farm = Farm.new()
	farm._ready()

	# Check biomes initialized
	if not farm.grid.biomes or farm.grid.biomes.size() == 0:
		log_error("No biomes initialized")
		farm.queue_free()
		return

	log_pass("Biomes initialized: %d" % farm.grid.biomes.size())

	for biome_name in farm.grid.biomes:
		log_info("  Biome: %s" % biome_name)
		var biome = farm.grid.biomes[biome_name]

		# Check biome has bath
		if not biome.bath:
			log_error("Biome '%s' has no bath" % biome_name)
		else:
			log_pass("Biome '%s' has bath" % biome_name)

			# Check bath emojis
			if biome.bath.emoji_list.size() == 0:
				log_warning("Biome '%s' bath has no emojis" % biome_name)
			else:
				log_info("    Bath emojis (%d): %s" % [biome.bath.emoji_list.size(), ", ".join(biome.bath.emoji_list)])

		# Check biome evolution
		if biome.has_method("advance_simulation"):
			biome.advance_simulation(0.1)  # Advance 0.1 seconds
			log_pass("Biome '%s' advance_simulation works" % biome_name)
		else:
			log_error("Biome '%s' missing advance_simulation method" % biome_name)

	farm.queue_free()


func test_balance():
	log_test("\n### TEST 7: Balance Checks")

	var Farm = load("res://Core/Farm.gd")
	var farm = Farm.new()
	farm._ready()

	# Check starting balance (use emoji-credits API)
	var start_credits = farm.economy.get_resource("💰")
	log_info("Starting credits: %d" % start_credits)

	# Check wheat cost
	var wheat_cost = farm._get_build_cost("wheat")
	log_info("Wheat cost: %s" % wheat_cost)

	var wheat_credit_cost = wheat_cost.get("credits", 0)
	if wheat_credit_cost > start_credits:
		log_error("Cannot afford wheat at start (cost: %d, have: %d)" % [wheat_credit_cost, start_credits])
	else:
		log_pass("Can afford wheat at game start")

	# Test full economic cycle
	# Reset to known amount (clear and set)
	farm.economy.emoji_credits["💰"] = 10000  # 1000 units
	var before_plant = farm.economy.get_resource("💰")

	var pos = Vector2i(1, 1)
	farm.build("wheat", pos)
	var after_plant = farm.economy.get_resource("💰")

	var plant_cost_actual = before_plant - after_plant
	log_info("Actual wheat planting cost: %d credits" % plant_cost_actual)

	# Wait for some growth (simulate time passing)
	var plot = farm.grid.get_plot(pos)
	if plot and plot.quantum_state:
		var initial_radius = plot.quantum_state.radius

		# Simulate 10 seconds of growth
		for i in range(600):  # 10 seconds @ 60fps
			farm.update(1.0 / 60.0)

		var final_radius = plot.quantum_state.radius
		log_info("Growth over 10s: %.3f → %.3f (change: %.3f)" % [initial_radius, final_radius, final_radius - initial_radius])

		if final_radius < initial_radius:
			log_warning("Wheat is SHRINKING (negative growth)")
		elif abs(final_radius - initial_radius) < 0.001:
			log_warning("Wheat is NOT GROWING (stagnant)")
		else:
			log_pass("Wheat is growing")

		# Harvest and check returns
		var harvest_result = farm.harvest_plot(pos)
		var energy = harvest_result.get("energy", 0.0)
		var credits_gained = int(energy * 10)  # Rough conversion

		log_info("Harvest energy: %.3f (≈%d credits)" % [energy, credits_gained])

		if credits_gained < plant_cost_actual:
			log_warning("BALANCE ISSUE: Harvest returns (%d) less than plant cost (%d)" % [credits_gained, plant_cost_actual])
		else:
			log_pass("Harvest returns more than plant cost (profitable)")

	farm.queue_free()


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
