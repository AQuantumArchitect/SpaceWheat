class_name CampaignFixture
extends RefCounted

## Beat fixtures — "start at beat X" for play and for tests.
##
## start_at_beat(farm, quest_manager, beat_id) builds the state a player would
## hold at the moment `beat_id` OPENS, from the compiled spec alone
## (Core/Quests/data/story_flags.json ← Core/Campaign/campaign.json):
##
##   1. the Act-0 tutorial chain is played out through the real claim path
##      (each step marked ready + claimed, so its rewards and unlock_flags land
##      exactly as a played step's do);
##   2. every ancestor beat (the `requires` closure, parents first — the same
##      order tools/campaign/spec.py:ancestors() returns) is fired through
##      QuestManager._fire_story_flag, so StoryEngine applies its on_open
##      standing grants and offers its arc quest exactly as in play;
##   3. what the ancestor's objective asked of the world is put there when the
##      game has a seam for it — standing raised to its standing_gte gate,
##      berry counters restored to its berry_* gate (the save/load seam),
##      atoms planted for atom_in_biome (the biome's own register add), and
##      the biome it charted loaded (Farm.open_biome, the tail of discovery);
##   4. its door is completed through the real accept → ready → claim path, so
##      has_completed_flag() is true, its teaching pair is learned and the
##      claim's standing reward lands;
##   5. the target beat's own trigger atoms are planted, and the wallet is
##      topped up to a modest, spec-derived floor.
##
## The target beat itself is NOT fired here: QuestManager's evaluator opens it
## on its next physics frame, because its requires now hold — so its offer
## appears through the same path a player's would. (The rig verb waits for
## that and can force it only when asked.)
##
## What it cannot reproduce is reported, never faked: gate-ledger counts
## (reap/inject/measure history), physics readings (coherence, spectral gap,
## biome_state, signature size, diversity), and charted biomes that do not fit
## the six biome slots (a player culls to make room; the fixture keeps the
## biomes the beat itself reads, then the most recently charted).

const FLAG_FIRE_THRESHOLD := 0.85

## Set while a fixture replays ancestors. Presentation listeners that would
## otherwise fire a ceremony for a replayed beat (act postcards, the
## island_free ending) read this and stay quiet.
static var _replaying: bool = false
static var _replay_frame: int = -1
## True only inside a start_at_beat replay. Replay is synchronous, so the flag
## is also scoped to the frame it was raised in: a script error mid-replay can
## never leave postcards and the ending ceremony muted for the session.
static var replaying: bool:
	get:
		return _replaying and _replay_frame == Engine.get_process_frames()
	set(value):
		_replaying = value
		_replay_frame = Engine.get_process_frames() if value else -1

## Wallet floor: every resource the spec says a story step spends is topped up
## to twice its low-water mark; the staple goods get a flat floor.
const STAPLE_FLOOR := {"🌾": 20, "🍞": 20, "👥": 20}


# =============================================================================
# SPEC READING (compiled story flags)
# =============================================================================

static func flag_index(qm) -> Dictionary:
	var out := {}
	if qm == null or not qm.has_method("get_all_story_flags"):
		return out
	for f in qm.get_all_story_flags():
		if f is Dictionary:
			out[str(f.get("id", ""))] = f
	return out


## The beats this beat requires (its story_flag_set predicates, in authored order).
static func requires_of(flag: Dictionary) -> Array:
	var out: Array = []
	for p in flag.get("predicates", []):
		if p is Dictionary and str(p.get("type", "")) == "story_flag_set":
			out.append(str(p.get("id", "")))
	return out


static func _arc(flag: Dictionary) -> Dictionary:
	var aq = flag.get("arc_quest")
	return aq if aq is Dictionary else {}


## What completing the beat asks: the arc quest's state_predicates, or (for an
## auto beat) the non-requires predicates its flag fires on.
static func objective_of(flag: Dictionary) -> Array:
	var aq := _arc(flag)
	if not aq.is_empty():
		var sp = aq.get("state_predicates", [])
		return sp if sp is Array else []
	var out: Array = []
	for p in flag.get("predicates", []):
		if p is Dictionary and str(p.get("type", "")) != "story_flag_set":
			out.append(p)
	return out


## What must hold for an OFFERED beat to open beyond its requires (the spec's
## `trigger`, e.g. a village path's atom). Auto beats fold trigger and
## objective together; objective_of() covers them.
static func trigger_of(flag: Dictionary) -> Array:
	if _arc(flag).is_empty():
		return []
	var out: Array = []
	for p in flag.get("predicates", []):
		if p is Dictionary and str(p.get("type", "")) != "story_flag_set":
			out.append(p)
	return out


## Ancestors of beat_id, parents before children — identical traversal to
## tools/campaign/spec.py:ancestors (DFS over requires in order, post-order).
static func ancestors(qm, beat_id: String, index: Dictionary = {}) -> Array:
	if index.is_empty():
		index = flag_index(qm)
	var order: Array = []
	var seen := {}
	if not index.has(beat_id):
		return order
	for r in requires_of(index[beat_id]):
		_visit(str(r), index, seen, order)
	return order


static func _visit(bid: String, index: Dictionary, seen: Dictionary, order: Array) -> void:
	if seen.has(bid) or not index.has(bid):
		return
	seen[bid] = true
	for r in requires_of(index[bid]):
		_visit(str(r), index, seen, order)
	order.append(bid)


static func _teach_pair(flag: Dictionary) -> Array:
	var aq := _arc(flag)
	var n := str(aq.get("reward_north", ""))
	var s := str(aq.get("reward_south", ""))
	return [n, s] if n != "" and s != "" else []


static func _biomes_in(preds: Array) -> Array:
	var out: Array = []
	for p in preds:
		if p is Dictionary and p.has("biome") and not (str(p["biome"]) in out):
			out.append(str(p["biome"]))
	return out


# =============================================================================
# START AT BEAT
# =============================================================================

static func start_at_beat(farm, qm, beat_id: String, opts: Dictionary = {}) -> Dictionary:
	var report := {
		"ok": false, "beat": beat_id, "ancestors": [], "fired": [], "doors": [],
		"tutorial_steps": [], "biomes_loaded": [], "biomes_skipped": [],
		"atoms_planted": [], "standing_raised": [], "berries": [],
		"icons_learned": [], "unreproduced": [], "wallet": {}, "notes": [],
	}
	if farm == null or qm == null or not ("story_flags_fired" in farm):
		report["error"] = "no_farm_or_quest_manager"
		return report
	var index := flag_index(qm)
	if not index.has(beat_id):
		report["error"] = "unknown_beat"
		return report
	if farm.story_flags_fired.has(beat_id):
		report["notes"].append("beat already fired on this farm")

	var anc := ancestors(qm, beat_id, index)
	report["ancestors"] = anc
	replaying = true
	_complete_tutorial(farm, qm, report)
	_load_charted_biomes(farm, index, anc, beat_id, report)
	for aid in anc:
		_replay_ancestor(farm, qm, index, str(aid), anc, report)
	# The target's own trigger (an offered beat that opens on a world fact,
	# e.g. village_path_industrial needs 🏭 in the Village): plant it.
	var target: Dictionary = index[beat_id]
	for p in trigger_of(target):
		if str(p.get("type", "")) == "atom_in_biome":
			_plant_atom(farm, index, anc, str(p.get("biome", "")), str(p.get("atom", "")), report, beat_id)
		else:
			report["unreproduced"].append({"beat": beat_id, "trigger": str(p.get("type", ""))})
	if bool(opts.get("wallet", true)):
		report["wallet"] = _top_up_wallet(farm)
	replaying = false
	report["ok"] = true
	report["requires_resolved"] = requires_resolved(qm, farm, beat_id, index)
	return report


## True when every beat beat_id requires has fired AND its door is resolved —
## the evaluator's own reading (story_flag_set scores 1.0).
static func requires_resolved(qm, farm, beat_id: String, index: Dictionary = {}) -> bool:
	if index.is_empty():
		index = flag_index(qm)
	if not index.has(beat_id):
		return false
	for r in requires_of(index[beat_id]):
		if not farm.story_flags_fired.has(str(r)):
			return false
		if qm.has_method("flag_door_is_resolved") and not qm.flag_door_is_resolved(str(r)):
			return false
	return true


# -----------------------------------------------------------------------------
# Act 0
# -----------------------------------------------------------------------------

static func _tutorial_quest(qm) -> Dictionary:
	for q in qm.active_quests.values():
		if q is Dictionary and str(q.get("category", "")) == "TUTORIAL":
			return q
	for q in qm.story_offers.values():
		if q is Dictionary and str(q.get("category", "")) == "TUTORIAL":
			return q
	return {}


## Play out the tutorial chain through the real ready → claim path: each
## claim applies the step's rewards, fires its unlock_flags (loom_opens) and
## chain-offers the next step (auto-accepted by the lane).
static func _complete_tutorial(farm, qm, report: Dictionary) -> void:
	if not farm.story_flags_fired.has("tutorial_seen") and qm.has_method("maybe_start_tutorial"):
		qm.maybe_start_tutorial(farm)
	for _i in range(16):
		var tq := _tutorial_quest(qm)
		if tq.is_empty():
			break
		var qid := int(tq.get("id", -1))
		if qm.story_offers.has(qid):
			qm.accept_quest(tq)
		if qm.active_quests.has(qid):
			qm.mark_quest_ready(qid, "campaign_fixture")
		if qm.active_quests.has(qid):
			qm.claim_quest(qid)
		if qm.active_quests.has(qid):
			# Could not claim (should not happen): retire it rather than loop.
			qm.retire_quest(qid, "campaign_fixture")
		report["tutorial_steps"].append(str(tq.get("tutorial_teaches", qid)))
	report["unreproduced"].append({"beat": "tutorial", "what": "gate ledger (measure/hadamard/bell/reap counts)"})


# -----------------------------------------------------------------------------
# Biomes
# -----------------------------------------------------------------------------

static func _load_charted_biomes(farm, index: Dictionary, anc: Array, beat_id: String, report: Dictionary) -> void:
	var charted: Array = []  # in ancestor order
	for aid in anc:
		var b := str(index[aid].get("chart", ""))
		if b != "" and not (b in charted):
			charted.append(b)
	if charted.is_empty():
		return
	var router = farm._get_active_biome_router() if farm.has_method("_get_active_biome_router") else null
	var free := 99
	if router != null and router.has_method("get_open_slot_count"):
		free = int(router.get_open_slot_count())
	# Priority: biomes the target beat itself reads, then most recently charted.
	var wanted := _biomes_in(objective_of(index[beat_id]) + trigger_of(index[beat_id]))
	var order: Array = []
	for b in wanted:
		if b in charted:
			order.append(b)
	var rev := charted.duplicate()
	rev.reverse()
	for b in rev:
		if not (b in order):
			order.append(b)
	var chosen: Array = []
	for b in order:
		if farm.grid != null and farm.grid.get_biome(b) != null:
			chosen.append(b)  # already loaded: no slot needed
		elif free > 0:
			chosen.append(b)
			free -= 1
		else:
			report["biomes_skipped"].append(b)
	# Load in story order, so the slot row reads the way the road went.
	for b in charted:
		if not (b in chosen):
			continue
		var res: Dictionary = farm.open_biome(b, false) if farm.has_method("open_biome") else {}
		if res.get("success", false):
			report["biomes_loaded"].append(b)
		else:
			report["biomes_skipped"].append(b)
			report["notes"].append("open_biome(%s): %s" % [b, str(res.get("message", "failed"))])


# -----------------------------------------------------------------------------
# One ancestor
# -----------------------------------------------------------------------------

static func _replay_ancestor(farm, qm, index: Dictionary, aid: String, anc: Array, report: Dictionary) -> void:
	var flag: Dictionary = qm._story_flag_by_id(aid) if qm.has_method("_story_flag_by_id") else index[aid]
	if flag.is_empty():
		flag = index[aid]
	if not farm.story_flags_fired.has(aid):
		qm._fire_story_flag(flag, farm)
		report["fired"].append(aid)
	# The world the objective asked for.
	_reproduce_objective(farm, index, aid, anc, report)
	# The door.
	var aq := _arc(flag)
	if aq.is_empty():
		return
	if qm.has_completed_flag(aid):
		return
	var q := _find_arc_quest(qm, aid)
	if q.is_empty():
		# StoryEngine absent (bare harness): offer it the way StoryEngine does.
		var qid_new: int = qm.offer_story_quest(aq.duplicate(true), aid)
		q = qm.get_quest_by_id(qid_new)
	if q.is_empty():
		report["notes"].append("no arc quest for %s" % aid)
		return
	var qid := int(q.get("id", -1))
	if qm.story_offers.has(qid):
		qm.accept_quest(q)
	if qm.active_quests.has(qid):
		qm.mark_quest_ready(qid, "campaign_fixture")
	if qm.active_quests.has(qid):
		qm.claim_quest(qid)
	if qm.has_completed_flag(aid):
		report["doors"].append(aid)
	else:
		report["notes"].append("door for %s did not complete" % aid)
	var pair := _teach_pair(flag)
	if not pair.is_empty():
		farm.discover_icon(pair[0], pair[1])
		report["icons_learned"].append("%s%s" % [pair[0], pair[1]])


static func _find_arc_quest(qm, flag_id: String) -> Dictionary:
	for q in qm.story_offers.values():
		if q is Dictionary and str(q.get("source_flag", "")) == flag_id:
			return q
	for q in qm.active_quests.values():
		if q is Dictionary and str(q.get("source_flag", "")) == flag_id:
			return q
	return {}


static func _reproduce_objective(farm, index: Dictionary, aid: String, anc: Array, report: Dictionary) -> void:
	var berry_need := {}  # biome -> [count, phase]
	for p in objective_of(index[aid]):
		if not (p is Dictionary):
			continue
		var t := str(p.get("type", ""))
		match t:
			"standing_gte":
				_raise_standing(farm, str(p.get("faction", "")), str(p.get("channel", "trust")),
						float(p.get("value", 0.0)), report)
			"berry_consumed_count_gte":
				var b := str(p.get("biome", ""))
				var cur: Array = berry_need.get(b, [0, 0.0])
				cur[0] = maxi(int(cur[0]), int(ceil(float(p.get("value", 0)))))
				berry_need[b] = cur
			"berry_total_phase_gte":
				var b2 := str(p.get("biome", ""))
				var cur2: Array = berry_need.get(b2, [0, 0.0])
				cur2[1] = maxf(float(cur2[1]), float(p.get("value", 0.0)) + 0.01)
				berry_need[b2] = cur2
			"atom_in_biome":
				_plant_atom(farm, index, anc, str(p.get("biome", "")), str(p.get("atom", "")), report, aid)
			"biome_evolving", "story_flag_any", "active_biome_is":
				pass  # charted biomes load above; a fork pick is its own beat; standing places are transient
			_:
				report["unreproduced"].append({"beat": aid, "objective": t})
	for b in berry_need:
		_restore_berries(farm, str(b), int(berry_need[b][0]), float(berry_need[b][1]), report)


static func _raise_standing(farm, faction: String, channel: String, value: float, report: Dictionary) -> void:
	if faction == "" or not farm.has_method("get_or_create_standing"):
		return
	var cur := float(farm.get_or_create_standing(faction).to_dict().get(channel, 0.0))
	if cur + 1e-9 >= value:
		return
	farm.apply_standing_deltas(faction, {channel: value - cur + 1e-6}, false)
	report["standing_raised"].append({"faction": faction, "channel": channel, "from": cur, "to": value})


static func _restore_berries(farm, biome_name: String, count: int, phase: float, report: Dictionary) -> void:
	var biome = farm.grid.get_biome(biome_name) if farm.grid != null else null
	if biome == null or biome.get("quantum_computer") == null:
		report["unreproduced"].append({"what": "berries", "biome": biome_name, "reason": "biome not loaded"})
		return
	var reg = biome.quantum_computer.berry_register
	var c0: int = reg.get_consumed_count()
	var p0: float = reg.get_consumed_phase()
	# Only what the ancestor asked for: inflating phase past its own gate
	# would pre-pay a later beat's berry_total_phase_gte.
	var want_phase := phase
	if c0 >= count and p0 >= want_phase:
		return
	reg.restore_consumed(maxi(c0, count), maxf(p0, want_phase))
	report["berries"].append({"biome": biome_name, "count": reg.get_consumed_count(),
			"phase": reg.get_consumed_phase()})


## Put `atom` into `biome_name`'s register: the same register add the Icon
## hat's inject uses (BiomeBase.expand_quantum_system + Farm.discover_icon),
## without its cost. The pole pair is the teaching that carries the atom
## (ancestors first), else a pair the player already knows.
static func _plant_atom(farm, index: Dictionary, anc: Array, biome_name: String, atom: String,
		report: Dictionary, for_beat: String) -> void:
	var biome = farm.grid.get_biome(biome_name) if farm.grid != null else null
	if biome == null or biome.get("quantum_computer") == null:
		report["unreproduced"].append({"beat": for_beat, "atom": atom, "biome": biome_name, "reason": "biome not loaded"})
		return
	var reg = biome.quantum_computer.register_map
	if reg != null and reg.coordinates.has(atom):
		return
	var pair := _pair_for_atom(farm, index, anc, atom)
	if pair.is_empty():
		report["unreproduced"].append({"beat": for_beat, "atom": atom, "reason": "no pair carries it"})
		return
	var cap := ActionCostRuntime.get_max_biome_qubits(farm)
	var n: int = biome.get_total_register_count() if biome.has_method("get_total_register_count") else 0
	if cap > 0 and n >= cap:
		report["unreproduced"].append({"beat": for_beat, "atom": atom, "reason": "biome at qubit cap"})
		return
	var res: Dictionary = biome.expand_quantum_system(pair[0], pair[1])
	if res.get("success", false):
		farm.discover_icon(pair[0], pair[1])
		report["atoms_planted"].append({"biome": biome_name, "pair": "%s%s" % [pair[0], pair[1]], "for": for_beat})
	else:
		report["unreproduced"].append({"beat": for_beat, "atom": atom, "reason": str(res.get("error", "expand failed"))})


static func _pair_for_atom(farm, index: Dictionary, anc: Array, atom: String) -> Array:
	for aid in anc:
		var p := _teach_pair(index[aid])
		if not p.is_empty() and atom in p:
			return p
	for icon in farm.get_known_icons():
		if icon is Dictionary and (str(icon.get("north", "")) == atom or str(icon.get("south", "")) == atom):
			return [str(icon["north"]), str(icon["south"])]
	for fid in index:
		var p2 := _teach_pair(index[fid])
		if not p2.is_empty() and atom in p2:
			return p2
	return []


# -----------------------------------------------------------------------------
# Wallet
# -----------------------------------------------------------------------------

static func _top_up_wallet(farm) -> Dictionary:
	var econ = farm.get("economy")
	if econ == null or not econ.has_method("add_resource"):
		return {}
	var floor_by := STAPLE_FLOOR.duplicate()
	var res := CampaignRuntime.resources()
	for emoji in res:
		var row = res[emoji]
		if row is Dictionary:
			floor_by[str(emoji)] = maxi(int(floor_by.get(str(emoji), 0)), 2 * int(row.get("low_water", 5)))
	var added := {}
	for emoji in floor_by:
		var have := int(econ.get_resource(emoji))
		var want := int(floor_by[emoji])
		if have < want:
			econ.add_resource(emoji, want - have, "campaign_fixture")
			added[emoji] = want - have
	return added


# =============================================================================
# DEV JUMP — Escape → Dev → "start at beat…"
# =============================================================================

## Start a fresh demos_normal run and apply start_at_beat once its farm is
## live. The jumper node lives on the tree root so it survives the GameRoot
## remount the restart performs.
static func jump(beat_id: String, scenario_id: String = "demos_normal") -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	var gsm = tree.root.get_node_or_null("/root/GameStateManager")
	if gsm == null or not ("session_lifecycle" in gsm) or gsm.session_lifecycle == null:
		return false
	var old = tree.root.get_node_or_null("CampaignFixtureJumper")
	if old != null:
		old.queue_free()
	var j := _Jumper.new()
	j.name = "CampaignFixtureJumper"
	j.beat_id = beat_id
	tree.root.add_child(j)
	gsm.session_lifecycle.request_fresh_restart(false, scenario_id)
	return true


class _Jumper extends Node:
	var beat_id: String = ""
	var _armed_frames: int = 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_delta: float) -> void:
		_armed_frames += 1
		if _armed_frames > 60 * 120:
			push_warning("CampaignFixture: gave up waiting for a fresh farm to start %s" % beat_id)
			queue_free()
			return
		if _armed_frames < 10:
			return  # let the restart tear the old session down first
		var gsm = get_tree().root.get_node_or_null("/root/GameStateManager")
		if gsm == null or not gsm.has_method("get_active_farm"):
			return
		var farm = gsm.get_active_farm()
		if farm == null or not is_instance_valid(farm):
			return
		if not (farm.has_method("is_boot_finalized") and farm.is_boot_finalized()):
			return
		var qm = InstrumentLocator.resolve_quest_manager(self, farm)
		if qm == null:
			return
		# The shell connects the quest manager a beat after farm_ready.
		var se = get_tree().root.get_node_or_null("/root/StoryEngine")
		if se != null and "_farm" in se and se._farm != farm:
			return
		var rep := CampaignFixture.start_at_beat(farm, qm, beat_id)
		print("CampaignFixture: start_at_beat(%s) → %d ancestors, %d doors, biomes %s" % [
			beat_id, (rep.get("ancestors", []) as Array).size(),
			(rep.get("doors", []) as Array).size(), str(rep.get("biomes_loaded", []))])
		queue_free()
