## Test: Emoji Injection Block-Embedding (No Redistribution)
##
## Verifies Manifest Section 3.5 compliance:
## "expanding N must not redistribute existing probability"
##
## This test ensures that when a new emoji is injected into the bath,
## existing emojis retain their exact probabilities (no renormalization).
extends GutTest

## Test: Block-embedding preserves existing probabilities
func test_block_embedding_preserves_probabilities():
	# Create bath with 2 emojis
	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "💀"])

	# Set initial probabilities
	bath.initialize_weighted({"🌾": 0.7, "💀": 0.3})

	# Record probabilities BEFORE injection
	var p_wheat_before = bath.get_probability("🌾")
	var p_death_before = bath.get_probability("💀")

	gut.p("BEFORE injection: 🌾=%.6f, 💀=%.6f, Tr(ρ)=%.6f" % [
		p_wheat_before, p_death_before, bath._density_matrix.get_trace()])

	# Inject new emoji with zero initial amplitude (block-embedding)
	var icon_registry = get_node_or_null("/root/IconRegistry")
	assert_not_null(icon_registry, "IconRegistry should exist")

	var mushroom_icon = icon_registry.get_icon("🍄")
	assert_not_null(mushroom_icon, "Mushroom icon should exist")

	# CRITICAL: Inject with zero amplitude (proper block-embedding)
	bath.inject_emoji("🍄", mushroom_icon, Complex.zero())

	# Record probabilities AFTER injection
	var p_wheat_after = bath.get_probability("🌾")
	var p_death_after = bath.get_probability("💀")
	var p_mushroom_after = bath.get_probability("🍄")

	gut.p("AFTER injection: 🌾=%.6f, 💀=%.6f, 🍄=%.6f, Tr(ρ)=%.6f" % [
		p_wheat_after, p_death_after, p_mushroom_after, bath._density_matrix.get_trace()])

	# MANIFEST REQUIREMENT: Existing probabilities MUST NOT change
	assert_almost_eq(p_wheat_after, p_wheat_before, 1e-6,
		"VIOLATION: Wheat probability redistributed! %.6f → %.6f" % [p_wheat_before, p_wheat_after])

	assert_almost_eq(p_death_after, p_death_before, 1e-6,
		"VIOLATION: Death probability redistributed! %.6f → %.6f" % [p_death_before, p_death_after])

	# New emoji should have zero population (block-embedding)
	assert_almost_eq(p_mushroom_after, 0.0, 1e-6,
		"VIOLATION: New emoji has non-zero population without pump! p(🍄)=%.6f" % p_mushroom_after)

	# Trace should still be 1.0 (trace-preserving)
	var trace_after = bath._density_matrix.get_trace()
	assert_almost_eq(trace_after, 1.0, 1e-6,
		"VIOLATION: Trace not preserved! Tr(ρ)=%.6f" % trace_after)

	gut.p("✅ PASSED: Block-embedding preserves existing probabilities")

## Test: Injection with non-zero amplitude violates trace
func test_non_zero_amplitude_warns():
	# Create bath
	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "💀"])
	bath.initialize_weighted({"🌾": 0.7, "💀": 0.3})

	# Inject with non-zero amplitude (VIOLATION of trace-1)
	var icon_registry = get_node_or_null("/root/IconRegistry")
	var mushroom_icon = icon_registry.get_icon("🍄")

	# This should trigger a warning (Tr(ρ) > 1)
	bath.inject_emoji("🍄", mushroom_icon, Complex.new(0.2, 0.0))

	var trace_after = bath._density_matrix.get_trace()

	gut.p("Trace after non-zero injection: %.6f (should be > 1.0)" % trace_after)

	# Trace should be > 1.0 (expected violation)
	assert_gt(trace_after, 1.0, "Expected Tr(ρ) > 1.0 when injecting with non-zero amplitude")

	gut.p("✅ PASSED: Non-zero amplitude correctly violates trace-1")

## Test: Multiple injections preserve independence
func test_multiple_injections_independent():
	# Create bath with 1 emoji
	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾"])
	bath.initialize_weighted({"🌾": 1.0})

	var icon_registry = get_node_or_null("/root/IconRegistry")

	# Inject first emoji (death)
	var death_icon = icon_registry.get_icon("💀")
	bath.inject_emoji("💀", death_icon, Complex.zero())

	var p_wheat_after_first = bath.get_probability("🌾")
	var p_death_after_first = bath.get_probability("💀")

	gut.p("After 1st injection: 🌾=%.6f, 💀=%.6f" % [p_wheat_after_first, p_death_after_first])

	# Inject second emoji (mushroom)
	var mushroom_icon = icon_registry.get_icon("🍄")
	bath.inject_emoji("🍄", mushroom_icon, Complex.zero())

	var p_wheat_after_second = bath.get_probability("🌾")
	var p_death_after_second = bath.get_probability("💀")
	var p_mushroom_after_second = bath.get_probability("🍄")

	gut.p("After 2nd injection: 🌾=%.6f, 💀=%.6f, 🍄=%.6f" % [
		p_wheat_after_second, p_death_after_second, p_mushroom_after_second])

	# Original emoji should still have p=1.0
	assert_almost_eq(p_wheat_after_second, 1.0, 1e-6,
		"VIOLATION: Original emoji probability changed!")

	# First injected emoji should still have p=0.0
	assert_almost_eq(p_death_after_second, 0.0, 1e-6,
		"VIOLATION: First injected emoji probability changed!")

	# Second injected emoji should have p=0.0
	assert_almost_eq(p_mushroom_after_second, 0.0, 1e-6,
		"VIOLATION: Second injected emoji has non-zero population!")

	gut.p("✅ PASSED: Multiple injections preserve independence")

## Test: Block structure verification (off-diagonals remain zero)
func test_block_structure_off_diagonals_zero():
	# Create bath with 2 emojis in pure state |🌾⟩
	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "💀"])
	bath.initialize_weighted({"🌾": 1.0, "💀": 0.0})

	# Create coherence between wheat and death (populate off-diagonals)
	var mat_before = bath._density_matrix.get_matrix()
	mat_before.set_element(0, 1, Complex.new(0.1, 0.05))  # ρ[🌾][💀]
	mat_before.set_element(1, 0, Complex.new(0.1, -0.05)) # ρ[💀][🌾] (Hermitian)
	bath._density_matrix.set_matrix(mat_before)

	var coherence_before = bath.get_coherence("🌾", "💀")
	gut.p("Coherence BEFORE injection: %.6f" % coherence_before.abs())

	# Inject mushroom
	var icon_registry = get_node_or_null("/root/IconRegistry")
	var mushroom_icon = icon_registry.get_icon("🍄")
	bath.inject_emoji("🍄", mushroom_icon, Complex.zero())

	# Check coherence between wheat and death (should be preserved)
	var coherence_after = bath.get_coherence("🌾", "💀")
	gut.p("Coherence AFTER injection: %.6f" % coherence_after.abs())

	assert_almost_eq(coherence_after.abs(), coherence_before.abs(), 1e-6,
		"VIOLATION: Off-diagonal coherence not preserved!")

	# Check coherence between wheat/death and mushroom (should be zero)
	var coherence_wheat_mushroom = bath.get_coherence("🌾", "🍄")
	var coherence_death_mushroom = bath.get_coherence("💀", "🍄")

	assert_almost_eq(coherence_wheat_mushroom.abs(), 0.0, 1e-6,
		"VIOLATION: Off-diagonal ρ[🌾][🍄] should be zero! (block structure)")

	assert_almost_eq(coherence_death_mushroom.abs(), 0.0, 1e-6,
		"VIOLATION: Off-diagonal ρ[💀][🍄] should be zero! (block structure)")

	gut.p("✅ PASSED: Block structure maintained (off-diagonals zero)")
