extends RefCounted

## ToolConfig — Archetype Frame configuration.
##
## Top of the keyboard hierarchy is now the **archetype hat row** (4-0).
## Each hat picks a frame; 1/2/3 picks a sub-mode within that frame; QERF
## is the four-chip primary action row. See `docs/ARCHETYPE_FRAMES.md`.
##
## | Hat | Frame      | Live wiring                                    |
## |-----|------------|------------------------------------------------|
## |  4  | Spark      | Lindblad jolt (wet country) / Majorana bridges |
## |  5  | Icon       | Icon injection (player faction signature)      |
## |  6  | Merchant   | Bath contracts: thermal / dephase / damp       |
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
	# SPARK (S, Q, P) — casting moment. Spend the pole emoji (surprisal-priced)
	# to instantly shove the qubit toward that pole: a strong ONE-SHOT Lindblad
	# pulse. The dissipative kick can re-purify a faded qubit — the thing no
	# unitary (Ace Plant, Druid) can do. Openness is a place: the jolt fires
	# only where the biome's regime runs open (wet country); the enclave holds.
	# Q = push toward south pole  |  R = push toward north pole
	# Mode 2 (🌉 bridge): Majorana spans — nonlocal storage between two biomes
	# (BridgeRegister; What Connects). R anchors, F braids, Q fuses, E inspects.
	# Bridge verbs work in any regime — the span is the anti-Lindblad artifact.
	# =========================================================================
	FRAME_SPARK: {
		"name": "Spark",
		"emoji": "⚡",
		"icon": "res://Assets/UI/Tools/Lindblad/Lindblad.svg",
		"time_scale": "dissipative",
		"description": "Energy dyad (Lindblad jolt, wet country only) — Q discharges south (out), R charges north (invest). The kick that can re-purify. Mode 2: Majorana bridges (any regime).",
		"modes": ["shift", "bridge"],
		"mode_labels": ["⚡", "🌉"],
		"mode_emojis": ["⚡", "🌉"],
		"pauses_sim": false,
		"actions": {
			"shift": {
				"Q": {"action": "spark_south", "label": "S.Pole", "emoji": "↓",
					  "icon": "res://Assets/UI/Tools/Lindblad/Decay.svg",
					  "hint": "One-shot Lindblad kick toward south (spend south-pole emoji, surprisal-priced). Dissipative — it re-purifies. Open country only: the enclave holds."},
				"E": {"action": "jolt_inspect", "label": "Gauge", "emoji": "🔍", "icon": "",
					  "hint": "Read the jolt — pole odds, Bloch radius, the biome's kT, and what each direction would cost here"},
				"R": {"action": "spark_north", "label": "N.Pole", "emoji": "↑",
					  "icon": "res://Assets/UI/Tools/Lindblad/Drive.svg",
					  "hint": "One-shot Lindblad kick toward north (spend north-pole emoji, surprisal-priced). Dissipative — it re-purifies. Open country only: the enclave holds."}
			},
			"bridge": {
				"Q": {"action": "bridge_fuse", "label": "Fuse", "emoji": "⚛",
					  "icon": "res://Assets/UI/Science/Measure.svg",
					  "hint": "Fuse a bridge anchored here — Born-sample the joint parity, paid in surprisal. Reading the bridge spends it.",
					  "destructive": true},
				"E": {"action": "bridge_inspect", "label": "Inspect", "emoji": "🔍", "icon": "",
					  "hint": "Read the bridge card — span, parity odds, live Γ (the product of both shores' wet rates), age, braids"},
				"R": {"action": "bridge_anchor", "label": "Span", "emoji": "⚓",
					  "icon": "res://Assets/UI/Biome/BiomeAssign.svg",
					  "hint": "Anchor a span on the focused qubit. Anchor a second shore in another biome to raise the bridge."},
				"F": {"action": "bridge_braid", "label": "Braid", "emoji": "🪢", "icon": "",
					  "hint": "Braid the end-modes at this shore — S here, √X on the far shore. The braid alphabet is Clifford only."}
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
	# MERCHANT (S, C, F) — standing contracts with the country you stand in.
	# Each sub-mode (1/2/3) IS one of the three canonical qubit channels:
	#   thermal 🌡 — detailed-balance pair (generalized amplitude damping):
	#                net flow the direction you chose, but the back-rate keeps
	#                the plot MIXED — the biome stays warm, the reap bank lives.
	#   dephase 💨 — pure phase damping: coherence out, populations untouched.
	#                Export only — decoherence is irreversible; no contract can
	#                sell your phase back. Pays deferred: kT rises with entropy.
	#   damp    🌊 — one-way amplitude damping: pins the pole hard. Maximum
	#                extraction, and it cools the biome toward purity.
	# The counterparty is the Bath itself — a Lindblad channel's other end is
	# the environment, by definition. Your wallet is the ledger. Costs use
	# social fees (🧺 export, 📜 import) + the surprisal-priced pole stake.
	# Openness is a place: contracts run only where the regime is open.
	# Q exports (channel out) · E reads the price · R imports · F settles.
	# =========================================================================
	FRAME_MERCHANT: {
		"name": "Merchant",
		"emoji": "🤝",
		"icon": "res://Assets/UI/Icon/Icon.svg",
		"time_scale": "discrete",
		"description": "Standing contracts (wet country only) — Q exports, E reads the price, R imports, F settles. Modes 1/2/3 pick the channel: thermal / dephase / damp. Price = −kT·log p.",
		"modes": ["thermal", "dephase", "damp"],
		"mode_labels": ["~", ".", "|"],
		"mode_emojis": ["🌡", "💨", "🌊"],
		"pauses_sim": true,
		"actions": {
			"thermal": {
				"Q": {"action": "drain", "label": "Export", "emoji": "📤",
					  "icon": "res://Assets/UI/Tools/Lindblad/Decay.svg",
					  "hint": "Thermal export — couple the plot to a colder reservoir: population flows out at detailed balance, credited to your wallet as it drains (costs 🧺 + south-pole stake). The back-rate keeps the plot warm — the reap bank survives."},
				"E": {"action": "read_price", "label": "Price", "emoji": "!",
					  "icon": "res://Assets/UI/Science/Measure.svg",
					  "hint": "Read the order book — pole odds, the biome's kT, unit prices both directions, and how your standing with the native faction moves them"},
				"R": {"action": "pump", "label": "Import", "emoji": "📥",
					  "icon": "res://Assets/UI/Tools/Lindblad/Drive.svg",
					  "hint": "Thermal import — couple to a hotter reservoir: population flows in at detailed balance (costs 📜 + north-pole stake). The gentle way in: arrives warm, never pinned."},
				"F": {"action": "settle", "label": "Settle", "emoji": "✔",
					  "icon": "", "hint": "Close the contract — remove the standing channel on the selected plot(s). The ledger keeps what already moved."}
			},
			"dephase": {
				"Q": {"action": "drain", "label": "Export", "emoji": "📤",
					  "icon": "res://Assets/UI/Tools/Lindblad/Decay.svg",
					  "hint": "Sell your phase to the noise — coherence drains, populations untouched (costs 🧺 only). Nothing lands in the wallet: the biome runs hotter, and the season's reap pays kT·ΔS on the entropy you grew."},
				"E": {"action": "read_price", "label": "Price", "emoji": "!",
					  "icon": "res://Assets/UI/Science/Measure.svg",
					  "hint": "Read the order book — pole odds, the biome's kT, unit prices both directions, and how your standing with the native faction moves them"},
				"R": {"action": "", "label": "—", "emoji": "🚫", "icon": "",
					  "hint": "No contract can sell you back your phase — decoherence is irreversible. Coherence returns only through your own gates (Druid, 0).",
					  "disabled": true},
				"F": {"action": "settle", "label": "Settle", "emoji": "✔",
					  "icon": "", "hint": "Close the contract — remove the standing channel on the selected plot(s). The ledger keeps what already moved."}
			},
			"damp": {
				"Q": {"action": "drain", "label": "Export", "emoji": "📤",
					  "icon": "res://Assets/UI/Tools/Lindblad/Decay.svg",
					  "hint": "Damping export — one-way drain to the south sink, credited as it flows (costs 🧺 + south-pole stake). Maximum extraction: pins the plot cold and starves the reap bank."},
				"E": {"action": "read_price", "label": "Price", "emoji": "!",
					  "icon": "res://Assets/UI/Science/Measure.svg",
					  "hint": "Read the order book — pole odds, the biome's kT, unit prices both directions, and how your standing with the native faction moves them"},
				"R": {"action": "pump", "label": "Import", "emoji": "📥",
					  "icon": "res://Assets/UI/Tools/Lindblad/Drive.svg",
					  "hint": "Damping import — one-way pump toward north (costs 📜 + north-pole stake). Pins the pole hard: purity rises, the heat dies."},
				"F": {"action": "settle", "label": "Settle", "emoji": "✔",
					  "icon": "", "hint": "Close the contract — remove the standing channel on the selected plot(s). The ledger keeps what already moved."}
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
	# ACE — the player-character vantage. The ONLY hat that works in every mode
	# (open/closed/classical/quantum) because it uses the one universal operation:
	# measurement. You watch the substrate spin and scrub time (E pause / F
	# fast-forward), then STRIKE (R) to collapse a register into a classical
	# outcome, and EXTRACT (Q) the reward. Selection is a free, transient cursor
	# move — the strike binds the terminal it needs (view renders from the QC).
	# The energy dyad (Plant/invest) was open-system-only; it lives on Spark (DLC).
	# R is a resolve() seam: today it collapses + rewards, later it dispatches into
	# the biome's mini-game (collapsed state = context, score = reward).
	# =========================================================================
	FRAME_ACE: {
		"name": "Ace",
		"emoji": "O",
		"icon": "res://Assets/UI/Science/Measure.svg",
		"time_scale": "discrete",
		"description": "Player vantage — E pauses / F fast-forwards (scrub the odds), R strikes (collapse), Q extracts the reward",
		"modes": ["probe"],
		"mode_labels": ["?"],
		"mode_emojis": ["?"],
		"pauses_sim": true,
		"actions": {
			"probe": {
				"Q": {"action": "pop", "label": "Extract", "emoji": "^",
					  "icon": "res://Assets/UI/Science/Pop-Harvest.svg",
					  "hint": "Cash out — pull the realized reward off a collapsed register into inventory. Reward = surprisal −kT·log p (rare collapse pays more).",
					  "shift_action": "pop", "shift_label": "Mass Extract"},
				"E": {"action": "", "label": "Pause", "emoji": "⏸",
					  "icon": "",
					  "hint": "Pause — freeze time to read the odds (global side-effect; no tool verb)",
					  "disabled": true},
				"R": {"action": "measure", "label": "Strike", "emoji": "!",
					  "icon": "res://Assets/UI/Science/Measure.svg",
					  "hint": "Strike — collapse the selected register to one classical outcome (resolve the biome). The strike binds the terminal it needs."},
				"F": {"action": "fast_forward", "label": "Fast-Fwd", "emoji": "⏩",
					  "icon": "",
					  "hint": "Fast-forward — let the Hamiltonian spin the odds (advance time). Also resumes play."}
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

## Openness is a place, not a setting: every hat is always selectable. The
## Lindblad verbs (Spark jolt, Merchant contracts) refuse per-plot wherever the
## target biome's regime runs closed — QuantumInstrument checks is_open_here()
## on the actual ground, and the chips grey honestly via ActionValidator. The
## keyboard is never sealed; the world decides.
static func is_frame_available(_frame_name: String) -> bool:
	return true


## Frames selectable in the current system mode, in FRAME_IDS order.
static func available_frame_ids() -> Array:
	var out: Array = []
	for fid in FRAME_IDS:
		if is_frame_available(fid):
			out.append(fid)
	return out


static func select_frame(frame_name: String) -> bool:
	# Select an archetype frame by name. Empty string (FRAME_NULL) = no hat.
	# Every frame is always selectable — regime gating lives on the verbs, not the hats.
	if frame_name == FRAME_NULL:
		current_frame = frame_name
		return true
	if ARCHETYPE_FRAMES.has(frame_name):
		if not is_frame_available(frame_name):
			return false
		current_frame = frame_name
		return true
	push_error("ToolConfig: invalid frame '%s'" % frame_name)
	return false


static func cycle_frame(delta: int) -> void:
	# Step through the frames by ±1, wrapping.
	# Used by WASD layer crawl (A/D on frame layer).
	var ids := available_frame_ids()
	if ids.is_empty():
		return
	var idx := ids.find(current_frame)
	if idx < 0:
		idx = 0
	select_frame(ids[wrapi(idx + delta, 0, ids.size())])


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
