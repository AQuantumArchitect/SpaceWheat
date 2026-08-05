extends "res://tests/smoke_test_base.gd"

## Pin the acts-4-8 blackout OFF: UIProgression.objective_text() and
## objective_target_key() must keep serving the second half of the campaign.
##
## Regression under test: both functions early-returned "" once island_lives
## fired — island_lives is act 4 of 8 (a stale comment called it "the ENDGAME
## flag"), so the ActFilament banner and the ObjectiveSpotlight pulse went
## permanently dark for acts 4-8. This smoke drives the static authority with
## a stub shell in the player_shell group:
##   1. an ACTIVE act-5 arc quest → text non-empty; "C" once ready.
##   2. only a pending offer      → OFFER_LINE + key "X" (banner says
##      "X then I"; the spotlight must pulse the same key, not go dark).
##   3. no quest, no offer        → "" (the EARNED endgame quiet, not an
##      act cutoff).
##
## Run: godot --headless --path . --script tests/objective_blackout_smoke.gd

const UIProgression := preload("res://UI/Core/UIProgression.gd")


class StubQM:
	extends Node
	var active_quests: Dictionary = {}
	var story_offers: Dictionary = {}
	func get_all_story_flags() -> Array:
		return [{"id": "edge_of_the_enclave", "act": 5}]


class StubShell:
	extends Node
	var quest_manager: Node = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Objective blackout smoke (acts 4-8 stay lit) ===")
	var qm := StubQM.new()
	var shell := StubShell.new()
	shell.quest_manager = qm
	root.add_child(shell)
	shell.add_child(qm)
	shell.add_to_group("player_shell")

	# --- 1. Mid-late campaign: an ACTIVE arc quest (act 5) must surface. -----
	qm.active_quests = {7: {
		"id": 7, "category": "ARC", "status": "active",
		"source_flag": "edge_of_the_enclave",
		"hint": "Grow the signature past sixteen — the enclave's edge is measured.",
	}}
	var text := UIProgression.objective_text()
	_check(text != "", "active act-5 arc quest surfaces text", "got empty")
	_check(text.contains("signature"), "text carries the hint", "got: %s" % text)

	qm.active_quests[7]["status"] = "ready"
	_check(UIProgression.objective_target_key() == "C", "ready arc quest targets C",
			"got: %s" % UIProgression.objective_target_key())

	# --- 2. Offer-only late game: banner + spotlight must agree on X. --------
	qm.active_quests = {}
	qm.story_offers = {9: {
		"id": 9, "category": "ARC", "status": Quest.STATUS_STORY,
		"source_flag": "the_crossing",
	}}
	_check(UIProgression.objective_text() == UIProgression.OFFER_LINE,
			"offer-only text is the OFFER_LINE", "got: %s" % UIProgression.objective_text())
	_check(UIProgression.objective_target_key() == "X", "offer-only target is X",
			"got: %s" % UIProgression.objective_target_key())

	# --- 3. Nothing at all → the earned quiet. -------------------------------
	qm.story_offers = {}
	_check(UIProgression.objective_text() == "" and UIProgression.objective_target_key() == "",
			"no quest + no offer is empty (earned quiet)")

	_finish("objective blackout smoke")
