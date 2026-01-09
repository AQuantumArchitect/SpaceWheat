class_name CarrionThroneIcon
extends "res://Core/Icons/LindbladIcon.gd"

## Carrion Throne Icon - Imperial Wheat, Quotas, Authority, Extraction
## Extends LindbladIcon with measurement-like collapse and extractive effects
##
## The Yang to Biotic's Yin, the Order to Chaos's Disorder:
## - Increases temperature slightly (industrial efficiency, not organic cooling)
## - Collapses superposition (measurement pressure)
## - Extracts energy (resources flow to Empire)
## - Suppresses evolution (Quantum Zeno effect)
##
## Physics: Represents quantum measurement bath + extractive coupling
## - Measurement operators (partial collapse)
## - Extractive damping (σ_- operator, energy drain)
## - Zeno suppression (frequent measurement freezes evolution)

## Political Season Strange Attractor (from Revolutionary Biome Collection)
## 4-dimensional agricultural-political feedback system
var harvest_decay_state: Vector2 = Vector2(0.7, 0.3)    # 🌾🍂 (Harvest/Decay)
var labor_conflict_state: Vector2 = Vector2(0.5, 0.5)   # 👥⚔️ (Labor/Conflict)
var authority_growth_state: Vector2 = Vector2(0.8, 0.2) # 🏰🌱 (Authority/Growth)
var wealth_void_state: Vector2 = Vector2(0.3, 0.7)      # 💰🕳️ (Wealth/Void)

# Strange attractor parameters
var seasonal_frequency: float = 0.5
var conflict_coupling: float = 0.3
var wealth_decay_rate: float = 0.2
var harvest_authority_link: float = 0.4

# Attractor history for visualization (stores 4D state snapshots)
var attractor_history: Array[Dictionary] = []
const MAX_HISTORY_LENGTH = 200  # Keep last 200 samples
var system_time: float = 0.0

func _ready():
	super._ready()

	# Icon identity
	icon_name = "Carrion Throne"
	icon_emoji = "🏰"

	# Temperature modulation: MODERATE COOLING (industrial efficiency)
	base_temperature = 20.0
	temperature_scaling = -0.5  # Moderate cooling (not as strong as Biotic)

	# Initialize quantum effects
	_initialize_jump_operators()

	# Initialize political season strange attractor
	_initialize_political_attractor()


## Lindblad Jump Operators

func _initialize_jump_operators():
	"""Define jump operators for quantum measurement and extraction

	Unlike Biotic (pumping + stabilization) or Chaos (dephasing + damping),
	Carrion Throne uses measurement-like operators:
	- Measurement (projective): Partial collapse toward |0⟩ or |1⟩
	- Extraction (σ_-): Energy drain to imperial treasury
	- Zeno suppression: Frequent measurement freezes evolution
	"""

	# Moderate measurement-like collapse (drives toward classical states)
	jump_operators.append({
		"operator_type": "measurement_z",  # Z-basis measurement
		"base_rate": 0.10  # Moderate - repeated measurement
	})

	# Strong extraction (energy drain to Empire)
	jump_operators.append({
		"operator_type": "damping",  # σ_- operator (energy loss)
		"base_rate": 0.12  # Strong extraction
	})

	# Note: Zeno suppression is implemented directly in apply_to_qubit()


## Temperature Modulation (Moderate Cooling)

func get_effective_temperature() -> float:
	"""Calculate effective temperature from Imperial influence

	Carrion Throne creates MODERATE cooling (industrial efficiency).
	- Not as strong as Biotic's organic cooling (-60K)
	- Opposite of Chaos's heating (+80K)
	- Represents mechanized order (-30K)

	Returns:
		Temperature (Kelvin)
		- 0% activation: 20K (baseline)
		- 100% activation: ~10K (moderate cooling)
	"""
	var cooling_amount = active_strength * 30.0  # Half of Biotic's 60K
	return max(5.0, base_temperature - cooling_amount)  # Clamp to min 5K


func get_T1_modifier() -> float:
	"""Get T₁ time modifier based on Icon effects

	Moderate cooling INCREASES T₁ time (slower energy relaxation).

	Returns:
		Multiplier for T₁ (1.0 = no effect, > 1.0 = slower damping)
	"""
	var temp = get_effective_temperature()
	# Lower temperature → longer T₁ (but not as strong as Biotic)
	return 50.0 / (temp + 1.0)  # Half of Biotic's effect


func get_T2_modifier() -> float:
	"""Get T₂ time modifier based on Icon effects

	Moderate cooling INCREASES T₂ time (slower dephasing).
	BUT: Measurement pressure DECREASES T₂ (collapses phase)

	These effects partially cancel!

	Returns:
		Multiplier for T₂ (1.0 = no effect)
	"""
	var temp = get_effective_temperature()
	var cooling_benefit = 50.0 / (temp + 1.0)  # Cooling helps

	# But measurement pressure hurts phase coherence
	var measurement_penalty = 1.0 - (active_strength * 0.4)  # Down to 0.6x

	# Net effect (they partially cancel)
	return cooling_benefit * measurement_penalty


## Measurement Pressure (Direct Collapse)

func apply_to_qubit(qubit, dt: float) -> void:
	"""Apply Carrion Throne's quantum effects to a single qubit

	Imperial pressure creates:
	1. Temperature modulation (industrial cooling)
	2. Measurement-like collapse (partial projection)
	3. Extractive damping (energy drain)
	4. Evolution suppression (Quantum Zeno)

	Args:
		qubit: DualEmojiQubit to affect
		dt: Time step (seconds)
	"""
	if active_strength <= 0.0:
		return

	# Skip if qubit is part of entangled pair (handled at pair level)
	if qubit.entangled_pair != null:
		return

	# 1. Set environment temperature (industrial cooling)
	var temp = get_effective_temperature()
	qubit.environment_temperature = temp

	# 2. Apply jump operators (measurement + extraction)
	if not jump_operators.is_empty():
		_apply_custom_lindblad(qubit, dt)

	# 3. Measurement-induced collapse (drives toward |0⟩ or |1⟩)
	_apply_measurement_pressure(qubit, dt)

	# 4. Extractive energy drain (resources flow to Empire)
	_apply_imperial_extraction(qubit, dt)


func _apply_measurement_pressure(qubit, dt: float) -> void:
	"""Apply measurement-like pressure that collapses superposition

	Physics: Frequent measurement in quantum mechanics causes partial
	collapse toward measurement eigenstates.

	Imperial interpretation: Quotas force quantum possibilities to collapse
	into definite classical outcomes.
	"""
	var measurement_rate = 0.15 * active_strength  # 15% collapse per second at full activation

	# Collapse toward nearest pole (|0⟩ or |1⟩)
	# θ near 0 → drive to 0
	# θ near π → drive to π
	var target_theta = 0.0 if qubit.theta < PI/2 else PI

	# Partial collapse (not instant)
	qubit.theta = lerp(qubit.theta, target_theta, measurement_rate * dt)

	# Also randomize phase (measurement destroys phase coherence)
	var phase_randomization = 0.1 * active_strength * dt
	qubit.phi += randf_range(-phase_randomization, phase_randomization)


func _apply_imperial_extraction(qubit, dt: float) -> void:
	"""Extract energy from qubit (resources flow to Empire)

	Physics: Coupling to external bath drains energy.

	Imperial interpretation: Quotas extract productivity, leaving
	the system depleted.
	"""
	var extraction_rate = 0.08 * active_strength  # 8% energy drain per second

	# Drain energy (move toward ground state |0⟩)
	# This is equivalent to amplitude damping
	var current_excited_prob = sin(qubit.theta / 2.0) ** 2
	var target_excited_prob = current_excited_prob * (1.0 - extraction_rate * dt)

	# Convert back to theta
	qubit.theta = 2.0 * asin(sqrt(clamp(target_excited_prob, 0.0, 1.0)))


## Growth Modulation (Inverted-U Curve)

func get_growth_modifier() -> float:
	"""Get growth rate multiplier for wheat cultivation

	Imperial pressure has dual effect:
	- LOW pressure (0-40%): Slight boost (order, efficiency) → 1.0x to 1.2x
	- MODERATE pressure (40-70%): Strong boost (deadline motivation) → 1.2x to 1.5x
	- HIGH pressure (70-100%): Penalty (oppression, exhaustion) → 1.5x down to 0.8x

	Creates inverted-U curve: optimal at ~60% activation.

	Returns:
		Growth speed multiplier (0.8x to 1.5x)
	"""
	if active_strength < 0.4:
		# Low pressure: slight efficiency boost
		return 1.0 + (active_strength * 0.5)  # 1.0x to 1.2x

	elif active_strength < 0.7:
		# Moderate pressure: strong motivation
		var normalized = (active_strength - 0.4) / 0.3  # 0 to 1
		return 1.2 + (normalized * 0.3)  # 1.2x to 1.5x

	else:
		# High pressure: oppressive penalty
		var normalized = (active_strength - 0.7) / 0.3  # 0 to 1
		return 1.5 - (normalized * 0.7)  # 1.5x down to 0.8x


## Entanglement Suppression

func get_entanglement_strength_modifier() -> float:
	"""Get entanglement strength multiplier

	Imperial measurement pressure WEAKENS entanglement bonds.

	Physics: Measurement on one qubit of entangled pair breaks correlation.

	Returns:
		Entanglement strength multiplier (1.0x to 0.5x)
	"""
	return 1.0 - (active_strength * 0.5)  # Down to 0.5x at full pressure


## Activation Logic

func calculate_activation_from_quota(current_wheat: int, quota_target: int, time_remaining: float, total_time: float) -> float:
	"""Calculate activation based on quota progress and deadline

	Activation increases when:
	- Far from quota target (need to produce more)
	- Close to deadline (time pressure)

	Args:
		current_wheat: Wheat harvested so far
		quota_target: Required wheat amount
		time_remaining: Seconds until deadline
		total_time: Total time for quota period

	Returns:
		Activation strength (0.0 to 1.0)
	"""
	# Progress ratio (0 = nothing, 1 = quota met)
	var progress = clamp(float(current_wheat) / float(max(1, quota_target)), 0.0, 1.0)
	var shortfall_pressure = 1.0 - progress  # 1.0 when behind, 0.0 when complete

	# Time urgency (0 = just started, 1 = deadline imminent)
	var elapsed_ratio = 1.0 - clamp(time_remaining / max(1.0, total_time), 0.0, 1.0)
	var time_pressure = elapsed_ratio ** 2  # Quadratic - pressure accelerates near deadline

	# Combined activation (weighted average)
	var base_activation = (shortfall_pressure * 0.6) + (time_pressure * 0.4)

	# If quota is ALREADY MET, pressure drops to minimum
	if current_wheat >= quota_target:
		base_activation = 0.1  # Residual imperial presence

	active_strength = clamp(base_activation, 0.0, 1.0)
	return active_strength


func calculate_activation_from_deadline(time_remaining: float, total_time: float) -> float:
	"""Calculate activation based ONLY on deadline (simplified)

	Args:
		time_remaining: Seconds until deadline
		total_time: Total time period

	Returns:
		Activation strength (0.0 to 1.0)
	"""
	var urgency = 1.0 - clamp(time_remaining / max(1.0, total_time), 0.0, 1.0)
	active_strength = clamp(urgency ** 2, 0.0, 1.0)  # Quadratic acceleration
	return active_strength


## Visual Effects

func get_visual_effect() -> Dictionary:
	"""Return visual effect parameters for rendering

	Carrion Throne: Cold metallic gold, geometric, mechanical, oppressive.
	"""
	return {
		"type": "imperial_order",
		"color": Color(0.7, 0.6, 0.2, 0.8),  # Cold gold/amber (not warm)
		"particle_type": "geometric",         # Sharp, angular particles
		"flow_pattern": "marching",          # Ordered, regimented movement
		"sound": "industrial_hum",           # Mechanical, grinding
		"glow_radius": int(active_strength * 20),
		"oppression_overlay": active_strength * 0.2,  # Screen darkening (oppression)
		"particle_density": int(active_strength * 40),
		"intensity": active_strength,
		"geometric_sharpness": active_strength * 0.8  # Harsh edges
	}


## Icon Effects Summary

func get_physics_description() -> String:
	"""Return human-readable description of Icon's physical effects

	For educational tooltips and codex entries.
	"""
	var desc = "[%s %s]\n" % [icon_emoji, icon_name]

	desc += "Temperature: %.1f K (%.0f%% cooling)\n" % [
		get_effective_temperature(),
		(1.0 - get_effective_temperature() / base_temperature) * 100
	]

	desc += "Measurement Collapse: %.1f%%/s\n" % (active_strength * 15.0)
	desc += "Energy Extraction: %.1f%%/s\n" % (active_strength * 8.0)
	desc += "Growth Rate: %.2fx\n" % get_growth_modifier()
	desc += "Entanglement Strength: %.2fx\n" % get_entanglement_strength_modifier()

	if jump_operators.size() > 0:
		desc += "Quantum Effects:\n"
		for jump in jump_operators:
			var op_type = jump["operator_type"]
			var rate = jump["base_rate"] * active_strength
			desc += "  - %s (Γ=%.3f/s)\n" % [op_type, rate]

	desc += "\nPhysics: Quantum measurement bath + extractive coupling"
	desc += "\nEffect: Order through control, extraction through measurement"

	return desc


## Political Season Strange Attractor

func update_political_season(dt: float) -> void:
	"""Update the political season strange attractor

	Call this from game loop to evolve the attractor over time.
	"""
	if active_strength > 0.0:  # Only evolve when Icon is active
		evolve_political_attractor(dt)


func _initialize_political_attractor() -> void:
	"""Initialize the 4D political-agricultural strange attractor"""
	# Reset to initial conditions
	harvest_decay_state = Vector2(0.7, 0.3)
	labor_conflict_state = Vector2(0.5, 0.5)
	authority_growth_state = Vector2(0.8, 0.2)
	wealth_void_state = Vector2(0.3, 0.7)

	attractor_history.clear()
	system_time = 0.0


func evolve_political_attractor(dt: float) -> void:
	"""Evolve the political season strange attractor

	Based on Revolutionary Biome Collection design.
	Creates feedback loops between harvest, labor, authority, and wealth.
	"""
	system_time += dt

	# 1. Seasonal harvest cycle drives everything
	var season_phase = seasonal_frequency * system_time
	harvest_decay_state.x += 0.1 * sin(season_phase) * dt
	harvest_decay_state.y += 0.1 * cos(season_phase) * dt
	harvest_decay_state = harvest_decay_state.limit_length(1.0)

	# 2. Labor-Authority feedback (political instability)
	labor_conflict_state.x += conflict_coupling * authority_growth_state.x * dt
	authority_growth_state.y -= conflict_coupling * labor_conflict_state.y * dt

	# 3. Wealth accumulation and decay
	wealth_void_state.x *= (1.0 - wealth_decay_rate * dt)
	wealth_void_state.y += wealth_decay_rate * harvest_decay_state.x * dt

	# 4. Harvest success affects political legitimacy
	authority_growth_state.x += harvest_authority_link * harvest_decay_state.x * dt

	# 5. Authority affects labor allocation
	labor_conflict_state.y -= 0.2 * authority_growth_state.x * dt

	# Normalize to keep on unit circles
	labor_conflict_state = labor_conflict_state.limit_length(1.0)
	authority_growth_state = authority_growth_state.limit_length(1.0)
	wealth_void_state = wealth_void_state.limit_length(1.0)

	# Store snapshot for visualization
	_record_attractor_snapshot()


func _record_attractor_snapshot() -> void:
	"""Record current 4D state for strange attractor visualization"""
	var snapshot = {
		"time": system_time,
		"harvest_decay": harvest_decay_state,
		"labor_conflict": labor_conflict_state,
		"authority_growth": authority_growth_state,
		"wealth_void": wealth_void_state
	}

	attractor_history.append(snapshot)

	# Keep history bounded
	if attractor_history.size() > MAX_HISTORY_LENGTH:
		attractor_history.remove_at(0)


func get_attractor_history() -> Array[Dictionary]:
	"""Get strange attractor history for visualization"""
	return attractor_history


func get_political_season() -> String:
	"""Get current political season based on attractor phase"""
	var phase = fmod(seasonal_frequency * system_time, TAU)

	if phase < PI/2:
		return "Spring Growth 🌱"
	elif phase < PI:
		return "Summer Labor 👥"
	elif phase < 3*PI/2:
		return "Autumn Harvest 🌾"
	else:
		return "Winter Authority 🏰"


func project_4d_to_2d(snapshot: Dictionary) -> Vector2:
	"""Project 4D political attractor to 2D for visualization

	Uses PCA-like projection to flatten 4D state to viewable 2D space.

	Returns:
		2D projection suitable for drawing
	"""
	var h = snapshot["harvest_decay"]
	var l = snapshot["labor_conflict"]
	var a = snapshot["authority_growth"]
	var w = snapshot["wealth_void"]

	# Project onto 2 principal components
	# Component 1: Harvest-Authority axis (economic success)
	var x = (h.x + a.x) * 0.5

	# Component 2: Labor-Wealth axis (social tension)
	var y = (l.y + w.y) * 0.5

	return Vector2(x, y) * 200.0  # Scale for visibility


## Debug

func get_debug_string() -> String:
	var base = super.get_debug_string()
	var temp = get_effective_temperature()
	var growth = get_growth_modifier()
	return base + " | T=%.1fK | Growth: %.2fx | Extract: %.0f%%" % [temp, growth, active_strength * 8.0]
