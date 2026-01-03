extends SceneTree

## Test Phase 2: Objectives

const ObjectiveType = preload("res://Core/Quests/ObjectiveType.gd")
const QuantumObjective = preload("res://Core/Quests/QuantumObjective.gd")
const QuantumCondition = preload("res://Core/Quests/QuantumCondition.gd")
const QuantumOperation = preload("res://Core/Quests/QuantumOperation.gd")

func _init():
	print("================================================================================")
	print("🧪 QUANTUM QUEST SYSTEM - PHASE 2 TESTS")
	print("================================================================================")

	var all_passed = true

	all_passed = test_objective_type() and all_passed
	all_passed = test_quantum_objective() and all_passed

	print("\n================================================================================")
	if all_passed:
		print("✅ ALL PHASE 2 TESTS PASSED")
		quit(0)
	else:
		print("❌ SOME TESTS FAILED")
		quit(1)

func test_objective_type() -> bool:
	print("\n🎯 Testing ObjectiveType...")

	var tests_passed = 0
	var tests_total = 0

	# Test 1: Type count
	tests_total += 1
	var all_types = ObjectiveType.get_all_types()
	if all_types.size() == 24:
		print("  ✓ 24 objective types defined")
		tests_passed += 1
	else:
		print("  ✗ Expected 24 types, got %d" % all_types.size())

	# Test 2: Display names
	tests_total += 1
	var achieve_name = ObjectiveType.get_display_name(ObjectiveType.ACHIEVE_STATE)
	if achieve_name == "Achieve State":
		print("  ✓ Display names work")
		tests_passed += 1
	else:
		print("  ✗ Display name failed: got '%s'" % achieve_name)

	# Test 3: Emojis
	tests_total += 1
	var harvest_emoji = ObjectiveType.get_emoji(ObjectiveType.HARVEST_EMOJI)
	if harvest_emoji == "🌾":
		print("  ✓ Objective emojis work")
		tests_passed += 1
	else:
		print("  ✗ Emoji failed: got '%s'" % harvest_emoji)

	# Test 4: Categories
	tests_total += 1
	var cat_state = ObjectiveType.get_category(ObjectiveType.ACHIEVE_STATE)
	var cat_ent = ObjectiveType.get_category(ObjectiveType.CREATE_ENTANGLEMENT)
	if cat_state == "State-Based" and cat_ent == "Entanglement":
		print("  ✓ Objective categories work")
		tests_passed += 1
	else:
		print("  ✗ Categories failed: %s, %s" % [cat_state, cat_ent])

	# Test 5: Requirement checks
	tests_total += 1
	var maintain_needs_time = ObjectiveType.requires_time_tracking(ObjectiveType.MAINTAIN_STATE)
	var sequence_needs_ops = ObjectiveType.requires_operation_tracking(ObjectiveType.SEQUENCE_OPERATIONS)
	var navigate_needs_path = ObjectiveType.requires_path_tracking(ObjectiveType.NAVIGATE_BLOCH)
	if maintain_needs_time and sequence_needs_ops and navigate_needs_path:
		print("  ✓ Requirement checks work")
		tests_passed += 1
	else:
		print("  ✗ Requirement checks failed")

	var result = tests_passed == tests_total
	print("  Result: %d/%d tests passed" % [tests_passed, tests_total])
	return result

func test_quantum_objective() -> bool:
	print("\n🎁 Testing QuantumObjective...")

	var tests_passed = 0
	var tests_total = 0

	# Test 1: Factory method - achieve state
	tests_total += 1
	var theta_cond = QuantumCondition.create_theta_condition("🌾", "🐺", PI/2, 0.1)
	var achieve_obj = QuantumObjective.create_achieve_state_objective([theta_cond])
	if achieve_obj.objective_type == ObjectiveType.ACHIEVE_STATE and achieve_obj.conditions.size() == 1:
		print("  ✓ Achieve state objective factory works")
		tests_passed += 1
	else:
		print("  ✗ Achieve state objective failed")

	# Test 2: Description
	tests_total += 1
	var desc = achieve_obj.describe()
	if "Achieve" in desc and "polar angle" in desc:
		print("  ✓ Objective description: '%s'" % desc.split("\n")[0])
		tests_passed += 1
	else:
		print("  ✗ Description failed: '%s'" % desc)

	# Test 3: Factory method - maintain state
	tests_total += 1
	var maintain_obj = QuantumObjective.create_maintain_state_objective([theta_cond], 5.0)
	if maintain_obj.min_duration == 5.0:
		print("  ✓ Maintain state objective factory works")
		tests_passed += 1
	else:
		print("  ✗ Maintain state objective failed")

	# Test 4: Factory method - entanglement
	tests_total += 1
	var ent_cond = QuantumCondition.create_entanglement_condition(
		["🌾", "🐺"], ["🍅", "🍝"], 0.8
	)
	var ent_obj = QuantumObjective.create_entanglement_objective(ent_cond, 3.0)
	if ent_obj.objective_type == ObjectiveType.CREATE_ENTANGLEMENT:
		print("  ✓ Entanglement objective factory works")
		tests_passed += 1
	else:
		print("  ✗ Entanglement objective failed")

	# Test 5: Factory method - harvest
	tests_total += 1
	var harvest_obj = QuantumObjective.create_harvest_objective("🌾", 0.7)
	if harvest_obj.emoji_targets == ["🌾"] and harvest_obj.conditions.size() > 0:
		print("  ✓ Harvest objective factory works")
		tests_passed += 1
	else:
		print("  ✗ Harvest objective failed")

	# Test 6: Validation
	tests_total += 1
	if achieve_obj.is_valid():
		print("  ✓ Objective validation works")
		tests_passed += 1
	else:
		print("  ✗ Validation failed")

	# Test 7: Difficulty estimation
	tests_total += 1
	var difficulty = achieve_obj.estimate_difficulty()
	if difficulty > 0.0 and difficulty <= 1.0:
		print("  ✓ Difficulty estimation: %.2f" % difficulty)
		tests_passed += 1
	else:
		print("  ✗ Difficulty estimation failed: %.2f" % difficulty)

	# Test 8: Short description
	tests_total += 1
	var short_desc = achieve_obj.describe_short()
	if "🎯" in short_desc:
		print("  ✓ Short description: '%s'" % short_desc)
		tests_passed += 1
	else:
		print("  ✗ Short description failed: '%s'" % short_desc)

	var result = tests_passed == tests_total
	print("  Result: %d/%d tests passed" % [tests_passed, tests_total])
	return result
