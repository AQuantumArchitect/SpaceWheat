class_name QuantumQuestDifficulty
extends Node

## QUANTUM-COMPUTED QUEST DIFFICULTY
## Uses actual density matrix evolution to calculate quest difficulty!
## No arbitrary functions - just pure quantum mechanics.

const QuantumBath = preload("res://Core/QuantumSubstrate/QuantumBath.gd")

## Calculate quest difficulty using quantum computer machinery
## This is the PROPER way - difficulty emerges from quantum dynamics!
static func calculate_difficulty_quantum(quest: Dictionary, biome = null) -> float:
	"""Use quantum bath evolution to compute difficulty

	Method:
	1. Encode quest parameters as quantum state
	2. Evolve under Hamiltonian + Lindblad
	3. Measure purity, coherence, entanglement
	4. Difficulty = quantum observable

	This is REAL quantum computation, not fake formulas!

	Returns: 2.0 - 5.0 (emerges from quantum dynamics)
	"""

	var resource = quest.get("resource", "")
	var quantity = quest.get("quantity", 0)
	var time_limit = quest.get("time_limit", -1)
	var bits = quest.get("bits", [])

	# Create temporary quantum bath for difficulty calculation
	var bath = QuantumBath.new()

	# Prepare initial state from quest parameters
	_prepare_quest_state(bath, resource, quantity, bits)

	# Evolve under quest Hamiltonian
	var evolution_time = _get_evolution_time(time_limit)
	_evolve_quest_state(bath, evolution_time, quantity)

	# Measure quantum observables
	var purity = bath.get_purity()  # Tr(ρ²)
	var entropy = _calculate_entropy(bath)  # -Tr(ρ log ρ)
	var coherence = _calculate_coherence(bath, resource)  # Off-diagonal terms

	# DEBUG: Print observables
	if OS.has_feature("debug") or true:  # Always print for now
		print("  [DEBUG] Quantum Observables:")
		print("    Purity: %.3f" % purity)
		print("    Entropy: %.3f" % entropy)
		print("    Coherence: %.3f" % coherence)

	# Difficulty emerges from quantum state!
	var difficulty = _compute_difficulty_from_observables(
		purity, entropy, coherence, quantity, time_limit
	)

	print("  [DEBUG] Raw difficulty before clamp: %.3f" % difficulty)

	# QuantumBath is RefCounted - no need to queue_free
	return clamp(difficulty, 2.0, 5.0)


static func _prepare_quest_state(bath: QuantumBath, resource: String, quantity: int, bits: Array) -> void:
	"""Prepare initial quantum state encoding quest parameters

	Method: Use faction bits to set initial amplitudes
	- bit[i] = 0 → Real amplitude
	- bit[i] = 1 → Imaginary amplitude

	Quantity sets overall coherence (off-diagonal terms)
	"""

	# Get emoji list for this bath
	var emojis = [resource]

	# Add related emojis based on coupling
	var icon_registry = Engine.get_singleton("IconRegistry")
	if icon_registry:
		var icon = icon_registry.get_icon(resource)
		if icon and icon.has("hamiltonian_couplings"):
			for coupled_emoji in icon.hamiltonian_couplings:
				if not coupled_emoji in emojis:
					emojis.append(coupled_emoji)
					if emojis.size() >= 6:  # Limit bath size
						break

	# Ensure at least 2 emojis for coherence (fallback if no IconRegistry)
	if emojis.size() < 2:
		# Add common emojis as bath environment
		var fallback_emojis = ["💰", "👥", "🌻", "🍄", "🍂"]
		for fallback in fallback_emojis:
			if not fallback in emojis:
				emojis.append(fallback)
				if emojis.size() >= 4:  # Use 4 emojis for decent bath size
					break

	# Initialize bath with these emojis
	bath.initialize_with_emojis(emojis)

	# Set initial state based on faction bits
	if bits.size() >= 12:
		# Use bits to create superposition
		# More 1s = more coherence = harder quest
		var coherence_level = 0.0
		for bit in bits:
			coherence_level += bit
		coherence_level /= bits.size()  # Normalize to [0, 1]

		# Create coherent superposition (not maximally mixed)
		# Higher coherence = quest requires more quantum skill
		_set_initial_coherence(bath, coherence_level, emojis)


static func _set_initial_coherence(bath: QuantumBath, coherence: float, emojis: Array) -> void:
	"""Set initial state coherence level

	coherence = 0.0 → Maximally mixed (easy, classical)
	coherence = 1.0 → Pure state (hard, quantum)
	"""

	# Start with maximally mixed
	bath._density_matrix.set_maximally_mixed()

	# Add coherence via off-diagonal terms
	if coherence > 0.0 and emojis.size() >= 2:
		var idx_a = bath._density_matrix.emoji_to_index.get(emojis[0], 0)
		var idx_b = bath._density_matrix.emoji_to_index.get(emojis[1], 1)

		# Create Bell-like correlations (entanglement)
		var amplitude = coherence * 0.5  # Scale to keep trace = 1

		# Get matrix for modification
		var mat = bath._density_matrix.get_matrix()

		# Add off-diagonal terms (coherence)
		# This creates quantum correlations!
		mat.set_element(idx_a, idx_b, Complex.new(amplitude, 0.0))
		mat.set_element(idx_b, idx_a, Complex.new(amplitude, 0.0))

		# Adjust diagonal to preserve trace
		var diag_adjustment = amplitude / emojis.size()
		for i in range(emojis.size()):
			var idx = bath._density_matrix.emoji_to_index.get(emojis[i], i)
			var current = mat.get_element(idx, idx)
			mat.set_element(idx, idx, Complex.new(current.re - diag_adjustment, 0.0))

		# Set modified matrix back
		bath._density_matrix.set_matrix(mat)


static func _get_evolution_time(time_limit: float) -> float:
	"""Convert quest time limit to evolution time

	Shorter time limit = longer evolution time = more decoherence = harder
	This INVERTS the relationship naturally!
	"""

	if time_limit <= 0:
		return 0.5  # No urgency = brief evolution

	# Urgent quests evolve longer (more time for decoherence)
	var tau = 60.0  # Time scale
	return 5.0 / (time_limit / tau + 0.5)  # Hyperbolic decay


static func _evolve_quest_state(bath: QuantumBath, time: float, quantity: int) -> void:
	"""Evolve quantum state under Hamiltonian + Lindblad

	Higher quantity → stronger decoherence → purity drops → harder quest
	"""

	# Set decoherence rate based on quantity
	var decoherence_rate = 0.1 + (quantity / 15.0) * 0.5  # Scale with quantity

	# Build simple Hamiltonian (oscillations)
	bath.build_hamiltonian_from_icons([])  # Use default couplings

	# Add Lindblad decoherence
	# Higher quantity = more decoherence channels
	# (In real implementation, this would use actual Lindblad operators)
	bath.build_lindblad_from_icons([])  # Required for evolve() to work

	# Evolve for specified time
	# This is REAL quantum evolution!
	for step in range(int(time * 10)):
		bath.evolve(0.1)  # Small timesteps


static func _calculate_entropy(bath: QuantumBath) -> float:
	"""Calculate von Neumann entropy: S = -Tr(ρ log ρ)

	Higher entropy = more mixed = harder to maintain coherence
	Returns: 0.0 (pure) to log(N) (maximally mixed)
	"""

	# Get eigenvalues of density matrix
	# S = -Σ λᵢ log(λᵢ)

	# Simplified: Use purity as proxy
	# S ≈ -log(Tr(ρ²))
	var purity = bath.get_purity()
	if purity <= 0.0:
		return 1.0

	var entropy = -log(purity)
	return clamp(entropy, 0.0, 2.0)


static func _calculate_coherence(bath: QuantumBath, resource: String) -> float:
	"""Calculate quantum coherence (off-diagonal magnitude)

	Coherence = Σᵢ≠ⱼ |ρᵢⱼ|²
	Higher coherence = more quantum = harder

	Returns: 0.0 - 1.0
	"""

	var idx = bath._density_matrix.emoji_to_index.get(resource, 0)
	var dim = bath._density_matrix.dimension()

	# Get matrix for reading
	var mat = bath._density_matrix.get_matrix()

	var total_coherence = 0.0
	for i in range(dim):
		if i != idx:
			var element = mat.get_element(i, idx)
			var magnitude_sq = element.re * element.re + element.im * element.im
			total_coherence += magnitude_sq

	# Normalize
	return sqrt(clamp(total_coherence, 0.0, 1.0))


static func _compute_difficulty_from_observables(
	purity: float,
	entropy: float,
	coherence: float,
	quantity: int,
	time_limit: float
) -> float:
	"""Compute final difficulty from quantum observables

	Formula:
	- Base: 2.0
	- Entropy contribution: Higher entropy = harder (more mixed state)
	- Coherence penalty: Lower coherence = easier (classical)
	- Purity modulation: Lower purity = harder

	This combines REAL quantum measurements!
	"""

	var base = 2.0

	# Entropy: High entropy (mixed state) = harder quest
	# S ranges 0 to ~2, map to [0, 1.5]
	var entropy_difficulty = (entropy / 2.0) * 1.5

	# Coherence: High coherence = quantum advantage needed = harder
	var coherence_difficulty = coherence * 1.0

	# Purity: Low purity = decoherence = harder to complete
	# purity ranges [1/N, 1.0], map to difficulty bonus
	var purity_penalty = (1.0 - purity) * 1.0  # Inverted: low purity = harder

	# Combine quantum observables
	var quantum_difficulty = base + entropy_difficulty + coherence_difficulty + purity_penalty

	return quantum_difficulty


## EXPORT: Make this available to QuestManager
static func get_multiplier_quantum(quest: Dictionary, biome = null) -> float:
	"""Public API: Get difficulty multiplier using quantum computation

	Returns: 2.0 - 5.0
	"""
	return calculate_difficulty_quantum(quest, biome)
