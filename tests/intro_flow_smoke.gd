extends "res://tests/smoke_test_base.gd"

## First-minute information flow. Instantiates Welcome, Arc, the offer toast
## path, HintToast tracker+link, and PredicateGloss farm-verb copy so a
## screenshot of "act 0 / REAP ×1 / soft_gate(x, 0, 0.05)" cannot ship again.
## The lane is silent (banner is the ask). Unsigned offers toast to Arc.
##
## Run: godot --headless --path . --script tests/intro_flow_smoke.gd

const IntroVoice := preload("res://Core/Story/IntroVoice.gd")
const PredicateGloss := preload("res://Core/Quests/PredicateGloss.gd")


class ArcQMStub:
	extends Node
	var story_offers: Dictionary = {}
	var active_quests: Dictionary = {}
	var accepted: Array = []

	func get_story_offers() -> Array:
		return story_offers.values()

	func get_all_story_flags() -> Array:
		return [{
			"id": "first_harvest",
			"display_name": "First Harvest",
			"act": 0,
			"campaign": "demos",
			"arc_beat": "You turned time forward and the whole country answered.",
			"predicates": [{"type": "gate_sequence_contains", "gate": "reap", "count": 1}],
		}]

	func evaluate_predicate_score(_p) -> float:
		return 0.0

	func evaluate_flag_score(_f) -> float:
		return 0.0

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
	var terminal_pool = null
	var grid = null
	var faction_density = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Intro flow smoke ===")
	_check_intro_voice()
	_check_gloss()
	await _check_welcome()
	await _check_toast_expand()
	await _check_arc_postcard()
	_check_offer_toast()
	_finish("Intro flow smoke")


func _check_intro_voice() -> void:
	_check(IntroVoice.welcome_title().contains("The Demos"), "welcome title names The Demos")
	_check(IntroVoice.welcome_verbs().size() == 3, "spine still names the three first verbs")
	_check(IntroVoice.welcome_fiction().size() == 2, "welcome fiction is identity, not a lesson")
	_check(IntroVoice.welcome_footer().to_lower().contains("tap"),
			"welcome footer is a dismiss, not a second door")
	_check(not IntroVoice.welcome_footer().to_lower().contains("arc"),
			"welcome is identity; the 1D lane auto-accepts onto the banner")
	var step0 := {
		"category": "TUTORIAL",
		"tutorial_teaches": "core_loop",
		"body": "The Demos sleeps — wheat and people, waiting. Explore a plot, strike its qubit to collapse it, then gather what the collapse leaves behind.",
		"tutorial_hint": "Strike a plot (R), then gather the yield (Q). Tap a plot.",
		"state_predicates": [{"type": "gate_sequence_contains", "gate": "measure", "count": 1}],
	}
	_check(IntroVoice.live_ask_token(step0) == "strike", "step 0 live ask is strike")
	_check(IntroVoice.is_auto_tutorial(step0, null), "step 0 is the auto-accepted lane")
	var toast: Dictionary = IntroVoice.toast_for_offer(step0, null)
	_check(toast.is_empty(), "auto-tutorial does not dual-gold the banner")

	var contracts := {
		"category": "TUTORIAL",
		"tutorial_teaches": "contracts",
		"body": "The Millwright's Union is buying.",
		"tutorial_hint": "Deliver 2× 🌾 to the mill.",
		"state_predicates": [],
	}
	_check(IntroVoice.is_auto_tutorial(contracts, null), "the mill is in the lane")
	var ctoast: Dictionary = IntroVoice.toast_for_offer(contracts, null)
	_check(ctoast.is_empty(), "mill offer is silent — Commitments is the fill room")

	var optional := {
		"category": "ARC",
		"source_flag": "village_stirs",
		"body": "The village stirs.",
		"faction": "Hearth Keepers",
	}
	var otoast: Dictionary = IntroVoice.toast_for_offer(optional, null)
	_check(str(otoast.get("message", "")).to_lower().contains("arc"),
			"unsigned offer names the Arc as the door")
	_check(str(otoast.get("route", "")) == "arc", "unsigned toast doors to Arc")


func _check_gloss() -> void:
	var reap := {"type": "gate_sequence_contains", "gate": "reap", "count": 1}
	var form := PredicateGloss.formula(reap, null)
	_check(form.contains("structural count"), "reap formula is a structural count", form)
	_check(not form.contains("soft_gate"), "reap formula is not a soft_gate at 0", form)
	_check(not form.contains("≥ 0"), "reap formula does not say ≥ 0", form)
	var summ := PredicateGloss.summary(reap, null)
	_check(summ.contains("Reap the season"), "reap summary is player-voice", summ)
	_check(summ.contains("(8)"), "reap summary names Ace hat digit", summ)
	var strike := {"type": "gate_sequence_contains", "gate": "measure", "count": 1}
	var ssumm := PredicateGloss.summary(strike, null)
	_check(ssumm.contains("Strike"), "measure summary says Strike", ssumm)
	_check(ssumm.contains("tap"), "measure summary names the tap", ssumm)


func _check_welcome() -> void:
	var overlay := WelcomeOverlay.new()
	root.add_child(overlay)
	await process_frame
	_check(int(overlay.panel_size_mode) == int(OverlayBase.PanelSizeMode.MEDIUM), "welcome is MEDIUM")
	_check(overlay.dimmer_color.a <= 0.50, "welcome dimmer is glass",
			"alpha %.2f" % overlay.dimmer_color.a)
	_check(overlay.panel_title.contains("The Demos"), "welcome chrome names The Demos")
	var titles := _collect_label_text(overlay)
	_check(titles.contains("quantum language"), "welcome speaks identity", titles)
	_check(titles.to_lower().contains("tap anywhere"), "welcome footer is a dismiss", titles)
	_check(not titles.to_lower().contains("arc"), "welcome is not a second door to Arc", titles)
	_check(not titles.contains("Wake a sleeping plot"), "welcome does not reprint the verb cards", titles)
	_check(not titles.contains("THE FIRST MINUTE"), "welcome is not a keymap wall")
	overlay.queue_free()
	await process_frame


func _collect_label_text(n: Node) -> String:
	var bits: Array[String] = []
	_collect_label_text_into(n, bits)
	return " ".join(bits)


func _collect_label_text_into(n: Node, bits: Array) -> void:
	if n is Label:
		bits.append((n as Label).text)
	elif n is RichTextLabel:
		bits.append((n as RichTextLabel).text)
	for c in n.get_children():
		_collect_label_text_into(c, bits)


func _check_toast_expand() -> void:
	# Intro toasts are tracker + link: no detail reprint, first tap opens
	# the Arc. Unique ephemeral detail (non-intro) still expands in place.
	var fired: Array = []
	var toast := HintToast.new()
	root.add_child(toast)
	toast.show_text("🌾 [b]The Demos sleeps[/b]", 3, "",
			func() -> void: fired.append(true),
			"")
	await process_frame
	var toast_body := str(toast._label.text)
	_check(toast_body.contains("[X] opens the Arc") or toast_body.contains("[F] opens the Arc"),
			"tracker toast names a key, not a tap-only Arc")
	_check(not toast.is_expanded(), "tracker toast has no expand rung")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.global_position = toast.get_global_rect().position + Vector2(8, 8)
	var scooted: Array = []
	toast._on_scoot = func() -> void: scooted.append(true)
	toast._ladder.has_scoot = true
	toast._on_gui_input(click)
	_check(fired.size() == 1, "first tap travels to Arc")
	_check(scooted.is_empty(), "first tap does not scoot")
	_check(not toast.is_expanded(), "first tap does not expand")
	_check(is_instance_valid(toast) and not toast.is_queued_for_deletion(),
			"home tap keeps the toast for the scoot")
	toast._on_gui_input(click)
	_check(scooted.size() == 1, "second tap scoots")
	var frames := 0
	while is_instance_valid(toast) and not toast.is_queued_for_deletion() and frames < 240:
		await process_frame
		frames += 1
	_check(not is_instance_valid(toast) or toast.is_queued_for_deletion(),
			"scoot flattens")

	var unique := HintToast.new()
	root.add_child(unique)
	unique.show_text("⏳ a pause", 2, "", Callable(), "E holds time. F plays on.")
	await process_frame
	_check(str(unique._label.text).contains("tap to go there") or not unique._ladder.has_detail,
			"notification refuses detail even when a how-line is passed")
	_check(not unique.is_expanded(), "notification does not start expanded")
	var unique_click := InputEventMouseButton.new()
	unique_click.button_index = MOUSE_BUTTON_LEFT
	unique_click.pressed = true
	unique_click.global_position = unique.get_global_rect().position + Vector2(8, 8)
	unique._on_gui_input(unique_click)
	_check(not unique.is_expanded(), "notification does not expand on tap")
	unique.queue_free()
	await process_frame


func _check_arc_postcard() -> void:
	var gsm = root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		_fail("GameStateManager autoload available")
		return
	var qm := ArcQMStub.new()
	root.add_child(qm)
	var farm := FarmStub.new()
	farm.quest_manager = qm
	root.add_child(farm)
	var prev = gsm.active_farm
	gsm.active_farm = farm

	qm.active_quests = {1: {
		"id": 1,
		"category": "TUTORIAL",
		"tutorial_teaches": "core_loop",
		"body": "The Demos sleeps — wheat and people, waiting.",
		"tutorial_hint": "Strike a plot (R), then gather the yield (Q).",
		"math_note": "Fires the instant the gate ledger records 1 measure gate (a single R-strike) — a structural count, not a soft gate.",
		"state_predicates": [{"type": "gate_sequence_contains", "gate": "measure", "count": 1}],
	}}

	var overlay := ControlsOverlay.new()
	root.add_child(overlay)
	await process_frame
	overlay._show_tab(ControlsOverlay.Tab.ARC)
	await process_frame

	var rows: Array = overlay._arc_rows()
	_check(rows.size() >= 1, "Arc has the live lesson")
	_check(str(rows[0].get("kind", "")) == "live_tutorial",
			"live tutorial leads the Arc", str(rows[0].get("kind", "")))
	var kinds: Array = []
	var titles: Array = []
	for r in rows:
		kinds.append(str(r.get("kind", "")))
		var beat: Dictionary = r.get("beat", {})
		titles.append(str(beat.get("title", r.get("flag", {}).get("display_name", ""))))
	_check(not titles.has("First Harvest"),
			"First Harvest is a toast, not an Arc door", ",".join(titles))
	_check(not titles.has("Timber Country — The Door"),
			"Woodlot does not peek during the strike lesson", ",".join(titles))

	var face := _collect_label_text(overlay)
	_check(face.contains("NOW"), "Arc wears NOW on the live lesson", face)
	_check(face.contains("The Demos sleeps"), "Arc postcard speaks the lesson", face)
	_check(not face.contains("act 0"), "Arc face has no act 0", face)
	_check(not face.contains("soft_gate"), "Arc face has no soft_gate", face)
	_check(not face.contains("0.00 / 0.85"), "Arc face has no 0.00/0.85", face)
	_check(not face.contains("gate_sequence_contains"), "Arc face has no raw predicate", face)
	_check(overlay.get_action_info("E").get("label", "") == "Inspect", "E is Inspect")

	# Inspect the live lesson — physics stays on E, not the face.
	overlay._select_arc_row(0)
	await process_frame
	var inspect := overlay._arc_inspect_text()
	_check(inspect.contains("structural count") or inspect.contains("Strike") or inspect.contains("measure"),
			"E-inspect still has the physics", inspect)

	gsm.active_farm = prev
	overlay.queue_free()
	qm.queue_free()
	farm.queue_free()
	await process_frame


func _check_offer_toast() -> void:
	var event_log = root.get_node_or_null("/root/PlayerEventLog")
	var bridge = root.get_node_or_null("/root/PlayerEventBridge")
	if event_log == null or bridge == null:
		_fail("PlayerEventLog + PlayerEventBridge autoloads")
		return
	event_log.clear()
	var qm := ArcQMStub.new()
	root.add_child(qm)
	bridge._quest_manager = qm
	var step0 := {
		"id": 7,
		"category": "TUTORIAL",
		"tutorial_teaches": "core_loop",
		"faction": "Hearth Keepers",
		"body": "The Demos sleeps — wheat and people, waiting. Explore a plot, strike, then gather.",
		"tutorial_hint": "Strike a plot — tap a live bubble (or R).",
		"state_predicates": [{"type": "gate_sequence_contains", "gate": "measure", "count": 1}],
	}
	bridge._on_quest_offered(step0)
	var gold: Array = event_log.get_recent(5, 3)
	_check(gold.size() == 0, "auto-tutorial offer does not dual-gold the banner")
	var optional := {
		"id": 8,
		"category": "ARC",
		"source_flag": "village_stirs",
		"faction": "Hearth Keepers",
		"body": "The village stirs.",
	}
	bridge._on_quest_offered(optional)
	gold = event_log.get_recent(5, 3)
	_check(gold.size() == 1, "unsigned offer is a gold toast")
	if gold.size() == 1:
		_check(str(gold[0].get("route", "")) == "arc", "unsigned toast doors to Arc")
		_check(not str(gold[0].get("message", "")).to_lower().contains("accept"),
				"unsigned toast does not dump the accept how")
	bridge._on_quest_offered(optional)
	gold = event_log.get_recent(5, 3)
	_check(gold.size() == 1, "rewire/backfill does not double the door toast")
	var door_flag := IntroVoice.toast_for_flag("arc_handover", {
		"display_name": "The Wheel Is Yours",
		"arc_quest": {"body": "Open the Arc and read the island's open doors."},
	})
	_check(door_flag.is_empty(), "a flag that opens a door does not also gold-card the flag")
	var beat_flag := IntroVoice.toast_for_flag("first_harvest", {
		"display_name": "First Harvest",
		"arc_quest": null,
		"predicates": [{"type": "gate_sequence_contains", "gate": "reap", "count": 1}],
	})
	_check(beat_flag.is_empty(),
			"First Harvest is the Wheel's beat — no second gold card to Story")
	var recognition := IntroVoice.toast_for_flag("two_tables", {
		"display_name": "Two Tables",
		"predicates": [{"type": "story_flag_set", "id": "village_stirs"}],
	})
	_check(str(recognition.get("message", "")).contains("Two Tables"),
			"a flag with no door still toasts the beat")
	var handoff := IntroVoice.toast_for_flag("loom_opens", {
		"display_name": "The Loom Opens",
		"predicates": [],
	})
	_check(handoff.is_empty(), "hat-unlock handoff flags do not gold-card mid-lane")
	bridge._quest_manager = null
	qm.queue_free()
