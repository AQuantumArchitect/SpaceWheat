extends "res://tests/smoke_test_base.gd"

## One-strand cinch: banner ask, toast, Arc row, recap, and standing weather
## compose from IntroVoice. Face copy has no Act-N, no ±0.12, no math: dump.
##
## Run: godot --headless --path . --script tests/narrative_spine_smoke.gd

const IntroVoice := preload("res://Core/Story/IntroVoice.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Narrative spine smoke ===")
	_check_felt_standing()
	_check_ask_and_token()
	_check_recap_and_flag_toast()
	_check_beat_from_quest()
	await _check_commitments_face()
	_finish("Narrative spine smoke")


func _check_felt_standing() -> void:
	var line := IntroVoice.felt_standing("Millwright's Union", "trust", 0.12)
	_check(line.contains("Millwright"), "felt standing names the faction")
	_check(line.contains("grows"), "felt standing names the direction")
	_check(not line.contains("0.12"), "felt standing drops the ledger delta", line)
	_check(not line.contains("%+"), "felt standing has no printf leftovers", line)
	var snap := IntroVoice.felt_standing_snapshot("Packlords", "trust", 0.4)
	_check(snap.contains("Packlords"), "snapshot names the faction")
	_check(not snap.contains("0.40") and not snap.contains("+0."),
			"snapshot has no standing number on the face", snap)


func _check_ask_and_token() -> void:
	var q := {
		"category": "TUTORIAL",
		"tutorial_teaches": "core_loop",
		"tutorial_hint": "Strike a plot (R), then gather the yield (Q). Pick plots with G H J K L.",
		"body": "The Demos sleeps — wheat and people, waiting.",
		"math_note": "Fires the instant the gate ledger records 1 measure gate.",
	}
	_check(IntroVoice.live_ask_token(q) == "strike", "step 0 live_ask is strike")
	var ask := IntroVoice.ask_line(q)
	_check(ask.contains("Strike"), "ask leads with the first sentence")
	_check(not ask.contains("math"), "ask is not the math_note")
	_check(ask.length() <= IntroVoice.ASK_MAX_CHARS + 5, "ask stays banner-short")


func _check_recap_and_flag_toast() -> void:
	var recap: Dictionary = IntroVoice.recap()
	var line := str(recap.get("line", ""))
	_check(not line.contains("Act %") and not line.contains("Act 0") and not line.contains("Act 1"),
			"recap does not lead with Act N", line)
	var toast: Dictionary = IntroVoice.toast_for_flag("first_harvest", {
		"display_name": "First Harvest",
		"arc_beat": "You turned time forward and the whole country answered.",
		"predicates": [{"type": "gate_sequence_contains", "gate": "reap", "count": 1}],
	})
	_check(str(toast.get("message", "")).contains("First Harvest"), "earned-flag toast is the title")
	_check(str(toast.get("detail", "")) == "", "flag toast has no detail reprint")
	_check(str(toast.get("route", "")) == "story", "flag toast routes to Story")
	var handoff := IntroVoice.toast_for_flag("loom_opens", {
		"display_name": "The Loom Opens",
		"arc_beat": "You spread one qubit across both its poles.",
		"predicates": [],
	})
	_check(handoff.is_empty(), "empty-predicate handoff flags do not gold-card the hat unlock")
	var door := IntroVoice.toast_for_flag("arc_handover", {
		"display_name": "The Wheel Is Yours",
		"arc_quest": {"body": "Open the Arc and read the island's open doors."},
	})
	_check(door.is_empty(), "flag-that-opens-a-door does not dual-gold the offer")


func _check_beat_from_quest() -> void:
	var q := {
		"category": "TUTORIAL",
		"tutorial_teaches": "contracts",
		"tutorial_hint": "Gather 2× 🌾. Then deliver on Commitments [U].",
		"body": "The Millwright's Union is buying.",
		"status": "active",
	}
	var beat: Dictionary = IntroVoice.beat_from_quest(q, "live")
	_check(str(beat.get("title", "")).contains("mill") or str(beat.get("title", "")).contains("Mill"),
			"contracts beat titles the mill", str(beat.get("title", "")))
	_check(str(beat.get("live_ask", "")) == "deliver", "contracts live_ask is deliver")
	_check(str(beat.get("kind", "")) == "live_tutorial", "live tutorial kind")
	_check(str(beat.get("ask", "")).contains("Gather") or str(beat.get("ask", "")).contains("deliver"),
			"ask is the how's first sentence")


func _check_commitments_face() -> void:
	var board := QuestBoard.new()
	root.add_child(board)
	await process_frame
	var quest := {
		"id": 7,
		"faction": "Millwright's Union",
		"resource": "🌾",
		"quantity": 2,
		"status": "active",
		"category": "TUTORIAL",
		"body": "The Millwright's Union is buying.",
		"tutorial_hint": "Gather 2× 🌾: strike [R], gather [Q]. Then deliver.",
		"math_note": "A DELIVERY quest, not a soft gate.",
		"progress": 0.5,
	}
	var unsel := board._make_commitment_row(quest, "G", false)
	var unsel_text := _label_dump(unsel)
	_check(unsel_text.contains("Millwright"), "unselected row names the faction")
	_check(not unsel_text.contains("math:"), "unselected row has no math:", unsel_text)
	_check(not unsel_text.contains("💡"), "unselected row has no hint dump", unsel_text)
	_check(not unsel_text.contains("The Millwright's Union is buying"),
			"unselected row hides body", unsel_text)
	var sel := board._make_commitment_row(quest, "G", true)
	var sel_text := _label_dump(sel)
	_check(sel_text.contains("The Millwright's Union is buying"), "selected row shows body")
	_check(not sel_text.contains("math:"), "selected row still hides math", sel_text)
	var inspect := board._commitments_inspect_text_for(quest)
	_check(inspect.contains("Gather") or inspect.contains("deliver"), "E holds the how")
	_check(inspect.contains("DELIVERY") or inspect.contains("soft gate") or inspect.contains("math"),
			"E holds the math")
	board.queue_free()


func _label_dump(n: Node) -> String:
	var bits: Array[String] = []
	if n is Label:
		bits.append(str((n as Label).text))
	for c in n.get_children():
		bits.append(_label_dump(c))
	return " ".join(bits)
