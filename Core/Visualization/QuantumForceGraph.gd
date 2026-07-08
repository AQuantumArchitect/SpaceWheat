class_name QuantumForceGraph
extends Node2D


## Quantum Force Graph - Coordinator
##
## Physics-grounded visualization of quantum states.
## Delegates work to focused component classes:
##
## - QuantumBubbleRenderer: Individual bubble drawing
## - QuantumEdgeRenderer: Relationship lines (MI web, entanglement, etc.)
## - QuantumRegionRenderer: Background regions and heatmaps
## - QuantumInfraRenderer: Gate infrastructure
## - QuantumEffectsRenderer: Entanglement particles, deaths, coherence strikes
## - TouchInputManager: User input (tap/swipe/drag) via autoload singleton
## - QuantumNodeManager: Node lifecycle and visual updates
##
## Visual Channel → Physics Data Mapping:
## - Position (radial): Bloch/subspace radius - pure states spread outward
## - Position (angular): Phase arg(ρ_01) - same-phase qubits cluster
## - Position (distance): Mutual Info I(A:B) - entangled bubbles cluster
## - Emoji opacity: P(n)/mass, P(s)/mass - measurement probability
## - Color hue: arg(ρ_01) - coherence phase
## - Color saturation: |ρ_01| - coherence magnitude
## - Glow intensity: |ρ_01| / Berry phase - coherence and history
## - Pulse rate: |ρ_01| + berry_phase - stability


# Preload component scripts
# Use batched renderer (falls back to GDScript if native unavailable)
const BubbleRendererScript = preload("res://Core/Visualization/BatchedBubbleRenderer.gd")
const EdgeRendererScript = preload("res://Core/Visualization/QuantumEdgeRenderer.gd")
const RegionRendererScript = preload("res://Core/Visualization/QuantumRegionRenderer.gd")
const ProjectionBuilderScript = preload("res://Core/Visualization/QuantumProjectionBuilder.gd")
const ProjectionFieldRendererScript = preload("res://Core/Visualization/QuantumProjectionFieldRenderer.gd")
const InfraRendererScript = preload("res://Core/Visualization/QuantumInfraRenderer.gd")
const EffectsRendererScript = preload("res://Core/Visualization/QuantumEffectsRenderer.gd")
const NodeManagerScript = preload("res://Core/Visualization/QuantumNodeManager.gd")
const GeometryBatcherScript = preload("res://Core/Visualization/GeometryBatcher.gd")

# Logging
@onready var _verbose = get_node_or_null("/root/VerboseConfig")


# Signals
signal quantum_node_selected(node: QuantumNode)
signal biome_selected(biome_name: String)
signal node_clicked(grid_pos: Vector2i, button_index: int)
signal chain_swiped(positions: Array)  # Array[Vector2i] from drag chain


# Component instances (untyped to avoid class_name dependency)
var bubble_renderer
var edge_renderer
var region_renderer
var projection_builder
var projection_renderer
var infra_renderer
var effects_renderer
var node_manager

# Autoload references
@onready var _touch_input_manager = get_node_or_null("/root/TouchInputManager")

# Drag chain state (for chain swipe gesture)
var _drag_chain: Array = []  # QuantumNode chain during swipe

# State
var quantum_nodes: Array = []
var node_by_plot_id: Dictionary = {}
var quantum_nodes_by_grid_pos: Dictionary = {}
var all_plot_positions: Dictionary = {}
var _pgd_positions: Dictionary = {}  # Plot-box screen positions from PlotGridDisplay; survives rebuild_nodes()
var _carousel_angle: float = 0.0  # Biome-carousel rotation (rad); eases so the active biome faces front
var sun_qubit_node: QuantumNode = null

var biomes: Dictionary = {}
var active_biome: String = ""
var render_all_biomes: bool = true

var layout_calculator: BiomeLayoutCalculator
var farm_grid = null
var terminal_pool = null

var biotic_flux_biome = null
var biotic_icon = null
var chaos_icon = null
var imperium_icon = null

var biome_evolution_batcher = null
var emoji_atlas_batcher = null  # Pre-built emoji atlas for GPU-accelerated rendering
var bubble_atlas_batcher = null  # Pre-built bubble atlas for GPU-accelerated rendering
var geometry_batcher = null  # Unified batcher for edges/effects/regions/infra
var lookahead_offset: int = 0  # 0 = render current frame; set >0 to preview lookahead
var projection_payloads: Dictionary = {}

var center_position: Vector2 = Vector2.ZERO
var graph_radius: float = 250.0
var time_accumulator: float = 0.0
var frame_count: int = 0

var cached_viewport_size: Vector2 = Vector2.ZERO
var _context_cache: Dictionary = {}

# Detailed performance profiling
var _perf_samples: Dictionary = {
	"process_total": [],
	"process_viewport": [],
	"process_context": [],
	"process_visuals": [],
	"process_animations": [],
	"process_forces": [],
	"process_particles": [],
	"draw_total": [],
	"draw_context": [],
	"draw_canvas_item": [],
	"draw_geom_begin": [],
	"draw_region": [],
	"draw_projection": [],
	"draw_infra": [],
	"draw_edge": [],
	"draw_effects": [],
	"draw_bubble": [],
	"draw_flush": [],
	"draw_sun": [],
	"draw_debug": [],
}
var _perf_report_interval: int = 300  # Report every N frames (less noise)

# Projection-state properties
var lock_dimensions: bool = false  # Used by BathQuantumVisualizationController

# Particle storage
var entanglement_particles: Array = []
var life_cycle_effects: Dictionary = {"deaths": [], "strikes": []}

# Per-plot tether colors
var plot_tether_colors: Dictionary = {}

# Constants
const DEBUG_MODE = false
const PARTICLE_LIFE = 1.5
const PARTICLE_SPEED = 80.0
const PARTICLE_SIZE = 3.0
const REDRAW_STRIDE_ACTIVE = 1
const REDRAW_STRIDE_IDLE = 2


func _ready():
	_initialize_components()
	_connect_to_active_biome_router()


func _exit_tree() -> void:
	teardown()


func _connect_to_active_biome_router():
	# Connect to ActiveBiomeManager for biome filtering optimization.
	var abm = get_node_or_null("/root/ActiveBiomeManager")
	if abm:
		# Initialize with current active biome
		active_biome = abm.active_biome
		# Listen for changes
		if abm.has_signal("active_biome_changed"):
			abm.active_biome_changed.connect(_on_active_biome_changed)


func _on_active_biome_changed(new_biome: String, _old_biome: String):
	# Handle biome switching - update active_biome for force system optimization.
	set_active_biome(new_biome)
	# Newly-active biome may have just realized its registers — make sure they own bubbles.
	_ensure_register_bubbles()


func _initialize_components():
	# Create and configure all component instances.
	bubble_renderer = BubbleRendererScript.new()
	edge_renderer = EdgeRendererScript.new()
	region_renderer = RegionRendererScript.new()
	projection_builder = ProjectionBuilderScript.new()
	projection_renderer = ProjectionFieldRendererScript.new()
	infra_renderer = InfraRendererScript.new()
	effects_renderer = EffectsRendererScript.new()
	node_manager = NodeManagerScript.new()
	geometry_batcher = GeometryBatcherScript.new()

	_connect_touch_input_signals()

	# Create layout calculator
	layout_calculator = BiomeLayoutCalculator.new()


func _connect_touch_input_signals() -> void:
	# Connect touch input manager signals once.
	if not _touch_input_manager:
		return
	if not _touch_input_manager.tap_detected.is_connected(_on_touch_tap):
		_touch_input_manager.tap_detected.connect(_on_touch_tap)
	if not _touch_input_manager.drag_started.is_connected(_on_drag_start):
		_touch_input_manager.drag_started.connect(_on_drag_start)
	if not _touch_input_manager.drag_moved.is_connected(_on_drag_move):
		_touch_input_manager.drag_moved.connect(_on_drag_move)
	if not _touch_input_manager.drag_ended.is_connected(_on_drag_end):
		_touch_input_manager.drag_ended.connect(_on_drag_end)


func _process(delta: float):
	var t0 = Time.get_ticks_usec()
	time_accumulator += delta
	frame_count += 1

	# Register-first lazy seed: on a fresh boot the biome's viz_cache has no metadata at
	# setup() time, so the field would otherwise stay empty until a strike. Once viz is
	# populated, seed the live register bubbles. Cheap no-op once the field is seeded.
	if quantum_nodes.is_empty():
		_ensure_register_bubbles()

	# GATE: Skip all rendering if no bubbles exist (viz_cache still not ready)
	if quantum_nodes.is_empty():
		projection_payloads = {}
		return

	# GATE: Check for active terminal bubbles (explored, not measured)
	var has_active = _has_active_terminal_bubbles()

	# Check for viewport resize
	var viewport = get_viewport()
	if viewport:
		var new_size = viewport.get_visible_rect().size
		if new_size != cached_viewport_size:
			cached_viewport_size = new_size
			update_layout(true)
	var t1 = Time.get_ticks_usec()

	var ctx = _build_context()
	var t2 = Time.get_ticks_usec()

	# Update node visuals from quantum state
	node_manager.update_node_visuals(quantum_nodes, ctx)
	var t3 = Time.get_ticks_usec()

	# Animations are cosmetic (spawn fade-in, measured-freeze) and MUST run for any
	# bubble that exists — they drive visual_scale 0→1, which is what makes a bubble
	# appear at all. Gating them behind "active (bound, unmeasured) terminals" left
	# every freshly-measured bubble stuck at visual_scale=0 → invisible. The
	# quantum_nodes.is_empty() gate above already short-circuits the no-bubble case.
	node_manager.update_animations(quantum_nodes, time_accumulator, delta)
	var t4 = Time.get_ticks_usec()

	# Station layout (Mini-Metro pass): bubbles sit AT their plot-slot anchors with a
	# few px of breathing wobble; inactive biomes are static miniatures on the turntable.
	# Position is identity now — correlations read as edges, never as layout forces.
	_update_station_layout(delta)
	var t5 = Time.get_ticks_usec()

	# GATE: Only update particles if we have active bubbles
	if has_active:
		effects_renderer.update_particles(delta, ctx)
	var t6 = Time.get_ticks_usec()

	# Rebuild projection payloads from node state — only while the B microscope
	# needs them (they draw nothing otherwise).
	if show_inspection_layers:
		_update_projection_payloads()

	# Redraw every frame when actively rendering gameplay bubbles.
	# In idle/no-active states we can safely throttle to reduce overhead.
	var redraw_stride = REDRAW_STRIDE_ACTIVE if has_active else REDRAW_STRIDE_IDLE
	if frame_count % redraw_stride == 0:
		queue_redraw()
	var t7 = Time.get_ticks_usec()

	# Store timing samples
	_perf_samples["process_total"].append(t7 - t0)
	_perf_samples["process_viewport"].append(t1 - t0)
	_perf_samples["process_context"].append(t2 - t1)
	_perf_samples["process_visuals"].append(t3 - t2)
	_perf_samples["process_animations"].append(t4 - t3)
	_perf_samples["process_forces"].append(t5 - t4)
	_perf_samples["process_particles"].append(t6 - t5)

	# Trim sample arrays (keep last 300 samples)
	for key in _perf_samples:
		if _perf_samples[key].size() > 300:
			_perf_samples[key].pop_front()

	# Report every N frames
	if frame_count % _perf_report_interval == 0 and _verbose and _verbose.allows("perf_hud", _verbose.LogLevel.DEBUG):
		_print_perf_report()


func _draw():
	var t_start = Time.get_ticks_usec()
	var ctx = _build_context()
	var t_ctx = Time.get_ticks_usec()

	# Get canvas item (might stall waiting for GPU)
	var canvas_item = get_canvas_item()
	var t_canvas = Time.get_ticks_usec()

	# Begin geometry batch for all untextured primitives
	geometry_batcher.begin(canvas_item)
	var t_geom_begin = Time.get_ticks_usec()

	# Draw in layers (back to front) - all add to geometry batch
	# 1. Background regions
	region_renderer.draw(self, ctx)
	var t_region = Time.get_ticks_usec()

	# 2. Semantic projection fields — inspection-only (B microscope open);
	# the default view is the clean metro map.
	if show_inspection_layers:
		projection_renderer.draw(self, ctx)
	var t_projection = Time.get_ticks_usec()

	# 3. Gate infrastructure — inspection-only (Bell-pair lines in the edge
	# pass carry the ambient signal).
	if show_inspection_layers:
		infra_renderer.draw(self, ctx)
	var t_infra = Time.get_ticks_usec()

	# 4. Edge relationships
	edge_renderer.draw(self, ctx)
	var t_edge = Time.get_ticks_usec()

	# 5. Effects
	effects_renderer.draw(self, ctx)
	var t_effects = Time.get_ticks_usec()

	# 6. Quantum bubbles
	bubble_renderer.draw(self, ctx)
	var t_bubble = Time.get_ticks_usec()

	# Flush geometry batch (RenderingServer call)
	geometry_batcher.flush()
	var t_flush = Time.get_ticks_usec()

	# 7. Sun qubit
	bubble_renderer.draw_sun_qubit(self, ctx)
	var t_sun = Time.get_ticks_usec()

	# Debug overlay
	if DEBUG_MODE:
		_draw_debug_overlay()
	var t_end = Time.get_ticks_usec()

	# Store timing samples (consolidated sub-1ms steps)
	_perf_samples["draw_total"].append(t_end - t_start)
	_perf_samples["draw_context"].append(t_ctx - t_start)
	_perf_samples["draw_canvas_item"].append(t_canvas - t_ctx)  # GPU stall?
	_perf_samples["draw_geom_begin"].append(t_geom_begin - t_canvas)
	_perf_samples["draw_region"].append(t_region - t_geom_begin)
	_perf_samples["draw_projection"].append(t_projection - t_region)
	_perf_samples["draw_infra"].append(t_infra - t_projection)
	_perf_samples["draw_edge"].append(t_edge - t_infra)
	_perf_samples["draw_effects"].append(t_effects - t_edge)
	_perf_samples["draw_bubble"].append(t_bubble - t_effects)
	_perf_samples["draw_flush"].append(t_flush - t_bubble)  # RenderingServer.canvas_item_add_triangle_array()
	_perf_samples["draw_sun"].append(t_sun - t_flush)
	_perf_samples["draw_debug"].append(t_end - t_sun)


func _has_active_terminal_bubbles() -> bool:
	# Check if any terminal bubbles are actively explored (not measured).
	#
	# Used to gate animations, particles, and music.
	# A bubble is "active" if it has a farm_tether AND is not measured.
	#
	# Returns:
	# true if at least one bubble is bound and not measured
	for node in quantum_nodes:
		if node.has_farm_tether and node.terminal:
			# Must be bound AND not measured (frozen state)
			if node.terminal.is_bound and not node.terminal.is_measured:
				return true
	return false


func _build_context() -> Dictionary:
	# Build the shared context dictionary for all components.
	_context_cache["quantum_nodes"] = quantum_nodes
	_context_cache["node_by_plot_id"] = node_by_plot_id
	_context_cache["quantum_nodes_by_grid_pos"] = quantum_nodes_by_grid_pos
	_context_cache["all_plot_positions"] = all_plot_positions
	_context_cache["sun_qubit_node"] = sun_qubit_node
	_context_cache["biomes"] = biomes
	_context_cache["active_biome"] = active_biome
	_context_cache["filter_biome"] = _get_filter_biome()
	_context_cache["layout_calculator"] = layout_calculator
	_context_cache["farm_grid"] = farm_grid
	_context_cache["terminal_pool"] = terminal_pool
	_context_cache["biome_evolution_batcher"] = biome_evolution_batcher
	_context_cache["emoji_atlas_batcher"] = emoji_atlas_batcher
	_context_cache["bubble_atlas_batcher"] = bubble_atlas_batcher
	_context_cache["geometry_batcher"] = geometry_batcher
	_context_cache["projection_payloads"] = projection_payloads
	_context_cache["lookahead_offset"] = lookahead_offset
	_context_cache["biotic_flux_biome"] = biotic_flux_biome
	_context_cache["biotic_icon"] = biotic_icon
	_context_cache["chaos_icon"] = chaos_icon
	_context_cache["imperium_icon"] = imperium_icon
	_context_cache["center_position"] = center_position
	_context_cache["graph_radius"] = graph_radius
	_context_cache["time_accumulator"] = time_accumulator
	_context_cache["frame_count"] = frame_count
	_context_cache["entanglement_particles"] = entanglement_particles
	_context_cache["life_cycle_effects"] = life_cycle_effects
	_context_cache["plot_tether_colors"] = plot_tether_colors
	_context_cache["particle_life"] = PARTICLE_LIFE
	_context_cache["particle_speed"] = PARTICLE_SPEED
	_context_cache["particle_size"] = PARTICLE_SIZE
	_context_cache["show_inspection_layers"] = show_inspection_layers
	return _context_cache


## Inspection layers (Lindblad arrows, entanglement clusters, gate webs, …)
## draw only while the B microscope is open — the default view stays a clean
## metro map. Wired to OverlayManager.overlay_changed in RuntimeMount.
var show_inspection_layers: bool = false

func on_overlay_changed(overlay_name: String, is_open: bool) -> void:
	if overlay_name == "biome_detail":
		show_inspection_layers = is_open
		queue_redraw()


# ============================================================================
# PUBLIC API (Backward Compatibility)
# ============================================================================

func setup_standalone(bubble_defs: Array) -> void:
	# Minimal setup for testing — create bubbles without biomes or farm.
	#
	# Each dict in bubble_defs:
	# {grid_pos: Vector2i, screen_pos: Vector2, radius: float, emoji_north: String, emoji_south: String}
	for def in bubble_defs:
		var node = QuantumNode.new(null, def.screen_pos, def.grid_pos, center_position)
		node.radius = def.get("radius", 20.0)
		node.emoji_north = def.get("emoji_north", "🌾")
		node.emoji_south = def.get("emoji_south", "🌿")
		node.emoji_north_opacity = 1.0
		node.emoji_south_opacity = 0.3
		node.visual_scale = 1.0
		node.visual_alpha = 1.0
		node.visible = true
		node.biome_name = "TestBiome"
		quantum_nodes.append(node)
		quantum_nodes_by_grid_pos[def.grid_pos] = node


func setup(p_biomes: Dictionary, p_farm_grid = null, p_terminal_pool = null, _p_skip_bubbles: bool = false):
	# Initialize the quantum force graph.
	#
	# Args:
	# p_biomes: Dictionary of biome_name → BiomeBase
	# p_farm_grid: Optional FarmGrid reference
	# p_terminal_pool: Optional TerminalPool reference
	# _p_skip_bubbles: Deprecated; ignored
	biomes = p_biomes
	farm_grid = p_farm_grid
	terminal_pool = p_terminal_pool

	# Connect to TerminalPool signals for dynamic updates (optional game mechanic overlay)
	if terminal_pool:
		if not terminal_pool.terminal_bound.is_connected(_on_pool_terminal_bound):
			terminal_pool.terminal_bound.connect(_on_pool_terminal_bound)
		if not terminal_pool.terminal_unbound.is_connected(_on_pool_terminal_unbound):
			terminal_pool.terminal_unbound.connect(_on_pool_terminal_unbound)

	# Find special biomes
	for biome_name in biomes:
		var biome = biomes[biome_name]
		if biome_name == "BioticFlux":
			biotic_flux_biome = biome
		if "biotic_icon" in biome:
			biotic_icon = biome.biotic_icon
		if "chaos_icon" in biome:
			chaos_icon = biome.chaos_icon
		if "imperium_icon" in biome:
			imperium_icon = biome.imperium_icon

	# Update layout
	update_layout(true)

	# Create nodes from quantum registers (first-class architecture)
	rebuild_nodes()
	_update_projection_payloads()


func rebuild_nodes():
	# Register-first rebuild: one persistent live bubble per ASSIGNED plot slot. The
	# bubble belongs to the register, not to a terminal — it renders live from viz_cache
	# and is always present. MEASURE flips the bubble in place (frozen + cyan ring);
	# HARVEST clears it back to live. This is the fix for "R spawns a new measured
	# bubble / transmutes the others / Q clears everything": there is now exactly ONE
	# bubble per register and the verbs are overlays on it.
	quantum_nodes.clear()
	node_by_plot_id.clear()
	quantum_nodes_by_grid_pos.clear()
	all_plot_positions.clear()

	_ensure_register_bubbles()

	# Restore the measured-overlay for any terminals already measured (save / scenario
	# restore): re-attach them to the matching register bubble so the frozen readout
	# survives a reload.
	if terminal_pool and terminal_pool.has_method("get_all_terminals"):
		for terminal in terminal_pool.get_all_terminals():
			if terminal and terminal.is_measured and terminal.grid_position != GridSentinel.INVALID_POSITION:
				var b = quantum_nodes_by_grid_pos.get(terminal.grid_position)
				if b:
					b.terminal = terminal
					b.is_terminal_bubble = true
	_update_projection_payloads()


func _ensure_register_bubbles() -> void:
	# Idempotent seeder: make sure every assigned plot slot whose biome has a populated
	# viz_cache owns a live register bubble. Safe to call repeatedly — it only ADDS
	# bubbles for slots that don't have one yet, so it never disturbs a measured overlay.
	# Called lazily from _process (viz_cache isn't ready at setup() on a fresh boot) and
	# on biome load / active-biome change so newly-realized registers get their bubble.
	var grid = farm_grid if farm_grid else (farm_ref.grid if farm_ref else null)
	if not grid or not grid.has_method("get_plot_biome_assignments"):
		return
	var assignments: Dictionary = grid.get_plot_biome_assignments()
	var added := 0
	for grid_pos in assignments.keys():
		if quantum_nodes_by_grid_pos.has(grid_pos):
			continue
		var biome_name := str(assignments[grid_pos])
		if biome_name == "" or not biomes.has(biome_name):
			continue
		var biome = biomes.get(biome_name)
		var register_id := int(grid_pos.x)
		var node = node_manager.build_register_node(biome_name, biome, register_id, grid_pos, biomes, layout_calculator)
		if not node:
			continue
		# Exploration: bubbles start hidden until the player's focus first lands on
		# the plot (cursor selection or any action). COSMETIC only — the node still
		# exists, evolves, and can be acted on; only rendering is gated.
		node.visible = _is_plot_revealed(grid_pos)
		quantum_nodes.append(node)
		quantum_nodes_by_grid_pos[grid_pos] = node
		if node.plot_id:
			node_by_plot_id[node.plot_id] = node
		all_plot_positions[grid_pos] = node.classical_anchor
		added += 1
	# Self-heal (monotonic within a session): a mid-session state apply or an acted-on
	# bubble (bound terminal) must never stay hidden — fail open, per the anti-gating law.
	for pos in quantum_nodes_by_grid_pos:
		var n = quantum_nodes_by_grid_pos[pos]
		if n and not n.visible and (n.terminal != null or _is_plot_revealed(pos)):
			n.visible = true
			added += 1
	if added > 0:
		queue_redraw()
		if _verbose:
			_verbose.debug("viz", "🫧", "Seeded %d register bubbles (register-first)" % added)


func create_all_register_bubbles():
	# Create bubbles for ALL quantum registers in all biomes.
	#
	# Used by visual tests to populate the force graph without terminal bindings.
	# Replaces the single test bubble with one bubble per qubit per biome.
	# Clear existing nodes
	quantum_nodes.clear()
	node_by_plot_id.clear()
	quantum_nodes_by_grid_pos.clear()
	all_plot_positions.clear()

	# Create bubbles for all registers
	var new_nodes = node_manager.create_all_register_bubbles(biomes, layout_calculator)

	for node in new_nodes:
		quantum_nodes.append(node)
		if node.plot_id:
			node_by_plot_id[node.plot_id] = node
	_update_projection_payloads()

	queue_redraw()


# ============================================================================
# FARM SIGNAL CONNECTION (Replaces BathQuantumVisualizationController)
# ============================================================================

# Farm reference for signal connections
var farm_ref = null

# Plot selection tracking (synced with PlotGridDisplay)
var plot_grid_display_ref = null
var selected_plot_positions: Dictionary = {}  # Vector2i -> true

func connect_to_farm(farm: Node) -> void:
	# Connect directly to farm signals (replaces BathQuantumVisualizationController)
	if _verbose:
		_verbose.debug("viz", "🔗", "QuantumForceGraph connecting to farm signals")
	farm_ref = farm

	# Connect to terminal lifecycle signals (guard against double-connect)
	if farm.has_signal("terminal_bound") and not farm.terminal_bound.is_connected(_on_terminal_bound):
		farm.terminal_bound.connect(_on_terminal_bound)
		if _verbose:
			_verbose.debug("viz", "✓", "Connected to farm.terminal_bound signal")
	if farm.has_signal("terminal_measured") and not farm.terminal_measured.is_connected(_on_terminal_measured):
		farm.terminal_measured.connect(_on_terminal_measured)
	if farm.has_signal("terminal_released") and not farm.terminal_released.is_connected(_on_terminal_released):
		farm.terminal_released.connect(_on_terminal_released)
	if farm.has_signal("biome_removed") and not farm.biome_removed.is_connected(_on_biome_removed):
		farm.biome_removed.connect(_on_biome_removed)
	if farm.has_signal("biome_loaded") and not farm.biome_loaded.is_connected(_on_biome_loaded):
		farm.biome_loaded.connect(_on_biome_loaded)
	if farm.has_signal("plot_revealed") and not farm.plot_revealed.is_connected(_on_plot_revealed):
		farm.plot_revealed.connect(_on_plot_revealed)

	# Store references for node creation
	if "terminal_pool" in farm and farm.terminal_pool:
		terminal_pool = farm.terminal_pool
	if "biome_evolution_batcher" in farm and farm.biome_evolution_batcher:
		biome_evolution_batcher = farm.biome_evolution_batcher


## Cosmetic reveal state. Fail OPEN (visible) when no farm is connected — a bare
## visual-test graph without a farm must never render an empty field by accident.
func _is_plot_revealed(grid_pos: Vector2i) -> bool:
	if farm_ref and farm_ref.has_method("is_plot_revealed"):
		return farm_ref.is_plot_revealed(grid_pos)
	return true


func _on_plot_revealed(grid_pos: Vector2i) -> void:
	# The player's focus first landed on this plot — wake its bubble with the
	# spawn bloom. If the bubble doesn't exist yet, the next _ensure_register_bubbles
	# pass reads the persisted set and creates it visible.
	var node = quantum_nodes_by_grid_pos.get(grid_pos)
	if node and not node.visible:
		node.visible = true
		node.start_spawn_animation(time_accumulator)
		queue_redraw()


func _on_terminal_bound(grid_pos: Vector2i, terminal_id: String, _emoji_pair: Dictionary) -> void:
	# Register-first: EXPLORE (binding) does NOT spawn a bubble — the live register
	# bubble already exists at this slot. We only ensure it's there (covers a biome
	# realized by interaction before the lazy seed caught it). MEASURE does the flip.
	if _verbose:
		_verbose.debug("viz", "📍", "Terminal bound at %s (register-first: ensure bubble)" % grid_pos)
	# Anti-gating safety net: acting on a plot reveals it even if selection was
	# bypassed (rig-driven actions, boot-time verb on the default plot index).
	if farm_ref and farm_ref.has_method("reveal_plot"):
		farm_ref.reveal_plot(grid_pos)
	_ensure_register_bubbles()
	queue_redraw()


func _on_terminal_measured(grid_pos: Vector2i, terminal_id: String, outcome: String, probability: float) -> void:
	# Flip the EXISTING register bubble at this slot into its measured overlay: attach
	# the terminal and route it through the terminal-visual updater, which paints the
	# frozen collapsed readout + cyan ring (apply_measured_visual). No new bubble.
	if _verbose:
		_verbose.debug("viz", "📏", "Terminal %s measured at %s → %s (p=%.2f)" % [terminal_id, grid_pos, outcome, probability])

	# Anti-gating safety net: a measured plot must always show its bubble.
	if farm_ref and farm_ref.has_method("reveal_plot"):
		farm_ref.reveal_plot(grid_pos)
	var bubble = quantum_nodes_by_grid_pos.get(grid_pos)
	if not bubble:
		_ensure_register_bubbles()
		bubble = quantum_nodes_by_grid_pos.get(grid_pos)
	if not bubble:
		return
	if not bubble.terminal and farm_ref and farm_ref.grid:
		var measured_plot = farm_ref.grid.get_plot(grid_pos)
		if measured_plot:
			bubble.terminal = measured_plot.terminal
	# Route through _update_terminal_visuals_from_buffer so the measured readout is drawn.
	bubble.is_terminal_bubble = true
	queue_redraw()


func _on_terminal_released(grid_pos: Vector2i, terminal_id: String, credits_earned: int) -> void:
	# HARVEST: clear the measured overlay but KEEP the register bubble. It returns to
	# live (the register re-spreads under H over the next ticks). Erasing it here was
	# the terminal-first behavior that left the field empty after every harvest.
	if _verbose:
		_verbose.debug("viz", "💰", "Terminal %s harvested at %s (+%d) — bubble back to live" % [terminal_id, grid_pos, credits_earned])

	var bubble = quantum_nodes_by_grid_pos.get(grid_pos)
	if not bubble:
		return
	bubble.terminal = null
	bubble.is_terminal_bubble = false
	bubble.is_lifeless = false
	queue_redraw()


func _on_biome_loaded(biome_name: String, biome_ref) -> void:
	# Handle dynamically loaded biome - register for visualization
	biomes[biome_name] = biome_ref
	update_layout(true)
	_ensure_register_bubbles()
	queue_redraw()
	if _verbose:
		_verbose.debug("viz", "🧭", "Dynamic biome registered for viz: %s" % biome_name)


func _on_biome_removed(biome_name: String) -> void:
	# CASCADE CLEANUP: Remove ALL nodes for removed biome (no exceptions)
	var removed_count = 0
	var i = quantum_nodes.size() - 1

	while i >= 0:
		var node = quantum_nodes[i]
		if node.biome_name == biome_name:
			# Remove from all registries
			if node.plot_id:
				node_by_plot_id.erase(node.plot_id)
			if node.grid_position != GridSentinel.INVALID_POSITION:
				quantum_nodes_by_grid_pos.erase(node.grid_position)
				all_plot_positions.erase(node.grid_position)

			# Remove from main array
			quantum_nodes.remove_at(i)
			removed_count += 1
		i -= 1

	# Remove from biomes dict (now guaranteed clean)
	if biomes.has(biome_name):
		biomes.erase(biome_name)

	# Compact buffer memory
	if bubble_renderer and bubble_renderer.has_method("compact_buffer"):
		bubble_renderer.compact_buffer()

	if _verbose and removed_count > 0:
		_verbose.info("viz", "🧹", "Cascaded cleanup: removed %d nodes for biome '%s'" % [removed_count, biome_name])

	queue_redraw()


func _on_plot_selection_changed(grid_pos: Vector2i, is_selected: bool) -> void:
	# Register-first: every assigned register owns a persistent, always-visible bubble.
	# Selection now only TRACKS the cursor (for highlight/targeting) — it no longer gates
	# visibility (the old model hid every unselected pure-quantum bubble, which is the
	# opposite of "bubbles all the time").
	if is_selected:
		selected_plot_positions[grid_pos] = true
	else:
		selected_plot_positions.erase(grid_pos)
	queue_redraw()


func register_biome(biome_name: String, biome):
	# Register a new biome dynamically and rebuild nodes.
	#
	# Use this when creating biomes after initial setup (e.g., in tests).
	#
	# Args:
	# biome_name: Name of the biome
	# biome: BiomeBase instance
	if not biomes:
		biomes = {}
	biomes[biome_name] = biome
	rebuild_nodes()  # Also rebuilds lookup dictionaries

	# Create sun qubit
	sun_qubit_node = node_manager.create_sun_qubit_node(biotic_flux_biome, layout_calculator)

	# Apply biome filter
	node_manager.filter_nodes_for_biome(quantum_nodes, _get_filter_biome())
	_update_projection_payloads()


func add_nodes_for_biome(biome_name: String, biome) -> void:
	# Add nodes for a single biome without rebuilding existing nodes.
	#
	# Use this for incremental updates when toggling biomes on.
	if not biomes:
		biomes = {}
	biomes[biome_name] = biome

	# Create nodes for just this biome
	var ctx = _build_context()
	var single_biome_ctx = {
		"biomes": {biome_name: biome},
		"farm_grid": ctx.get("farm_grid"),
		"terminal_pool": ctx.get("terminal_pool"),
		"layout_calculator": layout_calculator
	}

	var new_nodes = node_manager.create_quantum_nodes(single_biome_ctx)

	# Add to existing nodes
	for node in new_nodes:
		quantum_nodes.append(node)

		# Update lookup dictionaries
		if node.plot_id:
			node_by_plot_id[node.plot_id] = node
		if node.grid_position != GridSentinel.INVALID_POSITION:
			quantum_nodes_by_grid_pos[node.grid_position] = node
			all_plot_positions[node.grid_position] = node.classical_anchor
	_update_projection_payloads()

	print("  [ForceGraph] Added %d nodes for %s" % [new_nodes.size(), biome_name])


func remove_nodes_for_biome(biome_name: String) -> void:
	# Remove nodes for a single biome without rebuilding everything.
	#
	# Use this for incremental updates when toggling biomes off.
	# Remove nodes matching this biome
	var removed_count = 0
	var i = quantum_nodes.size() - 1
	while i >= 0:
		var node = quantum_nodes[i]
		if node.biome_name == biome_name:
			# Remove from lookup dictionaries
			if node.plot_id and node_by_plot_id.has(node.plot_id):
				node_by_plot_id.erase(node.plot_id)
			if node.grid_position != GridSentinel.INVALID_POSITION:
				if quantum_nodes_by_grid_pos.has(node.grid_position):
					quantum_nodes_by_grid_pos.erase(node.grid_position)
				if all_plot_positions.has(node.grid_position):
					all_plot_positions.erase(node.grid_position)

			# Remove from array (RefCounted nodes auto-free when no references remain)
			quantum_nodes.remove_at(i)
			removed_count += 1
		i -= 1

	# Remove from biomes dict
	if biomes and biomes.has(biome_name):
		biomes.erase(biome_name)

	print("  [ForceGraph] Removed %d nodes for %s" % [removed_count, biome_name])


func update_layout(force_rebuild: bool = false):
	# Recompute layout from viewport size.
	var viewport = get_viewport()
	if not viewport:
		return

	var viewport_size = viewport.get_visible_rect().size

	# Compute layout
	layout_calculator.compute_layout(biomes, viewport_size, active_biome)

	center_position = layout_calculator.graph_center
	graph_radius = layout_calculator.graph_radius

	# Update node positions
	if force_rebuild:
		layout_calculator.update_node_positions(quantum_nodes)


func _update_projection_payloads() -> void:
	# Build semantic projection payloads once per frame from cached node/state.
	projection_payloads = {}
	if not projection_builder or biomes.is_empty() or quantum_nodes.is_empty():
		return

	var nodes_by_biome: Dictionary = {}
	for node in quantum_nodes:
		if not node or not node.visible:
			continue
		var biome_name: String = node.biome_name if node.biome_name != "" else ""
		if biome_name.is_empty():
			continue
		if active_biome != "" and biome_name != active_biome:
			continue
		if not nodes_by_biome.has(biome_name):
			nodes_by_biome[biome_name] = []
		nodes_by_biome[biome_name].append(node)

	for biome_name in nodes_by_biome:
		var biome = biomes.get(biome_name, null)
		if not biome or not biome.viz_cache:
			continue
		var biome_nodes: Array = nodes_by_biome[biome_name]
		if biome_nodes.is_empty():
			continue
		var anchor_emoji := ""
		var first_node = biome_nodes[0]
		if first_node and first_node.emoji_north != "":
			anchor_emoji = first_node.emoji_north
		elif first_node and first_node.emoji_south != "":
			anchor_emoji = first_node.emoji_south
		projection_payloads[biome_name] = projection_builder.build_self_energy_projection_from_cache(
			biome_nodes,
			biome.viz_cache,
			anchor_emoji,
			time_accumulator
		)


func set_active_biome(biome_name: String):
	# Set the active biome for single-biome view.
	#
	# Args:
	# biome_name: Name of biome to show, or "" for all biomes
	active_biome = biome_name
	node_manager.filter_nodes_for_biome(quantum_nodes, _get_filter_biome())
	update_layout(true)
	biome_selected.emit(biome_name)


func _get_filter_biome() -> String:
	return "" if render_all_biomes else active_biome


func get_node_at_position(pos: Vector2) -> QuantumNode:
	# Get quantum node at screen grid_pos.
	return get_bubble_at_screen_pos(pos)


func get_bubble_at_screen_pos(screen_pos: Vector2) -> QuantumNode:
	# Hit-test bubbles at screen grid_pos with touch-friendly expanded radius.
	for node in quantum_nodes:
		if not node.visible:
			continue
		var hit_radius = node.radius * 1.5  # Covers body + inner glow
		if node.position.distance_to(screen_pos) <= hit_radius:
			return node
	return null


func get_stats() -> Dictionary:
	# Get graph statistics.
	var active_nodes = 0
	var total_entanglements = 0
	for node in quantum_nodes:
		if node.plot and node.plot.is_active():
			active_nodes += 1
			total_entanglements += node.plot.entangled_plots.size()
	return {
		"total_nodes": quantum_nodes.size(),
		"active_nodes": active_nodes,
		"total_entanglements": total_entanglements / 2
	}


func get_perf_averages() -> Dictionary:
	# Get averaged performance data for external profiling displays.
	var avg = {}
	for key in _perf_samples:
		var samples = _perf_samples[key]
		if samples.size() > 0:
			var total = 0.0
			for s in samples:
				total += s
			avg[key] = total / samples.size() / 1000.0  # Convert to ms
		else:
			avg[key] = 0.0
	return avg


func get_bubble_renderer():
	# Get the bubble renderer for stats access.
	return bubble_renderer


func set_emoji_atlas_batcher(atlas_batcher):
	# Set the pre-built emoji atlas batcher for GPU-accelerated emoji rendering.
	emoji_atlas_batcher = atlas_batcher
	if bubble_renderer and bubble_renderer.has_method("set_emoji_atlas_batcher"):
		bubble_renderer.set_emoji_atlas_batcher(atlas_batcher)


func set_bubble_atlas_batcher(atlas_batcher):
	# Set the pre-built bubble atlas batcher for GPU-accelerated bubble rendering.
	bubble_atlas_batcher = atlas_batcher
	if bubble_renderer and bubble_renderer.has_method("set_bubble_atlas_batcher"):
		bubble_renderer.set_bubble_atlas_batcher(atlas_batcher)


func teardown() -> void:
	# Release visualization resources and disconnect runtime signal owners.
	if _touch_input_manager:
		if _touch_input_manager.tap_detected.is_connected(_on_touch_tap):
			_touch_input_manager.tap_detected.disconnect(_on_touch_tap)
		if _touch_input_manager.drag_started.is_connected(_on_drag_start):
			_touch_input_manager.drag_started.disconnect(_on_drag_start)
		if _touch_input_manager.drag_moved.is_connected(_on_drag_move):
			_touch_input_manager.drag_moved.disconnect(_on_drag_move)
		if _touch_input_manager.drag_ended.is_connected(_on_drag_end):
			_touch_input_manager.drag_ended.disconnect(_on_drag_end)

	if is_inside_tree():
		var abm = get_node_or_null("/root/ActiveBiomeManager")
		if abm and abm.has_signal("active_biome_changed") and abm.active_biome_changed.is_connected(_on_active_biome_changed):
			abm.active_biome_changed.disconnect(_on_active_biome_changed)

	if farm_ref:
		if farm_ref.has_signal("terminal_bound") and farm_ref.terminal_bound.is_connected(_on_terminal_bound):
			farm_ref.terminal_bound.disconnect(_on_terminal_bound)
		if farm_ref.has_signal("terminal_measured") and farm_ref.terminal_measured.is_connected(_on_terminal_measured):
			farm_ref.terminal_measured.disconnect(_on_terminal_measured)
		if farm_ref.has_signal("terminal_released") and farm_ref.terminal_released.is_connected(_on_terminal_released):
			farm_ref.terminal_released.disconnect(_on_terminal_released)
		if farm_ref.has_signal("biome_removed") and farm_ref.biome_removed.is_connected(_on_biome_removed):
			farm_ref.biome_removed.disconnect(_on_biome_removed)
		if farm_ref.has_signal("biome_loaded") and farm_ref.biome_loaded.is_connected(_on_biome_loaded):
			farm_ref.biome_loaded.disconnect(_on_biome_loaded)

	if terminal_pool:
		if terminal_pool.terminal_bound.is_connected(_on_pool_terminal_bound):
			terminal_pool.terminal_bound.disconnect(_on_pool_terminal_bound)
		if terminal_pool.terminal_unbound.is_connected(_on_pool_terminal_unbound):
			terminal_pool.terminal_unbound.disconnect(_on_pool_terminal_unbound)

	if bubble_renderer and bubble_renderer.has_method("release_resources"):
		bubble_renderer.release_resources()

	quantum_nodes.clear()
	node_by_plot_id.clear()
	quantum_nodes_by_grid_pos.clear()
	all_plot_positions.clear()
	_pgd_positions.clear()
	projection_payloads = {}
	entanglement_particles.clear()
	life_cycle_effects = {"deaths": [], "strikes": []}
	plot_tether_colors.clear()
	_context_cache.clear()
	sun_qubit_node = null
	biomes.clear()
	farm_ref = null
	farm_grid = null
	terminal_pool = null
	biome_evolution_batcher = null
	emoji_atlas_batcher = null
	bubble_atlas_batcher = null
	geometry_batcher = null
	bubble_renderer = null
	edge_renderer = null
	projection_builder = null
	projection_renderer = null
	region_renderer = null
	infra_renderer = null
	effects_renderer = null
	node_manager = null


func print_snapshot(reason: String = ""):
	# Print debug snapshot of graph state.
	if not DEBUG_MODE:
		return
	var stats = get_stats()
	print("\n  ===== QUANTUM GRAPH SNAPSHOT =====")
	if reason != "":
		print("Reason: %s" % reason)
	print("Total nodes: %d" % stats.total_nodes)
	print("Active (planted): %d" % stats.active_nodes)
	print("Entanglements: %d" % stats.total_entanglements)
	print("===================================\n")


func add_life_cycle_effect(effect_type: String, effect_data: Dictionary):
	# Add a life cycle effect (death or strike).
	#
	# Args:
	# effect_type: "deaths" or "strikes"
	# effect_data: Effect data with grid_pos, color, etc.
	if effect_type == "spawns":
		return
	if not life_cycle_effects.has(effect_type):
		life_cycle_effects[effect_type] = []
	effect_data["time"] = 0.0
	life_cycle_effects[effect_type].append(effect_data)


func set_plot_tether_color(grid_pos: Vector2i, color: Color):
	# Set a custom tether color for a plot.
	plot_tether_colors[grid_pos] = color


## Screen-space position of a register's station bubble (O(1) lookup).
## Returns (-1, -1) when the register has no bubble. Used by the floating
## reward layer to launch "+N emoji" fliers from the popped station.
func get_register_screen_position(biome_name: String, register_id: int) -> Vector2:
	var node = node_by_plot_id.get("%s_r%d" % [biome_name, register_id])
	if node == null:
		return Vector2(-1, -1)
	return get_global_transform() * node.position


func update_plot_positions(plot_positions: Dictionary, biome_name: String = "") -> void:
	# Update plot anchors from PlotGridDisplay (screen-space coordinates).
	#
	# Args:
	# plot_positions: Dictionary of Vector2i -> Vector2 (screen grid_pos)
	# biome_name: Optional biome name for logging/context
	if plot_positions.is_empty():
		return

	# Update global cache
	for grid_pos in plot_positions.keys():
		all_plot_positions[grid_pos] = plot_positions[grid_pos]
		_pgd_positions[grid_pos] = plot_positions[grid_pos]

	# Update node anchors
	for node in quantum_nodes:
		if node.grid_position == GridSentinel.INVALID_POSITION:
			continue
		if not plot_positions.has(node.grid_position):
			continue
		var anchor_pos = plot_positions[node.grid_position]
		node.classical_anchor = anchor_pos
		# Keep measured nodes frozen at the new anchor grid_pos
		if node.is_terminal_measured():
			node.position = anchor_pos

	if _verbose:
		_verbose.debug("viz", "📌", "Plot anchors updated (%d) for biome '%s'" % [
			plot_positions.size(), biome_name
		])


# ============================================================================
# INPUT HANDLING
# ============================================================================

func _on_pool_terminal_bound(_terminal: RefCounted, _register_id: int):
	# Handle terminal binding from TerminalPool.
	# No-op: Farm.terminal_bound signal handles bubble creation directly.
	pass


func _on_pool_terminal_unbound(_terminal: RefCounted):
	# Handle terminal unbinding from TerminalPool.
	# No-op: Farm.terminal_released signal handles bubble removal directly.
	pass


func _on_touch_tap(grid_pos: Vector2) -> void:
	# Handle tap from TouchInputManager — hit-test bubbles.
	var node = get_bubble_at_screen_pos(grid_pos)
	if not node or node.grid_position == GridSentinel.INVALID_POSITION:
		return

	if _verbose:
		var measured = node.is_terminal_measured() if node.has_method("is_terminal_measured") else false
		_verbose.debug("viz", "👆", "Bubble tap at %s (measured=%s)" % [node.grid_position, measured])

	quantum_node_selected.emit(node)
	node_clicked.emit(node.grid_position, MOUSE_BUTTON_LEFT)
	if _touch_input_manager:
		_touch_input_manager.consume_current_tap()


func _on_drag_start(grid_pos: Vector2) -> void:
	# Handle drag start from TouchInputManager — begin chain tracking.
	_drag_chain.clear()
	var node = get_bubble_at_screen_pos(grid_pos)
	if node:
		_drag_chain.append(node)


func _on_drag_move(grid_pos: Vector2) -> void:
	# Handle drag move from TouchInputManager — extend chain.
	if _drag_chain.is_empty():
		return
	var node = get_bubble_at_screen_pos(grid_pos)
	if node and node != _drag_chain.back():
		_drag_chain.append(node)


func _on_drag_end(_start_pos: Vector2, _end_pos: Vector2) -> void:
	# Handle drag end from TouchInputManager — emit chain if 2+ bubbles.
	if _drag_chain.size() < 2:
		_drag_chain.clear()
		return

	var positions: Array[Vector2i] = []
	for n in _drag_chain:
		positions.append(n.grid_position)
	chain_swiped.emit(positions)
	_drag_chain.clear()


# (C++ batched force positions retired 2026-06-30; the GDScript force soup itself was
# retired 2026-07-07 — _update_station_layout owns the farm graph layout: anchored
# stations + turntable, no forces.)


# ============================================================================
# PERFORMANCE PROFILING
# ============================================================================

func _print_perf_report():
	# Print detailed performance breakdown with averages.
	var fps = Engine.get_frames_per_second()

	# Calculate averages
	var avg = {}
	for key in _perf_samples:
		var samples = _perf_samples[key]
		if samples.size() > 0:
			var total = 0.0
			for s in samples:
				total += s
			avg[key] = total / samples.size() / 1000.0  # Convert to ms
		else:
			avg[key] = 0.0

	# Calculate max values (P95 approximation)
	var p95 = {}
	for key in _perf_samples:
		var samples = _perf_samples[key].duplicate()
		if samples.size() > 5:
			samples.sort()
			var idx = int(samples.size() * 0.95)
			p95[key] = samples[idx] / 1000.0
		elif samples.size() > 0:
			p95[key] = samples[-1] / 1000.0
		else:
			p95[key] = 0.0

	# One perf_hud-routed message (the call site already gates on
	# allows("perf_hud", DEBUG) — this just stops bypassing the logger).
	var out: Array[String] = []
	out.append("═".repeat(78))
	out.append("🔬 GDSCRIPT PERFORMANCE BREAKDOWN - Frame %d (%.0f FPS)" % [frame_count, fps])
	out.append("═".repeat(78))

	# Frame budget
	var frame_ms = 1000.0 / fps if fps > 0 else 100.0
	var total_tracked = avg["process_total"] + avg["draw_total"]
	var untracked = frame_ms - total_tracked

	out.append("🎯 FRAME BUDGET: %.1fms/frame (target: 16.67ms)" % frame_ms)
	out.append("   ├─ Tracked GDScript: %.2fms" % total_tracked)
	out.append("   └─ Untracked (GPU wait, other): %.2fms" % maxf(0, untracked))

	# _process breakdown
	out.append("📊 _process() breakdown (avg | P95):")
	out.append("   ├─ Viewport check:   %5.2fms | %5.2fms" % [avg["process_viewport"], p95["process_viewport"]])
	out.append("   ├─ Build context:    %5.2fms | %5.2fms  ← Dictionary creation" % [avg["process_context"], p95["process_context"]])
	out.append("   ├─ Update visuals:   %5.2fms | %5.2fms  ← node_manager loop" % [avg["process_visuals"], p95["process_visuals"]])
	out.append("   ├─ Animations:       %5.2fms | %5.2fms" % [avg["process_animations"], p95["process_animations"]])
	out.append("   ├─ Force positions:  %5.2fms | %5.2fms" % [avg["process_forces"], p95["process_forces"]])
	out.append("   └─ Particles:        %5.2fms | %5.2fms" % [avg["process_particles"], p95["process_particles"]])
	out.append("   TOTAL:               %5.2fms | %5.2fms" % [avg["process_total"], p95["process_total"]])

	# _draw breakdown (consolidated sub-1ms, detailed GPU tracking)
	out.append("🎨 _draw() breakdown (avg | P95):")
	out.append("   ├─ Context + Canvas:  %5.2fms | %5.2fms  ← Dict + get_canvas_item()" % [avg["draw_context"] + avg["draw_canvas_item"], p95["draw_context"] + p95["draw_canvas_item"]])
	out.append("   ├─ Geom Setup:        %5.2fms | %5.2fms  ← batcher.begin()" % [avg["draw_geom_begin"], p95["draw_geom_begin"]])
	out.append("   ├─ Region render:     %5.2fms | %5.2fms" % [avg["draw_region"], p95["draw_region"]])
	out.append("   ├─ Projection field:  %5.2fms | %5.2fms" % [avg["draw_projection"], p95["draw_projection"]])
	out.append("   ├─ Infra + edges:     %5.2fms | %5.2fms" % [avg["draw_infra"] + avg["draw_edge"], p95["draw_infra"] + p95["draw_edge"]])
	out.append("   ├─ Effects:           %5.2fms | %5.2fms" % [avg["draw_effects"], p95["draw_effects"]])
	out.append("   ├─ Bubble renderer:   %5.2fms | %5.2fms  ← BubbleAtlasBatcher" % [avg["draw_bubble"], p95["draw_bubble"]])
	out.append("   ├─ Geometry flush:    %5.2fms | %5.2fms  ← RenderingServer call" % [avg["draw_flush"], p95["draw_flush"]])
	out.append("   ├─ Sun qubit:         %5.2fms | %5.2fms  ← draw_sun_qubit()" % [avg["draw_sun"], p95["draw_sun"]])
	out.append("   └─ Debug + other:     %5.2fms | %5.2fms" % [avg.get("draw_debug", 0), p95.get("draw_debug", 0)])
	out.append("   TOTAL:                %5.2fms | %5.2fms" % [avg["draw_total"], p95["draw_total"]])

	# Identify bottleneck
	var bottlenecks: Array = []
	if avg["process_visuals"] > 2.0:
		bottlenecks.append("🚨 update_visuals: %.1fms - node loop too slow" % avg["process_visuals"])
	if avg["process_context"] + avg["draw_context"] > 1.0:
		bottlenecks.append("🚨 context build: %.1fms - called twice per frame!" % (avg["process_context"] + avg["draw_context"]))
	if avg["draw_edge"] > 3.0:
		bottlenecks.append("🚨 edge_renderer: %.1fms - too many edges?" % avg["draw_edge"])
	if avg["draw_bubble"] > 5.0:
		bottlenecks.append("🚨 bubble_renderer: %.1fms - emoji/atlas overhead" % avg["draw_bubble"])
	if untracked > 10.0:
		bottlenecks.append("🚨 untracked: %.1fms - GPU stall or vsync?" % untracked)

	if bottlenecks.size() > 0:
		out.append("⚠️  BOTTLENECKS DETECTED:")
		for b in bottlenecks:
			out.append("   %s" % b)
	else:
		out.append("✅ No major bottlenecks detected")

	# Node counts
	var geom_stats = geometry_batcher.get_stats() if geometry_batcher else {}
	out.append("📈 STATS: %d nodes | %d tris | %d draw calls" % [
		quantum_nodes.size(),
		geom_stats.get("triangle_count", 0),
		geom_stats.get("draw_calls", 0)
	])
	out.append("═".repeat(78))
	if _verbose:
		_verbose.debug("perf_hud", "🔬", "\n" + "\n".join(out))


# ============================================================================
# DEBUG
# ============================================================================

func _draw_debug_overlay():
	# Draw debug information overlay.
	var font = ThemeDB.fallback_font
	var stats = get_stats()

	var debug_text = "Nodes: %d active, %d total | Entanglements: %d" % [
		stats.active_nodes, stats.total_nodes, stats.total_entanglements
	]
	draw_string(font, Vector2(10, 20), debug_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

	# Draw node positions
	for node in quantum_nodes:
		if not node.visible:
			continue
		draw_circle(node.position, 5.0, Color(0, 1, 1, 0.5))
		draw_string(font, node.position + Vector2(-15, -15),
			"[%d,%d]" % [node.grid_position.x, node.grid_position.y],
			HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0, 1, 1, 0.7))


func _get_scaled_force_delta(delta: float) -> float:
	# Scale force graph delta based on quantum evolution granularity.
	#
	# Slower quantum evolution (larger dt) → slower force graph movement.
	# Uses minimum dt across all loaded biomes (fastest biome drives the animation).
	# 4th-root scaling keeps slow biomes more visually alive than sqrt did.
	#
	# Reference: dt=0.02s → scale_val=1.0 (full speed)
	# dt=1.0s  → scale_val=0.376 (2.7× slower, was 7× with sqrt)
	# dt=100s  → scale_val=0.133 (clamped to MIN_SCALE=0.1)
	#
	# Args:
	# delta: Raw frame delta from _process()
	#
	# Returns:
	# Scaled delta for force graph physics
	const REFERENCE_DT = 0.02  # Baseline evolution dt (default for fast biomes)
	const MIN_SCALE = 0.1      # Was 0.002 — raised so slow biomes stay animated

	# Use minimum dt across all biomes so the fastest biome drives animation rate
	var min_dt = REFERENCE_DT
	var found_any = false
	for biome_name in biomes:
		var biome = biomes[biome_name]
		if biome and "max_evolution_dt" in biome:
			if not found_any or biome.max_evolution_dt < min_dt:
				min_dt = biome.max_evolution_dt
				found_any = true

	# 4th-root scaling: softer than sqrt, keeps slow biomes more animated
	# pow(x, 0.25) = sqrt(sqrt(x))
	var scale_val = pow(REFERENCE_DT / min_dt, 0.25)
	scale_val = max(scale_val, MIN_SCALE)

	return delta * scale_val


# Station layout tuning (Mini-Metro pass, 2026-07-07). The O(n²) force soup
# (repulsion + MI attraction + centre spring + drag) is deleted: position is
# IDENTITY — a bubble sits at its plot slot; correlations are edges, not layout.
const WOBBLE_LEASH: float = 3.5      # px of breathing drift around the anchor
const WOBBLE_W1: float = 0.5         # rad/s — wobble x frequency
const WOBBLE_W2: float = 0.37        # rad/s — wobble y frequency (irrational-ish ratio)
const MINIATURE_SHRINK: float = 0.5  # extra shrink for inactive-biome clusters

## Wobble clock advanced by the biome-speed-scaled delta so slow biomes still
## read slower, without any per-node physics.
var _wobble_clock: float = 0.0


func _update_station_layout(delta: float) -> void:
	# Anchored drift. ACTIVE biome bubbles sit ON their plot tiles
	# (classical_anchor — PlotGridDisplay pushes true tile positions via
	# update_plot_positions) plus a small golden-angle-desynced wobble; measured
	# bubbles are frozen readouts (zero wobble). Inactive biomes render as static
	# miniatures: their plot layout SHAPE, shrunk around their turntable slot.
	# The turntable itself (stable slot per biome, active eases to front) is kept
	# from the force era — it is the "universe of biomes" read.
	if not layout_calculator:
		return

	var nodes_by_biome: Dictionary = {}
	for node in quantum_nodes:
		if not node.biome_name or node.quantum_behavior == 2:  # FIXED nodes own their position
			continue
		if not nodes_by_biome.has(node.biome_name):
			nodes_by_biome[node.biome_name] = []
		nodes_by_biome[node.biome_name].append(node)
	if nodes_by_biome.is_empty():
		return

	_wobble_clock += _get_scaled_force_delta(delta)

	var biome_list: Array = nodes_by_biome.keys()
	biome_list.sort()  # stable ordering → stable carousel slots
	var n := biome_list.size()
	var center: Vector2 = layout_calculator.graph_center

	# Ease the turntable so the active biome's slot rotates to the front (angle 0).
	var active_idx := biome_list.find(active_biome)
	if active_idx < 0:
		active_idx = 0
	var target_angle := -TAU * float(active_idx) / float(maxi(n, 1))
	_carousel_angle = lerp_angle(_carousel_angle, target_angle, clampf(delta * 5.0, 0.0, 1.0))

	var reach: float = minf(center.x, center.y)
	var turntable_rx: float = reach * 0.60
	var turntable_ry: float = reach * 0.26
	# Bias the turntable DOWN into the play area so the back cluster clears the top
	# tab bar and the front cluster clears the bottom action bar.
	var play_center: Vector2 = Vector2(center.x, center.y + reach * 0.18)
	var ease_w: float = 1.0 - exp(-6.0 * delta)  # critically-damped settle

	for i in range(n):
		var bname: String = biome_list[i]
		var cluster_nodes: Array = nodes_by_biome[bname]
		var cluster_center: Vector2 = play_center
		var depth: float = 1.0
		if n > 1:
			var ang := TAU * float(i) / float(n) + _carousel_angle
			depth = cos(ang)  # +1 front (lower, larger), -1 back (higher, smaller)
			cluster_center = Vector2(
				play_center.x + sin(ang) * turntable_rx,
				play_center.y + depth * turntable_ry
			)
		var depth_scale: float = 0.55 + 0.45 * (depth * 0.5 + 0.5)  # 1.0 front → 0.55 back

		# Soft handoff between "miniature at turntable slot" and "on the plot tiles":
		# the active biome blends to its true anchors as its slot swings to the front
		# (continuous in depth — no snap when the carousel settles).
		var front_blend: float = 0.0
		if bname == active_biome:
			front_blend = clampf((depth - 0.7) / 0.3, 0.0, 1.0) if n > 1 else 1.0

		# Resolve each node's true anchor: the PGD plot-tile position when the
		# tile exists (_pgd_positions is pushed by PlotGridDisplay and survives
		# the boot ordering where bubbles are built AFTER the first push), else
		# the node's parametric anchor (registers beyond the plot ring).
		var anchors: Array = []
		var anchor_mean := Vector2.ZERO
		for node in cluster_nodes:
			var a: Vector2 = _pgd_positions.get(node.grid_position, node.classical_anchor)
			anchors.append(a)
			anchor_mean += a
		anchor_mean /= float(maxi(cluster_nodes.size(), 1))

		for ni in range(cluster_nodes.size()):
			var node = cluster_nodes[ni]
			var plot_anchor: Vector2 = anchors[ni]
			var miniature: Vector2 = cluster_center \
					+ (plot_anchor - anchor_mean) * (depth_scale * MINIATURE_SHRINK)
			var world_anchor: Vector2 = miniature.lerp(plot_anchor, front_blend)
			# Miniature stations shrink with the turntable (renderers read this).
			node.depth_scale = lerpf(depth_scale * 0.6, 1.0, front_blend)
			var target: Vector2 = world_anchor
			if front_blend > 0.0 and not node.is_terminal_measured():
				var s: float = float(node.register_id) * 2.399  # golden-angle desync seed
				target += Vector2(
					sin(WOBBLE_W1 * _wobble_clock + s),
					cos(WOBBLE_W2 * _wobble_clock + 1.7 * s)
				) * (WOBBLE_LEASH * front_blend)
			node.velocity = Vector2.ZERO
			node.position = node.position.lerp(target, ease_w)
