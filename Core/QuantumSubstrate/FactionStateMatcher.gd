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
	#
	# Weighted average of the per-channel fits — the breakdown IS the
	# computation (see explain_alignment; the scalar is exactly the weighted
	# mean of its rows, so readback can never drift from the score). Hybrid
	# averaging keeps gameplay values in 0.2–0.9 instead of tiny products.
	var rows := explain_alignment(faction_bits, obs)
	if rows.is_empty():
		return -1.0  # Not enough preference data to score honestly

	var total_score := 0.0
	var total_weight := 0.0
	for r in rows:
		if r.known:
			total_score += float(r.fit) * float(r.weight)
			total_weight += float(r.weight)
	return total_score / total_weight if total_weight > 0.0 else -1.0


## The resonance, decomposed: one row per axiom channel, same order and same
## math as compute_alignment. Row keys: channel, weight, known (bool),
## fit ∈ [0,1] (-1.0 when the observable is unknown), want / have (the canon
## band words the quest board already speaks), want_value / have_value.
##   faction_bits[0-1] purity · [2-3] entropy · [4-5] coherence ·
##   [6-7] distribution shape · [8-9] scale · [10-11] dynamics
static func explain_alignment(faction_bits: Array, obs: BiomeObservables) -> Array:
	if faction_bits.size() < 12:
		return []

	var rows: Array = []

	# Continuous channels, Gaussian fit (σ 0.4): the faction wants the
	# observable near its 2-bit quartile; "have" bands the live value into the
	# same canon vocabulary so want-vs-have reads as one language.
	# (name, first bit, weight, band words, live observable)
	var continuous := [
		["purity", 0, 2.0, ["chaos", "murk", "order", "crystal"], obs.purity],
		["entropy", 2, 2.0, ["focused", "tempered", "diffuse", "uniform"], obs.entropy],
		["coherence", 4, 1.5, ["classical", "tinged", "quantum", "woven"], obs.coherence],
	]
	var tail := [
		["scale", 8, 1.0, ["sparse", "modest", "broad", "vast"], obs.scale],
		["dynamics", 10, 0.5, ["still", "breathing", "restless", "storming"], obs.dynamics],
	]

	for spec in continuous:
		rows.append(_explain_continuous(spec, faction_bits))

	# Distribution shape: discrete channel — exact class or 0.3 partial credit.
	var shape_names := ["peaked", "bimodal", "spread", "uniform"]
	var shape_pref: int = int(faction_bits[6]) * 2 + int(faction_bits[7])
	var shape_known: bool = obs.distribution_shape >= 0
	rows.append({
		"channel": "distribution", "weight": 1.0, "known": shape_known,
		"fit": (1.0 if shape_pref == obs.distribution_shape else 0.3) if shape_known else -1.0,
		"want": shape_names[clampi(shape_pref, 0, 3)],
		"have": shape_names[obs.distribution_shape] if (shape_known and obs.distribution_shape < 4) else "—",
		"want_value": float(shape_pref), "have_value": float(obs.distribution_shape),
	})

	for spec in tail:
		rows.append(_explain_continuous(spec, faction_bits))

	return rows


static func _explain_continuous(spec: Array, faction_bits: Array) -> Dictionary:
	var b: int = int(spec[1])
	var names: Array = spec[3]
	var actual: float = float(spec[4])
	var pref: float = _bits_to_range(faction_bits[b], faction_bits[b + 1])
	var known := _is_known_observable(actual)
	return {
		"channel": spec[0], "weight": spec[2], "known": known,
		"fit": _gaussian_match(pref, actual, 0.4) if known else -1.0,
		"want": names[clampi(int(faction_bits[b]) * 2 + int(faction_bits[b + 1]), 0, 3)],
		"have": names[clampi(int(actual * 4.0), 0, 3)] if known else "—",
		"want_value": pref, "have_value": actual,
	}


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


static func _is_known_observable(value: float) -> bool:
	return value >= 0.0


# ============================================================================
# DEBUG / UTILITY
# ============================================================================

static func describe_preferences(faction_bits: Array) -> String:
	# Human-readable description of faction preferences from bits. Player-facing
	# (the quest board's "their axioms:" line) — the words speak the game's canon
	# (woven = entangled, still/storming = dynamics) rather than textbook labels.
	if faction_bits.size() < 12:
		return "insufficient bits"

	var parts = []

	# Purity
	var purity_val = faction_bits[0] * 2 + faction_bits[1]
	var purity_names = ["chaos", "murk", "order", "crystal"]
	parts.append("purity: " + purity_names[purity_val])

	# Entropy
	var entropy_val = faction_bits[2] * 2 + faction_bits[3]
	var entropy_names = ["focused", "tempered", "diffuse", "uniform"]
	parts.append("entropy: " + entropy_names[entropy_val])

	# Coherence
	var coherence_val = faction_bits[4] * 2 + faction_bits[5]
	var coherence_names = ["classical", "tinged", "quantum", "woven"]
	parts.append("coherence: " + coherence_names[coherence_val])

	# Distribution
	var dist_val = faction_bits[6] * 2 + faction_bits[7]
	var dist_names = ["peaked", "bimodal", "spread", "uniform"]
	parts.append("distribution: " + dist_names[dist_val])

	# Scale
	var scale_val = faction_bits[8] * 2 + faction_bits[9]
	var scale_names = ["sparse", "modest", "broad", "vast"]
	parts.append("scale: " + scale_names[scale_val])

	# Dynamics
	var dyn_val = faction_bits[10] * 2 + faction_bits[11]
	var dyn_names = ["still", "breathing", "restless", "storming"]
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
