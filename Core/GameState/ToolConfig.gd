extends RefCounted

## ToolConfig - Time Scale Ratchet Tool Architecture
##
## Tool groups organized by temporal granularity:
##
## | Group | Time Scale   | Physics     | Character                                |
## |-------|--------------|-------------|------------------------------------------|
## | 1     | Continuous   | Unitary     | Smooth, reversible quantum gates         |
## | 2     | Dissipative  | Lindbladian | Energy exchange, "vampire" in/out        |
## | 3     | Discrete     | Measurement | Collapse, harvest, build gates           |
## | [4]   | Meta         | System      | Vocabulary and biome add/remove via F-cycle |
##
## Key Layout:
##   1 2 3 [4]  = Tool group selection (time scale ratchet)
##   Q E R      = Action keys (DOWN, NEUTRAL, UP)
##   F          = Mode cycling (all groups), or current meta mode cycle button
##
## Direction Philosophy:
##   Q = DOWN  (dig into, bind, construct)
##   E = NEUTRAL (observe, balance, transfer)
##   R = UP    (extract, harvest, remove)

## Current tool group (1-4) - Default to Measure (3) for main gameplay loop
static var current_group: int = 3

## Current mode index within each group (for F-cycling)
static var group_mode_indices: Dictionary = {
	1: 0,  # Unitary: X, Y, Z axis
	2: 0,  # Lindbladian: thermal, dephase, damp
	3: 0,  # Measure: probe, gate, build
	4: 0   # Meta: (no modes)
}

# ============================================================================
# TOOL GROUP DEFINITIONS - Time Scale Ratchet
# ============================================================================

const TOOL_GROUPS = {
	# =========================================================================
	# GROUP 1: UNITARY (~) - Continuous
	# Pure quantum gates. Smooth, reversible. Sim runs.
	# =========================================================================
	1: {
		"name": "Unitary",
		"emoji": "~",
		"icon": "res://Assets/UI/Q-Bit/Unitary.svg",
		"time_scale": "continuous",
		"description": "Smooth, reversible quantum gates",
		"has_f_cycling": true,
		"modes": ["X", "Y", "Z"],
		"mode_labels": ["X", "Y", "Z"],
		"mode_emojis": ["X", "Y", "Z"],
		"pauses_sim": false,
		"actions": {
			"X": {
				"Q": {"action": "rotate_down", "label": "-", "emoji": "-",
					  "icon": "res://Assets/UI/Q-Bit/Pauli-X.svg",
					  "hint": "Rotate X axis down"},
				"E": {"action": "hadamard", "label": "H", "emoji": "H",
					  "icon": "res://Assets/UI/Q-Bit/Hadamard.svg",
					  "hint": "Hadamard superposition"},
				"R": {"action": "rotate_up", "label": "+", "emoji": "+",
					  "icon": "res://Assets/UI/Q-Bit/Pauli-X.svg",
					  "hint": "Rotate X axis up"}
			},
			"Y": {
				"Q": {"action": "rotate_down", "label": "-", "emoji": "-",
					  "icon": "res://Assets/UI/Q-Bit/Pauli-Y.svg",
					  "hint": "Rotate Y axis down"},
				"E": {"action": "hadamard", "label": "H", "emoji": "H",
					  "icon": "res://Assets/UI/Q-Bit/Hadamard.svg",
					  "hint": "Hadamard superposition"},
				"R": {"action": "rotate_up", "label": "+", "emoji": "+",
					  "icon": "res://Assets/UI/Q-Bit/Pauli-Y.svg",
					  "hint": "Rotate Y axis up"}
			},
			"Z": {
				"Q": {"action": "rotate_down", "label": "-", "emoji": "-",
					  "icon": "res://Assets/UI/Q-Bit/Pauli-Z.svg",
					  "hint": "Rotate Z axis down"},
				"E": {"action": "hadamard", "label": "H", "emoji": "H",
					  "icon": "res://Assets/UI/Q-Bit/Hadamard.svg",
					  "hint": "Hadamard superposition"},
				"R": {"action": "rotate_up", "label": "+", "emoji": "+",
					  "icon": "res://Assets/UI/Q-Bit/Pauli-Z.svg",
					  "hint": "Rotate Z axis up"}
			}
		}
	},

	# =========================================================================
	# GROUP 2: LINDBLADIAN (V) - Dissipative
	# "Vampire" - energy in/out of quantum space. Vocabulary harvest.
	# =========================================================================
	2: {
		"name": "Lindblad",
		"emoji": "V",
		"icon": "res://Assets/UI/Tools/Lindblad/Lindblad.svg",
		"time_scale": "dissipative",
		"description": "Energy exchange with environment",
		"has_f_cycling": true,
		"modes": ["thermal", "dephase", "damp"],
		"mode_labels": ["~", ".", "|"],
		"mode_emojis": ["~", ".", "|"],
		"pauses_sim": false,
		"held_context": true,
		"actions": {
			"thermal": {
				"Q": {"action": "drain", "label": "Drain", "emoji": "v",
					  "icon": "res://Assets/UI/Tools/Lindblad/Decay.svg",
					  "hint": "Dissipate excess to classical"},
				"E": {"action": "transfer", "label": "Xfer", "emoji": "<>",
					  "icon": "res://Assets/UI/Tools/Lindblad/Transfer.svg",
					  "hint": "Transfer population between qubits"},
				"R": {"action": "pump", "label": "Pump", "emoji": "^",
					  "icon": "res://Assets/UI/Tools/Lindblad/Drive.svg",
					  "hint": "Drive energy into quantum state"}
			},
			"dephase": {
				"Q": {"action": "drain", "label": "Drain", "emoji": "v",
					  "icon": "res://Assets/UI/Tools/Lindblad/Decay.svg",
					  "hint": "Dephasing drain"},
				"E": {"action": "transfer", "label": "Xfer", "emoji": "<>",
					  "icon": "res://Assets/UI/Tools/Lindblad/Transfer.svg",
					  "hint": "Dephasing transfer"},
				"R": {"action": "pump", "label": "Pump", "emoji": "^",
					  "icon": "res://Assets/UI/Tools/Lindblad/Drive.svg",
					  "hint": "Dephasing pump"}
			},
			"damp": {
				"Q": {"action": "drain", "label": "Drain", "emoji": "v",
					  "icon": "res://Assets/UI/Tools/Lindblad/Decay.svg",
					  "hint": "Amplitude damping drain"},
				"E": {"action": "transfer", "label": "Xfer", "emoji": "<>",
					  "icon": "res://Assets/UI/Tools/Lindblad/Transfer.svg",
					  "hint": "Amplitude damping transfer"},
				"R": {"action": "pump", "label": "Pump", "emoji": "^",
					  "icon": "res://Assets/UI/Tools/Lindblad/Drive.svg",
					  "hint": "Amplitude damping pump"}
			}
		}
	},

	# =========================================================================
	# GROUP 3: MEASURE (O) - Discrete
	# Main gameplay loop. F-cycles: probe -> gate
	# =========================================================================
	3: {
		"name": "Measure",
		"emoji": "O",
		"icon": "res://Assets/UI/Science/Measure.svg",
		"time_scale": "discrete",
		"description": "Collapse, harvest, entangle",
		"has_f_cycling": true,
		"modes": ["probe", "gate"],
		"mode_labels": ["?", ")("],
		"mode_emojis": ["?", ")("],
		"pauses_sim": true,
		"actions": {
			# PROBE MODE: Main quantum observation loop
				"probe": {
					"Q": {"action": "explore", "label": "Explore", "emoji": "?",
						  "icon": "res://Assets/UI/Science/Explore.svg",
						  "hint": "Bind terminal (dig DOWN)"},
					"E": {"action": "measure", "label": "Measure", "emoji": "!",
						  "icon": "res://Assets/UI/Science/Measure.svg",
						  "hint": "Collapse state (observe)"},
					"R": {"action": "pop", "label": "Pop", "emoji": "^",
						  "icon": "res://Assets/UI/Science/Pop-Harvest.svg",
						  "hint": "Pop terminal (auto-measures if only explored)",
						  "shift_action": "pop", "shift_label": "Mass Pop"}
				},
			# GATE MODE: Entanglement infrastructure
			"gate": {
				"Q": {"action": "build_gate", "label": "Gate", "emoji": ")(",
					  "icon": "res://Assets/UI/Q-Bit/CNOT.svg",
					  "hint": "Build entangling gate",
					  "submenu": "gate_selection"},
				"E": {"action": "inspect", "label": "Inspect", "emoji": "[]",
					  "icon": "res://Assets/UI/Science/Explore.svg",
					  "hint": "Inspect entanglement"},
				"R": {"action": "remove_gates", "label": "Break", "emoji": "X",
					  "icon": "res://Assets/UI/Biome/BiomeClear.svg",
					  "hint": "Break entanglement"}
			}
		}
	},

	# =========================================================================
	# GROUP 4: META (*) - System/Vocabulary
	# Biome configuration, vocabulary manipulation
	# =========================================================================
	4: {
		"name": "Meta",
		"emoji": "*",
		"icon": "res://Assets/UI/Icon/Icon.svg",
		"time_scale": "meta",
		"description": "Vocabulary and biome lifecycle controls",
		"has_f_cycling": true,
		"modes": ["vocabulary", "biomes"],
		"mode_labels": ["Vocab", "Biomes"],
		"mode_emojis": ["📖", "🌍"],
		"pauses_sim": true,
		"actions": {
			"vocabulary": {
				"Q": {"action": "inject_vocabulary", "label": "Add Vocab", "emoji": "+",
					  "icon": "res://Assets/UI/Biome/BiomeAssign.svg",
					  "hint": "Inject a vocabulary pair into the active biome",
					  "submenu": "vocab_injection"},
				"E": {"action": "", "label": "-", "emoji": "",
					  "icon": "",
					  "hint": "Reserved",
					  "disabled": true},
				"R": {"action": "remove_vocabulary", "label": "Trim Vocab", "emoji": "-",
					  "icon": "res://Assets/UI/Biome/BiomeClear.svg",
					  "hint": "Remove a vocabulary pair from the active biome"}
			},
			"biomes": {
				"Q": {"action": "discover_biome", "label": "Add Biome", "emoji": "🗺️",
					  "icon": "res://Assets/UI/Science/Explore.svg",
					  "hint": "Discover and load a new biome into the spindle"},
				"E": {"action": "", "label": "-", "emoji": "",
					  "icon": "",
					  "hint": "Reserved",
					  "disabled": true},
				"R": {"action": "remove_biome", "label": "Cull Biome", "emoji": "💀",
					  "icon": "res://Assets/UI/Biome/BiomeClear.svg",
					  "hint": "Liquidate the active biome from its live quantum state and return it to the unexplored pool"}
			}
		}
	}
}

# ============================================================================
# GROUP MANAGEMENT
# ============================================================================

static func select_group(group_num: int) -> void:
	"""Select a tool group (1-4)."""
	if group_num >= 1 and group_num <= 4:
		current_group = group_num


static func get_current_group() -> int:
	"""Get current tool group number."""
	return current_group


static func get_group(group_num: int) -> Dictionary:
	"""Get tool group definition by number (1-4)."""
	return TOOL_GROUPS.get(group_num, {})


static func get_current_group_def() -> Dictionary:
	"""Get current tool group definition."""
	return TOOL_GROUPS.get(current_group, {})


static func get_group_name(group_num: int) -> String:
	"""Get group name by number."""
	return get_group(group_num).get("name", "Unknown")


static func get_group_emoji(group_num: int) -> String:
	"""Get group emoji by number."""
	return get_group(group_num).get("emoji", "?")


static func get_group_icon_path(group_num: int) -> String:
	"""Get group icon path by number."""
	return get_group(group_num).get("icon", "")


static func does_group_pause_sim(group_num: int) -> bool:
	"""Check if group pauses simulation."""
	return get_group(group_num).get("pauses_sim", false)


static func get_group_time_scale(group_num: int) -> String:
	"""Get time scale type for group."""
	return get_group(group_num).get("time_scale", "")


# ============================================================================
# F-CYCLING (MODE EXPANSION WITHIN GROUPS)
# ============================================================================

static func has_f_cycling(group_num: int) -> bool:
	"""Check if group supports F-cycling."""
	return get_group(group_num).get("has_f_cycling", false)


static func cycle_group_mode(group_num: int) -> int:
	"""Cycle F-mode for a group. Returns new mode index, or -1 if no cycling."""
	var group_def = get_group(group_num)

	if not group_def.get("has_f_cycling", false):
		return -1

	var modes = group_def.get("modes", [])
	if modes.is_empty():
		return -1

	var current_index = group_mode_indices.get(group_num, 0)
	var new_index = (current_index + 1) % modes.size()
	group_mode_indices[group_num] = new_index

	return new_index


static func get_group_mode_index(group_num: int) -> int:
	"""Get current F-mode index for a group."""
	return group_mode_indices.get(group_num, 0)


static func get_group_mode_name(group_num: int) -> String:
	"""Get current F-mode name for a group."""
	var group_def = get_group(group_num)

	if not group_def.get("has_f_cycling", false):
		return ""

	var modes = group_def.get("modes", [])
	var index = group_mode_indices.get(group_num, 0)

	if index < modes.size():
		return modes[index]
	return ""


static func get_group_mode_label(group_num: int) -> String:
	"""Get current F-mode label for UI display."""
	var group_def = get_group(group_num)

	if not group_def.get("has_f_cycling", false):
		return ""

	var mode_labels = group_def.get("mode_labels", [])
	var index = group_mode_indices.get(group_num, 0)

	if index < mode_labels.size():
		return mode_labels[index]
	return ""


static func get_group_mode_emoji(group_num: int) -> String:
	"""Get current F-mode emoji for UI display."""
	var group_def = get_group(group_num)

	if not group_def.get("has_f_cycling", false):
		return ""

	var mode_emojis = group_def.get("mode_emojis", [])
	var index = group_mode_indices.get(group_num, 0)

	if index < mode_emojis.size():
		return mode_emojis[index]
	return ""


static func reset_group_modes() -> void:
	"""Reset all group modes to default (index 0)."""
	for key in group_mode_indices:
		group_mode_indices[key] = 0


# ============================================================================
# ACTION ACCESS
# ============================================================================

static func get_action(group_num: int, key: String) -> Dictionary:
	"""Get action definition for a group and key (Q/E/R).

	For groups with F-cycling, returns action from current mode.
	"""
	var group_def = get_group(group_num)
	if group_def.is_empty():
		return {}

	# Handle F-cycling groups
	if group_def.get("has_f_cycling", false):
		if key == "F":
			return get_cycle_action_info(group_num)
		var mode_name = get_group_mode_name(group_num)
		var mode_actions = group_def.get("actions", {}).get(mode_name, {})
		return mode_actions.get(key, {})

	# Non-cycling groups have direct actions
	var actions = group_def.get("actions", {})
	return actions.get(key, {})


static func get_action_label(group_num: int, key: String) -> String:
	"""Get action label for UI display."""
	return get_action(group_num, key).get("label", "")


static func get_action_emoji(group_num: int, key: String) -> String:
	"""Get action emoji for UI display."""
	return get_action(group_num, key).get("emoji", "")


static func get_action_name(group_num: int, key: String) -> String:
	"""Get action name (for dispatching to handlers)."""
	return get_action(group_num, key).get("action", "")


static func get_action_icon(group_num: int, key: String) -> String:
	"""Get action icon path for UI display."""
	return get_action(group_num, key).get("icon", "")


static func get_all_actions(group_num: int) -> Dictionary:
	"""Get all action slots for a group."""
	var actions = {
		"Q": get_action(group_num, "Q"),
		"E": get_action(group_num, "E"),
		"R": get_action(group_num, "R")
	}
	var f_action = get_action(group_num, "F")
	if not f_action.is_empty():
		actions["F"] = f_action
	return actions


static func get_cycle_action_info(group_num: int) -> Dictionary:
	"""Get the F-cycle action info for a cycling group."""
	var group_def = get_group(group_num)
	if group_def.is_empty() or not group_def.get("has_f_cycling", false):
		return {}

	var modes = group_def.get("modes", [])
	if modes.is_empty():
		return {}

	var mode_labels: Array = group_def.get("mode_labels", [])
	var current_index = group_mode_indices.get(group_num, 0)
	var next_index = (current_index + 1) % modes.size()
	var next_label = ""
	if next_index < mode_labels.size():
		next_label = str(mode_labels[next_index])
	elif next_index < modes.size():
		next_label = str(modes[next_index])

	return {
		"action": "cycle_mode",
		"label": "Cycle %s" % next_label if next_label != "" else "Cycle Mode",
		"emoji": "↺",
		"disabled": false
	}
