class_name BiomeQuantumSystemBuilder
extends RefCounted

## Quantum System Builder Component
##
## Handles:
## - build_operators_from_icons() - Build H and L from Array[Icon] (icon-cloud path)
## - expand_quantum_system() - Add qubit axis at runtime, rebuild operators
## - inject_coupling() - Add Hamiltonian coupling at runtime


# Signals
signal coupling_updated(emoji_a: String, emoji_b: String, strength: float)

# Injected dependencies
var quantum_computer = null
var resource_registry = null  # BiomeResourceRegistry
var atom_components: Dictionary = {}  # biome's authoritative L/decay spec


func set_dependencies(qc, res_registry, atoms: Dictionary = {}) -> void:
	quantum_computer = qc
	resource_registry = res_registry
	atom_components = atoms if atoms is Dictionary else {}


# ============================================================================
# Quantum System Expansion (BUILD Mode)
# ============================================================================

func expand_quantum_system(north_emoji: String, south_emoji: String) -> Dictionary:
	# Expand the biome's quantum computer to include a new emoji axis.

	# Adds a new qubit axis to the quantum system, rebuilds Hamiltonian and
	# Lindblad operators with coupling terms from the faction/icon system.

	# Rejects if EITHER emoji is already in the biome (prevents axis conflicts).

	# Args:
	# north_emoji: North pole emoji (|0> basis state)
	# south_emoji: South pole emoji (|1> basis state)

	# Returns:
	# Dictionary with:
	# - success: bool
	# - error: String (if failure)
	# - qubit_index: int (new qubit index if success)
	# - old_dim: int (dimension before expansion)
	# - new_dim: int (dimension after expansion)
	# 1. Check if quantum_computer exists
	if not quantum_computer:
		return {
			"success": false,
			"error": "no_quantum_computer",
			"message": "Biome has no quantum computer to expand"
		}

	# 2. Reject if EITHER emoji already exists (prevents axis conflicts)
	if quantum_computer.register_map.has(north_emoji):
		return {
			"success": false,
			"error": "emoji_conflict",
			"message": "Emoji %s already exists in this biome" % north_emoji
		}
	if quantum_computer.register_map.has(south_emoji):
		return {
			"success": false,
			"error": "emoji_conflict",
			"message": "Emoji %s already exists in this biome" % south_emoji
		}

	# 5. Record old dimension
	var old_dim = quantum_computer.register_map.dim()
	var old_num_qubits = quantum_computer.register_map.num_qubits

	# 6. Add new axis to quantum computer
	var new_qubit_index = old_num_qubits
	quantum_computer.allocate_axis(new_qubit_index, north_emoji, south_emoji)

	# 7. Update resource_registry emoji pairings
	if resource_registry:
		resource_registry.add_emoji_pair_to_producible(north_emoji, south_emoji)

	# 8. Build Icon list from the expanded register_map axes (H from icons.json).
	var HamBuilder = load("res://Core/QuantumSubstrate/HamiltonianBuilder.gd")
	var LindBuilder = load("res://Core/QuantumSubstrate/LindbladBuilder.gd")
	var IconRegistryCls = load("res://Core/Factions/IconRegistry.gd")
	var IconCls = load("res://Core/QuantumSubstrate/Icon.gd")
	var verbose = (Engine.get_main_loop().root.get_node_or_null("/root/VerboseConfig") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	var lexicon = (Engine.get_main_loop().root.get_node_or_null("/root/IconRegistry") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if lexicon == null:
		lexicon = IconRegistryCls.new()  # test harness fallback

	var biome_icons: Array = []
	for q in range(quantum_computer.register_map.num_qubits):
		var axis = quantum_computer.register_map.axes.get(q, {})
		var north: String = str(axis.get("north", ""))
		var south: String = str(axis.get("south", ""))
		if north == "" or south == "":
			continue
		var physics = lexicon.get_icon_physics_by_pair(north, south)
		var rec = lexicon.find_icon_by_pair(north, south)
		var iname: String = str(rec.get("name", north)) if not rec.is_empty() else north
		biome_icons.append(IconCls.from_pair_physics(iname, north, south, physics, 1.0))

	# 9. Rebuild H from icons.json; rebuild L from biome.atom_components.
	# Primed terms whose endpoints are now in basis activate automatically.
	quantum_computer.hamiltonian = HamBuilder.build_from_icons(biome_icons, quantum_computer.register_map, verbose)
	var lindblad_result = LindBuilder.build_from_atoms(atom_components, quantum_computer.register_map, verbose, quantum_computer.biome_name)
	quantum_computer.lindblad_operators = lindblad_result.get("operators", [])

	# 9b. Extract and set time-dependent driver configurations.
	var driven_configs = HamBuilder.get_driven_icons(biome_icons, quantum_computer.register_map)
	quantum_computer.set_driven_icons(driven_configs)

	# Reset to ground state after expanding basis (preserves ecological biases)
	quantum_computer.initialize_ground_state()

	var new_dim = quantum_computer.register_map.dim()

	VerboseHelper.info("quantum", "expand", "Expanded %s quantum system: %d -> %d qubits (%dD -> %dD)" % [
		quantum_computer.biome_name if quantum_computer else "Unknown", old_num_qubits, new_qubit_index + 1, old_dim, new_dim])
	VerboseHelper.info("quantum", "expand", "New axis: %s <-> %s (qubit %d)" % [north_emoji, south_emoji, new_qubit_index])

	return {
		"success": true,
		"qubit_index": new_qubit_index,
		"old_dim": old_dim,
		"new_dim": new_dim,
		"north_emoji": north_emoji,
		"south_emoji": south_emoji
	}


func inject_coupling(emoji_a: String, emoji_b: String, strength: float) -> Dictionary:
	# Inject a Hamiltonian coupling between two existing axes.

	# Unlike expand_quantum_system(), this does NOT add new qubits.
	# It modifies the Hamiltonian to create ZZ dynamics between existing axes.

	# Args:
	# emoji_a: First emoji (must exist in register_map)
	# emoji_b: Second emoji (must exist in register_map)
	# strength: Coupling strength J (ZZ interaction term)

	# Returns:
	# Dictionary with success/error keys
	if not quantum_computer:
		return {"success": false, "error": "no_quantum_computer"}

	var rm = quantum_computer.register_map
	if not rm.has(emoji_a):
		return {"success": false, "error": "missing_emoji", "emoji": emoji_a}
	if not rm.has(emoji_b):
		return {"success": false, "error": "missing_emoji", "emoji": emoji_b}

	# Get qubit indices for the emojis
	var qubit_a = rm.qubit(emoji_a)
	var qubit_b = rm.qubit(emoji_b)

	if qubit_a == -1 or qubit_b == -1:
		return {"success": false, "error": "qubit_lookup_failed"}

	# Add coupling to Hamiltonian via QuantumComputer
	var result = quantum_computer.add_coupling(qubit_a, qubit_b, strength)

	if result.success:
		coupling_updated.emit(emoji_a, emoji_b, strength)
		VerboseHelper.info("quantum", "coupling", "Injected coupling: %s <-> %s (J=%.3f)" % [emoji_a, emoji_b, strength])

	return result


# ============================================================================
# Operator Building with Caching
# ============================================================================

## Build H from Array[Icon] (icons.json physics) and L from atom_components, with caching.
func build_operators_from_icons(biome_name: String, biome_icons: Array, atoms: Dictionary = {}) -> void:
	if not quantum_computer:
		push_error("build_operators_from_icons: quantum_computer not set")
		return
	# Adopt the biome's atom_components as the L/decay authority for this builder.
	if not atoms.is_empty():
		atom_components = atoms
	var verbose = (Engine.get_main_loop().root.get_node_or_null("/root/VerboseConfig") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	# Cache key MUST reflect every input that affects H or L. If it doesn't,
	# editing icons.json physics fields silently serves stale operators.
	# Always include atom_components signature (even when empty) so the first
	# transition to non-empty atoms misses the cache instead of hitting it.
	var icon_sigs: PackedStringArray = []
	for icon in biome_icons:
		icon_sigs.append("%s|%s|se0=%.6f|se1=%.6f|rabi=%.6f|hc=%s|drv=%s" % [
			icon.pole_0, icon.pole_1,
			icon.self_energy_0, icon.self_energy_1, icon.rabi_coupling,
			JSON.stringify(icon.hamiltonian_couplings),
			"%s/%.6f/%.6f/%.6f" % [icon.self_energy_driver, icon.driver_frequency, icon.driver_phase, icon.driver_amplitude]
		])
	# The dissipative switch is part of the key: with it off no Lindblad operators are
	# built, so a coherent-only cache entry must never be served when dissipation is on
	# (or vice versa). Coherent state doesn't change which operators are built (H is always
	# constructed), so only the dissipative flag gates the operator set.
	var diss := "L1" if BalanceConfig.dissipative_enabled() else "L0"
	var cache_key := biome_name + "_icons_" + "|".join(icon_sigs).md5_text() + "_atoms_" + JSON.stringify(atom_components).md5_text() + "_" + diss

	var cache = OperatorCache.get_instance()
	var cached_ops = cache.try_load(biome_name, cache_key)
	var HamBuilder = load("res://Core/QuantumSubstrate/HamiltonianBuilder.gd")
	var LindBuilder = load("res://Core/QuantumSubstrate/LindbladBuilder.gd")

	var driven: Array = []

	if not cached_ops.is_empty():
		quantum_computer.hamiltonian = cached_ops.hamiltonian
		quantum_computer.lindblad_operators = cached_ops.lindblad_operators
		driven = HamBuilder.get_driven_icons(biome_icons, quantum_computer.register_map)
		quantum_computer.set_driven_icons(driven)
		if verbose:
			verbose.info("cache", "✅", "Operator cache HIT: %s" % biome_name)
		return

	if verbose:
		verbose.info("cache", "🔨", "Operator cache MISS: building %s" % biome_name)
	var start_time = Time.get_ticks_msec()

	quantum_computer.hamiltonian = HamBuilder.build_from_icons(
			biome_icons, quantum_computer.register_map, verbose)
	var lindblad_result = LindBuilder.build_from_atoms(
			atom_components, quantum_computer.register_map, verbose, biome_name)
	quantum_computer.lindblad_operators = lindblad_result.get("operators", [])
	driven = HamBuilder.get_driven_icons(biome_icons, quantum_computer.register_map)
	quantum_computer.set_driven_icons(driven)

	var elapsed = Time.get_ticks_msec() - start_time
	if verbose:
		verbose.info("cache", "💾", "Operators built in %d ms — caching" % elapsed)
	cache.save(biome_name, cache_key, quantum_computer.hamiltonian, quantum_computer.lindblad_operators)
