class_name BalanceConfig
extends RefCounted

## BalanceConfig - Runtime/default balance profile resolver.
## Canonical profile lives in GameState.balance_workbench_config.

const DEFAULTS: Dictionary = {
	"profile_id": "default",
	"display_name": "Default Runtime Balance",
	"action_roi_notes": {},
	"quest_reward_notes": {},
	"economy_variables": {
		"quantum_to_credits": 1.0,
		"max_biome_qubits": 12
	},
	"tuning": {
		"pop_base_yield_scale": 13.0,
		"reap_base_yield": 8.0,
		"reap_evolution_cycles": 13,
		"flux_to_credits": 1.0,
		"reap_cost_sequence": [1, 1, 2, 3, 5, 8, 13, 21],
		"reap_starting_tokens": 6,
		"measurement_drain_base": 0.15
	},
	# Physics balance — controls how quantum dynamics feel to the player.
	# Hamiltonian drives fast visible oscillation (seconds).
	# Lindblad drives slow irreversible flow (minutes).
	# The ratio H/L determines whether the player sees lively oscillation
	# (high ratio) or sluggish drift (low ratio).
	"physics": {
		# TWO INDEPENDENT PHYSICS GENERATORS — the master switches. The quantum state
		# evolves under the Lindblad master equation dρ/dt = −i[H,ρ] + Σ_k D[L_k]ρ; each
		# generator is gated on/off independently for clean isolation:
		#   coherent_dynamics    → the −i[H,ρ] term  (Hamiltonian / unitary evolution)
		#   dissipative_dynamics → the Σ D[L_k] term (Lindblad pump / drain / decay)
		# The game ships COHERENT-ONLY (the closed, unitary system): every bubble stays
		# pure (r = 1) forever and H alone re-spreads a collapsed qubit (time + H is the
		# pump). Turn dissipative on for the open-quantum DLC. Turn coherent off to study
		# pure Lindbladian relaxation. The point of the switches is that the game runs
		# correctly in the ABSENCE of either generator. See docs/CLOSED_SYSTEM.md.
		"coherent_dynamics": true,
		"dissipative_dynamics": false,
		# Global multiplier for all Lindblad rates from biomes.json. Only bites when
		# dissipative_dynamics = true. Rates were baked at the intended scale in the JSON.
		"lindblad_rate_scale": 1.0,
		# Global multiplier for all Hamiltonian off-diagonal couplings (rabi + cross-icon)
		# from icons.json — the one physical dial of the closed system. 1.0 = identity.
		"hamiltonian_coupling_scale": 1.0,
	}
}


## Runtime override for physics knobs (set by the reservoir sweep / tuning tools).
## Merged on top of DEFAULTS, under any explicit config passed to get_physics —
## so parametric retuning (e.g. hamiltonian_coupling_scale, lindblad_rate_scale)
## takes effect on the next operator rebuild without editing the constant.
static var _physics_override: Dictionary = {}


static func set_physics_override(overrides) -> void:
	_physics_override = overrides.duplicate(true) if overrides is Dictionary else {}


static func clear_physics_override() -> void:
	_physics_override = {}


## Convenience accessor for physics balance parameters.
## Precedence: DEFAULTS < live override < explicit `config.physics`.
static func get_physics(config: Dictionary = {}) -> Dictionary:
	var result = DEFAULTS.get("physics", {}).duplicate(true)
	for key in _physics_override.keys():
		result[key] = _physics_override[key]
	var overrides = config.get("physics", {})
	for key in overrides.keys():
		result[key] = overrides[key]
	return result


## Is the coherent (Hamiltonian / unitary von-Neumann) generator active? Default true.
static func coherent_enabled(config: Dictionary = {}) -> bool:
	return bool(get_physics(config).get("coherent_dynamics", true))


## Is the dissipative (Lindblad pump/drain/decay) generator active? Default false.
## This is THE predicate for every open-system mechanism: Lindblad operators, weak/drain
## measurement, the entropy-bank reap, the Spark/Merchant tools, drain/pump actions, and
## the dissipative UI readouts. Flip it on for the open-quantum DLC.
static func dissipative_enabled(config: Dictionary = {}) -> bool:
	return bool(get_physics(config).get("dissipative_dynamics", false))


## "Closed system" = pure unitary: coherent on, dissipative off. The default game.
## Used for the exact-unitary evolution kernel and the pure ground-state init — the
## places that specifically require r = 1. Honours get_physics precedence
## (DEFAULTS < live override < explicit config), so tuning tools can flip it freely.
static func is_closed_system(config: Dictionary = {}) -> bool:
	return coherent_enabled(config) and not dissipative_enabled(config)


static func load_default_config(state = null) -> Dictionary:
	if state and ("balance_workbench_config" in state):
		var state_cfg = state.balance_workbench_config
		if state_cfg is Dictionary and not state_cfg.is_empty():
			return merge_with_defaults(state_cfg)
	return DEFAULTS.duplicate(true)


static func merge_with_defaults(raw: Dictionary) -> Dictionary:
	var merged = DEFAULTS.duplicate(true)
	if not (raw is Dictionary):
		return merged
	if raw.has("profile_id"):
		merged["profile_id"] = str(raw.get("profile_id", "default"))
	if raw.has("display_name"):
		merged["display_name"] = str(raw.get("display_name", "Default Runtime Balance"))
	for key in [
		"action_roi_notes",
		"quest_reward_notes",
		"economy_variables",
		"tuning",
		"action_costs",
		"gate_costs",
		"quest_rewards",
		"production"
	]:
		var block = raw.get(key, null)
		if block is Dictionary:
			var dest = merged.get(key, {}).duplicate(true)
			for sub_key in block.keys():
				dest[str(sub_key)] = block[sub_key]
			merged[key] = dest
	for key in raw.keys():
		var normalized = str(key)
		if not merged.has(normalized):
			merged[normalized] = raw[key]
	return merged


static func load_config(path: String) -> Dictionary:
	# Legacy import path support for existing tooling.
	if path == "" or not FileAccess.file_exists(path):
		return DEFAULTS.duplicate(true)
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return DEFAULTS.duplicate(true)
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return DEFAULTS.duplicate(true)
	return merge_with_defaults(parsed)
