extends SceneTree

## StarterForest dynamics probe.
##
## Builds the live biome, then samples key axis marginals across a short
## Hamiltonian window and a longer Lindblad-dominated window.


const SAMPLE_TIMES: Array[float] = [0.0, 0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0]
const SAMPLE_DT: float = 0.25

const AXES: Array[Array] = [
	["☀", "🌙", "CelestialCycle"],
	["🦅", "🐇", "Raptor"],
	["🐺", "🦌", "PackHerd"],
	["🌱", "🌲", "Succession"],
	["🍂", "🌿", "Humus"],
	["🍄", "💀", "Mycelium"],
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== StarterForest dynamics probe ===")

	var root := Node.new()
	root.name = "StarterForestProbeRoot"
	get_root().add_child(root)

	var res: Dictionary = BiomeBuilder.build_from_registry("StarterForest", root, {"skip_tree_add": true})
	if not bool(res.get("success", false)):
		printerr("StarterForest build failed: %s" % str(res.get("error", "")))
		quit(1)
		return

	var biome: Node = res.get("biome_node", null)
	var qc: Object = res.get("quantum_computer", null)
	if biome == null or qc == null:
		printerr("StarterForest build returned null biome/qc")
		quit(1)
		return

	root.add_child(biome)

	print("qubits=%d  dim=%d  icons=%d  lindblad_ops=%d" % [
		qc.register_map.num_qubits,
		qc.register_map.dim(),
		biome.icons.size(),
		qc.lindblad_operators.size(),
	])
	print("time | ☀/🌙 | 🦅/🐇 | 🐺/🦌 | 🌱/🌲 | 🍂/🌿 | 🍄/💀")
	print("-----+------+------+------+------+------+------")

	var current_time: float = 0.0
	_print_row(qc, current_time)
	for target_time in SAMPLE_TIMES:
		if target_time <= current_time:
			continue
		var remaining: float = target_time - current_time
		qc.evolve(remaining, SAMPLE_DT, null)
		current_time = target_time
		_print_row(qc, current_time)

	print("\n=== dynamics probe done ===")
	root.queue_free()
	quit(0)


func _print_row(qc, t: float) -> void:
	var cells: Array[String] = []
	for axis in AXES:
		var north: String = str(axis[0])
		var south: String = str(axis[1])
		var label: String = str(axis[2])
		var p_n: float = _marg(qc, north)
		var p_s: float = _marg(qc, south)
		cells.append("%s %.3f/%.3f" % [label, p_n, p_s])
	print("%4.2f | %s" % [t, " | ".join(cells)])


func _marg(qc, emoji: String) -> float:
	if qc == null or not qc.has_method("get_population"):
		return NAN
	return float(qc.get_population(emoji))
