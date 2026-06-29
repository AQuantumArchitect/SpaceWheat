class_name QuantumNodeManager
extends RefCounted


## Quantum Node Manager
##
## Manages quantum node lifecycle:
## - Creating nodes from biomes/plots
## - Updating node visuals from quantum state
## - Filtering nodes for active biome
## - Animation updates


func create_quantum_nodes(ctx: Dictionary, _skip_quantum_register_bubbles: bool = false) -> Array:
	# Create quantum nodes for already-bound terminals.

	# Architecture:
	# 1. Terminal bubbles for any pre-bound terminals (from save/load)
	# 2. New terminals create bubbles dynamically via _on_terminal_bound signal
	# 3. Boot explore is triggered by BootManager after viz setup (real action, not fake)

	# Args:
	# ctx: Context dictionary with {biomes, farm_grid, terminal_pool, layout_calculator}
	# _skip_quantum_register_bubbles: Deprecated; ignored

	# Returns:
	# Array of created QuantumNode instances
	var biomes = ctx.get("biomes", {})
	var terminal_pool = ctx.get("terminal_pool")
	var layout_calculator = ctx.get("layout_calculator")

	var nodes: Array = []

	# TERMINAL BUBBLES: Create bubbles for terminals already bound (from save/load)
	if terminal_pool and terminal_pool.has_method("get_bound_terminals"):
		var bound_count = 0
		for terminal in terminal_pool.get_bound_terminals():
			var node = _create_node_for_terminal(terminal, layout_calculator, biomes)
			if node:
				nodes.append(node)
				bound_count += 1
		if bound_count > 0:
			var verbose = _get_verbose()
			if verbose:
				verbose.debug("viz", "💾", "Restored %d terminal bubbles from save" % bound_count)

	return nodes


func _create_node_for_register(biome_name: String, register_id: int, biomes: Dictionary, layout_calculator):
	# Create a QuantumNode directly from a quantum register (first-class architecture).

	# Args:
	# biome_name: Name of the biome containing the register
	# register_id: Index of the register/qubit in the quantum computer
	# biomes: Dictionary of all biomes for resolver
	# layout_calculator: For positioning bubbles

	# Returns:
	# QuantumNode representing this quantum register
	var biome = biomes.get(biome_name)
	if not biome or not biome.viz_cache or not biome.viz_cache.has_metadata():
		return null

	if register_id < 0 or register_id >= biome.viz_cache.get_num_qubits():
		return null

	# Calculate position from biome layout
	var anchor_pos = Vector2.ZERO
	var center_pos = Vector2.ZERO
	var parametric_t = 0.5
	var parametric_ring = 0.5

	if layout_calculator:
		center_pos = layout_calculator.graph_center
		# Distribute registers evenly around biome oval
		var num_registers = biome.viz_cache.get_num_qubits()
		parametric_t = float(register_id) / float(num_registers) if num_registers > 0 else 0.5
		parametric_ring = 0.7  # Place on outer ring by default

		anchor_pos = layout_calculator.get_parametric_position(
			biome_name,
			parametric_t,
			parametric_ring
		)

	# Create node (no plot, no terminal initially - pure quantum)
	var node = QuantumNode.new(null, anchor_pos, GridSentinel.INVALID_POSITION, center_pos)

	# PRIMARY quantum reference (this is what makes it first-class)
	node.biome_name = biome_name
	node.register_id = register_id
	node.plot_id = "%s_r%d" % [biome_name, register_id]  # Unique ID based on register

	# Biome resolver for quantum state queries
	node.biome_resolver = func(name: String): return biomes.get(name, null)

	# Parametric coordinates for layout
	node.parametric_t = parametric_t
	node.parametric_ring = parametric_ring

	# Get emojis from quantum register via biome
	var axis = biome.viz_cache.get_axis(register_id) if biome.viz_cache else {}
	node.emoji_north = axis.get("north", "")
	node.emoji_south = axis.get("south", "")

	# Not a terminal bubble (pure quantum visualization)
	node.is_terminal_bubble = false
	node.has_farm_tether = false

	# Ensure node is visible and has physics enabled
	node.visible = true
	node.quantum_behavior = 0  # 0 = FLOATING (physics enabled)

	return node


func create_sun_qubit_node(biome, layout_calculator):
	# Create the special sun qubit node for the BioticFlux biome.
	#
	# This is the top-layer celestial node, not a farm tether and not part of
	# the regular quantum node pool. The graph renders it separately so it can
	# stay visually distinct while still using the same bubble renderer.
	if not biome:
		return null

	var center_pos := Vector2.ZERO
	if layout_calculator:
		center_pos = layout_calculator.graph_center

	var biome_name := "BioticFlux"
	if biome and "biome_name" in biome and biome.biome_name != "":
		biome_name = biome.biome_name
	elif biome and biome.has_method("get_biome_type"):
		biome_name = biome.get_biome_type()

	var node = QuantumNode.new(null, center_pos, GridSentinel.INVALID_POSITION, center_pos)
	node.biome_name = biome_name
	node.register_id = 0
	node.plot_id = "%s_sun_qubit" % biome_name
	node.biome_resolver = func(name: String): return biome if name == biome_name else null
	node.has_farm_tether = false
	node.is_terminal_bubble = false
	node.quantum_behavior = 2  # 2 = FIXED: completely static celestial body
	node.visible = true
	node.visual_scale = 1.0
	node.visual_alpha = 1.0
	node.radius = 28.0
	node.coherence = 1.0
	node.energy = 1.0
	node.purity = 1.0
	node.color = Color(1.0, 0.88, 0.34, 1.0)
	node.season_projections[0] = 0.5
	node.season_projections[1] = 0.5
	node.season_projections[2] = 0.5

	var axis = {}
	if biome and biome.viz_cache and biome.viz_cache.has_metadata():
		axis = biome.viz_cache.get_axis(0)
	if axis.is_empty():
		axis = {"north": "☀", "south": "🌙"}
	node.emoji_north = axis.get("north", "☀")
	node.emoji_south = axis.get("south", "🌙")
	node.emoji_north_opacity = 1.0
	node.emoji_south_opacity = 0.15

	return node


func _create_node_for_plot(plot, grid_pos: Vector2i, layout_calculator, biomes: Dictionary):
	# Create a QuantumNode for a farm plot.
	# Calculate initial anchor position
	var anchor_pos = Vector2.ZERO
	var center_pos = Vector2.ZERO
	var biome_name = ""
	if plot.parent_biome:
		biome_name = plot.parent_biome.biome_name if "biome_name" in plot.parent_biome else ""

	if layout_calculator:
		center_pos = layout_calculator.graph_center
		var positions = layout_calculator.distribute_nodes_in_biome(biome_name, 4)
		if positions.size() > 0:
			var idx = clampi(grid_pos.x, 0, positions.size() - 1)
			var params = positions[idx]
			anchor_pos = layout_calculator.get_parametric_position(
				biome_name,
				params.get("t", 0.5),
				params.get("ring", 0.5)
			)
		else:
			# Fallback: random scattered position if layout calculator doesn't know this biome
			var angle = randf() * TAU
			var radius = 100.0 + randf() * 150.0
			anchor_pos = center_pos + Vector2(cos(angle), sin(angle)) * radius

	# Create node with required constructor arguments
	var node = QuantumNode.new(plot, anchor_pos, grid_pos, center_pos)

	node.plot_id = plot.plot_id if "plot_id" in plot else str(grid_pos)
	node.has_farm_tether = true

	# Set biome resolver for terminal-based biome lookup
	node.biome_resolver = func(name: String): return biomes.get(name, null)

	node.biome_name = biome_name
	if layout_calculator and biome_name != "":
		var positions = layout_calculator.distribute_nodes_in_biome(biome_name, 4)
		if positions.size() > 0:
			var idx = clampi(grid_pos.x, 0, positions.size() - 1)
			var params = positions[idx]
			node.parametric_t = params.get("t", 0.5)
			node.parametric_ring = params.get("ring", 0.5)

	# Initialize emojis
	if plot.is_active():
		var emojis = plot.get_plot_emojis() if plot.has_method("get_plot_emojis") else {}
		node.emoji_north = emojis.get("north", "")
		node.emoji_south = emojis.get("south", "")

	return node


func _create_node_for_terminal(terminal, layout_calculator, biomes: Dictionary):
	# Create a QuantumNode for a plot pool terminal.
	# Calculate initial anchor position
	var anchor_pos = Vector2.ZERO
	var center_pos = Vector2.ZERO
	var biome_name = terminal.bound_biome_name if terminal.bound_biome_name != "" else ""

	if layout_calculator:
		center_pos = layout_calculator.graph_center
		var positions = layout_calculator.distribute_nodes_in_biome(biome_name, 4)
		if positions.size() > 0:
			var idx = clampi(terminal.grid_position.x, 0, positions.size() - 1)
			var params = positions[idx]
			anchor_pos = layout_calculator.get_parametric_position(
				biome_name,
				params.get("t", 0.5),
				params.get("ring", 0.5)
			)
		else:
			# Fallback: random scattered position if layout calculator doesn't know this biome
			var angle = randf() * TAU
			var radius = 100.0 + randf() * 150.0
			anchor_pos = center_pos + Vector2(cos(angle), sin(angle)) * radius

	# Create node with required constructor arguments (null plot for terminal bubbles)
	var node = QuantumNode.new(null, anchor_pos, terminal.grid_position, center_pos)

	node.terminal = terminal
	node.has_farm_tether = true
	node.is_terminal_bubble = true

	# Set biome resolver for terminal-based biome lookup
	node.biome_resolver = func(name: String): return biomes.get(name, null)

	# Get biome name from terminal binding (now a string, not object)
	if biome_name != "":
		node.biome_name = biome_name
		if layout_calculator:
			var positions = layout_calculator.distribute_nodes_in_biome(biome_name, 4)
			if positions.size() > 0:
				var idx = clampi(terminal.grid_position.x, 0, positions.size() - 1)
				var params = positions[idx]
				node.parametric_t = params.get("t", 0.5)
				node.parametric_ring = params.get("ring", 0.5)

	# Set register_id from terminal binding so viz_cache bloch lookup works
	if "bound_register_id" in terminal and terminal.bound_register_id >= 0:
		node.register_id = terminal.bound_register_id

	# Set emojis from terminal; fall back to viz_cache axes if terminal doesn't have them
	node.emoji_north = terminal.north_emoji if terminal.north_emoji else ""
	node.emoji_south = terminal.south_emoji if terminal.south_emoji else ""
	if (node.emoji_north.is_empty() or node.emoji_south.is_empty()) and node.register_id >= 0 and biome_name != "":
		var biome = biomes.get(biome_name, null)
		if biome and biome.viz_cache:
			var axes = biome.viz_cache.get_axis(node.register_id)
			if not axes.is_empty():
				if node.emoji_north.is_empty():
					node.emoji_north = axes.get("north", "")
				if node.emoji_south.is_empty():
					node.emoji_south = axes.get("south", "")

	return node


func _get_plot_index(grid_pos: Vector2i) -> int:
	# Convert grid position to plot index for hex layout.
	# Standard 2x3 grid mapping
	return grid_pos.y * 3 + grid_pos.x


func update_node_visuals(nodes: Array, ctx: Dictionary) -> void:
	# Update visual properties of all nodes from their quantum states.

	# Optimized: Batches expensive purity queries per biome.

	# Args:
	# nodes: Array of QuantumNode instances
	# ctx: Context dictionary with {biomes, time_accumulator}
	var biomes = ctx.get("biomes", {})
	var time_accumulator = ctx.get("time_accumulator", 0.0)
	var batcher = ctx.get("biome_evolution_batcher", null)
	var use_lookahead = batcher != null and batcher.lookahead_enabled
	var lookahead_offset = ctx.get("lookahead_offset", 0)
	var snapshot_cache: Dictionary = {}

	for node in nodes:
		# Trigger spawn animation for new nodes
		if not node.is_spawning and node.visual_scale == 0.0 and not node.is_lifeless:
			# Pure quantum nodes (no plot, no terminal)
			if not node.has_farm_tether and node.biome_name != "" and not node.emoji_north.is_empty():
				node.start_spawn_animation(time_accumulator)
			# Terminal nodes with farm tether
			elif node.has_farm_tether and not node.emoji_north.is_empty():
				node.start_spawn_animation(time_accumulator)
			# Plot-based nodes
			elif node.plot and node.plot.is_active() and node.plot.parent_biome and node.plot.bath_subplot_id >= 0:
				node.start_spawn_animation(time_accumulator)

		# Update from quantum state (unless terminal bubble with own data)
		if not node.is_terminal_bubble:
			_update_node_visual_batched(
				node,
				biomes,
				use_lookahead,
				lookahead_offset,
				batcher,
				snapshot_cache
			)
		else:
			_update_terminal_visuals_from_buffer(
				node,
				biomes,
				use_lookahead,
				lookahead_offset,
				batcher,
				snapshot_cache
			)


func _update_node_visual_batched(
	node,
	biomes: Dictionary,
	use_lookahead: bool,
	lookahead_offset: int,
	batcher = null,
	snapshot_cache: Dictionary = {}
) -> void:
	# Update single node's visuals with batched purity lookup.
	var biome = null
	var snap = null
	var register_id: int = -1
	# PURE QUANTUM VISUALIZATION (no plot, no terminal - first-class quantum)
	if not node.has_farm_tether and not node.plot and node.biome_name != "":
		biome = biomes.get(node.biome_name, null)
		if biome and biome.viz_cache and node.register_id >= 0:
			# Measured bubbles: frozen visuals, skip quantum state queries
			if node.is_terminal_measured():
				return
			snap = _get_visual_snapshot(
				node.biome_name,
				biome,
				node.register_id,
				use_lookahead,
				lookahead_offset,
				batcher,
				snapshot_cache
			)
			if not node.apply_quantum_snapshot(snap, true):
				node.apply_lifeless_visual({"north": node.emoji_north, "south": node.emoji_south})
				return
			# Ensure node is visible
			if node.visual_scale == 0.0:
				node.visual_scale = 1.0
				node.visual_alpha = 1.0
			return
		else:
			_set_node_fallback(node)
			return

	# Terminal bubbles with no plot
	if node.has_farm_tether and not node.plot:
		if node.terminal and node.terminal.bound_biome_name != "":
			if node.terminal.north_emoji != "":
				node.emoji_north = node.terminal.north_emoji
			if node.terminal.south_emoji != "":
				node.emoji_south = node.terminal.south_emoji
			# Resolve biome from name using the biomes dictionary
			biome = biomes.get(node.terminal.bound_biome_name, null)
			if biome and biome.viz_cache and not node.is_terminal_measured():
				register_id = node.terminal.bound_register_id
				if register_id < 0 and node.emoji_north != "":
					register_id = biome.viz_cache.get_qubit(node.emoji_north)
				snap = _get_visual_snapshot(
					node.terminal.bound_biome_name,
					biome,
					register_id,
					use_lookahead,
					lookahead_offset,
					batcher,
					snapshot_cache
				)
				if not node.apply_quantum_snapshot(snap, true):
					node.apply_lifeless_visual({"north": node.emoji_north, "south": node.emoji_south})
					return
				if node.visual_scale == 0.0:
					node.visual_scale = 1.0
					node.visual_alpha = 1.0
				return
			_set_node_fallback(node)
		return

	# Measured bubbles: frozen visuals, skip quantum state queries
	if node.is_terminal_measured():
		return

	# Guard: unplanted plot → invisible
	if not node.plot or not node.plot.is_active():
		node.apply_lifeless_visual()
		return

	biome = node.plot.parent_biome
	if not biome:
		_set_node_fallback(node)
		return

	if not biome.viz_cache:
		_set_node_fallback(node)
		return

	var emojis = node.plot.get_plot_emojis() if node.plot.has_method("get_plot_emojis") else {}
	node.emoji_north = emojis.get("north", node.emoji_north)
	node.emoji_south = emojis.get("south", node.emoji_south)

	register_id = node.plot.bound_register_id if "bound_register_id" in node.plot else -1
	if register_id < 0 and node.emoji_north != "":
		register_id = biome.viz_cache.get_qubit(node.emoji_north)
	snap = _get_visual_snapshot(
		biome.get_biome_type(),
		biome,
		register_id,
		use_lookahead,
		lookahead_offset,
		batcher,
		snapshot_cache
	)
	if not node.apply_quantum_snapshot(snap, true):
		node.apply_lifeless_visual({"north": node.emoji_north, "south": node.emoji_south})
		return
	if node.visual_scale == 0.0:
		node.visual_scale = 1.0
		node.visual_alpha = 1.0
	return


func _update_terminal_visuals_from_buffer(
	node,
	biomes: Dictionary,
	use_lookahead: bool,
	lookahead_offset: int,
	batcher = null,
	snapshot_cache: Dictionary = {}
) -> void:
	# Update terminal bubbles from lookahead buffer when available.
	if not node.terminal:
		return

	if node.terminal.north_emoji != "":
		node.emoji_north = node.terminal.north_emoji
	if node.terminal.south_emoji != "":
		node.emoji_south = node.terminal.south_emoji

	if node.terminal.is_measured:
		node.apply_measured_visual(
			node.terminal.measured_outcome,
			node.terminal.north_emoji,
			node.terminal.south_emoji
		)
		return

	var biome = biomes.get(node.terminal.bound_biome_name, null)
	if not biome or not biome.viz_cache:
		_warn_unresolved(node, "biome/viz_cache absent for '%s'" % node.terminal.bound_biome_name)
		_set_node_fallback(node)
		return

	if node.terminal.bound_register_id < 0:
		# Binding not yet carrying a register — legitimately not-yet-resolvable
		# (e.g. restore in flight). Stay legible; this is absence, not failure.
		_set_node_fallback(node)
		return

	var snap = _get_visual_snapshot(
		node.terminal.bound_biome_name,
		biome,
		node.terminal.bound_register_id,
		use_lookahead,
		lookahead_offset,
		batcher,
		snapshot_cache
	)
	if node.apply_quantum_snapshot(snap, true):
		return

	# A bound terminal with a valid register that STILL can't resolve a snapshot is a
	# real bug, not a dead bubble — say so once, loudly, instead of silently ghosting it.
	_warn_unresolved(node, "empty snapshot for register %d in '%s' (lookahead=%s)" % [
		node.terminal.bound_register_id, node.terminal.bound_biome_name, str(use_lookahead)])
	_set_node_fallback(node)


func _warn_unresolved(node, reason: String) -> void:
	if node.resolve_warned:
		return
	node.resolve_warned = true
	var verbose = _get_verbose()
	if verbose:
		verbose.warn("viz", "🫧", "Bound terminal bubble unresolved → lifeless: %s" % reason)


func _get_visual_snapshot(
	biome_name: String,
	biome,
	register_id: int,
	use_lookahead: bool,
	lookahead_offset: int,
	batcher = null,
	snapshot_cache: Dictionary = {}
) -> Dictionary:
	if not biome or not biome.viz_cache:
		return {}
	if register_id < 0:
		return {}

	var cache_key = "%s:%d:%d:%d" % [biome_name, register_id, int(use_lookahead), lookahead_offset]
	if snapshot_cache.has(cache_key):
		return snapshot_cache[cache_key]

	var snap: Dictionary = {}
	if use_lookahead and batcher:
		snap = batcher.get_interpolated_snapshot(biome_name, register_id)
		if snap.is_empty():
			snap = biome.viz_cache.get_snapshot(register_id)
	else:
		snap = biome.viz_cache.get_snapshot(register_id)

	snapshot_cache[cache_key] = snap
	return snap


func _set_node_fallback(node) -> void:
	# Set fallback visualization when quantum state is unavailable.
	var emojis_dict = {}
	if node.plot and node.plot.has_method("get_plot_emojis"):
		var emojis = node.plot.get_plot_emojis()
		emojis_dict = {"north": emojis.get("north", ""), "south": emojis.get("south", "")}
	elif node.terminal:
		emojis_dict = {"north": node.terminal.north_emoji, "south": node.terminal.south_emoji}
	node.apply_lifeless_visual(emojis_dict)


func update_animations(nodes: Array, time_accumulator: float, delta: float) -> void:
	# Update spawn animations for all nodes.
	for node in nodes:
		node.update_animation(time_accumulator, delta)


func filter_nodes_for_biome(_nodes: Array, _active_biome: String) -> void:
	# Update node visibility based on active biome.

	# DISABLED: Visibility now controlled by plot selection (PlotGridDisplay checkmarks).
	# This function is a no-op for visibility.

	# Args:
	# nodes: Array of QuantumNode instances
	# active_biome: Name of active biome, or "" for all biomes
	# DISABLED: Don't override selection-based visibility
	# for node in nodes:
	#	if active_biome == "":
	#		node.visible = true
	#	else:
	#		node.visible = (node.biome_name == active_biome)
	pass


func is_node_in_active_biome(node, active_biome: String) -> bool:
	# Check if a node belongs to the active biome.
	if active_biome == "":
		return true
	return node.biome_name == active_biome


func _get_verbose():
	var ml := Engine.get_main_loop()
	return ml.root.get_node_or_null("/root/VerboseConfig") if ml and ml.root else null


func rebuild_from_biomes(biomes: Dictionary, ctx: Dictionary) -> Array:
	# Rebuild all quantum nodes from biomes.

	# Called when biome configuration changes.

	# Args:
	# biomes: Dictionary of biome_name → BiomeBase
	# ctx: Context dictionary

	# Returns:
	# New array of QuantumNode instances
	ctx["biomes"] = biomes
	return create_quantum_nodes(ctx)


func create_all_register_bubbles(biomes: Dictionary, layout_calculator) -> Array:
	# Create bubbles for ALL quantum registers in all biomes.

	# Used by visual tests to populate the force graph without terminal bindings.
	# Creates one bubble per qubit per biome.

	# Args:
	# biomes: Dictionary of biome_name → BiomeBase
	# layout_calculator: For positioning bubbles

	# Returns:
	# Array of created QuantumNode instances
	var nodes: Array = []

	for biome_name in biomes:
		var biome = biomes[biome_name]
		if not biome or not biome.viz_cache or not biome.viz_cache.has_metadata():
			continue

		var num_qubits = biome.viz_cache.get_num_qubits()
		for register_id in range(num_qubits):
			var node = _create_node_for_register(biome_name, register_id, biomes, layout_calculator)
			if node:
				nodes.append(node)

		if num_qubits > 0:
			var verbose = _get_verbose()
			if verbose:
				verbose.debug("viz", "🎈", "Created %d bubbles for %s" % [num_qubits, biome_name])

	if nodes.size() > 0:
		var verbose = _get_verbose()
		if verbose:
			verbose.info("viz", "✓", "Created %d register bubbles total" % nodes.size())
	return nodes
