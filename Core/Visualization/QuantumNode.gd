class_name QuantumNode
extends RefCounted

# Shared constants

## Quantum Node - Force-Directed Graph Representation
## First-class quantum visualization that represents density matrix states directly.
##
## Core Philosophy:
## - Bubbles ARE the quantum state visualization (not farm plot decorations)
## - Query quantum computer directly via biome_resolver
## - Farm plots are OPTIONAL game mechanics that can display bubbles
##
## Quantum Data Source (in priority order):
## 1. Direct quantum register (biome_name + register_id) - PREFERRED
## 2. Terminal binding (v2 architecture) - game mechanic overlay
## 3. Farm plot overlay - optional game-surface anchor

# Optional type reference for farm plot overlays

# Physics state
var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var classical_anchor: Vector2 = Vector2.ZERO  # Position of classical plot (tether target)

# QUANTUM STATE REFERENCE (First-class source of truth)
var biome_name: String = ""        # Which biome's quantum computer to query
var register_id: int = -1          # Which qubit/register in that quantum computer
var plot_id: String = ""           # Unique identifier for this bubble

# Optional game mechanic overlays (can be null for pure quantum viz)
var plot: FarmPlot = null          # Optional: farm plot displaying this bubble
var terminal = null                # Optional: bound terminal for game mechanics
var grid_position: Vector2i = Vector2i.ZERO  # Optional: grid position if part of farm

# Visual properties (derived from quantum state)
var energy: float = 0.0
var purity: float = -1.0
var coherence: float = 1.0
var color: Color = Color.WHITE
var radius: float = 20.0
var berry_phase: float = 0.0  # Accumulated quantum evolution (experience points)

# DUAL EMOJI SYSTEM for quantum superposition visualization
var emoji_north: String = "🌾"  # North pole emoji (e.g., 🌾 for wheat)
var emoji_south: String = "👥"  # South pole emoji (e.g., 👥 for wheat)
var emoji_north_opacity: float = 1.0  # Probability-weighted opacity
var emoji_south_opacity: float = 0.0  # Probability-weighted opacity

# Parametric biome coordinates (for auto-scaling layout)
# Position is computed by BiomeLayoutCalculator from these coords
var parametric_t: float = 0.5      # Angular parameter [0, 1] around biome oval
var parametric_ring: float = 0.5   # Radial parameter [0, 1] (0=center, 1=edge)

# Farm plot tethering
# When true, this bubble is attached to a farm plot and should show tether lines
# When false, this is a free-floating biome bubble (no tether)
var has_farm_tether: bool = false

# Terminal bubble flag (v2 architecture)
# When true, this bubble represents a bound terminal (EXPLORE action)
# Emojis come from terminal binding, not plot data
# Should NOT call update_from_quantum_state() which would zero out opacities
var is_terminal_bubble: bool = false

# V2 Architecture: Biome resolver callback (set by manager)
# Callable that takes biome_name: String and returns BiomeBase or null
# This decouples QuantumNode from scene tree for biome lookup
var biome_resolver: Callable = Callable()

# Lifeless mode - no quantum data available, should not wiggle
var is_lifeless: bool = false

# Quantum behavior (controls how forces apply)
# 0 = FLOATING: Forces active, normal physics
# 1 = HOVERING: Fixed to anchor (biome measurement plots)
# 2 = FIXED: Completely static (celestial bodies)
var quantum_behavior: int = 0

# === AZIMUTHAL SEASON SYSTEM ===
# Three "seasons" at 120° offsets encode phi as RGB-like projections
# Each season's intensity = (1 + cos(phi - season_angle)) / 2
# This creates visible rotational dynamics from quantum phase evolution
var season_projections: Array[float] = [0.5, 0.5, 0.5]  # [R, G, B] season intensities
var season_angular_momentum: float = 0.0  # Frame-to-frame spin accumulation
var phi_raw: float = 0.0  # Raw phi for force calculations

# Season constants - imported from shared source
const SEASON_ANGLES = VisualizationConstants.SEASON_ANGLES
const SEASON_COLORS = VisualizationConstants.SEASON_COLORS
const _BalanceConfig = preload("res://Core/GameMechanics/BalanceConfig.gd")

# Animation properties
var visual_scale: float = 0.0  # Animated scale (0 to 1)
var visual_alpha: float = 0.0  # Animated alpha (0 to 1)
var spawn_time: float = 0.0    # Time when node was created
var is_spawning: bool = false  # Currently animating in

# Visibility (for single-biome filtering - not a Node2D so we manage manually)
var visible: bool = true

# Orbit trail history (for visualizing evolution path)
var position_history: Array[Vector2] = []  # Last N positions
const MAX_TRAIL_LENGTH: int = 30  # Number of positions to remember
var trail_update_timer: float = 0.0
const TRAIL_UPDATE_INTERVAL: float = 0.05  # Update every 50ms

# Constants
const MIN_RADIUS = 10.0
const MAX_RADIUS = 40.0
const SPAWN_DURATION = 0.5  # Fade-in duration in seconds


func _init(
	wheat_plot = null,  # FarmPlot or null for pure quantum viz
	anchor_pos: Vector2 = Vector2.ZERO,
	grid_pos: Vector2i = Vector2i.ZERO,
	center_pos: Vector2 = Vector2.ZERO
):
	# Initialize quantum node.

	# Two modes:
	# 1. Pure quantum visualization: Pass null for wheat_plot, set biome_name/register_id manually
	# 2. Farm plot mode: pass a FarmPlot instance
	plot = wheat_plot
	classical_anchor = anchor_pos
	grid_position = grid_pos

	# Start at the anchor location (or center if no anchor)
	position = anchor_pos if anchor_pos != Vector2.ZERO else center_pos

	# Initialize visual scale and alpha to 0.0 (spawn animation will fade in)
	# This prevents the "flash at full size" bug when bubbles are created
	visual_scale = 0.0
	visual_alpha = 0.0

	if plot:
		plot_id = plot.plot_id
		# Don't call update_from_quantum_state() yet - wait for biome_resolver to be set

	# Start empty - no emoji displayed until quantum state is queried
	emoji_north_opacity = 0.0
	emoji_south_opacity = 0.0


func start_spawn_animation(current_time: float):
	# Start the spawn animation for this node
	is_spawning = true
	spawn_time = current_time
	visual_scale = 0.0
	visual_alpha = 0.0


func update_animation(current_time: float, _delta: float):
	# Update spawn animation
	if is_lifeless:
		visual_scale = 0.0
		visual_alpha = 0.0
		return
	if not is_spawning:
		visual_scale = 1.0
		visual_alpha = 1.0
		return

	var elapsed = current_time - spawn_time
	var progress = clamp(elapsed / SPAWN_DURATION, 0.0, 1.0)

	# Ease-out cubic for smooth deceleration
	var eased = 1.0 - pow(1.0 - progress, 3.0)

	visual_scale = eased
	visual_alpha = eased

	if progress >= 1.0:
		is_spawning = false
		visual_scale = 1.0
		visual_alpha = 1.0


func apply_lifeless_visual(emojis_dict: Dictionary = {}) -> void:
	# Apply a disconnected/static visual state.
	is_lifeless = true
	is_spawning = false
	energy = 0.0
	purity = -1.0
	coherence = 0.0
	radius = MIN_RADIUS
	color = Color(0.4, 0.4, 0.5, 0.4)
	visual_scale = 0.0
	visual_alpha = 0.0

	if not emojis_dict.is_empty():
		emoji_north = emojis_dict.get("north", emoji_north)
		emoji_south = emojis_dict.get("south", emoji_south)
	emoji_north_opacity = 0.0
	emoji_south_opacity = 0.0


func apply_measured_visual(measured_outcome: String = "", north_value: String = "", south_value: String = "") -> void:
	# Apply a frozen measured visual state.
	is_lifeless = false
	is_spawning = false
	if north_value != "":
		emoji_north = north_value
	if south_value != "":
		emoji_south = south_value

	energy = 1.0
	purity = 1.0
	coherence = 0.0
	color = Color(0.75, 0.75, 0.75, 0.9)

	if measured_outcome != "":
		if measured_outcome == emoji_north:
			emoji_north_opacity = 1.0
			emoji_south_opacity = 0.0
		elif measured_outcome == emoji_south:
			emoji_north_opacity = 0.0
			emoji_south_opacity = 1.0
		else:
			emoji_north_opacity = 0.0
			emoji_south_opacity = 0.0
	else:
		emoji_north_opacity = 0.0
		emoji_south_opacity = 0.0


func apply_quantum_snapshot(snap: Dictionary, smooth_radius: bool = false) -> bool:
	# Apply a resolved quantum visualization snapshot to this node.
	if snap.is_empty():
		return false

	is_lifeless = false

	var north_prob = snap.get("p0", 0.5)
	var south_prob = snap.get("p1", 0.5)
	var mass = maxf(north_prob + south_prob, 1e-6)
	var p_north = clampf(north_prob / mass, 0.0, 1.0)
	var p_south = clampf(south_prob / mass, 0.0, 1.0)
	emoji_north_opacity = p_north * p_north
	emoji_south_opacity = p_south * p_south

	var coh_magnitude = snap.get("r_xy", 0.0) * 0.5
	var coh_phase = snap.get("phi", 0.0)
	color = VisualizationConstants.phase_to_hsv(coh_phase, coh_magnitude)

	var old_phi = phi_raw
	phi_raw = coh_phase
	season_projections = VisualizationConstants.season_projections(phi_raw, coh_magnitude)

	var delta_phi = phi_raw - old_phi
	while delta_phi > PI:
		delta_phi -= TAU
	while delta_phi < -PI:
		delta_phi += TAU
	season_angular_momentum = season_angular_momentum * 0.8 + delta_phi * 0.2

	var snap_purity = snap.get("purity", -1.0)
	purity = snap_purity if snap_purity >= 0.0 else -1.0
	energy = purity  # Legacy alias retained for older renderers/tools
	coherence = coh_magnitude

	# Radius channel = Bloch/subspace radius — an OPEN-system mixedness encoding
	# (dissipation shrinks the reduced state). In the closed (unitary) system the
	# contract is "r = 1 forever" (see docs/CLOSED_SYSTEM.md), so bubbles render at
	# full size; the per-qubit reduced radius still dips under entanglement, but the
	# closed system has no dissipative mixedness to show, so we don't shrink for it.
	# (Without this, a missing/entangled r_bloch defaulted toward 0 → MIN_RADIUS →
	# every bubble tiny once the open-system radius driver was removed — #119.)
	var target_radius: float
	if _BalanceConfig.is_closed_system():
		target_radius = MAX_RADIUS
	else:
		var r_bloch = snap.get("r_bloch", 0.0)
		target_radius = lerpf(MIN_RADIUS, MAX_RADIUS, r_bloch)
	radius = lerpf(radius, target_radius, 0.15) if smooth_radius else target_radius

	berry_phase = coh_magnitude * TAU
	return true


func update_from_quantum_state(batcher = null):
	# Update visual properties from quantum state (first-class quantum visualization).

	# Args:
	# batcher: Optional BiomeEvolutionBatcher for smooth 60fps interpolation.
	# If provided and lookahead is enabled, uses interpolated snapshots
	# between physics frames for buttery smooth visuals.

	# Queries quantum computer directly via biome_resolver + biome_name.
	# No plot dependency - bubbles are independent quantum visualizations.

	# Visual mapping (no duplicates):
	# - Emoji opacity ← Normalized probabilities (θ-like, measurement outcome)
	# - Color hue ← Coherence phase arg(ρ_{n,s}) (φ-like, quantum phase)
	# - Color saturation ← Coherence magnitude (quantum vs classical)
	# - Glow ← coherence / Berry phase
	# - Radius ← Bloch/subspace radius only
	# - Purity ← explicit status ring / halo, not body size
	# - Motion policy/channel ownership lives in QuantumVisualGrammar
	var is_transitioning_planted = (radius == MAX_RADIUS)

	# === DETERMINE BIOME SOURCE (priority order) ===
	# 1. Direct quantum register (biome_name + register_id) - PREFERRED
	# 2. Terminal binding (game mechanic overlay)
	var biome = null

	if biome_name != "" and biome_resolver.is_valid():
		biome = biome_resolver.call(biome_name)
		if not biome and register_id == 0:
			print("    [LIFELESS] Biome '%s' not found via resolver" % biome_name)

	elif terminal and terminal.is_bound:
		if biome_resolver.is_valid() and terminal.bound_biome_name != "":
			biome = biome_resolver.call(terminal.bound_biome_name)
			if not biome_name:
				biome_name = terminal.bound_biome_name

	# Guard: no biome or no viz payload → LIFELESS fallback (no wiggle)
	if not biome or not biome.viz_cache or not biome.viz_cache.has_metadata():
		# Try to get emojis from either source
		var emojis_dict = {}
		if terminal and terminal.is_bound:
			emojis_dict = {"north": terminal.north_emoji, "south": terminal.south_emoji}
		elif plot:
			emojis_dict = plot.get_plot_emojis()
		apply_lifeless_visual(emojis_dict)
		return

	# Has real quantum data - not lifeless
	is_lifeless = false

	# === CHECK IF MEASURED: If so, freeze at measurement outcome ===
	var is_measured_now = is_terminal_measured()
	if is_measured_now:
		if terminal and terminal.is_measured and terminal.measured_outcome:
			apply_measured_visual(terminal.measured_outcome, terminal.north_emoji, terminal.south_emoji)
		else:
			apply_measured_visual()
		return

	# === QUERY BIOME FOR REAL QUANTUM DATA (UNMEASURED ONLY) ===
	# Get emojis from either terminal or plot
	var emojis = {}
	if terminal and terminal.is_bound:
		emojis = {"north": terminal.north_emoji, "south": terminal.south_emoji}
	elif plot:
		emojis = plot.get_plot_emojis()

	emoji_north = emojis.get("north", emoji_north)
	emoji_south = emojis.get("south", emoji_south)

	# Prefer cached visualization metrics from biome viz_cache (fast path)
	# If batcher is provided with lookahead, use interpolated snapshot for smooth 60fps
	var qubit_index = -1
	var snap: Dictionary = {}
	if biome and biome.viz_cache:
		qubit_index = biome.viz_cache.get_qubit(emoji_north)
		# Use interpolated snapshot for smooth visuals between physics frames
		if batcher and batcher.lookahead_enabled and qubit_index >= 0:
			snap = batcher.get_interpolated_snapshot(biome_name, qubit_index)
		else:
			snap = biome.viz_cache.get_snapshot(qubit_index)

	if snap.is_empty():
		apply_lifeless_visual({"north": emoji_north, "south": emoji_south})
		return
	apply_quantum_snapshot(snap)
	var north_prob = snap.get("p0", 0.5)
	var south_prob = snap.get("p1", 0.5)
	var coh_magnitude = snap.get("r_xy", 0.0) * 0.5
	var coh_phase = snap.get("phi", 0.0)
	var x_val = snap.get("x", 0.0)
	var y_val = snap.get("y", 0.0)

	# DEBUG: Log phi values occasionally (every 100 frames for first qubit)
	if register_id == 0 and Engine.get_process_frames() % 100 == 0:
		_test_log("trace", "🧬", "Node q%d: φ=%.4f, x=%.4f, y=%.4f, r_xy=%.4f, p0=%.3f" % [
			register_id, coh_phase, x_val, y_val, coh_magnitude * 2.0, north_prob])

	if is_transitioning_planted:
		var verbose = _get_verbose()
		if verbose:
			verbose.debug("quantum", "⚛️", "Node %s: θ=(%.2f/%.2f) φ=%.1f° purity=%.3f |coh|=%.3f mass=%.3f" % [
				grid_position, emoji_north_opacity, emoji_south_opacity,
				rad_to_deg(coh_phase), purity, coh_magnitude, north_prob + south_prob])


func update_position(delta: float):
	# Update position from velocity
	position += velocity * delta

	# Update orbit trail history
	trail_update_timer += delta
	if trail_update_timer >= TRAIL_UPDATE_INTERVAL:
		trail_update_timer = 0.0
		position_history.append(position)
		if position_history.size() > MAX_TRAIL_LENGTH:
			position_history.remove_at(0)


func _test_log(_level: String, emoji: String, message: String) -> void:
	# Log test/debug messages with [TEST] prefix to VerboseConfig if available.
	var tree = Engine.get_main_loop()
	if not tree:
		return
	var verbose = (Engine.get_main_loop().root.get_node_or_null("/root/VerboseConfig") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if verbose:
		verbose.trace("test", emoji, message)


# ============================================================================
# V2 Architecture: Terminal-delegating computed properties
# ============================================================================

func get_emoji_north() -> String:
	# Get north emoji - delegates to terminal when available (v2 single source of truth)
	if terminal and terminal.is_bound:
		return terminal.north_emoji
	return emoji_north


func get_emoji_south() -> String:
	# Get south emoji - delegates to terminal when available (v2 single source of truth)
	if terminal and terminal.is_bound:
		return terminal.south_emoji
	return emoji_south


func get_emoji_opacities(biome = null) -> Dictionary:
	# Get emoji opacities computed from biome's density matrix at render time.

	# V2 Architecture: Opacities are computed fresh each frame from biome state.
	# This eliminates the need to cache/duplicate probability state.

	# Args:
	# biome: BiomeBase to query for probabilities (optional)

	# Returns:
	# Dictionary with "north" and "south" opacity values (0.0-1.0)
	# If no terminal or not bound, use cached values
	if not terminal or not terminal.is_bound:
		return {"north": emoji_north_opacity, "south": emoji_south_opacity}

	# If measured, show only the measured outcome
	if terminal.is_measured:
		if terminal.measured_outcome == terminal.north_emoji:
			return {"north": 1.0, "south": 0.0}
		else:
			return {"north": 0.0, "south": 1.0}

	# If no biome provided, try to resolve from terminal's biome name
	if not biome and biome_resolver.is_valid() and terminal.bound_biome_name != "":
		biome = biome_resolver.call(terminal.bound_biome_name)

	if not biome:
		return {"north": emoji_north_opacity, "south": emoji_south_opacity}

	# Query live viz snapshot for this register. If unavailable, keep cached
	# opacities rather than inventing a neutral 50/50 state.
	if not biome.viz_cache:
		return {"north": emoji_north_opacity, "south": emoji_south_opacity}

	var snap = biome.viz_cache.get_snapshot(terminal.bound_register_id)
	if snap.is_empty():
		return {"north": emoji_north_opacity, "south": emoji_south_opacity}

	var north_prob = float(snap.get("p0", -1.0))
	if north_prob < 0.0:
		return {"north": emoji_north_opacity, "south": emoji_south_opacity}

	var south_prob = 1.0 - north_prob
	var mass = north_prob + south_prob

	if mass > 0.001:
		return {"north": north_prob / mass, "south": south_prob / mass}
	return {"north": emoji_north_opacity, "south": emoji_south_opacity}


func is_terminal_measured() -> bool:
	# Check if this node's terminal is measured (v2 single source of truth)
	if terminal:
		return terminal.is_measured
	if plot:
		return plot.is_measured
	return false


func _get_verbose():
	# Safely access VerboseConfig autoload from RefCounted class
	var ml := Engine.get_main_loop()
	return ml.root.get_node_or_null("/root/VerboseConfig") if ml and ml.root else null
