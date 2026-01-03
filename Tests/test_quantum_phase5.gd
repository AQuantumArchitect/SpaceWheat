extends SceneTree

## Test Phase 5: Quest Evaluation

const QuantumQuestEvaluator = preload("res://Core/Quests/QuantumQuestEvaluator.gd")
const QuantumQuest = preload("res://Core/Quests/QuantumQuest.gd")
const QuantumObjective = preload("res://Core/Quests/QuantumObjective.gd")
const QuantumCondition = preload("res://Core/Quests/QuantumCondition.gd")
const QuestCategory = preload("res://Core/Quests/QuestCategory.gd")

func _init():
	print("================================================================================")
	print("🧪 QUANTUM QUEST SYSTEM - PHASE 5 TESTS")
	print("================================================================================")

	var all_passed = true

	all_passed = test_evaluator() and all_passed

	print("\n================================================================================")
	if all_passed:
		print("✅ ALL PHASE 5 TESTS PASSED")
		quit(0)
	else:
		print("❌ SOME TESTS FAILED")
		quit(1)

func test_evaluator() -> bool:
	print("\n⚖️  Testing QuantumQuestEvaluator...")

	var tests_passed = 0
	var tests_total = 0

	var evaluator = QuantumQuestEvaluator.new()

	# Test 1: Condition evaluation with mock value - satisfied
	tests_total += 1
	var theta_cond = QuantumCondition.create_theta_condition("🌾", "🐺", PI/2, 0.1)
	var progress_satisfied = evaluator.evaluate_condition_with_mock_value(theta_cond, PI/2)
	if progress_satisfied == 1.0:
		print("  ✓ Condition evaluation (satisfied): %.2f" % progress_satisfied)
		tests_passed += 1
	else:
		print("  ✗ Condition evaluation failed: %.2f" % progress_satisfied)

	# Test 2: Condition evaluation with mock value - partial progress
	tests_total += 1
	var progress_partial = evaluator.evaluate_condition_with_mock_value(theta_cond, PI/2 + 0.2)
	if progress_partial > 0.5 and progress_partial < 1.0:
		print("  ✓ Partial progress: %.2f" % progress_partial)
		tests_passed += 1
	else:
		print("  ✗ Partial progress failed: %.2f" % progress_partial)

	# Test 3: Condition evaluation with mock value - far from target
	tests_total += 1
	var progress_far = evaluator.evaluate_condition_with_mock_value(theta_cond, 0.0)
	if progress_far < 0.5:
		print("  ✓ Far from target: %.2f" % progress_far)
		tests_passed += 1
	else:
		print("  ✗ Far from target failed: %.2f" % progress_far)

	# Test 4: Quest activation
	tests_total += 1
	var achieve_obj = QuantumObjective.create_achieve_state_objective([theta_cond])
	var quest = QuantumQuest.create_simple_quest(
		"test_eval_001",
		"Test Quest",
		QuestCategory.TUTORIAL,
		achieve_obj
	)
	if evaluator.activate_quest(quest):
		print("  ✓ Quest activation works")
		tests_passed += 1
	else:
		print("  ✗ Quest activation failed")

	# Test 5: Quest is in active list
	tests_total += 1
	if evaluator.active_quests.has("test_eval_001"):
		print("  ✓ Quest added to active list")
		tests_passed += 1
	else:
		print("  ✗ Quest not in active list")

	# Test 6: Quest deactivation
	tests_total += 1
	evaluator.deactivate_quest("test_eval_001")
	if not evaluator.active_quests.has("test_eval_001"):
		print("  ✓ Quest deactivation works")
		tests_passed += 1
	else:
		print("  ✗ Quest still in active list")

	# Test 7: Coherence condition evaluation
	tests_total += 1
	var coherence_cond = QuantumCondition.create_coherence_condition("🌾", "🐺", 0.8)
	var coherence_progress = evaluator.evaluate_condition_with_mock_value(coherence_cond, 0.85)
	if coherence_progress == 1.0:
		print("  ✓ Coherence condition satisfied")
		tests_passed += 1
	else:
		print("  ✗ Coherence condition failed: %.2f" % coherence_progress)

	# Test 8: Amplitude condition evaluation
	tests_total += 1
	var amp_cond = QuantumCondition.create_amplitude_condition("🌾", 0.7, 0.1)
	var amp_progress = evaluator.evaluate_condition_with_mock_value(amp_cond, 0.72)
	if amp_progress == 1.0:
		print("  ✓ Amplitude condition satisfied")
		tests_passed += 1
	else:
		print("  ✗ Amplitude condition failed: %.2f" % amp_progress)

	# Test 9: Entanglement condition (using mock - will return 0 without real projection)
	tests_total += 1
	var ent_cond = QuantumCondition.create_entanglement_condition(
		["🌾", "🐺"], ["🍅", "🍝"], 0.8
	)
	# Entanglement condition with mock value of 0.85
	var ent_progress = evaluator.evaluate_condition_with_mock_value(ent_cond, 0.85)
	if ent_progress == 1.0:
		print("  ✓ Entanglement condition satisfied")
		tests_passed += 1
	else:
		print("  ✗ Entanglement condition failed: %.2f" % ent_progress)

	# Test 10: Berry phase condition
	tests_total += 1
	var berry_cond = QuantumCondition.create_berry_phase_condition("🌾", "🐺", PI, 0.2)
	var berry_progress = evaluator.evaluate_condition_with_mock_value(berry_cond, PI + 0.1)
	if berry_progress == 1.0:
		print("  ✓ Berry phase condition satisfied")
		tests_passed += 1
	else:
		print("  ✗ Berry phase condition failed: %.2f" % berry_progress)

	var result = tests_passed == tests_total
	print("  Result: %d/%d tests passed" % [tests_passed, tests_total])
	return result
