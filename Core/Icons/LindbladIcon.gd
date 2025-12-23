class_name LindbladIcon
extends IconHamiltonian

## Lindblad Icon - Real Quantum Environmental Effects
## Extends IconHamiltonian with physically accurate Lindblad jump operators
##
## Icons now represent environmental conditions that affect quantum states:
## - Temperature modulation (affects T₁/T₂)
## - Jump operators (dephasing, damping, pumping, etc.)
## - Conspiracy network modulation (legacy, for tomato growth)
##
## This is REAL physics: open quantum systems with dissipation and decoherence.

# Temperature modulation
# Note: base_temperature and temperature_scaling are inherited from IconHamiltonian

# Lindblad jump operators for quantum states
# Each entry: {operator_type: String, base_rate: float}
# operator_type: "dephasing", "damping", "pumping", "phase_flip", "custom"
var jump_operators: Array = []

# Custom Hamiltonian term (optional, for coherent driving)
var hamiltonian_coupling: float = 0.0  # Coupling strength
var hamiltonian_operator: String = ""  # "sigma_x", "sigma_y", "sigma_z"


func _ready():
	super._ready()  # Call parent _ready
	_initialize_jump_operators()


## Override in subclasses to define jump operators
func _initialize_jump_operators():
	"""Define Lindblad jump operators for this Icon

	Example:
		jump_operators.append({
			"operator_type": "dephasing",
			"base_rate": 0.1
		})
	"""
	pass


## Temperature Modulation

func get_effective_temperature() -> float:
	"""Calculate effective temperature from Icon activation

	Returns:
		Temperature (Kelvin or relative units)
	"""
	return base_temperature + (temperature_scaling * active_strength * 80.0)


func get_T1_modifier() -> float:
	"""Get T₁ time modifier based on Icon effects

	Returns:
		Multiplier for T₁ (1.0 = no effect, < 1.0 = faster damping)
	"""
	# Default: temperature increases decoherence
	var temp = get_effective_temperature()
	return 1.0 / (1.0 + temp / 100.0)


func get_T2_modifier() -> float:
	"""Get T₂ time modifier based on Icon effects

	Returns:
		Multiplier for T₂ (1.0 = no effect, < 1.0 = faster dephasing)
	"""
	var temp = get_effective_temperature()
	return 1.0 / (1.0 + temp / 100.0)


## Quantum State Modulation

func apply_to_qubit(qubit, dt: float) -> void:
	"""Apply Icon's quantum effects to a single qubit

	Uses Lindblad evolution with Icon-specific jump operators.

	Args:
		qubit: DualEmojiQubit to affect
		dt: Time step (seconds)
	"""
	if active_strength <= 0.0:
		return

	# Skip if qubit is part of entangled pair (handled at pair level)
	if qubit.entangled_pair != null:
		return

	# Set environment temperature
	var temp = get_effective_temperature()
	qubit.environment_temperature = temp

	# Apply custom jump operators if defined
	if not jump_operators.is_empty():
		_apply_custom_lindblad(qubit, dt)


func apply_to_entangled_pair(pair, dt: float) -> void:
	"""Apply Icon's quantum effects to an entangled pair

	Args:
		pair: EntangledPair to affect
		dt: Time step (seconds)
	"""
	if active_strength <= 0.0:
		return

	# Apply custom jump operators if defined
	if not jump_operators.is_empty():
		_apply_custom_lindblad_to_pair(pair, dt)


func _apply_custom_lindblad(qubit, dt: float) -> void:
	"""Apply custom Lindblad operators defined in jump_operators array

	Converts operator types to actual matrix operators and applies Lindblad evolution.
	"""
	const Lindblad = preload("res://Core/QuantumSubstrate/LindbladEvolution.gd")

	var rho = qubit.to_density_matrix()
	var operators_to_apply = []

	for jump_data in jump_operators:
		var op_type = jump_data["operator_type"]
		var base_rate = jump_data["base_rate"]
		var effective_rate = base_rate * active_strength

		var operator_matrix = null
		match op_type:
			"dephasing":
				operator_matrix = Lindblad.sigma_z()
				effective_rate *= 0.5  # σ_z needs factor of 0.5
			"damping":
				operator_matrix = Lindblad.sigma_minus()
			"pumping":
				operator_matrix = Lindblad.sigma_plus()
			"phase_flip":
				operator_matrix = Lindblad.sigma_z()
			"bit_flip":
				operator_matrix = Lindblad.sigma_x()

		if operator_matrix != null:
			operators_to_apply.append({
				"operator": operator_matrix,
				"rate": effective_rate
			})

	# Apply all jump operators
	if not operators_to_apply.is_empty():
		rho = Lindblad.apply_lindblad_step_2x2(rho, operators_to_apply, dt)
		qubit.from_density_matrix(rho)


func _apply_custom_lindblad_to_pair(pair, dt: float) -> void:
	"""Apply custom Lindblad operators to entangled pair (4x4 density matrix)

	FIX: Now applies Icon effects to pairs without modifying T₁/T₂ times.
	"""
	const Lindblad = preload("res://Core/QuantumSubstrate/LindbladEvolution.gd")

	# Get effective temperature for this Icon
	var temp = get_effective_temperature()

	# Apply standard T₁/T₂ decoherence with Icon temperature
	# This uses the LindbladEvolution module which handles it correctly
	pair.density_matrix = Lindblad.apply_two_qubit_decoherence_4x4(
		pair.density_matrix,
		dt,
		temp,
		100.0  # base T₁ time
	)


## Icon Effects Summary

func get_physics_description() -> String:
	"""Return human-readable description of Icon's physical effects

	For educational tooltips and codex entries.
	"""
	var desc = "[%s %s]\n" % [icon_emoji, icon_name]

	desc += "Temperature: %.1f K (base) + %.1f K (active)\n" % [
		base_temperature,
		temperature_scaling * active_strength * 80.0
	]

	if jump_operators.size() > 0:
		desc += "Quantum Effects:\n"
		for jump in jump_operators:
			var op_type = jump["operator_type"]
			var rate = jump["base_rate"] * active_strength
			desc += "  - %s (Γ=%.3f/s)\n" % [op_type, rate]

	if hamiltonian_operator != "":
		desc += "Coherent Drive: %s (Ω=%.3f)\n" % [hamiltonian_operator, hamiltonian_coupling * active_strength]

	return desc


func get_visual_effect() -> Dictionary:
	"""Return visual effect parameters for rendering

	Override in subclasses for Icon-specific visuals.
	"""
	return {
		"type": "generic",
		"color": Color.WHITE,
		"particle_type": "none",
		"intensity": active_strength
	}


## Debug

func get_debug_string() -> String:
	var base = super.get_debug_string()
	var temp = get_effective_temperature()
	var jump_count = jump_operators.size()
	return base + " | T=%.1fK | Jumps: %d" % [temp, jump_count]
