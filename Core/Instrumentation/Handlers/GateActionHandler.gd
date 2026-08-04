extends RefCounted

## GateActionHandler - Static instrumentation dispatcher for quantum gate operations.
##
## Follows ProbeActions pattern:
## - Static methods only
## - Explicit parameters (no implicit state)
## - Dictionary returns with {success: bool, ...data, error?: String}
## - Single responsibility per method
##
## Gate Injection:
## All gate operations go through GateInjector to ensure the C++ lookahead
## buffer is invalidated after density matrix mutations. This prevents
## stale pre-computed evolution frames from being rendered.



## ============================================================================
## SINGLE-QUBIT GATE OPERATIONS
## ============================================================================

static func apply_pauli_x(farm, positions: Array[Vector2i]) -> Dictionary:
	# Apply Pauli-X gate (bit flip) to selected positions.

	# Flips the qubit state: |0> -> |1>, |1> -> |0>
	return _apply_gate_batch(farm, positions, "X", "Pauli-X")


static func apply_pauli_y(farm, positions: Array[Vector2i]) -> Dictionary:
	# Apply Pauli-Y gate to selected positions.

	# Combines X and Z rotations: |0> -> i|1>, |1> -> -i|0>
	return _apply_gate_batch(farm, positions, "Y", "Pauli-Y")


static func apply_pauli_z(farm, positions: Array[Vector2i]) -> Dictionary:
	# Apply Pauli-Z gate (phase flip) to selected positions.

	# Applies phase flip: |0> -> |0>, |1> -> -|1>
	return _apply_gate_batch(farm, positions, "Z", "Pauli-Z")


static func apply_hadamard(farm, positions: Array[Vector2i]) -> Dictionary:
	# Apply Hadamard gate (superposition) to selected positions.

	# Creates equal superposition from basis states:
	# |0> -> (|0> + |1>)/sqrt(2), |1> -> (|0> - |1>)/sqrt(2)
	return _apply_gate_batch(farm, positions, "H", "Hadamard")


static func apply_s_gate(farm, positions: Array[Vector2i]) -> Dictionary:
	# Apply S gate (pi/2 phase) to selected positions.

	# S = [[1, 0], [0, i]] (square root of Z gate)
	return _apply_gate_batch(farm, positions, "S", "S-gate")


static func apply_t_gate(farm, positions: Array[Vector2i]) -> Dictionary:
	# Apply T gate (pi/4 phase) to selected positions.

	# T = [[1, 0], [0, e^(i*pi/4)]] (enables universal computation)
	return _apply_gate_batch(farm, positions, "T", "T-gate")


static func apply_sdg_gate(farm, positions: Array[Vector2i]) -> Dictionary:
	# Apply S-dagger gate (-pi/2 phase) to selected positions.

	# S-dagger = [[1, 0], [0, -i]] (inverse of S gate)
	return _apply_gate_batch(farm, positions, "Sdg", "S-dagger")


static func apply_tdg_gate(farm, positions: Array[Vector2i]) -> Dictionary:
	# Apply T-dagger gate (-pi/4 phase) to selected positions.

	# T-dagger = [[1, 0], [0, e^(-i*pi/4)]] (inverse of T gate)
	return _apply_gate_batch(farm, positions, "Tdg", "T-dagger")


static func apply_rx_gate(farm, positions: Array[Vector2i]) -> Dictionary:
	# Apply Rx rotation gate to selected positions.

	# Rx(theta) rotation around X-axis. Default theta = pi/4.
	return _apply_gate_batch(farm, positions, "Rx", "Rx-gate")


static func apply_ry_gate(farm, positions: Array[Vector2i]) -> Dictionary:
	# Apply Ry rotation gate to selected positions.

	# Ry(theta) rotation around Y-axis. Default theta = pi/4.
	return _apply_gate_batch(farm, positions, "Ry", "Ry-gate")


static func apply_rz_gate(farm, positions: Array[Vector2i]) -> Dictionary:
	# Apply Rz rotation gate to selected positions.

	# Rz(theta) rotation around Z-axis. Default theta = pi/4.
	return _apply_gate_batch(farm, positions, "Rz", "Rz-gate")


## Golden-angle rotations — the Druid's organic Bloch-sphere step. `direction >= 0` steps +φ,
## `< 0` steps −φ (so rotate_up / rotate_down trace opposite ways around the circle).
static func apply_golden_gate(farm, positions: Array[Vector2i], axis: String, direction: int) -> Dictionary:
	# Library keys are "RxΦ"/"RyΦ"/"RzΦ" (+) and "...Φ-" (−); axis arrives as "X"/"Y"/"Z".
	var base := "R" + axis.to_lower() + "Φ"
	var gate_name := base if direction >= 0 else base + "-"
	return _apply_gate_batch(farm, positions, gate_name, "%s golden-angle" % axis)


## ============================================================================
## PLANT — coherent state preparation (Ace R)
## ============================================================================

## Below this Bloch radius the state is fog — no unitary can help it.
const PLANT_MIN_BLOCH_R: float = 0.05
## Within this cosine of the pole the plot counts as already planted.
const PLANT_ALIGNED_COS: float = 0.999


static func apply_plant(farm, positions: Array[Vector2i]) -> Dictionary:
	# Coherent Rabi pulse toward each plot's north pole (steepest ascent).

	# Reads the register's reduced Bloch vector r from the native packet and
	# rotates it fully onto the pole axis n̂: U = exp(−iα·u·σ/2) with
	# u = (r×n̂)/|r×n̂| and α = angle(r, n̂). Unitary — legal in ANY regime,
	# and purity-preserving BY THEOREM: the pulse aligns the Bloch vector but
	# cannot lengthen it. p_north caps at (1+|r|)/2 — a fog (r ≈ 0) cannot be
	# planted. That refusal is the lesson: coherent control moves states, only
	# dissipation (measurement, the Spark) makes them anew.
	if not farm or not farm.grid:
		return {"success": false, "error": "farm_not_ready", "message": "Farm not loaded"}
	if positions.is_empty():
		return {"success": false, "error": "no_positions", "message": "No plots selected"}

	var planted := 0
	var already := 0
	var fogged := 0
	var failed := 0
	var last_p_north := 0.0
	for pos in positions:
		var resolved = _resolve_biome_register(farm, pos)
		var biome = resolved.get("biome", null)
		var register_id: int = int(resolved.get("register_id", -1))
		if not biome or not biome.quantum_computer or register_id < 0:
			failed += 1
			continue
		var qc = biome.quantum_computer
		var packet: PackedFloat64Array = qc.export_bloch_packet() if qc.has_method("export_bloch_packet") else PackedFloat64Array()
		if packet.size() < (register_id + 1) * 9:
			failed += 1
			continue
		var base := register_id * 9
		var rx := packet[base + 2]
		var ry := packet[base + 3]
		var rz := packet[base + 4]
		var r_len := packet[base + 5]

		# Target axis: the plot's north pole. Pole 0 = |0⟩ = +z by convention
		# (bloch packet z = p0 − p1); flip if this plot's north sits on pole 1.
		var tz := 1.0
		var plot = farm.grid.get_plot(pos)
		var north_emoji: String = str(plot.north_emoji) if plot and plot.is_active() and plot.north_emoji else ""
		if north_emoji != "" and qc.has(north_emoji) and qc.pole(north_emoji) == 1:
			tz = -1.0

		if r_len < PLANT_MIN_BLOCH_R:
			fogged += 1
			continue
		var cos_a: float = clampf((rz * tz) / r_len, -1.0, 1.0)
		if cos_a > PLANT_ALIGNED_COS:
			already += 1
			continue
		var alpha: float = acos(cos_a)

		# Rotation axis u = (r × t̂)/|r × t̂| with t̂ = (0,0,tz): u = (ry·tz, −rx·tz, 0).
		var ux := ry * tz
		var uy := -rx * tz
		var u_len: float = sqrt(ux * ux + uy * uy)
		if u_len < 1e-12:
			# Anti-parallel to the target (parallel is excluded above): any
			# equatorial axis completes the swing — use x̂.
			ux = 1.0
			uy = 0.0
			u_len = 1.0
		ux /= u_len
		uy /= u_len

		# U = cos(α/2)·I − i·sin(α/2)·(ux·σx + uy·σy)   (u_z = 0 always here)
		var c := cos(alpha * 0.5)
		var s := sin(alpha * 0.5)
		var u_mat = ComplexMatrix.new(2)
		u_mat.set_element(0, 0, Complex.new(c, 0.0))
		u_mat.set_element(1, 1, Complex.new(c, 0.0))
		u_mat.set_element(0, 1, Complex.new(-s * uy, -s * ux))
		u_mat.set_element(1, 0, Complex.new(s * uy, -s * ux))

		var inject = GateInjector.inject_gate(biome, register_id, u_mat, farm)
		if inject.get("success", false):
			planted += 1
			last_p_north = (1.0 + r_len) * 0.5
		else:
			failed += 1

	var result := {
		"success": planted > 0,
		"planted_count": planted,
		"already_aligned": already,
		"fogged": fogged,
		"failed": failed,
		"p_north_reached": last_p_north,
	}
	if planted == 0:
		if fogged > 0:
			result["error"] = "fogged"
			result["message"] = "A fog cannot be planted — no coherent pulse purifies r ≈ 0. Measure it, or jolt it with the Spark (wet country)."
		elif already > 0:
			result["error"] = "already_planted"
			result["message"] = "Already planted — the state sits on its north pole."
		else:
			result["error"] = "no_valid_plots"
			result["message"] = "No plot with a live quantum state selected."
	return result


## ============================================================================
## TWO-QUBIT GATE OPERATIONS
## ============================================================================

static func apply_cnot(farm, positions: Array[Vector2i]) -> Dictionary:
	# Apply CNOT gate to position pairs.

	# Processes sequential pairs: (0,1), (2,3), etc.
	# Control qubit at first position, target at second.
	return _apply_two_qubit_gate_batch(farm, positions, "CNOT", "CNOT")


static func apply_cz(farm, positions: Array[Vector2i]) -> Dictionary:
	# Apply CZ gate to position pairs.

	# Controlled-Z gate between sequential position pairs.
	return _apply_two_qubit_gate_batch(farm, positions, "CZ", "CZ")


static func apply_swap(farm, positions: Array[Vector2i]) -> Dictionary:
	# Apply SWAP gate to position pairs.

	# Swaps qubit states between sequential position pairs.
	return _apply_two_qubit_gate_batch(farm, positions, "SWAP", "SWAP")


static func create_bell_pair(farm, positions: Array[Vector2i]) -> Dictionary:
	# Create Bell pair (H + CNOT) - maximally entangled state.

	# Requires exactly 2 positions. Creates |Phi+> = (|00> + |11>) / sqrt(2)
	if positions.size() < 2:
		return {
			"success": false,
			"error": "need_two_positions",
			"message": "Select 2 plots to create Bell pair"
		}

	var pos_a = positions[0]
	var pos_b = positions[1]

	# Step 1: Apply Hadamard to first qubit
	var h_result = _apply_single_qubit_gate(farm, pos_a, "H")
	if not h_result.success:
		return {
			"success": false,
			"error": "hadamard_failed",
			"message": "Failed to apply Hadamard"
		}

	# Step 2: Apply CNOT (control=a, target=b)
	var cnot_result = _apply_two_qubit_gate(farm, pos_a, pos_b, "CNOT")
	if not cnot_result.success:
		return {
			"success": false,
			"error": "cnot_failed",
			"message": "Failed to apply CNOT"
		}

	return {
		"success": true,
		"positions": [pos_a, pos_b],
		"state": "Bell pair |Phi+> = (|00>+|11>)/sqrt(2)"
	}


static func create_ghz_state(farm, positions: Array[Vector2i]) -> Dictionary:
	# Create GHZ state - maximally entangled n-qubit state.

	# Creates (|000...0⟩ + |111...1⟩)/√2 for all selected positions.
	# Uses H on first qubit, then CNOT from first to each subsequent qubit.
	if positions.size() < 2:
		return {
			"success": false,
			"error": "need_two_positions",
			"message": "Select 2+ plots for GHZ state"
		}

	# Step 1: Apply Hadamard to first qubit
	var h_result = _apply_single_qubit_gate(farm, positions[0], "H")
	if not h_result.success:
		return {
			"success": false,
			"error": "hadamard_failed",
			"message": "Failed to apply Hadamard to control qubit"
		}

	# Step 2: Apply CNOT from first qubit to each subsequent qubit
	var cnot_count = 0
	for i in range(1, positions.size()):
		var cnot_result = _apply_two_qubit_gate(farm, positions[0], positions[i], "CNOT")
		if cnot_result.success:
			cnot_count += 1

	if cnot_count == 0:
		return {
			"success": false,
			"error": "cnot_failed",
			"message": "Failed to apply any CNOT gates"
		}

	var zeros = "0".repeat(positions.size())
	var ones = "1".repeat(positions.size())

	return {
		"success": true,
		"positions": positions,
		"qubit_count": positions.size(),
		"cnot_applied": cnot_count,
		"state": "GHZ |%s⟩+|%s⟩)/√2" % [zeros, ones]
	}


## ============================================================================
## ENTANGLEMENT OPERATIONS
## ============================================================================

static func cluster(farm, positions: Array[Vector2i]) -> Dictionary:
	# Create linear cluster state from selected positions.

	# A cluster state is a highly entangled state used in measurement-based
	# quantum computing. The linear cluster has graph structure:

	# q[0] — q[1] — q[2] — ... — q[n-1]

	# where edges represent CZ gates applied after H on all qubits.

	# Preparation (respects selection order):
	# 1. Apply H to ALL selected qubits → |+⟩⊗n
	# 2. Apply CZ between adjacent pairs: (0,1), (1,2), ..., (n-2,n-1)

	# The selection order determines the linear chain topology.
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.size() < 2:
		return {
			"success": false,
			"error": "need_two_positions",
			"message": "Need at least 2 plots for cluster state"
		}

	# Step 1: Apply Hadamard to ALL qubits (creates |+⟩⊗n)
	var h_count = 0
	var h_order: Array = []
	for pos in positions:
		var h_result = _apply_single_qubit_gate(farm, pos, "H")
		if h_result.success:
			h_count += 1
			h_order.append(h_result.get("register_id", -1))

	if h_count < 2:
		return {
			"success": false,
			"error": "hadamard_failed",
			"message": "Failed to apply H to enough qubits (need 2+, got %d)" % h_count
		}

	# Step 2: Apply CZ between adjacent pairs in selection order
	# This creates the linear graph structure: 0-1-2-...-n
	var cz_count = 0
	var cz_edges: Array = []

	for i in range(positions.size() - 1):
		var cz_result = _apply_two_qubit_gate(farm, positions[i], positions[i + 1], "CZ")
		if cz_result.success:
			cz_count += 1
			cz_edges.append([cz_result.get("register_a", -1), cz_result.get("register_b", -1)])

	if cz_count == 0:
		return {
			"success": false,
			"error": "cz_failed",
			"message": "Failed to apply any CZ gates"
		}

	return {
		"success": true,
		"positions": positions,
		"qubit_count": positions.size(),
		"h_applied": h_count,
		"cz_applied": cz_count,
		"cz_edges": cz_edges,
		"state": "Linear cluster state (%d qubits, %d edges)" % [h_count, cz_count]
	}


static func disentangle(farm, positions: Array[Vector2i]) -> Dictionary:
	# Break entanglement between qubits by measuring and resetting.

	# Performs measurement to collapse entangled state.
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var success_count = 0
	var results: Array = []

	for pos in positions:
		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome:
			continue

		var plot = farm.grid.get_plot(pos)
		if not plot or not plot.is_active():
			continue

		var reg_id = int(plot.bound_register_id)
		if reg_id < 0:
			reg_id = int(farm.grid.get_register_for_plot(pos))
		if reg_id < 0:
			continue

		if not biome.quantum_computer or not biome.quantum_computer.register_map:
			continue
		if not biome.quantum_computer.register_map.has(reg_id):
			continue

		var qubit = biome.quantum_computer.register_map.get(reg_id)
		if not qubit:
			continue

		# Measure to collapse entanglement
		var measure_result = biome.quantum_computer.measure_axis(qubit.north_emoji, qubit.south_emoji)
		if measure_result != "":
			success_count += 1
			results.append({"position": pos, "outcome": measure_result, "register_id": reg_id})

	return {
		"success": success_count > 0,
		"disentangled_count": success_count,
		"results": results
	}


static func inspect_entanglement(farm, positions: Array[Vector2i]) -> Dictionary:
	# Show entanglement information for selected qubits.

	# Returns which qubits are entangled with the selected ones.
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var info: Array = []

	for pos in positions:
		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome or not biome.quantum_computer:
			continue

		var plot = farm.grid.get_plot(pos)
		if not plot or not plot.is_active():
			continue

		var reg_id = int(plot.bound_register_id)
		if reg_id < 0:
			reg_id = int(farm.grid.get_register_for_plot(pos))
		if reg_id < 0:
			continue

		var qc = biome.quantum_computer
		var entangled = qc.get_entangled_component(reg_id)

		var partners: Array = []
		if entangled.size() > 1:
			for r_id in entangled:
				if r_id != reg_id:
					partners.append(r_id)

		info.append({
			"position": pos,
			"register_id": reg_id,
			"entangled_with": partners,
			"is_entangled": partners.size() > 0
		})

	return {
		"success": true,
		"entanglement_info": info
	}


## ============================================================================
## HELPER METHODS
## ============================================================================

static func _apply_gate_batch(farm, positions: Array[Vector2i], gate_name: String, display_name: String) -> Dictionary:
	# Apply a single-qubit gate to all positions in batch.
	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var success_count = 0
	var results: Array = []

	for pos in positions:
		var result = _apply_single_qubit_gate(farm, pos, gate_name)
		if result.success:
			success_count += 1
		results.append(result)

	# When every position refused, lift the first honest per-position message to the top
	# level — _run_action's toast tail reads only result.message, so without this the
	# player got a bare "✗ H-Gate blocked" while the real reason ("StarterForest holds
	# 4 qubits — this slot is beyond them") sat unread inside results[] (anti-gating law).
	var out := {
		"success": success_count > 0,
		"gate": gate_name,
		"display_name": display_name,
		"applied_count": success_count,
		"total_count": positions.size(),
		"results": results
	}
	if success_count == 0:
		out["message"] = _first_failure_message(results, "%s refused" % display_name)
	return out


static func _apply_two_qubit_gate_batch(farm, positions: Array[Vector2i], gate_name: String, display_name: String) -> Dictionary:
	# Apply a two-qubit gate to sequential position pairs.
	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var success_count = 0
	var results: Array = []

	for i in range(0, positions.size() - 1, 2):
		var pos_a = positions[i]
		var pos_b = positions[i + 1]
		var result = _apply_two_qubit_gate(farm, pos_a, pos_b, gate_name)
		if result.success:
			success_count += 1
		results.append(result)

	# Same message lift as _apply_gate_batch — an all-refused Operator-frame gate must
	# say why, not just "blocked".
	var out := {
		"success": success_count > 0,
		"gate": gate_name,
		"display_name": display_name,
		"pair_count": success_count,
		"results": results
	}
	if success_count == 0:
		out["message"] = _first_failure_message(results, "%s refused" % display_name)
	return out


## First non-empty failure message from a batch's per-position results — the honest text
## _apply_single_qubit_gate/_apply_two_qubit_gate already wrote.
static func _first_failure_message(results: Array, fallback: String) -> String:
	for r in results:
		if typeof(r) == TYPE_DICTIONARY and not bool(r.get("success", false)):
			var msg := str(r.get("message", ""))
			if msg != "":
				return msg
	return fallback


static func _resolve_biome_register(farm, position: Vector2i) -> Dictionary:
	# Thin adapter over PlotRegisterResolver — the ONE slot→qubit authority
	# shared with the display. The old body here wrapped unbound slots with
	# posmod(slot_index, num_qubits), silently gating a DIFFERENT plot's qubit
	# than the bubble the player saw. Wrapping is banned; out-of-range slots
	# resolve to register_id -1 and the caller refuses with an honest message.
	return PlotRegisterResolver.resolve(farm, position)


static func _apply_single_qubit_gate(farm, position: Vector2i, gate_name: String) -> Dictionary:
	# Apply a single-qubit gate at a position.
	if not farm:
		return {
			"success": false,
			"error": "no_farm",
			"message": "Farm not loaded"
		}

	var resolved = _resolve_biome_register(farm, position)
	var biome = resolved.get("biome", null)
	var register_id: int = int(resolved.get("register_id", -1))

	# Validate biome and register. The message reaches the player via
	# _apply_gate_batch's message lift → _run_action's toast tail — a refused
	# verb must SAY so (anti-gating law).
	if not biome or not biome.quantum_computer or register_id < 0:
		var nq: int = int(resolved.get("num_qubits", 0))
		var refuse_msg := "No qubit under this plot"
		if str(resolved.get("biome_name", "")) != "" and nq > 0:
			refuse_msg = "%s holds %d qubit%s — this slot is beyond them" % [
				str(resolved.get("biome_name")), nq, "" if nq == 1 else "s"]
		return {
			"success": false,
			"error": "no_quantum_state",
			"message": refuse_msg,
			"position": position
		}

	# Get gate matrix from library
	var gate_lib = QuantumGateLibrary.new()
	if not gate_lib.GATES.has(gate_name):
		return {
			"success": false,
			"error": "unknown_gate",
			"message": "Unknown gate: %s" % gate_name
		}

	var gate_matrix = gate_lib.GATES[gate_name]["matrix"]
	if not gate_matrix:
		return {
			"success": false,
			"error": "no_matrix",
			"message": "No matrix for gate: %s" % gate_name
		}

	# Check density matrix exists
	if biome.quantum_computer.density_matrix == null:
		return {
			"success": false,
			"error": "no_density_matrix",
			"message": "Density matrix not initialized"
		}

	# Use GateInjector to apply gate + invalidate lookahead buffer
	var inject_result = GateInjector.inject_gate(biome, register_id, gate_matrix, farm)

	return {
		"success": bool(inject_result.get("success", false)),
		"gate": gate_name,
		"register_id": register_id,
		"position": position,
		"gate_injected": inject_result.get("gate_injected", false),
		"error": str(inject_result.get("error", "")),
		"message": str(inject_result.get("message", ""))
	}


static func _apply_two_qubit_gate(farm, position_a: Vector2i, position_b: Vector2i, gate_name: String) -> Dictionary:
	# Apply a two-qubit gate between two positions.

	# Supports both v2 terminal-based and v1 plot-based models.
	# Both positions must be in the same biome.
	if not farm:
		return {
			"success": false,
			"error": "no_farm",
			"message": "Farm not loaded"
		}

	# ONE slot→qubit authority, same as the 1-qubit path and the display.
	# (The old body had three stacked fallbacks ending in a posmod wrap that
	# silently gated a different plot's qubit; and measured plots slid into
	# the wrap instead of refusing.)
	var plot_a = farm.grid.get_plot(position_a) if farm.grid else null
	var plot_b = farm.grid.get_plot(position_b) if farm.grid else null
	if (plot_a and plot_a.is_measured) or (plot_b and plot_b.is_measured):
		return {
			"success": false,
			"error": "plot_measured",
			"message": "A measured plot is frozen — harvest it before gating"
		}

	var resolved_a = _resolve_biome_register(farm, position_a)
	var resolved_b = _resolve_biome_register(farm, position_b)
	var biome_a = resolved_a.get("biome", null)
	var biome_b = resolved_b.get("biome", null)
	var reg_a: int = int(resolved_a.get("register_id", -1))
	var reg_b: int = int(resolved_b.get("register_id", -1))

	# Both positions must have valid registers in the SAME biome
	if biome_a != biome_b or not biome_a or not biome_a.quantum_computer:
		return {
			"success": false,
			"error": "different_biomes",
			"message": "Both plots must be in same biome"
		}

	if reg_a < 0 or reg_b < 0:
		return {
			"success": false,
			"error": "missing_registers",
			"message": "No qubit under one of these plots (%s holds %d)" % [
				str(resolved_a.get("biome_name", "?")), int(resolved_a.get("num_qubits", 0))]
		}

	# Get gate matrix from library
	var gate_lib = QuantumGateLibrary.new()
	if not gate_lib.GATES.has(gate_name):
		return {
			"success": false,
			"error": "unknown_gate",
			"message": "Unknown gate: %s" % gate_name
		}

	var gate_matrix = gate_lib.GATES[gate_name]["matrix"]
	if not gate_matrix:
		return {
			"success": false,
			"error": "no_matrix",
			"message": "No matrix for gate: %s" % gate_name
		}

	# Check density matrix exists
	if biome_a.quantum_computer.density_matrix == null:
		return {
			"success": false,
			"error": "no_density_matrix",
			"message": "Density matrix not initialized"
		}

	# Use GateInjector to apply 2-qubit gate + invalidate lookahead buffer
	var inject_result = GateInjector.inject_gate_2q(biome_a, reg_a, reg_b, gate_matrix, farm)

	return {
		"success": bool(inject_result.get("success", false)),
		"gate": gate_name,
		"register_a": reg_a,
		"register_b": reg_b,
		"position_a": position_a,
		"position_b": position_b,
		"gate_injected": inject_result.get("gate_injected", false),
		"error": str(inject_result.get("error", "")),
		"message": str(inject_result.get("message", ""))
	}
