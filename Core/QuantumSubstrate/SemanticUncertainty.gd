class_name SemanticUncertainty
extends RefCounted

## Semantic Uncertainty Principle
##
## Implements: precision × flexibility >= h_semantic
##
## Precision = How stable/well-defined meanings are (1 - normalized_entropy)
## Flexibility = How easily state can change (normalized_entropy)
##
## This creates strategic tension:
## - High precision -> stable but rigid (hard to change)
## - High flexibility -> adaptable but chaotic (meanings drift)
##
## The uncertainty principle ensures you can't have both at once.
## This is the quantum analogue of information-theoretic constraints.

## Minimum uncertainty product (semantic Planck constant)
const PLANCK_SEMANTIC: float = 0.25

## ========================================
## Public API
## ========================================

static func compute_uncertainty(density_matrix) -> Dictionary:
	"""Calculate semantic uncertainty metrics from density matrix

	Args:
		density_matrix: ComplexMatrix representing quantum state

	Returns:
		{
			"precision": float,           # 1.0 - entropy (high = stable meanings)
			"flexibility": float,         # entropy (high = adaptable state)
			"product": float,             # precision × flexibility
			"satisfies_principle": bool,  # product >= PLANCK_SEMANTIC
			"entropy": float,             # raw von Neumann entropy
			"purity": float,              # Tr(rho^2) - measure of state purity
			"regime": String              # descriptive regime name
		}
	"""
	# Get matrix dimension
	var dim = density_matrix.n  # Using .n from ComplexMatrix

	if dim < 2:
		return _empty_result()

	# Compute entropy (simplified: diagonal approximation for performance)
	var entropy = _compute_population_entropy(density_matrix)
	var max_entropy = log(float(dim))

	# Normalize entropy to [0, 1]
	var normalized_entropy = entropy / max_entropy if max_entropy > 0.0 else 0.0

	# Precision is inverse of entropy
	var precision = 1.0 - normalized_entropy

	# Flexibility is entropy itself
	var flexibility = normalized_entropy

	# Compute uncertainty product
	var product = precision * flexibility

	# Check if principle is satisfied
	var satisfies = product >= PLANCK_SEMANTIC

	# Compute purity for additional insight
	var purity = _compute_purity(density_matrix)

	# Determine regime
	var regime = _classify_regime(precision, flexibility, purity)

	return {
		"precision": precision,
		"flexibility": flexibility,
		"product": product,
		"satisfies_principle": satisfies,
		"entropy": entropy,
		"purity": purity,
		"regime": regime
	}


static func compute_from_quantum_computer(quantum_computer) -> Dictionary:
	"""Convenience method to compute uncertainty directly from QuantumComputer"""
	if quantum_computer == null or quantum_computer.density_matrix == null:
		return _empty_result()

	return compute_uncertainty(quantum_computer.density_matrix)


## ========================================
## Entropy Calculations
## ========================================

static func _compute_population_entropy(density_matrix) -> float:
	"""Compute population entropy: S = -sum(p_i log p_i)

	This is the diagonal approximation of von Neumann entropy.
	Faster than full diagonalization, good enough for gameplay.
	"""
	var entropy = 0.0
	var dim = density_matrix.n

	for i in range(dim):
		var p = density_matrix.get_element(i, i).re
		if p > 1e-10:  # Avoid log(0)
			entropy -= p * log(p)

	return entropy


static func _compute_von_neumann_entropy(density_matrix) -> float:
	"""Compute full von Neumann entropy: S = -Tr(rho log rho)

	Requires eigenvalue decomposition. More accurate but slower.
	For most gameplay purposes, population entropy is sufficient.
	"""
	# For now, use population entropy as approximation
	# Full diagonalization would require eigenvalue computation
	return _compute_population_entropy(density_matrix)


static func _compute_purity(density_matrix) -> float:
	"""Compute purity: Tr(rho^2)

	Pure state: purity = 1.0
	Maximally mixed: purity = 1/d
	"""
	var trace_rho_squared = 0.0
	var dim = density_matrix.n

	# Tr(rho^2) = sum_ij |rho_ij|^2
	for i in range(dim):
		for j in range(dim):
			var element = density_matrix.get_element(i, j)
			trace_rho_squared += element.re * element.re + element.im * element.im

	return trace_rho_squared


## ========================================
## Regime Classification
## ========================================

static func _classify_regime(precision: float, flexibility: float, purity: float) -> String:
	"""Classify the current uncertainty regime"""
	# High precision -> crystallized (stable, rigid)
	if precision > 0.8 and purity > 0.8:
		return "crystallized"

	# High flexibility -> fluid (chaotic, adaptable)
	if flexibility > 0.8:
		return "fluid"

	# Balanced zone
	if precision > 0.4 and flexibility > 0.4:
		return "balanced"

	# Near maximum precision
	if precision > 0.7:
		return "stable"

	# Near maximum flexibility
	if flexibility > 0.7:
		return "chaotic"

	# Low both -> diffuse (meaning drift, system degradation)
	if precision < 0.3 and flexibility < 0.3:
		return "diffuse"

	return "transitional"


static func get_regime_description(regime: String) -> String:
	"""Get human-readable description of uncertainty regime"""
	match regime:
		"crystallized":
			return "Crystallized - Meanings are locked, state highly stable but rigid"
		"fluid":
			return "Fluid - State is highly adaptable but meanings drift unpredictably"
		"balanced":
			return "Balanced - Good mix of stability and adaptability"
		"stable":
			return "Stable - Meanings are mostly fixed, moderate adaptability"
		"chaotic":
			return "Chaotic - High entropy, unpredictable dynamics"
		"diffuse":
			return "Diffuse - Degenerate state, low information content"
		"transitional":
			return "Transitional - Moving between regimes"
		_:
			return "Unknown regime"


static func get_regime_color(regime: String) -> Color:
	"""Get color for regime visualization"""
	match regime:
		"crystallized":
			return Color(0.4, 0.6, 0.9)    # Ice blue
		"fluid":
			return Color(0.2, 0.7, 0.9)    # Cyan
		"balanced":
			return Color(0.4, 0.8, 0.4)    # Green
		"stable":
			return Color(0.3, 0.5, 0.7)    # Steel blue
		"chaotic":
			return Color(0.9, 0.3, 0.3)    # Red
		"diffuse":
			return Color(0.5, 0.5, 0.5)    # Gray
		"transitional":
			return Color(0.9, 0.8, 0.3)    # Yellow
		_:
			return Color.WHITE


static func get_regime_emoji(regime: String) -> String:
	"""Get emoji for regime"""
	match regime:
		"crystallized":
			return "❄️"
		"fluid":
			return "💧"
		"balanced":
			return "⚖️"
		"stable":
			return "🪨"
		"chaotic":
			return "🌀"
		"diffuse":
			return "🌫️"
		"transitional":
			return "↔️"
		_:
			return "❓"


## ========================================
## Gameplay Implications
## ========================================

static func get_action_modifier(uncertainty: Dictionary) -> Dictionary:
	"""Get gameplay modifiers based on uncertainty state

	Returns multipliers that can affect gameplay mechanics.
	"""
	var precision = uncertainty.get("precision", 0.5)
	var flexibility = uncertainty.get("flexibility", 0.5)
	var regime = uncertainty.get("regime", "transitional")

	var modifiers = {
		"tool_effectiveness": 1.0,
		"meaning_stability": 1.0,
		"evolution_speed": 1.0,
		"state_change_cost": 1.0,
		"observation_accuracy": 1.0
	}

	match regime:
		"crystallized":
			# Stable but hard to change
			modifiers.tool_effectiveness = 0.7  # Tools less effective
			modifiers.meaning_stability = 1.5   # Meanings very stable
			modifiers.state_change_cost = 2.0   # Expensive to change
			modifiers.observation_accuracy = 1.3 # Clear measurements

		"fluid":
			# Easy to change but unpredictable
			modifiers.tool_effectiveness = 1.2  # Tools very effective
			modifiers.meaning_stability = 0.5   # Meanings drift
			modifiers.evolution_speed = 1.5     # Fast dynamics
			modifiers.state_change_cost = 0.5   # Cheap to change
			modifiers.observation_accuracy = 0.7 # Fuzzy measurements

		"balanced":
			# All modifiers neutral
			pass

		"chaotic":
			modifiers.evolution_speed = 2.0
			modifiers.meaning_stability = 0.3
			modifiers.observation_accuracy = 0.5

		"diffuse":
			modifiers.tool_effectiveness = 0.5
			modifiers.meaning_stability = 0.5
			modifiers.evolution_speed = 0.5

	return modifiers


## ========================================
## Helpers
## ========================================

static func _empty_result() -> Dictionary:
	"""Return empty/default result for error cases"""
	return {
		"precision": 0.5,
		"flexibility": 0.5,
		"product": 0.25,
		"satisfies_principle": true,
		"entropy": 0.0,
		"purity": 1.0,
		"regime": "unknown"
	}


## ========================================
## Debug & Visualization
## ========================================

static func format_uncertainty_report(uncertainty: Dictionary) -> String:
	"""Format uncertainty data as readable report"""
	var lines: Array[String] = [
		"=== Semantic Uncertainty Report ===",
		"",
		"Precision:   %.3f (1 = pure state, 0 = mixed)" % uncertainty.get("precision", 0.0),
		"Flexibility: %.3f (0 = rigid, 1 = fluid)" % uncertainty.get("flexibility", 0.0),
		"",
		"Product:     %.4f (must be >= %.2f)" % [
			uncertainty.get("product", 0.0),
			PLANCK_SEMANTIC
		],
		"Satisfies:   %s" % ("YES" if uncertainty.get("satisfies_principle", false) else "NO"),
		"",
		"Entropy:     %.4f nats" % uncertainty.get("entropy", 0.0),
		"Purity:      %.4f" % uncertainty.get("purity", 0.0),
		"",
		"Regime:      %s %s" % [
			get_regime_emoji(uncertainty.get("regime", "unknown")),
			uncertainty.get("regime", "unknown")
		],
		get_regime_description(uncertainty.get("regime", "unknown")),
	]

	return "\n".join(lines)
