extends "res://tests/smoke_test_base.gd"

## Pins the 2026-08-17 toast mechanics: gold (importance ≥ 3) toasts persist
## until explicitly dismissed, the whole panel is a click-to-dismiss target,
## and stack overflow evicts the oldest NON-persistent toast first. Playtest
## driver: three story-beat toasts after the first reap vanished before they
## could be read, and keyboard dismissal (E/F) is dead exactly then (the Ace
## hat owns both keys).

const PlayerShellScript = preload("res://UI/PlayerShell.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== HintToast lifecycle smoke ===")

	# --- persistence by importance ---
	var gold := HintToast.new()
	root.add_child(gold)
	gold.show_text("✨ [b]First Harvest[/b] — a story beat worth reading", 3)
	_check(gold.is_persistent(), "importance-3 toast is persistent")
	_check(gold.mouse_filter == Control.MOUSE_FILTER_STOP, "toast panel takes the mouse")
	_check(gold.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND,
		"toast invites the click with a pointing hand")

	var teal := HintToast.new()
	root.add_child(teal)
	teal.show_text("⚖️ a passing whisper", 2)
	_check(not teal.is_persistent(), "importance-2 toast still decays")

	# Let the fade-in tween settle. Bounded FRAME loop, not wall-clock —
	# headless frame pacing stalls while emoji atlases load, which starves
	# tween ticks even as SceneTreeTimers count the wall time.
	var frames := 0
	while gold.modulate.a < 0.95 and frames < 240:
		await process_frame
		frames += 1
	_check(is_instance_valid(gold) and not gold.is_queued_for_deletion(),
		"persistent toast is still alive after fade-in")
	_check(gold.modulate.a > 0.9, "persistent toast reaches full alpha")
	# ...and HOLDS it: a persistent toast has no interval/fade-out stage.
	frames = 0
	while frames < 30:
		await process_frame
		frames += 1
	_check(is_instance_valid(gold) and gold.modulate.a > 0.9,
		"persistent toast holds full alpha (no fade-out stage)")

	# --- bump preserves persistence ---
	_check(gold.matches("✨ [b]First Harvest[/b] — a story beat worth reading"),
		"matches() sees the raw bbcode")
	gold.bump()
	_check(gold.is_persistent(), "a bumped gold toast stays persistent")

	# --- click-to-dismiss ---
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	gold._on_gui_input(click)
	frames = 0
	while is_instance_valid(gold) and not gold.is_queued_for_deletion() and frames < 240:
		await process_frame
		frames += 1
	_check(not is_instance_valid(gold) or gold.is_queued_for_deletion(),
		"a click flattens and frees the toast")

	# --- overflow eviction policy (static — no shell needed) ---
	var stack := VBoxContainer.new()
	root.add_child(stack)
	var gold_a := HintToast.new(); stack.add_child(gold_a); gold_a.show_text("gold a", 3)
	var teal_b := HintToast.new(); stack.add_child(teal_b); teal_b.show_text("teal b", 2)
	var gold_c := HintToast.new(); stack.add_child(gold_c); gold_c.show_text("gold c", 3)
	_check(PlayerShellScript.pick_toast_eviction_victim(stack) == teal_b,
		"eviction prefers the oldest non-persistent toast")
	stack.remove_child(teal_b)
	teal_b.queue_free()
	_check(PlayerShellScript.pick_toast_eviction_victim(stack) == gold_a,
		"an all-gold stack evicts its oldest")

	_finish("HintToast lifecycle smoke")
