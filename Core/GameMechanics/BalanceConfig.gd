class_name BalanceConfig
extends RefCounted

## BalanceConfig - Runtime/default balance profile resolver.
## Canonical profile lives in GameState.balance_workbench_config.

# ── SINGLE SOURCE OF TRUTH for every scalar balance knob ───────────────────────────
# One row per tunable: its default value AND its board edit-metadata live here together.
# DEFAULTS and the in-game balance board are both DERIVED from this list, so adding or
# retuning a knob is a one-line change in ONE place (no more editing DEFAULTS + the board
# + default.jsonl separately). `root` places it in the config tree (tuning /
# economy_variables / physics). `board:false` keeps it out of the editor (e.g. arrays).
# `open_only:true` hides it in the closed (Hamiltonian-only) system. The economy roots
# (tuning / economy_variables) are mirrored in Core/Config/FarmVariableGraph/default.jsonl
# (the canonical runtime source, loaded at boot); physics knobs live here only.
const TUNABLES: Array = [
	# root, key, default, board metadata
	{"root": "tuning", "key": "pop_base_yield_scale", "default": 13.0, "label": "Pop yield scale", "category": "Yield", "kind": "float", "step": 0.5, "min": 0.5, "max": 50.0},
	{"root": "tuning", "key": "reap_base_yield", "default": 8.0, "label": "Reap base yield", "category": "Yield", "kind": "float", "step": 0.5, "min": 0.5, "max": 50.0},
	{"root": "tuning", "key": "reap_evolution_cycles", "default": 13, "label": "Reap evolve cycles", "category": "Physics", "kind": "int", "step": 1, "min": 1, "max": 60},
	{"root": "tuning", "key": "flux_to_credits", "default": 1.0, "label": "Flux → credits", "category": "Economy", "kind": "float", "step": 0.1, "min": 0.1, "max": 10.0, "open_only": true},
	{"root": "tuning", "key": "reap_cost_sequence", "default": [1, 1, 2, 3, 5, 8, 13, 21], "board": false},
	{"root": "tuning", "key": "reap_starting_tokens", "default": 6, "label": "Reap start tokens", "category": "Yield", "kind": "int", "step": 1, "min": 0, "max": 30},
	{"root": "tuning", "key": "measurement_drain_base", "default": 0.15, "label": "Measurement drain", "category": "Yield", "kind": "float", "step": 0.05, "min": 0.0, "max": 1.0, "open_only": true},
	# Market scarcity temperature kT (Boltzmann E = −kT·log p).
	{"root": "tuning", "key": "market_temperature", "default": 10.0, "label": "Market kT", "category": "Market", "kind": "float", "step": 0.5, "min": 1.0, "max": 30.0},
	{"root": "tuning", "key": "market_temperature_entropy_gain", "default": 1.0, "label": "Market kT entropy gain", "category": "Market", "kind": "float", "step": 0.1, "min": 0.0, "max": 5.0},
	# Incorporation-reward multiplier — the escape from the resource spiral. Harvesting a
	# register whose ICON is in your signature boosts its yield:
	# mult = (r + (incorporated ? signature_r_bonus : 0)) ^ exponent; closed (r=1)
	# → incorporated ×4 / not ×1; open (r<1) → a curve. See ProbeActions._incorporation_reward_multiplier.
	{"root": "tuning", "key": "signature_r_bonus", "default": 1.0, "label": "Signature r-bonus", "category": "Signature", "kind": "float", "step": 0.25, "min": 0.0, "max": 4.0},
	{"root": "tuning", "key": "signature_reward_exponent", "default": 2.0, "label": "Signature exponent", "category": "Signature", "kind": "float", "step": 0.25, "min": 1.0, "max": 4.0},
	{"root": "economy_variables", "key": "quantum_to_credits", "default": 1.0, "label": "Quantum → credits", "category": "Economy", "kind": "float", "step": 0.1, "min": 0.1, "max": 10.0},
	{"root": "economy_variables", "key": "max_biome_qubits", "default": 6, "label": "Max biome qubits", "category": "Physics", "kind": "int", "step": 1, "min": 4, "max": 24},
	# Physics scalars (the H/L dials). lindblad_rate_scale only bites when dissipative;
	# hamiltonian_coupling_scale is the one physical dial of the closed system (1.0 = identity).
	{"root": "physics", "key": "lindblad_rate_scale", "default": 1.0, "label": "Lindblad rate", "category": "Physics", "kind": "float", "step": 0.1, "min": 0.1, "max": 5.0, "open_only": true},
	{"root": "physics", "key": "hamiltonian_coupling_scale", "default": 1.0, "label": "Hamiltonian coupling", "category": "Physics", "kind": "float", "step": 0.1, "min": 0.1, "max": 5.0},
]

# Structural defaults that are NOT scalar knobs (the H/L master switches + note blocks).
# The two generators are gated independently for clean isolation: coherent_dynamics →
# −i[H,ρ] (unitary), dissipative_dynamics → Σ D[L_k] (Lindblad). The game ships
# COHERENT-ONLY (closed/unitary, r=1 forever; time+H is the pump). See docs/CLOSED_SYSTEM.md.
const _STRUCTURAL: Dictionary = {
	"profile_id": "default",
	"display_name": "Default Runtime Balance",
	"action_roi_notes": {},
	"quest_reward_notes": {},
	"physics_switches": {
		"coherent_dynamics": true,
		"dissipative_dynamics": false,
	},
}

## DEFAULTS is DERIVED from TUNABLES + _STRUCTURAL — never hand-maintained.
static var DEFAULTS: Dictionary = _build_defaults()


static func _build_defaults() -> Dictionary:
	var d: Dictionary = {
		"profile_id": _STRUCTURAL["profile_id"],
		"display_name": _STRUCTURAL["display_name"],
		"action_roi_notes": {},
		"quest_reward_notes": {},
		"economy_variables": {},
		"tuning": {},
		"physics": _STRUCTURAL["physics_switches"].duplicate(true),
	}
	for t in TUNABLES:
		var root := str(t["root"])
		if not d.has(root):
			d[root] = {}
		d[root][str(t["key"])] = t["default"]
	return d


## Board rows for the in-game balance editor, derived from TUNABLES (one source).
## EscapeMenu's Balance tab consumes this instead of a hand-maintained list. `value_path` is the
## dotted config location; `open_only` rows are filtered out in the closed system.
static func board_specs() -> Array:
	var specs: Array = []
	for t in TUNABLES:
		if not bool(t.get("board", true)):
			continue
		specs.append({
			"id": str(t["key"]),
			"label": str(t.get("label", t["key"])),
			"category": str(t.get("category", "Tuning")),
			"value_path": [str(t["root"]), str(t["key"])],
			"kind": str(t.get("kind", "float")),
			"step": t.get("step", 1.0),
			"min": t.get("min", 0.0),
			"max": t.get("max", 100.0),
			"default": t["default"],
			"open_only": bool(t.get("open_only", false)),
		})
	return specs


## Runtime override for physics knobs (set by the reservoir sweep / tuning tools).
## Merged on top of DEFAULTS, under any explicit config passed to get_physics —
## so parametric retuning (e.g. hamiltonian_coupling_scale, lindblad_rate_scale)
## takes effect on the next operator rebuild without editing the constant.
static var _physics_override: Dictionary = {}


static func set_physics_override(overrides) -> void:
	_physics_override = overrides.duplicate(true) if overrides is Dictionary else {}


## Merge (rather than replace) physics overrides — the story-driven path.
## What Fades flags carry `physics_changes` (e.g. the endgame door sets
## dissipative_dynamics true); merging preserves any tuning overrides already
## in force. Re-applied deterministically on load from fired story flags.
static func merge_physics_override(changes: Dictionary) -> void:
	for key in changes:
		_physics_override[key] = changes[key]


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


## Is the dissipative (Lindblad pump/drain/decay) generator active GLOBALLY?
## Default false; the endgame door (the_door_stays_open) flips it true. This is
## the WORLD switch — the default regime for the 147 biomes that author no
## explicit "regime". Per-biome truth (and every player verb: Spark jolt,
## Merchant contracts, weak measurement, the reap split) goes through
## QuantumComputer.is_open_here(), which honors regime_override FIRST and only
## falls back to this switch. Openness is a place; this is the weather, not
## the law.
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
