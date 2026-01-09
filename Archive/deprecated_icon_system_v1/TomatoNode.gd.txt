class_name TomatoNode
extends Resource

## Minimal Quantum Tomato Node
## Represents one of the 12 conspiracy nodes with Bloch + Gaussian state

# Identification
@export var node_id: String = ""
@export var emoji_transform: String = ""  # e.g., "🌱→🍅"
@export var meaning: String = ""
@export var conspiracies: Array[String] = []

# Quantum state - Bloch sphere (semantic)
@export var theta: float = 0.0  # Polar angle [0, PI]
@export var phi: float = 0.0    # Azimuthal angle [-PI, PI]

# Quantum state - Gaussian CV (energy)
@export var q: float = 0.0  # Position quadrature
@export var p: float = 0.0  # Momentum quadrature

# Derived properties
var energy: float = 0.0
var active: bool = false

# Berry phase tracking (geometric phase accumulation)
var berry_phase: float = 0.0
var berry_phase_enabled: bool = false
var last_bloch_vector: Vector3 = Vector3.ZERO

# Connections (filled by network)
var connections: Dictionary = {}  # node_id -> strength


func _init():
	update_energy()


## Core quantum operations

func get_bloch_vector() -> Vector3:
	"""Convert Bloch angles to 3D Cartesian vector"""
	return Vector3(
		sin(theta) * cos(phi),
		sin(theta) * sin(phi),
		cos(theta)
	)


func update_energy():
	"""Calculate total energy from Gaussian and Bloch components"""
	# Gaussian energy (harmonic oscillator)
	var gaussian_energy = (q * q + p * p) / 2.0

	# Bloch energy (potential on sphere)
	var bloch_energy = 1.0 - cos(theta)

	energy = gaussian_energy + bloch_energy
	active = energy > 0.1


func evolve(dt: float):
	"""Simple time evolution - Bloch precession + Gaussian damping"""
	if not active:
		return

	# Store current Bloch vector for Berry phase calculation
	if berry_phase_enabled:
		var current_vector = get_bloch_vector()
		if last_bloch_vector != Vector3.ZERO:
			accumulate_berry_phase(last_bloch_vector, current_vector)
		last_bloch_vector = current_vector

	# Bloch sphere precession (energy-driven)
	theta += energy * dt * 0.05
	theta = clamp(theta, 0.0, PI)

	# Phase precession
	phi += dt * energy * 0.1
	phi = fmod(phi + PI, TAU) - PI  # Keep in [-PI, PI]

	# Gaussian damping (slowly decay to ground state)
	q *= 0.995
	p *= 0.995

	update_energy()


func get_semantic_blend() -> float:
	"""Returns value [0, 1] representing position between north/south poles"""
	return theta / PI


## Serialization

func to_dict() -> Dictionary:
	return {
		"node_id": node_id,
		"emoji_transform": emoji_transform,
		"meaning": meaning,
		"conspiracies": conspiracies,
		"theta": theta,
		"phi": phi,
		"q": q,
		"p": p,
		"energy": energy
	}


func from_dict(data: Dictionary):
	node_id = data.get("node_id", "")
	emoji_transform = data.get("emoji_transform", "")
	meaning = data.get("meaning", "")
	conspiracies = data.get("conspiracies", [])
	theta = data.get("theta", 0.0)
	phi = data.get("phi", 0.0)
	q = data.get("q", 0.0)
	p = data.get("p", 0.0)
	update_energy()


## Berry Phase Tracking

func enable_berry_phase_tracking() -> void:
	"""Enable Berry phase accumulation for this node"""
	berry_phase_enabled = true
	berry_phase = 0.0
	last_bloch_vector = get_bloch_vector()


func disable_berry_phase_tracking() -> void:
	"""Disable Berry phase tracking"""
	berry_phase_enabled = false
	berry_phase = 0.0
	last_bloch_vector = Vector3.ZERO


func accumulate_berry_phase(v1: Vector3, v2: Vector3) -> void:
	"""Accumulate Berry phase from Bloch sphere path segment

	Berry phase is the solid angle enclosed by the path on the sphere.
	For small segments, we use: dγ ≈ (v1 × v2) · n̂ / 2
	where n̂ is the normal to the plane formed by v1, v2, and origin.
	"""
	var cross_product = v1.cross(v2)
	var solid_angle = cross_product.length()

	# Determine sign from orientation
	var v_mid = (v1 + v2).normalized()
	if cross_product.dot(v_mid) < 0:
		solid_angle *= -1.0

	berry_phase += solid_angle / 2.0


func get_berry_phase() -> float:
	"""Get accumulated Berry phase"""
	return berry_phase


func reset_berry_phase() -> void:
	"""Reset Berry phase to zero (e.g., after completing a cycle)"""
	berry_phase = 0.0


## Debug output

func get_debug_string() -> String:
	var base = "[%s] %s | E=%.3f θ=%.2f φ=%.2f" % [node_id, emoji_transform, energy, theta, phi]
	if berry_phase_enabled:
		base += " | γ=%.3f" % berry_phase
	return base
