## FarmView - passive view container for farm runtime.
## GameRoot owns and drives FarmView via attach_runtime / prepare_runtime_visuals
## / finalize_runtime_mount. FarmView does NOT boot, does NOT own a PlayerShell.

extends Control

const BiomeBackgroundClass = preload("res://Core/Visualization/BiomeBackground.gd")

const BACKGROUND_LAYER := -1
const QUANTUM_VIZ_Z_INDEX := 40

var shell = null  # PlayerShell — borrowed from AppRoot, never owned here
var farm: Node = null
var quantum_viz: QuantumForceGraph = null
var biome_background: Control = null
var performance_hud: Control = null

@onready var _verbose = get_node_or_null("/root/VerboseConfig")


func _ready() -> void:
	# Passive container — GameRoot calls attach_runtime() to wire everything.
	add_to_group("farm_view")


# =============================================================================
# RUNTIME LIFECYCLE (called by GameRoot)
# =============================================================================

func attach_runtime(p_farm: Node, p_shell: Node, p_quantum_viz, is_headless: bool) -> void:
	# Store runtime references. Called once (or twice — second call with real values).
	farm = p_farm
	if p_shell != null:
		shell = p_shell
	if p_quantum_viz != null:
		quantum_viz = p_quantum_viz
	if _verbose:
		_verbose.info("ui", "🌾", "FarmView.attach_runtime (headless=%s)" % is_headless)


func prepare_runtime_visuals(is_headless: bool) -> void:
	# Create biome background and wire quantum visualization.
	# Called by GameRoot after attach_runtime, before boot_ui.
	if is_headless:
		if _verbose:
			_verbose.info("ui", "🎯", "FarmView headless — skipping visuals")
		return

	_create_biome_background_layer()
	_connect_quantum_viz_to_farm()


func finalize_runtime_mount(is_headless: bool = false) -> void:
	# Post boot_ui wiring: signal connections and HUD proxies.
	if is_headless:
		return
	_connect_visualization_ui_signals()
	_bind_overlay_hud_proxies()
	if _verbose:
		_verbose.info("ui", "✅", "FarmView ready")


func teardown_runtime() -> void:
	# Called by GameRoot.teardown_visuals before queue_free.
	quantum_viz = null
	biome_background = null
	performance_hud = null
	farm = null
	shell = null


# =============================================================================
# VISUALIZATION SETUP
# =============================================================================

func _create_biome_background_layer() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = BACKGROUND_LAYER
	bg_layer.name = "BiomeBackgroundLayer"
	add_child(bg_layer)

	biome_background = BiomeBackgroundClass.new()
	biome_background.name = "BiomeBackground"
	bg_layer.add_child(biome_background)
	if _verbose:
		_verbose.info("ui", "✅", "Biome background created (CanvasLayer -1)")


func _connect_quantum_viz_to_farm() -> void:
	if quantum_viz:
		quantum_viz.connect_to_farm(farm)
		return
	# Under the SW_FIELD_3D toggle the 3D field is mounted by GameRoot and connects to the
	# farm itself, so a null 2D quantum_viz here is expected, not a failure.
	if OS.has_environment("SW_FIELD_3D"):
		return
	push_error("FarmView: quantum_viz is NULL — cannot connect to farm!")


func _connect_visualization_ui_signals() -> void:
	if quantum_viz and shell:
		var plot_grid_display = shell.get_node_or_null("QuantumInstrument/PlotGridDisplay")
		if plot_grid_display and plot_grid_display.has_signal("plot_selection_changed"):
			plot_grid_display.plot_selection_changed.connect(quantum_viz._on_plot_selection_changed)
			if _verbose:
				_verbose.info("ui", "✅", "PlotGridDisplay connected to visualization")
			if plot_grid_display.has_method("get_selected_plots"):
				var selected = plot_grid_display.get_selected_plots()
				for pos in selected:
					quantum_viz.selected_plot_positions[pos] = true

	if quantum_viz:
		if quantum_viz.node_clicked.connect(_on_quantum_node_clicked) != OK:
			if _verbose:
				_verbose.warn("ui", "⚠️", "Failed to connect node_clicked signal")
		quantum_viz.chain_swiped.connect(_on_chain_swiped)
		if _verbose:
			_verbose.info("ui", "✅", "Quantum viz signals connected")


func _bind_overlay_hud_proxies() -> void:
	performance_hud = null
	if not shell or not ("overlay_manager" in shell) or not shell.overlay_manager:
		return
	var overlay_manager = shell.overlay_manager
	if overlay_manager.has_signal("quit_requested") and not overlay_manager.quit_requested.is_connected(_on_quit_requested):
		overlay_manager.quit_requested.connect(_on_quit_requested)
	if overlay_manager.has_method("get_overlay"):
		performance_hud = overlay_manager.get_overlay("inspector")


# =============================================================================
# INPUT HANDLERS
# =============================================================================

func _on_quit_requested() -> void:
	if _verbose:
		_verbose.info("ui", "🛑", "Quit requested")
	if quantum_viz and quantum_viz.has_method("teardown"):
		quantum_viz.teardown()
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("request_application_quit"):
		gsm.request_application_quit(true)
	else:
		if farm and is_instance_valid(farm):
			farm.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		get_tree().quit()


func _on_quantum_node_clicked(grid_pos: Vector2i, button_index: int) -> void:
	# Delegate to the ONE action decoder. The old direct farm.instrument calls
	# were a parallel mechanics authority: they skipped selection sync, lookahead
	# buffer invalidation, whispers and QII's action_performed. Same resolution
	# as _on_chain_swiped.
	if _verbose:
		_verbose.debug("ui", "🎯", "Bubble tap: %s button=%d" % [grid_pos, button_index])
	var instrument_input = shell.current_farm_ui.instrument_input if shell and shell.current_farm_ui else null
	if not instrument_input:
		if _verbose:
			_verbose.error("ui", "❌", "Bubble tap: no QuantumInstrumentInput attached")
		return
	instrument_input.handle_bubble_tap(grid_pos)


func _on_chain_swiped(positions: Array) -> void:
	if positions.size() < 2 or not farm:
		return
	if _verbose:
		_verbose.debug("ui", "⛓️", "Chain swipe: %d bubbles" % positions.size())
	var instrument_input = shell.current_farm_ui.instrument_input if shell and shell.current_farm_ui else null
	if not instrument_input:
		if _verbose:
			_verbose.error("ui", "❌", "Chain swipe: no QuantumInstrumentInput attached")
		return
	instrument_input.apply_chain_gate(positions)


# =============================================================================
# ACCESSORS
# =============================================================================

func get_farm() -> Node:
	return farm


func get_shell() -> Node:
	return shell
