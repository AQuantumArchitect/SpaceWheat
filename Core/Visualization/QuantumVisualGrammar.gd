class_name QuantumVisualGrammar
extends RefCounted

## Single source of truth for visual-channel ownership.
##
## Renderers draw these named channels. They should not invent new meanings for
## size, alpha, angle, or motion locally. If a new visual effect needs a channel,
## add it here first so it can be compared against the existing grammar.

enum MotionPolicy {
	FORBIDDEN_AMBIENT,
	STATE_SMOOTH,
	EVENT_BOUND,
	FLOW_ADVECTED,
	STATIC
}

const MOTION_POLICY_NAMES := {
	MotionPolicy.FORBIDDEN_AMBIENT: "forbidden_ambient",
	MotionPolicy.STATE_SMOOTH: "state_smooth",
	MotionPolicy.EVENT_BOUND: "event_bound",
	MotionPolicy.FLOW_ADVECTED: "flow_advected",
	MotionPolicy.STATIC: "static",
}

const CHANNEL_BUBBLE_RADIUS := "bubble.radius"
const CHANNEL_BUBBLE_EMOJI_OPACITY := "bubble.emoji_opacity"
const CHANNEL_BUBBLE_COLOR_PHASE := "bubble.color_phase"
const CHANNEL_BUBBLE_PHASE_ARC := "bubble.phase_arc"
const CHANNEL_BUBBLE_COHERENCE_SPIN := "bubble.coherence_spin"
const CHANNEL_BUBBLE_PURITY_RING := "bubble.purity_ring"
const CHANNEL_BUBBLE_UNCERTAINTY_RING := "bubble.uncertainty_ring"
const CHANNEL_BUBBLE_MEASURED_MARK := "bubble.measured_mark"
const CHANNEL_FIELD_SELF_ENERGY_CONTOUR := "field.self_energy_contour"
const CHANNEL_FIELD_DECOHERENCE_HEAT := "field.decoherence_heat"
const CHANNEL_FIELD_ORBIT_TRAIL := "field.orbit_trail"
const CHANNEL_EDGE_MUTUAL_INFORMATION := "edge.mutual_information"
const CHANNEL_EDGE_HAMILTONIAN_STRAND := "edge.hamiltonian_strand"
const CHANNEL_EDGE_LINDBLAD_FLOW := "edge.lindblad_flow"
const CHANNEL_EDGE_ENTANGLEMENT := "edge.entanglement"
const CHANNEL_INFRA_GATE_TOPOLOGY := "infra.gate_topology"
const CHANNEL_EVENT_DEATH := "event.death"
const CHANNEL_EVENT_COHERENCE_STRIKE := "event.coherence_strike"

const CHANNELS := {
	CHANNEL_BUBBLE_RADIUS: {
		"owner": "BatchedBubbleRenderer",
		"source": "Bloch subspace radius",
		"motion_policy": MotionPolicy.STATE_SMOOTH,
		"rule": "Body size follows subspace radius only; purity is shown elsewhere.",
	},
	CHANNEL_BUBBLE_EMOJI_OPACITY: {
		"owner": "BatchedBubbleRenderer",
		"source": "normalized north/south measurement probability",
		"motion_policy": MotionPolicy.STATE_SMOOTH,
		"rule": "Opacity belongs to measurement probability, not ambient animation.",
	},
	CHANNEL_BUBBLE_COLOR_PHASE: {
		"owner": "BatchedBubbleRenderer",
		"source": "Bloch phi and coherence magnitude",
		"motion_policy": MotionPolicy.STATE_SMOOTH,
		"rule": "Hue and saturation are phase/coherence readouts.",
	},
	CHANNEL_BUBBLE_PHASE_ARC: {
		"owner": "BatchedBubbleRenderer",
		"source": "Bloch phi",
		"motion_policy": MotionPolicy.STATE_SMOOTH,
		"rule": "Angular expression is reserved for phi.",
	},
	CHANNEL_BUBBLE_COHERENCE_SPIN: {
		"owner": "BatchedBubbleRenderer",
		"source": "Bloch phi and coherence magnitude",
		"motion_policy": MotionPolicy.STATE_SMOOTH,
		"rule": "Internal spin may follow phi; do not use it for self-energy.",
	},
	CHANNEL_BUBBLE_PURITY_RING: {
		"owner": "BatchedBubbleRenderer",
		"source": "node purity",
		"motion_policy": MotionPolicy.STATE_SMOOTH,
		"rule": "Purity has its own ring or halo; do not fold it back into radius.",
	},
	CHANNEL_BUBBLE_UNCERTAINTY_RING: {
		"owner": "BatchedBubbleRenderer",
		"source": "2 * sqrt(p_north * p_south)",
		"motion_policy": MotionPolicy.STATE_SMOOTH,
		"rule": "Ring thickness belongs to measurement uncertainty.",
	},
	CHANNEL_BUBBLE_MEASURED_MARK: {
		"owner": "BatchedBubbleRenderer",
		"source": "terminal measured state",
		"motion_policy": MotionPolicy.STATIC,
		"rule": "Measured status is a stable mark, not a pulse.",
	},
	CHANNEL_FIELD_SELF_ENERGY_CONTOUR: {
		"owner": "QuantumProjectionFieldRenderer",
		"source": "Hamiltonian diagonal self_energy and self_energy_driver",
		"motion_policy": MotionPolicy.STATE_SMOOTH,
		"rule": "Self-energy is terrain/contour membership, not bubble body breathing.",
	},
	CHANNEL_FIELD_DECOHERENCE_HEAT: {
		"owner": "QuantumRegionRenderer",
		"source": "sink flux",
		"motion_policy": MotionPolicy.STATE_SMOOTH,
		"rule": "Background heat follows dissipative pressure.",
	},
	CHANNEL_FIELD_ORBIT_TRAIL: {
		"owner": "QuantumRegionRenderer",
		"source": "node position history",
		"motion_policy": MotionPolicy.STATE_SMOOTH,
		"rule": "Trails show actual graph evolution.",
	},
	CHANNEL_EDGE_MUTUAL_INFORMATION: {
		"owner": "QuantumEdgeRenderer",
		"source": "mutual information I(A:B)",
		"motion_policy": MotionPolicy.STATE_SMOOTH,
		"rule": "MI binds clusters and petals.",
	},
	CHANNEL_EDGE_HAMILTONIAN_STRAND: {
		"owner": "QuantumEdgeRenderer",
		"source": "Hamiltonian coupling",
		"motion_policy": MotionPolicy.STATIC,
		"rule": "Unitary structure is a stable strand unless source data changes.",
	},
	CHANNEL_EDGE_LINDBLAD_FLOW: {
		"owner": "QuantumEdgeRenderer",
		"source": "Lindblad outgoing rates",
		"motion_policy": MotionPolicy.FLOW_ADVECTED,
		"rule": "Motion is allowed when it reads as current along a directed flow.",
	},
	CHANNEL_EDGE_ENTANGLEMENT: {
		"owner": "QuantumEdgeRenderer",
		"source": "explicit entanglement metadata",
		"motion_policy": MotionPolicy.STATE_SMOOTH,
		"rule": "Width/color may follow strength; ambient pulsing should be removed.",
	},
	CHANNEL_INFRA_GATE_TOPOLOGY: {
		"owner": "QuantumInfraRenderer",
		"source": "active plot gates",
		"motion_policy": MotionPolicy.STATIC,
		"rule": "Gate infrastructure is topology/status, not ambient line breathing.",
	},
	CHANNEL_EVENT_DEATH: {
		"owner": "QuantumEffectsRenderer",
		"source": "death event",
		"motion_policy": MotionPolicy.EVENT_BOUND,
		"rule": "Transient motion is allowed only while the event is active.",
	},
	CHANNEL_EVENT_COHERENCE_STRIKE: {
		"owner": "QuantumEffectsRenderer",
		"source": "coherence strike event",
		"motion_policy": MotionPolicy.EVENT_BOUND,
		"rule": "Transient motion is allowed only while the event is active.",
	},
}


static func get_channel(channel_id: String) -> Dictionary:
	return CHANNELS.get(channel_id, {})


static func get_motion_policy(channel_id: String) -> int:
	return int(get_channel(channel_id).get("motion_policy", MotionPolicy.FORBIDDEN_AMBIENT))


static func get_motion_policy_name(channel_id: String) -> String:
	return MOTION_POLICY_NAMES.get(get_motion_policy(channel_id), "unknown")


static func is_ambient_motion_allowed(channel_id: String) -> bool:
	return get_motion_policy(channel_id) != MotionPolicy.FORBIDDEN_AMBIENT


static func get_channel_summary() -> Array:
	var out: Array = []
	var keys := CHANNELS.keys()
	keys.sort()
	for channel_id in keys:
		var channel: Dictionary = CHANNELS[channel_id]
		out.append({
			"id": channel_id,
			"owner": channel.get("owner", ""),
			"source": channel.get("source", ""),
			"motion_policy": MOTION_POLICY_NAMES.get(channel.get("motion_policy", MotionPolicy.FORBIDDEN_AMBIENT), "unknown"),
			"rule": channel.get("rule", ""),
		})
	return out
