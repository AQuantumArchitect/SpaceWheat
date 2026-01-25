class_name PlantingManager
extends RefCounted

## PlantingManager - Planting operations with parametric capability system
##
## Extracted from FarmGrid.gd as part of decomposition.
## Handles crop planting with biome capability lookup and economy cost enforcement.

const BiomeBase = preload("res://Core/Environment/BiomeBase.gd")
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")
const FarmPlot = preload("res://Core/GameMechanics/FarmPlot.gd")

# Signals
signal plot_planted(position: Vector2i)
signal plot_changed(position: Vector2i, change_type: String, details: Dictionary)
signal visualization_changed()

# Component dependencies (injected via set_dependencies)
var _plot_manager = null  # GridPlotManager
var _biome_routing = null  # BiomeRoutingManager
var _economy = null  # FarmEconomy
var _entanglement = null  # EntanglementManager
var _verbose = null

# Stats
var total_plots_planted: int = 0


func set_dependencies(plot_manager, biome_routing, economy, entanglement) -> void:
	"""Inject component dependencies."""
	_plot_manager = plot_manager
	_biome_routing = biome_routing
	_economy = economy
	_entanglement = entanglement


func set_verbose(verbose_ref) -> void:
	"""Set verbose logger reference."""
	_verbose = verbose_ref


func plant(position: Vector2i, plant_type: String, _quantum_state: Resource = null) -> bool:
	"""Generic plant method - handles all crop types (PARAMETRIC - Phase 4)

	Queries biome capabilities to get emoji pairs and validate planting.
	No more hard-coded plot_type_map - uses biome-defined capabilities.

	Args:
		position: Grid position to plant at
		plant_type: "wheat", "tomato", "mushroom", etc.
		_quantum_state: DEPRECATED - kept for backward compatibility

	Returns: true if planting succeeded, false otherwise
	"""
	var plot = _plot_manager.get_plot(position)
	if plot == null or plot.is_planted:
		return false

	# Get plot-specific biome from multi-biome registry
	var plot_biome = _biome_routing.get_biome_for_plot(position)
	if not plot_biome:
		push_error("⚠️ Cannot plant: No biome assigned to plot %s" % position)
		return false

	# PARAMETRIC: Find capability for this plant_type in biome
	var capability = null
	for cap in plot_biome.get_plantable_capabilities():
		if cap.plant_type == plant_type:
			capability = cap
			break

	# Dynamic capability creation if capability doesn't exist
	if not capability:
		# Get emoji pair from central registry
		var emoji_pair = EconomyConstants.get_plant_type_emojis(plant_type)
		if emoji_pair.is_empty():
			push_error("⚠️ Unknown plant type: %s (not in EconomyConstants.PLANT_TYPE_EMOJIS)" % plant_type)
			return false

		# Create dynamic capability
		var PlantingCapability = BiomeBase.PlantingCapability
		capability = PlantingCapability.new()
		capability.plant_type = plant_type
		capability.emoji_pair = emoji_pair
		capability.cost = {"💰": EconomyConstants.get_planting_cost(emoji_pair.north)}
		capability.display_name = plant_type.capitalize()
		capability.requires_biome = false

		# Register capability with biome
		plot_biome.planting_capabilities.append(capability)
		if _verbose:
			_verbose.info("farm", "🔧", "Created dynamic capability for %s in %s" % [
				plant_type, plot_biome.get_biome_type()])

	# ECONOMY: Enforce planting costs
	var north_emoji = capability.emoji_pair.get("north", "?")
	var planting_cost = EconomyConstants.get_planting_cost(north_emoji)
	if _economy and planting_cost > 0:
		if not _economy.can_afford_resource("💰", planting_cost):
			push_warning("⚠️ Not enough 💰-credits to plant %s (need %d)" % [plant_type, planting_cost])
			return false
		_economy.remove_resource("💰", planting_cost, "planting_%s" % plant_type)

	# Set emoji pairs from capability
	plot.north_emoji = capability.emoji_pair.north
	plot.south_emoji = capability.emoji_pair.south
	plot.plot_type_name = plant_type

	# AUTO-EXPANSION: If biome doesn't support this emoji pair, expand its quantum system
	if plot_biome.has_method("supports_emoji_pair"):
		if not plot_biome.supports_emoji_pair(plot.north_emoji, plot.south_emoji):
			if plot_biome.has_method("expand_quantum_system"):
				var expand_result = plot_biome.expand_quantum_system(plot.north_emoji, plot.south_emoji)
				if not expand_result.success:
					push_error("❌ Failed to expand quantum system: %s" % expand_result.get("message", expand_result.error))
					return false
				if _verbose:
					_verbose.info("farm", "🔬", "Expanded %s quantum system to include %s/%s axis" % [
						plot_biome.get_biome_type(), plot.north_emoji, plot.south_emoji])

	# Special handling for tomato: assign conspiracy node
	if plant_type == "tomato":
		var node_ids = ["seed", "observer", "underground", "genetic", "ripening", "market",
						"sauce", "identity", "solar", "water", "meaning", "meta"]
		var node_index = total_plots_planted % node_ids.size()
		plot.conspiracy_node_id = node_ids[node_index]
		if _verbose:
			_verbose.info("farm", "🍅", "Planted tomato at %s connected to node: %s" % [plot.plot_id, plot.conspiracy_node_id])

	# Register plot in biome's quantum computer
	plot.register_in_biome(plot_biome)

	# Track register allocation in biome routing
	if "register_id" in plot and plot.register_id >= 0:
		_biome_routing.track_register_allocation(position, plot.register_id, plot_biome.quantum_computer)
	else:
		push_error("Plot %s planted but register_id not set!" % position)

	total_plots_planted += 1

	# Emit signals for visualization and biome updates
	plot_planted.emit(position)
	plot_changed.emit(position, "planted", {"plant_type": plant_type})
	visualization_changed.emit()

	# AUTO-ENTANGLE: If this plot has infrastructure entanglements, entangle quantum states
	if _entanglement:
		_entanglement.auto_entangle_from_infrastructure(position)

		# AUTO-APPLY PERSISTENT GATES: Apply any persistent gate infrastructure to new qubit
		_entanglement.auto_apply_persistent_gates(position)

	return true


func get_adjacent_wheat(position: Vector2i) -> Array:
	"""Get all wheat plots adjacent to a position (4-connected)

	Returns: Array of adjacent WheatPlot references
	"""
	var adjacent = []
	var directions = [
		Vector2i.UP,
		Vector2i.DOWN,
		Vector2i.LEFT,
		Vector2i.RIGHT
	]

	for direction in directions:
		var adj_pos = position + direction
		if _plot_manager.is_valid_position(adj_pos):
			var adj_plot = _plot_manager.get_plot(adj_pos)
			if adj_plot and adj_plot.is_planted and adj_plot.plot_type == FarmPlot.PlotType.WHEAT:
				adjacent.append(adj_plot)

	return adjacent
