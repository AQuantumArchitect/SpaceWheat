class_name SpectralPreview
extends RefCounted

## Pure what-if spectral gap: "if this biome's register held THESE axes, what
## would its H-gap be?" — the number the ending literally gates on
## (island_free: Village gap ≤ 0.55), computable BEFORE committing a plant or
## a trim. Side-effect free by construction (first-source law):
##   - fresh RegisterMap, never the biome's
##   - icons via BiomeQuantumSystemBuilder.icons_from_axes — the SAME
##     derivation the live rebuild uses, one authority, no drift
##   - H via the static HamiltonianBuilder.build_from_icons
##   - gap via QuantumComputer.gap_of_hamiltonian — the SAME packing trick
##     the live read uses, on a PRIVATE eigensolver instance
## Returns -1.0 on any failure or above the cost guard (dense eigensolve is
## O(dim³); past dim 256 the preview honestly says "—" instead of hitching).
##
## Results cache on (physics_signature, pair): physics_signature already
## fingerprints every input that determines H, so it is the exact right key —
## any plant/trim/coupling change mints a new signature and misses the cache.

const MAX_PREVIEW_DIM := 256

# Explicit preloads — bare class_name identifiers are compile bombs under
# --check-only harnesses. (QuantumEvolutionEngine is the native extension
# class, a true global.)
const RegisterMapCls = preload("res://Core/QuantumSubstrate/RegisterMap.gd")
const BuilderCls = preload("res://Core/Environment/Components/BiomeQuantumSystemBuilder.gd")
const HamiltonianBuilderCls = preload("res://Core/QuantumSubstrate/HamiltonianBuilder.gd")
const QuantumComputerCls = preload("res://Core/QuantumSubstrate/QuantumComputer.gd")

static var _engine = null
static var _cache: Dictionary = {}


## Gap for an arbitrary axis list [{north, south}, ...]. -1.0 = unmeasurable.
static func gap_for_axes(axes: Array, lexicon = null) -> float:
	if axes.is_empty():
		return -1.0
	var dim := 1 << axes.size()
	if dim > MAX_PREVIEW_DIM:
		return -1.0
	var rm = RegisterMapCls.new()
	for i in range(axes.size()):
		rm.register_axis(i, str(axes[i].get("north", "")), str(axes[i].get("south", "")))
	var icons: Array = BuilderCls.icons_from_axes(axes, lexicon)
	if icons.is_empty():
		return -1.0
	var h = HamiltonianBuilderCls.build_from_icons(icons, rm)
	if h == null:
		return -1.0
	if _engine == null:
		_engine = QuantumEvolutionEngine.new()
	return QuantumComputerCls.gap_of_hamiltonian(h, dim, _engine)


## The live biome's axes + one candidate pair appended (the Icon-R plant).
static func preview_gap_with(biome, north: String, south: String) -> float:
	var key := "%s|+|%s|%s" % [_signature_of(biome), north, south]
	if _cache.has(key):
		return float(_cache[key])
	var axes := _live_axes(biome)
	if axes.is_empty():
		return -1.0
	axes.append({"north": north, "south": south})
	var g := gap_for_axes(axes)
	_remember(key, g)
	return g


## The live biome's axes minus qubit q (the Icon-Q trim).
static func preview_gap_without(biome, qubit_index: int) -> float:
	var key := "%s|-|%d" % [_signature_of(biome), qubit_index]
	if _cache.has(key):
		return float(_cache[key])
	var axes := _live_axes(biome)
	if qubit_index < 0 or qubit_index >= axes.size():
		return -1.0
	axes.remove_at(qubit_index)
	var g := gap_for_axes(axes)
	_remember(key, g)
	return g


static func _live_axes(biome) -> Array:
	if biome == null or biome.get("quantum_computer") == null \
			or biome.quantum_computer.register_map == null:
		return []
	var rm = biome.quantum_computer.register_map
	var axes: Array = []
	for q in range(rm.num_qubits):
		var axis = rm.axes.get(q, {})
		axes.append({"north": str(axis.get("north", "")), "south": str(axis.get("south", ""))})
	return axes


static func _signature_of(biome) -> String:
	if biome != null and biome.get("quantum_computer") != null \
			and "physics_signature" in biome.quantum_computer:
		return str(biome.quantum_computer.physics_signature)
	return "?"


static func _remember(key: String, g: float) -> void:
	if _cache.size() > 128:
		_cache.clear()  # bounded; a rare re-solve beats a leak
	_cache[key] = g
