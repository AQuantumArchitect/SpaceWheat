extends SceneTree

## Test Phase 4: Quest Generation

const QuantumQuestVocabulary = preload("res://Core/Quests/QuantumQuestVocabulary.gd")
const QuantumQuestGenerator = preload("res://Core/Quests/QuantumQuestGenerator.gd")
const QuestCategory = preload("res://Core/Quests/QuestCategory.gd")
const QuantumObservable = preload("res://Core/Quests/QuantumObservable.gd")
const QuantumOperation = preload("res://Core/Quests/QuantumOperation.gd")

func _init():
	print("================================================================================")
	print("🧪 QUANTUM QUEST SYSTEM - PHASE 4 TESTS")
	print("================================================================================")

	var all_passed = true

	all_passed = test_vocabulary() and all_passed
	all_passed = test_generator() and all_passed

	print("\n================================================================================")
	if all_passed:
		print("✅ ALL PHASE 4 TESTS PASSED")
		quit(0)
	else:
		print("❌ SOME TESTS FAILED")
		quit(1)

func test_vocabulary() -> bool:
	print("\n📖 Testing QuantumQuestVocabulary...")

	var tests_passed = 0
	var tests_total = 0

	# Test 1: Title generation
	tests_total += 1
	var title = QuantumQuestVocabulary.generate_title(
		"🌾",
		QuantumObservable.COHERENCE,
		QuestCategory.TUTORIAL
	)
	if not title.is_empty() and "🌾" in title:
		print("  ✓ Title generation: '%s'" % title)
		tests_passed += 1
	else:
		print("  ✗ Title generation failed: '%s'" % title)

	# Test 2: Description generation
	tests_total += 1
	var desc = QuantumQuestVocabulary.generate_description(
		"🌾",
		QuantumObservable.COHERENCE,
		QuantumOperation.HADAMARD,
		QuestCategory.TUTORIAL
	)
	if not desc.is_empty():
		print("  ✓ Description generation works")
		tests_passed += 1
	else:
		print("  ✗ Description generation failed")

	# Test 3: Observable phrases
	tests_total += 1
	var coherence_phrase = QuantumQuestVocabulary.get_observable_phrase(QuantumObservable.COHERENCE)
	if not coherence_phrase.is_empty():
		print("  ✓ Observable phrase: '%s'" % coherence_phrase)
		tests_passed += 1
	else:
		print("  ✗ Observable phrase failed")

	# Test 4: Operation phrases
	tests_total += 1
	var hadamard_phrase = QuantumQuestVocabulary.get_operation_phrase(QuantumOperation.HADAMARD)
	if not hadamard_phrase.is_empty():
		print("  ✓ Operation phrase: '%s'" % hadamard_phrase)
		tests_passed += 1
	else:
		print("  ✗ Operation phrase failed")

	# Test 5: Random components
	tests_total += 1
	var adj = QuantumQuestVocabulary.get_random_adjective()
	var noun = QuantumQuestVocabulary.get_random_noun()
	var verb = QuantumQuestVocabulary.get_random_verb()
	if not adj.is_empty() and not noun.is_empty() and not verb.is_empty():
		print("  ✓ Random components: %s %s %s" % [adj, noun, verb])
		tests_passed += 1
	else:
		print("  ✗ Random components failed")

	var result = tests_passed == tests_total
	print("  Result: %d/%d tests passed" % [tests_passed, tests_total])
	return result

func test_generator() -> bool:
	print("\n🎲 Testing QuantumQuestGenerator...")

	var tests_passed = 0
	var tests_total = 0

	var generator = QuantumQuestGenerator.new()

	# Create generation context
	var context = QuantumQuestGenerator.GenerationContext.new()
	context.player_level = 1
	context.available_emojis = ["🌾", "🐺", "🍅", "🍝"]
	context.faction_bits = 0b000000000001
	context.difficulty_preference = 0.3

	# Test 1: Single quest generation
	tests_total += 1
	var quest = generator.generate_quest(context)
	if quest and quest.is_valid():
		print("  ✓ Quest generation: '%s'" % quest.title)
		tests_passed += 1
	else:
		print("  ✗ Quest generation failed")

	# Test 2: Quest has objectives
	tests_total += 1
	if quest and quest.objectives.size() > 0:
		print("  ✓ Quest has %d objective(s)" % quest.objectives.size())
		tests_passed += 1
	else:
		print("  ✗ Quest objectives missing")

	# Test 3: Quest has rewards
	tests_total += 1
	if quest and quest.reward_credits > 0:
		print("  ✓ Quest rewards: %d credits, %d XP" % [quest.reward_credits, quest.reward_xp])
		tests_passed += 1
	else:
		print("  ✗ Quest rewards missing")

	# Test 4: Quest difficulty calculated
	tests_total += 1
	if quest and quest.difficulty > 0.0:
		print("  ✓ Quest difficulty: %.2f" % quest.difficulty)
		tests_passed += 1
	else:
		print("  ✗ Quest difficulty not calculated")

	# Test 5: Quest description
	tests_total += 1
	if quest and not quest.description.is_empty():
		print("  ✓ Quest has description")
		tests_passed += 1
	else:
		print("  ✗ Quest description missing")

	# Test 6: Batch generation
	tests_total += 1
	var batch = generator.generate_quest_batch(context, 3)
	if batch.size() == 3:
		print("  ✓ Batch generation: %d quests" % batch.size())
		tests_passed += 1
	else:
		print("  ✗ Batch generation failed: got %d quests" % batch.size())

	# Test 7: Daily quests
	tests_total += 1
	var daily = generator.generate_daily_quests(context)
	if daily.size() == 3:
		print("  ✓ Daily quest generation: %d quests" % daily.size())
		tests_passed += 1
	else:
		print("  ✗ Daily quest generation failed: got %d quests" % daily.size())

	# Test 8: High level quest
	tests_total += 1
	context.player_level = 10
	context.difficulty_preference = 0.8
	var hard_quest = generator.generate_quest(context)
	if hard_quest and hard_quest.difficulty > 0.3:
		print("  ✓ High-level quest difficulty: %.2f" % hard_quest.difficulty)
		tests_passed += 1
	else:
		print("  ✗ High-level quest difficulty too low: %.2f" % (hard_quest.difficulty if hard_quest else 0.0))

	var result = tests_passed == tests_total
	print("  Result: %d/%d tests passed" % [tests_passed, tests_total])
	return result
