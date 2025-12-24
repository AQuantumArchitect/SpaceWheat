class_name SaveDataAdapter

## SaveDataAdapter.gd
## Converts GameState (from saves) into UI-displayable data
##
## This is the clean interface between save/load system and visualizer
## Handles all the reconstruction logic so SaveLoadMenu stays simple

## Display data packet
class DisplayData:
	var biome_data: Dictionary  # Raw biome state from save
	var grid_data: Array  # Serialized plots
	var grid_width: int
	var grid_height: int
	var economy: Dictionary  # Resources to display
	var goals: Dictionary  # Goal state
	var icons: Dictionary  # Icon activation levels
	var timestamp: int
	var playtime: float

	func _init(gstate: GameState):
		biome_data = gstate.biome_state.duplicate(true)
		grid_data = gstate.plots.duplicate(true)
		grid_width = gstate.grid_width
		grid_height = gstate.grid_height

		# Economy snapshot
		economy = {
			"credits": gstate.credits,
			"wheat": gstate.wheat_inventory,
			"labor": gstate.labor_inventory,
			"flour": gstate.flour_inventory,
			"flower": gstate.flower_inventory,
			"mushroom": gstate.mushroom_inventory,
			"detritus": gstate.detritus_inventory,
			"imperium": gstate.imperium_resource,
			"tributes_paid": gstate.tributes_paid,
			"tributes_failed": gstate.tributes_failed
		}

		# Goals snapshot
		goals = {
			"current_index": gstate.current_goal_index,
			"completed": gstate.completed_goals.duplicate()
		}

		# Icons snapshot
		icons = {
			"biotic": gstate.biotic_activation,
			"chaos": gstate.chaos_activation,
			"imperium": gstate.imperium_activation
		}

		timestamp = gstate.save_timestamp
		playtime = gstate.game_time


## Convert GameState to display data
static func from_game_state(game_state: GameState) -> DisplayData:
	"""Convert a loaded GameState into UI display data"""
	if not game_state:
		push_error("SaveDataAdapter: Cannot convert null GameState")
		return null

	return DisplayData.new(game_state)


## Create Biome from saved state
static func create_biome_from_state(biome_state: Dictionary) -> Biome:
	"""Reconstruct a Biome instance from saved biome_state dictionary"""
	var biome = Biome.new()

	if not biome_state:
		print("⚠️  SaveDataAdapter: Empty biome state, creating fresh biome")
		biome._ready()
		return biome

	# Restore time
	if biome_state.has("time_elapsed"):
		biome.time_elapsed = biome_state["time_elapsed"]

	# Restore sun qubit
	if biome_state.has("sun_qubit") and biome_state["sun_qubit"]:
		var sq_data = biome_state["sun_qubit"]
		if biome.sun_qubit:
			biome.sun_qubit.theta = sq_data.get("theta", 0.0)
			biome.sun_qubit.phi = sq_data.get("phi", 0.0)
			biome.sun_qubit.radius = sq_data.get("radius", 1.0)
			biome.sun_qubit.energy = sq_data.get("energy", 1.0)

	# Restore wheat icon
	if biome_state.has("wheat_icon") and biome_state["wheat_icon"]:
		var wi_data = biome_state["wheat_icon"]
		if biome.wheat_icon and biome.wheat_icon.has("internal_qubit"):
			var iq = biome.wheat_icon["internal_qubit"]
			iq.theta = wi_data.get("theta", PI/12)
			iq.phi = wi_data.get("phi", 0.0)
			iq.radius = wi_data.get("radius", 1.0)
			iq.energy = wi_data.get("energy", 1.0)

	# Restore mushroom icon
	if biome_state.has("mushroom_icon") and biome_state["mushroom_icon"]:
		var mi_data = biome_state["mushroom_icon"]
		if biome.mushroom_icon and biome.mushroom_icon.has("internal_qubit"):
			var iq = biome.mushroom_icon["internal_qubit"]
			iq.theta = mi_data.get("theta", 11*PI/12)
			iq.phi = mi_data.get("phi", 0.0)
			iq.radius = mi_data.get("radius", 1.0)
			iq.energy = mi_data.get("energy", 1.0)

	# Restore emoji qubits (quantum states per plot)
	if biome_state.has("quantum_states") and biome_state["quantum_states"]:
		biome.quantum_states.clear()
		for qs_data in biome_state["quantum_states"]:
			if qs_data.has("position"):
				var pos = qs_data["position"]
				var qubit = DualEmojiQubit.new()
				qubit.theta = qs_data.get("theta", 0.0)
				qubit.phi = qs_data.get("phi", 0.0)
				qubit.radius = qs_data.get("radius", 1.0)
				qubit.energy = qs_data.get("energy", 1.0)
				biome.quantum_states[pos] = qubit

	print("✅ Biome reconstructed from saved state")
	return biome


## Create FarmGrid from saved plot data
static func create_grid_from_state(
	plots_array: Array,
	width: int,
	height: int,
	biome: Biome = null
) -> FarmGrid:
	"""Reconstruct a FarmGrid instance from saved plot states"""
	var grid = FarmGrid.new()
	grid.grid_width = width
	grid.grid_height = height

	# Initialize grid with empty cells if not already
	if grid.cells.is_empty():
		grid.cells = []
		for y in range(height):
			for x in range(width):
				var cell = {"type": 0, "planted": false, "measured": false, "entangled": []}
				grid.cells.append(cell)

	# Restore plot states from saved data
	for plot_data in plots_array:
		if not plot_data:
			continue

		var pos = plot_data.get("position", Vector2i(0, 0))
		if pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height:
			var idx = pos.y * width + pos.x
			if idx >= 0 and idx < grid.cells.size():
				grid.cells[idx] = {
					"type": plot_data.get("type", 0),
					"planted": plot_data.get("is_planted", false),
					"measured": plot_data.get("has_been_measured", false),
					"entangled": plot_data.get("entangled_with", [])
				}

	# Link biome if provided
	if biome:
		grid.biome = biome
		biome.grid = grid

	print("✅ FarmGrid reconstructed from saved state (%dx%d)" % [width, height])
	return grid


## Create display-ready data for visualizer
static func prepare_visualization(display_data: DisplayData) -> Dictionary:
	"""Prepare data specifically for the visualizer"""
	return {
		"biome_state": display_data.biome_data,
		"grid_width": display_data.grid_width,
		"grid_height": display_data.grid_height,
		"grid_data": display_data.grid_data,
		"timestamp": display_data.timestamp
	}


## Create display-ready data for info panels
static func prepare_display_info(display_data: DisplayData) -> Dictionary:
	"""Prepare data for UI info panels (resources, goals, etc)"""
	return {
		"economy": display_data.economy,
		"goals": display_data.goals,
		"icons": display_data.icons,
		"playtime": display_data.playtime,
		"timestamp": display_data.timestamp
	}
