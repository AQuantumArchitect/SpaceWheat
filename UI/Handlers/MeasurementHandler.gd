class_name MeasurementHandler
extends RefCounted

## MeasurementHandler - Static handler for measurement-related operations
##
## Follows ProbeActions pattern:
## - Static methods only
## - Explicit parameters (no implicit state)
## - Dictionary returns with {success: bool, ...data, error?: String}
##
## Note: Core EXPLORE/MEASURE/POP operations are in ProbeActions.gd
## This handler focuses on supplementary measurement operations.


## ============================================================================
## MEASUREMENT TRIGGER OPERATIONS
## ============================================================================

static func measure_trigger(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Build measure trigger for controlled collapse.

	Creates conditional measurement infrastructure.
	First plot in selection is trigger, remaining are targets.
	"""
	if not farm or not farm.grid:
		return {
			"success": false,
			"error": "farm_not_ready",
			"message": "Farm not loaded"
		}

	if positions.size() < 2:
		return {
			"success": false,
			"error": "need_trigger_and_target",
			"message": "Need trigger plot and at least one target"
		}

	var trigger_pos = positions[0]
	var target_positions = positions.slice(1)

	var biome = farm.grid.get_biome_for_plot(trigger_pos)
	if not biome:
		return {
			"success": false,
			"error": "no_biome",
			"message": "Could not access biome"
		}

	# Get trigger plot info
	var trigger_plot = farm.grid.get_plot(trigger_pos)
	if not trigger_plot or not trigger_plot.is_active():
		return {
			"success": false,
			"error": "invalid_trigger",
			"message": "Trigger plot not planted"
		}

	var trigger_emoji = trigger_plot.north_emoji

	# Set up measurement trigger
	var success = false
	if biome.has_method("set_measurement_trigger"):
		success = biome.set_measurement_trigger(trigger_emoji, target_positions)

	if not success:
		return {
			"success": false,
			"error": "trigger_setup_failed",
			"message": "Failed to set measurement trigger"
		}

	return {
		"success": true,
		"trigger_position": trigger_pos,
		"trigger_emoji": trigger_emoji,
		"target_count": target_positions.size()
	}


## ============================================================================
## REMOVE GATES OPERATION
## ============================================================================

static func remove_gates(farm, positions: Array[Vector2i]) -> Dictionary:
	"""Remove gate infrastructure from selected plots.

	Clears any persistent gate configurations.
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

	var removed_count = 0

	for pos in positions:
		var biome = farm.grid.get_biome_for_plot(pos)
		if not biome:
			continue

		# Clear gate infrastructure if supported
		if biome.has_method("clear_gate_at_position"):
			if biome.clear_gate_at_position(pos):
				removed_count += 1
		elif biome.has_method("remove_gate_infrastructure"):
			if biome.remove_gate_infrastructure(pos):
				removed_count += 1

	return {
		"success": removed_count > 0,
		"removed_count": removed_count,
		"total_positions": positions.size()
	}
