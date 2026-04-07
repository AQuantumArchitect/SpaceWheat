## FarmView - UI entry point
## Farm is owned/created by GameStateManager; FarmView only attaches UI.

extends Control

const QuantumForceGraph = preload("res://Core/Visualization/QuantumForceGraph.gd")
const BiomeBackgroundClass = preload("res://Core/Visualization/BiomeBackground.gd")
const SaveStore = preload("res://Core/GameState/SaveStore.gd")
const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")
# BootManager is an autoload singleton - no need to preload

const BACKGROUND_LAYER := -1
const SHELL_Z_INDEX := 10
const QUANTUM_VIZ_Z_INDEX := 40

var shell = null  # PlayerShell (from scene)
var farm: Node = null
var quantum_viz: QuantumForceGraph = null
var biome_background: Control = null  # BiomeBackground for full-screen biome art
var performance_hud: Control = null  # Performance profiling overlay

# Helpers to access autoloads safely (avoids compile-time errors in tests)
@onready var _verbose = InstrumentLocator.resolve_verbose_config(self)
@onready var _boot_mgr = InstrumentLocator.resolve_root_node(self, "/root/BootManager")


func _ready():
	"""Initialize: boot core systems, then attach UI"""
	_verbose.info("ui", "🌾", "FarmView starting...")

	# DEBUG: Check if FarmView is properly sized
	_verbose.debug("ui", "📏", "FarmView size: %.0f × %.0f" % [size.x, size.y])
	_verbose.debug("ui", "", "FarmView anchors: L%.1f T%.1f R%.1f B%.1f" % [anchor_left, anchor_top, anchor_right, anchor_bottom])
	_verbose.debug("ui", "", "Viewport: %.0f × %.0f" % [get_viewport_rect().size.x, get_viewport_rect().size.y])

	# Detect headless mode early
	var is_headless = DisplayServer.get_name() == "headless"

	# ═══════════════════════════════════════════════════════════════════════
	# BOOT CORE (GameStateManager owns Farm)
	# ═══════════════════════════════════════════════════════════════════════
	# Consume pending restart state if a restart was requested (R key / ESC menu).
	# -1 means fresh game; >=0 means load that slot through the normal boot path.
	var gsm = InstrumentLocator.resolve_game_state_manager(self)
	var load_slot := -1
	var scenario_id := SaveStore.DEFAULT_SCENARIO_ID
	if gsm and gsm.pending_restart_requested:
		load_slot = gsm.pending_restart_slot
		scenario_id = gsm.pending_restart_scenario_id if gsm.pending_restart_scenario_id != "" else SaveStore.DEFAULT_SCENARIO_ID
		gsm.pending_restart_slot = -1
		gsm.pending_restart_requested = false
		gsm.pending_restart_scenario_id = scenario_id
		if load_slot >= 0:
			_verbose.info("ui", "🔄", "Restarting into save slot %d" % load_slot)
		else:
			_verbose.info("ui", "🔄", "Restarting into fresh scenario '%s'" % scenario_id)
	farm = await _boot_mgr.boot_core(load_slot, scenario_id, is_headless)
	if not farm:
		_verbose.warn("ui", "❌", "Farm not available after core boot")
		return

	# Reparent FarmView under Farm (UI lives under simulation)
	if get_parent() != farm:
		var parent = get_parent()
		if parent:
			parent.remove_child(self)
		farm.add_child(self)
		if get_tree().current_scene == self:
			get_tree().current_scene = farm

	# ═══════════════════════════════════════════════════════════════════════
	# SKIP ALL UI SETUP IN HEADLESS MODE (prevents GPU initialization)
	# ═══════════════════════════════════════════════════════════════════════
	if is_headless:
		_verbose.info("ui", "🎯", "Headless mode detected - skipping UI/visualization")
		return

	_create_biome_background_layer()

	# Load PlayerShell scene
	_verbose.debug("ui", "🎪", "Loading player shell scene...")
	var shell_scene = load("res://UI/PlayerShell.tscn")
	if shell_scene:
		shell = shell_scene.instantiate()
		add_child(shell)
		shell.z_index = SHELL_Z_INDEX
		_verbose.info("ui", "✅", "Player shell loaded and added to tree")
	else:
		_verbose.warn("ui", "❌", "PlayerShell.tscn not found!")
		return

	_create_quantum_visualization()

	# ═══════════════════════════════════════════════════════════════════════
	# PRE-BOOT: Signal connections needed before game starts
	# ═══════════════════════════════════════════════════════════════════════

	# CRITICAL: Connect visualization signals BEFORE boot emits game_ready
	# Direct connection - farm → QuantumForceGraph (no controller middleman)
	_connect_quantum_viz_to_farm()

	# ═══════════════════════════════════════════════════════════════════════
	# BOOT UI - Visualization + UI setup after core is ready
	# ═══════════════════════════════════════════════════════════════════════
	_verbose.info("farm", "🚀", "Starting UI Boot Sequence...")
	await _boot_mgr.boot_ui(farm, shell, quantum_viz)
	_verbose.info("farm", "✅", "UI Boot Sequence complete")

	# ═══════════════════════════════════════════════════════════════════════
	# POST-BOOT: Additional signal connections and final setup
	# ═══════════════════════════════════════════════════════════════════════

	_connect_visualization_ui_signals()
	_bind_overlay_hud_proxies()

	# Input is handled by PlayerShell._input() → modal stack → QuantumInstrumentInput
	# No need for InputController anymore!
	_verbose.info("ui", "✅", "Input routing handled by PlayerShell modal stack")

	_verbose.info("ui", "✅", "FarmView ready - game started!")


func _create_biome_background_layer() -> void:
	"""Create full-screen biome background behind gameplay/UI."""
	_verbose.debug("ui", "🖼️", "Creating biome background layer...")
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = BACKGROUND_LAYER  # Behind layer 0 (all other UI)
	bg_layer.name = "BiomeBackgroundLayer"
	add_child(bg_layer)

	biome_background = BiomeBackgroundClass.new()
	biome_background.name = "BiomeBackground"
	bg_layer.add_child(biome_background)
	_verbose.info("ui", "✅", "Biome background created (CanvasLayer -1)")


func _create_quantum_visualization() -> void:
	"""Create the primary quantum visualization layer."""
	_verbose.debug("ui", "🛁", "Creating quantum force graph visualization...")
	quantum_viz = QuantumForceGraph.new()
	add_child(quantum_viz)
	# Keep visualization in viewport space and stable above gameplay plots.
	quantum_viz.top_level = true
	quantum_viz.position = Vector2.ZERO
	quantum_viz.z_index = QUANTUM_VIZ_Z_INDEX


func _connect_quantum_viz_to_farm() -> void:
	"""Connect visualization to farm signals before UI boot completes."""
	if quantum_viz:
		quantum_viz.connect_to_farm(farm)
		return
	push_error("FarmView: quantum_viz is NULL - cannot connect to farm!")


func _connect_visualization_ui_signals() -> void:
	"""Connect plot selection + gesture signals to visualization."""
	# Connect PlotGridDisplay → visualization (PlotGridDisplay created during boot_ui)
	if quantum_viz and shell:
		var plot_grid_display = shell.get_node_or_null("QuantumInstrument/PlotGridDisplay")
		if plot_grid_display and plot_grid_display.has_signal("plot_selection_changed"):
			plot_grid_display.plot_selection_changed.connect(quantum_viz._on_plot_selection_changed)
			_verbose.info("ui", "✅", "PlotGridDisplay connected to visualization")
			# Sync initial selection state
			if plot_grid_display.has_method("get_selected_plots"):
				var selected = plot_grid_display.get_selected_plots()
				for pos in selected:
					quantum_viz.selected_plot_positions[pos] = true

	# Connect touch gesture signals from QuantumForceGraph (direct access - no .graph)
	if quantum_viz:
		var click_result = quantum_viz.node_clicked.connect(_on_quantum_node_clicked)
		if click_result != OK:
			_verbose.warn("ui", "⚠️", "Failed to connect node_clicked signal")
		else:
			_verbose.info("ui", "✅", "Touch: Tap-to-measure connected")

		quantum_viz.chain_swiped.connect(_on_chain_swiped)
		_verbose.info("ui", "✅", "Touch: Chain-swipe-to-gate connected")


func _bind_overlay_hud_proxies() -> void:
	"""Expose overlay-driven HUD references for diagnostics surfaces."""
	performance_hud = null
	if not shell or not ("overlay_manager" in shell) or not shell.overlay_manager:
		return
	var overlay_manager = shell.overlay_manager
	if overlay_manager.has_signal("quit_requested") and not overlay_manager.quit_requested.is_connected(_on_quit_requested):
		overlay_manager.quit_requested.connect(_on_quit_requested)
	if overlay_manager.has_method("get_overlay"):
		performance_hud = overlay_manager.get_overlay("inspector")


func _on_quit_requested() -> void:
	"""Handle quit request"""
	_verbose.info("ui", "🛑", "Quit requested - exiting game")
	if quantum_viz and quantum_viz.has_method("teardown"):
		quantum_viz.teardown()
	var gsm = InstrumentLocator.resolve_game_state_manager(self)
	if gsm and gsm.has_method("request_application_quit"):
		gsm.request_application_quit(true)
	else:
		if farm and is_instance_valid(farm):
			farm.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		get_tree().quit()


func _on_overlay_state_changed(overlay_name: String, visible: bool) -> void:
	"""Handle overlay state changes (if needed for future features)"""
	# Input is now handled by PlayerShell modal stack - no sync needed
	pass


func _on_quantum_node_clicked(grid_pos: Vector2i, button_index: int) -> void:
	"""Handle tap gesture on quantum bubble - TAP TO MEASURE/POP (v2 Terminal system)

	Triggered when user taps a quantum bubble (short press <50px distance).
	Uses Terminal-based architecture (EXPLORE → MEASURE → POP):
	- Bound but not measured → MEASURE (collapse quantum state)
	- Measured → POP (harvest and return terminal to pool)
	"""
	_verbose.debug("ui", "🎯", "BUBBLE TAP HANDLER CALLED! Grid pos: %s, button: %d" % [grid_pos, button_index])

	if not farm or not farm.terminal_pool:
		_verbose.warn("ui", "⚠️", "No farm or terminal_pool available")
		return

	# Look up terminal via plot (O(1) vs O(n) pool scan)
	var plot = farm.grid.get_plot(grid_pos) if farm.grid else null
	var terminal = plot.terminal if plot else null
	if not terminal:
		_verbose.warn("ui", "⚠️", "No terminal bound at %s" % grid_pos)
		return

	if not ("instrument" in farm) or not farm.instrument:
		_verbose.error("ui", "❌", "Bubble tap requires Farm.instrument but none is attached")
		return

	# Bubble tap action: measure or pop (Ensemble Model)
	if not terminal.is_measured:
		# MEASURE: Sample from ensemble, drain ρ, record claim
		_verbose.debug("ui", "→", "MEASURING terminal at %s" % grid_pos)
		var result = farm.instrument.action_measure(grid_pos)
		if result.success:
			var prob = result.recorded_probability
			var drained = result.was_drained
			_verbose.info("ui", "📊", "Measured: %s (%.1f%% recorded, drained=%s)" % [
				result.outcome, prob * 100, drained
			])
		else:
			_verbose.warn("ui", "⚠️", "Measure failed: %s" % result.get("message", "unknown"))
	else:
		# POP: Convert recorded probability to credits with purity and neighbor bonuses
		_verbose.debug("ui", "→", "POPPING terminal at %s" % grid_pos)
		var result = farm.instrument.action_pop(grid_pos)
		if result.success:
			var credits = result.credits
			var purity = result.get("purity", 1.0)
			var neighbors = result.get("neighbor_count", 4)
			_verbose.info("ui", "🎉", "Popped: %s → %.1f credits (purity: %.2f, neighbors: %d)" % [result.resource, credits, purity, neighbors])
		else:
			_verbose.warn("ui", "⚠️", "Pop failed: %s" % result.get("message", "unknown"))


func _on_chain_swiped(positions: Array) -> void:
	"""Handle chain swipe across bubbles → gate building via QII."""
	if positions.size() < 2 or not farm:
		return

	_verbose.debug("ui", "⛓️", "Chain swipe: %d bubbles %s" % [positions.size(), positions])

	# Route through QuantumInstrumentInput for tool-aware gate building
	var qi = shell.current_farm_ui.input_handler if shell and shell.current_farm_ui else null
	if not qi:
		_verbose.error("ui", "❌", "Chain swipe requires QuantumInstrumentInput but none is attached")
		return
	qi.apply_chain_gate(positions)


func get_farm() -> Node:
	"""Get the current farm (for external access)"""
	return farm


func get_shell() -> Node:
	"""Get the shell (for external access)"""
	return shell
