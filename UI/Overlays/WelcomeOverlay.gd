class_name WelcomeOverlay
extends "res://UI/Core/OverlayBase.gd"

## Welcome splash — shown ONCE on a fresh game (first run, before tutorial_seen).
## Dismissing it (F = Begin, or any tap/key) is the human ACTION that begins
## the tutorial: tutorial_seen fires on dismiss, not at boot.
##
## Form (2026-09-09): identity, not a lesson. Fiction names who you are.
## The how (Explore / Strike / Gather) lives on Guide; the first live ask
## lives on the banner after dismiss. The splash is a tracker (you are The Demos) plus a
## begin-link (tap anywhere / F). The dimmer is a glass, not a blackout —
## the field is the illustration. Copy lives in IntroVoice.

const IntroVoice := preload("res://Core/Story/IntroVoice.gd")


func _init() -> void:
	name = "WelcomeOverlay"
	overlay_name = "welcome"
	panel_title = "🌾  " + IntroVoice.welcome_title()
	panel_title_size = 26
	panel_size_mode = PanelSizeMode.MEDIUM
	panel_border_color = Color(0.40, 0.70, 0.50, 0.9)
	show_dimmer = true
	# Glass, not a curtain: the farm has to be visible as the illustration.
	dimmer_color = Color(0, 0, 0, 0.45)
	use_scroll_container = false
	navigation_mode = NavigationMode.NONE
	overlay_tier = 18  # system/modal tier — above gameplay and info overlays
	action_labels = {"Q": "", "E": "", "R": "", "F": "Begin"}


func _build_content(container: Control) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(box)

	for line in IntroVoice.welcome_fiction():
		var lbl := Label.new()
		lbl.text = str(line)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(0.88, 0.93, 0.86))
		box.add_child(lbl)

	box.add_child(_make_spacer(8))

	var footer := Label.new()
	footer.text = IntroVoice.welcome_footer()
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 14)
	footer.add_theme_color_override("font_color", Color(0.85, 0.95, 0.88))
	box.add_child(footer)


func _make_spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


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
