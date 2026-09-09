extends "res://tests/smoke_test_base.gd"

## First-minute information flow. Instantiates Welcome, Arc, the offer toast
## path, HintToast expand-on-tap, and PredicateGloss farm-verb copy so a
## screenshot of "act 0 / REAP ×1 / soft_gate(x, 0, 0.05)" cannot ship again.
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
	_check(IntroVoice.welcome_verbs().size() == 3, "welcome has three verb cards")
	_check(IntroVoice.welcome_fiction().size() >= 2, "welcome fiction is more than one line")
	var step0 := {
		"category": "TUTORIAL",
		"tutorial_teaches": "core_loop",
		"body": "The Demos sleeps — wheat and people, waiting. Explore a plot, strike its qubit to collapse it, then gather what the collapse leaves behind.",
		"tutorial_hint": "Strike a plot (R), then gather the yield (Q). Tap a plot.",
		"state_predicates": [{"type": "gate_sequence_contains", "gate": "measure", "count": 1}],
	}
	_check(IntroVoice.live_ask_token(step0) == "strike", "step 0 live ask is strike")
	_check(IntroVoice.is_auto_tutorial(step0, null), "step 0 auto-advances")
	var toast: Dictionary = IntroVoice.toast_for_offer(step0, null)
	_check(int(toast.get("importance", 0)) == 3, "first lesson is a gold toast")
	var msg := str(toast.get("message", ""))
	_check(msg.contains("The Demos sleeps"), "first toast speaks the lesson", msg)
	_check(not msg.to_lower().contains("accept"), "auto-tutorial toast does not say accept", msg)
	_check(str(toast.get("detail", "")).contains("Strike"), "toast detail is the how")
	_check(str(toast.get("route", "")) == "arc", "toast tap still doors to Arc")

	var contracts := {
		"category": "TUTORIAL",
		"tutorial_teaches": "contracts",
		"body": "The Millwright's Union is buying.",
		"tutorial_hint": "Tap 📋 [C].",
		"state_predicates": [],
	}
	var ctoast: Dictionary = IntroVoice.toast_for_offer(contracts, null)
	_check(str(ctoast.get("detail", "")).to_lower().contains("accept"),
			"contracts step still teaches the accept door")


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
	_check(int(overlay.panel_size_mode) == int(OverlayBase.PanelSizeMode.LARGE), "welcome is LARGE")
	_check(overlay.dimmer_color.a <= 0.50, "welcome dimmer is glass",
			"alpha %.2f" % overlay.dimmer_color.a)
	_check(overlay.panel_title.contains("The Demos"), "welcome chrome names The Demos")
	# Walk the tree for the three verb titles.
	var titles := _collect_label_text(overlay)
	_check(titles.contains("Explore"), "welcome card Explore", titles)
	_check(titles.contains("Strike"), "welcome card Strike", titles)
	_check(titles.contains("Gather"), "welcome card Gather", titles)
	_check(titles.contains("Wake a sleeping plot"), "welcome card story", titles)
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
	var fired: Array = []
	var toast := HintToast.new()
	root.add_child(toast)
	toast.show_text("🌾 [b]The Demos sleeps[/b]\nwheat and people, waiting.", 3, "",
			func() -> void: fired.append(true),
			"Strike a plot — tap a live bubble (or R).")
	await process_frame
	_check(str(toast._label.text).contains("tap for more"),
			"unexpanded toast invites tap for more")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.global_position = toast.get_global_rect().position + Vector2(8, 8)
	toast._on_gui_input(click)
	_check(toast.is_expanded(), "first tap expands")
	_check(fired.is_empty(), "first tap does NOT travel")
	_check(is_instance_valid(toast) and not toast.is_queued_for_deletion(),
			"expanded toast stays")
	_check(toast._label.text.contains("Strike a plot"), "expanded toast shows the how")
	toast._on_gui_input(click)
	_check(fired.size() == 1, "second tap travels to Arc")
	var frames := 0
	while is_instance_valid(toast) and not toast.is_queued_for_deletion() and frames < 240:
		await process_frame
		frames += 1
	_check(not is_instance_valid(toast) or toast.is_queued_for_deletion(),
			"second tap flattens")


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
		"state_predicates": [{"type": "gate_sequence_contains", "gate": "measure", "count": 1}],
	}}

	var overlay := ControlsOverlay.new()
	root.add_child(overlay)
	await process_frame
	overlay._show_tab(ControlsOverlay.Tab.ARC)
	await process_frame

	var rows: Array = overlay._arc_rows()
	_check(rows.size() >= 2, "Arc has the live lesson and First Harvest")
	_check(str(rows[0].get("kind", "")) == "live_tutorial",
			"live tutorial leads the Arc", str(rows[0].get("kind", "")))
	_check(str(rows[1].get("kind", "")) == "flag_unfired",
			"First Harvest follows as a flag, not the featured door")

	var face := _collect_label_text(overlay)
	_check(face.contains("NOW"), "Arc wears NOW on the live lesson", face)
	_check(face.contains("The Demos sleeps"), "Arc postcard speaks the lesson", face)
	_check(not face.contains("act 0"), "Arc face has no act 0", face)
	_check(not face.contains("soft_gate"), "Arc face has no soft_gate", face)
	_check(not face.contains("0.00 / 0.85"), "Arc face has no 0.00/0.85", face)
	_check(not face.contains("gate_sequence_contains"), "Arc face has no raw predicate", face)
	_check(overlay.get_action_info("E").get("label", "") == "More", "E is More")

	# Select First Harvest (row 1) and confirm the beat, not the formula, is on the face.
	overlay._select_arc_row(1)
	await process_frame
	var harvest_face := _collect_label_text(overlay)
	_check(harvest_face.contains("First Harvest"), "First Harvest still listed", harvest_face)
	_check(harvest_face.contains("whole country answered") or harvest_face.contains("First Harvest"),
			"First Harvest selected shows story, not just a meter", harvest_face)
	_check(not harvest_face.contains("soft_gate"), "selected First Harvest has no soft_gate", harvest_face)
	var inspect := overlay._arc_inspect_text()
	_check(inspect.contains("structural count") or inspect.contains("Reap"),
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
	_check(gold.size() == 1, "auto-tutorial offer pushes a gold toast")
	if gold.size() == 1:
		var msg := str(gold[0].get("message", ""))
		_check(msg.contains("The Demos sleeps"), "gold toast is the lesson", msg)
		_check(not msg.to_lower().contains("accept"), "gold toast does not say accept", msg)
		_check(str(gold[0].get("detail", "")).contains("Strike"), "gold toast carries the how as detail")
		_check(str(gold[0].get("route", "")) == "arc", "gold toast still doors to Arc")
	bridge._quest_manager = null
	qm.queue_free()
