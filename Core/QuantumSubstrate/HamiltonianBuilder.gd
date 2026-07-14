class_name HamiltonianBuilder
extends RefCounted

## Build Hamiltonian from icon resources, filtered by RegisterMap
##
## Icons define GLOBAL physics (from icons.json via IconRegistry).
## RegisterMap defines LOCAL coordinates: {emoji: {qubit, pole}}.
## Only couplings where BOTH emojis have coordinates are included.
##
## This allows the same icon definitions to be reused across biomes
## with different register configurations.

const _BalanceConfig = preload("res://Core/GameMechanics/BalanceConfig.gd")


## Global coupling scale — the symmetric partner to LindbladBuilder's rate scale.
## Multiplies every off-diagonal H coupling (rabi + cross-icon), so the coherent/
## dissipative regime is one parametric knob over the authored values. 1.0 = identity.
static func _get_coupling_scale() -> float:
	return float(_BalanceConfig.get_physics().get("hamiltonian_coupling_scale", 1.0))



static func _add_self_energy(H: ComplexMatrix, qubit: int, pole: int,
							  energy: Complex, num_qubits: int) -> void:
	# Add diagonal term for states where qubit is in pole state.

	# For each basis state |i⟩ where qubit = pole, add energy to H[i,i].
	var dim = 1 << num_qubits
	var shift = num_qubits - 1 - qubit

	for i in range(dim):
		# Check if qubit at position 'qubit' has bit value 'pole'
		if ((i >> shift) & 1) == pole:
			var current = H.get_element(i, i)
			H.set_element(i, i, current.add(energy))


static func _add_coupling(H: ComplexMatrix,
						   q_a: int, p_a: int,
						   q_b: int, p_b: int,
						   coupling: Complex, num_qubits: int) -> void:
	# Add off-diagonal coupling between two qubit-pole pairs.

	# Cases:
	# - Same qubit, different poles: σ_x rotation (|0⟩↔|1⟩)
	# - Different qubits: Conditional transition (correlated flip)
	var dim = 1 << num_qubits

	if q_a == q_b:
		# Same qubit: σ_x rotation (|0⟩↔|1⟩)
		if p_a == p_b:
			# Self-coupling should be handled by self_energy
			return

		var shift = num_qubits - 1 - q_a
		for i in range(dim):
			# Check if qubit is in pole p_a
			if ((i >> shift) & 1) == p_a:
				var j = i ^ (1 << shift)  # Flip bit
				var current = H.get_element(i, j)
				H.set_element(i, j, current.add(coupling))
	else:
		# Different qubits: conditional transition
		# Flip both qubits if both match source poles
		var shift_a = num_qubits - 1 - q_a
		var shift_b = num_qubits - 1 - q_b

		for i in range(dim):
			var bit_a = (i >> shift_a) & 1
			var bit_b = (i >> shift_b) & 1

			# Both qubits must match source poles
			if bit_a == p_a and bit_b == p_b:
				var j = i ^ (1 << shift_a) ^ (1 << shift_b)
				var current = H.get_element(i, j)
				H.set_element(i, j, current.add(coupling))


static func _hermitianize(H: ComplexMatrix) -> ComplexMatrix:
	# Return (H + H†)/2 to ensure Hermiticity.

	# This corrects any numerical errors from asymmetric coupling additions.
	var H_dag = H.conjugate_transpose()
	return H.add(H_dag).scale_real(0.5)


## Build Hamiltonian directly from an Array[Icon] (icon-cloud biomes).
## Icons are first-class qubit entities: each icon IS one qubit.
## Reuses all existing helpers (_add_self_energy, _add_coupling, _hermitianize).
static func build_from_icons(icons: Array, register_map: RegisterMap,
		verbose = null, time: float = 0.0) -> ComplexMatrix:
	var dim = register_map.dim()
	var num_qubits = register_map.num_qubits
	var H = ComplexMatrix.zeros(dim)

	var stats = {"self_energies": 0, "rabi": 0, "cross": 0, "skipped": 0}
	var h_scale := _get_coupling_scale()

	if verbose:
		verbose.info("quantum", "🔨", "Building H from %d icons (%dD)" % [icons.size(), dim])

	# Duplicate emojis are legal: the same icon axis may live on several qubits
	# (degeneracy). Each UNIQUE icon is applied once per instance-qubit, and
	# cross couplings fan out to EVERY instance of the target emoji. Callers
	# often pass one Icon per qubit, so a duplicated axis appears twice in
	# `icons` — dedupe by pole pair to avoid double-stamping the physics.
	var seen_pairs: Dictionary = {}
	for icon in icons:
		if not register_map.has(icon.pole_0) or not register_map.has(icon.pole_1):
			stats.skipped += 1
			continue
		var pair_key: String = "%s|%s" % [icon.pole_0, icon.pole_1]
		if seen_pairs.has(pair_key):
			continue
		seen_pairs[pair_key] = true

		# Every qubit carrying exactly this axis (degenerate instances).
		var source_qubits: Array = register_map.qubits_with_axis(icon.pole_0, icon.pole_1)
		if source_qubits.is_empty():
			# Legacy shape: poles registered but not as one axis — keep the
			# historical primary-instance behavior.
			source_qubits = [register_map.qubit(icon.pole_0)]

		var e0 := _get_pole_energy(icon, 0, time)
		var e1 := _get_pole_energy(icon, 1, time)
		var cross_couplings := _get_cross_couplings(icon)

		for q in source_qubits:
			# σ_z self-energies (diagonal)
			if abs(e0) > 1e-10:
				_add_self_energy(H, q, 0, Complex.new(e0, 0.0), num_qubits)
				stats.self_energies += 1
			if abs(e1) > 1e-10:
				_add_self_energy(H, q, 1, Complex.new(e1, 0.0), num_qubits)
				stats.self_energies += 1

			# σ_x rabi coupling (off-diagonal, pole_0 ↔ pole_1 on same qubit)
			if abs(icon.rabi_coupling) > 1e-10:
				_add_coupling(H, q, 0, q, 1, Complex.new(icon.rabi_coupling * h_scale, 0.0), num_qubits)
				stats.rabi += 1

			# Cross-icon couplings (both poles of source → target pole).
			# Degenerate coupling: apply to ALL instances of the target emoji.
			for target in cross_couplings:
				var target_coords: Array = register_map.all_coordinates_for(target)
				if target_coords.is_empty():
					stats.skipped += 1
					continue
				var v = cross_couplings[target]
				var c: Complex
				if v is Vector2:
					c = Complex.new(v.x, v.y)
				elif v is Complex:
					c = v
				else:
					c = Complex.new(float(v), 0.0)
				if h_scale != 1.0:
					c = Complex.new(c.re * h_scale, c.im * h_scale)
				for tcoord in target_coords:
					var tq: int = int(tcoord["qubit"])
					var tp: int = int(tcoord["pole"])
					_add_coupling(H, q, 0, tq, tp, c, num_qubits)
					_add_coupling(H, q, 1, tq, tp, c, num_qubits)
					stats.cross += 1

	H = _hermitianize(H)

	if verbose:
		verbose.info("quantum", "✅", "H from icons: %d self-energies + %d rabi + %d cross | skipped: %d" % [
			stats.self_energies, stats.rabi, stats.cross, stats.skipped])
	else:
		VerboseHelper.info("quantum", "build", "H from icons: %d qubits, %d SE + %d rabi + %d cross" % [
			icons.size(), stats.self_energies, stats.rabi, stats.cross])
	return H


## Extract driven icon configs from Array[Icon].
## Returns array of driver dicts for set_driven_icons().
static func get_driven_icons(icons: Array, register_map: RegisterMap) -> Array:
	var driven := []
	var seen_pairs: Dictionary = {}
	for icon in icons:
		var driver := _get_driver_dict(icon)
		if driver.is_empty() or not driver.has("type"):
			continue
		if not register_map.has(icon.pole_0):
			continue
		# Dedupe by pole pair, then emit one driver per degenerate instance —
		# every qubit carrying this axis gets driven (matches build_from_icons).
		var pair_key: String = "%s|%s" % [icon.pole_0, icon.pole_1]
		if seen_pairs.has(pair_key):
			continue
		seen_pairs[pair_key] = true
		var driven_qubits: Array = register_map.qubits_with_axis(icon.pole_0, icon.pole_1)
		if driven_qubits.is_empty():
			driven_qubits = [register_map.qubit(icon.pole_0)]
		for q in driven_qubits:
			driven.append({
				"emoji": icon.pole_0,
				"qubit": q,
				"pole": 0,
				"icon_ref": icon,
				"driver_type": str(driver.get("type", "")),
				"base_energy": _get_pole_energy(icon, 0, 0.0),
				"freq": float(driver.get("freq", 0.0)),
				"phase": float(driver.get("phase", 0.0)),
				"amp": float(driver.get("amp", 1.0)),
			})
	return driven


static func _get_cross_couplings(icon) -> Dictionary:
	if icon == null:
		return {}
	var couplings = icon.get("hamiltonian_couplings")
	if couplings is Dictionary:
		return couplings
	couplings = icon.get("cross_couplings")
	return couplings if couplings is Dictionary else {}


static func _get_driver_dict(icon) -> Dictionary:
	if icon == null:
		return {}
	var driver = icon.get("driver")
	if driver == null:
		driver = {}
	if driver is Dictionary and not driver.is_empty():
		return driver
	var driver_type = str(icon.get("self_energy_driver"))
	if driver_type == "":
		return {}
	return {
		"type": driver_type,
		"freq": float(icon.get("driver_frequency")),
		"phase": float(icon.get("driver_phase")),
		"amp": float(icon.get("driver_amplitude"))
	}


static func _get_pole_energy(icon, pole: int, time: float) -> float:
	if icon == null:
		return 0.0
	if icon.has_method("get_pole_energy"):
		return float(icon.get_pole_energy(pole, time))
	var key := "self_energy_0" if pole == 0 else "self_energy_1"
	var direct = icon.get(key)
	if direct != null:
		return float(direct)
	if pole == 0 and icon.has_method("get_self_energy"):
		return float(icon.get_self_energy(time))
	var base = icon.get("self_energy")
	return float(base) if base != null else 0.0
