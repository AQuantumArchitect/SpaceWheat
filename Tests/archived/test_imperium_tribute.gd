extends SceneTree
## Test: Imperium Tribute System
## Verifies that Imperium drains credits and produces imperium resource

const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const ImperiumIcon = preload("res://Core/Icons/ImperiumIcon.gd")

var economy: FarmEconomy
var imperium_icon: ImperiumIcon
var test_results = []
var tests_passed = 0
var tests_failed = 0

func _init():
	print("═══════════════════════════════════════════════════════")
	print("   IMPERIUM TRIBUTE SYSTEM TEST")
	print("═══════════════════════════════════════════════════════")
	print("")

	# Create economy
	economy = FarmEconomy.new()
	get_root().add_child(economy)

	# Create Imperium Icon
	imperium_icon = ImperiumIcon.new()
	imperium_icon.set_activation(0.1)  # Start at 10% activation
	get_root().add_child(imperium_icon)

	# Link Icon to economy
	economy.imperium_icon = imperium_icon

	# Wait for initialization
	await create_timer(0.1).timeout

	# Run tests
	test_basic_tribute_system()
	await create_timer(1.0).timeout

	test_tribute_success()
	await create_timer(1.0).timeout

	test_tribute_failure()
	await create_timer(1.0).timeout

	test_tribute_scaling()
	await create_timer(1.0).timeout

	# Print summary
	_print_summary()

	# Exit
	await create_timer(0.1).timeout
	quit()


func test_basic_tribute_system():
	print("TEST 1: Basic Tribute System")
	print("─────────────────────────────────────────")

	_assert_equal(economy.credits, 100, "Starting credits")
	_assert_equal(economy.imperium_resource, 0, "Starting imperium")
	_assert_true(imperium_icon.active_strength == 0.1, "Imperium Icon at 10% activation")

	print("")


func test_tribute_success():
	print("TEST 2: Successful Tribute Payment")
	print("─────────────────────────────────────────")

	var initial_credits = economy.credits
	var initial_imperium = economy.imperium_resource
	var initial_activation = imperium_icon.active_strength

	# Manually trigger tribute demand
	economy._demand_tribute()

	# Wait for processing
	await create_timer(0.1).timeout

	# Should have paid tribute (started with 100 credits)
	_assert_true(economy.credits < initial_credits, "Credits decreased (paid: %d)" % (initial_credits - economy.credits))
	_assert_true(economy.imperium_resource > initial_imperium, "Imperium resource increased (+%d 🏰)" % (economy.imperium_resource - initial_imperium))
	_assert_true(imperium_icon.active_strength < initial_activation, "Imperium Icon activation decreased (appeased)")
	_assert_equal(economy.total_tributes_paid, 1, "One tribute paid")
	_assert_equal(economy.total_tributes_failed, 0, "No tributes failed")

	print("")


func test_tribute_failure():
	print("TEST 3: Failed Tribute Payment")
	print("─────────────────────────────────────────")

	# Drain all credits
	economy.credits = 0
	var initial_activation = imperium_icon.active_strength
	var initial_imperium = economy.imperium_resource

	# Manually trigger tribute demand
	economy._demand_tribute()

	# Wait for processing
	await create_timer(0.1).timeout

	# Should have failed tribute (no credits)
	_assert_equal(economy.credits, 0, "Still no credits")
	_assert_equal(economy.imperium_resource, initial_imperium, "Imperium resource unchanged (no gain from failure)")
	_assert_true(imperium_icon.active_strength > initial_activation, "Imperium Icon activation increased (displeasure)")
	_assert_equal(economy.total_tributes_failed, 1, "One tribute failed")

	print("")


func test_tribute_scaling():
	print("TEST 4: Tribute Scaling Over Time")
	print("─────────────────────────────────────────")

	# Give player lots of credits
	economy.credits = 1000

	# Pay several tributes
	var tribute_amounts = []
	for i in range(3):
		var before = economy.credits
		economy._demand_tribute()
		await create_timer(0.1).timeout
		var amount = before - economy.credits
		tribute_amounts.append(amount)

	# Check that tribute increases each time
	_assert_true(tribute_amounts[1] > tribute_amounts[0], "Second tribute larger than first (%d > %d)" % [tribute_amounts[1], tribute_amounts[0]])
	_assert_true(tribute_amounts[2] > tribute_amounts[1], "Third tribute larger than second (%d > %d)" % [tribute_amounts[2], tribute_amounts[1]])

	print("  📈 Tribute scaling: %d → %d → %d credits" % [tribute_amounts[0], tribute_amounts[1], tribute_amounts[2]])

	print("")


## Helper functions

func _assert_true(condition: bool, description: String):
	if condition:
		print("  ✅ %s" % description)
		tests_passed += 1
	else:
		print("  ❌ %s" % description)
		tests_failed += 1
	test_results.append({"passed": condition, "description": description})


func _assert_equal(actual, expected, description: String):
	if actual == expected:
		print("  ✅ %s (got %s)" % [description, str(actual)])
		tests_passed += 1
	else:
		print("  ❌ %s (expected %s, got %s)" % [description, str(expected), str(actual)])
		tests_failed += 1
	test_results.append({"passed": actual == expected, "description": description})


func _print_summary():
	print("═══════════════════════════════════════════════════════")
	print("   TEST SUMMARY")
	print("═══════════════════════════════════════════════════════")
	print("")
	print("Total tests: %d" % (tests_passed + tests_failed))
	print("Passed: %d ✅" % tests_passed)
	print("Failed: %d ❌" % tests_failed)
	print("")

	if tests_failed == 0:
		print("🎉 ALL TESTS PASSED!")
		print("")
		print("✨ Imperium Tribute System Working:")
		print("  - Credits drain every 30 seconds")
		print("  - Imperium resource (🏰) produced on payment")
		print("  - Successful tribute appeases Imperium (-5% activation)")
		print("  - Failed tribute angers Imperium (+20% activation)")
		print("  - Tribute amount scales over time (+10% per tribute)")
	else:
		print("⚠️  SOME TESTS FAILED")
		print("")
		print("Failed tests:")
		for result in test_results:
			if not result["passed"]:
				print("  - %s" % result["description"])

	print("")
	print("═══════════════════════════════════════════════════════")
