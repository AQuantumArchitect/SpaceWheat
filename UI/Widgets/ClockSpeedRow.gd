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

signal speed_step_requested(delta: int)


func _ready() -> void:
	# Rides its own top band's right corner, alone — the menu row is ALSO
	# right-aligned (ALIGNMENT_END), so merging the two into one band would put
	# two right-aligned clusters on one row and let them collide on a narrow
	# window (the same reasoning that kept ModeSelectionRow off this row before
	# it moved to the bottom with the hats, 2026-08-24).
	z_index = 6
	compact = true
	alignment = BoxContainer.ALIGNMENT_END
	super._ready()
	if not button_selected.is_connected(_on_button_selected):
		button_selected.connect(_on_button_selected)
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
	selected_id = -1
	speed_step_requested.emit(1 if id == FASTER_ID else -1)
