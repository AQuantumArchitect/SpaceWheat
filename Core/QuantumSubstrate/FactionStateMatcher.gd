class_name FactionStateMatcher
extends RefCounted

## ABSTRACT QUANTUM MACHINERY
## Matches faction state-shape preferences against biome observables
## NO game-specific content - works with any QuantumComputer-backed substrate.
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
	# Abstract quantum observables from any register substrate
	var purity: float = -1.0       # Tr(rho^2) in [1/N, 1]
	var entropy: float = -1.0      # Normalized to [0, 1]
	var coherence: float = -1.0    # Sum of |rho_ij|^2 for i!=j, in [0, 1]
	var distribution_shape: int = -1  # 0=peaked, 1=bimodal, 2=spread, 3=uniform
	var scale: float = -1.0        # Total probability mass (activity level)
	var dynamics: float = -1.0     # Evolution rate (how fast state changes)


class QuestParameters:
	# Abstract quest parameters - game applies theming
	var alignment: float = -1.0    # How well matched [0, 1], -1 = unknown
	var intensity: float = -1.0    # Derived from scale preferences
	var complexity: float = -1.0   # Derived from entropy x coherence
	var urgency: float = -1.0      # Derived from dynamics preference
	var variety: float = -1.0      # Derived from distribution shape
	var basis_weights: Array = [] # Probability weights for each basis state
	var available_emojis: Array = []  # Signature constraint (faction ∩ player)
	var operator_weights: Dictionary = {}  # Quest type distribution from faction bits (Born rule sampling)


# ============================================================================
# CORE MACHINERY
# ============================================================================

static func extract_observables(substrate, biome = null) -> BiomeObservables:
	# Extract abstract observables from a biome or QuantumComputer.

	# Args:
	# substrate: BiomeBase, QuantumComputer, or density wrapper
	# biome: Optional biome reference for dynamics tracking
	var obs = BiomeObservables.new()
	var state_source = _resolve_state_source(substrate, biome)
	var density_matrix = _resolve_density_matrix(state_source)

	if state_source == null or density_matrix == null:
		return obs

	obs.purity = _get_purity(state_source, density_matrix)

	# Entropy: -log(purity) normalized to [0, 1]
	var dim = _density_dim(density_matrix)
	var max_entropy = log(dim) if dim > 1 else 1.0
	if obs.purity > 0 and max_entropy > 0:
		obs.entropy = clamp(-log(obs.purity) / max_entropy, 0.0, 1.0)
	else:
		obs.entropy = -1.0

	# Coherence: sum of off-diagonal magnitudes squared
	obs.coherence = _calculate_coherence(density_matrix)

	# Distribution shape: analyze probability distribution
	obs.distribution_shape = _classify_distribution(density_matrix)

	# Scale: total "active" probability mass
	obs.scale = _calculate_scale(density_matrix)

	# Dynamics: use tracker if available, else fallback
	if biome and "dynamics_tracker" in biome and biome.dynamics_tracker:
		obs.dynamics = biome.dynamics_tracker.get_dynamics()
	else:
		obs.dynamics = -1.0

	return obs


static func compute_alignment(faction_bits: Array, obs: BiomeObservables) -> float:
	# Core alignment computation - NO game-specific content!

	# faction_bits[0-1]: purity preference
	# faction_bits[2-3]: entropy preference
	# faction_bits[4-5]: coherence preference
	# faction_bits[6-7]: distribution shape preference
	# faction_bits[8-9]: scale preference
	# faction_bits[10-11]: dynamics preference

	# Uses HYBRID approach: weighted average of individual matches
	# This gives better gameplay values (0.2-0.9) instead of tiny products (0.001-0.01)
	if faction_bits.size() < 12:
		return -1.0  # Not enough preference data to score honestly

	var total_score = 0.0
	var total_weight = 0.0

	# Purity alignment (bits 0-1) - WEIGHT: 2.0 (most important)
	var purity_pref = _bits_to_range(faction_bits[0], faction_bits[1])
	if _is_known_observable(obs.purity):
		var purity_match = _gaussian_match(purity_pref, obs.purity, 0.4)
		total_score += purity_match * 2.0
		total_weight += 2.0

	# Entropy alignment (bits 2-3) - WEIGHT: 2.0 (most important)
	var entropy_pref = _bits_to_range(faction_bits[2], faction_bits[3])
	if _is_known_observable(obs.entropy):
		var entropy_match = _gaussian_match(entropy_pref, obs.entropy, 0.4)
		total_score += entropy_match * 2.0
		total_weight += 2.0

	# Coherence alignment (bits 4-5) - WEIGHT: 1.5
	var coherence_pref = _bits_to_range(faction_bits[4], faction_bits[5])
	if _is_known_observable(obs.coherence):
		var coherence_match = _gaussian_match(coherence_pref, obs.coherence, 0.4)
		total_score += coherence_match * 1.5
		total_weight += 1.5

	# Distribution shape alignment (bits 6-7) - WEIGHT: 1.0
	var shape_pref = faction_bits[6] * 2 + faction_bits[7]
	if obs.distribution_shape >= 0:
		var shape_match = 1.0 if shape_pref == obs.distribution_shape else 0.3
		total_score += shape_match * 1.0
		total_weight += 1.0

	# Scale alignment (bits 8-9) - WEIGHT: 1.0
	var scale_pref = _bits_to_range(faction_bits[8], faction_bits[9])
	if _is_known_observable(obs.scale):
		var scale_match = _gaussian_match(scale_pref, obs.scale, 0.4)
		total_score += scale_match * 1.0
		total_weight += 1.0

	# Dynamics alignment (bits 10-11) - WEIGHT: 0.5 (least important, often 0.5)
	var dynamics_pref = _bits_to_range(faction_bits[10], faction_bits[11])
	if _is_known_observable(obs.dynamics):
		var dynamics_match = _gaussian_match(dynamics_pref, obs.dynamics, 0.4)
		total_score += dynamics_match * 0.5
		total_weight += 0.5

	# Weighted average: gives values in [0, 1] range
	return total_score / total_weight if total_weight > 0.0 else -1.0


static func generate_quest_parameters(faction_bits: Array, obs: BiomeObservables, substrate) -> QuestParameters:
	# Generate abstract quest parameters from faction x biome
	var params = QuestParameters.new()

	# Core alignment
	params.alignment = compute_alignment(faction_bits, obs)
	if params.alignment < 0.0:
		params.alignment = 0.0

	# Intensity: scale preference x biome scale
	var scale_pref = _bits_to_range(faction_bits[8], faction_bits[9]) if faction_bits.size() >= 10 else 0.5
	params.intensity = scale_pref * obs.scale if _is_known_observable(obs.scale) else 0.0

	# Complexity: entropy x coherence (high of both = complex)
	var complexity_sum = 0.0
	var complexity_count = 0.0
	if _is_known_observable(obs.entropy):
		complexity_sum += obs.entropy
		complexity_count += 1.0
	if _is_known_observable(obs.coherence):
		complexity_sum += obs.coherence
		complexity_count += 1.0
	params.complexity = complexity_sum / complexity_count if complexity_count > 0.0 else 0.0

	# Urgency: from dynamics preference
	var dynamics_pref = _bits_to_range(faction_bits[10], faction_bits[11]) if faction_bits.size() >= 12 else 0.5
	params.urgency = dynamics_pref * obs.dynamics if _is_known_observable(obs.dynamics) else 0.0

	# Variety: from distribution shape
	params.variety = float(obs.distribution_shape) / 3.0 if obs.distribution_shape >= 0 else 0.0

	# Basis weights: probability distribution from the register substrate
	params.basis_weights = _get_basis_weights(substrate)

	# Operator weights: quest type probability distribution from faction bits
	# Born rule sampling over operator structures (amplitude/coherence/ratio/multi)
	params.operator_weights = calculate_operator_weights(faction_bits)

	return params


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

static func _resolve_state_source(substrate, biome = null):
	var source = substrate if substrate != null else biome
	if source == null:
		return null
	if "quantum_computer" in source and source.quantum_computer:
		return source.quantum_computer
	return source


static func _resolve_density_matrix(state_source):
	if state_source == null:
		return null
	if "density_matrix" in state_source and state_source.density_matrix:
		return state_source.density_matrix
	if state_source.has_method("get_density_matrix"):
		return state_source.get_density_matrix()
	return null


static func _get_purity(state_source, density_matrix) -> float:
	if state_source and state_source.has_method("get_purity"):
		return clampf(float(state_source.get_purity()), 0.0, 1.0)
	if density_matrix and density_matrix.has_method("get_purity"):
		return clampf(float(density_matrix.get_purity()), 0.0, 1.0)
	return -1.0


static func _density_dim(density_matrix) -> int:
	if density_matrix == null:
		return 0
	if density_matrix.has_method("dimension"):
		return int(density_matrix.dimension())
	if "n" in density_matrix:
		return int(density_matrix.n)
	return 0


static func _density_matrix_view(density_matrix):
	if density_matrix != null and density_matrix.has_method("get_matrix"):
		var matrix = density_matrix.get_matrix()
		if matrix:
			return matrix
	return density_matrix


static func _basis_probability(density_matrix, index: int) -> float:
	if density_matrix == null:
		return 0.0
	if density_matrix.has_method("get_probability_by_index"):
		return clampf(float(density_matrix.get_probability_by_index(index)), 0.0, 1.0)
	if density_matrix.has_method("get_diagonal_real"):
		return clampf(float(density_matrix.get_diagonal_real(index)), 0.0, 1.0)
	if density_matrix.has_method("get_element"):
		return clampf(float(density_matrix.get_element(index, index).re), 0.0, 1.0)
	return 0.0

static func _bits_to_range(bit0: int, bit1: int) -> float:
	# Convert 2 bits to [0, 1] range: 00->0.125, 01->0.375, 10->0.625, 11->0.875
	var value = bit0 * 2 + bit1  # 0, 1, 2, or 3
	return (value + 0.5) / 4.0


static func _gaussian_match(preference: float, actual: float, sigma: float = 0.3) -> float:
	# Gaussian similarity: high when preference ~= actual
	var diff = preference - actual
	return exp(-(diff * diff) / (2.0 * sigma * sigma))


static func _calculate_coherence(density_matrix) -> float:
	# Calculate total off-diagonal magnitude squared
	if density_matrix == null:
		return -1.0

	var dim = _density_dim(density_matrix)
	if dim < 2:
		return 0.0

	var mat = _density_matrix_view(density_matrix)
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
	# Classify probability distribution shape: 0=peaked, 1=bimodal, 2=spread, 3=uniform
	if density_matrix == null:
		return -1

	var probs = []
	var dim = _density_dim(density_matrix)

	for i in range(dim):
		probs.append(_basis_probability(density_matrix, i))

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
	# Calculate variance of probability distribution
	if probs.is_empty():
		return 0.0

	var mean = 1.0 / probs.size()
	var variance = 0.0

	for p in probs:
		var diff = p - mean
		variance += diff * diff

	return variance / probs.size()


static func _calculate_scale(density_matrix) -> float:
	# Calculate total 'active' probability mass
	if density_matrix == null:
		return -1.0

	# Sum probabilities above threshold
	var active_mass = 0.0
	var dim = _density_dim(density_matrix)
	var threshold = 0.05

	for i in range(dim):
		var prob = _basis_probability(density_matrix, i)
		if prob > threshold:
			active_mass += prob

	return clamp(active_mass, 0.0, 1.0)


static func _get_basis_weights(substrate) -> Array:
	# Get probability weights for all basis states
	var weights = []
	var state_source = _resolve_state_source(substrate)

	if state_source == null:
		return [1.0]  # Single uniform weight

	var density_matrix = _resolve_density_matrix(state_source)
	if density_matrix == null:
		return [1.0]

	var dim = _density_dim(density_matrix)
	var total = 0.0

	for i in range(dim):
		var prob = _basis_probability(density_matrix, i)
		weights.append(prob)
		total += prob

	# Renormalize
	if total > 0:
		for i in range(weights.size()):
			weights[i] /= total

	return weights


static func _is_known_observable(value: float) -> bool:
	return value >= 0.0


# ============================================================================
# DEBUG / UTILITY
# ============================================================================

static func describe_preferences(faction_bits: Array) -> String:
	# Human-readable description of faction preferences from bits
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
	# Human-readable description of biome observables
	var parts = []
	parts.append("purity: " + ("—" if obs.purity < 0.0 else "%.2f" % obs.purity))
	parts.append("entropy: " + ("—" if obs.entropy < 0.0 else "%.2f" % obs.entropy))
	parts.append("coherence: " + ("—" if obs.coherence < 0.0 else "%.2f" % obs.coherence))

	var shape_names = ["peaked", "bimodal", "spread", "uniform"]
	# -1 = unknown; a bare negative index would silently read "uniform" (arr[-1]).
	var shape_known: bool = obs.distribution_shape >= 0 and obs.distribution_shape < shape_names.size()
	parts.append("shape: " + (shape_names[obs.distribution_shape] if shape_known else "—"))

	parts.append("scale: " + ("—" if obs.scale < 0.0 else "%.2f" % obs.scale))
	parts.append("dynamics: " + ("—" if obs.dynamics < 0.0 else "%.2f" % obs.dynamics))

	return ", ".join(parts)


# ============================================================================
# QUANTUM-NATIVE MEASUREMENT OPERATORS (for amplitude quests)
# ============================================================================

static func calculate_operator_weights(faction_bits: Array) -> Dictionary:
	# Calculate continuous weights for different operator types

	# Accepts int or float values in [0,1] - prepares for future continuous distributions!

	# Returns:
	# Dictionary with probability weights for quest structures

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
