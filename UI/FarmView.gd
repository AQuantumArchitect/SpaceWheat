## FarmView - UI entry point
## Farm is owned/created by GameStateManager; FarmView only attaches UI.

extends Control

const QuantumForceGraph = preload("res://Core/Visualization/QuantumForceGraph.gd")
const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")
const BiomeBackgroundClass = preload("res://Core/Visualization/BiomeBackground.gd")
const PerformanceHUDClass = preload("res://UI/Overlays/PerformanceHUD.gd")
const MilkHunterBridgeClass = preload("res://Core/Instrumentation/MilkHunterBridge.gd")
const MilkHunterHUDClass = preload("res://UI/Overlays/MilkHunterHUD.gd")
# BootManager is an autoload singleton - no need to preload

const BACKGROUND_LAYER := -1
const SHELL_Z_INDEX := 10
const QUANTUM_VIZ_Z_INDEX := 40
const PERFORMANCE_HUD_Z_INDEX := 2000
const MILK_HUNTER_HUD_Z_INDEX := 1500

var shell = null  # PlayerShell (from scene)
var farm: Node = null
var quantum_viz: QuantumForceGraph = null
var biome_background: Control = null  # BiomeBackground for full-screen biome art
var performance_hud: Control = null  # Performance profiling overlay
var milk_hunter_bridge: Node = null  # MilkHunterBridge (phrame-paced IPC)
var milk_hunter_hud: Control = null  # MilkHunterHUD overlay

# Helpers to access autoloads safely (avoids compile-time errors in tests)
@onready var _verbose = get_node("/root/VerboseConfig")
@onready var _boot_mgr = get_node("/root/BootManager")


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
	farm = await _boot_mgr.boot_core(-1, "default", is_headless)
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
	_create_performance_hud()

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

	# Optional: phrame-paced milk hunter bridge for visual automation runs
	if OS.get_environment("RIG_PHRAME_BRIDGE") == "1":
		_create_milk_hunter_bridge()

	# ═══════════════════════════════════════════════════════════════════════
	# POST-BOOT: Additional signal connections and final setup
	# ═══════════════════════════════════════════════════════════════════════

	_connect_visualization_ui_signals()

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


func _create_performance_hud() -> void:
	"""Create high-z performance profiling overlay."""
	_verbose.debug("ui", "🔬", "Creating performance profiling HUD...")
	performance_hud = PerformanceHUDClass.new()
	add_child(performance_hud)
	performance_hud.z_index = PERFORMANCE_HUD_Z_INDEX  # Above all UI
	_verbose.info("ui", "✅", "Performance HUD created")


func _create_milk_hunter_bridge() -> void:
	"""Create phrame-paced milk hunter bridge + HUD overlay."""
	_verbose.info("ui", "🌉", "Creating MilkHunterBridge (RIG_PHRAME_BRIDGE=1)...")
	milk_hunter_bridge = MilkHunterBridgeClass.new()
	milk_hunter_bridge.name = "MilkHunterBridge"
	add_child(milk_hunter_bridge)
	milk_hunter_bridge.setup(farm, shell.farm_instrument)

	milk_hunter_hud = MilkHunterHUDClass.new()
	milk_hunter_hud.name = "MilkHunterHUD"
	add_child(milk_hunter_hud)
	milk_hunter_hud.z_index = MILK_HUNTER_HUD_Z_INDEX
	milk_hunter_hud.connect_to_bridge(milk_hunter_bridge)
	_verbose.info("ui", "✅", "MilkHunterBridge + HUD ready")


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


func _on_quit_requested() -> void:
	"""Handle quit request"""
	_verbose.info("ui", "🛑", "Quit requested - exiting game")
	get_tree().quit()


func _on_restart_requested() -> void:
	"""Handle restart request"""
	_verbose.info("ui", "🔄", "Restart requested - reloading scene")
	# Reset music completely before reloading
	if has_node("/root/MusicManager"):
		get_node("/root/MusicManager").reset()
	get_tree().reload_current_scene()


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

	# v2: Look up terminal by grid position
	var terminal = farm.terminal_pool.get_terminal_at_grid_pos(grid_pos)
	if not terminal:
		_verbose.warn("ui", "⚠️", "No terminal bound at %s" % grid_pos)
		return

	# Get biome for this position (needed for MEASURE)
	var biome = farm.grid.get_biome_for_plot(grid_pos) if farm.grid else null

	# Bubble tap action: measure or pop (Ensemble Model)
	if not terminal.is_measured:
		# MEASURE: Sample from ensemble, drain ρ, record claim
		_verbose.debug("ui", "→", "MEASURING terminal at %s" % grid_pos)
		var result = ProbeActions.action_measure(terminal, biome, farm.economy)
		if result.success:
			var prob = result.recorded_probability
			var drained = result.was_drained
			_verbose.info("ui", "📊", "Measured: %s (%.1f%% recorded, drained=%s)" % [
				result.outcome, prob * 100, drained
			])
			# Emit with recorded probability for visualization
			farm.plot_measured.emit(grid_pos, result.outcome)
		else:
			_verbose.warn("ui", "⚠️", "Measure failed: %s" % result.get("message", "unknown"))
	else:
		# POP: Convert recorded probability to credits with purity and neighbor bonuses
		_verbose.debug("ui", "→", "POPPING terminal at %s" % grid_pos)
		var result = ProbeActions.action_pop(terminal, farm.terminal_pool, farm.economy, farm)
		if result.success:
			var credits = result.credits
			var purity = result.get("purity", 1.0)
			var neighbors = result.get("neighbor_count", 4)
			_verbose.info("ui", "🎉", "Popped: %s → %.1f credits (purity: %.2f, neighbors: %d)" % [result.resource, credits, purity, neighbors])
			farm.plot_harvested.emit(grid_pos, {
				"emoji": result.resource,
				"credits": credits,
				"purity": purity,
				"neighbors": neighbors
			})
		else:
			_verbose.warn("ui", "⚠️", "Pop failed: %s" % result.get("message", "unknown"))


func _on_chain_swiped(positions: Array) -> void:
	"""Handle chain swipe across bubbles → gate building via QII."""
	if positions.size() < 2 or not farm:
		return

	_verbose.debug("ui", "⛓️", "Chain swipe: %d bubbles %s" % [positions.size(), positions])

	# Route through QuantumInstrumentInput for tool-aware gate building
	var qi = shell.current_farm_ui.input_handler if shell and shell.current_farm_ui else null
	if qi:
		qi.apply_chain_gate(positions)
	else:
		_verbose.debug("ui", "⛓️", "No QII available, using fallback entanglement")
		# Fallback: Bell pairs between consecutive bubbles
		for i in range(positions.size() - 1):
			farm.grid.create_entanglement(positions[i], positions[i + 1], "phi_plus")


func get_farm() -> Node:
	"""Get the current farm (for external access)"""
	return farm


func get_shell() -> Node:
	"""Get the shell (for external access)"""
	return shell
