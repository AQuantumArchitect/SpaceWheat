extends SceneTree

## Test Phase 1: Core Quantum Types

const QuantumObservable = preload("res://Core/Quests/QuantumObservable.gd")
const QuantumOperation = preload("res://Core/Quests/QuantumOperation.gd")
const ComparisonOp = preload("res://Core/Quests/ComparisonOp.gd")
const QuantumCondition = preload("res://Core/Quests/QuantumCondition.gd")

func _init():
	print("================================================================================")
	print("🧪 QUANTUM QUEST SYSTEM - PHASE 1 TESTS")
	print("================================================================================")

	var all_passed = true

	all_passed = test_quantum_observable() and all_passed
	all_passed = test_quantum_operation() and all_passed
	all_passed = test_comparison_op() and all_passed
	all_passed = test_quantum_condition() and all_passed

	print("\n================================================================================")
	if all_passed:
		print("✅ ALL PHASE 1 TESTS PASSED")
		quit(0)
	else:
		print("❌ SOME TESTS FAILED")
		quit(1)

func test_quantum_observable() -> bool:
	print("\n⚛️  Testing QuantumObservable...")

	var tests_passed = 0
	var tests_total = 0

	# Test 1: Observable count
	tests_total += 1
	var all_obs = QuantumObservable.get_all_observables()
	if all_obs.size() == 18:
		print("  ✓ 18 quantum observables defined")
		tests_passed += 1
	else:
		print("  ✗ Expected 18 observables, got %d" % all_obs.size())

	# Test 2: Display names
	tests_total += 1
	var theta_name = QuantumObservable.get_display_name(QuantumObservable.THETA)
	if theta_name == "polar angle θ":
		print("  ✓ Display names work")
		tests_passed += 1
	else:
		print("  ✗ Display name failed: got '%s'" % theta_name)

	# Test 3: Emojis
	tests_total += 1
	var coherence_emoji = QuantumObservable.get_emoji(QuantumObservable.COHERENCE)
	if coherence_emoji == "🌊":
		print("  ✓ Observable emojis work")
		tests_passed += 1
	else:
		print("  ✗ Emoji failed: got '%s'" % coherence_emoji)

	# Test 4: Category checks
	tests_total += 1
	var theta_is_single = QuantumObservable.is_single_qubit(QuantumObservable.THETA)
	var amp_is_bath = QuantumObservable.is_bath_wide(QuantumObservable.AMPLITUDE)
	var ent_is_multi = QuantumObservable.is_multi_qubit(QuantumObservable.ENTANGLEMENT)
	if theta_is_single and amp_is_bath and ent_is_multi:
		print("  ✓ Observable categories work")
		tests_passed += 1
	else:
		print("  ✗ Category checks failed")

	# Test 5: Typical ranges
	tests_total += 1
	var theta_range = QuantumObservable.get_typical_range(QuantumObservable.THETA)
	if theta_range["min"] == 0.0 and abs(theta_range["max"] - PI) < 0.01:
		print("  ✓ Typical ranges work (θ: 0 to π)")
		tests_passed += 1
	else:
		print("  ✗ Range failed: %s" % str(theta_range))

	var result = tests_passed == tests_total
	print("  Result: %d/%d tests passed" % [tests_passed, tests_total])
	return result

func test_quantum_operation() -> bool:
	print("\n🔧 Testing QuantumOperation...")

	var tests_passed = 0
	var tests_total = 0

	# Test 1: Operation count
	tests_total += 1
	var all_ops = QuantumOperation.get_all_operations()
	if all_ops.size() == 25:
		print("  ✓ 25 quantum operations defined")
		tests_passed += 1
	else:
		print("  ✗ Expected 25 operations, got %d" % all_ops.size())

	# Test 2: Display names
	tests_total += 1
	var bell_name = QuantumOperation.get_display_name(QuantumOperation.BELL_ENTANGLE)
	if bell_name == "Bell Entanglement":
		print("  ✓ Operation display names work")
		tests_passed += 1
	else:
		print("  ✗ Display name failed: got '%s'" % bell_name)

	# Test 3: Operation emojis
	tests_total += 1
	var measure_emoji = QuantumOperation.get_emoji(QuantumOperation.STRONG_MEASURE)
	if measure_emoji == "💥":
		print("  ✓ Operation emojis work")
		tests_passed += 1
	else:
		print("  ✗ Emoji failed: got '%s'" % measure_emoji)

	# Test 4: Categories
	tests_total += 1
	var cat_proj = QuantumOperation.get_category(QuantumOperation.CREATE_PROJECTION)
	var cat_unitary = QuantumOperation.get_category(QuantumOperation.HADAMARD)
	if cat_proj == "Projection" and cat_unitary == "Unitary":
		print("  ✓ Operation categories work")
		tests_passed += 1
	else:
		print("  ✗ Categories failed: %s, %s" % [cat_proj, cat_unitary])

	# Test 5: Requirements
	tests_total += 1
	var hadamard_needs_proj = QuantumOperation.requires_projection(QuantumOperation.HADAMARD)
	var bell_needs_two = QuantumOperation.requires_two_projections(QuantumOperation.BELL_ENTANGLE)
	if hadamard_needs_proj and bell_needs_two:
		print("  ✓ Operation requirements work")
		tests_passed += 1
	else:
		print("  ✗ Requirements failed")

	var result = tests_passed == tests_total
	print("  Result: %d/%d tests passed" % [tests_passed, tests_total])
	return result

func test_comparison_op() -> bool:
	print("\n📊 Testing ComparisonOp...")

	var tests_passed = 0
	var tests_total = 0

	# Test 1: Comparison count
	tests_total += 1
	var all_comps = ComparisonOp.get_all_comparisons()
	if all_comps.size() == 14:
		print("  ✓ 14 comparison operators defined")
		tests_passed += 1
	else:
		print("  ✗ Expected 14 comparisons, got %d" % all_comps.size())

	# Test 2: Display names
	tests_total += 1
	var approx_name = ComparisonOp.get_display_name(ComparisonOp.APPROX)
	if approx_name == "approximately":
		print("  ✓ Comparison display names work")
		tests_passed += 1
	else:
		print("  ✗ Display name failed: got '%s'" % approx_name)

	# Test 3: Evaluation - EQUALS
	tests_total += 1
	var eq_true = ComparisonOp.evaluate(1.0, 1.05, 0.1, ComparisonOp.EQUALS)
	var eq_false = ComparisonOp.evaluate(1.0, 1.5, 0.1, ComparisonOp.EQUALS)
	if eq_true and not eq_false:
		print("  ✓ EQUALS comparison works")
		tests_passed += 1
	else:
		print("  ✗ EQUALS failed: %s, %s" % [eq_true, eq_false])

	# Test 4: Evaluation - IN_RANGE
	tests_total += 1
	var range_true = ComparisonOp.evaluate(1.0, 1.05, 0.1, ComparisonOp.IN_RANGE)
	var range_false = ComparisonOp.evaluate(1.0, 1.5, 0.1, ComparisonOp.IN_RANGE)
	if range_true and not range_false:
		print("  ✓ IN_RANGE comparison works")
		tests_passed += 1
	else:
		print("  ✗ IN_RANGE failed")

	# Test 5: Progress calculation
	tests_total += 1
	var progress_close = ComparisonOp.get_progress(0.9, 1.0, 0.1, ComparisonOp.IN_RANGE)
	var progress_far = ComparisonOp.get_progress(0.5, 1.0, 0.1, ComparisonOp.IN_RANGE)
	if progress_close > 0.8 and progress_far < 0.2:
		print("  ✓ Progress calculation works (%.2f, %.2f)" % [progress_close, progress_far])
		tests_passed += 1
	else:
		print("  ✗ Progress failed: %.2f, %.2f" % [progress_close, progress_far])

	var result = tests_passed == tests_total
	print("  Result: %d/%d tests passed" % [tests_passed, tests_total])
	return result

func test_quantum_condition() -> bool:
	print("\n🎯 Testing QuantumCondition...")

	var tests_passed = 0
	var tests_total = 0

	# Test 1: Factory method - theta condition
	tests_total += 1
	var theta_cond = QuantumCondition.create_theta_condition("🌾", "🐺", PI/2, 0.1)
	if theta_cond.observable == QuantumObservable.THETA and theta_cond.emoji_pair == ["🌾", "🐺"]:
		print("  ✓ Theta condition factory works")
		tests_passed += 1
	else:
		print("  ✗ Theta condition failed")

	# Test 2: Description
	tests_total += 1
	var desc = theta_cond.describe()
	if "polar angle θ" in desc and "🌾" in desc:
		print("  ✓ Condition description: '%s'" % desc)
		tests_passed += 1
	else:
		print("  ✗ Description failed: '%s'" % desc)

	# Test 3: Factory method - coherence condition
	tests_total += 1
	var coherence_cond = QuantumCondition.create_coherence_condition("🌾", "🐺", 0.8)
	if coherence_cond.observable == QuantumObservable.COHERENCE:
		print("  ✓ Coherence condition factory works")
		tests_passed += 1
	else:
		print("  ✗ Coherence condition failed")

	# Test 4: Factory method - amplitude condition
	tests_total += 1
	var amp_cond = QuantumCondition.create_amplitude_condition("🌾", 0.7, 0.1)
	if amp_cond.emoji_target == "🌾" and amp_cond.target_value == 0.7:
		print("  ✓ Amplitude condition factory works")
		tests_passed += 1
	else:
		print("  ✗ Amplitude condition failed")

	# Test 5: Validation
	tests_total += 1
	if theta_cond.is_valid():
		print("  ✓ Condition validation works")
		tests_passed += 1
	else:
		print("  ✗ Validation failed")

	# Test 6: Short description
	tests_total += 1
	var short_desc = theta_cond.describe_short()
	if "θ" in short_desc:
		print("  ✓ Short description: '%s'" % short_desc)
		tests_passed += 1
	else:
		print("  ✗ Short description failed: '%s'" % short_desc)

	var result = tests_passed == tests_total
	print("  Result: %d/%d tests passed" % [tests_passed, tests_total])
	return result
