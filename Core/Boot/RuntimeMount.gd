class_name RuntimeMount
extends RefCounted

## Attaches view-side stuff to a live Farm: visualization (force graph, atlases, layout),
## UI mount (FarmUI, PlotGridDisplay, QuantumInstrumentInput, FarmSurface, SnapshotService),
## and music check.
##
## Owns:
## - stage_visualization (Stage 3B)
## - stage_ui (Stage 3C, async)
## - stage_music (Stage 3E)
## - bubble quality decision + emoji atlas collection helpers
##
## RefCounted; takes farm/shell/quantum_viz Nodes as parameters from the orchestrator.

const PerfOptimizer = preload("res://Core/Settings/PerformanceOptimizer.gd")

var _verbose  # Injected from BootManager (VerboseConfig)


func _init(verbose) -> void:
	_verbose = verbose


func stage_visualization(farm: Node, quantum_viz: Node) -> void:
	# Stage 3B: Initialize visualization (force graph, atlases, layout).
	# Returns silently on early-out paths (headless, null viz); orchestrator emits the
	# `visualization_ready` signal regardless, matching original behavior.
	_verbose.info("boot", "📍", "Stage 3B: Visualization")
	var is_headless = DisplayServer.get_name() == "headless"

	if not quantum_viz:
		if is_headless:
			_verbose.info("boot", "ℹ️", "Headless rig: QuantumViz unavailable (expected)")
		else:
			_verbose.warn("boot", "⚠️", "QuantumViz is null - skipping visualization")
		return

	# Register biomes with QuantumForceGraph (direct - no controller middleman)
	if not quantum_viz.layout_calculator:
		if is_headless:
			_verbose.info("boot", "ℹ️", "Headless rig: layout calculator unavailable (expected)")
		else:
			_verbose.warn("boot", "⚠️", "BiomeLayoutCalculator not created - visualization disabled")
		return

	_verbose.info("boot", "✓", "QuantumForceGraph created")
	_verbose.info("boot", "✓", "BiomeLayoutCalculator ready")
	_verbose.info("boot", "✓", "Layout positions computed")

	# Collect biomes for setup (canonical source: farm.grid)
	var biomes = {}
	if farm.biome_enabled and farm.grid:
		for biome_name in farm.grid.get_biome_names():
			var biome = farm.grid.get_biome(biome_name)
			if biome:
				biomes[biome_name] = biome

	# Quantum visualization setup (direct QuantumForceGraph - no controller)
	if biomes.size() > 0:
		_verbose.info("boot", "💭", "Setting up quantum visualization...")
		for biome_name in biomes:
			quantum_viz.biomes[biome_name] = biomes[biome_name]

		# Initialize layout and setup.
		# setup() hydrates any already-bound terminals from the TerminalPool,
		# including save/restore state, before we attach the live farm signals.
		quantum_viz.update_layout(true)
		var farm_grid = farm.grid if "grid" in farm else null
		var terminal_pool = farm.terminal_pool if "terminal_pool" in farm else null
		quantum_viz.setup(biomes, farm_grid, terminal_pool)

		# Wire farm signals → QuantumForceGraph so new explores create bubbles.
		# setup() handles current state hydration; connect_to_farm() is the live delta lane.
		if quantum_viz.has_method("connect_to_farm"):
			quantum_viz.connect_to_farm(farm)

		# Re-run layout NOW that biome_evolution_batcher is wired.
		# update_layout() pushes biome oval centers to the batcher's cache so they can be
		# forwarded to the C++ ForceGraphEngine once it finishes async initialization.
		quantum_viz.update_layout(false)

		# Seed node positions from layout calculator before C++ engine takes over.
		# This gives sane initial positions so there's no one-frame pile-up at origin.
		if quantum_viz.quantum_nodes.size() > 0:
			for node in quantum_viz.quantum_nodes:
				if node and node.biome_name and quantum_viz.layout_calculator:
					var new_pos = quantum_viz.layout_calculator.get_parametric_position(
						node.biome_name, node.parametric_t, node.parametric_ring
					)
					node.position = new_pos
					node.classical_anchor = new_pos
			_verbose.info("boot", "🔄", "Seeded %d node positions from layout" % quantum_viz.quantum_nodes.size())

		_verbose.info("boot", "✓", "Quantum viz ready")

	# Pre-compile GPU shaders before creating force graph (requires Vulkan RenderingDevice)
	var _rd_check = RenderingServer.create_local_rendering_device()
	var _has_rd = _rd_check != null
	if _rd_check:
		_rd_check.free()
	if biomes.size() > 0:
		_verbose.info("boot", "🎨", "Building emoji atlas...")

		# Collect all emojis (biomes JSON + factions JSON + runtime from loaded biomes)
		var all_emojis = collect_all_emojis(biomes)
		_verbose.info("boot", "🎨", "  Total unique: %d emojis" % all_emojis.size())

		# Build atlas with graceful fallback (skip in headless mode)
		var EmojiAtlasBatcherClass = load("res://Core/Visualization/EmojiAtlasBatcher.gd")
		var atlas_batcher = EmojiAtlasBatcherClass.new()

		if is_headless:
			_verbose.info("boot", "ℹ️", "Headless mode detected - skipping atlas build (text fallback)")
		else:
			# Try to build atlas, but don't fail if it errors
			_verbose.info("boot", "🎨", "  Attempting atlas build (may take 10-30 seconds)...")
			atlas_batcher.build_atlas_cached(all_emojis, quantum_viz)
			if atlas_batcher._atlas_built:
				_verbose.info("boot", "✓", "Emoji atlas ready (%d emojis)" % atlas_batcher._emoji_uvs.size())
			else:
				_verbose.warn("boot", "⚠️", "Atlas build failed - using text fallback for all emojis")

		# Pass atlas to quantum viz (even if empty - will use text fallback)
		if quantum_viz.has_method("set_emoji_atlas_batcher"):
			quantum_viz.set_emoji_atlas_batcher(atlas_batcher)

		# Build bubble shape atlas for GPU-accelerated bubble rendering
		_verbose.info("boot", "🔮", "Building bubble atlas...")
		var BubbleAtlasBatcherClass = load("res://Core/Visualization/BubbleAtlasBatcher.gd")
		var bubble_atlas = BubbleAtlasBatcherClass.new()
		if bubble_atlas.build_atlas():
			_verbose.info("boot", "✓", "Bubble atlas ready (%d templates)" % bubble_atlas._template_uvs.size())

			var bubble_quality := resolve_bubble_quality(bubble_atlas)
			bubble_atlas.set_graphics_quality(bubble_quality)
			_verbose.info("boot", "🖥️", "Bubble quality: %s" % bubble_quality_name(bubble_atlas, bubble_quality))

			# Pass atlas to the quantum viz graph for use by bubble renderer
			if quantum_viz.has_method("set_bubble_atlas_batcher"):
				quantum_viz.set_bubble_atlas_batcher(bubble_atlas)
		else:
			_verbose.warn("boot", "⚠️", "Bubble atlas build failed - using C++ fallback")

	# Initial explored terminals are sourced from save/scenario state
	# (GameStateSerializer plot restore), not hardcoded boot-time auto-explore.


func resolve_bubble_quality(bubble_atlas) -> int:
	var override := OS.get_environment("SW_BUBBLE_QUALITY").strip_edges().to_lower()
	match override:
		"low":
			return bubble_atlas.GraphicsQuality.LOW
		"medium", "med":
			return bubble_atlas.GraphicsQuality.MEDIUM
		"high":
			return bubble_atlas.GraphicsQuality.HIGH
		_:
			pass

	if PerfOptimizer.detect_software_renderer():
		return bubble_atlas.GraphicsQuality.LOW
	return bubble_atlas.GraphicsQuality.HIGH


func bubble_quality_name(bubble_atlas, quality: int) -> String:
	match quality:
		bubble_atlas.GraphicsQuality.LOW:
			return "LOW"
		bubble_atlas.GraphicsQuality.MEDIUM:
			return "MEDIUM"
		bubble_atlas.GraphicsQuality.HIGH:
			return "HIGH"
		_:
			return "UNKNOWN(%d)" % quality


func stage_ui(farm: Node, shell: Node, quantum_viz: Node, world_builder) -> void:
	# Stage 3C: Initialize UI (FarmUI, PlotGridDisplay, QuantumInstrumentInput, FarmSurface,
	# SnapshotService). Async — caller must `await`.
	# `world_builder` is needed only for ensure_quantum_instrument() — kept stateless.
	_verbose.info("boot", "📍", "Stage 3C: UI Initialization")

	# Verify shell is a PlayerShell with expected methods
	if not shell.has_method("load_farm_ui"):
		push_error("BootManager: shell is not a PlayerShell! Type: %s, Script: %s" % [
			shell.get_class(),
			shell.get_script().resource_path if shell.get_script() else "no script"
		])
		return

	# Load and instantiate FarmUI scene
	_verbose.info("boot", "🔍", "Loading FarmUI.tscn...")
	var farm_ui_scene = load("res://UI/FarmUI.tscn")
	assert(farm_ui_scene != null, "FarmUI.tscn not found!")

	_verbose.info("boot", "🔍", "Instantiating FarmUI...")
	var farm_ui = farm_ui_scene.instantiate() as Control
	assert(farm_ui != null, "FarmUI failed to instantiate!")
	_verbose.info("boot", "✓", "FarmUI instantiated")

	# INJECT DEPENDENCIES BEFORE ADD_CHILD
	# This allows PlotGridDisplay._ready() to have all dependencies available,
	# creating tiles synchronously during tree entry (cleaner boot sequence).
	var plot_grid_display = farm_ui.get_node("PlotGridDisplay")
	if plot_grid_display:
		# Inject in order: farm → grid_config → layout_calculator → biomes
		plot_grid_display.inject_farm(farm)
		plot_grid_display.inject_grid_config(farm.grid_config)

		# Layout calculator may not exist if no biomes were loaded
		if quantum_viz and quantum_viz.layout_calculator:
			if plot_grid_display.has_method("inject_layout_calculator"):
				plot_grid_display.inject_layout_calculator(quantum_viz.layout_calculator)
		else:
			if DisplayServer.get_name() == "headless":
				_verbose.info("boot", "ℹ️", "Headless rig: no layout_calculator (fallback tile positions)")
			else:
				_verbose.warn("boot", "⚠️", "No layout_calculator available - tiles will use fallback positioning")

		if farm.grid and farm.grid.has_biomes():
			plot_grid_display.inject_biomes(farm.grid.get_all_biomes())
			_verbose.info("boot", "✓", "PlotGridDisplay dependencies pre-injected")
		else:
			_verbose.warn("boot", "⚠️", "No biomes to inject - PlotGridDisplay will have no tiles")

		# Wire plot positions to QuantumForceGraph for tethering
		if quantum_viz and plot_grid_display.has_signal("plot_positions_changed"):
			if not plot_grid_display.plot_positions_changed.is_connected(quantum_viz.update_plot_positions):
				plot_grid_display.plot_positions_changed.connect(quantum_viz.update_plot_positions)
				_verbose.info("boot", "📡", "PlotGridDisplay connected to QuantumForceGraph anchors")

	# NOW add to tree - _ready() runs with all dependencies available
	_verbose.info("boot", "🔍", "Mounting FarmUI in shell (triggers _ready)...")
	shell.load_farm_ui(farm_ui)
	_verbose.info("boot", "✓", "FarmUI mounted in shell")

	# Set farm reference in PlayerShell (needed for quest board)
	shell.farm = farm
	_verbose.info("boot", "✓", "Farm reference set in PlayerShell")

	# Setup remaining FarmUI parts (ResourcePanel wiring, signal connections)
	# PlotGridDisplay injection is idempotent - guards prevent double tile creation
	_verbose.info("boot", "🔍", "Calling farm_ui.setup_farm()...")
	farm_ui.setup_farm(farm)
	_verbose.info("boot", "✓", "farm_ui.setup_farm() complete")

	# Create and inject QuantumInstrumentInput (single input projection)
	_verbose.info("boot", "🔍", "Creating QuantumInstrumentInput...")
	var instrument_input = Node.new()
	var QuantumInstrumentScript = load("res://UI/Core/QuantumInstrumentInput.gd")
	instrument_input.set_script(QuantumInstrumentScript)
	instrument_input.name = "QuantumInstrumentInput"
	_verbose.info("boot", "🔍", "Adding QuantumInstrumentInput to shell (triggers _ready)...")
	shell.add_child(instrument_input)
	_verbose.info("boot", "✓", "QuantumInstrumentInput added to tree")

	# Inject dependencies
	instrument_input.inject_farm(farm)
	if plot_grid_display:
		instrument_input.inject_plot_grid_display(plot_grid_display)

		# Connect multi-select checkbox signal to PlotGridDisplay
		instrument_input.plot_checked.connect(plot_grid_display.set_plot_checked)
		_verbose.info("boot", "✓", "Multi-select checkbox signals connected")
	farm_ui.instrument_input = instrument_input

	# CRITICAL: Connect instrument_input signals to action bar AFTER instrument_input exists
	# (farm_setup_complete fires too early, before instrument_input is created)
	if shell.has_method("connect_to_quantum_input"):
		shell.connect_to_quantum_input()
		_verbose.info("boot", "✓", "QuantumInstrumentInput connected to action bars")

	var instrument = world_builder.ensure_quantum_instrument(farm)
	shell.quantum_instrument = instrument
	instrument_input.inject_instrument(instrument)
	_verbose.info("boot", "🎛️", "QuantumInstrument ready (unified game mechanics API)")

	# Mount FarmSurface — the live instrument's snapshot contract.
	const FarmSurfaceScript = preload("res://UI/Core/FarmSurface.gd")
	var farm_surface = FarmSurfaceScript.new()
	farm_surface.name = "FarmSurface"
	shell.add_child(farm_surface)
	var abm = (Engine.get_main_loop().root.get_node_or_null("/root/ActiveBiomeManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	farm_surface.bind(instrument, abm)
	if farm_surface.has_method("bind_tool_input"):
		farm_surface.bind_tool_input(instrument_input)
	farm_surface.mount()
	if "farm_surface" in shell:
		shell.farm_surface = farm_surface
	_verbose.info("boot", "🔭", "FarmSurface mounted (surface snapshot contract)")

	# Create SnapshotService for diagnostics/state snapshots shared by UI + headless runners
	const SnapshotServiceClass = preload("res://Core/Instrumentation/SnapshotService.gd")
	var snapshot_service = SnapshotServiceClass.new()
	snapshot_service.name = "SnapshotService"
	shell.add_child(snapshot_service)
	shell.snapshot_service = snapshot_service
	snapshot_service.setup(farm, shell)
	snapshot_service.inject_instrument(instrument)
	_verbose.info("boot", "🎛️", "SnapshotService ready (diagnostics + rig snapshots)")

	_verbose.info("boot", "✓", "QuantumInstrumentInput created (Musical Spindle)")


func stage_music() -> void:
	# Stage 3E: Seed initial music track.
	_verbose.info("boot", "📍", "Stage 3E: Music")

	var music = (Engine.get_main_loop().root.get_node_or_null("/root/MusicManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if not music:
		_verbose.warn("boot", "⚠️", "MusicManager not found - skipping music")
		return

	var abm = (Engine.get_main_loop().root.get_node_or_null("/root/ActiveBiomeManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	var active_biome: String = abm.get_active_biome() if abm and abm.has_method("get_active_biome") else ""
	if not active_biome.is_empty():
		music.play_biome_track(active_biome)
		_verbose.info("boot", "🎵", "Music started: %s" % active_biome)
	else:
		_verbose.info("boot", "🔇", "No active biome — music starts silent")


func collect_all_emojis(biomes: Dictionary) -> Array:
	# Extract ALL unique emojis for atlas building.
	# Uses IconRegistry.build_emoji_universe() to get emojis from BiomeRegistry +
	# FactionRegistry, plus runtime emojis from currently loaded biomes.
	var icon_registry = (Engine.get_main_loop().root.get_node_or_null("/root/IconRegistry") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	# Start with all emojis from BiomeRegistry + FactionRegistry
	var unique_emojis: Dictionary = {}
	for emoji in icon_registry.build_emoji_universe():
		unique_emojis[emoji] = true

	# Also include runtime emojis from currently loaded biomes
	for biome_name in biomes:
		var biome = biomes[biome_name]
		if not biome:
			continue

		# PRIMARY SOURCE: Use viz_cache.get_emojis() if available (most complete)
		if biome.has_method("get_emoji_pair_for_qubit") or (biome.has_meta("viz_cache") or "viz_cache" in biome):
			if biome.viz_cache and biome.viz_cache.has_method("get_emojis"):
				var biome_emojis = biome.viz_cache.get_emojis()
				if biome_emojis:
					for emoji in biome_emojis:
						unique_emojis[emoji] = true
					continue  # Got emojis from viz_cache, skip to next biome

		# FALLBACK: Use quantum_computer register_map
		if not biome.quantum_computer:
			continue

		var qc = biome.quantum_computer
		var register_map = qc.register_map
		if not register_map:
			continue

		# Get all emojis from register map coordinates
		if "coordinates" in register_map:
			for emoji in register_map.coordinates.keys():
				if not emoji.is_valid_ascii():
					unique_emojis[emoji] = true

		# Also get from axes (north/south poles)
		if "axes" in register_map:
			for axis_id in register_map.axes:
				var axis = register_map.axes[axis_id]
				if axis.has("north") and not axis.north.is_valid_ascii():
					unique_emojis[axis.north] = true
				if axis.has("south") and not axis.south.is_valid_ascii():
					unique_emojis[axis.south] = true

	return unique_emojis.keys()
