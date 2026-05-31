class_name PlaneRegistry
extends RefCounted

## PlaneRegistry - Canonical plane/frame taxonomy for the farm instrument.
##
## Three physics-defined planes with explicit frame lists:
##
##   coherent    — reversible / near-unitary ops
##     frames: supports | single_qubit | links | two_qubit
##   dissipative — resource flow / channels
##     frames: sources_sinks | channels | routes | catalysts
##   probe       — reveal / measure / extract
##     frames: explore | measure | harvest
##
## The Captain, Icon, and Operator frames handle what was formerly called "Meta"
## (biome lifecycle, icon injection, gate building) — not physics planes. Their
## structural actions live in `Core/GameState/MacroActions.gd`.

# =============================================================================
# PLANES
# =============================================================================

const PLANE_COHERENT := "coherent"
const PLANE_DISSIPATIVE := "dissipative"
const PLANE_PROBE := "probe"

const PLANE_IDS := [PLANE_COHERENT, PLANE_DISSIPATIVE, PLANE_PROBE]

# =============================================================================
# FRAME IDS
# =============================================================================

# coherent plane
const FRAME_SUPPORTS := "supports"
const FRAME_SINGLE_QUBIT := "single_qubit"
const FRAME_LINKS := "links"
const FRAME_TWO_QUBIT := "two_qubit"

# dissipative plane
const FRAME_SOURCES_SINKS := "sources_sinks"
const FRAME_CHANNELS := "channels"
const FRAME_ROUTES := "routes"
const FRAME_CATALYSTS := "catalysts"

# probe plane
const FRAME_EXPLORE := "explore"
const FRAME_MEASURE := "measure"
const FRAME_HARVEST := "harvest"

# =============================================================================
# CANONICAL PLANE DEFINITIONS
# =============================================================================

const PLANES := {
	PLANE_COHERENT: {
		"plane_id": PLANE_COHERENT,
		"label": "Coherent",
		"description": "Reversible / near-unitary quantum operations",
		"frames": [FRAME_SUPPORTS, FRAME_SINGLE_QUBIT, FRAME_LINKS, FRAME_TWO_QUBIT],
	},
	PLANE_DISSIPATIVE: {
		"plane_id": PLANE_DISSIPATIVE,
		"label": "Dissipative",
		"description": "Resource flow, pump/drain, transfer, channels",
		"frames": [FRAME_SOURCES_SINKS, FRAME_CHANNELS, FRAME_ROUTES, FRAME_CATALYSTS],
	},
	PLANE_PROBE: {
		"plane_id": PLANE_PROBE,
		"label": "Probe",
		"description": "Reveal, measure, extract",
		"frames": [FRAME_EXPLORE, FRAME_MEASURE, FRAME_HARVEST],
	},
}

const PLANE_ACTIONS := {
	PLANE_COHERENT: [
		{
			"action_id": "q",
			"family": "action",
			"target_type": "plot",
			"enabled": true,
			"cost": {},
			"label": "-",
			"action": "rotate_down",
		},
		{
			"action_id": "e",
			"family": "action",
			"target_type": "plot",
			"enabled": true,
			"cost": {},
			"label": "H",
			"action": "hadamard",
		},
		{
			"action_id": "r",
			"family": "action",
			"target_type": "plot",
			"enabled": true,
			"cost": {},
			"label": "+",
			"action": "rotate_up",
		},
	],
	PLANE_DISSIPATIVE: [
		{
			"action_id": "q",
			"family": "action",
			"target_type": "plot",
			"enabled": true,
			"cost": {},
			"label": "Drain",
			"action": "drain",
		},
		{
			"action_id": "e",
			"family": "action",
			"target_type": "plot",
			"enabled": true,
			"cost": {},
			"label": "Xfer",
			"action": "transfer",
		},
		{
			"action_id": "r",
			"family": "action",
			"target_type": "plot",
			"enabled": true,
			"cost": {},
			"label": "Pump",
			"action": "pump",
		},
	],
	PLANE_PROBE: [
		{
			"action_id": "q",
			"family": "action",
			"target_type": "plot",
			"enabled": true,
			"cost": {},
			"label": "Explore",
			"action": "explore",
		},
		{
			"action_id": "e",
			"family": "action",
			"target_type": "plot",
			"enabled": true,
			"cost": {},
			"label": "Measure",
			"action": "measure",
		},
		{
			"action_id": "r",
			"family": "action",
			"target_type": "plot",
			"enabled": true,
			"cost": {},
			"label": "Pop",
			"action": "pop",
		},
	],
}

# =============================================================================
# FRAME LABELS (human-readable)
# =============================================================================

const FRAME_LABELS := {
	FRAME_SUPPORTS: "Supports",
	FRAME_SINGLE_QUBIT: "Single-Qubit",
	FRAME_LINKS: "Links",
	FRAME_TWO_QUBIT: "Two-Qubit",
	FRAME_SOURCES_SINKS: "Sources/Sinks",
	FRAME_CHANNELS: "Channels",
	FRAME_ROUTES: "Routes",
	FRAME_CATALYSTS: "Catalysts",
	FRAME_EXPLORE: "Explore",
	FRAME_MEASURE: "Measure",
	FRAME_HARVEST: "Harvest",
}

# =============================================================================
# QUERIES
# =============================================================================

static func get_plane(plane_id: String) -> Dictionary:
	return PLANES.get(plane_id, {})


static func get_frames(plane_id: String) -> Array:
	return get_plane(plane_id).get("frames", [])


static func get_actions(plane_id: String, _frame_id: String = "") -> Array:
	var actions: Array = []
	for action in PLANE_ACTIONS.get(plane_id, []):
		actions.append(action.duplicate(true))
	return actions


static func plane_label(plane_id: String) -> String:
	return get_plane(plane_id).get("label", plane_id)


static func frame_label(frame_id: String) -> String:
	return FRAME_LABELS.get(frame_id, frame_id)


## Returns the next frame id within a plane, wrapping. Null if plane unknown.
static func cycle_frame(plane_id: String, current_frame_id: String, step: int = 1) -> String:
	var frames := get_frames(plane_id)
	if frames.is_empty():
		return ""
	var idx := frames.find(current_frame_id)
	if idx < 0:
		return frames[0]
	return frames[posmod(idx + step, frames.size())]


## Map active archetype frame to surface plane (post 2026-04-28 redistribution).
## - Druid / Operator → coherent (unitary gates + entangling-gate craft)
## - Spark → dissipative (Lindblad drain / transfer / pump)
## - Ace → probe (explore / measure / harvest)
## - Icon / Captain / Merchant → "" (meta / quest layer, owned by M / C)
## - Null hat ("") → ""
static func plane_id_from_frame(frame_name: String) -> String:
	match frame_name:
		"druid", "operator": return PLANE_COHERENT
		"spark": return PLANE_DISSIPATIVE
		"ace": return PLANE_PROBE
		_: return ""
