class_name QuantumOracle
extends RefCounted

## Quantum RNG Oracle
## Uses quantum measurement from density matrices for weighted random selection
##
## Features:
## - Weighted sampling from options
## - Repeat-until-sorted ordering
## - Uses existing quantum computer (no temp allocation)
## - Fallback to classical RNG if quantum unavailable

static func sample_weighted(options: Array, biome = null) -> Variant:
	"""Sample one option using quantum measurement.

	Args:
		options: Array of {value: Variant, weight: float}
		biome: Optional biome to use for quantum measurement

	Returns:
		Sampled option value, or null if options empty

	Example:
		var options = [
			{"value": "🌾", "weight": 0.5},
			{"value": "🌱", "weight": 0.3},
			{"value": "🍂", "weight": 0.2}
		]
		var result = QuantumOracle.sample_weighted(options, current_biome)
		# Returns: "🌾" with 50% probability (via quantum measurement)
	"""
	if options.is_empty():
		return null

	# Normalize weights
	var total_weight = 0.0
	for opt in options:
		total_weight += opt.get("weight", 0.0)

	if total_weight <= 0:
		return options[randi() % options.size()].get("value")  # Fallback uniform

	# Use quantum measurement if biome available
	if biome and biome.quantum_computer:
		return _quantum_sample(options, total_weight, biome.quantum_computer)
	else:
		return _classical_sample(options, total_weight)


static func _quantum_sample(options: Array, total_weight: float, qc: QuantumComputer) -> Variant:
	"""Use quantum measurement for weighted sampling.

	Strategy:
	1. Map option weights to cumulative probability
	2. Get population from quantum computer for random emoji
	3. Use population as random float ∈ [0, 1]
	4. Select option based on cumulative threshold
	"""
	# Build cumulative distribution
	var cumulative = []
	var running_sum = 0.0
	for opt in options:
		running_sum += opt.get("weight", 0.0) / total_weight
		cumulative.append({"value": opt.get("value"), "threshold": running_sum})

	# Get quantum random float
	var quantum_random = _get_quantum_random(qc)

	# Select option based on threshold
	for entry in cumulative:
		if quantum_random <= entry.get("threshold", 1.0):
			return entry.get("value")

	# Fallback (shouldn't reach)
	return options[-1].get("value")


static func _get_quantum_random(qc: QuantumComputer) -> float:
	"""Extract random float from quantum computer via population query.

	Uses: get_population() on first registered emoji in quantum computer.
	This gives us a float ∈ [0, 1] based on current quantum state.
	"""
	var all_pops = qc.get_all_populations()
	if all_pops.is_empty():
		return randf()  # Fallback if no emojis

	# Use first emoji's population as random source
	var first_emoji = all_pops.keys()[0]
	var population = all_pops[first_emoji]

	# Population is ∈ [0, 1], perfect for random selection
	return population


static func _classical_sample(options: Array, total_weight: float) -> Variant:
	"""Fallback classical weighted random sampling."""
	var rand = randf() * total_weight
	var cumulative = 0.0

	for opt in options:
		cumulative += opt.get("weight", 0.0)
		if rand <= cumulative:
			return opt.get("value")

	return options[-1].get("value")


static func sample_ordered(options: Array, biome = null) -> Array:
	"""Sample all options in weighted order (measurement with removal).

	Algorithm:
	1. Measure to get one option
	2. Remove that option from pool
	3. Repeat until all sampled
	4. Returns ordered array based on measurement sequence

	Example:
		var options = [
			{"value": "explore", "weight": 0.5},
			{"value": "measure", "weight": 0.3},
			{"value": "pop", "weight": 0.2}
		]
		var ordered = QuantumOracle.sample_ordered(options, biome)
		# Returns: ["explore", "measure", "pop"] (probabilistic order)
	"""
	var remaining = options.duplicate(true)
	var result = []

	while not remaining.is_empty():
		var sampled = sample_weighted(remaining, biome)
		result.append(sampled)

		# Remove sampled option
		for i in range(remaining.size()):
			if remaining[i].get("value") == sampled:
				remaining.remove_at(i)
				break

	return result


static func sample_multiple(options: Array, count: int, biome = null, allow_duplicates: bool = false) -> Array:
	"""Sample multiple options using quantum measurement.

	Args:
		options: Array of {value: Variant, weight: float}
		count: Number of samples to take
		biome: Optional biome for quantum measurement
		allow_duplicates: If false, uses sampling without replacement

	Returns:
		Array of sampled values
	"""
	if allow_duplicates:
		var results = []
		for i in range(count):
			results.append(sample_weighted(options, biome))
		return results
	else:
		# Use ordered sampling (no replacement)
		var ordered = sample_ordered(options, biome)
		return ordered.slice(0, min(count, ordered.size()))
