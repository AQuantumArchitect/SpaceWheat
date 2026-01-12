class_name StrangeAttractorAnalyzer
extends RefCounted

## Strange Attractor Analysis - Phase Space Trajectory Classifier
##
## Records biome evolution as trajectory through phase space and classifies
## attractor personality to give each civilization unique topological identity.
##
## Architecture:
## - Records Observable Vector3(emoji1, emoji2, emoji3) each evolution step
## - Maintains rolling window of last 1000-2000 points
## - Computes attractor signature every N frames
## - Classifies personality: "stable", "cyclic", "chaotic", "explosive"
##
## Physics:
## - Strange attractors are the hallmark of chaotic dynamical systems
## - Lyapunov exponents measure sensitivity to initial conditions
## - Periodic attractors show up as closed loops in phase space
## - Fixed points are stable equilibria

## ========================================
## Configuration
## ========================================

## Which 3 emojis define the phase space axes
var selected_emojis: Array[String] = []

## Maximum trajectory length (rolling window)
var max_trajectory_length: int = 1500

## How often to update signature (frames)
var signature_update_interval: int = 60

## ========================================
## State
## ========================================

## Phase space trajectory (3D points)
var trajectory: Array[Vector3] = []

## Current attractor signature (cached)
var current_signature: Dictionary = {}

## Frames since last signature update
var frames_since_update: int = 0

## ========================================
## Cached Metrics (for performance)
## ========================================

var _cached_centroid: Vector3 = Vector3.ZERO
var _cached_spread: float = 0.0
var _cached_periodicity: float = 0.0
var _cached_lyapunov: float = 0.0

## ========================================
## Public API
## ========================================

func initialize(emoji_axes: Array[String]):
	"""Set which 3 emojis define the phase space axes

	Args:
		emoji_axes: Array of exactly 3 emoji strings
	"""
	assert(emoji_axes.size() == 3, "Must provide exactly 3 emojis for axes")
	selected_emojis = emoji_axes.duplicate()
	trajectory.clear()
	current_signature = {}
	frames_since_update = 0

	print("📊 StrangeAttractorAnalyzer initialized: %s" % str(emoji_axes))


func record_snapshot(observables: Dictionary):
	"""Record current state as point in phase space

	Args:
		observables: Dictionary mapping emoji -> population probability
	"""
	if selected_emojis.is_empty():
		push_warning("StrangeAttractorAnalyzer: No emojis selected")
		return

	# Extract values for selected axes
	var point = Vector3(
		observables.get(selected_emojis[0], 0.0),
		observables.get(selected_emojis[1], 0.0),
		observables.get(selected_emojis[2], 0.0)
	)

	trajectory.append(point)

	# Maintain rolling window
	if trajectory.size() > max_trajectory_length:
		trajectory.pop_front()

	# Periodically update signature
	frames_since_update += 1
	if frames_since_update >= signature_update_interval:
		frames_since_update = 0
		_update_signature()


func get_signature() -> Dictionary:
	"""Get current attractor signature (cached)

	Returns:
		Dictionary with keys:
		  - personality: String (stable/cyclic/chaotic/explosive/irregular)
		  - centroid: Vector3
		  - spread: float
		  - periodicity: float
		  - lyapunov_exponent: float
		  - trajectory_length: int
	"""
	return current_signature


func get_personality() -> String:
	"""Get classified personality: stable/cyclic/chaotic/explosive/irregular

	Returns:
		Personality string
	"""
	return current_signature.get("personality", "unknown")


func get_trajectory() -> Array[Vector3]:
	"""Get raw trajectory data (for visualization)

	Returns:
		Array of Vector3 points in phase space
	"""
	return trajectory


func get_trajectory_normalized() -> Array[Vector3]:
	"""Get trajectory normalized to [0,1] cube for visualization

	Returns:
		Array of Vector3 points normalized to unit cube
	"""
	if trajectory.is_empty():
		return []

	# Find bounds
	var min_val = trajectory[0]
	var max_val = trajectory[0]

	for point in trajectory:
		min_val.x = min(min_val.x, point.x)
		min_val.y = min(min_val.y, point.y)
		min_val.z = min(min_val.z, point.z)

		max_val.x = max(max_val.x, point.x)
		max_val.y = max(max_val.y, point.y)
		max_val.z = max(max_val.z, point.z)

	var range_val = max_val - min_val

	# Avoid division by zero
	if range_val.x < 0.001:
		range_val.x = 1.0
	if range_val.y < 0.001:
		range_val.y = 1.0
	if range_val.z < 0.001:
		range_val.z = 1.0

	# Normalize
	var normalized: Array[Vector3] = []
	for point in trajectory:
		var norm_point = (point - min_val) / range_val
		normalized.append(norm_point)

	return normalized


## ========================================
## Analysis Functions
## ========================================

func _update_signature():
	"""Compute attractor signature from trajectory"""
	if trajectory.size() < 50:
		current_signature = {
			"status": "insufficient_data",
			"personality": "unknown",
			"trajectory_length": trajectory.size()
		}
		return

	# Compute metrics
	_cached_centroid = _compute_centroid()
	_cached_spread = _compute_spread()
	_cached_periodicity = _detect_periodicity()
	_cached_lyapunov = _estimate_lyapunov_exponent()

	# Classify personality
	var personality = _classify_personality()

	current_signature = {
		"personality": personality,
		"centroid": _cached_centroid,
		"spread": _cached_spread,
		"periodicity": _cached_periodicity,
		"lyapunov_exponent": _cached_lyapunov,
		"trajectory_length": trajectory.size()
	}


func _compute_centroid() -> Vector3:
	"""Compute center of mass of trajectory

	Returns:
		Average position in phase space
	"""
	if trajectory.is_empty():
		return Vector3.ZERO

	var sum = Vector3.ZERO
	for point in trajectory:
		sum += point

	return sum / float(trajectory.size())


func _compute_spread() -> float:
	"""Compute average distance from centroid (measure of volatility)

	Returns:
		Average distance from centroid (0.0 = collapsed, high = dispersed)
	"""
	if trajectory.size() < 2:
		return 0.0

	var centroid = _cached_centroid
	var sum_dist = 0.0

	for point in trajectory:
		sum_dist += point.distance_to(centroid)

	return sum_dist / float(trajectory.size())


func _detect_periodicity() -> float:
	"""Detect periodic patterns via autocorrelation

	Uses simple lag-based autocorrelation to detect repeating patterns.

	Returns:
		Periodicity score (0.0 = chaotic, 1.0 = perfect cycle)
	"""
	if trajectory.size() < 50:
		return 0.0

	# Simple autocorrelation at lag = trajectory.size() / 4
	var lag = int(trajectory.size() / 4.0)
	if lag < 10:
		return 0.0

	var correlation = 0.0
	var count = 0

	for i in range(trajectory.size() - lag):
		var dist = trajectory[i].distance_to(trajectory[i + lag])
		# Closer points = higher correlation
		correlation += 1.0 / (1.0 + dist)
		count += 1

	return correlation / float(count)


func _estimate_lyapunov_exponent() -> float:
	"""Estimate largest Lyapunov exponent (chaos indicator)

	Simplified estimation: measures average divergence rate of nearby trajectories.
	Real Lyapunov calculation requires tracking perturbations over time.

	Returns:
		Approximate Lyapunov exponent:
		  < 0.0 = stable (fixed point)
		  ~ 0.0 = cyclic (limit cycle)
		  > 0.0 = chaotic (strange attractor)
	"""
	if trajectory.size() < 100:
		return 0.0

	# Simplified estimation: measure average divergence rate
	var divergence_samples: Array[float] = []
	var sample_interval = 10  # Compare points 10 steps apart

	for i in range(50, trajectory.size() - sample_interval):
		var p1 = trajectory[i]
		var p2 = trajectory[i + sample_interval]
		var dist = p1.distance_to(p2)

		if dist > 0.001:  # Avoid log(0)
			divergence_samples.append(log(dist))

	if divergence_samples.is_empty():
		return 0.0

	# Average log divergence
	var sum_div = 0.0
	for d in divergence_samples:
		sum_div += d

	return sum_div / (float(divergence_samples.size()) * sample_interval)


func _classify_personality() -> String:
	"""Classify attractor based on metrics

	Classification rules:
	- Explosive: growing rapidly (high spread or high Lyapunov)
	- Chaotic: positive Lyapunov, low periodicity
	- Cyclic: high periodicity, low Lyapunov
	- Stable: negative Lyapunov or low spread (converging)
	- Irregular: everything else (transitional)

	Returns:
		Personality string
	"""
	var lyapunov = _cached_lyapunov
	var spread = _cached_spread
	var periodicity = _cached_periodicity

	# Explosive: growing rapidly
	if spread > 2.0 or lyapunov > 0.5:
		return "explosive"

	# Chaotic: positive Lyapunov, low periodicity
	if lyapunov > 0.05 and periodicity < 0.3:
		return "chaotic"

	# Cyclic: high periodicity, low Lyapunov
	if periodicity > 0.6 and lyapunov < 0.05:
		return "cyclic"

	# Stable: negative Lyapunov, converging to fixed point
	if lyapunov < -0.05 or spread < 0.2:
		return "stable"

	# Default
	return "irregular"


## ========================================
## Personality Descriptions (Static Utilities)
## ========================================

static func get_personality_description(personality: String) -> String:
	"""Get human-readable description of personality type

	Args:
		personality: Personality string

	Returns:
		Human-readable description
	"""
	match personality:
		"stable":
			return "Stable equilibrium - converges to fixed state"
		"cyclic":
			return "Rhythmic cycles - predictable oscillations"
		"chaotic":
			return "Strange attractor - complex, sensitive dynamics"
		"explosive":
			return "Explosive growth - rapidly expanding"
		"irregular":
			return "Irregular dynamics - transitional behavior"
		_:
			return "Unknown dynamics"


static func get_personality_color(personality: String) -> Color:
	"""Get color coding for personality type

	Args:
		personality: Personality string

	Returns:
		Color for UI display
	"""
	match personality:
		"stable":
			return Color.STEEL_BLUE
		"cyclic":
			return Color.MEDIUM_PURPLE
		"chaotic":
			return Color.ORANGE_RED
		"explosive":
			return Color.RED
		"irregular":
			return Color.YELLOW
		_:
			return Color.WHITE


static func get_personality_emoji(personality: String) -> String:
	"""Get emoji representation of personality type

	Args:
		personality: Personality string

	Returns:
		Emoji string
	"""
	match personality:
		"stable":
			return "🔵"
		"cyclic":
			return "🔄"
		"chaotic":
			return "🌀"
		"explosive":
			return "💥"
		"irregular":
			return "❓"
		_:
			return "⚪"
