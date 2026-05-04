@tool
extends SceneTree

## tests/contract_market_smoke.gd — verify QuantumContractEngine is
## registered and can produce a non-trivial bid under a minimal scenario.
##
## Run: godot --headless -s tests/contract_market_smoke.gd
##
## This is substrate-only: the engine doesn't need to be wired into
## QuestManager to pass. We just confirm the native class answers.

const NATIVE_CLASS := "QuantumContractEngine"


func _init() -> void:
	print("\n=== CONTRACT MARKET SMOKE TEST ===")
	if not ClassDB.class_exists(NATIVE_CLASS):
		print("❌ FAIL: %s class not registered — build native/ first" % NATIVE_CLASS)
		quit(1)
		return

	var engine = ClassDB.instantiate(NATIVE_CLASS)
	if engine == null:
		print("❌ FAIL: cannot instantiate %s" % NATIVE_CLASS)
		quit(1)
		return
	print("✓ Instantiated %s" % NATIVE_CLASS)

	# Minimal scenario: one faction, one resource, modest attention.
	var biome_bits := [0.6, 0.4, 0.3, 0.5, 0.7, 0.5, 0.4, 0.5, 0.6, 0.5, 0.5, 0.5]
	var player_bits := [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5]
	var faction_bits := [0.7, 0.3, 0.2, 0.4, 0.6, 0.5, 0.5, 0.5, 0.7, 0.5, 0.6, 0.4]

	engine.set_time(0.0)
	engine.set_biome_bits(biome_bits)
	engine.set_player_bits(player_bits)
	engine.set_market_biome_bits(biome_bits, 0.6, 0.5, 0.6)
	engine.set_spectral_signal(1.2, 0.35, 0.25, 0.75, biome_bits)
	engine.add_faction("Hearth Keepers", faction_bits, 0.5, 0.2)
	engine.set_faction_hamiltonian_drive("Hearth Keepers", 0.4)
	engine.set_resource("🌾", 20.0, 30.0, 5.0, 0.2)
	engine.set_resource("🍞", 10.0, 25.0, 3.0, 0.3)
	engine.add_icon("Harvest", "🌾", "🍞", "Hearth Keepers", faction_bits)

	var offers: Array = engine.generate_resource_bids(["🌾", "🍞"], 2)
	print("  Offers generated: %d" % offers.size())
	if offers.is_empty():
		print("❌ FAIL: engine produced zero bids in scenario with strong demand + attention")
		quit(1)
		return

	var first: Dictionary = offers[0]
	print("  First offer keys: %s" % [first.keys()])
	print("  First offer sample: faction=%s resource=%s qty=%.1f score=%.3f" % [
		first.get("faction", "?"),
		first.get("resource", "?"),
		float(first.get("quantity", 0.0)),
		float(first.get("market_score", 0.0)),
	])

	print("\n✅ CONTRACT MARKET SMOKE PASS — engine live, %d resource offers generated" % offers.size())
	quit(0)
