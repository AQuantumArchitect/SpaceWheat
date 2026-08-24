class_name WelcomeOverlay
extends "res://UI/Core/OverlayBase.gd"

## Welcome / how-to-play splash — shown ONCE on a fresh game (first run, before tutorial_seen).
## Points the player at the X → Guide tab for the full instructions. Dismissing it (F = Begin,
## or ESC) is the human ACTION that begins the tutorial: tutorial_seen fires on dismiss, not at
## boot — matching the principle that flags fire from human action.

## Story first (owner ruling 2026-08-17): a brand-new player used to meet
## eleven rows of keymap; the fiction was one line among them. Now the fiction
## leads, and only the three keys the first minute needs appear — the full
## keymap lives where it always did, in the Guide (X → O), and the objective
## portal (top-right) carries the player from there.
const _ROWS := [
	"You are The Demos — a people learning the quantum language of your own ground.",
	"",
	"Your whole vocabulary is one word: 🌾/👥 — wheat and people, the axis your island turns on.",
	"The factions past the hedge keep older words, and they teach the ones who keep their contracts.",
	"",
	"THE FIRST MINUTE   ·   tap a plot to explore it [F] (costs 🍞)  ·  tap its bubble to strike — the answer locks in [R] (costs 👥)  ·  tap the frozen bubble to extract the yield [Q], free.",
	"",
	"The gold banner (top-right) always names your one live task — tap it any time for the Arc, the island's list of open doors.  The Guide (X → O) is the full how-to-play.",
	"",
	"Tap anywhere  (or press  F)  to begin.",
]


func _init() -> void:
	name = "WelcomeOverlay"
	overlay_name = "welcome"
	panel_title = "🌾  Welcome to SpaceWheat"
	panel_title_size = 24
	panel_size_mode = PanelSizeMode.MEDIUM
	panel_border_color = Color(0.40, 0.70, 0.50, 0.9)
	show_dimmer = true
	dimmer_color = Color(0, 0, 0, 0.82)
	use_scroll_container = false
	navigation_mode = NavigationMode.NONE
	overlay_tier = 18  # system/modal tier — above gameplay and info overlays
	action_labels = {"Q": "", "E": "", "R": "", "F": "Begin"}


func _build_content(container: Control) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(box)
	for row in _ROWS:
		var lbl := Label.new()
		lbl.text = str(row)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var emphasis := str(row).begins_with("THE FIRST MINUTE") \
			or str(row).begins_with("Tap anywhere")
		lbl.add_theme_font_size_override("font_size", 15 if emphasis else 13)
		lbl.add_theme_color_override("font_color",
			Color(0.85, 0.95, 0.88) if emphasis else Color(0.78, 0.82, 0.88))
		box.add_child(lbl)


# ANY key — or tap/click — dismisses the welcome (standard "press any key" splash) so the
# player is never trapped. Consume that one press cleanly (no fall-through → no double-pop
# on ESC); the next press plays normally. Without this, the modal ate Q/E/R until F was
# pressed — which read as "actions are blocked / frame selection prevents changing frames."
func handle_input(event: InputEvent) -> bool:
	if not is_active:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		_dismiss()
		return true
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		_dismiss()
		return true
	return false


# Pointer path: PlayerShell only routes KEYBOARD events into overlay
# handle_input, so "Tap anywhere to begin" needs a direct ear. Consume the
# press so it doesn't leak through as a bubble tap under the splash.
func _input(event: InputEvent) -> void:
	if not is_active:
		return
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		get_viewport().set_input_as_handled()
		_dismiss()


# Tap path (action-bar chip): F = Begin → dismiss.
func _on_action_f() -> void:
	_dismiss()


func _dismiss() -> void:
	if not is_active:
		return
	var ps := _find_player_shell()
	if ps != null and "overlay_manager" in ps and ps.overlay_manager != null \
			and ps.overlay_manager.has_method("close_overlay"):
		ps.overlay_manager.close_overlay()
	else:
		deactivate()


# Any dismiss (F or ESC) begins the tutorial — the human action that fires tutorial_seen.
# Idempotent: maybe_start_tutorial guards on tutorial_seen, so re-entry is harmless.
func _on_deactivated() -> void:
	var ps := _find_player_shell()
	var qm = null
	if ps != null and "quest_manager" in ps and ps.quest_manager != null:
		qm = ps.quest_manager
	else:
		qm = get_node_or_null("/root/QuestManager")
	var farm = InstrumentLocator.resolve_active_farm(self) if InstrumentLocator else null
	if qm != null and qm.has_method("maybe_start_tutorial") and farm != null:
		qm.maybe_start_tutorial(farm)
