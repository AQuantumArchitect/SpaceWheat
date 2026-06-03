extends RefCounted

## ToolConfig — Archetype Frame configuration.
##
## Top of the keyboard hierarchy is now the **archetype hat row** (4-0).
## Each hat picks a frame; 1/2/3 picks a sub-mode within that frame; QERF
## is the four-chip primary action row. See `docs/ARCHETYPE_FRAMES.md`.
##
## | Hat | Frame      | Live wiring                                    |
## |-----|------------|------------------------------------------------|
## |  4  | Spark      | Pole shift (spend pole emoji → shove qubit)    |
## |  5  | Icon       | Icon injection (player faction signature)      |
## |  6  | Merchant   | Faction contracts (drain/transfer/pump)        |
## |  7  | Captain    | Biomes lifecycle (discover / cull)             |
## |  8  | Ace        | Measure / probe (explore / measure / pop)      |
## |  9  | Operator   | Gate building (build / inspect / break)        |
## |  0  | Druid      | Unitary (X/Y/Z rotations, Hadamard)            |
##
## No hat pressed = Ace (default probe toolkit).
##
## String-keyed API: `select_frame`, `get_frame`, `get_action(frame, key)`…

# =============================================================================
# FRAME IDS
# =============================================================================

const FRAME_SPARK := "spark"
const FRAME_ICON := "icon"
const FRAME_MERCHANT := "merchant"   # faction contracts
const FRAME_CAPTAIN := "captain"
const FRAME_ACE := "ace"             # probe / measure / harvest
const FRAME_OPERATOR := "operator"
const FRAME_DRUID := "druid"
const FRAME_NULL := ""               # no hat selected

const FRAME_IDS: Array = [
	FRAME_SPARK, FRAME_ICON, FRAME_MERCHANT, FRAME_CAPTAIN,
	FRAME_ACE, FRAME_OPERATOR, FRAME_DRUID,
]

## Top-row hat keys → archetype frame.
const HAT_KEY_TO_FRAME: Dictionary = {
	"4": FRAME_SPARK,
	"5": FRAME_ICON,
	"6": FRAME_MERCHANT,
	"7": FRAME_CAPTAIN,
	"8": FRAME_ACE,
	"9": FRAME_OPERATOR,
	"0": FRAME_DRUID,
}

# =============================================================================
# RUNTIME STATE
# =============================================================================

## Current archetype frame. Empty string (FRAME_NULL) = no hat selected.
static var current_frame: String = FRAME_ACE

## Sub-mode index within each frame (selected by 1/2/3 in the new grammar).
static var frame_mode_indices: Dictionary = {
	FRAME_SPARK: 0,
	FRAME_ICON: 0,
	FRAME_MERCHANT: 0,
	FRAME_CAPTAIN: 0,
	FRAME_ACE: 0,
	FRAME_OPERATOR: 0,
	FRAME_DRUID: 0,
}

# =============================================================================
# ARCHETYPE FRAME DEFINITIONS
# =============================================================================

const ARCHETYPE_FRAMES: Dictionary = {
	# =========================================================================
	# SPARK (S, Q, P) — casting moment. Spend one pole emoji to instantly
	# shove the qubit toward that pole (strong one-shot Lindblad drive/decay).
	# No extra fees: the pole emoji IS the cost.
	# Q = push toward south pole  |  R = push toward north pole
	# =========================================================================
	FRAME_SPARK: {
		"name": "Spark",
		"emoji": "⚡",
		"icon": "res://Assets/UI/Tools/Lindblad/Lindblad.svg",
		"time_scale": "dissipative",
		"description": "Energy dyad (Lindblad jolt) — Q discharges south (out), R charges north (invest). Both fire while paused or playing.",
		"modes": ["shift"],
		"mode_labels": ["⚡"],
		"mode_emojis": ["⚡"],
		"pauses_sim": false,
		"actions": {
			"shift": {
				"Q": {"action": "spark_south", "label": "S.Pole", "emoji": "↓",
					  "icon": "res://Assets/UI/Tools/Lindblad/Decay.svg",
					  "hint": "Spend 1× south-pole emoji — jolt qubit toward south pole (fires while paused or playing)"},
				"E": {"action": "", "label": "Pause", "emoji": "⏸", "icon": "",
					  "hint": "Pause — global side-effect only (no tool action)",
					  "disabled": true},
				"R": {"action": "spark_north", "label": "N.Pole", "emoji": "↑",
					  "icon": "res://Assets/UI/Tools/Lindblad/Drive.svg",
					  "hint": "Spend 1× north-pole emoji — jolt qubit toward north pole (fires while paused or playing)"}
			}
		}
	},

	# =========================================================================
	# ICON (S, Q, F) — pattern embodiment. Holds the icon-injection wiring
	# (formerly Captain.signature). The player inserts dual-emoji-qubit
	# icons drawn from their own faction signature into the active biome.
	# =========================================================================
	FRAME_ICON: {
		"name": "Icon",
		"emoji": "📖",
		"icon": "res://Assets/UI/Icon/Icon.svg",
		"time_scale": "meta",
		"description": "Icon injection — dual-emoji qubits from your faction signature",
		"modes": ["inject"],
		"mode_labels": ["Icon"],
		"mode_emojis": ["📖"],
		"pauses_sim": true,
		"actions": {
			"inject": {
				"Q": {"action": "remove_icon", "label": "Trim Icon", "emoji": "−",
					  "icon": "res://Assets/UI/Biome/BiomeClear.svg",
					  "hint": "Remove an icon from the active biome", "destructive": true},
				"E": {"action": "inspect_qubit", "label": "Inspect", "emoji": "🔍", "icon": "",
					  "hint": "Open qubit detail view — zooms into this qubit in the V surface"},
				"R": {"action": "inject_icon", "label": "Add Icon", "emoji": "+",
					  "icon": "res://Assets/UI/Biome/BiomeAssign.svg",
					  "hint": "Empty plot: inject icon. Tracked + ripe: incorporate icon into your signature.",
					  "submenu": "icon_injection",
					  "chip_resolver": "icon.r_state"},
				"F": {"action": "toggle_berry_track", "label": "Track", "emoji": "⌖", "icon": "",
					  "hint": "Toggle Berry-phase tracking on the focused icon. Press again to stop. Also fires Play."}
			}
		}
	},

	# =========================================================================
	# MERCHANT (S, C, F) — faction networking. Sets up Lindbladian
	# drain/transfer/pump as abstracted faction contracts with other factions
	# (import/broker/export). Costs use social resources: basket 🧺,
	# handshake 🤝, scroll 📜. F=Tip is live across all sub-modes.
	# Sub-modes (1/2/3): thermal / dephase / damp — flavor only, same verbs.
	# =========================================================================
	FRAME_MERCHANT: {
		"name": "Merchant",
		"emoji": "🤝",
		"icon": "res://Assets/UI/Icon/Icon.svg",
		"time_scale": "discrete",
		"description": "Energy dyad (faction contracts) — Q sells/exports (extract), R buys/imports (invest), E reads the price (measure). Price = −kT·log p.",
		"modes": ["thermal", "dephase", "damp"],
		"mode_labels": ["~", ".", "|"],
		"mode_emojis": ["🌡", "💨", "🌊"],
		"pauses_sim": true,
		"actions": {
			"thermal": {
				"Q": {"action": "drain", "label": "Export", "emoji": "📤",
					  "icon": "res://Assets/UI/Tools/Lindblad/Decay.svg",
					  "hint": "Thermal export — local population flows out to a faction partner (costs 🧺 + south-pole)"},
				"E": {"action": "measure", "label": "Read Price", "emoji": "!",
					  "icon": "res://Assets/UI/Science/Measure.svg",
					  "hint": "Read the order-book price — collapse to a classical outcome (pauses the sim)"},
				"R": {"action": "pump", "label": "Import", "emoji": "📥",
					  "icon": "res://Assets/UI/Tools/Lindblad/Drive.svg",
					  "hint": "Thermal import — local population rises as a faction partner contributes (costs 📜 + north-pole)"},
				"F": {"action": "merchant_hint", "label": "Tip", "emoji": "💬",
					  "icon": "", "hint": "Whisper a hint to the player"}
			},
			"dephase": {
				"Q": {"action": "drain", "label": "Export", "emoji": "📤",
					  "icon": "res://Assets/UI/Tools/Lindblad/Decay.svg",
					  "hint": "Dephasing export — local coherence flows out to a faction partner (costs 🧺 + south-pole)"},
				"E": {"action": "measure", "label": "Read Price", "emoji": "!",
					  "icon": "res://Assets/UI/Science/Measure.svg",
					  "hint": "Read the order-book price — collapse to a classical outcome (pauses the sim)"},
				"R": {"action": "pump", "label": "Import", "emoji": "📥",
					  "icon": "res://Assets/UI/Tools/Lindblad/Drive.svg",
					  "hint": "Dephasing import — local coherence rises via partner phase contribution (costs 📜 + north-pole)"},
				"F": {"action": "merchant_hint", "label": "Tip", "emoji": "💬",
					  "icon": "", "hint": "Whisper a hint to the player"}
			},
			"damp": {
				"Q": {"action": "drain", "label": "Export", "emoji": "📤",
					  "icon": "res://Assets/UI/Tools/Lindblad/Decay.svg",
					  "hint": "Amplitude-damping export — local population drains to vacuum (costs 🧺 + south-pole)"},
				"E": {"action": "measure", "label": "Read Price", "emoji": "!",
					  "icon": "res://Assets/UI/Science/Measure.svg",
					  "hint": "Read the order-book price — collapse to a classical outcome (pauses the sim)"},
				"R": {"action": "pump", "label": "Import", "emoji": "📥",
					  "icon": "res://Assets/UI/Tools/Lindblad/Drive.svg",
					  "hint": "Amplitude-damping import — counter-rotate back toward excited (costs 📜 + north-pole)"},
				"F": {"action": "merchant_hint", "label": "Tip", "emoji": "💬",
					  "icon": "", "hint": "Whisper a hint to the player"}
			}
		}
	},

	# =========================================================================
	# CAPTAIN (W, C, F) — strategic decree. Now holds biome lifecycle only;
	# the signature/icon-injection sub-mode moved to Icon (5).
	# =========================================================================
	FRAME_CAPTAIN: {
		"name": "Captain",
		"emoji": "*",
		"icon": "res://Assets/UI/Icon/Icon.svg",
		"time_scale": "meta",
		"description": "Strategic decree — biome lifecycle (discover / cull)",
		"modes": ["biomes"],
		"mode_labels": ["Biomes"],
		"mode_emojis": ["🌍"],
		"pauses_sim": true,
		"actions": {
			"biomes": {
				"Q": {"action": "remove_biome", "label": "Cull Biome", "emoji": "💀",
					  "icon": "res://Assets/UI/Biome/BiomeClear.svg",
					  "hint": "Liquidate the active biome from its live quantum state and return it to the unexplored pool",
					  "destructive": true},
				"E": {"action": "forecast_biome_discovery", "label": "Compass", "emoji": "🧭",
					  "icon": "res://Assets/UI/Science/Explore.svg",
					  "hint": "Read the discovery compass — see which unexplored biomes your affinity is pulling toward"},
				"R": {"action": "discover_biome", "label": "Add Biome", "emoji": "🗺️",
					  "icon": "res://Assets/UI/Science/Explore.svg",
					  "hint": "Discover and load a new biome into the spindle"}
			}
		}
	},

	# =========================================================================
	# ACE (S, C, P) — the energy dyad. The default/wanderer archetype, now the
	# primary economic loop: Q extracts energy (Harvest, reward = −kT·log p),
	# R invests energy (Plant, injects population), E reads the price (Measure,
	# collapses + pauses). Selecting a plot auto-binds its terminal, so the old
	# "Explore" verb is gone — you pay to extract/invest, not to look.
	# =========================================================================
	FRAME_ACE: {
		"name": "Ace",
		"emoji": "O",
		"icon": "res://Assets/UI/Science/Measure.svg",
		"time_scale": "discrete",
		"description": "Energy dyad — Q harvests (extract), R plants (invest), E measures (read price)",
		"modes": ["probe"],
		"mode_labels": ["?"],
		"mode_emojis": ["?"],
		"pauses_sim": true,
		"actions": {
			"probe": {
				"Q": {"action": "pop", "label": "Harvest", "emoji": "^",
					  "icon": "res://Assets/UI/Science/Pop-Harvest.svg",
					  "hint": "Extract energy from the selected plot — reward = surprisal −kT·log p (rare outcome pays more). Ends the session.",
					  "shift_action": "pop", "shift_label": "Mass Harvest", "destructive": true},
				"E": {"action": "measure", "label": "Measure", "emoji": "!",
					  "icon": "res://Assets/UI/Science/Measure.svg",
					  "hint": "Read the price — collapse the state to a classical outcome (pauses the sim)"},
				"R": {"action": "spark_north", "label": "Plant", "emoji": "v",
					  "icon": "res://Assets/UI/Tools/Lindblad/Drive.svg",
					  "hint": "Invest energy into the selected plot — jolt population toward the north pole (spend 1× north-pole emoji)"}
			}
		}
	},

	# =========================================================================
	# OPERATOR (W, Q, F) — topology craft. Holds gate-building actions:
	# build / inspect / break entangling gates.
	# =========================================================================
	FRAME_OPERATOR: {
		"name": "Operator",
		"emoji": "⚙",
		"icon": "res://Assets/UI/Q-Bit/CNOT.svg",
		"time_scale": "discrete",
		"description": "Topology craft — build, inspect, and break entangling gates",
		"modes": ["gate"],
		"mode_labels": [")("],
		"mode_emojis": [")("],
		"pauses_sim": true,
		"actions": {
			"gate": {
				"Q": {"action": "remove_gates", "label": "Break", "emoji": "X",
					  "icon": "res://Assets/UI/Biome/BiomeClear.svg",
					  "hint": "Break entanglement", "destructive": true},
				"E": {"action": "inspect", "label": "Inspect", "emoji": "[]",
					  "icon": "res://Assets/UI/Science/Explore.svg",
					  "hint": "Inspect entanglement"},
				"R": {"action": "build_gate", "label": "Gate", "emoji": ")(",
					  "icon": "res://Assets/UI/Q-Bit/CNOT.svg",
					  "hint": "Build entangling gate",
					  "submenu": "gate_selection"}
			}
		}
	},

	# =========================================================================
	# DRUID (W, Q, P) — quantum priesthood. Holds the Unitary wiring after
	# the 2026-04-28 redistribution: X/Y/Z rotations + Hadamard.
	# =========================================================================
	FRAME_DRUID: {
		"name": "Druid",
		"emoji": "V",
		"icon": "res://Assets/UI/Q-Bit/Unitary.svg",
		"time_scale": "continuous",
		"description": "Quantum priesthood — reversible unitary gates",
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
	}
}

# =============================================================================
# RESOLUTION HELPER
# =============================================================================

# =============================================================================
# FRAME MANAGEMENT
# =============================================================================

static func select_frame(frame_name: String) -> bool:
	# Select an archetype frame by name. Empty string (FRAME_NULL) = no hat.
	if frame_name == FRAME_NULL or ARCHETYPE_FRAMES.has(frame_name):
		current_frame = frame_name
		return true
	push_error("ToolConfig: invalid frame '%s'" % frame_name)
	return false


static func cycle_frame(delta: int) -> void:
	# Step through FRAME_IDS by ±1, wrapping. Used by WASD layer crawl (A/D on frame layer).
	var idx := FRAME_IDS.find(current_frame)
	if idx < 0:
		idx = 0
	select_frame(FRAME_IDS[wrapi(idx + delta, 0, FRAME_IDS.size())])


static func get_current_frame() -> String:
	# Get the active archetype frame name. Empty string = Ace.
	return current_frame


static func get_frame(frame_name: String) -> Dictionary:
	# Get an archetype frame definition.
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
# SUB-MODE MANAGEMENT (1/2/3)
# =============================================================================

static func cycle_frame_mode(frame_name: String) -> int:
	# Cycle to the next sub-mode within a frame. Returns the new index, or
	# -1 if the frame has fewer than 2 modes.
	var def := get_frame(frame_name)
	var modes: Array = def.get("modes", [])
	if modes.size() < 2:
		return -1
	var current_index: int = int(frame_mode_indices.get(frame_name, 0))
	var new_index := (current_index + 1) % modes.size()
	frame_mode_indices[frame_name] = new_index
	return new_index


static func set_frame_mode(frame_name: String, mode_index: int) -> int:
	# Direct-jump to a specific sub-mode by index. Returns the index applied,
	# or -1 if out of range.
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
	var modes: Array = def.get("modes", [])
	if modes.is_empty():
		return ""
	if modes.size() == 1:
		return str(modes[0])
	var index: int = int(frame_mode_indices.get(frame_name, 0))
	return str(modes[index]) if index < modes.size() else ""


static func get_frame_mode_label(frame_name: String) -> String:
	var def := get_frame(frame_name)
	var labels: Array = def.get("mode_labels", [])
	if labels.is_empty():
		return ""
	var index: int = int(frame_mode_indices.get(frame_name, 0))
	return str(labels[index]) if index < labels.size() else ""


static func get_frame_mode_emoji(frame_name: String) -> String:
	var def := get_frame(frame_name)
	var emojis: Array = def.get("mode_emojis", [])
	if emojis.is_empty():
		return ""
	var index: int = int(frame_mode_indices.get(frame_name, 0))
	return str(emojis[index]) if index < emojis.size() else ""


static func reset_frame_modes() -> void:
	for key in frame_mode_indices:
		frame_mode_indices[key] = 0


# =============================================================================
# ACTION ACCESS
# =============================================================================

static func get_action(frame: String, key: String) -> Dictionary:
	# Get action definition for a frame and key (Q/E/R/F).

	# F is NOT auto-filled with mode-cycle info — mode cycling lives on Tab.
	# If a frame wants to bind F to something specific (e.g. Merchant hint),
	# it declares an explicit F slot under its current sub-mode. Otherwise
	# F returns {} and the action bar shows it sitting unused.
	var def := get_frame(frame)
	if def.is_empty():
		return {}
	var mode_name := get_frame_mode_name(frame)
	var mode_actions: Dictionary = def.get("actions", {}).get(mode_name, {})
	if mode_actions.is_empty():
		return def.get("actions", {}).get(key, {})
	return mode_actions.get(key, {})


static func get_action_label(frame: String, key: String) -> String:
	return get_action(frame, key).get("label", "")


static func get_action_emoji(frame: String, key: String) -> String:
	return get_action(frame, key).get("emoji", "")


static func get_action_name(frame: String, key: String) -> String:
	return get_action(frame, key).get("action", "")


static func get_action_icon(frame: String, key: String) -> String:
	return get_action(frame, key).get("icon", "")


static func get_all_actions(frame: String) -> Dictionary:
	var actions := {
		"Q": get_action(frame, "Q"),
		"E": get_action(frame, "E"),
		"R": get_action(frame, "R"),
	}
	var f_action := get_action(frame, "F")
	if not f_action.is_empty():
		actions["F"] = f_action
	return actions


static func has_explicit_f_action(frame: String) -> bool:
	# True when the frame declares an explicit F action in its current sub-mode.
	return not get_action(frame, "F").is_empty()
