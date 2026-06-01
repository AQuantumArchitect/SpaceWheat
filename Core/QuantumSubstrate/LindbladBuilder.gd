class_name LindbladBuilder
extends RefCounted

## Build Lindblad operators from Icons, filtered by RegisterMap
##
## Lindblad operators: L_k = amplitude * |target⟩⟨source|
## where amplitude = √(rate × lindblad_rate_scale)
##
## Icons define couplings: {target_emoji: Complex}
## RegisterMap filters: only include if both emojis have coordinates
##
## PHYSICS INTENT: Hamiltonian drives fast coherent dynamics (Rabi oscillation).
## Lindblad drives slow irreversible dissipation (thermalization, decay).
## lindblad_rate_scale (from BalanceConfig.physics) controls the ratio:
## at 0.1, Lindblad timescales are ~100× slower than Hamiltonian timescales,
## giving visible oscillation before dissipation damps it out.

const _BalanceConfig = preload("res://Core/GameMechanics/BalanceConfig.gd")

## Lindblad rate scale — sourced from BalanceConfig.physics.lindblad_rate_scale.
## SCAFFOLDING: Remove once biomes.json rates are tuned to final values.
static func _get_rate_scale() -> float:
	return _BalanceConfig.get_physics().get("lindblad_rate_scale", 0.1)


## Build Lindblad operators directly from a biome's atom_components dict.
##
## Atoms-native path. atom_components is keyed by atom (emoji); each entry may
## carry `lindblad_outgoing`, `lindblad_incoming`, and `decay` term shapes.
## The runtime basis is whichever atoms have a coordinate in `register_map`
## (i.e. are inhabited by an icon). Atoms referenced in atom_components but
## absent from register_map are *primed*: their terms stay in data, no operator emitted.
##
## `decay {rate, target}` is treated as a transfer (same |target⟩⟨source| jump op shape).
static func build_from_atoms(atom_components: Dictionary, register_map: RegisterMap, verbose = null, label: String = "") -> Dictionary:
	var operators: Array = []
	var num_qubits = register_map.num_qubits

	var stats = {
		"outgoing_added": 0, "outgoing_skipped": 0,
		"incoming_added": 0, "incoming_skipped": 0,
		"decay_added":    0, "decay_skipped":    0,
	}

	# Track the directed transfer graph of *active* (in-basis) jumps so we can flag
	# population sinks: an atom that receives transfers but never emits one is an
	# absorbing pure state — population piles there, S → 0, and the reap bank
	# collapses. A pump (e.g. 🗑→🌲) gives the sink an out-edge, so it's correctly
	# NOT flagged; a closed webway cycle (every node emits) is likewise fine.
	var src_atoms: Dictionary = {}
	var dst_atoms: Dictionary = {}

	if verbose:
		verbose.info("quantum", "🔨", "Lindblad from atoms: %d qubits" % num_qubits)

	# Track (source, target) pairs already emitted so incoming-direction entries
	# don't double-up on outgoing-direction declarations.
	var emitted: Dictionary = {}

	# Expand "everything" wildcard: merge its couplings into every real atom entry.
	if "everything" in atom_components and atom_components["everything"] is Dictionary:
		var wildcard: Dictionary = atom_components["everything"]
		var expanded: Dictionary = {}
		for k in atom_components:
			if k == "everything":
				continue
			var entry: Dictionary = (atom_components[k] as Dictionary).duplicate(true)
			for field in ["lindblad_outgoing", "lindblad_incoming"]:
				if field in wildcard:
					if field not in entry:
						entry[field] = {}
					for target in wildcard[field]:
						if target not in entry[field]:
							entry[field][target] = wildcard[field][target]
			expanded[k] = entry
		atom_components = expanded

	# First pass: outgoing + decay (both produce |target⟩⟨source| jumps)
	for source_emoji in atom_components.keys():
		var component = atom_components[source_emoji]
		if not (component is Dictionary):
			continue

		var source_in = register_map.has(source_emoji)
		var source_q := -1
		var source_p := 0
		if source_in:
			source_q = register_map.qubit(source_emoji)
			source_p = register_map.pole(source_emoji)

		# --- Outgoing transfers ---
		var outgoing = component.get("lindblad_outgoing", {})
		if outgoing is Dictionary:
			for target_emoji in outgoing.keys():
				if not source_in or not register_map.has(target_emoji):
					stats.outgoing_skipped += 1  # primed
					if verbose:
						verbose.debug("quantum", "primed", "L outgoing %s→%s (waiting for axis)" % [source_emoji, target_emoji])
					continue
				var target_q = register_map.qubit(target_emoji)
				var target_p = register_map.pole(target_emoji)
				var rate = float(outgoing[target_emoji]) * _get_rate_scale()
				var amp = Complex.new(sqrt(abs(rate)), 0.0)
				operators.append(_build_jump(source_q, source_p, target_q, target_p, amp, num_qubits))
				stats.outgoing_added += 1
				emitted[source_emoji + "→" + target_emoji] = true
				src_atoms[source_emoji] = true
				dst_atoms[target_emoji] = true

		# --- Decay (treated as outgoing transfer) ---
		var decay = component.get("decay", {})
		if decay is Dictionary and decay.has("rate"):
			var dt_emoji: String = str(decay.get("target", ""))
			var dt_rate: float = float(decay.get("rate", 0.0))
			if dt_rate > 0.0:
				if not source_in or not register_map.has(dt_emoji):
					stats.decay_skipped += 1  # primed
					if verbose:
						verbose.debug("quantum", "primed", "decay %s→%s (waiting for axis)" % [source_emoji, dt_emoji])
				else:
					var dt_q = register_map.qubit(dt_emoji)
					var dt_p = register_map.pole(dt_emoji)
					var rate = dt_rate * _get_rate_scale()
					var amp = Complex.new(sqrt(abs(rate)), 0.0)
					operators.append(_build_jump(source_q, source_p, dt_q, dt_p, amp, num_qubits))
					stats.decay_added += 1
					emitted[source_emoji + "→" + dt_emoji] = true
					src_atoms[source_emoji] = true
					dst_atoms[dt_emoji] = true

	# Second pass: incoming (dedup against emitted outgoing/decay)
	for receiver_emoji in atom_components.keys():
		var component = atom_components[receiver_emoji]
		if not (component is Dictionary):
			continue
		var incoming = component.get("lindblad_incoming", {})
		if not (incoming is Dictionary):
			continue

		var receiver_in = register_map.has(receiver_emoji)
		var receiver_q := -1
		var receiver_p := 0
		if receiver_in:
			receiver_q = register_map.qubit(receiver_emoji)
			receiver_p = register_map.pole(receiver_emoji)

		for src_emoji in incoming.keys():
			if not receiver_in or not register_map.has(src_emoji):
				stats.incoming_skipped += 1  # primed
				if verbose:
					verbose.debug("quantum", "primed", "L incoming %s→%s (waiting for axis)" % [src_emoji, receiver_emoji])
				continue
			if emitted.has(src_emoji + "→" + receiver_emoji):
				continue  # outgoing/decay already covered this pair
			var src_q = register_map.qubit(src_emoji)
			var src_p = register_map.pole(src_emoji)
			var rate = float(incoming[src_emoji]) * _get_rate_scale()
			var amp = Complex.new(sqrt(abs(rate)), 0.0)
			operators.append(_build_jump(src_q, src_p, receiver_q, receiver_p, amp, num_qubits))
			stats.incoming_added += 1
			src_atoms[src_emoji] = true
			dst_atoms[receiver_emoji] = true

	if verbose:
		verbose.info("quantum", "✅",
			"Atoms-Lindblad: %d ops | out:%d in:%d decay:%d | primed:%d" % [
				operators.size(),
				stats.outgoing_added, stats.incoming_added, stats.decay_added,
				stats.outgoing_skipped + stats.incoming_skipped + stats.decay_skipped
			])

	# Lint: any atom that receives a transfer but emits none is a population sink
	# with no refill path — S decays → 0 and the reap bank collapses. Surface it so
	# the biome can be authored with a pump (lindblad_incoming from 🗑) or a
	# balancing webway edge. Non-blocking diagnostic; no operator/data change.
	if not operators.is_empty():
		var sinks: Array = []
		for atom in dst_atoms.keys():
			if not src_atoms.has(atom):
				sinks.append(atom)
		if not sinks.is_empty():
			var who: String = label if label != "" else "(%d-op biome)" % operators.size()
			push_warning("LindbladBuilder: %s has population sink(s) %s with no outflow (no refill path) — S will decay → 0 and the reap bank collapses. Add a pump (lindblad_incoming from 🗑) or a balancing webway edge." % [who, " ".join(sinks)])

	return {"operators": operators}


static func _build_jump(from_q: int, from_p: int, to_q: int, to_p: int,
						amplitude: Complex, num_qubits: int) -> ComplexMatrix:
	# Build jump operator L = amplitude * |to⟩⟨from|.

	# Cases:
	# - Same qubit: flip pole (|0⟩→|1⟩ or |1⟩→|0⟩)
	# - Different qubits: correlated transfer (flip both)
	var dim = 1 << num_qubits
	var L = ComplexMatrix.zeros(dim)

	if from_q == to_q:
		# Same qubit: flip pole
		var shift = num_qubits - 1 - from_q

		for i in range(dim):
			# Check if qubit is in 'from' pole
			if ((i >> shift) & 1) == from_p:
				var j = i ^ (1 << shift)  # Flip bit
				L.set_element(j, i, amplitude)
	else:
		# Different qubits: correlated transfer
		# If from_q is in from_p AND to_q is NOT in to_p, flip both
		var shift_from = num_qubits - 1 - from_q
		var shift_to = num_qubits - 1 - to_q

		for i in range(dim):
			var bit_from = (i >> shift_from) & 1
			var bit_to = (i >> shift_to) & 1

			# Source qubit must be in from_p
			# Target qubit must NOT already be in to_p (room to transfer)
			if bit_from == from_p and bit_to != to_p:
				var j = i ^ (1 << shift_from) ^ (1 << shift_to)
				L.set_element(j, i, amplitude)

	return L
