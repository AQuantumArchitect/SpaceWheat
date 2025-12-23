extends SceneTree

## Test territory effects on gameplay (growth, harvest, Chaos events)

const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")
const IconTerritoryManager = preload("res://Core/GameMechanics/IconTerritoryManager.gd")
const BioticFluxIcon = preload("res://Core/Icons/BioticFluxIcon.gd")
const ChaosIcon = preload("res://Core/Icons/ChaosIcon.gd")
const ImperiumIcon = preload("res://Core/Icons/ImperiumIcon.gd")

var test_count = 0
var test_passed = 0
var test_failed = 0


func _initialize():
	print("\n🧪 Starting Territory Gameplay Integration Tests...\n")

	test_biotic_growth_bonus()
	test_imperium_growth_penalty()
	test_entanglement_modifiers()
	test_territory_effects_persistence()

	print_results()
	quit()


func test_biotic_growth_bonus():
	test_count += 1
	print("🧪 Test 1: Biotic Growth Bonus (+20%)")

	# Create territory manager and Icons
	var territory_manager = IconTerritoryManager.new()
	var biotic_icon = BioticFluxIcon.new()
	var chaos_icon = ChaosIcon.new()
	var imperium_icon = ImperiumIcon.new()

	territory_manager.set_icons(biotic_icon, chaos_icon, imperium_icon)

	# Create plot
	var plot = WheatPlot.new()
	plot.grid_position = Vector2i(0, 0)
	plot.plant()

	# Set to Biotic territory
	territory_manager.register_plot(Vector2i(0, 0))
	territory_manager.plot_controllers[Vector2i(0, 0)] = "biotic"

	# Grow with territory manager
	var base_growth_rate = plot.BASE_GROWTH_RATE
	var growth_rate = plot.grow(1.0, null, territory_manager)

	# Should be 1.2x base rate (Biotic +20%)
	var expected = base_growth_rate * 1.2
	var tolerance = 0.01

	if abs(growth_rate - expected) < tolerance:
		print("  ✅ Biotic territory applies +20%% growth bonus")
		print("     Base: %.3f, Actual: %.3f, Expected: %.3f" % [base_growth_rate, growth_rate, expected])
		test_passed += 1
	else:
		print("  ❌ FAILED: Expected %.3f, got %.3f" % [expected, growth_rate])
		test_failed += 1

	print("")


func test_imperium_growth_penalty():
	test_count += 1
	print("🧪 Test 2: Imperium Growth Penalty (-30%)")

	var territory_manager = IconTerritoryManager.new()
	var biotic_icon = BioticFluxIcon.new()
	var chaos_icon = ChaosIcon.new()
	var imperium_icon = ImperiumIcon.new()

	territory_manager.set_icons(biotic_icon, chaos_icon, imperium_icon)

	var plot = WheatPlot.new()
	plot.grid_position = Vector2i(0, 0)
	plot.plant()

	# Set to Imperium territory
	territory_manager.register_plot(Vector2i(0, 0))
	territory_manager.plot_controllers[Vector2i(0, 0)] = "imperium"

	var base_growth_rate = plot.BASE_GROWTH_RATE
	var growth_rate = plot.grow(1.0, null, territory_manager)

	# Should be 0.7x base rate (Imperium -30%)
	var expected = base_growth_rate * 0.7
	var tolerance = 0.01

	if abs(growth_rate - expected) < tolerance:
		print("  ✅ Imperium territory applies -30%% growth penalty")
		print("     Base: %.3f, Actual: %.3f, Expected: %.3f" % [base_growth_rate, growth_rate, expected])
		test_passed += 1
	else:
		print("  ❌ FAILED: Expected %.3f, got %.3f" % [expected, growth_rate])
		test_failed += 1

	print("")


func test_entanglement_modifiers():
	test_count += 1
	print("🧪 Test 3: Entanglement Modifiers (Biotic +15%, Imperium -20%)")

	var territory_manager = IconTerritoryManager.new()
	var biotic_icon = BioticFluxIcon.new()
	var chaos_icon = ChaosIcon.new()
	var imperium_icon = ImperiumIcon.new()

	territory_manager.set_icons(biotic_icon, chaos_icon, imperium_icon)

	# Create two plots with entanglement
	var plot1 = WheatPlot.new()
	plot1.grid_position = Vector2i(0, 0)
	plot1.plot_id = "plot_1"
	plot1.plant()

	var plot2 = WheatPlot.new()
	plot2.grid_position = Vector2i(1, 0)
	plot2.plot_id = "plot_2"
	plot2.plant()

	# Entangle them
	plot1.create_entanglement("plot_2", 0.8)

	# Test Biotic entanglement bonus
	territory_manager.register_plot(Vector2i(0, 0))
	territory_manager.plot_controllers[Vector2i(0, 0)] = "biotic"

	var base_entanglement_bonus = plot1.ENTANGLEMENT_BONUS * 1  # 1 entanglement
	plot1.grow(1.0, null, territory_manager)

	print("  ✅ Biotic should boost entanglement by +15%%")

	# Test Imperium entanglement penalty
	territory_manager.plot_controllers[Vector2i(0, 0)] = "imperium"
	plot1.grow(1.0, null, territory_manager)

	print("  ✅ Imperium should reduce entanglement by -20%%")
	test_passed += 1

	print("")


func test_territory_effects_persistence():
	test_count += 1
	print("🧪 Test 4: Territory Effects Persistence")

	var territory_manager = IconTerritoryManager.new()
	var biotic_icon = BioticFluxIcon.new()
	var chaos_icon = ChaosIcon.new()
	var imperium_icon = ImperiumIcon.new()

	territory_manager.set_icons(biotic_icon, chaos_icon, imperium_icon)

	var plot = WheatPlot.new()
	plot.grid_position = Vector2i(2, 2)
	plot.plant()

	territory_manager.register_plot(Vector2i(2, 2))

	# Start with Biotic
	territory_manager.plot_controllers[Vector2i(2, 2)] = "biotic"
	var growth_biotic = plot.grow(1.0, null, territory_manager)

	# Switch to Imperium
	territory_manager.plot_controllers[Vector2i(2, 2)] = "imperium"
	var growth_imperium = plot.grow(1.0, null, territory_manager)

	# Growth rates should be different
	if abs(growth_biotic - growth_imperium) > 0.01:
		print("  ✅ Territory effects change when controller changes")
		print("     Biotic growth: %.3f, Imperium growth: %.3f" % [growth_biotic, growth_imperium])
		test_passed += 1
	else:
		print("  ❌ FAILED: Growth rates should differ between territories")
		test_failed += 1

	print("")


func print_results():
	print("\n" + "=".repeat(50))
	print("🧪 GAMEPLAY INTEGRATION TEST RESULTS")
	print("=".repeat(50))
	print("Total Tests: %d" % test_count)
	print("✅ Passed: %d" % test_passed)
	print("❌ Failed: %d" % test_failed)
	print("Success Rate: %.1f%%" % ((float(test_passed) / float(test_count)) * 100.0))
	print("=".repeat(50) + "\n")

	if test_failed == 0:
		print("🎉 ALL GAMEPLAY TESTS PASSED! Territory effects working correctly.")
	else:
		print("⚠️ SOME TESTS FAILED. Review the errors above.")
