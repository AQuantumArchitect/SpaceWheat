class_name QuestManager
extends Node

## Quest lifecycle management
## Handles offer → accept → complete/fail flow
## Integrates with FarmEconomy for resource checking

# Quest system dependency

# Logging
@onready var _verbose = get_node_or_null("/root/VerboseConfig")

# =============================================================================
# SIGNALS
# =============================================================================

signal quest_offered(quest_data: Dictionary)
signal quest_accepted(quest_id: int)
signal quest_ready_to_claim(quest_id: int)  # Non-delivery quest conditions met, awaiting player claim
signal quest_completed(quest_id: int, rewards: Dictionary)
signal quest_failed(quest_id: int, reason: String)
signal quest_expired(quest_id: int)
signal active_quests_changed()
signal icon_learned(north: String, south: String, faction: String)
signal story_flag_fired(flag_id: String, flag_data: Dictionary)

# =============================================================================
# STATE
# =============================================================================

var active_quests: Dictionary = {}  # quest_id -> quest_data (status: "active" or "ready")
var story_offers: Dictionary = {}  # quest_id -> quest_data (story arc offers pending acknowledgement)
var completed_quests: Array = []
var failed_quests: Array = []
var next_quest_id: int = 0
var _announced_offers: Dictionary = {}  # quest_id -> true; dedup for quest_offered emit

# Quest timers
var quest_timers: Dictionary = {}  # quest_id -> Timer

# References (set via dependency injection)
var economy: Node = null
var faction_manager: Node = null
var current_biome: Node = null  # For tracking non-delivery quest progress
var _state_projection: QuestStateProjectionService = QuestStateProjectionService.new()
var _story_flags: Array = []    # All flag definitions loaded from story_flags.json
var _unfired_flags: Array = []  # Subset not yet in farm.story_flags_fired
var _signature_baseline: int = -1  # Seeded signature size snapshot (-1 = not captured)
var _baseline_farm_id: int = 0     # Farm instance the baseline was captured from (restart ⇒ recapture)
var _tutorial_steps: Array = [] # Act-0 onboarding chain (tutorial_arc.json), linked into a chain

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	set_physics_process(true)  # Enable for quest tracking
	_load_story_flags()
	_load_tutorial_arc()

func _physics_process(delta: float) -> void:
	var t0 = Time.get_ticks_usec()
	# Story flags don't require a biome — evaluate unconditionally.
	_evaluate_story_flags()
	# Non-delivery quest progress tracking requires a live biome reference.
	# A save/load frees the old farm's biomes: a stale (freed) current_biome is
	# not == null, and touching it aborts this whole frame BEFORE the quest
	# readiness loop — claims then never flip READY (act-4 marathon).
	if current_biome == null or not is_instance_valid(current_biome):
		return
	if _state_projection:
		_state_projection.observe_biome(current_biome, delta)

	for quest in active_quests.values():
		# Skip quests already ready to claim
		if quest.get("status") == "ready":
			continue
		var qpreds = quest.get("state_predicates", [])
		if qpreds is Array and not qpreds.is_empty():
			# state_predicates are the AUTHORITATIVE (physics-driven) completion path:
			# a quest carrying them is scored purely on its physics observables, and
			# type-specific tracking is SKIPPED (the `continue` below) so it can't
			# trivially auto-complete — e.g. a default SHAPE_ACHIEVE checks purity>0.7,
			# which is always true in the closed system (purity≡1). This is what makes
			# "physics-driven story quests" (familiarity with a set of emojis/icons)
			# first-class, distinct from DELIVER/market contracts that reward resources.
			var pred_score := _evaluate_quest_state_predicates(qpreds)
			quest["predicate_score"] = pred_score
			quest["progress"] = pred_score
			if pred_score >= QuestStateProjectionService.COMPLETION_THRESHOLD:
				var quest_id = int(quest.get("id", -1))
				if quest_id >= 0:
					mark_quest_ready(quest_id, "state_predicates")
			# Predicates are the AUTHORITATIVE completion when present — never
			# fall through to the type trackers, whose field defaults (e.g.
			# observable "purity", ≡1 in the enclave) would self-complete a
			# predicate-only quest instantly.
			continue

		var quest_type = quest.get("type", QuestTypes.Type.DELIVERY)

		# Only track quest types that need continuous monitoring
		if not QuestTypes.requires_tracking(quest_type):
			continue

		match quest_type:
			QuestTypes.Type.SHAPE_ACHIEVE:
				_update_shape_achieve_quest(quest, delta)
			QuestTypes.Type.SHAPE_MAINTAIN:
				_update_shape_maintain_quest(quest, delta)
			QuestTypes.Type.EVOLUTION:
				_update_evolution_quest(quest, delta)
			QuestTypes.Type.ENTANGLEMENT:
				_update_entanglement_quest(quest, delta)
			# Quantum mechanics quest types
			QuestTypes.Type.ACHIEVE_EIGENSTATE:
				_update_achieve_eigenstate_quest(quest, delta)
			QuestTypes.Type.MAINTAIN_COHERENCE:
				_update_maintain_coherence_quest(quest, delta)
			QuestTypes.Type.INDUCE_BELL_STATE:
				_update_induce_bell_state_quest(quest, delta)
			QuestTypes.Type.PREVENT_DECOHERENCE:
				_update_prevent_decoherence_quest(quest, delta)
			QuestTypes.Type.COLLAPSE_DELIBERATELY:
				_update_collapse_deliberately_quest(quest, delta)
	var t1 = Time.get_ticks_usec()
	if Engine.get_physics_frames() % 60 == 0:
		if _verbose:
			_verbose.trace("quest", "⏱️", "QuestManager Physics Trace: Total %d us" % [t1 - t0])

func connect_to_economy(econ: Node) -> void:
	# Inject economy dependency
	economy = econ

func connect_to_biome(biome: Node) -> void:
	# Inject biome dependency for quest tracking
	current_biome = biome


func connect_to_farm(farm: Node) -> void:
	_refresh_unfired_flags(farm)
	# Onboarding: headed games show the welcome splash, and DISMISSING it begins the tutorial
	# (so tutorial_seen fires from a human action, not at boot). Headless (rig/tests) has no
	# splash to dismiss, so begin immediately — preserving existing headless behavior.
	if RuntimeEnv.is_headless():
		maybe_start_tutorial(farm)
	var story_engine = get_node_or_null("/root/StoryEngine")
	if story_engine != null and story_engine.has_method("connect_to_farm_and_quests"):
		story_engine.connect_to_farm_and_quests(farm, self)


# =============================================================================
# STORY FLAGS
# =============================================================================

## Live standing channel value — PredicateGloss shows "have/target" on standing
## gates so completed contracts visibly move the number (the access-0.2 wall
## read as an unpayable toll to the fleet).
func standing_channel_now(faction: String, channel: String) -> float:
	var farm = _get_active_farm()
	if farm == null or not ("faction_standings" in farm) or farm.faction_standings == null:
		return 0.0
	var standing = farm.faction_standings.get(faction)
	if standing == null or not standing.has_method("to_dict"):
		return 0.0
	return float(standing.to_dict().get(channel, 0.0))


## Berries consumed so far in a biome — PredicateGloss shows live "N/M" so a
## fresh incorporation visibly moves the number (fleet #5: "progress display
## not updating" + the cumulative ladder read as shifting requirements).
func berry_consumed_in(biome_name: String) -> int:
	var farm = _get_active_farm()
	if farm == null or farm.grid == null:
		return 0
	var biome = farm.grid.get_biome(biome_name)
	if biome == null or biome.get("quantum_computer") == null or biome.quantum_computer.berry_register == null:
		return 0
	return int(biome.quantum_computer.berry_register.get_consumed_count())


## Live atom count in a biome — gloss shows "N/M" for the act-4/5 buildout
## (marathon #3: nobody organically injects icons; the Arc tab must teach it).
func atom_count_in(biome_name: String) -> int:
	var farm = _get_active_farm()
	if farm == null or farm.grid == null:
		return 0
	var biome = farm.grid.get_biome(biome_name)
	if biome == null or biome.get("quantum_computer") == null or biome.quantum_computer.register_map == null:
		return 0
	return int(biome.quantum_computer.register_map.coordinates.size())


## Live distinct-atom count across all loaded biomes (mirrors the
## atom_diversity_gte evaluator).
func atom_diversity_now() -> int:
	var farm = _get_active_farm()
	if farm == null or farm.grid == null:
		return 0
	var seen: Dictionary = {}
	for bname in farm.grid.get_biome_names():
		var b = farm.grid.get_biome(str(bname))
		if b == null or b.get("quantum_computer") == null or b.quantum_computer.register_map == null:
			continue
		for atom in b.quantum_computer.register_map.coordinates.keys():
			seen[str(atom)] = true
	return seen.size()


## Live signature size — PredicateGloss shows "N/M" on signature gates. The
## soft-gate score is a sigmoid, so the Arc bar reads ~9% at 12/15 known icons:
## honest math, but a sensor at the text seat read it as "1-2 of 15" and walled
## (hub leg L4a). The count is farm.known_icons — grown by claimed teachings
## AND Icon-hat incorporation, same organ the evaluator reads at :607.
func signature_size_now() -> int:
	var farm = _get_active_farm()
	if farm == null or not ("known_icons" in farm) or farm.known_icons == null:
		return 0
	return int(farm.known_icons.size())


## Player-facing display name for a story flag id (PredicateGloss speaks beats,
## not internal ids).
func flag_display_name(flag_id: String) -> String:
	for f in _story_flags:
		if f is Dictionary and str(f.get("id", "")) == flag_id:
			return str(f.get("display_name", flag_id))
	return flag_id


func _load_story_flags() -> void:
	var path := "res://Core/Quests/data/story_flags.json"
	# One JSON-load authority (slop knot #7); a missing file keeps the old
	# warning, malformed files are loud via the loader.
	var res: Dictionary = preload("res://Core/Config/JsonFileLoader.gd").load_json(
		path, {"context": "QuestManager", "required": false})
	if res.missing:
		push_warning("QuestManager: story_flags.json not found at %s" % path)
		return
	if not res.ok:
		return
	if res.data is Array:
		_story_flags = res.data
	else:
		push_warning("QuestManager: story_flags.json root is not an Array")


func _refresh_unfired_flags(farm) -> void:
	if farm == null or not ("story_flags_fired" in farm):
		_unfired_flags = _story_flags.duplicate()
		return
	_unfired_flags = []
	for flag in _story_flags:
		if not farm.story_flags_fired.has(str(flag.get("id", ""))):
			_unfired_flags.append(flag)


## Load the Act-0 onboarding chain and link each step to unlock the next (linear chain via
## chain_unlocks; dicts are references, so the nesting is built in one pass).
func _load_tutorial_arc() -> void:
	var path := "res://Core/Quests/data/tutorial_arc.json"
	# One JSON-load authority (slop knot #7); a missing file keeps the old
	# warning, malformed files are loud via the loader.
	var res: Dictionary = preload("res://Core/Config/JsonFileLoader.gd").load_json(
		path, {"context": "QuestManager", "required": false})
	if res.missing:
		push_warning("QuestManager: tutorial_arc.json not found at %s" % path)
		return
	if not res.ok:
		_tutorial_steps = []
		return
	var parsed = res.data
	var steps: Array = []
	if parsed is Dictionary and parsed.get("steps", null) is Array:
		steps = parsed["steps"]
	elif parsed is Array:
		steps = parsed
	for i in steps.size():
		steps[i]["chain_unlocks"] = [steps[i + 1]] if i + 1 < steps.size() else []
	_tutorial_steps = steps


## Offer the first Act-0 quest on a fresh game. Gated by a persisted marker in story_flags_fired
## ("tutorial_seen") so it never re-offers on a loaded save. Completing each step unlocks the next
## via _process_chain_unlocks. New games start with this empty; the marker survives save/load.
func maybe_start_tutorial(farm) -> void:
	if farm == null or _tutorial_steps.is_empty():
		return
	if not ("story_flags_fired" in farm):
		return
	if farm.story_flags_fired.has("tutorial_seen"):
		return
	farm.story_flags_fired["tutorial_seen"] = Engine.get_physics_frames()
	offer_tutorial_quest(_tutorial_steps[0])


## Story-flag firing threshold. Firing is governed by the SAME soft continuous geometry the
## Arc tab displays: a flag fires when smooth_and over its predicates' soft_gate scores reaches
## this value. (Replaces the old hard per-predicate firing path — soft continuous geometry is
## always >>> hard rules. A consequence: wide-width predicates fire at high confidence, a touch
## past their nominal threshold; this constant is the single dial for earlier/later firing.)
const FLAG_FIRE_THRESHOLD: float = 0.85


func _evaluate_story_flags() -> void:
	if _unfired_flags.is_empty():
		return
	var farm = _get_active_farm()
	if farm == null:
		return
	# BOOT RACE GUARD: the farm registers as active BEFORE its boot completes
	# (SessionLifecycle sets active_farm, then awaits farm_ready). Evaluating in
	# that window reads pre-seed state — e.g. the signature baseline snapshots 0,
	# then seeding lands and first_breath fires with zero player input.
	if not (farm.has_method("is_boot_finalized") and farm.is_boot_finalized()):
		return
	for flag in _unfired_flags.duplicate():
		var predicates = flag.get("predicates", [])
		if _evaluate_flag_predicates(predicates, farm) >= FLAG_FIRE_THRESHOLD:
			_fire_story_flag(flag, farm)


func _evaluate_flag_predicates(predicates: Array, farm) -> float:
	## Returns a continuous confidence score in [0, 1].
	## Empty list → 0.0 so that flags with no predicates never auto-fire.
	if predicates.is_empty():
		return 0.0
	var scores: Array = []
	for pred in predicates:
		if not (pred is Dictionary):
			return 0.0
		scores.append(_check_flag_predicate(pred, farm))
	return QuestMath.smooth_and(scores)


## Predicate types handled by _check_flag_predicate (state-outcome vocabulary). Quest completion
## (below) accepts these PLUS the QuestStateProjectionService observable/action vocabulary, so the
## tutorial + arc + market quests all draw from one unified predicate language.
const FLAG_PREDICATE_TYPES := [
	"story_flag_set", "story_flag_any", "biome_evolving", "berry_consumed_count_gte", "berry_total_phase_gte",
	"standing_gte", "biome_state_gte", "biome_state_lte", "signature_size_gte", "signature_growth_gte", "atom_count_gte", "atom_in_biome",
	"atom_diversity_gte", "biome_attractor_emoji_gte",
	"soul_purity_gte",
	"bridge_built_gte", "bridge_braids_gte", "bridge_fused_gte",
	"biome_frozen_loops_gte", "biome_loops_linked",
	# Closed-native chaos↔stability vocabulary:
	#   biome_spectral_gap_*  — H's own gap E₁−E₀ (composition-intrinsic, state-independent,
	#                           conserved): large = one dominant attractor (STABLE identity),
	#                           small = near-degenerate competing modes (CHAOTIC). The finale rides this.
	#   biome_energy_variance_* — Var(H)=⟨H²⟩−⟨H⟩² (state-relative restlessness; 0 in an eigenstate,
	#                           rises when the state is disturbed). Available; not on the spine.
	"biome_spectral_gap_gte", "biome_spectral_gap_lte",
	"biome_energy_variance_gte", "biome_energy_variance_lte",
	# biome_eigenvalue_gap_gte / biome_purity_trending are OPEN-SYSTEM ONLY (degenerate in the
	# closed system: ρ is pure → eigenvalue gap ≡ 1, purity ≡ 1). Kept for the open DLC; the
	# closed campaign must NOT gate on them — use biome_spectral_gap_* for chaos↔stability.
	"biome_eigenvalue_gap_gte", "biome_purity_trending",
]

## Per-type soft_gate widths — SINGLE SOURCE, read by both _check_flag_predicate below and
## predicate_fire_target. Types not listed use QuestMath.soft_gate's default 0.05.
const PREDICATE_SOFT_WIDTH := {
	"berry_consumed_count_gte": 1.5,
	"berry_total_phase_gte": 0.1,
	"signature_size_gte": 2.0,
	"atom_count_gte": 1.5,
	"atom_diversity_gte": 2.0,
	"biome_eigenvalue_gap_gte": 0.02,
	# H-gap scale is O(0.1–0.3) (rig: StarterForest 0.21, Village 0.25); width is the
	# chaos↔stability transition band. Starting estimate — co-tuned with thresholds on the rig.
	"biome_spectral_gap_gte": 0.03,
	"biome_spectral_gap_lte": 0.03,
	# Var(H) scale depends on the biome's H (self-energies ~0.2–0.5, rabi ~0.3–0.6); width is
	# the disturbance band. Starting estimate — co-tuned with thresholds on the rig.
	"biome_energy_variance_gte": 0.1,
	"biome_energy_variance_lte": 0.1,
}


## Unified per-predicate score for QUEST completion: flag-vocabulary predicates (state outcomes)
## resolve via _check_flag_predicate; everything else via the state-projection service (observables
## + recorded action history). Soft continuous geometry throughout.
func _quest_predicate_score(pred: Dictionary, farm) -> float:
	var t := str(pred.get("type", ""))
	if t in FLAG_PREDICATE_TYPES:
		return _check_flag_predicate(pred, farm) if farm != null else 0.0
	if _state_projection:
		return _state_projection.evaluate_predicate(pred)
	return 0.0


## smooth_and over a quest's state_predicates using the unified vocabulary. Empty → 0.0.
func _evaluate_quest_state_predicates(predicates: Array) -> float:
	if predicates.is_empty():
		return 0.0
	var farm = _get_active_farm()
	var scores: Array = []
	for pred in predicates:
		if not (pred is Dictionary):
			return 0.0
		scores.append(_quest_predicate_score(pred, farm))
	return QuestMath.smooth_and(scores)


## Integer-count predicate types — evaluated with QuestMath.count_gate so they fire
## exactly AT the authored count ("≥ 3" means 3, not 3 + width·atanh). Displays and
## physics must quote the same number.
const COUNT_GATE_TYPES: Array[String] = [
	"berry_consumed_count_gte", "signature_size_gte", "atom_count_gte", "atom_diversity_gte",
]


## Public: the value the player must actually reach for `pred` to fire. soft_gate is only
## 0.5 at the stated `value`; it crosses FLAG_FIRE_THRESHOLD near value + width·atanh(2·t−1).
## Count gates fire at the authored value itself.
func predicate_fire_target(pred: Dictionary) -> float:
	var t := str(pred.get("type", ""))
	var w: float = _pred_width(pred, t)
	var center := float(pred.get("value", 0.0))
	if t in COUNT_GATE_TYPES:
		return center
	var target := QuestMath.fire_value(center, w, FLAG_FIRE_THRESHOLD)
	if t.ends_with("_lte"):
		# "at most" predicates fire BELOW center — mirror the soft_gate offset.
		return 2.0 * center - target
	return target


## Soft-gate width for a predicate: a per-instance `width` override (campaign-pacing knob)
## falling back to the per-type default in PREDICATE_SOFT_WIDTH, then to QuestMath's 0.05.
## Lets a single beat fire crisply (e.g. first_breath at the first incorporation) without
## moving the global width that other flags of the same type rely on.
func _pred_width(pred: Dictionary, t: String) -> float:
	return float(pred.get("width", PREDICATE_SOFT_WIDTH.get(t, 0.05)))


## Public: the width _pred_width would use for `pred` — PredicateGloss.formula reads this
## to print the actual soft-gate width alongside the target, instead of duplicating the
## per-instance-override → per-type-default → QuestMath-default fallback chain.
func predicate_width(pred: Dictionary) -> float:
	return _pred_width(pred, str(pred.get("type", "")))


## Public: true if `pred`'s type fires on QuestMath.count_gate (integer counts, exact-at-N)
## rather than plain soft_gate. PredicateGloss.formula uses this to label the formula.
func predicate_is_count_gate(pred: Dictionary) -> bool:
	return str(pred.get("type", "")) in COUNT_GATE_TYPES


func _signature_baseline_size(farm) -> int:
	# Lazily snapshot the seeded signature size the first time a farm is evaluated.
	# Evaluation is gated on farm.is_boot_finalized(), so the snapshot always sees
	# the scenario's seeded signature — never the pre-seed empty array.
	# Re-captured per farm INSTANCE: a restart builds a new farm, and carrying the
	# old run's baseline over would demand N re-incorporations before first_breath.
	var farm_id: int = farm.get_instance_id() if farm else 0
	if _signature_baseline < 0 or farm_id != _baseline_farm_id:
		_signature_baseline = farm.known_icons.size() if farm and "known_icons" in farm else 0
		_baseline_farm_id = farm_id
	return _signature_baseline


func _check_flag_predicate(pred: Dictionary, farm) -> float:
	## Returns a continuous confidence score in [0, 1] for each predicate type.
	## Structural predicates (flag set, biome exists) return 1.0 or 0.0 exactly.
	## Physics predicates use soft_gate so partial progress is visible.
	var kind := str(pred.get("type", ""))
	match kind:
		"story_flag_set":
			return 1.0 if farm.story_flags_fired.has(str(pred.get("id", ""))) else 0.0
		"story_flag_any":
			# OR over a set of flags — the branch-choice predicate. Lets a
			# quest stay ACTIVE ("choose one door") until ANY alternative
			# fires, instead of instant-completing on an already-true gate
			# (five_doors' old state_predicates were satisfied the moment the
			# flag fired, so its fork guidance was claimed away untaught).
			for fid in pred.get("ids", []):
				if farm.story_flags_fired.has(str(fid)):
					return 1.0
			return 0.0
		"biome_evolving":
			if farm.grid == null:
				return 0.0
			var biome = farm.grid.get_biome(str(pred.get("biome", "")))
			return 1.0 if (biome != null and biome.get("quantum_computer") != null) else 0.0
		"berry_consumed_count_gte":
			if farm.grid == null:
				return 0.0
			var biome = farm.grid.get_biome(str(pred.get("biome", "")))
			if biome == null or biome.get("quantum_computer") == null:
				return 0.0
			var count := float(biome.quantum_computer.berry_register.get_consumed_count())
			return QuestMath.count_gate(count, float(pred.get("value", 0)), PREDICATE_SOFT_WIDTH["berry_consumed_count_gte"], FLAG_FIRE_THRESHOLD)
		"berry_total_phase_gte":
			if farm.grid == null:
				return 0.0
			var biome = farm.grid.get_biome(str(pred.get("biome", "")))
			if biome == null or biome.get("quantum_computer") == null:
				return 0.0
			var phase: float = biome.quantum_computer.berry_register.get_consumed_phase()
			return QuestMath.soft_gate(phase, float(pred.get("value", 0.0)), PREDICATE_SOFT_WIDTH["berry_total_phase_gte"])
		"standing_gte":
			var standing = farm.faction_standings.get(str(pred.get("faction", "")))
			if standing == null:
				return 0.0
			var channel: String = str(pred.get("channel", "trust"))
			var current := float(standing.to_dict().get(channel, 0.0))
			# Per-predicate width matters here more than anywhere: standing accrues
			# in fixed contract-sized steps (+0.02 access per delivery), so the
			# default 0.05 width silently prices a 0.2 gate at ~2 extra deliveries.
			# Authors declare "width" to pin a gate to a delivery count.
			return QuestMath.soft_gate(current, float(pred.get("value", 0.0)), _pred_width(pred, "standing_gte"))
		"biome_state_gte":
			if farm.grid == null:
				return 0.0
			var biome = farm.grid.get_biome(str(pred.get("biome", "")))
			if biome == null or biome.get("quantum_computer") == null:
				return 0.0
			var atom := str(pred.get("atom", ""))
			var reg = biome.quantum_computer.register_map
			if reg == null or not reg.coordinates.has(atom):
				return 0.0
			var coord: Dictionary = reg.coordinates[atom]
			var qubit := int(coord.get("qubit", -1))
			var pole := int(coord.get("pole", 0))
			if qubit < 0:
				return 0.0
			var snap: Dictionary = biome.viz_cache.get_snapshot(qubit)
			var marginal: float = float(snap.get("p1" if pole == 1 else "p0", 0.0))
			return QuestMath.soft_gate(marginal, float(pred.get("value", 0.0)))
		"biome_state_lte":
			# "At most" twin of biome_state_gte — score rises as the atom's marginal falls
			# BELOW value (e.g. draining 📜 below the ledger's autocatalytic threshold).
			if farm.grid == null:
				return 0.0
			var biome = farm.grid.get_biome(str(pred.get("biome", "")))
			if biome == null or biome.get("quantum_computer") == null:
				return 0.0
			var atom := str(pred.get("atom", ""))
			var reg = biome.quantum_computer.register_map
			if reg == null or not reg.coordinates.has(atom):
				return 0.0
			var coord: Dictionary = reg.coordinates[atom]
			var qubit := int(coord.get("qubit", -1))
			var pole := int(coord.get("pole", 0))
			if qubit < 0:
				return 0.0
			var snap: Dictionary = biome.viz_cache.get_snapshot(qubit)
			var marginal: float = float(snap.get("p1" if pole == 1 else "p0", 0.0))
			return QuestMath.soft_gate_inv(marginal, float(pred.get("value", 0.0)))
		"soul_purity_gte":
			# The player's OWN concept state: purity of the faction-alignment ρ — the
			# enclave's one open system (τ=300s decay pulls it toward the mixed state
			# unless choices keep renewing it; see docs/glossary/enclave.md). Starts
			# maximally mixed (~1/n), so this can only fire through deliberate living.
			# Width 0.1: identity resolves gradually — the Arc tab should feel it coming.
			if not ("faction_density" in farm) or farm.faction_density == null \
					or not farm.faction_density.has_method("get_purity"):
				return 0.0
			return QuestMath.soft_gate(float(farm.faction_density.get_purity()),
					float(pred.get("value", 0.5)), 0.1)
		"bridge_built_gte":
			# What Connects: lifetime Majorana spans raised (farm-wide BridgeRegister).
			if not ("bridge_register" in farm) or farm.bridge_register == null:
				return 0.0
			return QuestMath.soft_gate(float(farm.bridge_register.built_total),
					maxf(1.0, float(pred.get("value", 1))), 0.75)
		"bridge_braids_gte":
			# Lifetime braid operations — the Clifford alphabet, drilled.
			if not ("bridge_register" in farm) or farm.bridge_register == null:
				return 0.0
			return QuestMath.soft_gate(float(farm.bridge_register.braids_total),
					maxf(1.0, float(pred.get("value", 1))), 1.0)
		"bridge_fused_gte":
			# Lifetime fusions — bridges read, collapsed, and spent.
			if not ("bridge_register" in farm) or farm.bridge_register == null:
				return 0.0
			return QuestMath.soft_gate(float(farm.bridge_register.fused_total),
					maxf(1.0, float(pred.get("value", 1))), 0.75)
		"biome_frozen_loops_gte":
			# Closed Berry walks banked in the NAMED biome's record (a loop record
			# freezes when a tracked walk returns to its seed vertex having
			# enclosed real solid angle — What Connects, Machine 2).
			if farm.grid == null:
				return 0.0
			var loop_biome = farm.grid.get_biome(str(pred.get("biome", "")))
			if loop_biome == null or loop_biome.get("quantum_computer") == null \
					or loop_biome.quantum_computer.berry_register == null:
				return 0.0
			return QuestMath.soft_gate(float(loop_biome.quantum_computer.berry_register.frozen_loop_count()),
					maxf(1.0, float(pred.get("count", 1))), 0.75)
		"biome_loops_linked":
			# Two frozen loops in the NAMED biome whose mutual winding is nonzero —
			# the knot invariant (KnotRegister). Below two loops, halfway credit
			# per banked loop so the Arc tab shows the road.
			if farm.grid == null:
				return 0.0
			var knot_biome = farm.grid.get_biome(str(pred.get("biome", "")))
			if knot_biome == null or knot_biome.get("quantum_computer") == null \
					or knot_biome.quantum_computer.berry_register == null:
				return 0.0
			var frozen: Array = knot_biome.quantum_computer.berry_register.frozen_loops()
			if frozen.size() < 2:
				return QuestMath.soft_gate(float(frozen.size()), 2.0, 0.75) * 0.5
			var winding := float(absi(KnotRegister.max_mutual_winding(frozen)))
			return QuestMath.soft_gate(winding, maxf(1.0, float(pred.get("value", 1))), 0.5)
		"biome_spectral_gap_gte":
			# "stable / strong attractor" — score rises as H's gap E₁−E₀ climbs above value.
			# Composition-intrinsic (set by which icons make up H), state-independent, conserved:
			# a wide gap = one dominant configuration the biome rigidly holds = a settled identity.
			if farm.grid == null:
				return 0.0
			var biome = farm.grid.get_biome(str(pred.get("biome", "")))
			if biome == null or biome.get("quantum_computer") == null:
				return 0.0
			var g_gte: float = float(biome.quantum_computer.get_hamiltonian_spectral_gap())
			if g_gte < 0.0:
				return 0.0  # unmeasurable (solver failure sentinel) is never satisfaction
			return QuestMath.soft_gate(g_gte, float(pred.get("value", 0.0)), PREDICATE_SOFT_WIDTH["biome_spectral_gap_gte"])
		"biome_spectral_gap_lte":
			# "chaotic / near-degenerate" — score rises as H's gap falls below value (competing
			# modes, no single rest configuration). The empire's restlessness is this, by composition.
			if farm.grid == null:
				return 0.0
			var biome = farm.grid.get_biome(str(pred.get("biome", "")))
			if biome == null or biome.get("quantum_computer") == null:
				return 0.0
			var g_lte: float = float(biome.quantum_computer.get_hamiltonian_spectral_gap())
			if g_lte < 0.0:
				return 0.0  # a broken solver must not read as "chaotic" and hand out the ending
			return QuestMath.soft_gate_inv(g_lte, float(pred.get("value", 0.0)), PREDICATE_SOFT_WIDTH["biome_spectral_gap_lte"])
		"biome_energy_variance_gte":
			# "restless / chaotic" — score rises as Var(H) = ⟨H²⟩−⟨H⟩² climbs above value.
			# Var(H) is the closed-native chaos measure (a broad energy superposition swings
			# the marginals wildly); conserved under evolution, set by the biome's composition.
			if farm.grid == null:
				return 0.0
			var biome = farm.grid.get_biome(str(pred.get("biome", "")))
			if biome == null or biome.get("quantum_computer") == null:
				return 0.0
			var v_gte: float = float(biome.quantum_computer.get_energy_variance())
			return QuestMath.soft_gate(v_gte, float(pred.get("value", 0.0)), PREDICATE_SOFT_WIDTH["biome_energy_variance_gte"])
		"biome_energy_variance_lte":
			# "settled / stable" — score rises as Var(H) falls below value (the state nears an
			# H-eigenstate: eternal stillness). The closed-native "stable attractor" goal.
			if farm.grid == null:
				return 0.0
			var biome = farm.grid.get_biome(str(pred.get("biome", "")))
			if biome == null or biome.get("quantum_computer") == null:
				return 0.0
			var v_lte: float = float(biome.quantum_computer.get_energy_variance())
			return QuestMath.soft_gate_inv(v_lte, float(pred.get("value", 0.0)), PREDICATE_SOFT_WIDTH["biome_energy_variance_lte"])
		"signature_size_gte":
			return QuestMath.count_gate(float(farm.known_icons.size()), float(pred.get("value", 0)), _pred_width(pred, "signature_size_gte"), FLAG_FIRE_THRESHOLD)
		"signature_growth_gte":
			# Growth of the signature PAST the seeded boot baseline — i.e. how many icons
			# the player has actually incorporated THIS run. The scenario's starting
			# signature (e.g. The Demos) is the baseline, so this reads 0 at boot and only
			# crosses on a real incorporation. This is what makes first_breath fire from a
			# human action instead of from the seeded start (#5).
			return QuestMath.soft_gate(float(maxi(0, farm.known_icons.size() - _signature_baseline_size(farm))), float(pred.get("value", 0)), _pred_width(pred, "signature_growth_gte"))
		"atom_count_gte":
			if farm.grid == null:
				return 0.0
			var biome = farm.grid.get_biome(str(pred.get("biome", "")))
			if biome == null or biome.get("quantum_computer") == null:
				return 0.0
			var count := float(biome.quantum_computer.register_map.coordinates.size())
			return QuestMath.count_gate(count, float(pred.get("value", 0)), PREDICATE_SOFT_WIDTH["atom_count_gte"], FLAG_FIRE_THRESHOLD)
		"atom_in_biome":
			if farm.grid == null:
				return 0.0
			var biome = farm.grid.get_biome(str(pred.get("biome", "")))
			if biome == null or biome.get("quantum_computer") == null:
				return 0.0
			return 1.0 if biome.quantum_computer.register_map.coordinates.has(str(pred.get("atom", ""))) else 0.0
		"atom_diversity_gte":
			# Distinct atom emojis across ALL loaded biomes — rewards spreading a varied
			# ecology over the island's biome slots, not over-stuffing one biome (which the
			# per-biome plot cap forbids anyway). Union of every biome's register coordinates.
			if farm.grid == null:
				return 0.0
			var seen: Dictionary = {}
			for bname in farm.grid.get_biome_names():
				var b = farm.grid.get_biome(str(bname))
				if b == null or b.get("quantum_computer") == null or b.quantum_computer.register_map == null:
					continue
				for atom in b.quantum_computer.register_map.coordinates.keys():
					seen[str(atom)] = true
			return QuestMath.count_gate(float(seen.size()), float(pred.get("value", 0)), PREDICATE_SOFT_WIDTH["atom_diversity_gte"], FLAG_FIRE_THRESHOLD)
		"biome_attractor_emoji_gte":
			if farm.grid == null:
				return 0.0
			var biome = farm.grid.get_biome(str(pred.get("biome", "")))
			if biome == null or not biome.has_method("get_attractor_state"):
				return 0.0
			var attractor: Dictionary = biome.get_attractor_state()
			return QuestMath.soft_gate(attractor.get(str(pred.get("emoji", "")), 0.0),
					float(pred.get("value", 0.5)))
		"biome_eigenvalue_gap_gte":
			if farm.grid == null:
				return 0.0
			var biome = farm.grid.get_biome(str(pred.get("biome", "")))
			if biome == null or not biome.has_method("get_attractor_state"):
				return 0.0
			var attractor: Dictionary = biome.get_attractor_state()
			return QuestMath.soft_gate(attractor.get("eigenvalue_gap", 0.0),
					float(pred.get("value", 0.15)), PREDICATE_SOFT_WIDTH["biome_eigenvalue_gap_gte"])
		"biome_purity_trending":
			if farm.grid == null:
				return 0.0
			var biome = farm.grid.get_biome(str(pred.get("biome", "")))
			if biome == null or not biome.has_method("predict_purity"):
				return 0.0
			var steps := int(pred.get("steps", 5))
			# Score proportional to how strongly purity is trending upward.
			# Requires a ~1% positive trend to score 0.5; flat = ~0.4.
			var trend: float = biome.predict_purity(steps) - biome.get_purity()
			return QuestMath.soft_gate(trend, 0.01, 0.02)
		_:
			# Not every flag-vocabulary type has an arm here: gate_sequence_contains /
			# gate_order (and future observable/history types) are OWNED by the
			# state-projection service. Returning 0.0 silently zeroed them — a flag
			# gating on "a spark in the gate sequence" could never fire even though
			# the history recorded it. Delegate; the service's own default is 0.0.
			if _state_projection:
				return _state_projection.evaluate_predicate(pred)
			return 0.0


## Public: all loaded story flags (for Arc tab and tooling).
func get_all_story_flags() -> Array:
	return _story_flags


## Public: score a single predicate against the active farm. Score is in [0,1];
## ≥ FLAG_FIRE_THRESHOLD on combined `smooth_and` over a flag's predicates is
## what triggers a fire. Used by C-surface Arc tab to show progress.
func evaluate_predicate_score(pred: Dictionary) -> float:
	var farm = _get_active_farm()
	if farm == null or not (pred is Dictionary):
		return 0.0
	return _check_flag_predicate(pred, farm)


## Public: combined `smooth_and` score for a whole flag's predicates.
func evaluate_flag_score(flag: Dictionary) -> float:
	var farm = _get_active_farm()
	if farm == null:
		return 0.0
	var preds = flag.get("predicates", [])
	if not (preds is Array):
		return 0.0
	return _evaluate_flag_predicates(preds, farm)


func _fire_story_flag(flag: Dictionary, farm) -> void:
	var flag_id := str(flag.get("id", ""))
	if flag_id == "" or farm.story_flags_fired.has(flag_id):
		return

	# Record the fired frame — all downstream (beat, grants, quest, density) handled by StoryEngine.
	farm.story_flags_fired[flag_id] = Engine.get_physics_frames()

	# Remove from unfired list before emitting so predicate evaluation sees the flag as fired.
	_unfired_flags.erase(flag)

	story_flag_fired.emit(flag_id, flag)

	if _verbose:
		_verbose.info("quest", "📖", "Story flag fired: %s (act %d)" % [flag_id, int(flag.get("act", 0))])


## Non-expiring offer injected by StoryEngine when a story flag fires.
## All fields from quest_def are merged in; caller owns enrichment (attractor snap, etc.).
func offer_story_quest(quest_def: Dictionary, source_flag: String) -> int:
	if quest_def.is_empty():
		return -1
	var quest_id := next_quest_id
	next_quest_id += 1
	var q := QuestPipeline.from_story_def(quest_def, source_flag, quest_id)
	story_offers[quest_id] = q
	if not _announced_offers.has(quest_id):
		_announced_offers[quest_id] = true
		quest_offered.emit(q)
	return quest_id


## Offer a tutorial-chain quest (Act-0 onboarding). Parallel to offer_story_quest; routes through
## the pipeline's tutorial source. Used by _process_chain_unlocks for linear tutorial progression.
func offer_tutorial_quest(quest_def: Dictionary) -> int:
	if quest_def.is_empty():
		return -1
	var quest_id := next_quest_id
	next_quest_id += 1
	var q := QuestPipeline.from_tutorial_def(quest_def, quest_id)
	story_offers[quest_id] = q
	if not _announced_offers.has(quest_id):
		_announced_offers[quest_id] = true
		quest_offered.emit(q)
	# Break #1 — the offer-with-no-progress dead end. A predicate-driven tutorial step (whose
	# soft bar IS the teacher) is accepted FOR the player: it goes straight into active_quests
	# so the progress bar advances the instant the mechanic is done — no hidden X→Arc R-accept a
	# new player was never taught. The contracts step (5, a DELIVERY with no predicates) is the
	# one exception: it keeps the real accept→do→claim board ceremony. See _tutorial_auto_advances.
	if _tutorial_auto_advances(q):
		accept_quest(q)
	return quest_id


## A tutorial step auto-advances (auto-accept on offer + auto-claim on ready) when its completion
## is physics-driven — it carries state_predicates whose soft bar the player watches fill
## (tutorial_arc.json's own stated intent: "the progress bar is the teacher"). The contracts step
## is the sole tutorial step with NO predicates (a DELIVERY ask); it stays manual so the player
## learns the real accept→do→claim grammar they will need for every market contract.
func _tutorial_auto_advances(quest: Dictionary) -> bool:
	if str(quest.get("category", "")) != "TUTORIAL":
		return false
	var preds = quest.get("state_predicates", [])
	return preds is Array and not preds.is_empty()


## True if any story or active quest has source_flag == flag_id (for save/load restore check).
func has_quest_for_flag(flag_id: String) -> bool:
	for q in story_offers.values():
		if q.get("source_flag") == flag_id:
			return true
	for q in active_quests.values():
		if q.get("source_flag") == flag_id:
			return true
	return false


func _get_gsm():
	return get_node_or_null("/root/GameStateManager")


func _get_active_farm():
	var gsm = _get_gsm()
	if gsm and gsm.has_method("get_active_farm"):
		return gsm.get_active_farm()
	return null


func _get_signature_emojis() -> Array:
	# Get player-known emojis (farm-owned preferred).
	var gsm = _get_gsm()
	if gsm and gsm.player_progress:
		return gsm.player_progress.get_signature_emojis()
	return []


func _discover_icon(north: String, south: String) -> bool:
	# Grant an icon to the player (farm-owned preferred).

	# Returns true if signature was newly discovered, false if already known.
	var gsm = _get_gsm()
	var active_farm = gsm.get_active_farm() if gsm and gsm.has_method("get_active_farm") else null
	if active_farm and active_farm.has_method("discover_icon"):
		return active_farm.discover_icon(north, south)
	elif gsm and gsm.player_progress:
		return gsm.player_progress.discover_icon(north, south)
	return false


func _grant_resource_rewards(reward, faction_name: String) -> Dictionary:
	# Grant resource rewards to economy and return granted payload.
	var granted: Dictionary = {}
	if reward == null:
		return granted
	var rewards = reward.resource_rewards
	if not (rewards is Dictionary) or rewards.is_empty():
		return granted
	if economy == null:
		push_warning("QuestManager: economy not connected, cannot grant resource rewards")
		return granted

	var source = "quest_reward:%s" % faction_name.replace(" ", "_").to_lower()
	for emoji in rewards.keys():
		var amount = int(rewards.get(emoji, 0))
		if amount <= 0:
			continue
		economy.add_resource(emoji, amount, source)
		granted[emoji] = amount

	return granted


func _grant_icon_rewards(reward, faction_name: String) -> void:
	# Grant icon rewards and emit discovery signals.
	if reward == null:
		return

	# Paired signature is preferred (north/south axis)
	for pair in reward.learned_pairs:
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north == "" or south == "":
			continue
		var was_new = _discover_icon(north, south)
		if was_new:
			icon_learned.emit(north, south, faction_name)
			if _verbose:
				_verbose.info("quest", "📖", "%s taught you: %s/%s axis" % [faction_name, north, south])
		else:
			if _verbose:
				_verbose.debug("quest", "📖", "%s tried to teach %s/%s but you already know it" % [faction_name, north, south])


func _build_reward_payload(reward, granted_resources: Dictionary) -> Dictionary:
	# Convert reward object to plain dictionary for UI/signals.
	var payload: Dictionary = {
		"resource_rewards": granted_resources.duplicate(true),
		"learned_emojis": [],
		"learned_pairs": [],
		"bonus_multiplier": 1.0,
		"money_amount": 0
	}
	if reward == null:
		return payload
	payload["learned_emojis"] = reward.learned_emojis.duplicate()
	payload["learned_pairs"] = reward.learned_pairs.duplicate(true)
	payload["bonus_multiplier"] = reward.bonus_multiplier
	payload["money_amount"] = reward.money_amount
	return payload


func offer_all_faction_quests(biome) -> Array:
	# Generate quests for the current biome.

	# Quests come from the canonical MarketLattice: it reads the current mythos
	# substrate (faction density, principal mode, biome admitted factions,
	# player economy) and proposes bids that QuestManager wraps into the lifecycle.

	var quests: Array = []

	var now_ms: int = Time.get_ticks_msec()
	var player_icons := _get_signature_emojis()
	var seen_pairs: Dictionary = {}
	for quest in _offer_from_market_lattice(biome):
		if not _is_valid_offer_with_icons(quest, player_icons):
			continue
		var pk: String = "%s|%s" % [quest.get("reward_north", ""), quest.get("reward_south", "")]
		if pk != "|" and seen_pairs.has(pk):
			continue
		seen_pairs[pk] = true
		quest["id"] = next_quest_id
		next_quest_id += 1
		quest["offered_at"] = now_ms
		quests.append(quest)
		if not _announced_offers.has(quest["id"]):
			_announced_offers[quest["id"]] = true
			quest_offered.emit(quest)

	# One physics-derived quantum quest alongside the deliveries — a curriculum
	# ladder, closed-safe and deterministic. The companion faction is the offer
	# pool's MOST RESONANT voice (highest alignment with this biome's state), and
	# rung 1's flavor is personality-typed (QUEST_SYSTEM_PLAN stage 3): the
	# faction's operator taste (calculate_operator_weights over its 12 axial bits)
	# picks amplitude (push a population — material/direct factions) vs coherence
	# (superpose — mystical ones), the other flavor as fallback.
	#   rung 1 (amplitude | coherence): learn to steer marginals / to superpose.
	#   rung 2 (entanglement): once rung 1 is mastered (returns {}), ask for
	#   correlation — max pairwise MI via the standard SHAPE_ACHIEVE tracker.
	# Never two at once: quest volume stays constant as the player climbs.
	var resonance := _compute_faction_resonance(quests, biome)
	if not quests.is_empty():
		var obs := get_biome_observables(biome)
		var coh := float(obs.get("coherence", 0.0))
		var fac := _most_resonant_faction(quests, resonance)
		var bn := str(quests[0].get("biome_name", quests[0].get("biome", "")))
		var weights := _operator_weights_for(fac)
		# Rung-1 flavors in the faction's taste order (amplitude = grow a
		# population, coherence = superpose, ratio = commit a contested pair,
		# multi = hold two threads at once); unknown factions keep the original
		# coherence-first curriculum.
		var flavor_order: Array = ["coherence", "amplitude", "ratio", "multi"]
		if not weights.is_empty():
			flavor_order = ["amplitude", "coherence", "ratio", "multi"]
			flavor_order.sort_custom(func(x, y): return float(weights.get(x, 0.0)) > float(weights.get(y, 0.0)))
		var qq := {}
		# Wet country leads with its signature ask: WARD the biome against the
		# Bath (PREVENT_DECOHERENCE). Only where the ground is open — on closed
		# ground purity ≡ 1 and a ward would be a lie.
		var ward_qc = biome.get("quantum_computer")
		if ward_qc != null and ward_qc.has_method("is_open_here") and ward_qc.is_open_here():
			qq = QuestPipeline.suggest_ward_quest(bn, fac, float(obs.get("purity", 1.0)), next_quest_id)
		for flavor in flavor_order:
			if not qq.is_empty():
				break
			match str(flavor):
				"amplitude":
					qq = _suggest_amplitude_for(biome, bn, fac)
				"coherence":
					qq = QuestPipeline.suggest_quantum_quest(bn, fac, coh, next_quest_id)
				"ratio":
					qq = _suggest_ratio_for(biome, bn, fac)
				"multi":
					qq = _suggest_multi_for(biome, bn, fac, coh)
		if qq.is_empty():
			var max_mi := float(obs.get("max_mutual_information", -1.0))
			var nq: int = 0
			var qc = biome.get("quantum_computer")
			if qc != null and qc.register_map != null:
				nq = qc.register_map.num_qubits
			qq = QuestPipeline.suggest_entanglement_quest(bn, fac, max_mi, nq, next_quest_id)
		if not qq.is_empty():
			next_quest_id += 1
			qq["offered_at"] = now_ms
			quests.append(qq)
			if not _announced_offers.has(qq["id"]):
				_announced_offers[qq["id"]] = true
				quest_offered.emit(qq)

	_stamp_faction_resonance(quests, resonance)
	return quests


## QUEST_SYSTEM_PLAN pipeline stage 2 — "parameterize(faction, biome)" — wired at
## last: every offer carries the faction's live RESONANCE with the biome, i.e.
## FactionStateMatcher.compute_alignment of the faction's 12 axial bits against
## the biome's quantum observables (purity/entropy/coherence/shape/scale/dynamics).
## In the enclave purity and entropy are pinned (1, 0) — canon, not accident:
## order-loving factions are at home everywhere inside the walls; entropy-loving
## ones stay restless until Act 2 opens the webway. Rewards remain canonical
## (earnest-economy principle); resonance shapes voice + companion selection only.
## Returns {faction_name: {alignment, prefs}} for the offer pool's factions.
func _compute_faction_resonance(quests: Array, biome) -> Dictionary:
	var cache: Dictionary = {}
	if quests.is_empty() or biome == null:
		return cache
	var obs = FactionStateMatcher.extract_observables(null, biome)
	var registry = FactionRegistry.get_shared()
	if registry == null:
		return cache
	for quest in quests:
		if not (quest is Dictionary):
			continue
		var fname := str(quest.get("faction", ""))
		if fname == "" or cache.has(fname):
			continue
		var entry := {"alignment": -1.0, "prefs": "", "axiom_rows": []}
		var fac = registry.get_by_name(fname)
		if fac != null and fac.has_method("get_axial_bits"):
			var bits := Array(fac.get_axial_bits())
			entry["alignment"] = FactionStateMatcher.compute_alignment(bits, obs)
			entry["prefs"] = FactionStateMatcher.describe_preferences(bits)
			# The scalar's own terms (explain_alignment): stamped beside it so
			# the board can say WHICH axiom sings and which grates — same
			# moment-in-time truth as the alignment number itself.
			entry["axiom_rows"] = FactionStateMatcher.explain_alignment(bits, obs)
		cache[fname] = entry
	return cache


## Stamp computed resonance onto every offer whose faction is in the cache.
func _stamp_faction_resonance(quests: Array, resonance: Dictionary) -> void:
	for quest in quests:
		if not (quest is Dictionary):
			continue
		var e: Dictionary = resonance.get(str(quest.get("faction", "")), {})
		if not e.is_empty() and float(e.get("alignment", -1.0)) >= 0.0:
			quest["faction_alignment"] = float(e["alignment"])
			quest["faction_preferences"] = str(e["prefs"])
			quest["faction_axiom_rows"] = e.get("axiom_rows", [])


## The offer pool's most biome-resonant faction — it gets to voice the quantum
## companion quest. Falls back to the first offer's faction when resonance is
## unknown (no registry, no bits).
func _most_resonant_faction(quests: Array, resonance: Dictionary) -> String:
	var fac := str(quests[0].get("faction", "")) if not quests.is_empty() else ""
	var best := -1.0
	for q in quests:
		if not (q is Dictionary):
			continue
		var f := str(q.get("faction", ""))
		var a := float(resonance.get(f, {}).get("alignment", -1.0))
		if a > best:
			best = a
			fac = f
	return fac


## The faction's operator taste (QUEST_SYSTEM_PLAN stage 3): Born-rule weights
## over quest structures (amplitude/coherence/ratio/multi) from its 12 axial
## bits. Unknown faction → {} (caller treats as no preference).
func _operator_weights_for(faction_name: String) -> Dictionary:
	var registry = FactionRegistry.get_shared()
	var fac = registry.get_by_name(faction_name) if registry != null else null
	if fac == null or not fac.has_method("get_axial_bits"):
		return {}
	return FactionStateMatcher.calculate_operator_weights(Array(fac.get_axial_bits()))


## Amplitude-ask assembly: among the atoms this faction speaks (its cloud) that
## live in the biome's register, pick the one with the most headroom (lowest
## population) and build the quest. {} when the faction speaks nothing here or
## everything it speaks is already high — the ladder then falls to coherence.
func _suggest_amplitude_for(biome, biome_name: String, faction_name: String) -> Dictionary:
	var qc = biome.get("quantum_computer")
	if qc == null or qc.register_map == null or not qc.has_method("get_population"):
		return {}
	var registry = FactionRegistry.get_shared()
	var fac = registry.get_by_name(faction_name) if registry != null else null
	if fac == null or not ("cloud" in fac) or not (fac.cloud is Array):
		return {}
	var best_atom := ""
	var best_m := 1.0
	for e in fac.cloud:
		var atom := str(e)
		if not qc.register_map.coordinates.has(atom):
			continue
		var m := float(qc.get_population(atom))
		if m < best_m:
			best_m = m
			best_atom = atom
	return QuestPipeline.suggest_amplitude_quest(biome_name, faction_name, best_atom, best_m, next_quest_id)


## Ratio-ask assembly: among the atoms this faction speaks that live in the
## biome's register, find the most CONTESTED pair (populations nearest even)
## and ask to commit it — atom A oriented as the current leader. {} when the
## faction speaks fewer than two atoms here or every pair is already decided
## (suggest_ratio_quest declines balances ≥ 0.62).
func _suggest_ratio_for(biome, biome_name: String, faction_name: String) -> Dictionary:
	var qc = biome.get("quantum_computer")
	if qc == null or qc.register_map == null or not qc.has_method("get_population"):
		return {}
	var registry = FactionRegistry.get_shared()
	var fac = registry.get_by_name(faction_name) if registry != null else null
	if fac == null or not ("cloud" in fac) or not (fac.cloud is Array):
		return {}
	var present: Array = []
	for e in fac.cloud:
		var atom := str(e)
		if qc.register_map.coordinates.has(atom):
			present.append(atom)
	if present.size() < 2:
		return {}
	var best_a := ""
	var best_b := ""
	var best_bal := -1.0
	var best_dist := 1.0
	for i in range(present.size()):
		for j in range(i + 1, present.size()):
			var pa := float(qc.get_population(present[i]))
			var pb := float(qc.get_population(present[j]))
			if pa + pb <= 1e-9:
				continue
			var bal := pa / (pa + pb)
			var dist := absf(bal - 0.5)
			if dist < best_dist:
				best_dist = dist
				best_a = present[i] if bal >= 0.5 else present[j]
				best_b = present[j] if bal >= 0.5 else present[i]
				best_bal = maxf(bal, 1.0 - bal)
	return QuestPipeline.suggest_ratio_quest(biome_name, faction_name, best_a, best_b, best_bal, next_quest_id)


## Multi-ask assembly (prismatic factions): same headroom pick as the amplitude
## ask, composed with the biome's live coherence into a two-thread quest.
func _suggest_multi_for(biome, biome_name: String, faction_name: String, coherence: float) -> Dictionary:
	var qc = biome.get("quantum_computer")
	if qc == null or qc.register_map == null or not qc.has_method("get_population"):
		return {}
	var registry = FactionRegistry.get_shared()
	var fac = registry.get_by_name(faction_name) if registry != null else null
	if fac == null or not ("cloud" in fac) or not (fac.cloud is Array):
		return {}
	var best_atom := ""
	var best_m := 1.0
	for e in fac.cloud:
		var atom := str(e)
		if not qc.register_map.coordinates.has(atom):
			continue
		var m := float(qc.get_population(atom))
		if m < best_m:
			best_m = m
			best_atom = atom
	return QuestPipeline.suggest_multi_quest(biome_name, faction_name, coherence, best_atom, best_m, next_quest_id)


func record_quantum_action(action_name: String, payload: Dictionary = {}) -> void:
	if not _state_projection:
		return
	_state_projection.record_action(action_name, payload)


func get_state_projection_snapshot() -> Dictionary:
	if not _state_projection:
		return {}
	return _state_projection.get_snapshot()


func _is_valid_offer_with_icons(quest: Dictionary, player_icons: Array) -> bool:
	# Reject broken offers using pre-fetched player signature (avoids GSM walk).
	if quest.is_empty():
		return false
	var quest_type = quest.get("type", QuestTypes.Type.DELIVERY)
	if quest_type == QuestTypes.Type.DELIVERY:
		var resource = quest.get("resource", "")
		var quantity = quest.get("quantity", 0)
		if resource == "" or quantity <= 0:
			return false

	var north = quest.get("reward_north", "")
	var south = quest.get("reward_south", "")
	var has_icon_axis = (north != "" and south != "")
	var has_no_icon = (north == "" and south == "")
	if not has_icon_axis and not has_no_icon:
		return false
	if has_icon_axis and (north in player_icons or south in player_icons):
		return false
	return true


func get_biome_observables(biome) -> Dictionary:
	# Get current biome quantum observables for UI display
	var obs = FactionStateMatcher.extract_observables(null, biome)

	# Entanglement observable: max pairwise MI in bits (Bell = 2.0). Native cache
	# only — the GDScript fallback re-eigensolves per pair, too hot for trackers
	# that poll every physics frame. −1.0 = unknown (no cache), which the
	# _is_known_observable_value guard (>= 0) filters, so SHAPE quests on this
	# observable idle honestly instead of reading "zero entanglement".
	var max_mi := -1.0
	var qc = biome.get("quantum_computer")
	if qc != null and qc.has_method("get_cached_max_mutual_information"):
		max_mi = float(qc.get_cached_max_mutual_information())

	var out := {
		"purity": obs.purity,
		"entropy": obs.entropy,
		"coherence": obs.coherence,
		"max_mutual_information": max_mi,
		"distribution_shape": obs.distribution_shape,
		"scale": obs.scale,
		"dynamics": obs.dynamics,
		"description": FactionStateMatcher.describe_observables(obs),
	}
	# Per-atom population observables ("population:🌾") — the amplitude quest
	# family (SHAPE_ACHIEVE) reads these; cheap diagonal sums at tracker rate.
	if qc != null and qc.register_map != null and qc.has_method("get_population"):
		for atom in qc.register_map.coordinates.keys():
			out["population:%s" % str(atom)] = float(qc.get_population(str(atom)))
	return out


func _get_global_icon_map() -> Dictionary:
	var gsm = _get_gsm()
	var active_farm = gsm.get_active_farm() if gsm and gsm.has_method("get_active_farm") else null
	if active_farm and "biome_evolution_batcher" in active_farm:
		var batcher = active_farm.biome_evolution_batcher
		if batcher:
			var icon_map = batcher.get_global_icon_map()
			if icon_map is Dictionary:
				return icon_map
	return {}


func accept_quest(quest_data: Dictionary) -> bool:
	# Accept an offered quest

	# Args:
	# quest_data: Quest with "id" field

	# Returns:
	# true if accepted, false if invalid
	if not quest_data.has("id"):
		push_error("Cannot accept quest: missing ID")
		return false

	var quest_id = quest_data["id"]

	if active_quests.has(quest_id):
		push_warning("Quest %d already active" % quest_id)
		return false
	if story_offers.has(quest_id):
		story_offers.erase(quest_id)

	# Update status
	quest_data["status"] = "active"
	quest_data["accepted_at"] = Time.get_ticks_msec()

	# Store
	active_quests[quest_id] = quest_data

	# Start timer if quest has time limit
	if quest_data.get("time_limit", -1) > 0:
		_start_quest_timer(quest_id, quest_data["time_limit"])

	quest_accepted.emit(quest_id)
	active_quests_changed.emit()
	return true

# =============================================================================
# QUEST COMPLETION
# =============================================================================

func _finalize_quest_completion(quest_id: int, quest: Dictionary, reward, granted_resources: Dictionary) -> void:
	# Stamp completion fields, move quest to completed list, emit signals.
	quest["status"] = "completed"
	quest["completed_at"] = Time.get_ticks_msec()
	quest["reward"] = reward
	quest["reward_payload"] = _build_reward_payload(reward, granted_resources)
	active_quests.erase(quest_id)
	completed_quests.append(quest)
	_stop_quest_timer(quest_id)
	quest_completed.emit(quest_id, _build_reward_payload(reward, granted_resources))
	active_quests_changed.emit()
	# Break #2 — hand the story spine off FROM the tutorial before unlocking the next step, so
	# the hat/menu the next step teaches is already surfaced (load-bearing: step 3 fires
	# forest_listener → the Operator hat, before the entanglement step needs it).
	_fire_tutorial_unlock_flags(quest)
	_process_chain_unlocks(quest)
	_process_chain_branch(quest)


## Break #2 — tutorial ↔ story-spine handoff. A completed tutorial step FIRES the spine flags it
## hands off to (its authored `unlock_flags`), so the spine advances FROM the tutorial instead of
## racing it on a separate clock. The load-bearing case: step 3 fires `forest_listener`, which
## unlocks the Operator hat (UIProgression.HAT_UNLOCK_FLAGS) that the entanglement step (4) then
## tells the player to use — without this, a player with progressive-disclosure enforcement ON
## hits a locked hat the tutorial is pointing them at. Idempotent: _fire_story_flag no-ops a flag
## the spine already fired from the tutorial's own mechanics (first_breath from signature growth,
## forest_evolving from forest berries).
func _fire_tutorial_unlock_flags(quest: Dictionary) -> void:
	var flags = quest.get("unlock_flags", [])
	if not (flags is Array) or flags.is_empty():
		return
	var farm = _get_active_farm()
	if farm == null or not ("story_flags_fired" in farm):
		return
	for fid in flags:
		var flag := _story_flag_by_id(str(fid))
		if not flag.is_empty():
			_fire_story_flag(flag, farm)


## The raw story-flag definition for `flag_id` (the SAME dict instance held in _unfired_flags, so
## _fire_story_flag's by-reference erase stays correct). Empty dict when the id is unknown.
func _story_flag_by_id(flag_id: String) -> Dictionary:
	for f in _story_flags:
		if f is Dictionary and str(f.get("id", "")) == flag_id:
			return f
	return {}


## On completion, offer any quests this one unlocks (linear tutorial chains, arc continuations).
## chain_unlocks is an Array of quest spec dicts; each spec's "source" routes it (tutorial default).
func _process_chain_unlocks(quest: Dictionary) -> void:
	var unlocks = quest.get("chain_unlocks", [])
	if not (unlocks is Array):
		return
	for spec in unlocks:
		if not (spec is Dictionary) or spec.is_empty():
			continue
		_offer_chain_spec(spec, quest)


## Faction-siding branch: pick the branch whose condition scores HIGHEST (soft continuous
## geometry — the player's standing/state picks the path), and offer its unlock. chain_branch is
## [{when: <predicate>, unlock: <quest spec>}]. Only branches if the best score clears 0.5.
func _process_chain_branch(quest: Dictionary) -> void:
	var branches = quest.get("chain_branch", [])
	if not (branches is Array) or branches.is_empty():
		return
	var farm = _get_active_farm()
	var best_score := -1.0
	var best_unlock = null
	for br in branches:
		if not (br is Dictionary):
			continue
		var cond = br.get("when", {})
		var score := _quest_predicate_score(cond, farm) if cond is Dictionary else 0.0
		if score > best_score:
			best_score = score
			best_unlock = br.get("unlock", null)
	if best_unlock is Dictionary and not best_unlock.is_empty() and best_score >= 0.5:
		_offer_chain_spec(best_unlock, quest)


## Offer a chain/branch spec, routing by its "source" (tutorial default, story explicit).
func _offer_chain_spec(spec: Dictionary, parent_quest: Dictionary) -> void:
	var src := str(spec.get("source", Quest.SOURCE_TUTORIAL))
	if src == Quest.SOURCE_STORY:
		offer_story_quest(spec, str(parent_quest.get("source_flag", "")))
	else:
		offer_tutorial_quest(spec)


## Why the LAST complete_quest refused — read by QuestBoard so the settlement
## toast names the reason (marathon P1: "market could not settle" with ample
## resources gave players nothing to act on).
var last_complete_error: String = ""


func complete_quest(quest_id: int) -> bool:
	# Complete an active quest

	# Deducts required resources and grants rewards (including icon!)

	# Returns:
	# true if completed successfully
	last_complete_error = ""
	if not active_quests.has(quest_id):
		push_error("Cannot complete quest %d: not active" % quest_id)
		last_complete_error = "this commitment isn't active"
		return false

	var quest = active_quests[quest_id]
	var required_emoji = str(quest.get("resource", ""))
	var required_qty = int(quest.get("quantity", 0))
	if required_emoji.is_empty() or required_qty <= 0:
		push_warning("Cannot complete quest %d: invalid delivery target" % quest_id)
		last_complete_error = "it has no delivery ask"
		return false

	if economy == null:
		push_warning("QuestManager: economy not connected, cannot complete quest")
		last_complete_error = "no economy"
		return false

	# Fast resource check to avoid extra dictionary churn in tight rig loops.
	var held_qty = economy.get_resource(required_emoji)
	if held_qty < required_qty:
		push_warning("Cannot complete quest %d: insufficient resources" % quest_id)
		# d1-03: name the rule (asked qty) and the shortfall (held qty), not just the emoji —
		# matches QuestBoard's "deliver needs ×N — you hold M" wording (both numbers were
		# already in scope; the old message dropped them).
		last_complete_error = "deliver needs %s×%d — you hold %d" % [required_emoji, required_qty, int(held_qty)]
		return false

	var faction_name = str(quest.get("faction", "Unknown"))

	# Resource reward: route through the live MarketLattice only.
	# If the lattice is unavailable, fail loudly and do not mutate the quest.
	var granted_resources: Dictionary = {}
	var lat = _get_farm_market_lattice()
	if lat == null or not lat.has_method("synthesize_and_exercise"):
		push_error("QuestManager: market lattice required for quest completion")
		last_complete_error = "no market lattice"
		return false

	var exer: Dictionary = lat.synthesize_and_exercise(required_emoji, faction_name)
	if not exer.get("ok", false):
		push_error("QuestManager: market lattice exercise failed for quest %d: %s" % [
			quest_id,
			str(exer.get("error", "unknown"))
		])
		last_complete_error = "%s can't price %s here (%s)" % [
			faction_name, required_emoji, str(exer.get("error", "unknown"))]
		return false

	if not economy.remove_resource(required_emoji, required_qty, "quest_completion"):
		var player_has = economy.get_resource(required_emoji)
		push_error("Failed to deduct resources for quest %d: need %d %s, have %d" % [quest_id, required_qty, required_emoji, player_has])
		return false

	var out_emoji: String = str(exer.get("outcome", required_emoji))
	granted_resources[out_emoji] = int(exer.get("classical_reward", 0))

	# Vocabulary and standing always go through their own paths.
	var player_icons2 = _get_signature_emojis()
	var reward = QuestRewards.generate_reward(quest, null, player_icons2)
	_grant_icon_rewards(reward, faction_name)
	# Grant the coupling-tied RESOURCE reward — the market's payout. This is how a
	# DELIVER contract hands back resources the player's biome can't POP (e.g. 🔨 from
	# Millwright's Union). Previously only the exercise-outcome + icons were granted, so
	# the planned resource reward was computed and silently dropped.
	var plan_granted = _grant_resource_rewards(reward, faction_name)
	for plan_emoji in plan_granted:
		granted_resources[plan_emoji] = int(granted_resources.get(plan_emoji, 0)) + int(plan_granted[plan_emoji])
	_apply_standing_deltas(faction_name, reward.standing_deltas if reward else {})

	_finalize_quest_completion(quest_id, quest, reward, granted_resources)
	return true


func complete_or_claim(quest_id: int) -> bool:
	# Complete delivery quests or claim ready non-delivery quests.
	if not active_quests.has(quest_id):
		return false
	var quest = active_quests[quest_id]
	# Predicate-driven quests (tutorial steps, physics story quests) complete by
	# CLAIM when their soft bar fills — regardless of nominal type. Tutorial defs
	# carry no type, so Quest.make defaults them to DELIVERY (0); routing them
	# into delivery completion could never succeed (no resource/quantity ask).
	# Mirrors the QuestBoard's own ready→claim path.
	var qpreds = quest.get("state_predicates", [])
	if qpreds is Array and not qpreds.is_empty():
		return claim_quest(quest_id) if quest.get("status", "") == "ready" else false
	var quest_type = quest.get("type", QuestTypes.Type.DELIVERY)
	if quest_type == QuestTypes.Type.DELIVERY:
		return complete_quest(quest_id)
	# Non-delivery: must be ready
	if quest.get("status", "") == "ready":
		return claim_quest(quest_id)
	return false

# =============================================================================
# QUEST FAILURE
# =============================================================================

func fail_quest(quest_id: int, reason: String = "player_action") -> void:
	# Fail an active quest

	# Args:
	# quest_id: Quest to fail
	# reason: Why it failed (timeout, player_action, resource_shortage)
	if not active_quests.has(quest_id):
		return

	var quest = active_quests[quest_id]
	quest["status"] = "failed"
	quest["failed_at"] = Time.get_ticks_msec()
	quest["failure_reason"] = reason

	# Move to failed list
	active_quests.erase(quest_id)
	failed_quests.append(quest)

	# Stop timer
	_stop_quest_timer(quest_id)

	# Apply faction standing penalties for failure
	var fname: String = quest.get("faction", "")
	if fname != "":
		var failure_deltas: Dictionary = QuestRewards._standing_deltas_for_quest(quest, false)
		_apply_standing_deltas(fname, failure_deltas)

	quest_failed.emit(quest_id, reason)
	active_quests_changed.emit()


func _get_farm_market_lattice():
	var gsm = _get_gsm()
	var farm = gsm.get_active_farm() if gsm and gsm.has_method("get_active_farm") else null
	if farm == null:
		return null
	return farm.get_market_lattice() if farm.has_method("get_market_lattice") else null


func _apply_standing_deltas(faction_name: String, deltas: Dictionary) -> void:
	# Forward per-channel reputation deltas to the active Farm.
	# No-op if Farm or faction unavailable.
	if faction_name == "" or deltas == null or deltas.is_empty():
		return
	var gsm = _get_gsm()
	var farm = gsm.get_active_farm() if gsm and gsm.has_method("get_active_farm") else null
	if farm and farm.has_method("apply_standing_deltas"):
		farm.apply_standing_deltas(faction_name, deltas)


func _offer_from_market_lattice(biome) -> Array:
	# Delegate offer generation to the canonical MarketLattice substrate.
	# Returns pre-stamped quest dicts (sans id/offered_at — caller fills those).
	var gsm = _get_gsm()
	var farm = gsm.get_active_farm() if gsm and gsm.has_method("get_active_farm") else null
	if farm == null or not farm.has_method("get_market_lattice"):
		return []
	var lattice = farm.get_market_lattice()
	if lattice == null:
		return []
	# propose_offers returns MarketContract RefCounted objects; the pipeline projects each into
	# a canonical delivery quest (incl. the icon-pair vocab reward derivation).
	var contracts = lattice.propose_offers(biome, 196)
	var quests: Array = []
	for c in contracts:
		var quest := QuestPipeline.from_market_contract(c, biome)
		if not quest.is_empty():
			quests.append(quest)
	return quests

# =============================================================================
# QUEST READY/CLAIM (Non-delivery quests)
# =============================================================================

func mark_quest_ready(quest_id: int, completion_reason: String = "conditions_met") -> void:
	# Mark a non-delivery quest as ready to claim (conditions met)

	# The quest stays in active_quests but with status="ready".
	# Player must press Claim to receive rewards.
	if not active_quests.has(quest_id):
		return

	var quest = active_quests[quest_id]

	# Don't re-mark if already ready
	if quest.get("status") == "ready":
		return

	quest["status"] = "ready"
	quest["ready_at"] = Time.get_ticks_msec()
	quest["completion_reason"] = completion_reason

	quest_ready_to_claim.emit(quest_id)
	active_quests_changed.emit()

	# Break #1 (claim half): a predicate-driven tutorial step auto-claims the instant its bar
	# fills, so doing the mechanic both completes the step AND unlocks the next one — no hidden
	# C→Commitments R-claim. (The contracts step never reaches here; a DELIVERY completes via
	# complete_quest, not the ready→claim path.)
	if _tutorial_auto_advances(quest):
		claim_quest(quest_id)


func claim_quest(quest_id: int) -> bool:
	# Claim rewards for a ready non-delivery quest

	# Returns:
	# true if claimed successfully
	if not active_quests.has(quest_id):
		push_error("Cannot claim quest %d: not active" % quest_id)
		return false

	var quest = active_quests[quest_id]

	# Must be in ready state
	if quest.get("status") != "ready":
		push_warning("Cannot claim quest %d: not ready (status=%s)" % [quest_id, quest.get("status", "?")])
		return false

	# Generate and grant rewards
	var player_icons = _get_signature_emojis()
	var reward = QuestRewards.generate_reward(quest, null, player_icons)
	var faction_name = quest.get("faction", "Unknown")
	var granted_resources = _grant_resource_rewards(reward, faction_name)
	_grant_icon_rewards(reward, faction_name)
	_apply_standing_deltas(faction_name, reward.standing_deltas if reward else {})

	_finalize_quest_completion(quest_id, quest, reward, granted_resources)
	return true


# =============================================================================
# QUEST TIMERS
# =============================================================================

func _start_quest_timer(quest_id: int, duration: float) -> void:
	# Start countdown timer for quest
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(_on_quest_timeout.bind(quest_id))

	add_child(timer)
	quest_timers[quest_id] = timer
	timer.start()

func _stop_quest_timer(quest_id: int) -> void:
	# Stop and remove quest timer
	if quest_timers.has(quest_id):
		var timer = quest_timers[quest_id]
		timer.stop()
		timer.queue_free()
		quest_timers.erase(quest_id)

func _on_quest_timeout(quest_id: int) -> void:
	# Handle quest timer expiration
	if active_quests.has(quest_id):
		# Locked commitments never expire — the player pinned them to go gather the
		# deliverable and come back. (Defensive: locking also stops the timer.)
		if bool(active_quests[quest_id].get("locked", false)):
			return
		fail_quest(quest_id, "timeout")
		quest_expired.emit(quest_id)


## Pin/unpin a commitment. A locked commitment never expires, so the player can accept a
## contract they can't yet afford, go gather the deliverable, and come back to turn it in.
## Returns the new locked state (false if the quest isn't active).
func set_quest_locked(quest_id: int, locked: bool) -> bool:
	if not active_quests.has(quest_id):
		return false
	active_quests[quest_id]["locked"] = locked
	if locked:
		_stop_quest_timer(quest_id)            # pinned → countdown halted
	else:
		var tl: float = float(active_quests[quest_id].get("time_limit", -1))
		if tl > 0 and not quest_timers.has(quest_id):
			_start_quest_timer(quest_id, tl)   # un-pinned → resume the clock
	active_quests_changed.emit()
	return locked

func is_quest_locked(quest_id: int) -> bool:
	return active_quests.has(quest_id) and bool(active_quests[quest_id].get("locked", false))

func get_quest_time_remaining(quest_id: int) -> float:
	# Get seconds remaining on quest timer

	# Returns:
	# -1 if no time limit or timer not found
	if not quest_timers.has(quest_id):
		return -1.0

	return quest_timers[quest_id].time_left

# =============================================================================
# QUEST TYPE TRACKING (non-delivery quests)
# =============================================================================

## Observable resolution for the SHAPE/EVOLUTION trackers. Flat keys read
## directly from the observables dict; the DERIVED "balance:A/B" family (the
## ratio-quest ask) is computed from the per-atom populations:
##   balance = p_A / (p_A + p_B)  — 0.5 = even contest, 1.0 = A holds the pair.
## Returns -1.0 (unknown) when either population is missing, so trackers idle
## honestly instead of reading a fabricated zero.
func _observable_value(obs: Dictionary, name: String) -> float:
	if name.begins_with("balance:"):
		var pair := name.trim_prefix("balance:").split("/")
		if pair.size() != 2:
			return -1.0
		var key_a := "population:%s" % pair[0]
		var key_b := "population:%s" % pair[1]
		if not obs.has(key_a) or not obs.has(key_b):
			return -1.0
		var pa := float(obs.get(key_a, 0.0))
		var pb := float(obs.get(key_b, 0.0))
		return pa / (pa + pb) if (pa + pb) > 1e-9 else 0.5
	return float(obs.get(name, 0.0))


func _update_shape_achieve_quest(quest: Dictionary, _delta: float) -> void:
	var observable_name = quest.get("observable", "purity")
	var target_value := float(quest.get("target", 0.7))
	var comparison = quest.get("comparison", ">")

	var obs = get_biome_observables(current_biome)
	var current_value := _observable_value(obs, str(observable_name))
	if not _is_known_observable_value(current_value):
		return

	var progress: float
	if comparison == "<":
		progress = QuestMath.soft_gate_inv(current_value, target_value)
	else:
		progress = QuestMath.soft_gate(current_value, target_value)
	quest["progress"] = progress
	if progress >= 0.9:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "target_achieved")


func _update_shape_maintain_quest(quest: Dictionary, delta: float) -> void:
	var observable_name = quest.get("observable", "purity")
	var target_value := float(quest.get("target", 0.7))
	var comparison = quest.get("comparison", ">")
	var required_duration := float(quest.get("duration", 30.0))

	var obs = get_biome_observables(current_biome)
	var current_value := _observable_value(obs, str(observable_name))
	if not _is_known_observable_value(current_value):
		return

	var gate: float
	if comparison == "<":
		gate = QuestMath.soft_gate_inv(current_value, target_value)
	else:
		gate = QuestMath.soft_gate(current_value, target_value)

	# Accumulate when on-target; drain at equal rate when off-target.
	# Being "at the threshold" (gate=0.5) nets positive but slowly.
	quest["elapsed"] = QuestMath.smooth_accumulate(
			quest.get("elapsed", 0.0), gate, delta, 1.0)
	var progress: float = QuestMath.soft_gate(quest["elapsed"], required_duration * 0.9,
			required_duration * 0.05)
	quest["progress"] = progress
	if progress >= 0.9:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "maintained_duration")


func _update_evolution_quest(quest: Dictionary, _delta: float) -> void:
	var observable_name = quest.get("observable", "purity")
	var required_delta := float(quest.get("delta", 0.2))
	var direction = quest.get("direction", "increase")

	var obs = get_biome_observables(current_biome)
	var current_value := _observable_value(obs, str(observable_name))
	if not _is_known_observable_value(current_value):
		return

	if quest.get("initial_value") == null:
		quest["initial_value"] = current_value
		return

	var actual_change := current_value - float(quest["initial_value"])
	var signed_change := actual_change if direction == "increase" else -actual_change
	var progress: float = QuestMath.soft_gate(signed_change, required_delta)
	quest["progress"] = progress
	if progress >= 0.9:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "evolution_achieved")


func _update_entanglement_quest(quest: Dictionary, _delta: float) -> void:
	var target_coherence := float(quest.get("target_coherence", 0.6))

	var obs = get_biome_observables(current_biome)
	var current_coherence := float(obs.get("coherence", 0.0))
	if not _is_known_observable_value(current_coherence):
		return

	var progress: float = QuestMath.soft_gate(current_coherence, target_coherence)
	quest["progress"] = progress
	if progress >= 0.9:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "entanglement_created")


func _update_achieve_eigenstate_quest(quest: Dictionary, _delta: float) -> void:
	var target_purity := float(quest.get("target_purity", 0.95))

	var obs = get_biome_observables(current_biome)
	var current_purity := float(obs.get("purity", 0.0))
	if not _is_known_observable_value(current_purity):
		return

	var purity_score := QuestMath.soft_gate(current_purity, target_purity)
	var attractor_score := 1.0
	var target_emoji: String = quest.get("target_emoji", "")
	if target_emoji != "" and current_biome and current_biome.has_method("get_attractor_state"):
		var attractor: Dictionary = current_biome.get_attractor_state()
		attractor_score = QuestMath.soft_gate(attractor.get(target_emoji, 0.0), 0.45, 0.05)
	var progress: float = QuestMath.smooth_and([purity_score, attractor_score])
	quest["progress"] = progress
	if progress >= 0.9:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "eigenstate_achieved")


func _update_maintain_coherence_quest(quest: Dictionary, delta: float) -> void:
	var target_coherence := float(quest.get("target_coherence", 0.5))
	var required_duration := float(quest.get("duration", 30.0))

	var obs = get_biome_observables(current_biome)
	var current_coherence := float(obs.get("coherence", 0.0))
	if not _is_known_observable_value(current_coherence):
		return

	var gate := QuestMath.soft_gate(current_coherence, target_coherence)
	quest["elapsed"] = QuestMath.smooth_accumulate(
			quest.get("elapsed", 0.0), gate, delta, 1.0)
	var progress: float = QuestMath.soft_gate(quest["elapsed"], required_duration * 0.9,
			required_duration * 0.05)
	quest["progress"] = progress
	if progress >= 0.9:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "coherence_maintained")


func _update_induce_bell_state_quest(quest: Dictionary, _delta: float) -> void:
	var target_pair = quest.get("target_pair", [])
	var threshold := float(quest.get("threshold", 0.7))

	if target_pair.size() < 2:
		return

	if not current_biome or not current_biome.quantum_computer:
		return

	var qc = current_biome.quantum_computer
	var coherence := 0.0
	if qc.has_method("get_coherence"):
		var coh = qc.get_coherence(target_pair[0], target_pair[1])
		coherence = coh.abs() if coh else 0.0

	var progress: float = QuestMath.soft_gate(coherence, threshold)
	quest["progress"] = progress
	if progress >= 0.9:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "bell_state_achieved")


func _update_prevent_decoherence_quest(quest: Dictionary, delta: float) -> void:
	# Track PREVENT_DECOHERENCE: accumulate survival time above min_purity.
	# Dropping below does NOT instantly fail — instead the elapsed bank drains
	# at 2× speed, so a purity crash costs twice the time it took to earn.
	# This removes the cliff edge while preserving the urgency.
	var min_purity := float(quest.get("min_purity", 0.5))
	var required_duration := float(quest.get("duration", 60.0))

	var obs = get_biome_observables(current_biome)
	var current_purity := float(obs.get("purity", 0.0))

	var gate := QuestMath.soft_gate(current_purity, min_purity)
	quest["elapsed"] = QuestMath.smooth_accumulate(
			quest.get("elapsed", 0.0), gate, delta, 2.0)
	var progress: float = QuestMath.soft_gate(quest["elapsed"], required_duration * 0.9,
			required_duration * 0.05)
	quest["progress"] = progress
	if progress >= 0.9:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "decoherence_prevented")


func _update_collapse_deliberately_quest(quest: Dictionary, _delta: float) -> void:
	var target_emoji = quest.get("target_emoji", "")
	var target_probability := float(quest.get("target_probability", 0.8))

	if target_emoji.is_empty():
		return

	if not current_biome or not current_biome.quantum_computer:
		return

	var qc = current_biome.quantum_computer
	var probability := 0.0
	if qc.has_method("get_population"):
		probability = qc.get_population(target_emoji)

	var purity: float = float(qc.get_purity()) if qc.has_method("get_purity") else 0.0

	var prob_score := QuestMath.soft_gate(probability, target_probability)
	var purity_score := QuestMath.soft_gate(purity, 0.8)
	var progress: float = QuestMath.smooth_and([prob_score, purity_score])
	quest["progress"] = progress
	if progress >= 0.9:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "state_collapsed")


# =============================================================================
# QUERY FUNCTIONS
# =============================================================================

func _is_known_observable_value(value: float) -> bool:
	return value >= 0.0

func get_active_quests() -> Array:
	# Get all active quests as array
	return active_quests.values()


func get_story_offers() -> Array:
	# Get all pending story arc offers.
	return story_offers.values()


func dismiss_story_offer(quest_id: int) -> bool:
	# Remove a pending story arc offer from the current board view.
	if not story_offers.has(quest_id):
		return false
	story_offers.erase(quest_id)
	return true

func get_quest_by_id(quest_id: int) -> Dictionary:
	# Get quest data by ID (active quests first, then pending story offers).
	if active_quests.has(quest_id):
		return active_quests.get(quest_id, {})
	if story_offers.has(quest_id):
		return story_offers.get(quest_id, {})
	return {}

# =============================================================================
# SAVE / LOAD (quest ledger persistence — save v6)
# =============================================================================

## Deep-copy a quest dict for serialization. The generated QuestReward OBJECT
## (stamped by _finalize_quest_completion) is RefCounted and does not survive
## ResourceSaver; its plain-dict projection (reward_payload) is what history
## rows read, so the object is dropped.
static func _quest_save_copy(q: Dictionary) -> Dictionary:
	var out := q.duplicate(true)
	out.erase("reward")
	return out


## Serializable snapshot of the quest ledger: active commitments, contract
## history, and the id counter. quest_timers hold Timer NODES and are NOT
## serialized — restore_from_save_dict re-arms them from time_limit.
## story_offers are deliberately absent: offers are session state, regenerated
## on load by StoryEngine._restore_arc_quests_after_load / the market board.
func to_save_dict() -> Dictionary:
	var active_out: Dictionary = {}
	for qid in active_quests:
		var q = active_quests[qid]
		if q is Dictionary:
			active_out[int(qid)] = _quest_save_copy(q)
	var completed_out: Array = []
	for q in completed_quests:
		if q is Dictionary:
			completed_out.append(_quest_save_copy(q))
	var failed_out: Array = []
	for q in failed_quests:
		if q is Dictionary:
			failed_out.append(_quest_save_copy(q))
	return {
		"active": active_out,
		"completed": completed_out,
		"failed": failed_out,
		"next_quest_id": next_quest_id,
	}


## Restore the quest ledger from a save (v6+ quest_state section). Ordering
## contract (both load lanes — slot restart and path load — honor it):
## SessionLifecycle.reset_runtime_singletons CLEARS the session board first,
## then GameStateSerializer.apply_state_to_farm calls this, and only later
## does StoryEngine._restore_arc_quests_after_load re-offer arcs — its
## has_quest_for_flag guard then sees the restored actives, so an
## accepted-but-unclaimed teaching is never duplicated as a fresh offer.
## Empty dict (v4/v5 save, or a fresh game) = no-op: the board regenerates
## from persisted truth exactly as pre-v6 loads always did.
func restore_from_save_dict(data: Dictionary) -> void:
	if data == null or data.is_empty():
		return
	for quest_id in quest_timers.keys():
		_stop_quest_timer(quest_id)
	active_quests = {}
	var saved_active = data.get("active", {})
	if saved_active is Dictionary:
		for k in saved_active:
			var q = saved_active[k]
			if not (q is Dictionary):
				continue
			var qid: int = int(q.get("id", -1))
			if qid < 0 and str(k).is_valid_int():
				qid = int(str(k))
			if qid < 0:
				continue
			active_quests[qid] = q.duplicate(true)
			# Restored, not a new offer — never re-announce via quest_offered.
			_announced_offers[qid] = true
	var saved_completed = data.get("completed", [])
	completed_quests = saved_completed.duplicate(true) if saved_completed is Array else []
	var saved_failed = data.get("failed", [])
	failed_quests = saved_failed.duplicate(true) if saved_failed is Array else []
	# Monotonic: never rewind below ids already handed out this session, or
	# fresh offers would collide with restored quest ids.
	next_quest_id = maxi(next_quest_id, int(data.get("next_quest_id", 0)))
	# Re-arm expiry timers. Timer nodes don't serialize, so ELAPSED TIME RESETS:
	# a reloaded timed contract gets its full time_limit again (generous, and
	# honest about what a save can carry). Locked (pinned) commitments stay
	# timerless, mirroring set_quest_locked.
	for qid in active_quests:
		var q: Dictionary = active_quests[qid]
		if float(q.get("time_limit", -1)) > 0 and not bool(q.get("locked", false)):
			_start_quest_timer(qid, float(q.get("time_limit", -1)))
	# Defensive dedup: if an arc offer for the same flag somehow landed before
	# this restore ran, the restored active quest is the truth — drop the shadow.
	for oid in story_offers.keys():
		var sf := str(story_offers[oid].get("source_flag", ""))
		if sf == "":
			continue
		for q in active_quests.values():
			if str(q.get("source_flag", "")) == sf:
				story_offers.erase(oid)
				break
	active_quests_changed.emit()


# =============================================================================
# DEBUG / TESTING
# =============================================================================

func clear_all_quests() -> void:
	# Clear all quest data (testing only)
	for quest_id in quest_timers.keys():
		_stop_quest_timer(quest_id)

	active_quests.clear()
	story_offers.clear()
	completed_quests.clear()
	failed_quests.clear()
	next_quest_id = 0
	_announced_offers.clear()
	active_quests_changed.emit()
