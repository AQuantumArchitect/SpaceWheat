class_name ModeSelectionRow
extends "res://UI/Widgets/SelectionButtonRow.gd"

## Sub-mode chips for the ACTIVE hat — the pointer twin of the 1/2/3 keys.
##
## Several hats are two or three tools wearing one glyph: Spark is ⚡ shift AND
## 🌉 bridge, Merchant is thermal/dephase/damp, Druid rotates about X/Y/Z. Until
## this row existed, `ToolConfig.set_frame_mode` had exactly ONE runtime caller —
## the keyboard `1/2/3` branch in QuantumInstrumentInput — so a mouse-only player
## was locked to mode 0 of every hat forever. That is not a cosmetic gap: Spark's
## bridge verbs (anchor / braid / fuse) live only under the "bridge" action table,
## and the Act-7 "What Connects" flags gate on `bridge_braids_gte` /
## `bridge_fused_gte`. No mode switch, no ending.
##
## The row renders one chip per mode of the current hat, right-aligned into the
## hat band so it costs no vertical space, and HIDES ITSELF for single-mode hats
## (Ace, Icon, Captain, Operator) rather than showing a lone dead chip.
##
## Authority: clicks call the same ToolConfig.set_frame_mode + _on_mode_changed
## pair the keyboard calls. This row never owns mode state — it only displays it
## and asks for a change, so keyboard and mouse can never drift apart.

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

## Hat whose modes are currently rendered.
var current_frame: String = ""

## Modes rendered this build; button id i indexes into it.
var _modes: Array = []

signal mode_selected(frame_name: String, mode_index: int)


func _ready() -> void:
	# SAME band as the hat row now (2026-08-24: both moved to the bottom,
	# right above QERF), carved into a fixed right-hand dock by
	# ActionBarManager._position_mode_row rather than a band of its own.
	# Relative z barely matters — kept above its band-mates for the same
	# pick-order reason as before.
	z_index = 6
	compact = true
	# Hug the LEFT edge of ITS narrow dock, so the chips sit as close to the
	# (centered) hat cluster as the dock allows, reading as "just past the
	# hats" rather than adrift at the band's far right.
	alignment = BoxContainer.ALIGNMENT_BEGIN
	super._ready()
	if not button_selected.is_connected(_on_button_selected):
		button_selected.connect(_on_button_selected)
	show_frame(ToolConfig.get_current_frame())


## Point the row at a hat. Rebuilds the chips and hides for single-mode hats.
func show_frame(frame_name: String) -> void:
	current_frame = frame_name
	_modes = []
	if frame_name != "" and ToolConfig.ARCHETYPE_FRAMES.has(frame_name):
		var def: Dictionary = ToolConfig.get_frame(frame_name)
		var modes: Array = def.get("modes", [])
		# One mode is not a choice — a single chip would read as a dead button.
		if modes.size() >= 2:
			_modes = modes
	if _modes.is_empty():
		visible = false
		build_buttons([] as Array[Dictionary])
		return
	visible = true
	_rebuild_buttons()
	sync_selection()


func _rebuild_buttons() -> void:
	var def: Dictionary = ToolConfig.get_frame(current_frame)
	var emojis: Array = def.get("mode_emojis", [])
	var labels: Array = def.get("mode_labels", [])
	var actions: Dictionary = def.get("actions", {})
	var hat_name := str(def.get("name", current_frame))
	var specs: Array[Dictionary] = []
	for i in range(_modes.size()):
		var mode_name := str(_modes[i])
		var glyph := str(emojis[i]) if i < emojis.size() else mode_name
		var label := str(labels[i]) if i < labels.size() else mode_name
		specs.append({
			"id": i,
			"text": glyph,
			"icon_path": "",
			"enabled": true,
			# The tooltip has to carry the whole story: which hat, which key,
			# and what the mode actually re-binds, because the glyph alone
			# ("🌉") teaches nothing.
			"tooltip": "%s mode: %s [%d] — %s" % [
				hat_name, label, i + 1, _verb_summary(actions.get(mode_name, {}))],
		})
	build_buttons(specs)
	# Distinct names: every SelectionButtonRow names its containers SelectBtn_N,
	# so a probe (or a rig tap) searching by name would hit whichever row came
	# first in the tree — during verification "SelectBtn_1" resolved to the MENU
	# row's chip, three bands away. Mode chips get their own prefix.
	for i in range(buttons.size()):
		var container: Control = buttons[i].get("container")
		if container:
			container.name = "ModeChip_%d" % i


## "Q Fuse · E Inspect · R Span · F Braid" — the verbs this mode re-binds, so a
## player can tell the modes apart before committing a click.
func _verb_summary(mode_actions: Dictionary) -> String:
	if mode_actions.is_empty():
		return "changes what Q/E/R/F do"
	var parts: PackedStringArray = []
	for key in ["Q", "E", "R", "F"]:
		var entry = mode_actions.get(key, null)
		if entry is Dictionary:
			var verb := str(entry.get("label", ""))
			if verb != "" and verb != "—":
				parts.append("%s %s" % [key, verb])
	return " · ".join(parts) if parts.size() > 0 else "changes what Q/E/R/F do"


## Re-read the live mode index and move the highlight. Called after any change,
## from either input path — the row mirrors ToolConfig, never leads it.
func sync_selection() -> void:
	if _modes.is_empty():
		return
	var idx: int = ToolConfig.get_frame_mode_index(current_frame)
	set_selected(idx if idx >= 0 and idx < _modes.size() else -1)


func _on_button_selected(idx: int) -> void:
	if idx < 0 or idx >= _modes.size() or current_frame == "":
		return
	# Ask ToolConfig, then report what it actually applied — never assume the
	# click won (out-of-range returns -1).
	var applied: int = ToolConfig.set_frame_mode(current_frame, idx)
	if applied < 0:
		return
	set_selected(applied)
	mode_selected.emit(current_frame, applied)
