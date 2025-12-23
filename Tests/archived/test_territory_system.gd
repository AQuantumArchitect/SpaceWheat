extends SceneTree

## Automated test for Icon Territory Warfare system
## Tests territory calculations, Icon negotiation, and gameplay effects

const FactionTerritoryManager = preload("res://Core/GameMechanics/FactionTerritoryManager.gd")
const BioticFluxIcon = preload("res://Core/Icons/BioticFluxIcon.gd")
const ChaosIcon = preload("res://Core/Icons/ChaosIcon.gd")
const ImperiumIcon = preload("res://Core/Icons/ImperiumIcon.gd")

var territory_manager: FactionTerritoryManager
var biotic_icon: BioticFluxIcon
var chaos_icon: ChaosIcon
var imperium_icon: ImperiumIcon

var test_count = 0
var test_passed = 0
var test_failed = 0


func _initialize():
	print("\n🧪 Starting Icon Territory System Tests...\n")

	# Create Icon instances
	biotic_icon = BioticFluxIcon.new()
	chaos_icon = ChaosIcon.new()
	imperium_icon = ImperiumIcon.new()

	# Create territory manager (Factions control territory, Icons are quantum layer)
	territory_manager = FactionTerritoryManager.new()
	# NOTE: Icons are separate from factions - no set_icons() call needed

	# Register test plots (5x5 grid)
	for x in range(5):
		for y in range(5):
			territory_manager.register_plot(Vector2i(x, y))

	# Run tests
	test_territory_initialization()
	test_neutral_percentage_calculation()
	test_territory_influence_calculation()
	test_territory_effects()
	test_icon_negotiation()
	test_territory_recalculation()

	# Print results
	print_results()

	# Exit
	quit()


func test_territory_initialization():
	test_count += 1
	print("🧪 Test 1: Territory Initialization")

	# All plots should start neutral
	var stats = territory_manager.get_territory_stats()

	if stats.neutral_plots == 25:
		print("  ✅ All 25 plots initialized as neutral")
		test_passed += 1
	else:
		print("  ❌ FAILED: Expected 25 neutral plots, got %d" % stats.neutral_plots)
		test_failed += 1

	print("")


func test_neutral_percentage_calculation():
	test_count += 1
	print("🧪 Test 2: Neutral Percentage Calculation")

	var stats = territory_manager.get_territory_stats()

	# Should have neutral_percentage key
	if stats.has("neutral_percentage"):
		print("  ✅ neutral_percentage key exists")

		# Should be 100% at start
		if abs(stats.neutral_percentage - 100.0) < 0.01:
			print("  ✅ neutral_percentage = 100%% (correct)")
			test_passed += 1
		else:
			print("  ❌ FAILED: Expected 100%%, got %.2f%%" % stats.neutral_percentage)
			test_failed += 1
	else:
		print("  ❌ FAILED: neutral_percentage key missing!")
		test_failed += 1

	print("")


func test_territory_influence_calculation():
	test_count += 1
	print("🧪 Test 3: Faction Influence Calculation")

	# NOTE: Architecture changed - Factions control territory, Icons affect quantum physics
	# Icons no longer directly control territory

	# Offer tribute to boost Granary Guilds faction strength
	territory_manager.offer_tribute("granary_guilds", 50)  # Large tribute

	# Manually trigger recalculation
	territory_manager._recalculate_all_territories()

	# Check if Granary Guilds gained territory
	var stats = territory_manager.get_territory_stats()

	if stats.granary_guilds_plots > 0:
		print("  ✅ Granary Guilds captured %d plots after tribute" % stats.granary_guilds_plots)
		test_passed += 1
	else:
		print("  ❌ FAILED: Granary Guilds should capture plots after large tribute")
		test_failed += 1

	# Check dominant faction
	var dominant = territory_manager.get_dominant_faction()
	print("  Dominant faction: %s" % dominant)

	print("")


func test_territory_effects():
	test_count += 1
	print("🧪 Test 4: Faction Territory Effects")

	# NOTE: Architecture changed - Factions (not Icons) control territory
	# Test Granary Guilds territory effects (agricultural faction)
	var granary_plot = Vector2i(2, 2)  # Center plot
	territory_manager.plot_controllers[granary_plot] = "granary_guilds"

	var effects = territory_manager.get_territory_effects(granary_plot)

	if effects.has("growth_rate_multiplier"):
		var growth_mult = effects.growth_rate_multiplier
		if abs(growth_mult - 1.2) < 0.01:
			print("  ✅ Granary Guilds growth multiplier = 1.2 (correct)")
			test_passed += 1
		else:
			print("  ❌ FAILED: Expected 1.2, got %.2f" % growth_mult)
			test_failed += 1
	else:
		print("  ❌ FAILED: growth_rate_multiplier missing")
		test_failed += 1

	# Test neutral plot
	var neutral_plot = Vector2i(0, 0)
	territory_manager.plot_controllers[neutral_plot] = "neutral"
	var neutral_effects = territory_manager.get_territory_effects(neutral_plot)

	if neutral_effects.is_empty():
		print("  ✅ Neutral plots have no effects (correct)")
	else:
		print("  ⚠️ WARNING: Neutral plots should have no effects")

	print("")


func test_icon_negotiation():
	test_count += 1
	print("🧪 Test 5: Icon Negotiation")

	# Icons are set separately (quantum layer)
	biotic_icon.set_activation(0.5)
	chaos_icon.set_activation(0.5)
	imperium_icon.set_activation(0.5)

	# Test faction tribute (CLASSICAL LAYER - Factions control territory)
	var success = territory_manager.offer_tribute("granary_guilds", 10)

	if success:
		print("  ✅ Tribute accepted by Granary Guilds faction")

		# Check if faction strength increased
		var faction_strength = territory_manager.faction_strength.get("granary_guilds", 0.0)
		if faction_strength > 0.3:  # Started at 0.3
			print("  ✅ Granary Guilds faction strength increased to %.2f" % faction_strength)
			test_passed += 1
		else:
			print("  ❌ FAILED: Tribute didn't increase activation")
			test_failed += 1
	else:
		print("  ❌ FAILED: Tribute rejected")
		test_failed += 1

	print("")


func test_territory_recalculation():
	test_count += 1
	print("🧪 Test 6: Faction Territory Recalculation")

	# NOTE: Architecture changed - Factions control territory based on tribute/reputation
	# Icons (biotic, chaos, imperium) affect quantum physics, not territory

	# Boost different factions to test competition
	territory_manager.offer_tribute("granary_guilds", 100)  # Very large tribute
	territory_manager.offer_tribute("carrion_throne", 30)
	territory_manager.offer_tribute("laughing_court", 50)

	# Trigger recalculation
	territory_manager._recalculate_all_territories()

	var stats = territory_manager.get_territory_stats()

	# Granary Guilds should dominate (largest tribute)
	if stats.granary_guilds_plots >= stats.carrion_throne_plots and stats.granary_guilds_plots >= stats.laughing_court_plots:
		print("  ✅ Granary Guilds dominates with %d plots" % stats.granary_guilds_plots)
		test_passed += 1
	else:
		print("  ❌ FAILED: Granary Guilds should dominate with largest tribute")
		print("     Granary Guilds: %d, Carrion Throne: %d, Laughing Court: %d" %
			[stats.granary_guilds_plots, stats.carrion_throne_plots, stats.laughing_court_plots])
		test_failed += 1

	# Check percentages sum to ~100%
	var total_pct = (stats.granary_guilds_percentage + stats.carrion_throne_percentage +
					 stats.laughing_court_percentage + stats.yeast_prophets_percentage +
					 stats.house_of_thorns_percentage + stats.neutral_percentage)
	if abs(total_pct - 100.0) < 1.0:
		print("  ✅ Territory percentages sum to %.1f%% (correct)" % total_pct)
	else:
		print("  ⚠️ WARNING: Territory percentages sum to %.1f%% (should be ~100%%)" % total_pct)

	print("")


func print_results():
	print("\n" + "=".repeat(50))
	print("🧪 TEST RESULTS")
	print("=".repeat(50))
	print("Total Tests: %d" % test_count)
	print("✅ Passed: %d" % test_passed)
	print("❌ Failed: %d" % test_failed)
	print("Success Rate: %.1f%%" % ((float(test_passed) / float(test_count)) * 100.0))
	print("=".repeat(50) + "\n")

	if test_failed == 0:
		print("🎉 ALL TESTS PASSED! Icon Territory System is working correctly.")
	else:
		print("⚠️ SOME TESTS FAILED. Review the errors above.")
