extends GutTest

## Test: Energy Tap Sink Flux System (Manifest Section 4.1)
##
## Verifies complete energy tap workflow:
## 1. Drain Lindblad operators reduce target emoji probability
## 2. Sink state accumulates flux
## 3. Flux conservation (drained amount matches sink accumulation)
## 4. FarmPlot integration (process_energy_tap)

const QuantumBath = preload("res://Core/QuantumSubstrate/QuantumBath.gd")
const Icon = preload("res://Core/QuantumSubstrate/Icon.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")

## Test: Drain operator reduces target probability
func test_drain_operator_reduces_probability():
	gut.p("=== Testing drain operator reduces target probability ===")

	# Create bath with wheat, death, sink
	var bath = QuantumBath.new()
	var icon_registry = get_node_or_null("/root/IconRegistry")
	assert_not_null(icon_registry, "IconRegistry should exist")

	# Get icons
	var wheat_icon = icon_registry.get_icon("🌾")
	var death_icon = icon_registry.get_icon("💀")
	var sink_icon = Icon.new()
	sink_icon.emoji = "⬇️"
	sink_icon.display_name = "Sink"
	sink_icon.is_eternal = true

	# Configure wheat as drain target
	wheat_icon.is_drain_target = true
	wheat_icon.drain_to_sink_rate = 0.5  # 0.5 probability/sec

	# Initialize bath
	bath.initialize_with_emojis(["🌾", "💀", "⬇️"])
	bath.initialize_weighted({"🌾": 0.8, "💀": 0.2, "⬇️": 0.0})

	# Build operators
	bath.active_icons = [wheat_icon, death_icon, sink_icon]
	bath.build_hamiltonian_from_icons(bath.active_icons)
	bath.build_lindblad_from_icons(bath.active_icons)

	var p_wheat_before = bath.get_probability("🌾")
	var p_sink_before = bath.get_probability("⬇️")

	gut.p("BEFORE evolution: P(🌾)=%.4f, P(⬇️)=%.4f" % [p_wheat_before, p_sink_before])

	# Evolve for 1 second
	var dt = 0.016  # 60 FPS
	var total_time = 1.0
	var steps = int(total_time / dt)

	for i in range(steps):
		bath.evolve(dt)

	var p_wheat_after = bath.get_probability("🌾")
	var p_sink_after = bath.get_probability("⬇️")

	gut.p("AFTER evolution: P(🌾)=%.4f, P(⬇️)=%.4f" % [p_wheat_after, p_sink_after])

	# Wheat should have decreased
	assert_lt(p_wheat_after, p_wheat_before,
		"Wheat probability should decrease due to drain")

	# Sink should have increased
	assert_gt(p_sink_after, p_sink_before,
		"Sink probability should increase from drain")

	# Trace should still be 1.0
	var trace = bath._density_matrix.get_trace()
	assert_almost_eq(trace, 1.0, 1e-6,
		"Trace should be preserved: Tr(ρ)=%.6f" % trace)

	gut.p("✅ PASSED: Drain operator correctly transfers population")


## Test: Sink flux accumulation
func test_sink_flux_accumulation():
	gut.p("=== Testing sink flux accumulation ===")

	var bath = QuantumBath.new()
	var icon_registry = get_node_or_null("/root/IconRegistry")

	var wheat_icon = icon_registry.get_icon("🌾")
	wheat_icon.is_drain_target = true
	wheat_icon.drain_to_sink_rate = 0.3

	var sink_icon = Icon.new()
	sink_icon.emoji = "⬇️"
	sink_icon.display_name = "Sink"

	bath.initialize_with_emojis(["🌾", "⬇️"])
	bath.initialize_weighted({"🌾": 1.0, "⬇️": 0.0})

	bath.active_icons = [wheat_icon, sink_icon]
	bath.build_hamiltonian_from_icons(bath.active_icons)
	bath.build_lindblad_from_icons(bath.active_icons)

	# Evolve one step
	var dt = 0.016
	bath.evolve(dt)

	# Check flux
	var flux = bath.get_sink_flux("🌾")

	gut.p("Flux accumulated: %.6f (expected ~%.6f)" % [flux, 0.3 * dt * 1.0])

	# Flux should be approximately rate * dt * P(wheat)
	var expected_flux = 0.3 * dt * 1.0
	assert_almost_eq(flux, expected_flux, 0.001,
		"Flux should match rate * dt * P(emoji)")

	gut.p("✅ PASSED: Sink flux correctly accumulated")


## Test: Flux conservation
func test_flux_conservation():
	gut.p("=== Testing flux conservation ===")

	var bath = QuantumBath.new()
	var icon_registry = get_node_or_null("/root/IconRegistry")

	var wheat_icon = icon_registry.get_icon("🌾")
	wheat_icon.is_drain_target = true
	wheat_icon.drain_to_sink_rate = 0.2

	var sink_icon = Icon.new()
	sink_icon.emoji = "⬇️"
	sink_icon.display_name = "Sink"

	bath.initialize_with_emojis(["🌾", "⬇️"])
	bath.initialize_weighted({"🌾": 0.7, "⬇️": 0.3})

	bath.active_icons = [wheat_icon, sink_icon]
	bath.build_hamiltonian_from_icons(bath.active_icons)
	bath.build_lindblad_from_icons(bath.active_icons)

	var p_wheat_before = bath.get_probability("🌾")
	var p_sink_before = bath.get_probability("⬇️")

	# Evolve
	var dt = 0.016
	var total_flux = 0.0

	for i in range(60):  # 1 second at 60 FPS
		bath.evolve(dt)
		total_flux += bath.get_sink_flux("🌾")

	var p_wheat_after = bath.get_probability("🌾")
	var p_sink_after = bath.get_probability("⬇️")

	var wheat_lost = p_wheat_before - p_wheat_after
	var sink_gained = p_sink_after - p_sink_before

	gut.p("Wheat lost: %.6f" % wheat_lost)
	gut.p("Sink gained: %.6f" % sink_gained)
	gut.p("Total flux: %.6f" % total_flux)

	# Conservation: wheat lost ≈ sink gained
	assert_almost_eq(wheat_lost, sink_gained, 0.01,
		"Wheat loss should equal sink gain (conservation)")

	# Total flux should approximately match sink gain
	assert_almost_eq(total_flux, sink_gained, 0.02,
		"Accumulated flux should match sink gain")

	gut.p("✅ PASSED: Flux conservation verified")


## Test: Multiple drain targets
func test_multiple_drain_targets():
	gut.p("=== Testing multiple drain targets ===")

	var bath = QuantumBath.new()
	var icon_registry = get_node_or_null("/root/IconRegistry")

	var wheat_icon = icon_registry.get_icon("🌾")
	wheat_icon.is_drain_target = true
	wheat_icon.drain_to_sink_rate = 0.2

	var death_icon = icon_registry.get_icon("💀")
	death_icon.is_drain_target = true
	death_icon.drain_to_sink_rate = 0.3

	var sink_icon = Icon.new()
	sink_icon.emoji = "⬇️"
	sink_icon.display_name = "Sink"

	bath.initialize_with_emojis(["🌾", "💀", "⬇️"])
	bath.initialize_weighted({"🌾": 0.5, "💀": 0.5, "⬇️": 0.0})

	bath.active_icons = [wheat_icon, death_icon, sink_icon]
	bath.build_hamiltonian_from_icons(bath.active_icons)
	bath.build_lindblad_from_icons(bath.active_icons)

	# Evolve
	var dt = 0.016
	bath.evolve(dt)

	var flux_wheat = bath.get_sink_flux("🌾")
	var flux_death = bath.get_sink_flux("💀")

	gut.p("Flux from wheat: %.6f" % flux_wheat)
	gut.p("Flux from death: %.6f" % flux_death)

	# Both should have non-zero flux
	assert_gt(flux_wheat, 0.0, "Wheat should drain to sink")
	assert_gt(flux_death, 0.0, "Death should drain to sink")

	# Death should have higher flux (higher rate)
	assert_gt(flux_death, flux_wheat,
		"Higher drain rate should produce more flux")

	gut.p("✅ PASSED: Multiple drain targets work correctly")


## Test: Zero initial sink population
func test_zero_initial_sink_population():
	gut.p("=== Testing sink starts at zero population ===")

	var bath = QuantumBath.new()
	var icon_registry = get_node_or_null("/root/IconRegistry")

	var wheat_icon = icon_registry.get_icon("🌾")
	wheat_icon.is_drain_target = true
	wheat_icon.drain_to_sink_rate = 0.4

	var sink_icon = Icon.new()
	sink_icon.emoji = "⬇️"
	sink_icon.display_name = "Sink"

	# Inject wheat, then sink (block-embedding)
	bath.initialize_with_emojis(["🌾"])
	bath.initialize_weighted({"🌾": 1.0})

	# Inject sink with zero amplitude
	bath.inject_emoji("⬇️", sink_icon, Complex.zero())

	var p_sink_initial = bath.get_probability("⬇️")

	gut.p("Sink initial probability: %.6f (should be 0.0)" % p_sink_initial)

	assert_almost_eq(p_sink_initial, 0.0, 1e-6,
		"Sink should start at zero population (block-embedding)")

	# Build operators and evolve
	bath.active_icons = [wheat_icon, sink_icon]
	bath.build_hamiltonian_from_icons(bath.active_icons)
	bath.build_lindblad_from_icons(bath.active_icons)

	# Evolve
	for i in range(60):
		bath.evolve(0.016)

	var p_sink_after = bath.get_probability("⬇️")

	gut.p("Sink probability after evolution: %.6f" % p_sink_after)

	# Sink should have accumulated population
	assert_gt(p_sink_after, 0.0,
		"Sink should accumulate population from drain")

	gut.p("✅ PASSED: Sink correctly starts at zero and accumulates")


## Test: Lindblad term structure
func test_lindblad_drain_term_structure():
	gut.p("=== Testing Lindblad drain term structure ===")

	var bath = QuantumBath.new()
	var icon_registry = get_node_or_null("/root/IconRegistry")

	var wheat_icon = icon_registry.get_icon("🌾")
	wheat_icon.is_drain_target = true
	wheat_icon.drain_to_sink_rate = 0.5

	var sink_icon = Icon.new()
	sink_icon.emoji = "⬇️"
	sink_icon.display_name = "Sink"

	bath.initialize_with_emojis(["🌾", "⬇️"])
	bath.initialize_weighted({"🌾": 1.0, "⬇️": 0.0})

	bath.active_icons = [wheat_icon, sink_icon]
	bath.build_hamiltonian_from_icons(bath.active_icons)
	bath.build_lindblad_from_icons(bath.active_icons)

	# Check Lindblad terms
	var terms = bath._lindblad.get_terms()

	gut.p("Total Lindblad terms: %d" % terms.size())

	# Find drain term
	var found_drain = false
	for term in terms:
		if term.type == "drain":
			found_drain = true
			gut.p("Found drain term: %s → %s, rate=%.3f" % [
				term.source, term.target, term.rate
			])

			assert_eq(term.source, "🌾", "Drain source should be wheat")
			assert_eq(term.target, "⬇️", "Drain target should be sink")
			assert_almost_eq(term.rate, 0.5, 1e-6, "Drain rate should match Icon")

	assert_true(found_drain, "Should find drain term in Lindblad operators")

	gut.p("✅ PASSED: Drain term structure correct")
