extends SceneTree

## Integration test: Scenario progression system
## Demonstrates the unlock and prerequisite system works correctly
##
## Test Flow:
## 1. Create ScenarioRegistry and load all scenarios
## 2. Check that tutorial_basics is available by default
## 3. Verify challenge_time_trial is LOCKED (requires tutorial_basics)
## 4. Verify sandbox_small is available by default
## 5. Mark tutorial_basics as completed
## 6. Verify challenge_time_trial is now UNLOCKED
## 7. Verify scenario sorting by difficulty
## 8. Verify metadata for each scenario
##
## Expected Output: ✓ All scenario progression tests pass

var test_results: Array = []
var test_passed: bool = true

func _ready():
	print("\n" + "="*60)
	print("🧪 INTEGRATION TEST: Scenario Progression System")
	print("="*60 + "\n")

	# Step 1: Create registry
	print("📍 Step 1: Create ScenarioRegistry and load scenarios")
	var registry = ScenarioRegistry.new()
	registry._load_all_scenarios()
	registry._load_completed_scenarios()

	print("✓ Registry created and scenarios loaded")
	print("  Total scenarios found: %d" % registry.scenario_list.size())

	# Print all scenarios
	for meta in registry.scenario_list:
		print("  - [%s] %s (difficulty: %s)" % [meta.scenario_id, meta.display_name, meta.difficulty])

	# Step 2: Verify tutorial_basics exists and is unlocked by default
	print("\n📍 Step 2: Verify tutorial_basics is available by default")
	var tutorial_meta = registry.get_scenario_by_id("tutorial_basics")
	if not tutorial_meta:
		fail_test("tutorial_basics not found!")
		quit()
		return

	if not tutorial_meta.unlocked_by_default:
		fail_test("tutorial_basics should be unlocked by default!")

	if tutorial_meta.prerequisites.size() != 0:
		fail_test("tutorial_basics should have no prerequisites!")

	print("✓ tutorial_basics found and unlocked by default")
	print("  Display name: %s" % tutorial_meta.display_name)
	print("  Description: %s" % tutorial_meta.description)
	print("  Difficulty: %s" % tutorial_meta.difficulty)
	print("  Grid size: %s" % tutorial_meta.grid_size)
	print("  Starting credits: %d" % tutorial_meta.starting_credits)

	# Step 3: Verify challenge_time_trial is locked initially
	print("\n📍 Step 3: Verify challenge_time_trial is LOCKED initially")
	var challenge_meta = registry.get_scenario_by_id("challenge_time_trial")
	if not challenge_meta:
		fail_test("challenge_time_trial not found!")
		quit()
		return

	if challenge_meta.unlocked_by_default:
		fail_test("challenge_time_trial should NOT be unlocked by default!")

	if "tutorial_basics" not in challenge_meta.prerequisites:
		fail_test("challenge_time_trial should require tutorial_basics as prerequisite!")

	var unlocked_initially = registry._is_scenario_unlocked(challenge_meta)
	if unlocked_initially:
		fail_test("challenge_time_trial should be locked initially!")

	print("✓ challenge_time_trial is locked (requires tutorial_basics)")
	print("  Prerequisites: %s" % str(challenge_meta.prerequisites))
	print("  Difficulty: %s" % challenge_meta.difficulty)

	# Step 4: Verify sandbox_small is available by default
	print("\n📍 Step 4: Verify sandbox_small is available by default")
	var sandbox_meta = registry.get_scenario_by_id("sandbox_small")
	if not sandbox_meta:
		fail_test("sandbox_small not found!")
		quit()
		return

	if not sandbox_meta.unlocked_by_default:
		fail_test("sandbox_small should be unlocked by default!")

	print("✓ sandbox_small available by default")
	print("  Difficulty: %s" % sandbox_meta.difficulty)
	print("  Starting credits: %d" % sandbox_meta.starting_credits)

	# Step 5: Get unlocked scenarios (before completion)
	print("\n📍 Step 5: Check unlocked scenarios (before completion)")
	var unlocked_before = registry.get_unlocked_scenarios()
	print("✓ Unlocked scenarios before completion:")
	for meta in unlocked_before:
		print("  - %s" % meta.display_name)

	var tutorial_in_unlocked = false
	var challenge_in_unlocked = false
	var sandbox_in_unlocked = false
	for meta in unlocked_before:
		if meta.scenario_id == "tutorial_basics":
			tutorial_in_unlocked = true
		elif meta.scenario_id == "challenge_time_trial":
			challenge_in_unlocked = true
		elif meta.scenario_id == "sandbox_small":
			sandbox_in_unlocked = true

	if not tutorial_in_unlocked:
		fail_test("tutorial_basics should be in unlocked scenarios!")
	if challenge_in_unlocked:
		fail_test("challenge_time_trial should NOT be in unlocked scenarios yet!")
	if not sandbox_in_unlocked:
		fail_test("sandbox_small should be in unlocked scenarios!")

	# Step 6: Mark tutorial_basics as completed
	print("\n📍 Step 6: Mark tutorial_basics as completed")
	registry.mark_scenario_completed("tutorial_basics")
	print("✓ Marked tutorial_basics as completed")

	# Verify challenge_time_trial is now unlocked
	var unlocked_after = registry.get_unlocked_scenarios()
	print("✓ Unlocked scenarios after completion:")
	for meta in unlocked_after:
		print("  - %s" % meta.display_name)

	var challenge_now_unlocked = false
	for meta in unlocked_after:
		if meta.scenario_id == "challenge_time_trial":
			challenge_now_unlocked = true
			break

	if not challenge_now_unlocked:
		fail_test("challenge_time_trial should be unlocked after completing tutorial_basics!")

	# Step 7: Verify completion tracking
	print("\n📍 Step 7: Verify completion tracking")
	if not registry.is_scenario_completed("tutorial_basics"):
		fail_test("tutorial_basics should be marked as completed!")
	print("✓ tutorial_basics correctly marked as completed")

	if registry.is_scenario_completed("challenge_time_trial"):
		fail_test("challenge_time_trial should NOT be marked as completed yet!")
	print("✓ challenge_time_trial correctly NOT marked as completed")

	# Step 8: Verify scenario sorting by difficulty
	print("\n📍 Step 8: Verify scenario sorting by difficulty")
	var all_scenarios = registry.get_all_scenarios()
	print("✓ Scenarios in difficulty order:")
	var last_difficulty_idx = -1
	var difficulty_order = ["tutorial", "easy", "normal", "hard", "expert", "sandbox"]

	for meta in all_scenarios:
		var difficulty_idx = difficulty_order.find(meta.difficulty)
		if difficulty_idx == -1:
			difficulty_idx = difficulty_order.size()
		print("  - [%s] %s" % [meta.difficulty, meta.display_name])

		if difficulty_idx < last_difficulty_idx:
			fail_test("Scenarios not sorted by difficulty!")
		last_difficulty_idx = difficulty_idx

	# Step 9: Verify scenario metadata completeness
	print("\n📍 Step 9: Verify scenario metadata completeness")
	for meta in all_scenarios:
		var checks = {
			"scenario_id": not meta.scenario_id.is_empty(),
			"display_name": not meta.display_name.is_empty(),
			"description": not meta.description.is_empty(),
			"difficulty": not meta.difficulty.is_empty(),
			"grid_size": not meta.grid_size.is_empty(),
			"starting_credits": meta.starting_credits >= 0,
		}

		var all_valid = true
		for check_name in checks:
			if not checks[check_name]:
				all_valid = false
				print("  ✗ %s: missing or invalid %s" % [meta.scenario_id, check_name])

		if all_valid:
			print("  ✓ %s: all metadata valid" % meta.display_name)

	# Step 10: Test loading scenario gamestate
	print("\n📍 Step 10: Test loading scenario gamestates")
	for scenario_id in ["tutorial_basics", "challenge_time_trial", "sandbox_small"]:
		var gamestate = registry.load_scenario_gamestate(scenario_id)
		if not gamestate:
			fail_test("Could not load %s gamestate!" % scenario_id)
		else:
			print("✓ Loaded %s gamestate: %dx%d, %d credits" %
				  [scenario_id, gamestate.grid_width, gamestate.grid_height, gamestate.credits])

	# Final summary
	print("\n" + "="*60)
	if test_passed:
		print("✅ ALL TESTS PASSED!")
		print("Scenario progression system is working correctly")
	else:
		print("❌ SOME TESTS FAILED")
	print("="*60 + "\n")

	quit()


func fail_test(message: String):
	"""Mark test as failed"""
	test_passed = false
	print("❌ FAILED: " + message)
