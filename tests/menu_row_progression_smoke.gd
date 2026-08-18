extends "res://tests/smoke_test_base.gd"

## Pins the 2026-08-17 C-chip fixes: the quest-board chip's step gate reads
## the offered-but-unaccepted contracts step (story_offers, not just
## active_quests — the old sentinel hole briefly opened the whole funnel),
## and refresh_progression() actually surfaces the chip when the gate opens
## (it used to wait for an unrelated story flag to rebuild the row). Also
## pins the X chip's 📖 (it was a keyboard).

const UIProgressionScript = preload("res://UI/Core/UIProgression.gd")
const MenuRegistryScript = preload("res://UI/Core/MenuRegistry.gd")


class QMStub:
	extends Node
	var active_quests: Dictionary = {}
	var story_offers: Dictionary = {}


class ShellStub:
	extends Node
	var quest_manager: Node = null


class FarmStub:
	extends Node
	var story_flags_fired: Dictionary = {}
	# MusicManager polls the active farm every frame; a stub without this
	# property spams script errors from its fallback probe.
	var terminal_pool = null


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Menu row progression smoke ===")

	# 📖 pin: the X (playthrough) chip is a book — it names the narrative,
	# not the input device.
	var x_emoji := ""
	var c_emoji := ""
	for entry in MenuRegistryScript.TOP_LEVEL_MENUS:
		if str(entry.get("key_label", "")) == "X":
			x_emoji = str(entry.get("button_emoji", ""))
		elif str(entry.get("key_label", "")) == "C":
			c_emoji = str(entry.get("button_emoji", ""))
	_check(x_emoji == "📖", "X chip emoji is the book")
	_check(c_emoji != "", "C chip declares an emoji")

	var gsm = root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		_fail("GameStateManager autoload available")
		_finish("Menu row progression smoke")
		return

	# A farm with flags present (empty dict) — without one, the progression
	# tables fail OPEN and every gate reads unlocked.
	var farm := FarmStub.new()
	root.add_child(farm)
	var prev_farm = gsm.active_farm
	gsm.active_farm = farm

	var qm := QMStub.new()
	root.add_child(qm)
	var shell := ShellStub.new()
	shell.quest_manager = qm
	shell.add_to_group("player_shell")
	root.add_child(shell)

	# Step 0 live → the quests menu is still gated (MENU_UNLOCK_STEP: 1).
	qm.active_quests = {0: {"category": "TUTORIAL", "tutorial_step": 0}}
	_check(UIProgressionScript.current_tutorial_step() == 0, "step 0 reads from active_quests")
	_check(not UIProgressionScript.is_menu_visible("quests"), "C is gated during step 0")

	var row := MenuSelectionRow.new()
	root.add_child(row)
	await process_frame
	_check(row.get_button_pulse_target("C") == null, "no C chip while gated")
	_check(row.get_button_pulse_target("X") != null, "X chip renders while C is gated")

	# The offered-but-unaccepted window: the contracts step (1) waits in
	# story_offers for a real R-accept. The step must read 1 (not the
	# everything-unlocked sentinel), the gate must open, and a
	# refresh_progression() must surface the chip.
	qm.active_quests = {}
	qm.story_offers = {7: {"category": "TUTORIAL", "tutorial_step": 1}}
	_check(UIProgressionScript.current_tutorial_step() == 1,
		"step reads from story_offers while the contracts step awaits accept")
	_check(UIProgressionScript.is_menu_visible("quests"), "C unlocks at the contracts step")
	row.refresh_progression()
	await process_frame
	_check(row.get_button_pulse_target("C") != null, "refresh_progression surfaces the C chip")

	gsm.active_farm = prev_farm
	_finish("Menu row progression smoke")
