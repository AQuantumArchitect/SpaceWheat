class_name ToolConfig
extends RefCounted
## ToolConfig - v2 Tool Architecture Configuration
##
## Defines PLAY mode (4 tools) and BUILD mode (4 tools) with F-cycling support.
## Implements "Quantum Tomography Paradigm" - plots as probes into quantum soup.
##
## Key Changes from v1:
##   - EXPLORE replaces PLANT as primary action (discover, don't create)
##   - F-cycling for mode expansion within tools (GATES, ENTANGLE)
##   - Tab toggles BUILD/PLAY modes
##   - Spacebar pauses/resumes evolution

## Current game mode ("play" or "build")
static var current_mode: String = "play"

## F-cycling mode indices per tool (tool_num → current mode index)
static var tool_mode_indices: Dictionary = {
	2: 0,  # GATES: 0=basic, 1=phase, 2=two_qubit
	3: 0   # ENTANGLE: 0=bell, 1=cluster, 2=manipulate
}

# ============================================================================
# PLAY MODE TOOLS - Primary gameplay (Tab = "play")
# ============================================================================

const PLAY_TOOLS = {
	1: {  # PROBE - Core loop (80% of gameplay)
		"name": "Probe",
		"emoji": "🔬",
		"description": "Explore quantum soup, measure, harvest",
		"has_f_cycling": false,
		"actions": {
			"Q": {"action": "explore", "label": "Explore", "emoji": "🔍"},
			"E": {"action": "measure", "label": "Measure", "emoji": "👁️"},
			"R": {"action": "pop", "label": "Pop/Harvest", "emoji": "✂️"}
		}
	},
	2: {  # GATES - F-cycles through 3 modes
		"name": "Gates",
		"emoji": "🔄",
		"description": "Quantum gate operations (F to cycle modes)",
		"has_f_cycling": true,
		"modes": ["basic", "phase", "two_qubit"],
		"mode_labels": ["Basic", "Phase", "2-Qubit"],
		"actions": {
			"basic": {
				"Q": {"action": "gate_x", "label": "Pauli-X (Flip)", "emoji": "↔️"},
				"E": {"action": "gate_y", "label": "Pauli-Y", "emoji": "🔄"},
				"R": {"action": "gate_h", "label": "Hadamard", "emoji": "🌀"}
			},
			"phase": {
				"Q": {"action": "gate_s", "label": "S-Gate (π/2)", "emoji": "🌊"},
				"E": {"action": "gate_t", "label": "T-Gate (π/4)", "emoji": "✨"},
				"R": {"action": "gate_z", "label": "Pauli-Z", "emoji": "⚡"}
			},
			"two_qubit": {
				"Q": {"action": "gate_cnot", "label": "CNOT", "emoji": "⊕"},
				"E": {"action": "gate_cz", "label": "Control-Z", "emoji": "⚡"},
				"R": {"action": "gate_swap", "label": "SWAP", "emoji": "⇄"}
			}
		}
	},
	3: {  # ENTANGLE - F-cycles through 3 modes
		"name": "Entangle",
		"emoji": "🔗",
		"description": "Entanglement operations (F to cycle modes)",
		"has_f_cycling": true,
		"modes": ["bell", "cluster", "manipulate"],
		"mode_labels": ["Bell", "Cluster", "Manipulate"],
		"actions": {
			"bell": {
				"Q": {"action": "bell_phi_plus", "label": "Bell φ+", "emoji": "🔔"},
				"E": {"action": "bell_phi_minus", "label": "Bell φ-", "emoji": "🔕"},
				"R": {"action": "bell_psi", "label": "Bell ψ±", "emoji": "🎐"}
			},
			"cluster": {
				"Q": {"action": "cluster_ghz", "label": "GHZ State", "emoji": "🕸️"},
				"E": {"action": "cluster_w", "label": "W State", "emoji": "🌐"},
				"R": {"action": "cluster_graph", "label": "Graph State", "emoji": "📊"}
			},
			"manipulate": {
				"Q": {"action": "manip_phase", "label": "Phase Align", "emoji": "🎯"},
				"E": {"action": "manip_disentangle", "label": "Disentangle", "emoji": "✂️"},
				"R": {"action": "manip_transfer", "label": "Transfer", "emoji": "↔️"}
			}
		}
	},
	4: {  # INJECT - Expansion operations
		"name": "Inject",
		"emoji": "💉",
		"description": "Inject/remove qubits, drive biome",
		"has_f_cycling": false,
		"actions": {
			"Q": {"action": "seed", "label": "Seed (New Qubit)", "emoji": "🌱"},
			"E": {"action": "drive", "label": "Drive (Bias)", "emoji": "📈"},
			"R": {"action": "purge", "label": "Purge (Remove)", "emoji": "🗑️"}
		}
	}
}

# ============================================================================
# BUILD MODE TOOLS - World configuration (Tab = "build")
# ============================================================================

const BUILD_TOOLS = {
	1: {  # BIOME - Ecosystem management
		"name": "Biome",
		"emoji": "🌍",
		"description": "Assign plots to biomes, configure ecosystems",
		"has_f_cycling": false,
		"actions": {
			"Q": {"action": "submenu_biome_assign", "label": "Assign Biome ▸", "emoji": "🔄", "submenu": "biome_assign"},
			"E": {"action": "clear_biome_assignment", "label": "Clear Assignment", "emoji": "❌"},
			"R": {"action": "inspect_plot", "label": "Inspect Plot", "emoji": "🔍"}
		}
	},
	2: {  # ICON - Icon/emoji configuration
		"name": "Icon",
		"emoji": "⚙️",
		"description": "Configure icons and emoji associations",
		"has_f_cycling": false,
		"actions": {
			"Q": {"action": "submenu_icon_assign", "label": "Assign Icon ▸", "emoji": "🎨", "submenu": "icon_assign"},
			"E": {"action": "icon_swap", "label": "Swap N/S", "emoji": "🔃"},
			"R": {"action": "icon_clear", "label": "Clear Icon", "emoji": "⬜"}
		}
	},
	3: {  # LINDBLAD - Dissipation control
		"name": "Lindblad",
		"emoji": "🔬",
		"description": "Configure Lindblad operators and dissipation",
		"has_f_cycling": false,
		"actions": {
			"Q": {"action": "lindblad_drive", "label": "Drive (+pop)", "emoji": "📈"},
			"E": {"action": "lindblad_decay", "label": "Decay (-pop)", "emoji": "📉"},
			"R": {"action": "lindblad_transfer", "label": "Transfer", "emoji": "↔️"}
		}
	},
	4: {  # SYSTEM - Global system control
		"name": "System",
		"emoji": "⚡",
		"description": "System-level controls and configuration",
		"has_f_cycling": false,
		"actions": {
			"Q": {"action": "system_reset", "label": "Reset Bath", "emoji": "🔄"},
			"E": {"action": "system_snapshot", "label": "Snapshot", "emoji": "📸"},
			"R": {"action": "system_debug", "label": "Debug View", "emoji": "🐛"}
		}
	}
}

# ============================================================================
# SUBMENUS (shared between modes)
# ============================================================================

const SUBMENUS = {
	"biome_assign": {
		"name": "Assign to Biome",
		"emoji": "🔄",
		"parent_tool": 1,
		"parent_mode": "build",
		"dynamic": true,
		# Fallback definitions
		"Q": {"action": "assign_to_BioticFlux", "label": "BioticFlux", "emoji": "🌾"},
		"E": {"action": "assign_to_Market", "label": "Market", "emoji": "🏪"},
		"R": {"action": "assign_to_Forest", "label": "Forest", "emoji": "🌲"},
	},
	"icon_assign": {
		"name": "Assign Icon",
		"emoji": "🎨",
		"parent_tool": 2,
		"parent_mode": "build",
		"dynamic": true,
		"Q": {"action": "icon_assign_wheat", "label": "Wheat", "emoji": "🌾"},
		"E": {"action": "icon_assign_mushroom", "label": "Mushroom", "emoji": "🍄"},
		"R": {"action": "icon_assign_tomato", "label": "Tomato", "emoji": "🍅"},
	}
}

# ============================================================================
# MODE MANAGEMENT
# ============================================================================

static func toggle_mode() -> String:
	"""Toggle between play and build modes. Returns new mode."""
	current_mode = "build" if current_mode == "play" else "play"
	return current_mode


static func get_mode() -> String:
	"""Get current mode (play or build)."""
	return current_mode


static func set_mode(mode: String) -> void:
	"""Set current mode."""
	if mode in ["play", "build"]:
		current_mode = mode


# ============================================================================
# F-CYCLING (MODE EXPANSION WITHIN TOOLS)
# ============================================================================

static func cycle_tool_mode(tool_num: int) -> int:
	"""Cycle F-mode for a tool. Returns new mode index, or -1 if no cycling."""
	var tools = PLAY_TOOLS if current_mode == "play" else BUILD_TOOLS
	var tool_def = tools.get(tool_num, {})

	if not tool_def.get("has_f_cycling", false):
		return -1

	var modes = tool_def.get("modes", [])
	if modes.is_empty():
		return -1

	var current_index = tool_mode_indices.get(tool_num, 0)
	var new_index = (current_index + 1) % modes.size()
	tool_mode_indices[tool_num] = new_index

	return new_index


static func get_tool_mode_index(tool_num: int) -> int:
	"""Get current F-mode index for a tool."""
	return tool_mode_indices.get(tool_num, 0)


static func get_tool_mode_name(tool_num: int) -> String:
	"""Get current F-mode name for a tool."""
	var tools = PLAY_TOOLS if current_mode == "play" else BUILD_TOOLS
	var tool_def = tools.get(tool_num, {})

	if not tool_def.get("has_f_cycling", false):
		return ""

	var modes = tool_def.get("modes", [])
	var index = tool_mode_indices.get(tool_num, 0)

	if index < modes.size():
		return modes[index]
	return ""


static func get_tool_mode_label(tool_num: int) -> String:
	"""Get current F-mode label for UI display."""
	var tools = PLAY_TOOLS if current_mode == "play" else BUILD_TOOLS
	var tool_def = tools.get(tool_num, {})

	if not tool_def.get("has_f_cycling", false):
		return ""

	var mode_labels = tool_def.get("mode_labels", [])
	var index = tool_mode_indices.get(tool_num, 0)

	if index < mode_labels.size():
		return mode_labels[index]
	return ""


static func reset_tool_modes() -> void:
	"""Reset all tool modes to default (index 0)."""
	for key in tool_mode_indices:
		tool_mode_indices[key] = 0


# ============================================================================
# TOOL ACCESS (v2 API)
# ============================================================================

static func get_current_tools() -> Dictionary:
	"""Get tools for current mode."""
	return PLAY_TOOLS if current_mode == "play" else BUILD_TOOLS


static func get_tool(tool_num: int) -> Dictionary:
	"""Get tool definition by number (1-4)."""
	var tools = get_current_tools()
	return tools.get(tool_num, {})


static func get_tool_name(tool_num: int) -> String:
	"""Get tool name by number."""
	return get_tool(tool_num).get("name", "Unknown")


static func get_tool_emoji(tool_num: int) -> String:
	"""Get tool emoji by number."""
	return get_tool(tool_num).get("emoji", "?")


static func has_f_cycling(tool_num: int) -> bool:
	"""Check if tool supports F-cycling."""
	return get_tool(tool_num).get("has_f_cycling", false)


# ============================================================================
# ACTION ACCESS (v2 API with F-cycling support)
# ============================================================================

static func get_action(tool_num: int, key: String) -> Dictionary:
	"""Get action definition for a tool and key (Q/E/R).

	For tools with F-cycling, returns action from current mode.
	"""
	var tool_def = get_tool(tool_num)
	if tool_def.is_empty():
		return {}

	# Handle F-cycling tools
	if tool_def.get("has_f_cycling", false):
		var mode_name = get_tool_mode_name(tool_num)
		var mode_actions = tool_def.get("actions", {}).get(mode_name, {})
		return mode_actions.get(key, {})

	# Non-cycling tools have direct actions
	var actions = tool_def.get("actions", {})
	return actions.get(key, {})


static func get_action_label(tool_num: int, key: String) -> String:
	"""Get action label for UI display."""
	return get_action(tool_num, key).get("label", "")


static func get_action_emoji(tool_num: int, key: String) -> String:
	"""Get action emoji for UI display."""
	return get_action(tool_num, key).get("emoji", "")


static func get_action_name(tool_num: int, key: String) -> String:
	"""Get action name (for dispatching to handlers)."""
	return get_action(tool_num, key).get("action", "")


static func get_all_actions(tool_num: int) -> Dictionary:
	"""Get all Q/E/R actions for a tool (respecting F-cycling mode)."""
	return {
		"Q": get_action(tool_num, "Q"),
		"E": get_action(tool_num, "E"),
		"R": get_action(tool_num, "R")
	}


# ============================================================================
# SUBMENU ACCESS
# ============================================================================

static func get_submenu(submenu_name: String) -> Dictionary:
	"""Get submenu definition by name."""
	return SUBMENUS.get(submenu_name, {})


static func is_submenu_action(tool_num: int, key: String) -> bool:
	"""Check if action opens a submenu."""
	var action = get_action(tool_num, key)
	return action.has("submenu")


static func get_submenu_name_for_action(tool_num: int, key: String) -> String:
	"""Get submenu name if action opens one."""
	return get_action(tool_num, key).get("submenu", "")


static func get_dynamic_submenu(submenu_name: String, farm, current_selection: Vector2i = Vector2i.ZERO) -> Dictionary:
	"""Generate dynamic submenu from game state.

	For submenus marked with "dynamic": true, generates Q/E/R actions
	at runtime based on available game options.
	"""
	var base_submenu = get_submenu(submenu_name)

	if not base_submenu.get("dynamic", false):
		return base_submenu

	match submenu_name:
		"biome_assign":
			return _generate_biome_assign_submenu(base_submenu, farm)
		"icon_assign":
			return _generate_icon_assign_submenu(base_submenu, farm, current_selection)
		_:
			push_warning("Unknown dynamic submenu: %s" % submenu_name)
			return base_submenu


static func _generate_biome_assign_submenu(base: Dictionary, farm) -> Dictionary:
	"""Generate biome assignment submenu from registered biomes."""
	var generated = base.duplicate(true)

	var biome_names: Array[String] = []
	if farm and farm.grid and farm.grid.biomes:
		for key in farm.grid.biomes.keys():
			biome_names.append(str(key))

	if biome_names.is_empty():
		generated["Q"] = {"action": "", "label": "No Biomes!", "emoji": "❌"}
		generated["E"] = {"action": "", "label": "Error", "emoji": "⚠️"}
		generated["R"] = {"action": "", "label": "", "emoji": ""}
		generated["_disabled"] = true
		return generated

	var keys = ["Q", "E", "R"]
	for i in range(min(3, biome_names.size())):
		var biome_name = biome_names[i]
		var key = keys[i]

		var biome_emoji = "🌍"
		if farm.grid.biomes.has(biome_name):
			var biome = farm.grid.biomes[biome_name]
			if biome and biome.producible_emojis.size() > 0:
				biome_emoji = biome.producible_emojis[0]

		generated[key] = {
			"action": "assign_to_%s" % biome_name,
			"label": biome_name,
			"emoji": biome_emoji
		}

	for i in range(biome_names.size(), 3):
		generated[keys[i]] = {"action": "", "label": "Empty", "emoji": "⬜"}

	return generated


static func _generate_icon_assign_submenu(base: Dictionary, farm, current_selection: Vector2i) -> Dictionary:
	"""Generate icon assignment submenu from available icons."""
	var generated = base.duplicate(true)

	# Get available icons from biome
	var biome = null
	if farm and farm.grid:
		biome = farm.grid.get_biome_for_plot(current_selection)

	if not biome:
		generated["Q"] = {"action": "", "label": "No Biome", "emoji": "❌"}
		generated["E"] = {"action": "", "label": "Assign First", "emoji": "🔄"}
		generated["R"] = {"action": "", "label": "", "emoji": ""}
		generated["_disabled"] = true
		return generated

	# Use biome's producible emojis
	var emojis = biome.producible_emojis if biome.producible_emojis else []
	var keys = ["Q", "E", "R"]

	for i in range(min(3, emojis.size())):
		var emoji = emojis[i]
		generated[keys[i]] = {
			"action": "icon_assign_%s" % emoji.hash(),
			"label": emoji,
			"emoji": emoji
		}

	for i in range(emojis.size(), 3):
		generated[keys[i]] = {"action": "", "label": "Empty", "emoji": "⬜"}

	return generated


# ============================================================================
# BACKWARD COMPATIBILITY (v1 migration support)
# ============================================================================

## v1 TOOL_ACTIONS format for gradual migration
const TOOL_ACTIONS = PLAY_TOOLS  # Alias for compatibility

static func get_tool_count() -> int:
	"""Get number of tools in current mode."""
	return 4  # v2 always has 4 tools per mode
