class_name OverlayChrome
extends RefCounted

## OverlayChrome — shared widget builders for Surface overlay chrome.
##
## Extracted 2026-08-03 (slop-patrol Cycle 2, knot #19): the same small
## chrome helpers (`_make_key_chip`, `_make_muted_label`, `_make_spacer`,
## `_ratio_bar`, `_make_empty_row`, `_make_kv_row`) were copy-pasted across
## EscapeMenu, ControlsOverlay, QuestBoard, MapMetaOverlay,
## InspectorOverlay, and BiomeInspectorOverlay with drifting parameters.
##
## Every builder here is parameterized so each overlay keeps its EXACT
## pre-extraction look: the overlays' local `_make_*` functions remain as
## one-line delegates that pin their historical font sizes / min widths /
## colors. Do not "harmonize" those parameters without a screenshot pass.
##
## Deliberately NOT extracted (load-bearing per-overlay forks — see
## docs/SLOP_PATROL_2026-07-29.md knots #17/#18/#20): tab-row builders
## (ControlsOverlay/EscapeMenu key off local enums, the frame-keyed four off
## frame_id), EscapeMenu's tab click handling (entangled with its
## pending-confirmation guard), and open/close/input-swallow wiring
## (per-overlay, with z-order/input-routing regression history #197/#243).

## "[K]" key chip label.
static func key_chip(
	key_str: String,
	font_size: int = 13,
	min_width: int = 32,
	color: Color = UIStyleFactory.COLOR_KEY_CHIP
) -> Label:
	var lbl := Label.new()
	lbl.text = "[%s]" % key_str
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.custom_minimum_size = Vector2(min_width, 0)
	return lbl


## Centered muted hint text.
static func muted_label(
	text: String,
	font_size: int,
	color: Color = UIStyleFactory.COLOR_MUTED,
	autowrap: bool = true
) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	if autowrap:
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl


## Fixed-height vertical spacer.
static func spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


## Unicode ratio bar, e.g. "▮▮▮▯▯". Clamps ratio to [0, 1].
static func ratio_bar(ratio: float, length: int) -> String:
	var filled: int = clampi(int(round(clampf(ratio, 0.0, 1.0) * float(length))), 0, length)
	var bar := ""
	for i in range(length):
		bar += "▮" if i < filled else "▯"
	return bar


## Row for an unpopulated item slot: [K] — .
## Takes the chip pre-built so each overlay keeps its own chip styling.
static func empty_row(chip: Label) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(chip)
	var lbl := Label.new()
	lbl.text = "—"
	lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_ITEM_EMPTY)
	lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(lbl)
	return row


## key: value row with a fixed-width muted key column.
static func kv_row(
	key: String,
	value: String,
	key_min_width: int = 140,
	autowrap_value: bool = true
) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var k := Label.new()
	k.text = key
	k.add_theme_font_size_override("font_size", 12)
	k.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	k.custom_minimum_size = Vector2(key_min_width, 0)
	row.add_child(k)
	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 13)
	v.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if autowrap_value:
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(v)
	return row
