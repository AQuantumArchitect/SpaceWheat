extends Node

## PlayerEventBridge — translates game signals into PlayerEventLog entries.
## Autoloaded. Wakes on GameStateManager.farm_ready and chains to the relevant
## subsystems (quest_manager, economy, farm). Headless-safe: only writes to
## PlayerEventLog; spawning UI toasts is PlayerShell's job.

# Route phrases (accept/claim doors) come from the objective authority so the
# toast and the banner can never drift apart again. Core→UI preload is
# precedented (QuantumEdgeRenderer, BatchedBubbleRenderer do the same).
const UIProgression = preload("res://UI/Core/UIProgression.gd")

var _farm: Node = null
var _quest_manager: Node = null
var _economy: Node = null
var _instrument = null   # QuantumInstrument (RefCounted, not a Node)
var _wired := false
## First-icon-descent onboarding beat (task #405, Track 2 pattern from 63dd82f9):
## the first successful icon injection that opens a fractal child world earns
## ONE guided hint pointing at the new indigo descend satellite. Session-only
## (not persisted) — purely a one-time nudge, never a gate; re-injecting after
## this fires is silent, same as any other repeat action.
var _fractal_intro_shown := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Guarded /root/ lookup, not the bare autoload identifier (compile bomb under
	# --check-only harnesses — same law as PlotGridDisplay/BiomeInspectorOverlay).
	var gsm := get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_signal("farm_ready"):
		gsm.farm_ready.connect(_on_farm_ready)


func _on_farm_ready(farm: Node, _state) -> void:
	# Re-wire on EVERY new farm. The old one-shot guard (_wired) left this
	# bridge bound to the previous farm after a path-load created a fresh one
	# — ACTIVITY read "No events yet" forever on loaded saves (marathon #8).
	if farm == null or farm == _farm:
		return
	_farm = farm
	# The quest manager lives on the SHELL, not the farm — resolving it off
	# the farm returned null every boot, so quest events (offers, ready,
	# expiry) NEVER reached ACTIVITY. Same disease as the BootManager QM
	# rebind no-op: go through the locator's shell path.
	_quest_manager = InstrumentLocator.resolve_quest_manager(self, farm)
	_economy = _resolve(farm, "economy")
	# QuantumInstrument is a RefCounted (not a Node), so _resolve's Node cast
	# would drop it — grab it directly off the farm.
	_instrument = farm.instrument if ("instrument" in farm) else null
	_wire_quest_signals()
	_wire_economy_signals()
	_wire_farm_signals()
	_wire_instrument_signals()
	_wired = true
	# Seed the act-entry announcer from the LOADED position so resuming a
	# mid-campaign save doesn't replay "Act N" toasts for acts already lived.
	_announced_act = _current_act_now()
	# Boot-race backfill: offers born during connect_to_farm (the tutorial
	# quest, StoryEngine re-offers) emit quest_offered BEFORE this bridge
	# wires — the announcement vanished and ACTIVITY read "No events yet" at
	# fresh boot (stooge round 1: 3/3 blind players never found the Arc tab).
	# Pending offers are still pending, so announcing them on (re)wire is
	# re-orientation, not a duplicate.
	if _quest_manager != null and "story_offers" in _quest_manager:
		for q in _quest_manager.story_offers.values():
			if q is Dictionary:
				_on_quest_offered(q)


func _resolve(farm: Node, prop: String) -> Node:
	if prop in farm:
		var v = farm.get(prop)
		return v if v is Node else null
	return null


func _connect_once(obj: Object, sig: String, cb: Callable) -> void:
	# Rewiring runs per-farm; the quest manager can be the SAME autoload
	# across farms, so guard against double-connects.
	if obj != null and obj.has_signal(sig) and not obj.is_connected(sig, cb):
		obj.connect(sig, cb)


func _wire_quest_signals() -> void:
	_connect_once(_quest_manager, "icon_learned", _on_icon_learned)
	_connect_once(_quest_manager, "story_flag_fired", _on_story_flag_fired)
	_connect_once(_quest_manager, "quest_completed", _on_quest_completed)
	_connect_once(_quest_manager, "quest_ready_to_claim", _on_quest_ready_to_claim)
	_connect_once(_quest_manager, "quest_offered", _on_quest_offered)
	_connect_once(_quest_manager, "quest_failed", _on_quest_failed)
	_connect_once(_quest_manager, "quest_expired", _on_quest_expired)


func _wire_economy_signals() -> void:
	_connect_once(_economy, "purchase_failed", _on_purchase_failed)
	_connect_once(_economy, "resource_mutated", _on_resource_mutated)


func _wire_farm_signals() -> void:
	_connect_once(_farm, "standing_changed", _on_standing_changed)
	_connect_once(_farm, "biome_loaded", _on_biome_loaded)


func _wire_instrument_signals() -> void:
	_connect_once(_instrument, "action_performed", _on_instrument_action_performed)


# ─────────────── handlers ───────────────

func _push(message: String, importance: int, icon: String, category: String, path: String = "", route: String = "") -> void:
	# Guarded /root/ lookup — bare autoload identifiers are compile bombs under
	# --check-only harnesses (same law as the GameStateManager lookup above).
	var log_node := get_node_or_null("/root/PlayerEventLog")
	if log_node and log_node.has_method("push"):
		log_node.push(message, importance, icon, category, path, route)


func _on_icon_learned(north: String, south: String, faction: String) -> void:
	_push("📖 [b]%s / %s[/b]  taught by %s" % [north, south, faction], 2, "📖", "vocab", "V")


# ─────────────── act-entry announcement ───────────────
# The campaign's acts were invisible: no transition was ever announced
# anywhere (the postcard fires on act COMPLETION, headed-only, and act 5's
# was unreachable). When the contiguous-prefix current act grows, mark the
# entry once — a gold toast naming the act and its chapter movement.

var _announced_act: int = -1


func _current_act_now() -> int:
	if _farm == null or not ("story_flags_fired" in _farm) \
			or _quest_manager == null or not _quest_manager.has_method("get_all_story_flags"):
		return -1
	return StoryAtlas.current_act(_farm.story_flags_fired, _quest_manager.get_all_story_flags())


func _maybe_announce_act_entry() -> void:
	var act := _current_act_now()
	if act < 0 or _announced_act < 0 or act <= _announced_act:
		_announced_act = maxi(_announced_act, act)
		return
	_announced_act = act
	_push("🎬 [b]Act %d[/b] — %s" % [act, StoryAtlas.chapter_for_act(act)],
			3, "🎬", "story", "XI")


func _on_story_flag_fired(flag_id: String, flag_data: Dictionary) -> void:
	_maybe_announce_act_entry()
	var display := str(flag_data.get("display_name", flag_id))
	# Sentence-boundary cut, not .left(80): beats run 300-700 chars and the
	# old hard cut showed ~13% of the average beat, sliced mid-word. The [XY]
	# path chip is the breadcrumb to the full prose (X→Y story log).
	var beat := StoryAtlas.sentence_cut(str(flag_data.get("arc_beat", "")), 160)
	var grants: Dictionary = flag_data.get("standing_grants", {})
	var msg := "✨ [b]%s[/b]  %s" % [display, beat]
	if not grants.is_empty():
		var parts: Array[String] = []
		for f in grants:
			# standing_grants is {faction: {channel: delta}} (story_flags.json) — the
			# per-channel dict, NOT a scalar. float(<Dictionary>) threw "Nonexistent
			# 'float' constructor" on every grant-bearing flag (forest_evolving, …); flatten
			# to one "faction channel +Δ" fragment per channel. (Flat {faction: delta} tolerated.)
			var ch = grants[f]
			if ch is Dictionary:
				for c in ch:
					parts.append("%s %s %+.2f" % [str(f), str(c), float(ch[c])])
			else:
				parts.append("%s %+.2f" % [str(f), float(ch)])
		msg += "\n   " + ", ".join(parts)
	_push(msg, 3, "✨", "story", "XY")


func _on_quest_completed(qid: int, rewards: Dictionary) -> void:
	_push("✅ %s — %s" % [_quest_name(qid), _format_rewards(rewards)], 1, "✅", "quest", "Q")


func _on_quest_ready_to_claim(qid: int) -> void:
	# An auto-advancing tutorial step claims ITSELF one line after this signal
	# (mark_quest_ready → claim_quest) — a gold "C then U, then R" toast for it
	# is advice for an action the player cannot take by the time they read it
	# (anti-gating: false-help). The signal fires while the quest is still in
	# active_quests, so we can ask. Importance-1 keeps the beat in the
	# ACTIVITY feed without a toast; the story-flag/act toasts carry the moment.
	if _quest_manager != null and _quest_manager.has_method("tutorial_auto_advances"):
		var q = _quest_manager.active_quests.get(qid) if "active_quests" in _quest_manager else null
		if q is Dictionary and _quest_manager.tutorial_auto_advances(q):
			_push("✅ %s — step complete" % _quest_name(qid), 1, "✅", "quest", "Q")
			return
	# One spelling of the claim route, shared with the objective banner
	# (UIProgression.route_claim). This toast and the banner used to drift —
	# "C board" vs "Commitments (C → U)" — and the older spelling sent a
	# main-road playthrough to the wrong screen. The toast is now itself a
	# door: its route carries the quest id, so a body-tap lands on this very
	# contract's Commitments row (claim stays a deliberate click there).
	_push("🏆 [b]%s ready to claim[/b] — tap here, or %s" % [_quest_name(qid), UIProgression.route_claim()],
			3, "🏆", "quest", "Q", "commitments:%d" % qid)


## Player words for a quest id. Raw ids leaked into toasts ("❌ Quest
## 2416248927 failed") — the number means nothing to the player; the
## faction on the board is what they recognize.
func _quest_name(qid: int) -> String:
	var q = null
	if _quest_manager != null:
		for pool_name in ["active_quests", "story_offers"]:
			if pool_name in _quest_manager and _quest_manager.get(pool_name) is Dictionary:
				var hit = _quest_manager.get(pool_name).get(qid)
				if hit is Dictionary:
					q = hit
					break
		if q == null:
			# fail/complete paths erase from active BEFORE emitting — the
			# quest has already landed in history.
			for pool_name in ["failed_quests", "completed_quests"]:
				if pool_name in _quest_manager and _quest_manager.get(pool_name) is Array:
					for hq in _quest_manager.get(pool_name):
						if hq is Dictionary and int(hq.get("id", -1)) == qid:
							q = hq
							break
				if q != null:
					break
	if q is Dictionary:
		var fac := str(q.get("faction", "")).strip_edges()
		var res := str(q.get("resource", "")).strip_edges()
		var qty := int(q.get("quantity", 0))
		if fac != "" and res != "" and qty > 0:
			return "%s contract (%s×%d)" % [fac, res, qty]
		if fac != "":
			return "%s quest" % fac
	return "Quest %d" % qid


func _on_quest_offered(quest: Dictionary) -> void:
	# A story/arc/tutorial offer deserves an actual toast, not a log-only
	# entry — this used to check is_arc/from_story_flag, fields QuestPipeline
	# never sets (dead code; every offer landed at importance 1 and never hit
	# the screen). category and source_flag ARE the real fields
	# from_tutorial_def/from_story_def populate (Core/Quests/QuestPipeline.gd).
	var is_arc := str(quest.get("category", "")) == "TUTORIAL" \
		or str(quest.get("source_flag", "")).strip_edges() != ""
	var fac := str(quest.get("faction", ""))
	if fac.strip_edges() == "":
		fac = "the story"
	# Say WHERE: offers wait on the Arc tab, and no surface pointed there —
	# every blind round-1 tester starved two keypresses from the on-ramp.
	# Route phrase shared with the banner (click-first, keys as accelerators).
	# The gold toast is itself a door ("tap here" → Arc); the market branch is
	# log-only (importance 1 never toasts), so its line must not say "here" —
	# in the Story ACTIVITY feed there is no here to tap.
	if is_arc:
		_push("📜 New offer from %s — tap here to read & accept (or %s)" % [fac, UIProgression.route_accept()],
				3, "📜", "quest", "Q", "arc")
	else:
		_push("📜 New offer from %s — to read & accept: %s" % [fac, UIProgression.route_accept()],
				1, "📜", "quest", "Q")


func _on_quest_failed(qid: int, reason: String) -> void:
	_push("❌ %s failed — %s" % [_quest_name(qid), reason], 2, "❌", "quest", "Q")


func _on_quest_expired(_qid: int) -> void:
	# Importance 2: at 1 this was dropped by show_hint and commitments
	# vanished silently (fleet: "accepted quest disappears without a word").
	# Routes to the History sub-view — expired commitments land in
	# failed_quests, which only that view renders.
	_push("⌛ a commitment ran out of time — tap here to see it (📋 Commitments · History)",
			2, "⌛", "quest", "Q", "commitments_history")


func _on_purchase_failed(reason: String) -> void:
	_push("⚠ %s" % reason, 2, "⚠", "economy", "")


# Player words for wallet-mutation reasons. Ambient trickles (drain, composting)
# are logged too — a wallet delta with no trace reads as haunted (fleet: "🐺+2
# appeared after a refused action"; it was StarterForest's drain trickle).
const REASON_WORDS := {
	"quest_completion": "quest",
	"plot_harvest": "harvest",
	"trade": "trade",
	"synthesis": "synthesis",
	"lindblad_drain": "field drain",
	"lindblad_rainbow": "field drain",
	"composting": "composting",
}


## resource_mutated grew a 5th arg (biome_name) in d8126c22; this handler was never
## updated, so EVERY mutation since errored the connection and the "🌾 +23 (extract)"
## chatter toasts died silently (caught by the polish-pass rig re-verification).
func _on_resource_mutated(emoji: String, delta: float, reason: String, _amount: float, _biome_name: String = "") -> void:
	if reason in REASON_WORDS:
		var sign_str: String = "+" if delta >= 0 else ""
		_push("%s %s%d (%s)" % [emoji, sign_str, int(delta), REASON_WORDS[reason]], 1, emoji, "resource", "")


func _on_standing_changed(faction: String, channel: String, delta: float, new_value: float) -> void:
	if absf(delta) < 0.05:
		return
	# Plain words, not a ledger line — "🤝 Packlords · trust +0.12 → 0.45"
	# read as noise to a playtester ("some toast about packlords and 🤝 or
	# something, no idea what that means").
	var direction := "grows" if delta >= 0 else "slips"
	var msg := "🤝 Your %s with the %s %s (%+.2f)" % [channel, faction, direction, delta]
	_push(msg, 2, "🤝", "faction", "XT")


func _on_biome_loaded(biome_name: String, _biome_ref) -> void:
	_push("🗺 Biome loaded: %s" % biome_name, 1, "🗺", "biome", "")


## First-icon-descent onboarding beat (task #405): the first icon injection
## that opens a fractal child world (FractalWorldService.on_inject, called
## inside QuantumInstrument.action_inject_icon_pair) earns one guided nudge
## toward the new indigo descend satellite next to that register — same
## importance/toast path every other one-off beat here already uses (PlayerShell
## turns importance>=2 PlayerEventLog entries into a show_hint toast). Purely
## guidance: nothing here blocks or gates the injection itself.
func _on_instrument_action_performed(action: String, result: Dictionary) -> void:
	if _fractal_intro_shown or action != "inject_icon":
		return
	if not bool(result.get("success", false)):
		return
	if str(result.get("fractal_child_id", "")) == "":
		return
	_fractal_intro_shown = true
	_push("🟣 a new world has opened — tap the indigo glow beside it to step inside",
		2, "🟣", "fractal", "")


func _format_rewards(rewards: Dictionary) -> String:
	var parts: Array[String] = []
	for k in rewards.get("resource_rewards", {}):
		parts.append("%s×%d" % [k, int(rewards["resource_rewards"][k])])
	for p in rewards.get("learned_pairs", []):
		parts.append("%s/%s" % [str(p.get("north", "?")), str(p.get("south", "?"))])
	return ", ".join(parts) if not parts.is_empty() else "none"
