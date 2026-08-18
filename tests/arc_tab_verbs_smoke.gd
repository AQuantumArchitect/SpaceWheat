extends "res://tests/smoke_test_base.gd"

## Pins the 2026-08-17 Arc-tab honesty fixes ("X i g does nothing"):
## - verb chips derive from the SELECTED row's kind (Accept/Dismiss only on
##   offer rows; blank + speaking refusal on story-flag rows),
## - re-selecting the already-selected row flashes instead of dead-returning,
## - accept on a flag row refuses without touching quest state.
## Plus the ready-to-claim toast law: an auto-advancing tutorial step logs at
## importance 1 (no gold "C then U" advice for an action that auto-claims).


class ArcQMStub:
	extends Node
	var story_offers: Dictionary = {}
	var active_quests: Dictionary = {}
	var accepted: Array = []

	func get_story_offers() -> Array:
		return story_offers.values()

	func get_all_story_flags() -> Array:
		return [{
			"id": "smoke_flag",
			"display_name": "Smoke Flag",
			"act": 0,
			"campaign": "demos",
			"predicates": [{"type": "gate_sequence_contains", "gate": "reap", "count": 1}],
		}]

	func evaluate_predicate_score(_p) -> float:
		return 0.2

	func evaluate_flag_score(_f) -> float:
		return 0.2

	func accept_quest(q) -> bool:
		accepted.append(q)
		return true

	func tutorial_auto_advances(quest: Dictionary) -> bool:
		if str(quest.get("category", "")) != "TUTORIAL":
			return false
		var preds = quest.get("state_predicates", [])
		return preds is Array and not preds.is_empty()


class FarmStub:
	extends Node
	var story_flags_fired: Dictionary = {}
	var quest_manager: Node = null
	# MusicManager polls the active farm every frame; a stub without this
	# property spams script errors from its fallback probe.
	var terminal_pool = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Arc tab verbs smoke ===")

	var gsm = root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		_fail("GameStateManager autoload available")
		_finish("Arc tab verbs smoke")
		return

	var qm := ArcQMStub.new()
	root.add_child(qm)
	var farm := FarmStub.new()
	farm.quest_manager = qm
	root.add_child(farm)
	var prev_farm = gsm.active_farm
	gsm.active_farm = farm

	qm.story_offers = {3: {"id": 3, "category": "ARC", "faction": "Hearth Keepers",
		"body": "an offer", "state_predicates": []}}

	var overlay := ControlsOverlay.new()
	root.add_child(overlay)
	await process_frame
	overlay._show_tab(ControlsOverlay.Tab.ARC)
	await process_frame

	# Row 0 = the offer (offers sort first), row 1 = the unfired flag.
	var rows: Array = overlay._arc_rows()
	_check(rows.size() == 2, "stub yields one offer row and one flag row")
	_check(str(rows[0].get("kind", "")) == "arc_quest", "offer row leads the list")
	_check(overlay._arc_selected_idx == 0, "row 0 is the default selection")
	_check(str(overlay.get_action_info("R").get("label", "")) == "Accept",
		"offer row declares R = Accept")
	_check(str(overlay.get_action_info("Q").get("label", "")) == "Dismiss",
		"offer row declares Q = Dismiss")

	# Selecting the flag row blanks Q/R (push_action_infos normalizes missing
	# keys to the "—" chip; OverlayBase then no-ops them and speaks the
	# refusal on both input paths — no silent dead key).
	overlay._select_arc_row(1)
	await process_frame
	_check(str(overlay.get_action_info("R").get("label", "")) == "—",
		"flag row blanks R to the dash chip")
	_check(str(overlay.get_action_info("Q").get("label", "")) == "—",
		"flag row blanks Q to the dash chip")
	_check(str(overlay.get_action_info("E").get("label", "")) == "Refresh",
		"E stays declared on flag rows")
	_check(not overlay._action_key_declared_live("R"), "R is gated off flag rows")

	# Re-selecting the selected row must not crash and must not be a silent
	# no-op path (the flash tween is the feedback; here we just pin no-crash
	# and that selection holds).
	overlay._select_arc_row(1)
	await process_frame
	_check(overlay._arc_selected_idx == 1, "same-row re-select keeps the selection")

	# Accept on a flag row refuses without touching quest state.
	overlay._accept_selected_arc()
	_check(qm.accepted.is_empty(), "accept on a story-flag row leaves quest state untouched")

	# Back on the offer row, accept goes through.
	overlay._select_arc_row(0)
	await process_frame
	_check(str(overlay.get_action_info("R").get("label", "")) == "Accept",
		"re-declaration follows the selection back to the offer row")
	overlay._accept_selected_arc()
	_check(qm.accepted.size() == 1, "accept on the offer row commits it")

	# --- ready-to-claim toast law (PlayerEventBridge) ---
	var bridge = root.get_node_or_null("/root/PlayerEventBridge")
	var event_log = root.get_node_or_null("/root/PlayerEventLog")
	if bridge != null and event_log != null:
		event_log.clear()
		bridge._quest_manager = qm
		# Auto-advancing tutorial step: importance-1 line, never the gold toast.
		qm.active_quests = {11: {"id": 11, "category": "TUTORIAL", "faction": "Hearth Keepers",
			"state_predicates": [{"type": "gate_sequence_contains", "gate": "reap", "count": 1}]}}
		bridge._on_quest_ready_to_claim(11)
		var gold_rows := 0
		for e in event_log.get_recent(5, 3):
			gold_rows += 1
		_check(gold_rows == 0, "auto-claiming tutorial step pushes no importance-3 toast")
		_check(event_log.get_recent(5, 1).size() > 0, "the step-complete beat still reaches the log")
		# A real contract keeps the gold ready-to-claim toast.
		event_log.clear()
		qm.active_quests = {12: {"id": 12, "category": "", "faction": "Millwright's Union",
			"resource": "🌾", "quantity": 2}}
		bridge._on_quest_ready_to_claim(12)
		_check(event_log.get_recent(5, 3).size() == 1, "a real contract keeps the gold ready toast")
		bridge._quest_manager = null
	else:
		_check(false, "PlayerEventBridge/PlayerEventLog autoloads available")

	gsm.active_farm = prev_farm
	_finish("Arc tab verbs smoke")
