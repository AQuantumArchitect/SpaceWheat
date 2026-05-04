extends SceneTree

## tests/pair_offers_smoke.gd — smoke test for MarketLattice.propose_pair_offers.
## Builds Village + HearthKeepers, evolves both, asks the lattice for pair offers,
## prints what shows up.
##
## Run: godot --headless --quit --script tests/pair_offers_smoke.gd

const BiomeBuilder = preload("res://Core/Biomes/BiomeBuilder.gd")
const BiomeRegistry = preload("res://Core/Biomes/BiomeRegistry.gd")
const FactionRegistry = preload("res://Core/Factions/FactionRegistry.gd")
const FactionDensityMatrix = preload("res://Core/Factions/FactionDensityMatrix.gd")
const MarketLattice = preload("res://Core/Markets/MarketLattice.gd")


class FakeFarm:
	extends RefCounted
	var faction_density: FactionDensityMatrix
	var economy = null
	var grid = null


func _init() -> void:
	print("\n=== pair offers smoke ===")
	var br := BiomeRegistry.new()
	var v_spec = br.get_by_name("Village")
	var h_spec = br.get_by_name("HearthKeepers")
	var root := Node.new()
	get_root().add_child(root)
	var v_res := BiomeBuilder.build_from_spec(v_spec, root, {"skip_tree_add": true})
	var h_res := BiomeBuilder.build_from_spec(h_spec, root, {"skip_tree_add": true})
	if not v_res.success or not h_res.success:
		printerr("build failed: %s / %s" % [v_res.error, h_res.error])
		quit(1)
		return

	var v_biome = v_res.biome_node
	var h_biome = h_res.biome_node

	# Settle ~10s so marginals diverge.
	for _i in range(20):
		v_biome.quantum_computer.evolve(0.5, 0.02, null)
		h_biome.quantum_computer.evolve(0.5, 0.02, null)

	var farm := FakeFarm.new()
	farm.faction_density = FactionDensityMatrix.new()

	var lattice := MarketLattice.new(farm)
	var offers: Array = lattice.propose_pair_offers(v_biome, h_biome, 6)

	print("  offers proposed: %d" % offers.size())
	print("  ----------------------------------------------------------------")
	print("  %-3s %-20s %-7s %-9s %-10s %-7s %-7s" % ["#", "settlement biome", "deliver", "cost emoji", "cost qty", "tension", "shared?"])
	for i in range(offers.size()):
		var c = offers[i]
		var tension = c.get_meta("tension", 0.0) if c.has_meta("tension") else 0.0
		var shared = c.get_meta("shared", false) if c.has_meta("shared") else false
		print("  %-3d %-20s %-7s %-9s %-10.2f %-7.3f %s" % [
			i + 1, c.biome_name, c.resource, c.cost_emoji, c.cost_amount, tension, "yes" if shared else "no"
		])
	print("\n=== smoke done ===")
	quit(0)
