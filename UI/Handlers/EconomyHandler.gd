class_name EconomyHandler
extends RefCounted

## EconomyHandler - Static handler for economy/farming operations
##
## Follows ProbeActions pattern:
## - Static methods only
## - Explicit parameters (no implicit state)
## - Dictionary returns with {success: bool, ...data, error?: String}


## ============================================================================
## PLANTING OPERATIONS
## ============================================================================

static func batch_plant(farm, plant_type: String, positions: Array[Vector2i]) -> Dictionary:
	"""Batch plant crops of specified type.

	Supports: wheat, mushroom, fire, water, flour, vegetation, rabbit, wolf, etc.
	"""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var planted_count = 0
	var results: Array = []

	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if not plot:
			continue

		# Skip already planted plots
		if plot.is_planted:
			continue

		# Get emoji pair for plant type
		var emoji_pair = _get_emoji_pair_for_type(farm, pos, plant_type)
		if emoji_pair.is_empty():
			continue

		# Plant the plot
		plot.is_planted = true
		plot.north_emoji = emoji_pair.get("north", "")
		plot.south_emoji = emoji_pair.get("south", "")

		planted_count += 1
		results.append({
			"position": pos,
			"north": plot.north_emoji,
			"south": plot.south_emoji
		})

	return {
		"success": planted_count > 0,
		"plant_type": plant_type,
		"planted_count": planted_count,
		"results": results
	}


static func plant_batch_context_aware(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Context-aware batch planting based on biome type.

	Automatically selects appropriate crop for biome.
	"""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	# Detect biome from first selected plot
	var first_pos = positions[0]
	var biome_name = farm.grid.plot_biome_assignments.get(first_pos, "")

	var plant_type = "wheat"  # Default

	match biome_name:
		"VolcanicWorlds":
			plant_type = "crystal"
		"BioticFlux":
			plant_type = "wheat"
		"FungalNetworks":
			plant_type = "mushroom"
		"StellarForges":
			plant_type = "rocket"
		_:
			plant_type = "wheat"

	return batch_plant(farm, plant_type, positions)


## ============================================================================
## BUILDING OPERATIONS
## ============================================================================

static func batch_build(farm, build_type: String, positions: Array[Vector2i]) -> Dictionary:
	"""Batch build structures of specified type.

	Supports: mill, market, kitchen
	"""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var built_count = 0
	var results: Array = []

	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if not plot:
			continue

		# Place building on plot
		var success = false
		if farm.grid.has_method("place_building"):
			success = farm.grid.place_building(pos, build_type)
		elif plot.has_method("set_building"):
			success = plot.set_building(build_type)

		if success:
			built_count += 1
			results.append({
				"position": pos,
				"building_type": build_type
			})

	return {
		"success": built_count > 0,
		"build_type": build_type,
		"built_count": built_count,
		"results": results
	}


static func place_kitchen(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Place kitchen building at selected positions.

	Kitchen enables bread baking from flour.
	"""
	return batch_build(farm, "kitchen", positions)


## ============================================================================
## MILL OPERATIONS
## ============================================================================

static func mill_select_power(farm, power_key: String, positions: Array[Vector2i]) -> Dictionary:
	"""First stage of mill operation: select power source.

	Power sources: Q=water, E=wind, R=fire
	Returns info needed for second stage (conversion selection).
	"""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	# Map power key to power type
	var power_map = {
		"Q": "water",
		"E": "wind",
		"R": "fire"
	}

	var power_type = power_map.get(power_key, "")
	if power_type == "":
		return {
			"success": false,
			"error": "invalid_power_key",
			"message": "Invalid power key: %s" % power_key
		}

	# Check if power source is available
	var has_power = false
	if farm.economy:
		has_power = farm.economy.has_resource(power_type, 1)

	return {
		"success": true,
		"power_key": power_key,
		"power_type": power_type,
		"has_power": has_power,
		"stage": 1,
		"next_stage": "select_conversion"
	}


static func mill_convert(farm, conversion_key: String, power_type: String, positions: Array[Vector2i]) -> Dictionary:
	"""Second stage of mill operation: convert resource.

	Conversions: Q=flour (from wheat), E=lumber (from wood), R=energy
	"""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	# Map conversion key to output type
	var conversion_map = {
		"Q": {"output": "flour", "input": "wheat"},
		"E": {"output": "lumber", "input": "wood"},
		"R": {"output": "energy", "input": "fuel"}
	}

	var conversion = conversion_map.get(conversion_key, {})
	if conversion.is_empty():
		return {
			"success": false,
			"error": "invalid_conversion",
			"message": "Invalid conversion key: %s" % conversion_key
		}

	var output_type = conversion.output
	var input_type = conversion.input

	# Check resources and perform conversion
	var converted_count = 0

	if farm.economy:
		# Check if we have power and input
		var has_power = farm.economy.has_resource(power_type, 1)
		var has_input = farm.economy.has_resource(input_type, positions.size())

		if has_power and has_input:
			# Consume power (1 unit for entire batch)
			farm.economy.consume_resource(power_type, 1)

			# Convert each position's worth
			for pos in positions:
				if farm.economy.consume_resource(input_type, 1):
					farm.economy.add_resource(output_type, 1, "mill")
					converted_count += 1

	return {
		"success": converted_count > 0,
		"power_type": power_type,
		"input_type": input_type,
		"output_type": output_type,
		"converted_count": converted_count
	}


## ============================================================================
## PRODUCTION OPERATIONS
## ============================================================================

static func harvest_flour(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Harvest flour from mill at selected positions."""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var harvested_count = 0
	var total_flour = 0

	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if not plot:
			continue

		# Check if plot has mill with flour
		if plot.has_method("harvest_flour"):
			var flour = plot.harvest_flour()
			if flour > 0:
				harvested_count += 1
				total_flour += flour

				if farm.economy:
					farm.economy.add_resource("flour", flour, "mill_harvest")

	return {
		"success": harvested_count > 0,
		"harvested_count": harvested_count,
		"total_flour": total_flour
	}


static func market_sell(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Sell resources at market."""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var sold_count = 0
	var total_credits = 0

	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if not plot:
			continue

		# Check if plot has market
		if plot.has_method("sell_at_market"):
			var credits = plot.sell_at_market(farm.economy)
			if credits > 0:
				sold_count += 1
				total_credits += credits

	return {
		"success": sold_count > 0,
		"sold_count": sold_count,
		"total_credits": total_credits
	}


static func bake_bread(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Bake bread at kitchen using flour."""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.is_empty():
		return {
			"success": false,
			"error": "no_positions",
			"message": "No plots selected"
		}

	var baked_count = 0

	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if not plot:
			continue

		# Check if plot has kitchen
		if plot.has_method("bake_bread"):
			if plot.bake_bread(farm.economy):
				baked_count += 1

	return {
		"success": baked_count > 0,
		"baked_count": baked_count
	}


# NOTE: place_energy_tap removed (2026-01) - energy tap system deprecated


## ============================================================================
## HELPER METHODS
## ============================================================================

static func _get_emoji_pair_for_type(farm, pos: Vector2i, plant_type: String) -> Dictionary:
	"""Get emoji pair for a given plant type."""
	# Check biome for default pairs
	var biome = farm.grid.get_biome_for_plot(pos) if farm.grid else null

	# Common plant type mappings
	var type_map = {
		"wheat": {"north": "bread", "south": "mushroom"},
		"mushroom": {"north": "mushroom", "south": "ghost"},
		"fire": {"north": "fire", "south": "ice"},
		"water": {"north": "water", "south": "fire"},
		"flour": {"north": "flour", "south": "wheat"},
		"vegetation": {"north": "tree", "south": "stump"},
		"rabbit": {"north": "rabbit", "south": "skull"},
		"wolf": {"north": "wolf", "south": "rabbit"},
		"crystal": {"north": "crystal", "south": "rock"},
		"rocket": {"north": "rocket", "south": "explosion"},
		"bread": {"north": "bread", "south": "crumb"}
	}

	if type_map.has(plant_type):
		return type_map[plant_type]

	# Fallback to biome defaults
	if biome and biome.producible_emojis.size() >= 2:
		return {
			"north": biome.producible_emojis[0],
			"south": biome.producible_emojis[1]
		}

	return {}
