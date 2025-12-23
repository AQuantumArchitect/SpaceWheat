class_name GameController
extends Node

## Central controller for all game actions
## Coordinates between farm grid, economy, goals, and UI

# References to game systems (set by FarmView)
# Note: Using untyped vars to avoid circular dependencies
var farm_grid
var economy
var goals
var conspiracy_network
var faction_manager
var visual_effects
var quantum_graph
var vocabulary_evolution

# UI callbacks (set by FarmView)
var on_ui_update: Callable
var on_goal_update: Callable
var on_icon_update: Callable
var on_contract_check: Callable
var get_tile_callback: Callable

# Signals for UI feedback
signal action_feedback(message: String, success: bool)
signal visual_effect_requested(effect_type: String, position: Vector2, data: Dictionary)

# Build configuration - defines all plantable and buildable types
const BUILD_CONFIGS = {
	"wheat": {
		"cost": {"credits": 5},
		"farm_method": "plant_wheat",
		"visual_color": Color(0.4, 0.9, 0.4),
		"success_message": "Planted wheat!",
		"failure_message": "Cannot plant wheat here",
		"updates_quantum_graph": true
	},
	"tomato": {
		"cost": {"credits": 5},
		"farm_method": "plant_tomato",
		"visual_color": Color(0.9, 0.2, 0.2),
		"success_message": "Planted tomato!",
		"failure_message": "Cannot plant tomato here",
		"updates_quantum_graph": false
	},
	"mushroom": {
		"cost": {"credits": 0, "labor": 1},
		"farm_method": "plant_mushroom",
		"visual_color": Color(0.6, 0.3, 0.8),
		"success_message": "Planted mushroom!",
		"failure_message": "Cannot plant mushroom here (need 1 👥)",
		"updates_quantum_graph": false
	},
	"mill": {
		"cost": {"credits": 10},
		"farm_method": "place_mill",
		"visual_color": Color(0.8, 0.6, 0.4),
		"success_message": "🏭 Mill placed! Converts wheat → flour",
		"failure_message": "Plot must be empty to place mill!",
		"updates_quantum_graph": false
	},
	"market": {
		"cost": {"credits": 10},
		"farm_method": "place_market",
		"visual_color": Color(1.0, 0.85, 0.2),
		"success_message": "💰 Market placed! Sells flour → credits",
		"failure_message": "Plot must be empty to place market!",
		"updates_quantum_graph": false
	}
}


func _ready():
	print("🎮 GameController initialized")


## Public API - Game Actions

func build(pos: Vector2i, build_type: String) -> bool:
	"""Unified build/plant method - handles all types

	Args:
		pos: Grid position to build at
		build_type: Type identifier ("wheat", "tomato", "mushroom", "mill", "market")

	Returns:
		bool: True if successful, False if failed
	"""
	# 1. Validate build type exists
	if not BUILD_CONFIGS.has(build_type):
		push_error("Unknown build type: %s" % build_type)
		return false

	var config = BUILD_CONFIGS[build_type]

	# 2. PRE-VALIDATION: Check if building is possible BEFORE spending money
	var plot = farm_grid.get_plot(pos)
	if plot == null or plot.is_planted:
		action_feedback.emit(config["failure_message"], false)
		return false

	# 3. ECONOMY CHECK: Only deduct costs if we passed validation
	var costs = config["cost"]

	# Check if player can afford all required resources
	for resource in costs.keys():
		var amount = costs[resource]
		if amount <= 0:
			continue

		match resource:
			"credits":
				if not economy.can_afford(amount):
					action_feedback.emit("Not enough credits! (need %d 💰)" % amount, false)
					return false
			"labor":
				if economy.labor_inventory < amount:
					action_feedback.emit("Not enough labor! (need %d 👥)" % amount, false)
					return false
			"flour":
				if economy.flour_inventory < amount:
					action_feedback.emit("Not enough flour! (need %d 💨)" % amount, false)
					return false
			"wheat":
				if economy.wheat_inventory < amount:
					action_feedback.emit("Not enough wheat! (need %d 🌾)" % amount, false)
					return false

	# Deduct all resources (only if ALL affordability checks passed)
	for resource in costs.keys():
		var amount = costs[resource]
		if amount <= 0:
			continue

		match resource:
			"credits":
				economy.spend_credits(amount, build_type)
			"labor":
				economy.remove_labor(amount)
			"flour":
				economy.remove_flour(amount)
			"wheat":
				economy.remove_wheat(amount)

	# 4. FARM OPERATION: Call appropriate farm_grid method
	var success = false
	match config["farm_method"]:
		"plant_wheat":
			success = farm_grid.plant_wheat(pos)
		"plant_tomato":
			success = farm_grid.plant_tomato(pos, conspiracy_network)
		"plant_mushroom":
			success = farm_grid.plant_mushroom(pos)
		"place_mill":
			success = farm_grid.place_mill(pos)
		"place_market":
			success = farm_grid.place_market(pos)

	# 5. Handle failure (shouldn't happen after validation, but safety check)
	if not success:
		# Refund resources if we charged
		for resource in costs.keys():
			var amount = costs[resource]
			if amount <= 0:
				continue
			match resource:
				"credits":
					economy.earn_credits(amount, "refund")
				"labor":
					economy.add_labor(amount)
				"flour":
					economy.add_flour(amount)
				"wheat":
					economy.add_wheat(amount)
		action_feedback.emit(config["failure_message"], false)
		return false

	# 6. POST-PROCESSING: Visual effects and feedback
	if get_tile_callback.is_valid():
		var tile = get_tile_callback.call(pos)
		if tile:
			var effect_pos = tile.global_position + tile.size / 2
			visual_effect_requested.emit("plant", effect_pos, {"color": config["visual_color"]})

	# 7. Quantum graph update (only for wheat)
	if config["updates_quantum_graph"] and quantum_graph:
		quantum_graph.print_snapshot("%s at %s" % [build_type.capitalize(), pos])

	# 8. Trigger UI updates
	_trigger_updates()

	# 9. Success feedback
	action_feedback.emit(config["success_message"], true)

	return true


func measure_plot(pos: Vector2i) -> String:
	"""Measure plot (collapse quantum state)"""
	var result = farm_grid.measure_plot(pos)

	# Emit visual effect request
	if get_tile_callback.is_valid():
		var tile = get_tile_callback.call(pos)
		if tile:
			var effect_pos = tile.global_position + tile.size / 2
			visual_effect_requested.emit("measure", effect_pos, {"color": Color(0.7, 0.3, 1.0)})

	action_feedback.emit("⚛️ Measured: %s collapsed!" % result, true)
	print("👁️ Measured at %s -> %s" % [pos, result])

	_trigger_updates()
	return result


func harvest_plot(pos: Vector2i) -> Dictionary:
	"""Harvest single plot"""
	var harvest_data = farm_grid.harvest_wheat(pos)

	if harvest_data["success"]:
		# Record harvest based on outcome type
		var outcome = harvest_data.get("outcome", "wheat")
		var yield_amount = harvest_data["yield"]
		var emoji = ""

		match outcome:
			"wheat":
				# Wheat plot measured as 🌾
				emoji = "🌾"
				economy.record_harvest(yield_amount)
				goals.record_harvest(yield_amount)
				economy.add_emoji_resource(emoji, yield_amount)
				action_feedback.emit("✂️ Harvested %d %s!" % [yield_amount, emoji], true)
				print("✂️ Harvested at %s: %d %s" % [pos, yield_amount, emoji])
			"labor":
				# Wheat plot measured as 👥 - add to labor inventory
				emoji = "👥"
				economy.add_labor(yield_amount)
				economy.add_emoji_resource(emoji, yield_amount)
				action_feedback.emit("✂️ Harvested %d %s!" % [yield_amount, emoji], true)
				print("✂️ Harvested at %s: %d %s" % [pos, yield_amount, emoji])
			"mushroom":
				# Mushroom plot measured as 🍄
				emoji = "🍄"
				economy.add_mushroom(yield_amount)
				economy.add_emoji_resource(emoji, yield_amount)
				action_feedback.emit("✂️ Harvested %d %s!" % [yield_amount, emoji], true)
				print("✂️ Harvested at %s: %d %s" % [pos, yield_amount, emoji])
			"detritus":
				# Mushroom plot measured as 🍂 (compost)
				emoji = "🍂"
				economy.add_detritus(yield_amount)
				economy.add_emoji_resource(emoji, yield_amount)
				action_feedback.emit("✂️ Harvested %d %s!" % [yield_amount, emoji], true)
				print("✂️ Harvested at %s: %d %s" % [pos, yield_amount, emoji])
			"tomato":
				# Tomato plot measured as 🍅
				emoji = "🍅"
				economy.add_emoji_resource(emoji, yield_amount)
				economy.earn_credits(yield_amount * 2, "tomato_sale")  # Tomatoes worth 2 credits each
				action_feedback.emit("✂️ Harvested %d %s!" % [yield_amount, emoji], true)
				print("✂️ Harvested at %s: %d %s" % [pos, yield_amount, emoji])
			"sauce":
				# Tomato plot measured as 🍝 (sauce)
				emoji = "🍝"
				economy.add_emoji_resource(emoji, yield_amount)
				economy.earn_credits(yield_amount * 3, "sauce_sale")  # Sauce worth 3 credits each
				action_feedback.emit("✂️ Harvested %d %s!" % [yield_amount, emoji], true)
				print("✂️ Harvested at %s: %d %s" % [pos, yield_amount, emoji])

		# Check contracts
		if on_contract_check.is_valid():
			on_contract_check.call()

		# Emit visual effect request
		if get_tile_callback.is_valid():
			var tile = get_tile_callback.call(pos)
			if tile:
				var effect_pos = tile.global_position + tile.size / 2
				visual_effect_requested.emit("harvest", effect_pos, {"color": Color(1.0, 0.9, 0.3)})

		_trigger_updates()
		if on_goal_update.is_valid():
			on_goal_update.call()
		if on_icon_update.is_valid():
			on_icon_update.call()

	return harvest_data


func harvest_all() -> Dictionary:
	"""Harvest all measured mature plots"""
	var total_harvested = 0
	var harvest_count = 0

	# Iterate through all plots
	var grid_size = farm_grid.grid_width
	for y in range(grid_size):
		for x in range(grid_size):
			var pos = Vector2i(x, y)
			var plot = farm_grid.get_plot(pos)

			# Harvest if planted AND measured (quantum-only mechanics)
			if plot and plot.is_planted and plot.has_been_measured:
				var harvest_data = farm_grid.harvest_wheat(pos)
				if harvest_data["success"]:
					harvest_count += 1
					total_harvested += harvest_data["yield"]

					# Record each harvest
					economy.record_harvest(harvest_data["yield"])
					goals.record_harvest(harvest_data["yield"])

					# Emit visual effect request
					if get_tile_callback.is_valid():
						var tile = get_tile_callback.call(pos)
						if tile:
							var effect_pos = tile.global_position + tile.size / 2
							visual_effect_requested.emit("harvest", effect_pos, {"color": Color(1.0, 0.9, 0.3)})

	if harvest_count > 0:
		# Check contracts
		if on_contract_check.is_valid():
			on_contract_check.call()

		action_feedback.emit("✂️ Harvested %d plots → %d wheat!" % [harvest_count, total_harvested], true)
		print("✂️ Field harvest: %d plots → %d total wheat" % [harvest_count, total_harvested])

		_trigger_updates()
		if on_goal_update.is_valid():
			on_goal_update.call()
		if on_icon_update.is_valid():
			on_icon_update.call()
	else:
		action_feedback.emit("⚠️ No measured plots to harvest!", false)

	return {"harvest_count": harvest_count, "total_harvested": total_harvested}


func entangle_plots(pos1: Vector2i, pos2: Vector2i, bell_state: String = "phi_plus") -> bool:
	"""Create entanglement between two plots with specified Bell state

	Args:
		pos1: Grid position of first plot
		pos2: Grid position of second plot
		bell_state: "phi_plus" (same correlation), "psi_plus" (opposite), etc.
	"""
	var result = farm_grid.create_entanglement(pos1, pos2, bell_state)

	if result:
		var state_name = "same correlation" if bell_state == "phi_plus" else "opposite correlation"
		if quantum_graph:
			quantum_graph.print_snapshot("Entangled %s ↔ %s (%s)" % [pos1, pos2, state_name])
		action_feedback.emit("🔗 Entangled %s ↔ %s (%s)" % [pos1, pos2, state_name], true)
		_trigger_updates()
	else:
		action_feedback.emit("⚠️ Cannot entangle - both plots must be planted!", false)

	return result


func sell_all_wheat() -> Dictionary:
	"""Sell all wheat inventory"""
	var wheat_amount = economy.wheat_inventory
	if wheat_amount == 0:
		action_feedback.emit("⚠️ No wheat to sell!", false)
		return {"sold": 0, "credits": 0}

	var credits_earned = economy.sell_wheat(wheat_amount)
	action_feedback.emit("💰 Sold %d wheat → +%d credits!" % [wheat_amount, credits_earned], true)
	print("💰 Wheat sold: %d → %d credits" % [wheat_amount, credits_earned])

	_trigger_updates()
	return {"sold": wheat_amount, "credits": credits_earned}


## Helper Functions

func _trigger_updates():
	"""Trigger all UI update callbacks"""
	if on_ui_update.is_valid():
		on_ui_update.call()


func check_plot_harvestable(grid_size: int) -> bool:
	"""Check if any plot is ready to harvest (must be planted and measured)"""
	for y in range(grid_size):
		for x in range(grid_size):
			var pos = Vector2i(x, y)
			var plot = farm_grid.get_plot(pos)
			if plot and plot.is_planted and plot.has_been_measured:
				return true
	return false
