class_name Farm
extends Node

## Farm - Pure simulation manager for quantum wheat farming
## Owns all game systems and handles all game logic
## Emits signals when state changes (no UI dependencies)

# System preloads
const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const GoalsSystem = preload("res://Core/GameMechanics/GoalsSystem.gd")
const Biome = preload("res://Core/Environment/Biome.gd")
const FarmUIState = preload("res://Core/GameState/FarmUIState.gd")
const VocabularyEvolution = preload("res://Core/QuantumSubstrate/VocabularyEvolution.gd")

# Core simulation systems
var grid: FarmGrid
var economy: FarmEconomy
var goals: GoalsSystem
var biome: Biome
var vocabulary_evolution: VocabularyEvolution  # Vocabulary evolution system
var ui_state: FarmUIState  # UI State abstraction layer

# Configuration
var grid_width: int = 6
var grid_height: int = 1
var use_neutral_biome: bool = false  # Use static NeutralBiome (no quantum evolution) for testing

# Biome availability (may fail to load if icon dependencies are missing)
var biome_enabled: bool = false

# Build configuration - all plantable/buildable types
const BUILD_CONFIGS = {
	"wheat": {
		"cost": {"wheat": 1},
		"type": "plant",
		"plant_type": "wheat",
		"north_emoji": "🌾",
		"south_emoji": "👥"
	},
	"tomato": {
		"cost": {"wheat": 1},
		"type": "plant",
		"plant_type": "tomato",
		"north_emoji": "🍅",
		"south_emoji": "🍝"
	},
	"mushroom": {
		"cost": {"wheat": 0, "labor": 1},
		"type": "plant",
		"plant_type": "mushroom",
		"north_emoji": "🍄",
		"south_emoji": "🍂"
	},
	"mill": {
		"cost": {"wheat": 10},
		"type": "build"
	},
	"market": {
		"cost": {"wheat": 10},
		"type": "build"
	}
}

# Signals - emitted when game state changes (no UI callbacks needed)
signal state_changed(state_data: Dictionary)
signal action_result(action: String, success: bool, message: String)
signal plot_planted(position: Vector2i, plant_type: String)
signal plot_harvested(position: Vector2i, yield_data: Dictionary)
signal plot_measured(position: Vector2i, outcome: String)
signal plots_entangled(pos1: Vector2i, pos2: Vector2i, bell_state: String)
signal economy_changed(state: Dictionary)


func _ready():
	print("🌾 Farm simulation manager initializing...")

	# Create core systems
	economy = FarmEconomy.new()
	add_child(economy)
	print("   💰 FarmEconomy created")

	# Create environmental simulation (Biome - optional, may fail if icon dependencies missing)
	biome = null
	biome_enabled = false

	# Try to create Biome
	var BiomeClass = preload("res://Core/Environment/Biome.gd")
	if BiomeClass:
		biome = BiomeClass.new()
		if biome:
			# Enable static mode if requested (no quantum evolution)
			if use_neutral_biome:
				biome.is_static = true
				print("   🌍 Biome created in static mode (no quantum evolution)")
			else:
				print("   🌍 Biome (environment) created")
			add_child(biome)
			# Manually call _ready() since Farm may not be in the scene tree
			biome._ready()
			biome_enabled = true
		else:
			print("   ⚠️  Biome creation failed - running in simple mode (no growth)")
	else:
		print("   ⚠️  Biome not available - running in simple mode (no growth)")

	# Create grid AFTER biome (or fallback)
	grid = FarmGrid.new()
	grid.grid_width = grid_width
	grid.grid_height = grid_height

	# Only inject biome if it was created successfully
	if biome_enabled and biome:
		grid.biome = biome  # Pass biome reference to grid
		biome.grid = grid  # Pass grid reference to biome (for phase constraints)

	add_child(grid)
	print("   📊 FarmGrid created (%dx%d)" % [grid_width, grid_height])

	# Register grid and biome as metadata for UI systems (QuantumForceGraph visualization)
	set_meta("grid", grid)
	if biome_enabled:
		set_meta("biome", biome)
	print("   📡 Farm metadata registered (grid + biome for visualization)")

	# Get persistent vocabulary evolution from GameStateManager
	# The vocabulary persists across farms/biomes and travels with the player
	var game_state_mgr = get_tree().root.get_child(0) if get_tree().root.get_child_count() > 0 else null
	if game_state_mgr and game_state_mgr.has_method("get_vocabulary_evolution"):
		vocabulary_evolution = game_state_mgr.get_vocabulary_evolution()
	else:
		# Fallback: create local vocabulary if GameStateManager not available
		# This happens in test/standalone scenarios
		var VocabularyEvolution = preload("res://Core/QuantumSubstrate/VocabularyEvolution.gd")
		vocabulary_evolution = VocabularyEvolution.new()
		vocabulary_evolution._ready()
		add_child(vocabulary_evolution)

	# Inject vocabulary reference into grid for tap validation
	if grid:
		grid.vocabulary_evolution = vocabulary_evolution

	print("   📚 Persistent VocabularyEvolution injected")

	goals = GoalsSystem.new()
	add_child(goals)
	print("   🎯 GoalsSystem created")

	# Create UI State abstraction layer (Phase 2 integration)
	ui_state = FarmUIState.new()
	print("   🎨 FarmUIState created")

	# Connect economy signals to both state_changed AND ui_state
	economy.wheat_changed.connect(_on_economy_changed)
	economy.wheat_changed.connect(_on_economy_changed_ui)
	economy.credits_changed.connect(_on_economy_changed)  # Classical currency
	economy.credits_changed.connect(_on_economy_changed_ui)  # Update UI
	economy.flour_changed.connect(_on_economy_changed)
	economy.flour_changed.connect(_on_economy_changed_ui)
	economy.flower_changed.connect(_on_economy_changed)
	economy.flower_changed.connect(_on_economy_changed_ui)
	economy.labor_changed.connect(_on_economy_changed)
	economy.labor_changed.connect(_on_economy_changed_ui)

	# NOTE: Removed grid signal connections (grid.plot_planted/harvested were dead code)
	# Farm.gd emits the real plot_planted/harvested signals directly

	# Connect Farm's own measurement signal to trigger UIState update
	# (measurement happens directly in Farm.measure_plot, not through grid signals)
	if has_signal("plot_measured"):
		plot_measured.connect(_on_plot_measured_ui)

	# Connect goal signals
	goals.goal_completed.connect(_on_goal_completed)

	# Populate UIState with initial farm state
	ui_state.refresh_all(self)

	print("✅ Farm simulation ready!")


## Public API - Game Operations

func build(pos: Vector2i, build_type: String) -> bool:
	"""Build/plant at position - unified method for all types

	Returns: true if successful, false if failed
	Emits: action_result signal with success/failure message
	"""
	# Validate build type
	if not BUILD_CONFIGS.has(build_type):
		action_result.emit("build", false, "Unknown build type: %s" % build_type)
		return false

	var config = BUILD_CONFIGS[build_type]
	var cost = config["cost"]

	# 1. PRE-VALIDATION: Check if we can build here
	var plot = grid.get_plot(pos)
	if not plot or plot.is_planted:
		action_result.emit("build_%s" % build_type, false, "Plot already occupied!")
		return false

	# 2. ECONOMY CHECK: Can we afford it?
	if not _can_afford_cost(cost):
		var missing = _get_missing_resources(cost)
		action_result.emit("build_%s" % build_type, false, "Cannot afford! Missing: %s" % missing)
		return false

	# 3. DEDUCT COST
	_spend_resources(cost, build_type)

	# 4. EXECUTE BUILD
	var success = false
	match config["type"]:
		"plant":
			# Request quantum state from Biome (or create local if no biome)
			var qubit = null
			if biome_enabled and biome:
				qubit = biome.create_quantum_state(pos, config["north_emoji"], config["south_emoji"])
			else:
				# No biome mode: create local quantum state that won't evolve
				const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
				qubit = DualEmojiQubit.new(config["north_emoji"], config["south_emoji"], PI/2)
				qubit.energy = 0.3  # Stays at minimum without biome evolution
				print("   ⚠️  Created local qubit (no biome) at %s" % pos)

			success = grid.plant(pos, config["plant_type"], qubit)
		"build":
			# Route to specific building
			match build_type:
				"mill":
					success = grid.place_mill(pos)
				"market":
					success = grid.place_market(pos)

	if success:
		plot_planted.emit(pos, build_type)
		_emit_state_changed()
		action_result.emit("build_%s" % build_type, true, "%s placed successfully!" % build_type.capitalize())
		return true
	else:
		# Refund if operation failed, and clean up quantum state if created
		if config["type"] == "plant" and biome_enabled and biome:
			biome.clear_qubit(pos)
		_refund_resources(cost)
		action_result.emit("build_%s" % build_type, false, "Failed to place %s" % build_type)
		return false


func measure_plot(pos: Vector2i) -> String:
	"""Measure (collapse) quantum state of plot at position

	Returns: outcome emoji (e.g., "🌾", "👥", "🍄", "🍂")
	Emits: plot_measured signal
	"""
	if not grid:
		return ""

	var outcome = grid.measure_plot(pos)

	# No biome mode: use random outcome for testing (no quantum evolution happened)
	if not outcome and not biome_enabled:
		outcome = "🌾" if randf() > 0.5 else "👥"
		print("   📊 No-biome mode: random outcome %s at %s" % [outcome, pos])

	plot_measured.emit(pos, outcome)
	_emit_state_changed()
	action_result.emit("measure", true, "Measured: %s collapsed!" % outcome)
	return outcome


func harvest_plot(pos: Vector2i) -> Dictionary:
	"""Harvest measured plot - collect yield

	Returns: Dictionary with {success: bool, outcome: String, yield: int}
	Emits: plot_harvested signal with yield data
	"""
	if not grid or not economy:
		return {"success": false}

	var plot = grid.get_plot(pos)
	if not plot or not plot.is_planted or not plot.has_been_measured:
		action_result.emit("harvest", false, "Plot not ready to harvest")
		return {"success": false}

	var harvest_data = grid.harvest_wheat(pos)

	if harvest_data.get("success", false):
		# Route resources based on outcome
		_process_harvest_outcome(harvest_data)
		plot_harvested.emit(pos, harvest_data)
		_emit_state_changed()

		var emoji = harvest_data.get("outcome", "?")
		action_result.emit("harvest", true, "Harvested %d %s!" % [harvest_data.get("yield", 0), emoji])
	else:
		action_result.emit("harvest", false, "Harvest failed")

	return harvest_data


func measure_all() -> int:
	"""Measure all planted but unmeasured plots

	Returns: number of plots measured
	"""
	var measured_count = 0

	for y in range(grid.grid_height):
		for x in range(grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = grid.get_plot(pos)

			if plot and plot.is_planted and not plot.has_been_measured:
				measure_plot(pos)
				measured_count += 1

	action_result.emit("measure_all", true, "Measured %d plots" % measured_count)
	return measured_count


func harvest_all() -> int:
	"""Harvest all measured plots

	Returns: number of plots harvested
	"""
	var harvested_count = 0

	for y in range(grid.grid_height):
		for x in range(grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = grid.get_plot(pos)

			if plot and plot.is_planted and plot.has_been_measured:
				var result = harvest_plot(pos)
				if result.get("success", false):
					harvested_count += 1

	action_result.emit("harvest_all", true, "Harvested %d plots" % harvested_count)
	return harvested_count


func entangle_plots(pos1: Vector2i, pos2: Vector2i, bell_state: String = "phi_plus") -> bool:
	"""Create entanglement between two plots with specified Bell state

	Args:
		pos1: Grid position of first plot
		pos2: Grid position of second plot
		bell_state: "phi_plus" (same correlation), "psi_plus" (opposite correlation)

	Returns:
		bool: True if successful, False if failed

	Emits: plots_entangled signal on success
	"""
	if not grid:
		action_result.emit("entangle", false, "Farm grid not initialized")
		return false

	# Verify both plots exist and are planted
	var plot1 = grid.get_plot(pos1)
	var plot2 = grid.get_plot(pos2)

	if not plot1 or not plot1.is_planted:
		action_result.emit("entangle", false, "First plot must be planted!")
		return false

	if not plot2 or not plot2.is_planted:
		action_result.emit("entangle", false, "Second plot must be planted!")
		return false

	# Create the entanglement in the grid
	var result = grid.create_entanglement(pos1, pos2, bell_state)

	if result:
		# Emit entanglement signal
		plots_entangled.emit(pos1, pos2, bell_state)
		_emit_state_changed()

		var state_name = "same correlation (Φ+)" if bell_state == "phi_plus" else "opposite correlation (Ψ+)"
		action_result.emit("entangle", true, "🔗 Entangled %s ↔ %s (%s)" % [pos1, pos2, state_name])
		return true
	else:
		action_result.emit("entangle", false, "Failed to create entanglement")
		return false


## Batch Operation Methods (NEW - Multi-Select Support)

func batch_plant(positions: Array[Vector2i], plant_type: String) -> Dictionary:
	"""Plant multiple plots with the given plant type

	Args:
		positions: Array of grid positions to plant
		plant_type: "wheat", "tomato", or "mushroom"

	Returns: Dictionary with {success: bool, count: int, message: String}
	"""
	var result = {
		"success": false,
		"count": 0,
		"message": ""
	}

	if positions.is_empty():
		result["message"] = "No positions specified"
		return result

	var success_count = 0
	for pos in positions:
		if build(pos, plant_type):
			success_count += 1

	result["success"] = success_count > 0
	result["count"] = success_count
	result["message"] = "Planted %d/%d plots" % [success_count, positions.size()]
	return result


func batch_measure(positions: Array[Vector2i]) -> Dictionary:
	"""Measure quantum state of multiple plots

	Args:
		positions: Array of grid positions to measure

	Returns: Dictionary with {success: bool, count: int}
	"""
	var result = {
		"success": false,
		"count": 0
	}

	if positions.is_empty():
		return result

	var success_count = 0
	for pos in positions:
		if measure_plot(pos):
			success_count += 1

	result["success"] = success_count > 0
	result["count"] = success_count
	return result


func batch_harvest(positions: Array[Vector2i]) -> Dictionary:
	"""Harvest multiple plots (measure then harvest each)

	Args:
		positions: Array of grid positions to harvest

	Returns: Dictionary with {success: bool, count: int, total_yield: int}
	"""
	var result = {
		"success": false,
		"count": 0,
		"total_yield": 0
	}

	if positions.is_empty():
		return result

	var success_count = 0
	var total_yield = 0

	for pos in positions:
		# Measure first if not already measured
		var plot = grid.get_plot(pos)
		if plot and plot.is_planted and not plot.has_been_measured:
			measure_plot(pos)

		# Then harvest
		var harvest_result = harvest_plot(pos)
		if harvest_result.get("success", false):
			success_count += 1
			total_yield += harvest_result.get("yield", 0)

	result["success"] = success_count > 0
	result["count"] = success_count
	result["total_yield"] = total_yield
	return result


func batch_build(positions: Array[Vector2i], build_type: String) -> Dictionary:
	"""Build structures (mill, market) on multiple plots

	Args:
		positions: Array of grid positions to build on
		build_type: "mill" or "market"

	Returns: Dictionary with {success: bool, count: int}
	"""
	var result = {
		"success": false,
		"count": 0
	}

	if positions.is_empty():
		return result

	var success_count = 0
	for pos in positions:
		if build(pos, build_type):
			success_count += 1

	result["success"] = success_count > 0
	result["count"] = success_count
	return result


func get_plot(position: Vector2i):
	"""Get plot at given grid position (returns WheatPlot)"""
	if grid:
		return grid.get_plot(position)
	return null


func get_state() -> Dictionary:
	"""Get complete game state snapshot for serialization"""
	if not grid or not economy or not goals:
		return {}

	var state = {
		"economy": {
			"wheat": economy.wheat_inventory,
			"flour": economy.flour_inventory,
			"flower": economy.flower_inventory,
			"labor": economy.labor_inventory,
		},
		"plots": []
	}

	# Collect all plot states
	for y in range(grid.grid_height):
		for x in range(grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = grid.get_plot(pos)
			if plot:
				state["plots"].append({
					"position": pos,
					"is_planted": plot.is_planted,
					"emoji": plot.get_emoji() if plot.is_planted else ""
				})

	return state


func apply_state(state: Dictionary) -> void:
	"""Apply complete game state from snapshot"""
	if not grid or not economy:
		return

	# Apply economy state
	if state.has("economy"):
		var eco = state["economy"]
		economy.wheat_inventory = eco.get("wheat", 100)
		economy.flour_inventory = eco.get("flour", 0)
		economy.flower_inventory = eco.get("flower", 0)
		economy.labor_inventory = eco.get("labor", 0)

		# Emit signals so UI updates
		economy.wheat_changed.emit(economy.wheat_inventory)
		economy.flour_changed.emit(economy.flour_inventory)
		economy.flower_changed.emit(economy.flower_inventory)
		economy.labor_changed.emit(economy.labor_inventory)

	# Apply plot states
	if state.has("plots"):
		for plot_state in state["plots"]:
			var pos = plot_state.get("position")
			var plot = grid.get_plot(pos)
			if plot and plot_state.get("is_planted", false):
				# Recreate wheat at this position
				plot.plant()

	_emit_state_changed()


## GameState Integration - Clean Architecture Methods

func apply_game_state(state: Resource) -> void:
	"""Load a GameState into the simulation (clean architecture pattern)

	Args:
		state: GameState resource with all persistent game data

	Sets up the entire simulation from saved state:
	- Economy: wheat inventory (primary currency)
	- Plots: planted state, measurement state, quantum properties
	- Environment: sun/moon phase
	"""
	if not state:
		push_error("Cannot apply null game state")
		return

	if not (grid and economy and biome):
		push_error("Farm systems not initialized")
		return

	# Apply economy
	economy.wheat_inventory = state.get("wheat_inventory") if state.has("wheat_inventory") else 100
	economy.flour_inventory = state.get("flour_inventory") if state.has("flour_inventory") else 0

	# Emit economy change signals so UI updates
	economy.wheat_changed.emit(economy.wheat_inventory)
	economy.flour_changed.emit(economy.flour_inventory)

	# Apply plots
	var plots_array = state.get("plots") if state.has("plots") else []
	for plot_data in plots_array:
		var pos = plot_data.get("position") if plot_data.has("position") else Vector2i.ZERO
		var plot = grid.get_plot(pos)

		if plot:
			plot.is_planted = plot_data.get("is_planted") if plot_data.has("is_planted") else false
			plot.has_been_measured = plot_data.get("has_been_measured") if plot_data.has("has_been_measured") else false
			plot.theta_frozen = plot_data.get("theta_frozen") if plot_data.has("theta_frozen") else false

			# Regenerate quantum state if planted
			if plot.is_planted and not biome.quantum_states.has(pos):
				var qubit = biome.create_quantum_state(pos, "🌾", "🌱", PI/2)

	# Apply environment (sun & icons)
	if biome.sun_qubit:
		biome.sun_qubit.theta = state.get("sun_theta") if state.has("sun_theta") else 0.0
		biome.sun_qubit.phi = state.get("sun_phi") if state.has("sun_phi") else 0.0
	if biome.wheat_icon:
		biome.wheat_icon.theta = state.get("wheat_icon_theta") if state.has("wheat_icon_theta") else PI/12

	_emit_state_changed()


func capture_game_state(state: Resource) -> Resource:
	"""Save current simulation state to a GameState (clean architecture pattern)

	Args:
		state: GameState resource to update with current simulation state

	Captures:
	- Economy: current wheat inventory (primary currency)
	- Plots: current planted/measured/entangled states for all plots
	- Environment: current sun/moon phase

	Returns: The updated GameState resource
	"""
	if not state:
		push_error("Cannot capture to null game state")
		return state

	if not (grid and economy and biome):
		push_error("Farm systems not initialized")
		return state

	# Capture economy
	state["wheat_inventory"] = economy.wheat_inventory
	state["flour_inventory"] = economy.flour_inventory

	# Capture plots
	var plots_array = []
	for y in range(grid_height):
		for x in range(grid_width):
			var pos = Vector2i(x, y)
			var plot = grid.get_plot(pos)

			if plot:
				plots_array.append({
					"position": pos,
					"type": 0,
					"is_planted": plot.is_planted,
					"has_been_measured": plot.has_been_measured,
					"theta_frozen": plot.theta_frozen,
					"entangled_with": []
				})

	state["plots"] = plots_array

	# Capture environment (sun & icons)
	if biome.sun_qubit:
		state["sun_theta"] = biome.sun_qubit.theta
		state["sun_phi"] = biome.sun_qubit.phi
	if biome.wheat_icon:
		state["wheat_icon_theta"] = biome.wheat_icon.theta

	return state


## Private Helpers - Resource & Economy Management

func _can_afford_cost(cost: Dictionary) -> bool:
	"""Check if player can afford given resource cost"""
	for resource in cost.keys():
		var amount = cost[resource]
		if amount <= 0:
			continue

		match resource:
			"wheat":
				if not economy.can_afford_wheat(amount):
					return false
			"labor":
				if economy.labor_inventory < amount:
					return false
			"flour":
				if economy.flour_inventory < amount:
					return false

	return true


func _get_missing_resources(cost: Dictionary) -> String:
	"""Get human-readable list of missing resources"""
	var missing = []

	for resource in cost.keys():
		var amount = cost[resource]
		if amount <= 0:
			continue

		var have = 0
		match resource:
			"wheat":
				have = economy.wheat_inventory
			"labor":
				have = economy.labor_inventory
			"flour":
				have = economy.flour_inventory

		if have < amount:
			missing.append("%d more %s" % [amount - have, resource])

	return ", ".join(missing)


func _spend_resources(cost: Dictionary, action: String) -> void:
	"""Deduct resources from economy"""
	for resource in cost.keys():
		var amount = cost[resource]
		if amount <= 0:
			continue

		match resource:
			"wheat":
				economy.spend_wheat(amount, action)
			"labor":
				economy.remove_labor(amount)
			"flour":
				economy.remove_flour(amount)


func _refund_resources(cost: Dictionary) -> void:
	"""Return resources to player (failed operation)"""
	for resource in cost.keys():
		var amount = cost[resource]
		if amount <= 0:
			continue

		match resource:
			"wheat":
				economy.add_wheat(amount)
			"labor":
				economy.add_labor(amount)
			"flour":
				economy.add_flour(amount)


func _process_harvest_outcome(harvest_data: Dictionary) -> void:
	"""Route harvested resources to economy based on outcome"""
	var outcome = harvest_data.get("outcome", "")
	var yield_amount = harvest_data.get("yield", 1)

	match outcome:
		"wheat":
			economy.earn_wheat(yield_amount, "wheat_harvest")
			goals.record_harvest(yield_amount)
		"labor":
			economy.add_labor(yield_amount)
		"mushroom":
			economy.add_mushroom(yield_amount)
		"detritus":
			economy.add_detritus(yield_amount)
		"tomato":
			economy.earn_wheat(yield_amount * 2, "tomato_harvest")
		"sauce":
			economy.earn_wheat(yield_amount * 3, "sauce_harvest")


func _emit_state_changed() -> void:
	"""Emit state_changed signal with current game state"""
	state_changed.emit(get_state())


func _on_economy_changed(_value) -> void:
	"""Handle economy signal"""
	_emit_state_changed()


func _on_goal_completed(_goal) -> void:
	"""Handle goal completion"""
	_emit_state_changed()


## UI State Integration (Phase 2)

func _on_economy_changed_ui(_value = null) -> void:
	"""Handle economy changes - update UIState"""
	if ui_state:
		ui_state.update_economy(economy)


func _on_plot_measured_ui(position: Vector2i, outcome: String) -> void:
	"""Handle measurement - update UIState with measured outcome"""
	if ui_state and grid:
		var plot = grid.get_plot(position)
		if plot:
			ui_state.update_plot(position, plot)


func _on_plot_changed_ui(position: Vector2i, _data = null) -> void:
	"""Handle plot changes - update UIState"""
	if ui_state and grid:
		var plot = grid.get_plot(position)
		if plot:
			ui_state.update_plot(position, plot)
