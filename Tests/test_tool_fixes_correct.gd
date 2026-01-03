extends SceneTree

## Test: Tool Q and Tool R fixes
## Q: Biome validation prevents planting incompatible emojis
## R: Bubbles disappear after measure+harvest

const Farm = preload("res://Core/Farm.gd")

var farm: Farm

func _initialize():
	print("\n" + "=".repeat(80))
	print("🛠️  TEST: Tool Q & R Fixes (Corrected)")
	print("=".repeat(80))

	await get_root().ready

	# Setup farm
	farm = Farm.new()
	farm.name = "Farm"
	get_root().add_child(farm)

	# Connect to action_result signal
	farm.action_result.connect(_on_action_result)

	# TEST 1: Tool Q - Biome validation
	print("\n" + "=".repeat(80))
	print("🧪 TEST 1: Tool Q - Biome Validation")
	print("=".repeat(80))

	# Show plot assignments
	print("\n📍 Plot assignments:")
	print("   (2, 0) → BioticFlux (has 🌾, 🍄)")
	print("   (0, 0) → Market (no 🌾)")

	# Try to plant wheat in BioticFlux plot (should succeed)
	print("\n🌾 Attempting to plant WHEAT at (2,0) [BioticFlux biome]...")
	var wheat_biotic = farm.build(Vector2i(2, 0), "wheat")

	# Try to plant wheat in Market plot (should fail)
	print("\n🌾 Attempting to plant WHEAT at (0,0) [Market biome]...")
	var wheat_market = farm.build(Vector2i(0, 0), "wheat")

	# Try to plant tomato in BioticFlux (should fail - no 🍅)
	print("\n🍅 Attempting to plant TOMATO at (3,0) [BioticFlux biome]...")
	var tomato_biotic = farm.build(Vector2i(3, 0), "tomato")

	# TEST 2: Tool R - Bubble removal
	print("\n" + "=".repeat(80))
	print("🧪 TEST 2: Tool R - Bubble Removal After Harvest")
	print("=".repeat(80))

	# Plant mushroom in BioticFlux plot
	print("\n🍄 Planting mushroom at (4,0) [BioticFlux biome]...")
	var mushroom_success = farm.build(Vector2i(4, 0), "mushroom")

	if mushroom_success:
		# Advance simulation to let it grow a bit
		var biotic_flux = farm.get_node("BioticFlux")
		if biotic_flux:
			biotic_flux.advance_simulation(5.0)

		# Measure and harvest
		print("\n🔬✂️  Measuring and harvesting mushroom...")
		farm.measure_plot(Vector2i(4, 0))
		var harvest_result = farm.harvest_plot(Vector2i(4, 0))

		# Check plot state
		var plot = farm.grid.get_plot(Vector2i(4, 0))
		if plot:
			print("\n📊 Plot state after harvest:")
			print("   quantum_state: %s" % ("null ✅" if plot.quantum_state == null else "EXISTS ❌"))
			print("   is_planted: %s" % ("false ✅" if not plot.is_planted else "true ❌"))
			print("   has_been_measured: %s" % ("false ✅" if not plot.has_been_measured else "true ❌"))

	# SUMMARY
	print("\n" + "=".repeat(80))
	print("📊 SUMMARY")
	print("=".repeat(80))

	var test1_pass = wheat_biotic and not wheat_market and not tomato_biotic
	var test2_pass = mushroom_success

	print("\n🧪 Test 1 (Biome Validation):")
	print("   Wheat in BioticFlux: %s" % ("✅ ALLOWED" if wheat_biotic else "❌ BLOCKED"))
	print("   Wheat in Market: %s" % ("✅ BLOCKED" if not wheat_market else "❌ ALLOWED"))
	print("   Tomato in BioticFlux: %s" % ("✅ BLOCKED" if not tomato_biotic else "❌ ALLOWED"))
	print("   → Test 1: %s" % ("✅ PASS" if test1_pass else "❌ FAIL"))

	print("\n🧪 Test 2 (Bubble Removal):")
	var plot = farm.grid.get_plot(Vector2i(4, 0))
	if plot:
		var state_cleared = plot.quantum_state == null
		var not_planted = not plot.is_planted
		var not_measured = not plot.has_been_measured
		test2_pass = state_cleared and not_planted and not_measured
		print("   quantum_state cleared: %s" % ("✅" if state_cleared else "❌"))
		print("   is_planted=false: %s" % ("✅" if not_planted else "❌"))
		print("   has_been_measured=false: %s" % ("✅" if not_measured else "❌"))
		print("   → Test 2: %s" % ("✅ PASS" if test2_pass else "❌ FAIL"))
	else:
		print("   ❌ Plot not found")
		test2_pass = false

	if test1_pass and test2_pass:
		print("\n🎉 ALL TESTS PASSED!")
		print("   ✅ Tool Q: Biome validation working correctly")
		print("   ✅ Tool R: Bubble removal working correctly")
	else:
		print("\n⚠️  SOME TESTS FAILED")

	print("\n" + "=".repeat(80))
	quit(0)

func _on_action_result(action: String, success: bool, message: String):
	var status = "✅" if success else "❌"
	print("   %s %s" % [status, message])
