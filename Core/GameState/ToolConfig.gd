extends RefCounted

## ToolConfig — Archetype Frame configuration.
##
## Top of the keyboard hierarchy is now the **archetype hat row** (4-0).
## Each hat picks a frame; 1/2/3 picks a sub-mode within that frame; QERF
## remains the axial verb cross. See `docs/ARCHETYPE_FRAMES.md`.
##
## | Hat | Archetype  | Old tool-group equivalent              |
## |-----|------------|----------------------------------------|
## |  4  | Spark      | Tool 1 (Unitary X/Y/Z gates)           |
## |  5  | Icon       | (new — placeholder, no live actions)   |
## |  6  | Socialite  | (new — placeholder, no live actions)   |
## |  7  | Captain    | Tool 4 (Meta: biomes, signature)       |
## |  8  | Scientist  | Tool 3 (Measure: probe, gate)          |
## |  9  | Operator   | (new — placeholder, no live actions)   |
## |  0  | Druid      | Tool 2 (Lindblad: thermal/dephase/damp)|
##
## Ace = no hat pressed = default toolkit (currently routed to Scientist).
##
## ## Migration shape
##
## Internally archetype-frame-keyed. Externally exposes BOTH the new
## String-keyed API (`select_frame`, `get_frame`, `get_action(frame, key)`…)
## AND the legacy int-keyed API (`select_group(int)`, `get_action(int, key)`…)
## as transitional compat shims that translate via `GROUP_TO_FRAME`. The
## shims will be retired as callsites migrate to the frame API.

# =============================================================================
# FRAME IDS
# =============================================================================

const FRAME_SPARK := "spark"
const FRAME_ICON := "icon"
const FRAME_SOCIALITE := "socialite"
const FRAME_CAPTAIN := "captain"
const FRAME_SCIENTIST := "scientist"
const FRAME_OPERATOR := "operator"
const FRAME_DRUID := "druid"
const FRAME_ACE := ""  # null hat — default toolkit

const FRAME_IDS: Array = [
	FRAME_SPARK, FRAME_ICON, FRAME_SOCIALITE, FRAME_CAPTAIN,
	FRAME_SCIENTIST, FRAME_OPERATOR, FRAME_DRUID,
]

## Top-row hat keys → archetype frame.
const HAT_KEY_TO_FRAME: Dictionary = {
	"4": FRAME_SPARK,
	"5": FRAME_ICON,
	"6": FRAME_SOCIALITE,
	"7": FRAME_CAPTAIN,
	"8": FRAME_SCIENTIST,
	"9": FRAME_OPERATOR,
	"0": FRAME_DRUID,
}

## Transitional map: legacy tool group (1-4) → archetype frame.
## Tool 1's mode set splits across Spark + Icon eventually, and Tool 4 splits
## across Captain + Operator + Socialite, but for compat we route the live
## wiring to a single archetype each: Tool 1 → Spark, Tool 4 → Captain.
const GROUP_TO_FRAME: Dictionary = {
	1: FRAME_SPARK,
	2: FRAME_DRUID,
	3: FRAME_SCIENTIST,
	4: FRAME_CAPTAIN,
}

## Reverse: archetype frame → legacy group number for callers that still want
## an int. Frames that didn't have a live tool group in the old scheme map to
## their nearest neighbour (Icon→1, Socialite/Operator→4) so display layers
## get a stable answer.
const FRAME_TO_GROUP: Dictionary = {
	FRAME_SPARK: 1,
	FRAME_ICON: 1,
	FRAME_SOCIALITE: 4,
	FRAME_CAPTAIN: 4,
	FRAME_SCIENTIST: 3,
	FRAME_OPERATOR: 4,
	FRAME_DRUID: 2,
}

# =============================================================================
# RUNTIME STATE
# =============================================================================

## Current archetype frame. Empty string = Ace (no hat = default toolkit).
## Default to Scientist to preserve the legacy "boots into group 3" behaviour.
static var current_frame: String = FRAME_SCIENTIST

## Sub-mode index within each frame (selected by 1/2/3 in the new grammar,
## or by 5-0 in the legacy grammar — both routes write through here).
static var frame_mode_indices: Dictionary = {
	FRAME_SPARK: 0,
	FRAME_ICON: 0,
	FRAME_SOCIALITE: 0,
	FRAME_CAPTAIN: 0,
	FRAME_SCIENTIST: 0,
	FRAME_OPERATOR: 0,
	FRAME_DRUID: 0,
}

# =============================================================================
# ARCHETYPE FRAME DEFINITIONS
# =============================================================================

const ARCHETYPE_FRAMES: Dictionary = {
	# =========================================================================
	# SPARK (S, Q, P) — casting moment. Was Tool 1 (Unitary).
	# =========================================================================
	FRAME_SPARK: {
		"name": "Spark",
		"emoji": "⚡",
		"icon": "res://Assets/UI/Q-Bit/Unitary.svg",
		"time_scale": "continuous",
		"description": "Casting moment — reversible quantum gates",
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
	# ICON (S, Q, F) — pattern embodiment. Placeholder; no live actions yet.
	# =========================================================================
	FRAME_ICON: {
		"name": "Icon",
		"emoji": "📖",
		"icon": "res://Assets/UI/Icon/Icon.svg",
		"time_scale": "continuous",
		"description": "Pattern embodiment (not yet wired)",
		"has_f_cycling": false,
		"modes": ["hamiltonian"],
		"mode_labels": ["H"],
		"mode_emojis": ["H"],
		"pauses_sim": false,
		"actions": {
			"hamiltonian": {
				"Q": {"action": "", "label": "-", "emoji": "", "icon": "",
					  "hint": "Reserved (Icon hamiltonian)", "disabled": true},
				"E": {"action": "", "label": "-", "emoji": "", "icon": "",
					  "hint": "Reserved", "disabled": true},
				"R": {"action": "", "label": "-", "emoji": "", "icon": "",
					  "hint": "Reserved", "disabled": true}
			}
		}
	},

	# =========================================================================
	# SOCIALITE (S, C, F) — faction politics. Placeholder; no live actions yet.
	# =========================================================================
	FRAME_SOCIALITE: {
		"name": "Socialite",
		"emoji": "🤝",
		"icon": "res://Assets/UI/Icon/Icon.svg",
		"time_scale": "discrete",
		"description": "Faction politics / quest layer (not yet wired)",
		"has_f_cycling": false,
		"modes": ["quest"],
		"mode_labels": ["Q"],
		"mode_emojis": ["Q"],
		"pauses_sim": true,
		"actions": {
			"quest": {
				"Q": {"action": "", "label": "-", "emoji": "", "icon": "",
					  "hint": "Reserved (Socialite quest)", "disabled": true},
				"E": {"action": "", "label": "-", "emoji": "", "icon": "",
					  "hint": "Reserved", "disabled": true},
				"R": {"action": "", "label": "-", "emoji": "", "icon": "",
					  "hint": "Reserved", "disabled": true}
			}
		}
	},

	# =========================================================================
	# CAPTAIN (W, C, F) — strategic decree. Inherits Tool 4 (Meta) wiring.
	# Eventually will hold biome lifecycle / faction levers / fiefdom plans;
	# for now exposes the live "signature" + "biomes" sub-modes.
	# =========================================================================
	FRAME_CAPTAIN: {
		"name": "Captain",
		"emoji": "*",
		"icon": "res://Assets/UI/Icon/Icon.svg",
		"time_scale": "meta",
		"description": "Strategic decree — biome and signature lifecycle",
		"has_f_cycling": true,
		"modes": ["signature", "biomes"],
		"mode_labels": ["Icon", "Biomes"],
		"mode_emojis": ["📖", "🌍"],
		"pauses_sim": true,
		"actions": {
			"signature": {
				"Q": {"action": "inject_vocabulary", "label": "Add Icon", "emoji": "+",
					  "icon": "res://Assets/UI/Biome/BiomeAssign.svg",
					  "hint": "Inject a icon into the active biome",
					  "submenu": "icon_injection"},
				"E": {"action": "", "label": "-", "emoji": "",
					  "icon": "",
					  "hint": "Reserved",
					  "disabled": true},
				"R": {"action": "remove_vocabulary", "label": "Trim Icon", "emoji": "-",
					  "icon": "res://Assets/UI/Biome/BiomeClear.svg",
					  "hint": "Remove a icon from the active biome"}
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
	},

	# =========================================================================
	# SCIENTIST (W, C, P) — audit / discovery. Was Tool 3 (Measure).
	# =========================================================================
	FRAME_SCIENTIST: {
		"name": "Scientist",
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
	# OPERATOR (W, Q, F) — topology craft. Placeholder; no live actions yet.
	# =========================================================================
	FRAME_OPERATOR: {
		"name": "Operator",
		"emoji": "⚙",
		"icon": "res://Assets/UI/Icon/Icon.svg",
		"time_scale": "continuous",
		"description": "Topology craft (not yet wired)",
		"has_f_cycling": false,
		"modes": ["topology"],
		"mode_labels": ["T"],
		"mode_emojis": ["T"],
		"pauses_sim": false,
		"actions": {
			"topology": {
				"Q": {"action": "", "label": "-", "emoji": "", "icon": "",
					  "hint": "Reserved (Operator topology)", "disabled": true},
				"E": {"action": "", "label": "-", "emoji": "", "icon": "",
					  "hint": "Reserved", "disabled": true},
				"R": {"action": "", "label": "-", "emoji": "", "icon": "",
					  "hint": "Reserved", "disabled": true}
			}
		}
	},

	# =========================================================================
	# DRUID (W, Q, P) — quantum priesthood. Was Tool 2 (Lindblad).
	# =========================================================================
	FRAME_DRUID: {
		"name": "Druid",
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
	}
}

# =============================================================================
# RESOLUTION HELPER
# =============================================================================

## Resolve a frame-or-group identifier (String or int) to an archetype frame
## name. Returns "" for unknown / Ace.
static func resolve_frame(frame_or_group) -> String:
	if frame_or_group is String:
		return frame_or_group
	if frame_or_group is int:
		return GROUP_TO_FRAME.get(frame_or_group, "")
	return ""


# =============================================================================
# FRAME MANAGEMENT (new String-keyed API)
# =============================================================================

static func select_frame(frame_name: String) -> void:
	"""Select an archetype frame by name. Empty string = Ace (no hat)."""
	if frame_name == FRAME_ACE or ARCHETYPE_FRAMES.has(frame_name):
		current_frame = frame_name


static func get_current_frame() -> String:
	"""Get the active archetype frame name. Empty string = Ace."""
	return current_frame


static func get_frame(frame_name: String) -> Dictionary:
	"""Get an archetype frame definition."""
	return ARCHETYPE_FRAMES.get(frame_name, {})


static func get_current_frame_def() -> Dictionary:
	return ARCHETYPE_FRAMES.get(current_frame, {})


static func get_frame_name_label(frame_name: String) -> String:
	return get_frame(frame_name).get("name", "Unknown")


static func get_frame_emoji(frame_name: String) -> String:
	return get_frame(frame_name).get("emoji", "?")


static func get_frame_icon_path(frame_name: String) -> String:
	return get_frame(frame_name).get("icon", "")


static func does_frame_pause_sim(frame_name: String) -> bool:
	return get_frame(frame_name).get("pauses_sim", false)


static func get_frame_time_scale(frame_name: String) -> String:
	return get_frame(frame_name).get("time_scale", "")


# =============================================================================
# SUB-MODE MANAGEMENT (1/2/3 in the new grammar, 5-0 in the legacy grammar)
# =============================================================================

static func cycle_frame_mode(frame_name: String) -> int:
	"""Cycle to the next sub-mode within a frame. Returns the new index, or
	-1 if the frame has fewer than 2 modes."""
	var def := get_frame(frame_name)
	var modes: Array = def.get("modes", [])
	if modes.size() < 2:
		return -1
	var current_index: int = int(frame_mode_indices.get(frame_name, 0))
	var new_index := (current_index + 1) % modes.size()
	frame_mode_indices[frame_name] = new_index
	return new_index


static func set_frame_mode(frame_name: String, mode_index: int) -> int:
	"""Direct-jump to a specific sub-mode by index. Returns the index applied,
	or -1 if out of range."""
	var def := get_frame(frame_name)
	var modes: Array = def.get("modes", [])
	if mode_index < 0 or mode_index >= modes.size():
		return -1
	frame_mode_indices[frame_name] = mode_index
	return mode_index


static func get_frame_mode_index(frame_name: String) -> int:
	return int(frame_mode_indices.get(frame_name, 0))


static func get_frame_mode_name(frame_name: String) -> String:
	var def := get_frame(frame_name)
	if not def.get("has_f_cycling", false):
		var modes: Array = def.get("modes", [])
		if modes.is_empty():
			return ""
		return str(modes[0])
	var modes: Array = def.get("modes", [])
	var index: int = int(frame_mode_indices.get(frame_name, 0))
	if index < modes.size():
		return str(modes[index])
	return ""


static func get_frame_mode_label(frame_name: String) -> String:
	var def := get_frame(frame_name)
	if not def.get("has_f_cycling", false):
		return ""
	var labels: Array = def.get("mode_labels", [])
	var index: int = int(frame_mode_indices.get(frame_name, 0))
	if index < labels.size():
		return str(labels[index])
	return ""


static func get_frame_mode_emoji(frame_name: String) -> String:
	var def := get_frame(frame_name)
	if not def.get("has_f_cycling", false):
		return ""
	var emojis: Array = def.get("mode_emojis", [])
	var index: int = int(frame_mode_indices.get(frame_name, 0))
	if index < emojis.size():
		return str(emojis[index])
	return ""


static func reset_frame_modes() -> void:
	for key in frame_mode_indices:
		frame_mode_indices[key] = 0


# =============================================================================
# ACTION ACCESS — accepts String (frame name) OR int (legacy group num)
# =============================================================================

static func get_action(frame_or_group, key: String) -> Dictionary:
	"""Get action definition for a frame and key (Q/E/R/F). For F-cycling
	frames, returns the action from the current sub-mode."""
	var frame_name := resolve_frame(frame_or_group)
	var def := get_frame(frame_name)
	if def.is_empty():
		return {}

	var mode_name := ""
	if def.get("has_f_cycling", false):
		if key == "F":
			return get_cycle_action_info(frame_name)
		mode_name = get_frame_mode_name(frame_name)
	else:
		var modes: Array = def.get("modes", [])
		if not modes.is_empty():
			mode_name = str(modes[0])

	var mode_actions: Dictionary = def.get("actions", {}).get(mode_name, {})
	if mode_actions.is_empty():
		# Fall back to flat actions dict if a frame doesn't nest by mode.
		return def.get("actions", {}).get(key, {})
	return mode_actions.get(key, {})


static func get_action_label(frame_or_group, key: String) -> String:
	return get_action(frame_or_group, key).get("label", "")


static func get_action_emoji(frame_or_group, key: String) -> String:
	return get_action(frame_or_group, key).get("emoji", "")


static func get_action_name(frame_or_group, key: String) -> String:
	return get_action(frame_or_group, key).get("action", "")


static func get_action_icon(frame_or_group, key: String) -> String:
	return get_action(frame_or_group, key).get("icon", "")


static func get_all_actions(frame_or_group) -> Dictionary:
	var actions := {
		"Q": get_action(frame_or_group, "Q"),
		"E": get_action(frame_or_group, "E"),
		"R": get_action(frame_or_group, "R"),
	}
	var f_action := get_action(frame_or_group, "F")
	if not f_action.is_empty():
		actions["F"] = f_action
	return actions


static func get_cycle_action_info(frame_or_group) -> Dictionary:
	var frame_name := resolve_frame(frame_or_group)
	var def := get_frame(frame_name)
	if def.is_empty() or not def.get("has_f_cycling", false):
		return {}

	var modes: Array = def.get("modes", [])
	if modes.is_empty():
		return {}

	var labels: Array = def.get("mode_labels", [])
	var current_index: int = int(frame_mode_indices.get(frame_name, 0))
	var next_index := (current_index + 1) % modes.size()
	var next_label := ""
	if next_index < labels.size():
		next_label = str(labels[next_index])
	elif next_index < modes.size():
		next_label = str(modes[next_index])

	return {
		"action": "cycle_mode",
		"label": "Cycle %s" % next_label if next_label != "" else "Cycle Mode",
		"emoji": "↺",
		"disabled": false,
	}


static func has_f_cycling(frame_or_group) -> bool:
	var frame_name := resolve_frame(frame_or_group)
	return get_frame(frame_name).get("has_f_cycling", false)


# =============================================================================
# LEGACY INT-KEYED API (transitional — routes through the frame state)
# =============================================================================
#
# These shims let existing callsites continue to work unchanged. New code
# should call the frame API directly. Each shim translates an int group
# number to its archetype frame via GROUP_TO_FRAME, then forwards.

static func select_group(group_num: int) -> void:
	var frame_name: String = GROUP_TO_FRAME.get(group_num, "")
	if frame_name != "":
		select_frame(frame_name)


static func get_current_group() -> int:
	return int(FRAME_TO_GROUP.get(current_frame, 0))


static func get_group(group_num: int) -> Dictionary:
	return get_frame(GROUP_TO_FRAME.get(group_num, ""))


static func get_current_group_def() -> Dictionary:
	return get_current_frame_def()


static func get_group_name(group_num: int) -> String:
	return get_frame_name_label(GROUP_TO_FRAME.get(group_num, ""))


static func get_group_emoji(group_num: int) -> String:
	return get_frame_emoji(GROUP_TO_FRAME.get(group_num, ""))


static func get_group_icon_path(group_num: int) -> String:
	return get_frame_icon_path(GROUP_TO_FRAME.get(group_num, ""))


static func does_group_pause_sim(group_num: int) -> bool:
	return does_frame_pause_sim(GROUP_TO_FRAME.get(group_num, ""))


static func get_group_time_scale(group_num: int) -> String:
	return get_frame_time_scale(GROUP_TO_FRAME.get(group_num, ""))


static func cycle_group_mode(group_num: int) -> int:
	return cycle_frame_mode(GROUP_TO_FRAME.get(group_num, ""))


static func set_group_mode(group_num: int, mode_index: int) -> int:
	return set_frame_mode(GROUP_TO_FRAME.get(group_num, ""), mode_index)


static func get_group_mode_index(group_num: int) -> int:
	return get_frame_mode_index(GROUP_TO_FRAME.get(group_num, ""))


static func get_group_mode_name(group_num: int) -> String:
	return get_frame_mode_name(GROUP_TO_FRAME.get(group_num, ""))


static func get_group_mode_label(group_num: int) -> String:
	return get_frame_mode_label(GROUP_TO_FRAME.get(group_num, ""))


static func get_group_mode_emoji(group_num: int) -> String:
	return get_frame_mode_emoji(GROUP_TO_FRAME.get(group_num, ""))


static func reset_group_modes() -> void:
	reset_frame_modes()
