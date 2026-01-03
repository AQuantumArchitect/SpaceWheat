extends SceneTree

## Test Phase 3: Quests

const QuestCategory = preload("res://Core/Quests/QuestCategory.gd")
const QuantumQuest = preload("res://Core/Quests/QuantumQuest.gd")
const QuantumObjective = preload("res://Core/Quests/QuantumObjective.gd")
const QuantumCondition = preload("res://Core/Quests/QuantumCondition.gd")
const ObjectiveType = preload("res://Core/Quests/ObjectiveType.gd")

func _init():
	print("================================================================================")
	print("🧪 QUANTUM QUEST SYSTEM - PHASE 3 TESTS")
	print("================================================================================")

	var all_passed = true

	all_passed = test_quest_category() and all_passed
	all_passed = test_quantum_quest() and all_passed

	print("\n================================================================================")
	if all_passed:
		print("✅ ALL PHASE 3 TESTS PASSED")
		quit(0)
	else:
		print("❌ SOME TESTS FAILED")
		quit(1)

func test_quest_category() -> bool:
	print("\n📂 Testing QuestCategory...")

	var tests_passed = 0
	var tests_total = 0

	# Test 1: Category count
	tests_total += 1
	var all_cats = QuestCategory.get_all_categories()
	if all_cats.size() == 24:
		print("  ✓ 24 quest categories defined")
		tests_passed += 1
	else:
		print("  ✗ Expected 24 categories, got %d" % all_cats.size())

	# Test 2: Display names
	tests_total += 1
	var tutorial_name = QuestCategory.get_display_name(QuestCategory.TUTORIAL)
	if tutorial_name == "Tutorial":
		print("  ✓ Display names work")
		tests_passed += 1
	else:
		print("  ✗ Display name failed: got '%s'" % tutorial_name)

	# Test 3: Emojis
	tests_total += 1
	var daily_emoji = QuestCategory.get_emoji(QuestCategory.DAILY)
	if daily_emoji == "📅":
		print("  ✓ Category emojis work")
		tests_passed += 1
	else:
		print("  ✗ Emoji failed: got '%s'" % daily_emoji)

	# Test 4: Category types
	tests_total += 1
	var type_tutorial = QuestCategory.get_category_type(QuestCategory.TUTORIAL)
	var type_challenge = QuestCategory.get_category_type(QuestCategory.BASIC_CHALLENGE)
	if type_tutorial == "Learning" and type_challenge == "Challenge":
		print("  ✓ Category types work")
		tests_passed += 1
	else:
		print("  ✗ Category types failed: %s, %s" % [type_tutorial, type_challenge])

	# Test 5: Category properties
	tests_total += 1
	var daily_repeatable = QuestCategory.is_repeatable(QuestCategory.DAILY)
	var tutorial_is_tutorial = QuestCategory.is_tutorial(QuestCategory.TUTORIAL)
	var faction_is_faction = QuestCategory.is_faction_quest(QuestCategory.FACTION_MISSION)
	if daily_repeatable and tutorial_is_tutorial and faction_is_faction:
		print("  ✓ Category properties work")
		tests_passed += 1
	else:
		print("  ✗ Category properties failed")

	# Test 6: Difficulty ranges
	tests_total += 1
	var tutorial_range = QuestCategory.get_difficulty_range(QuestCategory.TUTORIAL)
	if tutorial_range["min"] == 0.0 and tutorial_range["max"] == 0.2:
		print("  ✓ Difficulty ranges work")
		tests_passed += 1
	else:
		print("  ✗ Difficulty range failed: %s" % str(tutorial_range))

	# Test 7: Reward multipliers
	tests_total += 1
	var expert_mult = QuestCategory.get_reward_multiplier(QuestCategory.EXPERT_CHALLENGE)
	if expert_mult == 2.5:
		print("  ✓ Reward multipliers work (expert: %.1fx)" % expert_mult)
		tests_passed += 1
	else:
		print("  ✗ Reward multiplier failed: %.1f" % expert_mult)

	var result = tests_passed == tests_total
	print("  Result: %d/%d tests passed" % [tests_passed, tests_total])
	return result

func test_quantum_quest() -> bool:
	print("\n📜 Testing QuantumQuest...")

	var tests_passed = 0
	var tests_total = 0

	# Test 1: Create simple quest
	tests_total += 1
	var theta_cond = QuantumCondition.create_theta_condition("🌾", "🐺", PI/2, 0.1)
	var achieve_obj = QuantumObjective.create_achieve_state_objective([theta_cond])
	var simple_quest = QuantumQuest.create_simple_quest(
		"test_001",
		"First Superposition",
		QuestCategory.TUTORIAL,
		achieve_obj
	)
	if simple_quest.quest_id == "test_001" and simple_quest.objectives.size() == 1:
		print("  ✓ Simple quest factory works")
		tests_passed += 1
	else:
		print("  ✗ Simple quest factory failed")

	# Test 2: Quest validation
	tests_total += 1
	if simple_quest.is_valid():
		print("  ✓ Quest validation works")
		tests_passed += 1
	else:
		print("  ✗ Quest validation failed")

	# Test 3: Difficulty calculation
	tests_total += 1
	simple_quest.calculate_difficulty()
	if simple_quest.difficulty > 0.0 and simple_quest.difficulty <= 0.2:
		print("  ✓ Difficulty calculation: %.2f" % simple_quest.difficulty)
		tests_passed += 1
	else:
		print("  ✗ Difficulty calculation failed: %.2f" % simple_quest.difficulty)

	# Test 4: Reward calculation
	tests_total += 1
	simple_quest.calculate_rewards(100)
	if simple_quest.reward_credits > 0 and simple_quest.reward_xp > 0:
		print("  ✓ Reward calculation: %d credits, %d XP" % [simple_quest.reward_credits, simple_quest.reward_xp])
		tests_passed += 1
	else:
		print("  ✗ Reward calculation failed")

	# Test 5: Quest acceptance
	tests_total += 1
	if simple_quest.accept_quest(0.0):
		print("  ✓ Quest acceptance works")
		tests_passed += 1
	else:
		print("  ✗ Quest acceptance failed")

	# Test 6: Progress tracking
	tests_total += 1
	simple_quest.update_objective_progress(0, 0.5)
	var completion = simple_quest.get_completion_percent()
	if completion == 50.0:
		print("  ✓ Progress tracking: %.0f%%" % completion)
		tests_passed += 1
	else:
		print("  ✗ Progress tracking failed: %.0f%%" % completion)

	# Test 7: Objective completion
	tests_total += 1
	simple_quest.mark_objective_complete(0)
	if simple_quest.is_complete():
		print("  ✓ Quest completion detection works")
		tests_passed += 1
	else:
		print("  ✗ Quest completion detection failed")

	# Test 8: Multi-objective quest
	tests_total += 1
	var coherence_cond = QuantumCondition.create_coherence_condition("🌾", "🐺", 0.8)
	var coherence_obj = QuantumObjective.create_achieve_state_objective([coherence_cond])
	var multi_quest = QuantumQuest.create_multi_objective_quest(
		"test_002",
		"Quantum Mastery",
		QuestCategory.BASIC_CHALLENGE,
		[achieve_obj, coherence_obj],
		true  # require all
	)
	if multi_quest.objectives.size() == 2 and multi_quest.require_all_objectives:
		print("  ✓ Multi-objective quest factory works")
		tests_passed += 1
	else:
		print("  ✗ Multi-objective quest factory failed")

	# Test 9: Full description
	tests_total += 1
	var desc = simple_quest.get_full_description()
	if "First Superposition" in desc and "Objectives:" in desc:
		print("  ✓ Quest description generation works")
		tests_passed += 1
	else:
		print("  ✗ Quest description failed")

	# Test 10: Short description
	tests_total += 1
	var short_desc = simple_quest.get_short_description()
	if "📚" in short_desc and "100%" in short_desc:
		print("  ✓ Short description: '%s'" % short_desc)
		tests_passed += 1
	else:
		print("  ✗ Short description failed: '%s'" % short_desc)

	var result = tests_passed == tests_total
	print("  Result: %d/%d tests passed" % [tests_passed, tests_total])
	return result
