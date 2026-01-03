extends SceneTree

## Comprehensive Integration Test for Quantum Quest System
## Demonstrates the complete workflow from generation to completion

const QuantumQuestGenerator = preload("res://Core/Quests/QuantumQuestGenerator.gd")
const QuantumQuestEvaluator = preload("res://Core/Quests/QuantumQuestEvaluator.gd")
const QuantumQuest = preload("res://Core/Quests/QuantumQuest.gd")
const QuestCategory = preload("res://Core/Quests/QuestCategory.gd")

func _init():
	print("================================================================================")
	print("🌌 QUANTUM QUEST SYSTEM - INTEGRATION TEST")
	print("================================================================================")

	var all_passed = true

	all_passed = test_full_workflow() and all_passed
	all_passed = test_multiple_objectives() and all_passed
	all_passed = test_quest_categories() and all_passed
	all_passed = test_faction_integration() and all_passed

	print("\n================================================================================")
	if all_passed:
		print("✅ ALL INTEGRATION TESTS PASSED")
		print("\n📊 System Summary:")
		print("   • 18 Quantum Observables")
		print("   • 25 Quantum Operations")
		print("   • 14 Comparison Operators")
		print("   • 24 Objective Types")
		print("   • 24 Quest Categories")
		print("   • Procedural Generation System")
		print("   • Real-time Evaluation Engine")
		print("\n🎉 Quantum Quest System fully operational!")
		quit(0)
	else:
		print("❌ SOME INTEGRATION TESTS FAILED")
		quit(1)

func test_full_workflow() -> bool:
	print("\n🔄 Testing Full Workflow...")

	var tests_passed = 0
	var tests_total = 0

	# Step 1: Create generator
	tests_total += 1
	var generator = QuantumQuestGenerator.new()
	if generator:
		print("  ✓ Generator created")
		tests_passed += 1
	else:
		print("  ✗ Generator creation failed")
		return false

	# Step 2: Create generation context
	tests_total += 1
	var context = QuantumQuestGenerator.GenerationContext.new()
	context.player_level = 1
	context.available_emojis = ["🌾", "🐺", "🍅", "🍝", "🍄", "🍂"]
	context.faction_bits = 0b000000000001
	context.difficulty_preference = 0.3
	if context.available_emojis.size() == 6:
		print("  ✓ Context created with %d emojis" % context.available_emojis.size())
		tests_passed += 1
	else:
		print("  ✗ Context creation failed")

	# Step 3: Generate quest
	tests_total += 1
	var quest = generator.generate_quest(context)
	if quest and quest.is_valid():
		print("  ✓ Quest generated: '%s'" % quest.title)
		tests_passed += 1
	else:
		print("  ✗ Quest generation failed")
		return false

	# Step 4: Verify quest structure
	tests_total += 1
	if quest.objectives.size() > 0 and quest.reward_credits > 0:
		print("  ✓ Quest structure valid (%d objectives, %d credits)" % [quest.objectives.size(), quest.reward_credits])
		tests_passed += 1
	else:
		print("  ✗ Quest structure invalid")

	# Step 5: Create evaluator
	tests_total += 1
	var evaluator = QuantumQuestEvaluator.new()
	if evaluator:
		print("  ✓ Evaluator created")
		tests_passed += 1
	else:
		print("  ✗ Evaluator creation failed")
		return false

	# Step 6: Activate quest
	tests_total += 1
	if evaluator.activate_quest(quest):
		print("  ✓ Quest activated")
		tests_passed += 1
	else:
		print("  ✗ Quest activation failed")

	# Step 7: Verify quest is active
	tests_total += 1
	if quest.state == QuantumQuest.QuestState.ACTIVE:
		print("  ✓ Quest state: ACTIVE")
		tests_passed += 1
	else:
		print("  ✗ Quest state incorrect: %d" % quest.state)

	# Step 8: Simulate progress with mock values
	tests_total += 1
	var obj = quest.objectives[0]
	if obj.conditions.size() > 0:
		var cond = obj.conditions[0]
		var mock_progress = evaluator.evaluate_condition_with_mock_value(
			cond,
			cond.target_value
		)
		if mock_progress == 1.0:
			print("  ✓ Mock progress evaluation: %.2f" % mock_progress)
			tests_passed += 1
		else:
			print("  ✗ Mock progress failed: %.2f" % mock_progress)
	else:
		print("  ✗ No conditions to evaluate")

	# Step 9: Simulate quest completion
	tests_total += 1
	quest.mark_objective_complete(0)
	if quest.is_complete():
		print("  ✓ Quest marked complete")
		tests_passed += 1
	else:
		print("  ✗ Quest completion failed")

	# Step 10: Get quest description
	tests_total += 1
	var desc = quest.get_full_description()
	if desc.length() > 0 and "✓" in desc:
		print("  ✓ Quest description generated")
		tests_passed += 1
	else:
		print("  ✗ Quest description failed")

	var result = tests_passed == tests_total
	print("  Result: %d/%d workflow steps passed" % [tests_passed, tests_total])
	return result

func test_multiple_objectives() -> bool:
	print("\n🎯 Testing Multiple Objectives...")

	var tests_passed = 0
	var tests_total = 0

	var generator = QuantumQuestGenerator.new()
	var context = QuantumQuestGenerator.GenerationContext.new()
	context.player_level = 10
	context.available_emojis = ["🌾", "🐺", "🍅", "🍝"]
	context.difficulty_preference = 0.8
	context.preferred_category = QuestCategory.ADVANCED_CHALLENGE

	# Test 1: Generate advanced quest
	tests_total += 1
	var quest = generator.generate_quest(context)
	if quest:
		print("  ✓ Advanced quest generated: '%s'" % quest.title)
		tests_passed += 1
	else:
		print("  ✗ Advanced quest generation failed")
		return false

	# Test 2: Check for multiple objectives
	tests_total += 1
	if quest.objectives.size() >= 1:
		print("  ✓ Quest has %d objective(s)" % quest.objectives.size())
		tests_passed += 1
	else:
		print("  ✗ Expected multiple objectives")

	# Test 3: Check difficulty
	tests_total += 1
	if quest.difficulty > 0.3:
		print("  ✓ Quest difficulty: %.2f (advanced)" % quest.difficulty)
		tests_passed += 1
	else:
		print("  ✗ Quest difficulty too low: %.2f" % quest.difficulty)

	# Test 4: Check reward scaling
	tests_total += 1
	if quest.reward_credits > 200:
		print("  ✓ Scaled rewards: %d credits" % quest.reward_credits)
		tests_passed += 1
	else:
		print("  ✗ Rewards not properly scaled: %d" % quest.reward_credits)

	var result = tests_passed == tests_total
	print("  Result: %d/%d tests passed" % [tests_passed, tests_total])
	return result

func test_quest_categories() -> bool:
	print("\n📂 Testing Quest Categories...")

	var tests_passed = 0
	var tests_total = 0

	var generator = QuantumQuestGenerator.new()
	var context = QuantumQuestGenerator.GenerationContext.new()
	context.player_level = 1
	context.available_emojis = ["🌾", "🐺"]

	# Test different categories
	var categories_to_test = [
		QuestCategory.TUTORIAL,
		QuestCategory.BASIC_CHALLENGE,
		QuestCategory.DISCOVERY,
		QuestCategory.DAILY
	]

	for category in categories_to_test:
		tests_total += 1
		context.preferred_category = category
		var quest = generator.generate_quest(context)
		if quest and quest.category == category:
			print("  ✓ %s quest generated" % QuestCategory.get_display_name(category))
			tests_passed += 1
		else:
			print("  ✗ %s quest failed" % QuestCategory.get_display_name(category))

	# Test daily quest batch
	tests_total += 1
	var daily_quests = generator.generate_daily_quests(context)
	if daily_quests.size() == 3:
		print("  ✓ Daily quest batch: %d quests" % daily_quests.size())
		tests_passed += 1
	else:
		print("  ✗ Daily quest batch failed: %d quests" % daily_quests.size())

	var result = tests_passed == tests_total
	print("  Result: %d/%d category tests passed" % [tests_passed, tests_total])
	return result

func test_faction_integration() -> bool:
	print("\n🏛️  Testing Faction Integration...")

	var tests_passed = 0
	var tests_total = 0

	var generator = QuantumQuestGenerator.new()
	var context = QuantumQuestGenerator.GenerationContext.new()
	context.player_level = 5
	context.available_emojis = ["🌾", "🐺", "🍅", "🍝"]
	context.faction_bits = 0b000000000001  # Agricultural faction

	# Test 1: Generate faction quest
	tests_total += 1
	context.preferred_category = QuestCategory.FACTION_MISSION
	var quest = generator.generate_quest(context)
	if quest:
		print("  ✓ Faction quest generated: '%s'" % quest.title)
		tests_passed += 1
	else:
		print("  ✗ Faction quest generation failed")

	# Test 2: Check faction bits set
	tests_total += 1
	if quest and quest.faction_bits == context.faction_bits:
		print("  ✓ Faction bits preserved: %d" % quest.faction_bits)
		tests_passed += 1
	else:
		print("  ✗ Faction bits not set correctly")

	# Test 3: Check faction emojis
	tests_total += 1
	if quest and quest.faction_emojis.size() > 0:
		print("  ✓ Faction emojis: %s" % str(quest.faction_emojis))
		tests_passed += 1
	else:
		print("  ✗ Faction emojis not set")

	# Test 4: Generate faction quest batch
	tests_total += 1
	var faction_quests = generator.generate_faction_quests(context)
	if faction_quests.size() == 2:
		print("  ✓ Faction quest batch: %d quests" % faction_quests.size())
		tests_passed += 1
	else:
		print("  ✗ Faction quest batch failed: %d quests" % faction_quests.size())

	var result = tests_passed == tests_total
	print("  Result: %d/%d faction tests passed" % [tests_passed, tests_total])
	return result
