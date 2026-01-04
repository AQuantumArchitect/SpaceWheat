# ARCHIVED - see Core/QuantumSubstrate/FactionStateMatcher.gd
# class_name FactionStateMatcher  # Disabled to avoid conflicts
extends RefCounted

## ABSTRACT QUANTUM MACHINERY
## Matches faction state-shape preferences against biome observables
## NO game-specific content - works with any QuantumBath!
##
## 12-Bit Faction Encoding (from faction classification):
##   [0]: Random(0) ↔ Deterministic(1)
##   [1]: Material(0) ↔ Mystical(1) - diagonal vs off-diagonal operators
##   [2]: Common(0) ↔ Elite(1)
##   [3]: Local(0) ↔ Cosmic(1)
##   [4]: Instant(0) ↔ Eternal(1)
##   [5]: Physical(0) ↔ Mental(1)
##   [6]: Crystalline(0) ↔ Fluid(1)
##   [7]: Direct(0) ↔ Subtle(1) - absolute vs ratio quests
##   [8]: Consumptive(0) ↔ Providing(1)
##   [9]: Monochrome(0) ↔ Prismatic(1) - single vs multi emoji
##   [10]: Emergent(0) ↔ Imposed(1) - current vs ideal target
##   [11]: Scattered(0) ↔ Focused(1) - selectivity
##
## NOTE: Bits can be float values in [0,1] for continuous preferences

# ============================================================================
# DATA CLASSES
# ============================================================================

class BiomeObservables:
	"""Abstract quantum observables from any bath"""
	var purity: float = 0.5       # Tr(rho^2) in [1/N, 1]
	var entropy: float = 0.5      # Normalized to [0, 1]
	var coherence: float = 0.0    # Sum of |rho_ij|^2 for i!=j, in [0, 1]
	var distribution_shape: int = 2  # 0=peaked, 1=bimodal, 2=spread, 3=uniform
	var scale: float = 0.5        # Total probability mass (activity level)
	var dynamics: float = 0.5     # Evolution rate (how fast state changes)


class QuestParameters:
	"""Abstract quest parameters - game applies theming"""
	var alignment: float = 0.5    # How well matched [0, 1]
	var intensity: float = 0.5    # Derived from scale preferences
	var complexity: float = 0.5   # Derived from entropy x coherence
	var urgency: float = 0.0      # Derived from dynamics preference
	var variety: float = 0.5      # Derived from distribution shape
	var basis_weights: Array = [] # Probability weights for each basis state


# ============================================================================
# CORE MACHINERY
# ============================================================================

static func extract_observables(bath, biome = null) -> BiomeObservables:
	"""Extract abstract observables from ANY QuantumBath

	Args:
		bath: QuantumBath instance
		biome: Optional biome reference for dynamics tracking
	"""
	var obs = BiomeObservables.new()

	if bath == null:
		return obs

	if not bath.has_method("get_purity"):
		return obs

	var density_matrix = bath.get("_density_matrix")
	if density_matrix == null:
		return obs

	# Purity: Tr(rho^2)
	obs.purity = bath.get_purity()

	# Entropy: -log(purity) normalized to [0, 1]
	var dim = density_matrix.dimension()
	var max_entropy = log(dim) if dim > 1 else 1.0
	if obs.purity > 0 and max_entropy > 0:
		obs.entropy = clamp(-log(obs.purity) / max_entropy, 0.0, 1.0)

	# Coherence: sum of off-diagonal magnitudes squared
	obs.coherence = _calculate_coherence(density_matrix)

	# Distribution shape: analyze probability distribution
	obs.distribution_shape = _classify_distribution(density_matrix)

	# Scale: total "active" probability mass
	obs.scale = _calculate_scale(density_matrix)

	# Dynamics: use tracker if available, else fallback
	if biome and biome.has("dynamics_tracker") and biome.dynamics_tracker:
		obs.dynamics = biome.dynamics_tracker.get_dynamics()
	else:
		obs.dynamics = 0.5  # Fallback for neutral dynamics

	return obs


static func compute_alignment(faction_bits: Array, obs: BiomeObservables) -> float:
	"""Core alignment computation - NO game-specific content!

	faction_bits[0-1]: purity preference
	faction_bits[2-3]: entropy preference
	faction_bits[4-5]: coherence preference
	faction_bits[6-7]: distribution shape preference
	faction_bits[8-9]: scale preference
	faction_bits[10-11]: dynamics preference

	Uses HYBRID approach: weighted average of individual matches
	This gives better gameplay values (0.2-0.9) instead of tiny products (0.001-0.01)
	"""
	if faction_bits.size() < 12:
		return 0.5  # Neutral alignment if not enough bits

	var total_score = 0.0
	var total_weight = 0.0

	# Purity alignment (bits 0-1) - WEIGHT: 2.0 (most important)
	var purity_pref = _bits_to_range(faction_bits[0], faction_bits[1])
	var purity_match = _gaussian_match(purity_pref, obs.purity, 0.4)
	total_score += purity_match * 2.0
	total_weight += 2.0

	# Entropy alignment (bits 2-3) - WEIGHT: 2.0 (most important)
	var entropy_pref = _bits_to_range(faction_bits[2], faction_bits[3])
	var entropy_match = _gaussian_match(entropy_pref, obs.entropy, 0.4)
	total_score += entropy_match * 2.0
	total_weight += 2.0

	# Coherence alignment (bits 4-5) - WEIGHT: 1.5
	var coherence_pref = _bits_to_range(faction_bits[4], faction_bits[5])
	var coherence_match = _gaussian_match(coherence_pref, obs.coherence, 0.4)
	total_score += coherence_match * 1.5
	total_weight += 1.5

	# Distribution shape alignment (bits 6-7) - WEIGHT: 1.0
	var shape_pref = faction_bits[6] * 2 + faction_bits[7]
	var shape_match = 1.0 if shape_pref == obs.distribution_shape else 0.3
	total_score += shape_match * 1.0
	total_weight += 1.0

	# Scale alignment (bits 8-9) - WEIGHT: 1.0
	var scale_pref = _bits_to_range(faction_bits[8], faction_bits[9])
	var scale_match = _gaussian_match(scale_pref, obs.scale, 0.4)
	total_score += scale_match * 1.0
	total_weight += 1.0

	# Dynamics alignment (bits 10-11) - WEIGHT: 0.5 (least important, often 0.5)
	var dynamics_pref = _bits_to_range(faction_bits[10], faction_bits[11])
	var dynamics_match = _gaussian_match(dynamics_pref, obs.dynamics, 0.4)
	total_score += dynamics_match * 0.5
	total_weight += 0.5

	# Weighted average: gives values in [0, 1] range
	return total_score / total_weight


static func generate_quest_parameters(faction_bits: Array, obs: BiomeObservables, bath) -> QuestParameters:
	"""Generate abstract quest parameters from faction x biome"""
	var params = QuestParameters.new()

	# Core alignment
	params.alignment = compute_alignment(faction_bits, obs)

	# Intensity: scale preference x biome scale
	var scale_pref = _bits_to_range(faction_bits[8], faction_bits[9]) if faction_bits.size() >= 10 else 0.5
	params.intensity = scale_pref * obs.scale

	# Complexity: entropy x coherence (high of both = complex)
	params.complexity = obs.entropy * 0.5 + obs.coherence * 0.5

	# Urgency: from dynamics preference
	var dynamics_pref = _bits_to_range(faction_bits[10], faction_bits[11]) if faction_bits.size() >= 12 else 0.5
	params.urgency = dynamics_pref * obs.dynamics

	# Variety: from distribution shape
	params.variety = float(obs.distribution_shape) / 3.0

	# Basis weights: probability distribution from bath
	params.basis_weights = _get_basis_weights(bath)

	return params


static func sample_basis_index(params: QuestParameters) -> int:
	"""Sample from probability distribution - returns INDEX (not game content!)"""
	if params.basis_weights.is_empty():
		return 0

	var roll = randf()
	var cumulative = 0.0

	for i in range(params.basis_weights.size()):
		cumulative += params.basis_weights[i]
		if roll <= cumulative:
			return i

	return params.basis_weights.size() - 1


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

static func _bits_to_range(bit0: int, bit1: int) -> float:
	"""Convert 2 bits to [0, 1] range: 00->0.125, 01->0.375, 10->0.625, 11->0.875"""
	var value = bit0 * 2 + bit1  # 0, 1, 2, or 3
	return (value + 0.5) / 4.0


static func _gaussian_match(preference: float, actual: float, sigma: float = 0.3) -> float:
	"""Gaussian similarity: high when preference ~= actual"""
	var diff = preference - actual
	return exp(-(diff * diff) / (2.0 * sigma * sigma))


static func _calculate_coherence(density_matrix) -> float:
	"""Calculate total off-diagonal magnitude squared"""
	if density_matrix == null:
		return 0.0

	var dim = density_matrix.dimension()
	if dim < 2:
		return 0.0

	var mat = density_matrix.get_matrix()
	if mat == null:
		return 0.0

	var total = 0.0

	for i in range(dim):
		for j in range(dim):
			if i != j:
				var element = mat.get_element(i, j)
				if element:
					total += element.re * element.re + element.im * element.im

	# Normalize by maximum possible coherence
	var max_coherence = float(dim * (dim - 1))
	return clamp(total / max_coherence, 0.0, 1.0) if max_coherence > 0 else 0.0


static func _classify_distribution(density_matrix) -> int:
	"""Classify probability distribution shape: 0=peaked, 1=bimodal, 2=spread, 3=uniform"""
	if density_matrix == null:
		return 2

	var probs = []
	var dim = density_matrix.dimension()

	for i in range(dim):
		probs.append(density_matrix.get_probability_by_index(i))

	probs.sort()
	probs.reverse()  # Descending order

	if probs.is_empty():
		return 2

	var max_prob = probs[0]
	var second_prob = probs[1] if probs.size() > 1 else 0.0
	var variance = _calculate_variance(probs)

	# Classification logic
	if max_prob > 0.7:
		return 0  # Peaked: one dominant state
	elif max_prob > 0.4 and second_prob > 0.3:
		return 1  # Bimodal: two dominant states
	elif variance < 0.01:
		return 3  # Uniform: all states equal
	else:
		return 2  # Spread: multiple active states


static func _calculate_variance(probs: Array) -> float:
	"""Calculate variance of probability distribution"""
	if probs.is_empty():
		return 0.0

	var mean = 1.0 / probs.size()
	var variance = 0.0

	for p in probs:
		var diff = p - mean
		variance += diff * diff

	return variance / probs.size()


static func _calculate_scale(density_matrix) -> float:
	"""Calculate total 'active' probability mass"""
	if density_matrix == null:
		return 0.5

	# Sum probabilities above threshold
	var active_mass = 0.0
	var dim = density_matrix.dimension()
	var threshold = 0.05

	for i in range(dim):
		var prob = density_matrix.get_probability_by_index(i)
		if prob > threshold:
			active_mass += prob

	return clamp(active_mass, 0.0, 1.0)


static func _get_basis_weights(bath) -> Array:
	"""Get probability weights for all basis states"""
	var weights = []

	if bath == null:
		return [1.0]  # Single uniform weight

	var density_matrix = bath.get("_density_matrix")
	if density_matrix == null:
		return [1.0]

	var dim = density_matrix.dimension()
	var total = 0.0

	for i in range(dim):
		var prob = density_matrix.get_probability_by_index(i)
		weights.append(prob)
		total += prob

	# Renormalize
	if total > 0:
		for i in range(weights.size()):
			weights[i] /= total

	return weights


# ============================================================================
# DEBUG / UTILITY
# ============================================================================

static func describe_preferences(faction_bits: Array) -> String:
	"""Human-readable description of faction preferences from bits"""
	if faction_bits.size() < 12:
		return "insufficient bits"

	var parts = []

	# Purity
	var purity_val = faction_bits[0] * 2 + faction_bits[1]
	var purity_names = ["chaos", "disorder", "order", "pure"]
	parts.append("purity: " + purity_names[purity_val])

	# Entropy
	var entropy_val = faction_bits[2] * 2 + faction_bits[3]
	var entropy_names = ["focused", "moderate", "diffuse", "uniform"]
	parts.append("entropy: " + entropy_names[entropy_val])

	# Coherence
	var coherence_val = faction_bits[4] * 2 + faction_bits[5]
	var coherence_names = ["classical", "slight-quantum", "quantum", "entangled"]
	parts.append("coherence: " + coherence_names[coherence_val])

	# Distribution
	var dist_val = faction_bits[6] * 2 + faction_bits[7]
	var dist_names = ["peaked", "bimodal", "spread", "uniform"]
	parts.append("distribution: " + dist_names[dist_val])

	# Scale
	var scale_val = faction_bits[8] * 2 + faction_bits[9]
	var scale_names = ["small", "medium", "large", "massive"]
	parts.append("scale: " + scale_names[scale_val])

	# Dynamics
	var dyn_val = faction_bits[10] * 2 + faction_bits[11]
	var dyn_names = ["stable", "moderate", "active", "volatile"]
	parts.append("dynamics: " + dyn_names[dyn_val])

	return ", ".join(parts)


static func describe_observables(obs: BiomeObservables) -> String:
	"""Human-readable description of biome observables"""
	var parts = []
	parts.append("purity: %.2f" % obs.purity)
	parts.append("entropy: %.2f" % obs.entropy)
	parts.append("coherence: %.2f" % obs.coherence)

	var shape_names = ["peaked", "bimodal", "spread", "uniform"]
	parts.append("shape: " + shape_names[obs.distribution_shape])

	parts.append("scale: %.2f" % obs.scale)
	parts.append("dynamics: %.2f" % obs.dynamics)

	return ", ".join(parts)


# ============================================================================
# QUANTUM-NATIVE MEASUREMENT OPERATORS (for amplitude quests)
# ============================================================================

static func calculate_operator_weights(faction_bits: Array) -> Dictionary:
	"""Calculate continuous weights for different operator types

	Accepts int or float values in [0,1] - prepares for future continuous distributions!

	Returns:
		Dictionary with probability weights for quest structures
	"""

	# Convert to floats (works with int 0/1 or float values)
	var material_mystical = float(faction_bits[1]) if faction_bits.size() > 1 else 0.0  # diagonal vs off-diagonal
	var direct_subtle = float(faction_bits[7]) if faction_bits.size() > 7 else 0.0
	var mono_prismatic = float(faction_bits[9]) if faction_bits.size() > 9 else 0.0
	var emergent_imposed = float(faction_bits[10]) if faction_bits.size() > 10 else 0.0
	var scattered_focused = float(faction_bits[11]) if faction_bits.size() > 11 else 0.0

	# Calculate weights via continuous combinations (NO if/then!)
	# Material(0) × Direct(0) × Monochrome(0) → amplitude quest (diagonal, absolute, single)
	var w_amplitude = (1.0 - material_mystical) * (1.0 - direct_subtle) * (1.0 - mono_prismatic)

	# Mystical(1) × Direct(0) × Monochrome(0) → coherence quest (off-diagonal, absolute, single)
	var w_coherence = material_mystical * (1.0 - direct_subtle) * (1.0 - mono_prismatic)

	# Subtle(1) × Monochrome(0) → ratio quest (relative, single pair)
	var w_ratio = direct_subtle * (1.0 - mono_prismatic)

	# Prismatic(1) × Direct(0) → multi-observable quest (absolute, multiple)
	var w_multi = mono_prismatic * (1.0 - direct_subtle)

	# Normalize to probability distribution
	var total = w_amplitude + w_coherence + w_ratio + w_multi

	if total > 0.001:
		return {
			"amplitude": w_amplitude / total,
			"coherence": w_coherence / total,
			"ratio": w_ratio / total,
			"multi": w_multi / total,
			"selectivity": scattered_focused,
			"target_mode": emergent_imposed,
		}

	# Fallback: uniform distribution
	return {
		"amplitude": 0.25,
		"coherence": 0.25,
		"ratio": 0.25,
		"multi": 0.25,
		"selectivity": 0.5,
		"target_mode": 0.5,
	}


static func sample_operator_structure(weights: Dictionary) -> String:
	"""Sample quest structure from probability distribution (Born rule)

	This is the ONLY stochastic step - sampling from continuous probabilities
	"""

	var roll = randf()
	var cumulative = 0.0

	# Cumulative probability sampling
	cumulative += weights.get("amplitude", 0.0)
	if roll < cumulative:
		return "amplitude"

	cumulative += weights.get("coherence", 0.0)
	if roll < cumulative:
		return "coherence"

	cumulative += weights.get("ratio", 0.0)
	if roll < cumulative:
		return "ratio"

	return "multi"


static func generate_measurement_operator(structure: String, weights: Dictionary, bath) -> Dictionary:
	"""Generate measurement operator M̂ based on sampled structure

	Returns operator specification (weights, not discrete quest type!)
	"""

	match structure:
		"amplitude":
			return _generate_amplitude_operator(bath, weights.get("selectivity", 0.5))
		"coherence":
			return _generate_coherence_operator(bath, weights.get("selectivity", 0.5))
		"ratio":
			return _generate_ratio_operator(bath, weights.get("selectivity", 0.5))
		"multi":
			return _generate_multi_operator(bath, weights)
		_:
			return _generate_amplitude_operator(bath, 0.5)


static func _generate_amplitude_operator(bath, selectivity: float) -> Dictionary:
	"""Generate diagonal operator: M̂ = Σᵢ wᵢ |i⟩⟨i|

	Args:
		selectivity ∈ [0,1]:
			0.0 = scattered (uniform weights)
			1.0 = focused (peaked on dominant emoji)

	Returns continuous operator weights (ready for float bits!)
	"""

	if bath == null or bath._density_matrix == null:
		return {"type": "amplitude", "weights": [1.0], "dominant_index": 0}

	var dim = bath._density_matrix.dimension()
	var weights = []

	# Get current probabilities from bath
	for i in range(dim):
		weights.append(bath._density_matrix.get_probability_by_index(i))

	# Apply selectivity via power law (SMOOTH function, not if/then!)
	# selectivity = 0.0 → exponent = 1.0 (uniform)
	# selectivity = 1.0 → exponent = 4.0 (very peaked)
	var exponent = 1.0 + selectivity * 3.0

	for i in range(weights.size()):
		weights[i] = pow(weights[i], exponent)

	# Normalize
	var total = 0.0
	for w in weights:
		total += w

	if total > 0:
		for i in range(weights.size()):
			weights[i] /= total

	# Find dominant emoji index (for human description)
	var max_idx = 0
	var max_weight = weights[0]
	for i in range(1, weights.size()):
		if weights[i] > max_weight:
			max_weight = weights[i]
			max_idx = i

	return {
		"type": "amplitude",
		"weights": weights,
		"dominant_index": max_idx,
		"dominant_weight": max_weight,
	}


static func _generate_coherence_operator(bath, selectivity: float) -> Dictionary:
	"""Generate off-diagonal operator: M̂ = Σᵢ≠ⱼ wᵢⱼ |i⟩⟨j|

	Returns coherence weights for off-diagonal elements
	"""

	if bath == null or bath._density_matrix == null:
		return {"type": "coherence", "total_coherence": 0.0}

	var dim = bath._density_matrix.dimension()
	var coherences = []
	var pairs = []

	# Extract off-diagonal magnitudes |ρ_ij|
	for i in range(dim):
		for j in range(i + 1, dim):
			var element = bath._density_matrix.get_matrix().get_element(i, j)
			var magnitude = sqrt(element.re * element.re + element.im * element.im)
			coherences.append(magnitude)
			pairs.append([i, j])

	# Apply selectivity
	var exponent = 1.0 + selectivity * 2.0
	for i in range(coherences.size()):
		coherences[i] = pow(coherences[i], exponent)

	# Normalize
	var total = 0.0
	for c in coherences:
		total += c

	if total > 0:
		for i in range(coherences.size()):
			coherences[i] /= total

	# Find dominant pair
	var max_idx = 0
	var max_coherence = coherences[0] if coherences.size() > 0 else 0.0
	for i in range(1, coherences.size()):
		if coherences[i] > max_coherence:
			max_coherence = coherences[i]
			max_idx = i

	var dominant_pair = pairs[max_idx] if pairs.size() > max_idx else [0, 1]

	return {
		"type": "coherence",
		"coherences": coherences,
		"pairs": pairs,
		"dominant_pair": dominant_pair,
		"total_coherence": total,
	}


static func _generate_ratio_operator(bath, selectivity: float) -> Dictionary:
	"""Generate ratio operator: Tr(M̂_A ρ) / Tr(M̂_B ρ) = target_ratio

	Picks two emojis to compare based on selectivity
	"""

	if bath == null or bath._density_matrix == null:
		return {"type": "ratio", "emoji_A_index": 0, "emoji_B_index": 1}

	var dim = bath._density_matrix.dimension()

	# Get probabilities
	var probs = []
	for i in range(dim):
		probs.append(bath._density_matrix.get_probability_by_index(i))

	# Apply selectivity sharpening
	var exponent = 1.0 + selectivity * 3.0
	var sharpened = []
	for p in probs:
		sharpened.append(pow(p, exponent))

	# Normalize
	var total = 0.0
	for s in sharpened:
		total += s
	if total > 0:
		for i in range(sharpened.size()):
			sharpened[i] /= total

	# Pick top 2 emojis for ratio
	var sorted_indices = range(dim)
	sorted_indices.sort_custom(func(a, b): return sharpened[a] > sharpened[b])

	var emoji_A_index = sorted_indices[0] if sorted_indices.size() > 0 else 0
	var emoji_B_index = sorted_indices[1] if sorted_indices.size() > 1 else 0

	# Calculate current ratio
	var current_ratio = 1.0
	if probs[emoji_B_index] > 0.001:
		current_ratio = probs[emoji_A_index] / probs[emoji_B_index]

	return {
		"type": "ratio",
		"emoji_A_index": emoji_A_index,
		"emoji_B_index": emoji_B_index,
		"current_ratio": current_ratio,
	}


static func _generate_multi_operator(bath, weights: Dictionary) -> Dictionary:
	"""Generate multi-observable operator (combination)

	Combines multiple observables based on prismatic preference
	"""

	# For now, combine amplitude and coherence
	var amp_op = _generate_amplitude_operator(bath, weights.get("selectivity", 0.5))
	var coh_op = _generate_coherence_operator(bath, weights.get("selectivity", 0.5))

	return {
		"type": "multi",
		"amplitude_component": amp_op,
		"coherence_component": coh_op,
		"weight_amplitude": 0.5,
		"weight_coherence": 0.5,
	}
