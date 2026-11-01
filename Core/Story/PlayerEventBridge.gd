extends Node

## PlayerEventBridge — translates game signals into PlayerEventLog entries.
## Autoloaded. Wakes on GameStateManager.farm_ready and chains to the relevant
## subsystems (quest_manager, economy, farm). Headless-safe: only writes to
## PlayerEventLog; spawning UI toasts is PlayerShell's job.

const IntroVoice = preload("res://Core/Story/IntroVoice.gd")
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
## Offer toasts the bridge has already spoken. quest_offered can fire, then
## farm_ready backfill walks the same story_offers — without this, one door
## is two gold cards.
var _announced_offer_ids: Dictionary = {}


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
	# Quest ids restart with the board. Stale ids from the previous farm
	# would swallow the next run's doors.
	_announced_offer_ids.clear()
	_fractal_intro_shown = false
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
	# Boot-race backfill: offers born during connect_to_farm (the tutorial
	# quest, StoryEngine re-offers) emit quest_offered BEFORE this bridge
	# wires — the announcement vanished and ACTIVITY read "No events yet" at
	# fresh boot (stooge round 1: 3/3 blind players never found the Arc tab).
	# _on_quest_offered is idempotent per quest id, so a later rewire does
	# not double the door.
	# Returning player: recap is the one card. Re-toasting every unsigned
	# offer on load stacked a second gold door on the same beat.
	var returning: bool = "story_flags_fired" in farm and farm.story_flags_fired.has("tutorial_seen")
	if _quest_manager != null and "story_offers" in _quest_manager:
		for q in _quest_manager.story_offers.values():
			if not (q is Dictionary):
				continue
			if returning:
				var qid := int(q.get("id", -1))
				if qid >= 0:
					_announced_offer_ids[qid] = true
				continue
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

func _push(message: String, importance: int, icon: String, category: String, path: String = "", route: String = "", detail: String = "") -> void:
	# Guarded /root/ lookup — bare autoload identifiers are compile bombs under
	# --check-only harnesses (same law as the GameStateManager lookup above).
	var log_node := get_node_or_null("/root/PlayerEventLog")
	if log_node and log_node.has_method("push"):
		log_node.push(message, importance, icon, category, path, route, detail)


func _on_icon_learned(north: String, south: String, faction: String) -> void:
	_push("📖 [b]%s / %s[/b]  taught by %s" % [north, south, faction], 2, "📖", "vocab", "V", "V")


func _on_story_flag_fired(flag_id: String, flag_data: Dictionary) -> void:
	# No Act-N entry card: the flag toast or the door offer already names
	# the beat. A third gold card on every chapter door was leftover.
	var toast: Dictionary = IntroVoice.toast_for_flag(flag_id, flag_data)
	if toast.is_empty():
		return
	_push(str(toast.get("message", "")), int(toast.get("importance", 3)),
			str(toast.get("icon", "✨")), "story",
			str(toast.get("path", "XY")), str(toast.get("route", "story")))


func _on_quest_completed(qid: int, rewards: Dictionary) -> void:
	_push("✅ %s — %s" % [_quest_name(qid), _format_rewards(rewards)], 1, "✅", "quest", "C")


func _on_quest_ready_to_claim(qid: int) -> void:
	# An auto-advancing tutorial step claims ITSELF one line after this signal
	# (mark_quest_ready → claim_quest) — a gold "C then U, then R" toast for it
	# is advice for an action the player cannot take by the time they read it
	# (anti-gating: false-help). The signal fires while the quest is still in
	# active_quests, so we can ask. Importance-1 keeps the beat in the
	# ACTIVITY feed without a toast; the story-flag/act toasts carry the moment.
	if _quest_manager != null:
		var q = _quest_manager.active_quests.get(qid) if "active_quests" in _quest_manager else null
		if q is Dictionary:
			var silent := false
			if _quest_manager.has_method("silent_auto_claims"):
				silent = bool(_quest_manager.silent_auto_claims(q))
			elif _quest_manager.has_method("tutorial_auto_advances"):
				silent = bool(_quest_manager.tutorial_auto_advances(q))
			# Banner already tracks the live ask (mill DELIVERY included).
			# A gold 🏆 on top of "Deliver 2× 🌾" was a second card.
			if not silent:
				var live: Dictionary = IntroVoice.live_quest()
				if int(live.get("id", -2)) == qid:
					silent = true
			if silent:
				_push("✅ %s — step complete" % _quest_name(qid), 1, "✅", "quest", "C")
				return
	# One spelling of the claim route, shared with the objective banner
	# (UIProgression.route_claim). This toast and the banner used to drift —
	# "C board" vs "Commitments (C → U)" — and the older spelling sent a
	# main-road playthrough to the wrong screen. The toast is now itself a
	# door: its route carries the quest id, so a body-tap lands on this very
	# contract's Commitments row (claim stays a deliberate click there).
	_push("🏆 [b]%s ready[/b]" % _quest_name(qid),
			3, "🏆", "quest", "C", "commitments:%d" % qid)


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
	# Lane steps are silent (banner already tracks them). Unsigned offers
	# toast as a room-change: tap opens Arc. Empty dict = no toast.
	# Idempotent: signal + farm_ready backfill used to speak the same door twice.
	var qid := int(quest.get("id", -1))
	if qid >= 0:
		if _announced_offer_ids.has(qid):
			return
		_announced_offer_ids[qid] = true
	var toast: Dictionary = IntroVoice.toast_for_offer(quest, _quest_manager)
	if toast.is_empty():
		return
	_push(str(toast.get("message", "")), int(toast.get("importance", 1)),
			str(toast.get("icon", "📜")), "quest", str(toast.get("path", "Q")),
			str(toast.get("route", "")), str(toast.get("detail", "")))


func _on_quest_failed(qid: int, reason: String) -> void:
	_push("❌ %s failed — %s" % [_quest_name(qid), reason], 2, "❌", "quest", "C", "C")


func _on_quest_expired(_qid: int) -> void:
	# Importance 2: at 1 this was dropped by show_hint and commitments
	# vanished silently (fleet: "accepted quest disappears without a word").
	# Routes to the History sub-view — expired commitments land in
	# failed_quests, which only that view renders.
	_push("⌛ a commitment ran out of time",
			2, "⌛", "quest", "C", "commitments_history")


func _on_purchase_failed(reason: String) -> void:
	_push("⚠ %s" % reason, 2, "⚠", "economy", "")


# Player words for wallet-mutation reasons. Ambient trickles (drain, composting)
# are logged too — a wallet delta with no trace reads as haunted (fleet: "🐺+2
# appeared after a refused action"; it was StarterForest's drain trickle).
const REASON_WORDS := {
	"quest_completion": "quest",
	"plot_harvest": "gather",
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
	# The 1D lane is the ask. Standing weather stacking over Strike / mill /
	# the loom (playtest: three 🤝 cards plus a refusal while the banner
	# said "weave") hid the live verb. Self still holds the snapshot.
	if UIProgression.current_tutorial_step() != UIProgression.NO_TUTORIAL_SENTINEL:
		return
	# Felt weather, not a ledger. ±0.12 lives behind E on Self.
	var msg := "🤝 %s" % IntroVoice.felt_standing(faction, channel, delta)
	_push(msg, 2, "🤝", "faction", "XT", "self")


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
