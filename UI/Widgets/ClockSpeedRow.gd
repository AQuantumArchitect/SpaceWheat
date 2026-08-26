class_name ClockSpeedRow
extends "res://UI/Widgets/SelectionButtonRow.gd"

## Clock-speed chips — the pointer twin of the `−` / `=` keys.
##
## Until this row existed, `_increase_time_controls()` / `_decrease_time_controls()`
## had exactly TWO call sites, both inside QuantumInstrumentInput's
## `_unhandled_key_input` — so the biome clock was keyboard-only, with no chip,
## no menu item and no gesture anywhere.
##
## That is not a convenience gap. Act 0's own step 1 is the icon ritual: track a
## plot, let the loop ripen, incorporate. Ripening runs in REAL TIME — a
## mouse-only lost-lamb leg measured ~6% per 15s, i.e. roughly four minutes of
## staring at ×1 before the first incorporation is even possible — while the
## game's own tracking hint says "⏩ = speeds this biome's clock (up to ×32), −
## slows it", naming a control that a mouse could not reach. The hint promised a
## dial that wasn't there.
##
## Authority: clicks call the SAME two QII methods the keys call. This row never
## owns timescale state — it only asks for a change — so the keyboard and the
## pointer cannot drift apart. (Same rule ModeSelectionRow follows, and for the
## same reason: two input paths, one authority.)

const SLOWER_ID := 0
const FASTER_ID := 1
const PAUSE_ID := 2

signal speed_step_requested(delta: int)
signal pause_toggle_requested()

var _paused: bool = false


func _ready() -> void:
	# Rides the LEFT end of the TimeBar's track (2026-08-25 second pass, owner
	# ask: "the time controls need to start getting integrated into the
	# timebar"). It used to own a whole top band in the right corner, inset
	# past the contract chip — three separate things stacked in one corner,
	# which is the "cluster fuck" the same pass was sent to fix. Down here the
	# transport reads left-to-right against the timeline it drives, and the top
	# strip is one band shorter.
	z_index = 6
	compact = true
	alignment = BoxContainer.ALIGNMENT_BEGIN
	super._ready()
	if not button_selected.is_connected(_on_button_selected):
		button_selected.connect(_on_button_selected)
	_resolve_shell()
	_rebuild_buttons()


## The pause glyph has to tell the truth about the world's state, so the chip
## follows PlayerShell's `paused_changed` rather than tracking its own flag —
## E/F on the keyboard, the escape menu and this chip all move one bit.
func _resolve_shell() -> void:
	var n: Node = get_parent()
	while n != null:
		if n.has_signal("paused_changed"):
			if not n.paused_changed.is_connected(_on_paused_changed):
				n.paused_changed.connect(_on_paused_changed)
			return
		n = n.get_parent()


func _on_paused_changed(is_paused: bool) -> void:
	if is_paused == _paused:
		return
	_paused = is_paused
	_rebuild_buttons()


func _rebuild_buttons() -> void:
	var specs: Array[Dictionary] = [
		{
			"id": SLOWER_ID,
			"text": "⏪",
			"icon_path": "",
			"enabled": true,
			"tooltip": "Slow this biome's clock [−] — loops ripen slower; the "
					+ "physics is unchanged, only how fast you watch it.",
		},
		{
			"id": PAUSE_ID,
			"text": "▶" if _paused else "⏸",
			"icon_path": "",
			"enabled": true,
			"tooltip": ("Let time run again [F] — the world is frozen."
					if _paused else
					"Freeze time [E] — look as long as you like; nothing ripens "
					+ "and nothing decays while it holds."),
		},
		{
			"id": FASTER_ID,
			"text": "⏩",
			"icon_path": "",
			"enabled": true,
			"tooltip": "Speed this biome's clock [=] up to ×32 — loops ripen "
					+ "faster. Berry-tracking needs real time; this is the dial.",
		},
	]
	build_buttons(specs)
	# Distinct names, for the same reason ModeSelectionRow carries its own
	# prefix: every SelectionButtonRow names its containers SelectBtn_N, so an
	# unscoped lookup by name resolves to whichever row the tree walk reaches
	# first — which during the mode-row work silently matched a chip three
	# bands away.
	for i in range(buttons.size()):
		var container: Control = buttons[i].get("container")
		if container:
			container.name = "ClockChip_%d" % i


func _on_button_selected(id: int) -> void:
	# No selected state: these are momentary steps, not a mode choice. Clearing
	# it keeps the gold underline off a chip that isn't a persistent setting.
	# (Pause IS a persistent state, but it wears its state in the glyph — ⏸ vs
	# ▶ — which is a truer cue than an underline on a two-state transport.)
	selected_id = -1
	if id == PAUSE_ID:
		pause_toggle_requested.emit()
		return
	speed_step_requested.emit(1 if id == FASTER_ID else -1)
