class_name PlotRegisterResolver
extends RefCounted

## THE slot→qubit law. One authority shared by the display (register bubbles),
## gate targeting (druid verbs), and Lindblad plumbing.
##
## Law: plot column ≡ register_id (plot_idx ≡ register_id invariant). A bound
## plot's terminal/projection binding is the primary source (it was bound BY
## this law at explore/measure time). An unbound plot projects its grid
## column, BOUNDED by the biome's qubit count — a column beyond it has NO
## bubble on screen and therefore NO target: resolution REFUSES (-1).
##
## History: gate targeting used to wrap with posmod(slot_index, num_qubits),
## so a druid gate on an empty slot silently spun ANOTHER plot's qubit
## ("J spins the sun/moon despite displaying the Skull", playtest 2). Wrapping
## is banned; refusal is loud (message flows to the player via _run_action).


static func resolve(farm, position: Vector2i) -> Dictionary:
	# Returns {biome, biome_name, register_id, num_qubits, reason}.
	# register_id == -1 → no valid target; `reason` says why (for honest toasts).
	var out := {
		"biome": null,
		"biome_name": "",
		"register_id": -1,
		"num_qubits": 0,
		"reason": "",
	}
	if not farm or not farm.grid:
		out["reason"] = "no_farm"
		return out

	var plot = farm.grid.get_plot(position)
	if plot and plot.is_active():
		# Primary authority: the plot's live binding (terminal-delegating).
		var bound_name: String = str(plot.bound_biome_name)
		var biome = farm.grid.get_biome(bound_name) if bound_name != "" else null
		if biome:
			out["biome"] = biome
			out["biome_name"] = bound_name
			out["num_qubits"] = _num_qubits(biome)
			out["register_id"] = int(plot.bound_register_id)
			return out

	# Projection: the biome assigned to this slot + the column law, bounded.
	var assigned_name: String = str(farm.grid.get_plot_biome_assignment(position))
	if assigned_name == "":
		out["reason"] = "no_biome_at_slot"
		return out
	var assigned = farm.grid.get_biome(assigned_name)
	if assigned == null:
		out["reason"] = "biome_not_loaded"
		return out
	out["biome"] = assigned
	out["biome_name"] = assigned_name
	var nq := _num_qubits(assigned)
	out["num_qubits"] = nq
	if position.x >= 0 and position.x < nq:
		out["register_id"] = position.x
	else:
		out["reason"] = "no_qubit_at_slot"
	return out


static func _num_qubits(biome) -> int:
	# register_map is the mechanics truth; viz_cache is its projection.
	if biome and biome.quantum_computer and biome.quantum_computer.register_map:
		return int(biome.quantum_computer.register_map.num_qubits)
	if biome and biome.viz_cache and biome.viz_cache.has_method("get_num_qubits"):
		return int(biome.viz_cache.get_num_qubits())
	return 0
