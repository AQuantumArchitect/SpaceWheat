#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test all 5 quest types work correctly
## Verifies generation, tracking, and auto-completion

const QuestManager = preload("res://Core/Quests/QuestManager.gd")
const QuestTheming = preload("res://Core/Quests/QuestTheming.gd")
const QuestTypes = preload("res://Core/Quests/QuestTypes.gd")
const FactionStateMatcher = preload("res://Core/QuantumSubstrate/FactionStateMatcher.gd")
const QuantumBath = preload("res://Core/QuantumSubstrate/QuantumBath.gd")
const BiomeDynamicsTracker = preload("res://Core/QuantumSubstrate/BiomeDynamicsTracker.gd")

func _init():
	print("\n" + "=".repeat(80))
	print("📦🎯⏱️🌀🔗 QUEST TYPE VARIETY TEST")
	print("=".repeat(80))

	# Test 1: Quest type generation
	print("\n📋 Test 1: Quest Type Generation")
	test_quest_type_generation()

	# Test 2: DELIVERY quest (existing system)
	print("\n📦 Test 2: DELIVERY Quest (resource-based)")
	test_delivery_quest()

	# Test 3: SHAPE_ACHIEVE quest
	print("\n🎯 Test 3: SHAPE_ACHIEVE Quest (reach target once)")
	test_shape_achieve_quest()

	# Test 4: SHAPE_MAINTAIN quest
	print("\n⏱️  Test 4: SHAPE_MAINTAIN Quest (hold for duration)")
	test_shape_maintain_quest()

	# Test 5: EVOLUTION quest
	print("\n🌀 Test 5: EVOLUTION Quest (change by delta)")
	test_evolution_quest()

	# Test 6: ENTANGLEMENT quest
	print("\n🔗 Test 6: ENTANGLEMENT Quest (create coherence)")
	test_entanglement_quest()

	print("\n" + "=".repeat(80))
	print("✅ ALL QUEST TYPE TESTS COMPLETE")
	print("=".repeat(80) + "\n")

	quit(0)


func test_quest_type_generation():
	"""Verify quest type selection based on complexity"""

	# Create mock bath
	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "🍄", "💨"])

	# Test low complexity → mostly DELIVERY
	print("\n  Low complexity (0.2) → should generate mostly DELIVERY:")
	var delivery_count = 0
	for i in range(10):
		var params = FactionStateMatcher.QuestParameters.new()
		params.complexity = 0.2
		params.alignment = 0.5
		params.intensity = 0.5

		var quest = QuestTheming.apply_theming(params, bath)
		var quest_type = quest.get("type", -1)
		if quest_type == QuestTypes.Type.DELIVERY:
			delivery_count += 1

	print("    Generated %d/10 DELIVERY quests (expect ~8/10)" % delivery_count)
	if delivery_count >= 6:
		print("    ✅ Low complexity favors DELIVERY")
	else:
		print("    ⚠️  Unexpected distribution")

	# Test high complexity → advanced types
	print("\n  High complexity (0.8) → should generate SHAPE_MAINTAIN/EVOLUTION:")
	var advanced_count = 0
	for i in range(10):
		var params = FactionStateMatcher.QuestParameters.new()
		params.complexity = 0.8
		params.alignment = 0.5
		params.intensity = 0.5

		var quest = QuestTheming.apply_theming(params, bath)
		var quest_type = quest.get("type", -1)
		if quest_type in [QuestTypes.Type.SHAPE_MAINTAIN, QuestTypes.Type.EVOLUTION]:
			advanced_count += 1

	print("    Generated %d/10 advanced quests (expect ~10/10)" % advanced_count)
	if advanced_count >= 8:
		print("    ✅ High complexity favors advanced quests")
	else:
		print("    ⚠️  Unexpected distribution")


func test_delivery_quest():
	"""Test DELIVERY quest (existing resource-based system)"""

	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "🍄", "💨"])

	var params = FactionStateMatcher.QuestParameters.new()
	params.complexity = 0.1  # Force DELIVERY
	params.intensity = 0.6
	params.alignment = 0.7
	params.urgency = 0.3
	params.basis_weights = [0.5, 0.3, 0.2]

	var quest = QuestTheming.apply_theming(params, bath)

	print("  Quest type: %s" % QuestTypes.get_type_name(quest.get("type")))
	print("  Resource: %s" % quest.get("resource"))
	print("  Quantity: %d" % quest.get("quantity"))
	print("  Time limit: %s" % ("none" if quest.get("time_limit") < 0 else "%ds" % int(quest.get("time_limit"))))
	print("  Reward multiplier: %.2fx" % quest.get("reward_multiplier"))

	if quest.get("type") == QuestTypes.Type.DELIVERY:
		print("  ✅ DELIVERY quest generated correctly")
	else:
		print("  ⚠️  Expected DELIVERY, got %s" % QuestTypes.get_type_name(quest.get("type")))


func test_shape_achieve_quest():
	"""Test SHAPE_ACHIEVE quest tracking"""

	# Create quest manager with mock biome
	var manager = MockQuestManager.new()
	var mock_biome = _create_mock_biome_with_observables(0.5, 0.5, 0.2)
	manager.connect_to_biome(mock_biome)

	# Create SHAPE_ACHIEVE quest: reach purity > 0.8
	var quest = {
		"id": 0,
		"type": QuestTypes.Type.SHAPE_ACHIEVE,
		"observable": "purity",
		"target": 0.8,
		"reward_multiplier": 3.0,
		"status": "active"
	}

	manager.active_quests[0] = quest

	print("  Quest: Achieve purity > 0.8")
	print("  Initial purity: 0.5")

	# Update with purity below target
	manager._update_shape_achieve_quest(quest, 0.1)
	if manager.active_quests.has(0):
		print("  After update (purity=0.5): Still active ✓")
	else:
		print("  ⚠️  Quest completed too early")

	# Manually raise purity in mock
	_set_mock_observable(mock_biome, "purity", 0.85)
	manager._update_shape_achieve_quest(quest, 0.1)

	if not manager.active_quests.has(0):
		print("  After update (purity=0.85): Auto-completed ✅")
	else:
		print("  ⚠️  Quest didn't auto-complete at target")


func test_shape_maintain_quest():
	"""Test SHAPE_MAINTAIN quest tracking"""

	var manager = MockQuestManager.new()
	var mock_biome = _create_mock_biome_with_observables(0.7, 0.3, 0.2)
	manager.connect_to_biome(mock_biome)

	# Create SHAPE_MAINTAIN quest: hold entropy < 0.4 for 5 seconds
	var quest = {
		"id": 1,
		"type": QuestTypes.Type.SHAPE_MAINTAIN,
		"observable": "entropy",
		"target": 0.4,
		"comparison": "<",  # entropy wants LOW values
		"duration": 5.0,
		"elapsed": 0.0,
		"reward_multiplier": 4.0,
		"status": "active"
	}

	manager.active_quests[1] = quest

	print("  Quest: Maintain entropy < 0.4 for 5s")
	print("  Initial entropy: 0.3 (below target ✓)")

	# Simulate 3 seconds of maintaining
	for i in range(30):
		manager._update_shape_maintain_quest(quest, 0.1)  # 30 × 0.1s = 3s

	print("  After 3s at target: elapsed = %.1fs (still active)" % quest.get("elapsed", 0.0))

	# Simulate 3 more seconds (total 6s, exceeds 5s requirement)
	for i in range(30):
		manager._update_shape_maintain_quest(quest, 0.1)

	if not manager.active_quests.has(1):
		print("  After 6s total: Auto-completed ✅")
	else:
		print("  ⚠️  Quest didn't complete after duration")


func test_evolution_quest():
	"""Test EVOLUTION quest tracking"""

	var manager = MockQuestManager.new()
	var mock_biome = _create_mock_biome_with_observables(0.5, 0.5, 0.2)
	manager.connect_to_biome(mock_biome)

	# Create EVOLUTION quest: increase coherence by 0.3
	var quest = {
		"id": 2,
		"type": QuestTypes.Type.EVOLUTION,
		"observable": "coherence",
		"delta": 0.3,
		"direction": "increase",
		"initial_value": null,
		"reward_multiplier": 4.5,
		"status": "active"
	}

	manager.active_quests[2] = quest

	print("  Quest: Increase coherence by 0.3")

	# First update: capture initial value
	manager._update_evolution_quest(quest, 0.1)
	print("  Initial coherence: %.2f (captured)" % quest.get("initial_value", 0.0))

	# Increase coherence
	_set_mock_observable(mock_biome, "coherence", 0.55)  # +0.35 from initial 0.2
	manager._update_evolution_quest(quest, 0.1)

	if not manager.active_quests.has(2):
		print("  After +0.35 change: Auto-completed ✅")
	else:
		print("  ⚠️  Quest didn't complete after exceeding delta")


func test_entanglement_quest():
	"""Test ENTANGLEMENT quest tracking"""

	var manager = MockQuestManager.new()
	var mock_biome = _create_mock_biome_with_observables(0.5, 0.5, 0.1)  # Low initial coherence
	manager.connect_to_biome(mock_biome)

	# Create ENTANGLEMENT quest: create coherence > 0.6
	var quest = {
		"id": 3,
		"type": QuestTypes.Type.ENTANGLEMENT,
		"target_coherence": 0.6,
		"reward_multiplier": 5.0,
		"status": "active"
	}

	manager.active_quests[3] = quest

	print("  Quest: Create coherence > 0.6")
	print("  Initial coherence: 0.1")

	# Update with low coherence
	manager._update_entanglement_quest(quest, 0.1)
	if manager.active_quests.has(3):
		print("  After update (coherence=0.1): Still active ✓")

	# Increase coherence above target
	_set_mock_observable(mock_biome, "coherence", 0.65)
	manager._update_entanglement_quest(quest, 0.1)

	if not manager.active_quests.has(3):
		print("  After coherence=0.65: Auto-completed ✅")
	else:
		print("  ⚠️  Quest didn't auto-complete at target")


# =============================================================================
# MOCK HELPERS
# =============================================================================

class MockBiome extends Node:
	"""Mock biome that returns controlled observable values"""
	var _observables := {"purity": 0.5, "entropy": 0.5, "coherence": 0.0}
	var bath = null

	func set_observable(key: String, value: float):
		_observables[key] = value

	func get_observable(key: String) -> float:
		return _observables.get(key, 0.0)


class MockQuestManager extends QuestManager:
	"""QuestManager subclass that uses mock observables"""

	func get_biome_observables(biome) -> Dictionary:
		"""Override to return mock values instead of calling FactionStateMatcher"""
		if biome is MockBiome:
			return biome._observables
		# Fallback to parent implementation
		return super.get_biome_observables(biome)


func _create_mock_biome_with_observables(purity: float, entropy: float, coherence: float) -> Node:
	"""Create mock biome with controllable observables"""
	var mock = MockBiome.new()
	mock._observables = {
		"purity": purity,
		"entropy": entropy,
		"coherence": coherence,
		"distribution_shape": 2,
		"scale": 0.5,
		"dynamics": 0.5,
		"description": "Mock observables"
	}

	# Create minimal bath
	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "🍄", "💨"])
	mock.bath = bath

	return mock


func _set_mock_observable(mock_biome: Node, key: String, value: float):
	"""Update observable value in mock biome"""
	if mock_biome is MockBiome:
		mock_biome._observables[key] = value
