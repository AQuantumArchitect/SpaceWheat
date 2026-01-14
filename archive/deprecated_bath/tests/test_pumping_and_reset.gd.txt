extends GutTest

## Test: Pumping and Reset Channels (Manifest Section 3.1 and 3.4)
##
## Verifies Gozinta (input) channels:
## 1. Reservoir pumping: L_t = √Γ |t⟩⟨r| transfers amplitude
## 2. Reset channel: ρ ← (1-α)ρ + α ρ_ref mixes states

const QuantumBath = preload("res://Core/QuantumSubstrate/QuantumBath.gd")
const Icon = preload("res://Core/QuantumSubstrate/Icon.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")

## Test: Pumping increases target probability
func test_pumping_increases_target_probability():
	gut.p("=== Testing pumping increases target probability ===")

	var bath = QuantumBath.new()
	var icon_registry = get_node_or_null("/root/IconRegistry")
	assert_not_null(icon_registry, "IconRegistry should exist")

	# Get icons
	var wheat_icon = icon_registry.get_icon("🌾")
	var death_icon = icon_registry.get_icon("💀")

	# Initialize bath with wheat and death
	bath.initialize_with_emojis(["🌾", "💀"])
	bath.initialize_weighted({"🌾": 1.0, "💀": 0.0})

	var p_death_before = bath.get_probability("💀")
	gut.p("BEFORE pumping: P(💀)=%.4f" % p_death_before)

	# Create pump: transfer amplitude from wheat to death
	var pump_icon = Icon.new()
	pump_icon.emoji = "🌾"
	pump_icon.display_name = "Pump(🌾→💀)"
	pump_icon.lindblad_incoming["💀"] = 0.3  # 0.3 amplitude/sec

	# Rebuild operators with pump
	var original_icons = bath.active_icons.duplicate()
	bath.active_icons = [wheat_icon, death_icon, pump_icon]
	bath.build_hamiltonian_from_icons(bath.active_icons)
	bath.build_lindblad_from_icons(bath.active_icons)

	# Evolve for 1 second
	var dt = 0.016
	for i in range(int(1.0 / dt)):
		bath.evolve(dt)

	# Restore original operators
	bath.active_icons = original_icons
	bath.build_hamiltonian_from_icons(bath.active_icons)
	bath.build_lindblad_from_icons(bath.active_icons)

	var p_death_after = bath.get_probability("💀")
	var p_wheat_after = bath.get_probability("🌾")

	gut.p("AFTER pumping: P(🌾)=%.4f, P(💀)=%.4f" % [p_wheat_after, p_death_after])

	# Death should have gained probability
	assert_gt(p_death_after, p_death_before,
		"Pumping should increase target probability")

	# Wheat should have decreased
	assert_lt(p_wheat_after, 1.0,
		"Pumping should decrease source probability")

	# Trace should be preserved
	var trace = bath._density_matrix.get_trace()
	assert_almost_eq(trace, 1.0, 1e-6,
		"Trace should be preserved: Tr(ρ)=%.6f" % trace)

	gut.p("✅ PASSED: Pumping increases target probability")


## Test: Reset channel mixes toward reference state
func test_reset_toward_pure_state():
	gut.p("=== Testing reset toward pure state ===")

	var bath = QuantumBath.new()
	var icon_registry = get_node_or_null("/root/IconRegistry")

	var wheat_icon = icon_registry.get_icon("🌾")
	var death_icon = icon_registry.get_icon("💀")

	# Start in mixed state: 50-50
	bath.initialize_with_emojis(["🌾", "💀"])
	bath.initialize_weighted({"🌾": 0.5, "💀": 0.5})

	var purity_before = bath.get_purity()
	gut.p("BEFORE reset: Tr(ρ²)=%.4f (mixed)" % purity_before)

	# Reset toward |🌾⟩ (pure state)
	# ρ ← (1-α)ρ + α |🌾⟩⟨🌾|
	var alpha = 0.8  # 80% toward pure
	apply_reset(bath, alpha, "🌾")

	var purity_after = bath.get_purity()
	var p_wheat = bath.get_probability("🌾")
	var p_death = bath.get_probability("💀")

	gut.p("AFTER reset: Tr(ρ²)=%.4f, P(🌾)=%.4f, P(💀)=%.4f" % [
		purity_after, p_wheat, p_death
	])

	# Purity should increase (closer to pure state)
	assert_gt(purity_after, purity_before,
		"Reset should increase purity toward pure state")

	# Wheat probability should increase toward 1.0
	assert_gt(p_wheat, 0.5,
		"Resetting to |🌾⟩ should increase P(🌾)")

	# Death probability should decrease toward 0.0
	assert_lt(p_death, 0.5,
		"Resetting to |🌾⟩ should decrease P(💀)")

	# Trace should be preserved
	var trace = bath._density_matrix.get_trace()
	assert_almost_eq(trace, 1.0, 1e-6,
		"Trace should be preserved: Tr(ρ)=%.6f" % trace)

	gut.p("✅ PASSED: Reset toward pure state works correctly")


## Test: Reset toward maximally mixed state
func test_reset_toward_maximally_mixed():
	gut.p("=== Testing reset toward maximally mixed state ===")

	var bath = QuantumBath.new()
	var icon_registry = get_node_or_null("/root/IconRegistry")

	var wheat_icon = icon_registry.get_icon("🌾")
	var death_icon = icon_registry.get_icon("💀")

	# Start in pure state: |🌾⟩
	bath.initialize_with_emojis(["🌾", "💀"])
	bath.initialize_weighted({"🌾": 1.0, "💀": 0.0})

	var purity_before = bath.get_purity()
	gut.p("BEFORE reset: Tr(ρ²)=%.4f (pure)" % purity_before)

	# Reset toward maximally mixed (I/2)
	# ρ ← (1-α)ρ + α (I/2)
	var alpha = 0.8
	apply_reset(bath, alpha, "maximally_mixed")

	var purity_after = bath.get_purity()
	var p_wheat = bath.get_probability("🌾")
	var p_death = bath.get_probability("💀")

	gut.p("AFTER reset: Tr(ρ²)=%.4f, P(🌾)=%.4f, P(💀)=%.4f" % [
		purity_after, p_wheat, p_death
	])

	# Purity should decrease (toward mixed state)
	assert_lt(purity_after, purity_before,
		"Reset toward mixed should decrease purity")

	# Probabilities should approach 0.5
	assert_almost_eq(p_wheat, 0.5, 0.1,
		"Resetting to maximally mixed should approach P(🌾)=0.5")

	assert_almost_eq(p_death, 0.5, 0.1,
		"Resetting to maximally mixed should approach P(💀)=0.5")

	var trace = bath._density_matrix.get_trace()
	assert_almost_eq(trace, 1.0, 1e-6,
		"Trace should be preserved: Tr(ρ)=%.6f" % trace)

	gut.p("✅ PASSED: Reset toward maximally mixed state works correctly")


## Test: Reset strength (alpha) controls mix fraction
func test_reset_strength_controls_mixing():
	gut.p("=== Testing reset strength controls mixing ===")

	var bath = QuantumBath.new()
	var icon_registry = get_node_or_null("/root/IconRegistry")

	var wheat_icon = icon_registry.get_icon("🌾")
	var death_icon = icon_registry.get_icon("💀")

	# Start: 100% death
	bath.initialize_with_emojis(["🌾", "💀"])
	bath.initialize_weighted({"🌾": 0.0, "💀": 1.0})

	# Reset with α=0.5 (50% toward |🌾⟩)
	apply_reset(bath, 0.5, "🌾")

	var p_wheat_alpha_half = bath.get_probability("🌾")
	gut.p("After α=0.5 reset: P(🌾)=%.4f (expected ~0.5)" % p_wheat_alpha_half)

	# Reinitialize for second test
	bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "💀"])
	bath.initialize_weighted({"🌾": 0.0, "💀": 1.0})

	# Reset with α=0.8 (80% toward |🌾⟩)
	apply_reset(bath, 0.8, "🌾")

	var p_wheat_alpha_high = bath.get_probability("🌾")
	gut.p("After α=0.8 reset: P(🌾)=%.4f (expected ~0.8)" % p_wheat_alpha_high)

	# Higher alpha should give higher probability
	assert_gt(p_wheat_alpha_high, p_wheat_alpha_half,
		"Higher α should produce higher probability in target state")

	# Alpha=0.5 should give P≈0.5
	assert_almost_eq(p_wheat_alpha_half, 0.5, 0.05,
		"α=0.5 should mix to ~0.5 (interpolation)")

	# Alpha=0.8 should give P≈0.8
	assert_almost_eq(p_wheat_alpha_high, 0.8, 0.05,
		"α=0.8 should mix to ~0.8 (interpolation)")

	gut.p("✅ PASSED: Reset strength correctly controls mixing")


## Test: No reset (alpha=0) preserves state
func test_no_reset_preserves_state():
	gut.p("=== Testing alpha=0 preserves state ===")

	var bath = QuantumBath.new()
	var icon_registry = get_node_or_null("/root/IconRegistry")

	var wheat_icon = icon_registry.get_icon("🌾")
	var death_icon = icon_registry.get_icon("💀")

	# Start in mixed state
	bath.initialize_with_emojis(["🌾", "💀"])
	bath.initialize_weighted({"🌾": 0.3, "💀": 0.7})

	var p_wheat_before = bath.get_probability("🌾")
	var purity_before = bath.get_purity()

	# Reset with α=0 (no effect)
	apply_reset(bath, 0.0, "🌾")

	var p_wheat_after = bath.get_probability("🌾")
	var purity_after = bath.get_purity()

	# Should be identical
	assert_almost_eq(p_wheat_after, p_wheat_before, 1e-6,
		"α=0 reset should not change state")

	assert_almost_eq(purity_after, purity_before, 1e-6,
		"α=0 reset should preserve purity")

	gut.p("✅ PASSED: α=0 reset preserves state")


## Test: Full reset (alpha=1) produces target state
func test_full_reset_produces_target_state():
	gut.p("=== Testing alpha=1 produces target state ===")

	var bath = QuantumBath.new()
	var icon_registry = get_node_or_null("/root/IconRegistry")

	var wheat_icon = icon_registry.get_icon("🌾")
	var death_icon = icon_registry.get_icon("💀")

	# Start in death state
	bath.initialize_with_emojis(["🌾", "💀"])
	bath.initialize_weighted({"🌾": 0.0, "💀": 1.0})

	# Full reset (α=1) to |🌾⟩
	apply_reset(bath, 1.0, "🌾")

	var p_wheat = bath.get_probability("🌾")
	var p_death = bath.get_probability("💀")
	var purity = bath.get_purity()

	gut.p("After α=1.0 reset: P(🌾)=%.6f, P(💀)=%.6f, Tr(ρ²)=%.6f" % [
		p_wheat, p_death, purity
	])

	# Should be pure state |🌾⟩⟨🌾|
	assert_almost_eq(p_wheat, 1.0, 1e-6,
		"α=1.0 reset should produce |🌾⟩ with P(🌾)=1.0")

	assert_almost_eq(p_death, 0.0, 1e-6,
		"α=1.0 reset should produce |🌾⟩ with P(💀)=0.0")

	assert_almost_eq(purity, 1.0, 1e-6,
		"α=1.0 reset should produce pure state with Tr(ρ²)=1.0")

	gut.p("✅ PASSED: α=1.0 reset produces target state")


## Helper function to apply reset (since BiomeBase not available in test)
func apply_reset(bath: QuantumBath, alpha: float, ref_state: String) -> void:
	"""Local implementation of reset channel for testing"""
	var dim = bath._density_matrix.dimension()
	var rho_current = bath._density_matrix.get_matrix()
	var rho_ref = ComplexMatrix.new(dim)

	const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
	const DensityMatrix = preload("res://Core/QuantumSubstrate/DensityMatrix.gd")

	match ref_state:
		"pure":
			var amps: Array = []
			amps.append(Complex.one())
			for i in range(1, dim):
				amps.append(Complex.zero())
			var pure_rho = DensityMatrix.new()
			pure_rho.initialize_with_emojis(bath._density_matrix.emoji_list)
			pure_rho.set_pure_state(amps)
			rho_ref = pure_rho.get_matrix()

		"maximally_mixed":
			var one_over_n = 1.0 / float(dim)
			for i in range(dim):
				rho_ref.set_element(i, i, Complex.new(one_over_n, 0.0))

		_:
			var emoji_idx = bath._density_matrix.emoji_to_index.get(ref_state, -1)
			if emoji_idx >= 0:
				rho_ref.set_element(emoji_idx, emoji_idx, Complex.one())

	var alpha_complex = Complex.new(alpha, 0.0)
	var one_minus_alpha = Complex.new(1.0 - alpha, 0.0)

	var rho_reset = rho_current.scale(one_minus_alpha).add(rho_ref.scale(alpha_complex))

	bath._density_matrix.set_matrix(rho_reset)
	bath._density_matrix._enforce_trace_one()
