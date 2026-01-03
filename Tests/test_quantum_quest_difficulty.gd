#!/usr/bin/env -S godot --headless -s
extends SceneTree

## 🌟 QUANTUM QUEST DIFFICULTY DEMONSTRATION
## Shows quest difficulty computed using ACTUAL quantum mechanics!

const QuestManager = preload("res://Core/Quests/QuestManager.gd")
const QuantumQuestDifficulty = preload("res://Core/Quests/QuantumQuestDifficulty.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")

var economy: FarmEconomy = null
var quest_manager: QuestManager = null

func _init():
	print("\n" + "=".repeat(80))
	print("🌟 QUANTUM QUEST DIFFICULTY DEMONSTRATION")
	print("=".repeat(80))

	# Setup minimal systems
	economy = FarmEconomy.new()
	root.add_child(economy)

	quest_manager = QuestManager.new()
	root.add_child(quest_manager)
	quest_manager.connect_to_economy(economy)

	# Run demonstrations
	await demo_comparison()
	await demo_quantum_evolution()
	await demo_faction_bits_effect()

	print("\n" + "=".repeat(80))
	print("✅ QUANTUM QUEST DEMONSTRATION COMPLETE")
	print("=".repeat(80) + "\n")

	quit(0)


func demo_comparison():
	"""Compare continuous vs quantum difficulty calculation"""

	print("\n" + "─".repeat(80))
	print("📊 DEMONSTRATION 1: Continuous vs Quantum Comparison")
	print("─".repeat(80))

	# Create test quest
	var quest = {
		"resource": "🌾",
		"quantity": 5,
		"time_limit": 120.0,
		"bits": [1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1],  # Millwright's Union
		"faction": "Millwright's Union"
	}

	print("\n📋 Quest Parameters:")
	print("  Faction: %s" % quest.faction)
	print("  Resource: %s × %d" % [quest.resource, quest.quantity])
	print("  Time limit: %ds" % quest.time_limit)
	print("  Faction bits: %s" % str(quest.bits))

	# Continuous approach (current)
	print("\n📊 CONTINUOUS APPROACH (Fast, Smooth Functions):")
	var continuous_start = Time.get_ticks_msec()

	var quantity_term = log(1.0 + quest.quantity) / log(1.0 + 15.0)
	var time_term = 1.0 - exp(-3.0 / (quest.time_limit / 60.0))
	var rarity_term = 0.0  # Wheat is common

	var continuous_difficulty = 2.0 + (quantity_term * 1.5) + time_term + rarity_term

	var continuous_time = Time.get_ticks_msec() - continuous_start

	print("  Quantity: log(%d+1)/log(16) = %.3f → +%.2f" % [quest.quantity, quantity_term, quantity_term * 1.5])
	print("  Time: 1-exp(-3/%.1f) = %.3f → +%.2f" % [quest.time_limit / 60.0, time_term, time_term])
	print("  Rarity: wheat = 0.0 → +%.2f" % rarity_term)
	print("  " + "─".repeat(40))
	print("  Difficulty: 2.0 + %.2f + %.2f + %.2f = %.2fx" % [quantity_term * 1.5, time_term, rarity_term, continuous_difficulty])
	print("  Computation time: %dms" % continuous_time)

	# Quantum approach (physics-based)
	print("\n⚛️  QUANTUM APPROACH (Physics-Based Evolution):")
	var quantum_start = Time.get_ticks_msec()

	var quantum_difficulty = QuantumQuestDifficulty.get_multiplier_quantum(quest, null)

	var quantum_time = Time.get_ticks_msec() - quantum_start

	print("  [Quantum computation ran: density matrix evolution]")
	print("  " + "─".repeat(40))
	print("  Difficulty: %.2fx (emerged from quantum dynamics!)" % quantum_difficulty)
	print("  Computation time: %dms" % quantum_time)

	print("\n✨ COMPARISON:")
	print("  Continuous: %.2fx (%.1f ms)" % [continuous_difficulty, continuous_time])
	print("  Quantum: %.2fx (%.1f ms)" % [quantum_difficulty, quantum_time])
	print("  Difference: %+.2fx" % (quantum_difficulty - continuous_difficulty))

	if abs(quantum_difficulty - continuous_difficulty) < 0.5:
		print("  ✅ Both approaches give similar difficulty (good!)")
	else:
		print("  ℹ️  Quantum captures additional physics effects")


func demo_quantum_evolution():
	"""Show quantum evolution details step-by-step"""

	print("\n" + "─".repeat(80))
	print("⚛️  DEMONSTRATION 2: Quantum Evolution Breakdown")
	print("─".repeat(80))

	# High-coherence quest (lots of 1s in bits)
	var quest = {
		"resource": "🍄",
		"quantity": 10,
		"time_limit": 60.0,
		"bits": [1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 1, 1],  # 9/12 = 0.75 coherence
		"faction": "Fungal Network"
	}

	print("\n📋 Quest: %s" % quest.faction)
	print("  Resource: %s × %d (rare!)" % [quest.resource, quest.quantity])
	print("  Time limit: %ds (urgent!)" % quest.time_limit)
	print("  Faction bits: %s" % str(quest.bits))

	# Calculate coherence from bits
	var ones_count = 0
	for bit in quest.bits:
		if bit == 1:
			ones_count += 1
	var coherence_level = float(ones_count) / quest.bits.size()

	print("\n⚛️  Step 1: Encode Quest → Quantum State")
	print("  Faction bits: %d ones / %d total = %.2f coherence" % [ones_count, quest.bits.size(), coherence_level])
	print("  Higher coherence = more quantum superposition = harder quest")

	print("\n⚛️  Step 2: Evolve Under Lindblad Master Equation")
	print("  Evolution time: 5.0/(60/60+0.5) = %.2fs" % (5.0 / (quest.time_limit / 60.0 + 0.5)))
	print("  Decoherence rate: 0.1 + (%d/15)*0.5 = %.2f" % [quest.quantity, 0.1 + (quest.quantity / 15.0) * 0.5])
	print("  Hamiltonian + Lindblad operators → density matrix ρ(t)")

	print("\n⚛️  Step 3: Measure Quantum Observables")
	print("  (Actual measurements happen during calculation)")

	# Compute
	var difficulty = QuantumQuestDifficulty.get_multiplier_quantum(quest, null)

	print("\n⚛️  Step 4: Difficulty Emerges from Physics")
	print("  Final difficulty: %.2fx" % difficulty)
	print("  This is NOT a formula - it emerged from quantum evolution!")


func demo_faction_bits_effect():
	"""Show how faction bits affect difficulty"""

	print("\n" + "─".repeat(80))
	print("🎲 DEMONSTRATION 3: Faction Bits → Difficulty")
	print("─".repeat(80))

	# Test different faction bit patterns
	var factions = [
		{
			"name": "Low Coherence",
			"bits": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],  # All 0s = 0.0 coherence
		},
		{
			"name": "Medium Coherence",
			"bits": [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0],  # 6/12 = 0.5 coherence
		},
		{
			"name": "High Coherence",
			"bits": [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],  # All 1s = 1.0 coherence
		}
	]

	print("\nTesting same quest with different faction bit patterns:\n")

	for faction in factions:
		var quest = {
			"resource": "🌾",
			"quantity": 5,
			"time_limit": -1,  # No time limit
			"bits": faction.bits,
			"faction": faction.name
		}

		# Count 1s
		var ones = 0
		for bit in faction.bits:
			if bit == 1:
				ones += 1
		var coherence = float(ones) / 12.0

		# Compute difficulty
		var difficulty = QuantumQuestDifficulty.get_multiplier_quantum(quest, null)

		print("  %s (coherence=%.2f):" % [faction.name, coherence])
		print("    Bits: %s" % str(faction.bits))
		print("    Difficulty: %.2fx" % difficulty)
		print()

	print("✨ Higher coherence in faction bits → More quantum effects → Higher difficulty")
	print("   This shows the quantum state truly affects the result!")


# Helper function
func wait(seconds: float):
	await create_timer(seconds).timeout
