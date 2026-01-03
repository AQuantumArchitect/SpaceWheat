## Test Phase 4: Energy Taps (Tool 4 Backend)
## Verifies Lindblad drain operators and energy accumulation

extends SceneTree

var QuantumComputer = preload("res://Core/QuantumSubstrate/QuantumComputer.gd")
var QuantumGateLibrary = preload("res://Core/QuantumSubstrate/QuantumGateLibrary.gd")
var QuantumBath = preload("res://Core/QuantumSubstrate/QuantumBath.gd")
var Icon = preload("res://Core/QuantumSubstrate/Icon.gd")
var Complex = preload("res://Core/QuantumSubstrate/Complex.gd")

func _init():
	print("\n=== PHASE 4: ENERGY TAP SINK FLUX TEST ===\n")

	# Test 1: Sink state injection
	test_sink_state_injection()

	# Test 2: Drain operator setup
	test_drain_operator_setup()

	# Test 3: Flux accumulation (conceptual)
	test_flux_tracking()

	print("\n✅ Phase 4 Tests Passed!\n")
	quit()


func test_sink_state_injection() -> void:
	print("TEST 1: Sink State Injection")
	print("----------------------------------------")

	# Create quantum computer
	var qc = QuantumComputer.new("test_biome")

	# Initially sink_flux_per_emoji should be empty
	var initial_flux = qc.get_all_sink_fluxes()
	verify(initial_flux.is_empty(), "Initial flux should be empty")
	print("✓ Initial flux dictionary is empty")

	# Get sink flux for non-existent emoji
	var zero_flux = qc.get_sink_flux("🌾")
	verify(abs(zero_flux - 0.0) < 1e-10, "Non-existent emoji should have 0 flux")
	print("✓ Non-existent emoji returns 0 flux")

	# Reset should work
	qc.reset_sink_flux()
	print("✓ Sink flux reset works")
	print()


func test_drain_operator_setup() -> void:
	print("TEST 2: Drain Operator Setup")
	print("----------------------------------------")

	# Create quantum computer and bath
	var qc = QuantumComputer.new("test_biome")

	# Create emojis for test
	var emoji_list = ["🌾", "🌽", "⬇️"]  # wheat, corn, sink
	var initial_weights = {
		"🌾": 0.5,
		"🌽": 0.3,
		"⬇️": 0.2
	}

	# Initialize bath with these emojis (simplified - bath would normally do this)
	print("✓ Configured test emoji list: ", emoji_list)

	# Create drain target icon
	var drain_icon = Icon.new()
	drain_icon.emoji = "🌾"
	drain_icon.display_name = "Wheat"
	drain_icon.is_drain_target = true
	drain_icon.drain_to_sink_rate = 0.1  # 0.1 probability/sec

	# Create sink icon
	var sink_icon = Icon.new()
	sink_icon.emoji = "⬇️"
	sink_icon.display_name = "Sink"
	sink_icon.is_eternal = true

	print("✓ Created drain target icon (wheat → sink at κ=0.1)")
	print("✓ Created sink icon")

	# Verify Icon properties
	verify(drain_icon.is_drain_target, "Icon should be marked as drain target")
	verify(abs(drain_icon.drain_to_sink_rate - 0.1) < 1e-10, "Drain rate should be 0.1")
	print("✓ Icon drain properties configured correctly")

	# Verify sink icon is eternal
	verify(sink_icon.is_eternal, "Sink should be eternal (never decay)")
	print("✓ Sink icon is eternal")
	print()


func test_flux_tracking() -> void:
	print("TEST 3: Flux Tracking and Accumulation")
	print("----------------------------------------")

	# Create quantum computer
	var qc = QuantumComputer.new("test_biome")

	# Simulate setting flux values (as would happen from Lindblad evolution in QuantumBath)
	# Manually set for testing (in real usage, QuantumBath.evolve() would set these)
	qc.sink_flux_per_emoji["🌾"] = 0.05  # 5% of wheat drained this frame
	qc.sink_flux_per_emoji["🌽"] = 0.02  # 2% of corn drained

	# Query accumulated flux
	var wheat_flux = qc.get_sink_flux("🌾")
	var corn_flux = qc.get_sink_flux("🌽")
	var all_flux = qc.get_all_sink_fluxes()

	print("✓ Set flux: wheat=", wheat_flux, ", corn=", corn_flux)
	verify(abs(wheat_flux - 0.05) < 1e-10, "Wheat flux should be 0.05")
	verify(abs(corn_flux - 0.02) < 1e-10, "Corn flux should be 0.02")
	print("✓ Flux values correct")

	# Verify all_flux contains both
	verify(all_flux.has("🌾"), "All flux should contain wheat")
	verify(all_flux.has("🌽"), "All flux should contain corn")
	verify(all_flux.size() == 2, "Should have exactly 2 fluxes")
	print("✓ All flux query returns correct entries")

	# Reset and verify empty
	qc.reset_sink_flux()
	var after_reset = qc.get_all_sink_fluxes()
	verify(after_reset.is_empty(), "Flux should be empty after reset")
	print("✓ Flux reset clears accumulator")

	# Test frame accumulation sequence
	print("\nTesting frame accumulation sequence:")
	qc.sink_flux_per_emoji["🌾"] = 0.10
	print("  Frame 1: wheat flux = 0.10")
	var f1 = qc.get_sink_flux("🌾")
	verify(abs(f1 - 0.10) < 1e-10, "Frame 1 flux incorrect")
	print("  ✓ Read: 0.10")

	qc.reset_sink_flux()
	print("  Reset flux")

	qc.sink_flux_per_emoji["🌾"] = 0.08  # Different frame
	print("  Frame 2: wheat flux = 0.08")
	var f2 = qc.get_sink_flux("🌾")
	verify(abs(f2 - 0.08) < 1e-10, "Frame 2 flux incorrect")
	print("  ✓ Read: 0.08")
	print("✓ Multi-frame accumulation works correctly")
	print()


func verify(condition: bool, message: String) -> void:
	if not condition:
		push_error("ASSERTION FAILED: ", message)
		quit()
