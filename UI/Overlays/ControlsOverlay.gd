class_name ControlsOverlay
extends "res://UI/Core/Surface.gd"

## X — playthrough surface (X key).
## This run's identity, narrative, economy, and how-to-play. Where Z holds
## save/system/identity ("which truth"), X holds the *current* truth: who you
## are in this playthrough, what's happened, what to do.
##
## Keyboard grammar matches the rest of the game (and Z):
##   TYUIO  = tabs (Self / Story / · / Balance / Guide), top row
##           (U slot intentionally empty — live quest pipeline lives on C)
##   GHJKL; = items within the active tab, same row as plot slots
##   [ / ]  = cycle tabs (surface frame cycle)
##   , / .  = cycle top-level menus
##   Q ←   = screw-out / retreat / withdraw (depth axis, never list nav)
##   R →   = screw-in / commit / advance / assign  (depth axis, never list nav)
##   E ↓   = pause + inspect / refresh / observe (snapshot)
##   F ↑   = flatten: collapses whatever E opened. No open panel → no-op.
##            F is never "back" and never navigation — those belong to ESC / [ ].
##   W/S    = navigate items within the active tab (page / cycle action)
##   1/2/3  = sub-mode within the active tab (icon slot, picker target)
##   Z/ESC  = close
##
## Note: Balance tab uses Q/R to shift biome scope (rather than W/S which
## is taken by action cycling, and A/D which the shell consumes for tab
## cycling). Treated as scope-axis depth, not item navigation.
##
## frame_ids = [self, story, balance, guide] — one per tab.

const ToolConfig      = preload("res://Core/GameState/ToolConfig.gd")

# =============================================================================
# TABS / FRAMES
# =============================================================================

enum Tab { SELF, STORY, BALANCE, GUIDE }

const TAB_ROW := [
	{"key": "T", "tab": Tab.SELF,    "name": "Self",    "frame": "self"},
	{"key": "Y", "tab": Tab.STORY,   "name": "Story",   "frame": "story"},
	# U slot intentionally empty — live quest pipeline lives on C (QuestBoard).
	{"key": "I", "tab": Tab.BALANCE, "name": "Balance", "frame": "balance"},
	{"key": "O", "tab": Tab.GUIDE,   "name": "Guide",   "frame": "guide"},
]

const TAB_BY_KEYCODE := {
	KEY_T: Tab.SELF,
	KEY_Y: Tab.STORY,
	# KEY_U intentionally empty (quest pipeline → C)
	KEY_I: Tab.BALANCE,
	KEY_O: Tab.GUIDE,
}

# Left-to-right slot keys (same convention as X).
const ITEM_KEYS := ["G", "H", "J", "K", "L", ";", "'"]
const ITEM_BY_KEYCODE := {
	KEY_G: 0,
	KEY_H: 1,
	KEY_J: 2,
	KEY_K: 3,
	KEY_L: 4,
	KEY_SEMICOLON: 5,
	KEY_APOSTROPHE: 6,
}

const FRAME_SELF    := "self"
const FRAME_STORY   := "story"
const FRAME_BALANCE := "balance"
const FRAME_GUIDE   := "guide"

const TAB_TO_FRAME := {
	Tab.SELF:    FRAME_SELF,
	Tab.STORY:   FRAME_STORY,
	Tab.BALANCE: FRAME_BALANCE,
	Tab.GUIDE:   FRAME_GUIDE,
}
const FRAME_TO_TAB := {
	FRAME_SELF:    Tab.SELF,
	FRAME_STORY:   Tab.STORY,
	FRAME_BALANCE: Tab.BALANCE,
	FRAME_GUIDE:   Tab.GUIDE,
}

# Guide tab: 7 sections, GHJKL;' selects which. The Verbs section absorbs
# what used to live on Z's I tab — the 7-hat × QERF reference.
# Glossary (') is the final section; projects docs/glossary/*.md live.
const GUIDE_ITEMS := [
	{"id": "loop",     "title": "Core Loop"},
	{"id": "tools",    "title": "Four Tools"},
	{"id": "biomes",   "title": "Biomes, Neighborhoods & Economy"},
	{"id": "try",      "title": "Things to Try"},
	{"id": "ref",      "title": "Quick Reference"},
	{"id": "verbs",    "title": "Verbs (per hat)"},
	{"id": "glossary", "title": "Glossary"},
]

# Featured strip: world-canon first (the story the physics tells), structure after.
const GLOSSARY_CANONICAL_TERMS := ["enclave", "measurement", "berry", "invariant", "webway", "resonance", "biome", "faction", "icon"]

# =============================================================================
# COLORS
# =============================================================================
const COLOR_HEADER      := Color(0.55, 0.7, 0.85, 0.9)

# =============================================================================
# STATE
# =============================================================================

var _current_tab: int = Tab.SELF
var _guide_item: int = 0    # index into GUIDE_ITEMS
var _glossary_reg: GlossaryRegistry = null

# Story graph state (the new Story page — quantum narrative substrate)
var _story_focus_node: String = ""    # current ui_focus; "" = use density.argmax
var _story_edge_idx: int = 0          # cursor into focused node's outgoing edges (read-only context)
var _story_chatter_idx: int = 0       # GHJKL; cursor into visible chatter feed (the QERF target)
var _story_icon_idx: int = 0          # 0/1/2; selected via 1/2/3 keys
var _story_chatter_connected: bool = false
var _story_attractor_cache: Dictionary = {}  # biome_name → {emojis, gap, phrame}
var _story_inspect_open: bool = false        # E toggles a chatter detail panel; F flattens it
const ATTRACTOR_CACHE_TTL: int = 60          # ~1 second at 60Hz physics

# Self tab icon picker state.
var _self_picker_slot: int = 0     # which active slot (0/1/2) is being rebound
var _self_picker_icon: int = 0     # cursor into known_icons (GHJKL; navigates)
var _self_picker_page: int = 0     # page of known_icons (6 per page)

# Experimental chatter state (mirrors EscapeMenu.gd; refreshed on demand).
var _balance_action_idx: int = 0  # still used by the read-only action inspector
var _balance_setting_idx: int = 0  # GHJKL; cursor into _balance_settings
var _balance_setting_page: int = 0
var _balance_settings: Array = []  # Array of {id, label, category, value_path, kind, step, min, max, default}
var _balance_biome_idx: int = 0
var _balance_snapshot: Dictionary = {}
var _balance_action_keys: Array[String] = []
var _balance_biomes: Array[String] = []
var _balance_projection: Dictionary = {}

# UI refs.
var _status_line: Label = null
var _tab_row_box: HBoxContainer = null
var _tab_labels: Dictionary = {}  # key str → Label
var _body_box: VBoxContainer = null
var _close_hint: Label = null

func _init() -> void:
	name = "ControlsOverlay"
	overlay_name = "controls"
	overlay_icon = ""
	overlay_tier = 11
	panel_title = "Playthrough"
	panel_title_size = 22
	panel_size_mode = PanelSizeMode.LARGE
	panel_border_color = Color(0.5, 0.5, 0.3, 0.8)
	navigation_mode = NavigationMode.NONE
	use_scroll_container = true
	content_spacing = 8
	surface_id = "X"
	frame_ids = [FRAME_SELF, FRAME_STORY, FRAME_BALANCE, FRAME_GUIDE]
	frame_id = TAB_TO_FRAME.get(_current_tab, FRAME_SELF)

# =============================================================================
# BUILD
# =============================================================================

func _build_content(container: Control) -> void:
	_status_line = Label.new()
	_status_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_line.add_theme_font_size_override("font_size", 12)
	_status_line.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	container.add_child(_status_line)

	_build_tab_row(container)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.4, 0.4, 0.3, 0.45))
	container.add_child(sep)

	_body_box = VBoxContainer.new()
	_body_box.add_theme_constant_override("separation", 4)
	_body_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_body_box)

	_close_hint = Label.new()
	_close_hint.text = "ESC close   ·   TYUIO tabs   ·   GHJKL; items   ·   [ ] cycle frames"
	_close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_close_hint.add_theme_font_size_override("font_size", 11)
	_close_hint.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	container.add_child(_close_hint)

	_render_all()

func _build_tab_row(container: Control) -> void:
	_tab_row_box = HBoxContainer.new()
	_tab_row_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_tab_row_box.add_theme_constant_override("separation", 18)
	container.add_child(_tab_row_box)
	_tab_labels.clear()
	for entry in TAB_ROW:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 15)
		_tab_row_box.add_child(lbl)
		_tab_labels[str(entry.get("key", ""))] = lbl

# =============================================================================
# RENDER
# =============================================================================

func _render_all() -> void:
	_refresh_status_line()
	_refresh_tab_row()
	_refresh_body()

func _refresh_status_line() -> void:
	if not _status_line:
		return
	_status_line.text = "Z · self mirror"

func _refresh_tab_row() -> void:
	if _tab_labels.is_empty():
		return
	for entry in TAB_ROW:
		var key_str := str(entry.get("key", ""))
		var tab_enum = int(entry.get("tab", Tab.SELF))
		var name_str := str(entry.get("name", ""))
		var lbl: Label = _tab_labels.get(key_str, null)
		if lbl == null:
			continue
		if tab_enum == _current_tab:
			lbl.text = "[%s] %s" % [key_str, name_str.to_upper()]
			lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_TAB_ACTIVE)
		else:
			lbl.text = "[%s] %s" % [key_str, name_str]
			lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_TAB_IDLE)

func _refresh_body() -> void:
	if not _body_box:
		return
	for child in _body_box.get_children():
		child.queue_free()
	match _current_tab:
		Tab.SELF:    _build_self_body()
		Tab.STORY:   _build_story_body()
		Tab.BALANCE: _build_balance_body()
		Tab.GUIDE:   _build_guide_body()

# =============================================================================
# BODY: SELF — the mirror. 12-axis alignment strip + faction standings.
# =============================================================================

func _build_self_body() -> void:
	var farm = InstrumentLocator.resolve_active_farm(self)

	# The Demos - the player neighborhood rendered as icons + marginal bars.
	# This self view does not advance the neighborhood's live state here, so
	# these only move when quest rewards or consume_grants explicitly write to
	# them. Stillness is the point.
	_build_our_faction_view(farm)

	_body_box.add_child(_make_spacer(8))
	_build_icon_picker(farm)
	_body_box.add_child(_make_spacer(8))
	_body_box.add_child(_make_section_header("alignment"))

	# Derive per-axis bias from weighted faction standings.
	# axis_bias[i] = probability the player leans toward pole_1 on axis i.
	# Pure mixed state (0.5 on every axis) is the starting condition.
	var axis_bias: Array = []
	axis_bias.resize(FactionAxes.AXIS_COUNT)
	for i in range(FactionAxes.AXIS_COUNT):
		axis_bias[i] = 0.5

	var standings: Dictionary = farm.faction_standings if farm and "faction_standings" in farm else {}
	if not standings.is_empty():
		# Build atom → [axis_index, bit] map from canonical axes.
		var atom_axis: Dictionary = {}
		for i in range(FactionAxes.AXIS_COUNT):
			var ax := FactionAxes.get_axis(i)
			atom_axis[str(ax.get("pole_0", ""))] = [i, 0]
			atom_axis[str(ax.get("pole_1", ""))] = [i, 1]

		var weighted_bits: Array = []
		var weight_per_axis: Array = []
		weighted_bits.resize(FactionAxes.AXIS_COUNT)
		weight_per_axis.resize(FactionAxes.AXIS_COUNT)
		for i in range(FactionAxes.AXIS_COUNT):
			weighted_bits[i] = 0.0
			weight_per_axis[i] = 0.0

		var faction_reg := FactionRegistry.get_shared()
		for fname in standings.keys():
			var s = standings[fname]
			if s == null:
				continue
			var sc: float = s.scalar() if s.has_method("scalar") else 0.0
			if absf(sc) < 0.0001:
				continue
			var faction = faction_reg.get_by_name(fname)
			if faction == null:
				continue
			var w := absf(sc)
			for atom in faction.cloud:
				if atom in atom_axis:
					var info: Array = atom_axis[atom]
					weighted_bits[info[0]] += w * float(info[1])
					weight_per_axis[info[0]] += w

		for i in range(FactionAxes.AXIS_COUNT):
			if weight_per_axis[i] > 0.0:
				axis_bias[i] = clampf(weighted_bits[i] / weight_per_axis[i], 0.0, 1.0)

	# Render alignment strip — two columns of 6 axes each.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 2)
	_body_box.add_child(grid)

	for i in range(FactionAxes.AXIS_COUNT):
		var axis_def := FactionAxes.get_axis(i)
		var pole0 := str(axis_def.get("pole_0", ""))
		var pole1 := str(axis_def.get("pole_1", ""))
		var label0 := str(axis_def.get("label_0", "?"))
		var label1 := str(axis_def.get("label_1", "?"))
		var bias: float = axis_bias[i]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_lbl := Label.new()
		name_lbl.text = "%s %s" % [pole0, label0]
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
		name_lbl.custom_minimum_size = Vector2(100, 0)
		row.add_child(name_lbl)

		var bar_lbl := Label.new()
		var filled := int(round(bias * 8.0))
		bar_lbl.text = "█".repeat(filled) + "░".repeat(8 - filled)
		bar_lbl.add_theme_font_size_override("font_size", 11)
		bar_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE)
		row.add_child(bar_lbl)

		var pct_lbl := Label.new()
		pct_lbl.text = "%s %s" % [label1, pole1]
		pct_lbl.add_theme_font_size_override("font_size", 11)
		pct_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
		row.add_child(pct_lbl)

		grid.add_child(row)

	if standings.is_empty():
		_body_box.add_child(_make_spacer(4))
		_body_box.add_child(_make_muted_label(
			"no faction standing yet — alignment is pure mixed state (50/50 on every axis).", 11,
		))

	# Faction standings — full 6-channel breakdown + signature progress.
	if not standings.is_empty():
		_body_box.add_child(_make_spacer(8))
		_body_box.add_child(_make_section_header("faction standings"))
		_render_faction_standings_grid(farm, standings)

		# Spotlight the top-magnitude other faction (not "The Demos")
		# with a FactionCard so the player sees its nature, not just its number.
		var spot: String = _top_other_faction_by_magnitude(standings)
		if spot != "":
			_body_box.add_child(_make_spacer(6))
			_body_box.add_child(_make_section_header("spotlight · %s" % spot))
			_render_faction_card(farm, spot)

	# Faction attachment (coming soon — UI shell only; no logic wired yet).
	_body_box.add_child(_make_spacer(8))
	_render_faction_attachment_panel(farm)

	# Vocabulary lexicon
	_body_box.add_child(_make_spacer(8))
	_build_lexicon_section(farm)

## Faction attachment panel (Phase B scaffolding — coming soon).
## Renders the pinned faction + every other faction with overlap distance.
## No logic wired: pressing A or D is a no-op. Cost preview is "??" until
## the formula is calibrated.
##
## Cost = (1.0 - overlap) * scale * faction_standing_modifier.
##   overlap comes from AlignmentGraph.overlap(); scale follows the calibrated attach/detach tuning.
##   When detach lands, cost is paid in the player's most-abundant credit emoji.
func _render_faction_attachment_panel(farm) -> void:
	_body_box.add_child(_make_section_header("faction attachment (coming soon)"))
	if farm == null or not "player_alignment" in farm or farm.player_alignment == null:
		_body_box.add_child(_make_muted_label("(player alignment not yet bound)", 11))
		return
	var pinned_name: String = farm.get_pinned_faction_name() if farm.has_method("get_pinned_faction_name") else ""
	var registry = null
	if "faction_density" in farm and farm.faction_density != null \
			and farm.faction_density.has_method("get_registry"):
		registry = farm.faction_density.get_registry()
	if registry == null or not registry.has_method("get_all"):
		_body_box.add_child(_make_muted_label("(faction registry not loaded)", 11))
		return
	var player_ag = farm.player_alignment
	var rows: Array = []
	for f in registry.get_all():
		if f == null or not "name" in f or f.alignment == null:
			continue
		var fname: String = str(f.name)
		var ov: float = float(player_ag.overlap(f.alignment))
		rows.append({"name": fname, "overlap": ov, "is_pinned": fname == pinned_name})
	rows.sort_custom(func(a, b):
		if bool(a.is_pinned) != bool(b.is_pinned):
			return bool(a.is_pinned)
		return float(a.overlap) > float(b.overlap))
	for row in rows:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		var tag := Label.new()
		tag.text = "[pinned]" if bool(row.is_pinned) else "        "
		tag.add_theme_font_size_override("font_size", 10)
		tag.add_theme_color_override("font_color", UIStyleFactory.COLOR_VERB_ACTIVE if bool(row.is_pinned) else UIStyleFactory.COLOR_MUTED)
		tag.custom_minimum_size = Vector2(56, 0)
		hbox.add_child(tag)
		var name_lbl := Label.new()
		name_lbl.text = String(row.name)
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.custom_minimum_size = Vector2(140, 0)
		hbox.add_child(name_lbl)
		var ov_lbl := Label.new()
		ov_lbl.text = "overlap %.2f" % float(row.overlap)
		ov_lbl.add_theme_font_size_override("font_size", 11)
		ov_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
		ov_lbl.custom_minimum_size = Vector2(80, 0)
		hbox.add_child(ov_lbl)
		var cost_lbl := Label.new()
		cost_lbl.text = "cost: ??"
		cost_lbl.add_theme_font_size_override("font_size", 11)
		cost_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
		cost_lbl.custom_minimum_size = Vector2(64, 0)
		hbox.add_child(cost_lbl)
		var verb_lbl := Label.new()
		verb_lbl.text = "[D] detach (coming soon)" if bool(row.is_pinned) else "[A] attach (coming soon)"
		verb_lbl.add_theme_font_size_override("font_size", 11)
		verb_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
		hbox.add_child(verb_lbl)
		_body_box.add_child(hbox)

## Returns the faction with the highest |scalar| standing, excluding "The Demos".
## Empty string when no eligible faction exists.
func _top_other_faction_by_magnitude(standings: Dictionary) -> String:
	var best_name: String = ""
	var best_mag: float = 0.0
	for fname in standings.keys():
		if str(fname) == "The Demos":
			continue
		var s = standings[fname]
		if s == null or not s.has_method("scalar"):
			continue
		var mag: float = absf(float(s.scalar()))
		if mag > best_mag:
			best_mag = mag
			best_name = str(fname)
	return best_name

## Render top factions with full 6-channel standing + signature progress.
## Sorted by aggregate scalar magnitude. Up to 6 rows.
func _render_faction_standings_grid(farm, standings: Dictionary) -> void:
	var known: Array = farm.get_known_emojis() if farm and farm.has_method("get_known_emojis") else []
	var known_set: Dictionary = {}
	for e in known:
		known_set[str(e)] = true

	var faction_reg := FactionRegistry.get_shared()

	var rows: Array = []
	for fname in standings.keys():
		var s = standings[fname]
		if s == null:
			continue
		var sc: float = s.scalar() if s.has_method("scalar") else 0.0
		if absf(sc) < 0.0001 \
				and absf(s.trust) < 0.0001 and absf(s.debt) < 0.0001 \
				and absf(s.attention) < 0.0001 and absf(s.access) < 0.0001 \
				and absf(s.legitimacy) < 0.0001 and absf(s.entanglement) < 0.0001:
			continue
		var f = faction_reg.get_by_name(str(fname))
		var sig: Array = f.cloud.duplicate() if f != null else []
		var sig_total: int = sig.size()
		var sig_known: int = 0
		for atom in sig:
			if known_set.has(str(atom)):
				sig_known += 1
		rows.append({
			"faction": str(fname),
			"scalar": sc,
			"trust": float(s.trust),
			"debt": float(s.debt),
			"attention": float(s.attention),
			"access": float(s.access),
			"legitimacy": float(s.legitimacy),
			"entanglement": float(s.entanglement),
			"sig_known": sig_known,
			"sig_total": sig_total,
		})

	rows.sort_custom(func(a, b): return absf(float(a.scalar)) > absf(float(b.scalar)))

	if rows.is_empty():
		_body_box.add_child(_make_muted_label("(no significant standings yet)", 11))
		return

	# Header row — channel labels.
	_body_box.add_child(_make_standing_row(["faction", "trst", "dbt", "attn", "acc", "leg", "ent", "sig"], COLOR_HEADER, true))

	var shown := 0
	for row in rows:
		if shown >= 6:
			break
		var color: Color = UIStyleFactory.COLOR_VALUE if shown == 0 else UIStyleFactory.COLOR_ITEM_IDLE
		var cells := [
			str(row.faction),
			"%+.2f" % float(row.trust),
			"%+.2f" % float(row.debt),
			"%+.2f" % float(row.attention),
			"%+.2f" % float(row.access),
			"%+.2f" % float(row.legitimacy),
			"%+.2f" % float(row.entanglement),
			"%d/%d" % [int(row.sig_known), int(row.sig_total)],
		]
		_body_box.add_child(_make_standing_row(cells, color, false))
		shown += 1

	if rows.size() > 6:
		_body_box.add_child(_make_muted_label(
			"… %d more standings on V `affinity`" % (rows.size() - 6), 11))

## Build a single fixed-width row for the standing grid. cells[0] is faction
## name (wide); cells[1..6] are channel values; cells[7] is sig progress.
func _make_standing_row(cells: Array, color: Color, is_header: bool) -> HBoxContainer:
	const WIDTHS: Array = [148, 48, 48, 48, 48, 48, 48, 56]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for i in range(cells.size()):
		var lbl := Label.new()
		lbl.text = str(cells[i])
		lbl.add_theme_font_size_override("font_size", 10 if is_header else 11)
		lbl.add_theme_color_override("font_color", color)
		if i < WIDTHS.size():
			lbl.custom_minimum_size = Vector2(WIDTHS[i], 0)
		if i == 0:
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
	return row

func _build_lexicon_section(farm) -> void:
	_body_box.add_child(_make_section_header("lexicon"))
	if farm == null:
		_body_box.add_child(_make_muted_label("(farm not loaded)", 11))
		return

	var lex = null
	if farm.has_method("_ensure_icon_atlas"):
		lex = farm._ensure_icon_atlas()
	elif "icon_atlas" in farm and farm.icon_atlas != null:
		lex = farm.icon_atlas

	if lex == null:
		_body_box.add_child(_make_muted_label("(lexicon not available)", 11))
		return

	var known_icons: Array = farm.known_icons if "known_icons" in farm else []
	var discovered: Dictionary = load("res://Core/Factions/IconRegistry.gd").discovered_set_from_icons(known_icons)
	var known_records: Array = lex.filter_discovered_records(discovered)

	if known_records.is_empty():
		_body_box.add_child(_make_muted_label(
			"no named icons discovered yet — complete quests to learn faction vocabulary", 11,
		))
		return

	_body_box.add_child(_make_muted_label("%d named icons known" % known_records.size(), 11))

	for rec in known_records:
		var p0 := str(rec.get("pole_0", "?"))
		var p1 := str(rec.get("pole_1", "?"))
		var icon_name := str(rec.get("name", ""))
		var factions: Array = lex.get_factions_for_pair(p0, p1)
		var label_text := "%s↔%s  %s" % [p0, p1, icon_name]
		if not factions.is_empty():
			label_text += "  · %s" % ", ".join(factions)
		var row := Label.new()
		row.text = label_text
		row.add_theme_font_size_override("font_size", 11)
		row.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE)
		_body_box.add_child(row)

## Z Self tab — Icon Picker. The player's 3 active expression slots, with
## a paginated list of known_icons for rebinding via 1/2/3 + GHJKL; + E.
##
## Controls (Self tab only):
##   1/2/3      — pick which slot (0/1/2) to rebind
##   GHJKL;     — cursor through visible known_icons (page of 6)
##   W/S        — page through known_icons (6 per page)
##   E          — assign cursor's icon to selected slot
func _build_icon_picker(farm) -> void:
	_body_box.add_child(_make_section_header("icons · expression"))
	if farm == null or not farm.has_method("get_known_icons"):
		_body_box.add_child(_make_muted_label("(farm not loaded)", 11))
		return
	var icons: Array = farm.get_known_icons()
	var slots: Array = farm.active_icon_slots if "active_icon_slots" in farm else [0,1,2]

	# Active slots row (1/2/3)
	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 14)
	for i in range(3):
		var slot_idx: int = int(slots[i]) if i < slots.size() else i
		var icon_str := "?"
		if slot_idx >= 0 and slot_idx < icons.size():
			var icon: Dictionary = icons[slot_idx]
			icon_str = "%s%s" % [str(icon.get("north", "·")), str(icon.get("south", "·"))]
		var sel := (i == _self_picker_slot)
		var lbl := Label.new()
		lbl.text = "[%d] %s" % [i + 1, icon_str]
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color",
			UIStyleFactory.COLOR_TAB_ACTIVE if sel else UIStyleFactory.COLOR_ITEM_IDLE)
		slot_row.add_child(lbl)
	_body_box.add_child(slot_row)
	_body_box.add_child(_make_spacer(4))

	# Known-icons page (GHJKL; cursor)
	if icons.is_empty():
		_body_box.add_child(_make_muted_label("(no known icons yet — incorporate icons via the Icon hat)", 11))
		return

	var page_size := ITEM_KEYS.size()  # 6
	var max_page: int = max(0, int(float(icons.size() - 1) / float(page_size)))
	_self_picker_page = clampi(_self_picker_page, 0, max_page)
	var start := _self_picker_page * page_size
	var end := mini(start + page_size, icons.size())
	_self_picker_icon = clampi(_self_picker_icon, start, end - 1)

	var pair_row := HBoxContainer.new()
	pair_row.add_theme_constant_override("separation", 10)
	for i in range(start, end):
		var icon: Dictionary = icons[i]
		var key_str: String = ITEM_KEYS[i - start]
		var icon_str := "%s%s" % [str(icon.get("north", "·")), str(icon.get("south", "·"))]
		var sel := (i == _self_picker_icon)
		var lbl := Label.new()
		lbl.text = "[%s] %s" % [key_str, icon_str]
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color",
			UIStyleFactory.COLOR_TAB_ACTIVE if sel else UIStyleFactory.COLOR_ITEM_IDLE)
		pair_row.add_child(lbl)
	_body_box.add_child(pair_row)

	# Page indicator + hints
	var hint := Label.new()
	hint.text = "page %d/%d   ·   1/2/3 slot   ·   GHJKL; cursor   ·   W/S page   ·   R assign" % [_self_picker_page + 1, max_page + 1]
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	_body_box.add_child(hint)

func _build_our_faction_view(farm) -> void:
	_body_box.add_child(_make_section_header("the demos"))
	var biome = null
	if farm and farm.grid and farm.grid.has_method("get_biome"):
		biome = farm.grid.get_biome("TheDemos")
	if biome == null or not biome.get("quantum_computer"):
		_body_box.add_child(_make_muted_label("the demos biome not loaded.", 11))
		return
	var qc = biome.quantum_computer
	var icons: Array = biome.icons if "icons" in biome else []
	if icons.is_empty() or qc == null or not qc.get("register_map"):
		_body_box.add_child(_make_muted_label("the demos has no icons yet.", 11))
		return
	for q in range(min(icons.size(), int(qc.register_map.num_qubits))):
		var icon: Dictionary = icons[q] if (icons[q] is Dictionary) else {}
		var p0 := str(icon.get("pole_0", "?"))
		var p1 := str(icon.get("pole_1", "?"))
		var binding_name := str(icon.get("name", ""))
		var m0: float = qc.get_marginal(q, 0) if qc.has_method("get_marginal") else 0.5
		var bias: float = clampf(1.0 - m0, 0.0, 1.0)  # how far toward pole_1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_lbl := Label.new()
		name_lbl.text = "%s %s" % [p0, binding_name]
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
		name_lbl.custom_minimum_size = Vector2(120, 0)
		row.add_child(name_lbl)
		var bar_lbl := Label.new()
		var filled := int(round(bias * 8.0))
		bar_lbl.text = "█".repeat(filled) + "░".repeat(8 - filled)
		bar_lbl.add_theme_font_size_override("font_size", 11)
		bar_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE)
		row.add_child(bar_lbl)
		var pole_lbl := Label.new()
		pole_lbl.text = p1
		pole_lbl.add_theme_font_size_override("font_size", 11)
		pole_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
		row.add_child(pole_lbl)
		_body_box.add_child(row)

	_render_faction_card(farm, "The Demos")

## Render a faction's nature card: signature, affinity, biomes-of-presence,
## alignment couplings, standing. Reusable for player or NPC inspection.
func _render_faction_card(farm, faction_name: String) -> void:
	var card: Dictionary = FactionCard.gather(faction_name, farm)
	if not bool(card.get("present", false)):
		return

	var signature: Array = card.get("signature", [])
	if not signature.is_empty():
		_body_box.add_child(_make_spacer(4))
		var sig_lbl := Label.new()
		sig_lbl.text = "signature  " + " ".join(signature)
		sig_lbl.add_theme_font_size_override("font_size", 11)
		sig_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
		_body_box.add_child(sig_lbl)

	var affinity: Array = card.get("affinity", [])
	if not affinity.is_empty():
		var parts: Array = []
		for entry in affinity:
			parts.append("%s %.2f" % [str(entry.get("emoji", "")), float(entry.get("value", 0.0))])
		var aff_lbl := Label.new()
		aff_lbl.text = "affinity  " + " · ".join(parts)
		aff_lbl.add_theme_font_size_override("font_size", 11)
		aff_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE)
		_body_box.add_child(aff_lbl)

	var biomes: Array = card.get("biomes_of_presence", [])
	if not biomes.is_empty():
		var bio_lbl := Label.new()
		bio_lbl.text = "expressed in  " + ", ".join(biomes)
		bio_lbl.add_theme_font_size_override("font_size", 11)
		bio_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
		_body_box.add_child(bio_lbl)

	var alignment: Array = card.get("alignment_top", [])
	if not alignment.is_empty():
		for entry in alignment:
			var w: float = float(entry.get("weight", 0.0))
			var sign_val := "+" if w >= 0.0 else "−"
			var ali_lbl := Label.new()
			ali_lbl.text = "  %s → %s   %s%.2f" % [
				str(entry.get("from", "")), str(entry.get("to", "")),
				sign_val, absf(w),
			]
			ali_lbl.add_theme_font_size_override("font_size", 11)
			ali_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
			_body_box.add_child(ali_lbl)

	var standing: float = float(card.get("standing", 0.0))
	if absf(standing) > 0.0001:
		var st_lbl := Label.new()
		st_lbl.text = "standing  %+.2f" % standing
		st_lbl.add_theme_font_size_override("font_size", 11)
		st_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE)
		_body_box.add_child(st_lbl)

# =============================================================================
# BODY: STORY — narrative log section.
# =============================================================================

## Render per-active-biome berry consumption (count + accumulated phase).
## Berry phase gates forest_evolving → forest_communion story flags.
func _render_berry_phase_section(farm) -> void:
	if farm == null or not "grid" in farm or farm.grid == null:
		return
	if not farm.grid.has_method("get_all_biomes"):
		return
	var biomes: Dictionary = farm.grid.get_all_biomes()
	var rows: Array = []
	for biome_name in biomes.keys():
		var biome = biomes[biome_name]
		if biome == null:
			continue
		var qc = biome.quantum_computer if "quantum_computer" in biome else null
		if qc == null:
			continue
		var berry = qc.berry_register if "berry_register" in qc else null
		if berry == null:
			continue
		var c: int = berry.get_consumed_count() if berry.has_method("get_consumed_count") else 0
		var p: float = berry.get_consumed_phase() if berry.has_method("get_consumed_phase") else 0.0
		if c == 0 and absf(p) < 0.01:
			continue
		rows.append({"biome": str(biome_name), "count": c, "phase": p})
	if rows.is_empty():
		return
	_body_box.add_child(_make_section_header("berry phase"))
	for row in rows:
		var lbl := Label.new()
		# Phase target reference: 4π ≈ 12.566 (full sphere). Show progress against that.
		var ratio: float = float(row.phase) / TAU / 2.0  # phase / (4π)
		lbl.text = "%s · %d consumed · phase %.2f rad (%.0f%% of 4π)" % [
			str(row.biome), int(row.count), float(row.phase), ratio * 100.0
		]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE)
		_body_box.add_child(lbl)
	_body_box.add_child(_make_spacer(8))

func _build_story_body() -> void:
	_ensure_story_chatter_wired()
	var engine = _story_engine()
	if engine == null or engine.graph == null:
		_body_box.add_child(_make_muted_label("Story substrate not ready.", 12))
		return

	# Resolve focused node: explicit ui_focus override OR density argmax.
	var focus_id: String = _story_focus_node if _story_focus_node != "" else engine.default_ui_focus()
	if focus_id == "" or not engine.graph.nodes.has(focus_id):
		_body_box.add_child(_make_muted_label("No nodes in graph.", 12))
		return
	var focus_node = engine.graph.nodes[focus_id]
	var outgoing: Array = engine.graph.get_outgoing_edges(focus_id)
	if outgoing.size() > 0:
		_story_edge_idx = clampi(_story_edge_idx, 0, outgoing.size() - 1)
	else:
		_story_edge_idx = 0

	# === ACTIVITY FEED (PlayerEventLog ring buffer, newest first) ===
	const ACTIVITY_VISIBLE := 12
	var player_event_log = get_node_or_null("/root/PlayerEventLog")
	var recent_events: Array = player_event_log.get_recent(ACTIVITY_VISIBLE, 1) if player_event_log and player_event_log.has_method("get_recent") else []
	var total_events: int = player_event_log.get_recent(player_event_log.MAX_EVENTS, 1).size() if player_event_log and player_event_log.has_method("get_recent") else 0
	var header_text: String = "activity"
	if total_events > recent_events.size():
		header_text = "activity (%d of %d)" % [recent_events.size(), total_events]
	_body_box.add_child(_make_section_header(header_text))
	if recent_events.is_empty():
		_body_box.add_child(_make_muted_label("No events yet.", 12))
	else:
		for ev in recent_events:
			var ev_lbl := RichTextLabel.new()
			ev_lbl.bbcode_enabled = true
			var path_str: String = str(ev.get("path", ""))
			var path_chip: String = "  [color=#7faab8][%s][/color]" % path_str if path_str != "" else ""
			ev_lbl.text = str(ev.get("message", "")) + path_chip
			ev_lbl.fit_content = true
			ev_lbl.scroll_active = false
			ev_lbl.add_theme_font_size_override("normal_font_size", 12)
			_body_box.add_child(ev_lbl)
	_body_box.add_child(_make_spacer(8))

	# === BERRY PHASE (gates story flags forest_evolving → forest_communion) ===
	var berry_farm = InstrumentLocator.resolve_active_farm(self)
	if berry_farm != null:
		_render_berry_phase_section(berry_farm)

	# === STORY LOG (fired arc beats, newest first) ===
	var story_farm = InstrumentLocator.resolve_active_farm(self)
	var story_log: Array = story_farm.story_log if story_farm != null and "story_log" in story_farm else []
	if not story_log.is_empty():
		var log_visible: int = story_log.size()
		_body_box.add_child(_make_section_header("story (%d)" % log_visible))
		for i in range(log_visible):
			var entry: Dictionary = story_log[story_log.size() - 1 - i]
			var act_n: int = int(entry.get("act", 0))
			var beat_text: String = str(entry.get("arc_beat", ""))
			if beat_text == "":
				continue
			var beat_lbl := Label.new()
			beat_lbl.text = "Act %d — %s" % [act_n, beat_text]
			beat_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			beat_lbl.add_theme_font_size_override("font_size", 12)
			beat_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE if i == 0 else UIStyleFactory.COLOR_MUTED)
			_body_box.add_child(beat_lbl)
		_body_box.add_child(_make_spacer(8))

	# === FOCUS NODE ===
	_body_box.add_child(_make_section_header("focus · %s · act %d" % [focus_node.display_name, focus_node.act]))
	var beat := Label.new()
	beat.text = str(focus_node.arc_beat) if focus_node.arc_beat != "" else "(no beat text)"
	beat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	beat.add_theme_font_size_override("font_size", 13)
	beat.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE)
	_body_box.add_child(beat)
	_body_box.add_child(_make_spacer(6))

	# Faction charge bar
	var charge: Dictionary = focus_node.faction_charge()
	if not charge.is_empty():
		var charge_text := ""
		for f in charge:
			charge_text += "%s %+.2f   " % [str(f), float(charge[f])]
		var charge_lbl := Label.new()
		charge_lbl.text = "charge: " + charge_text
		charge_lbl.add_theme_font_size_override("font_size", 11)
		charge_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
		_body_box.add_child(charge_lbl)

	# Density / coherence summary
	var density_w: float = float(engine.graph.density.get(focus_id, 0.0))
	var coh: float = engine.graph.coherence()
	var coh_word: String = "diffuse" if coh < 0.35 else ("moderate" if coh < 0.7 else "focused")
	var summary := Label.new()
	summary.text = "attention here: %.2f   ·   narrative focus: %.2f (%s)" % [density_w, coh, coh_word]
	summary.add_theme_font_size_override("font_size", 11)
	summary.add_theme_color_override("font_color", COLOR_HEADER)
	_body_box.add_child(summary)
	_body_box.add_child(_make_spacer(8))

	# === EDGES ===
	_body_box.add_child(_make_section_header("edges from here"))
	if outgoing.is_empty():
		_body_box.add_child(_make_muted_label("(no outgoing edges)", 11))
	else:
		for i in range(outgoing.size()):
			var edge = outgoing[i]
			var key_str: String = ITEM_KEYS[i] if i < ITEM_KEYS.size() else " "
			var target = engine.graph.nodes.get(edge.to_node, null)
			var target_name: String = target.display_name if target != null else edge.to_node
			var is_selected := (i == _story_edge_idx)
			var marker := "▶ " if is_selected else "  "
			var fired_glyph := " ✓" if edge.fired else ""
			var line := "%s[%s] → %s%s" % [marker, key_str, target_name, fired_glyph]
			var lbl := Label.new()
			lbl.text = line
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color",
				UIStyleFactory.COLOR_TAB_ACTIVE if is_selected else UIStyleFactory.COLOR_ITEM_IDLE)
			_body_box.add_child(lbl)

	_body_box.add_child(_make_spacer(8))

	# === ICON ROW ===
	_body_box.add_child(_make_section_header("icon · expression"))
	var icons: Array = _story_icons()
	var icon_row := HBoxContainer.new()
	icon_row.add_theme_constant_override("separation", 18)
	for i in range(3):
		var icon: Dictionary = icons[i] if i < icons.size() else {}
		var sel := (i == _story_icon_idx)
		var icon_text := "%s%s" % [str(icon.get("north", "·")), str(icon.get("south", "·"))]
		var ilbl := Label.new()
		ilbl.text = "[%d] %s" % [i + 1, icon_text]
		ilbl.add_theme_font_size_override("font_size", 14)
		ilbl.add_theme_color_override("font_color",
			UIStyleFactory.COLOR_TAB_ACTIVE if sel else UIStyleFactory.COLOR_ITEM_IDLE)
		icon_row.add_child(ilbl)
	_body_box.add_child(icon_row)
	_body_box.add_child(_make_spacer(4))

	# === ACTION ROW (canonical Q E R F left-to-right) ===
	_body_box.add_child(_make_action_row("Q", "Harmonize", "yield self toward target — alignment drifts toward this chatter's emoji palette"))
	var e_label := "flatten" if _story_inspect_open else "inspect ▾"
	var e_desc := "close detail panel" if _story_inspect_open else "open chatter detail (pauses sim)"
	_body_box.add_child(_make_action_row("E", e_label, e_desc))
	_body_box.add_child(_make_action_row("R", "Express", "push self outward — strong commit: alignment + mass shift + phase rotation"))
	var f_label := "flatten" if _story_inspect_open else "—"
	var f_desc := "close detail panel" if _story_inspect_open else ""
	_body_box.add_child(_make_action_row("F", f_label, f_desc))
	_body_box.add_child(_make_spacer(8))

	# === CHATTER BUBBLES (cursor target for QERF) ===
	_body_box.add_child(_make_section_header("chatter — GHJKL; selects target"))
	var chatter: Array = engine.recent_chatter(6)
	if chatter.is_empty():
		_body_box.add_child(_make_muted_label("(silence so far — wait for socialites)", 10))
		_story_chatter_idx = 0
	else:
		_story_chatter_idx = clampi(_story_chatter_idx, 0, chatter.size() - 1)
		for i in range(chatter.size()):
			var sel := (i == _story_chatter_idx)
			var key_str: String = ITEM_KEYS[i] if i < ITEM_KEYS.size() else " "
			_body_box.add_child(_make_chatter_bubble(chatter[i], sel, key_str))
		# Attractor state for the selected chatter's biome — what it's "trying to become".
		var sel_ev: Dictionary = chatter[_story_chatter_idx] if _story_chatter_idx < chatter.size() else {}
		var sel_biome_name: String = str(sel_ev.get("biome", ""))
		if sel_biome_name != "":
			var farm = InstrumentLocator.resolve_active_farm(self)
			if farm and farm.grid and farm.grid.has_method("get_biome"):
				var sel_biome = farm.grid.get_biome(sel_biome_name)
				if sel_biome and sel_biome.has_method("get_attractor_state"):
					var cached: Dictionary = _story_attractor_cache.get(sel_biome_name, {})
					var att: Dictionary
					if cached.is_empty() or Engine.get_physics_frames() - int(cached.get("phrame", 0)) > ATTRACTOR_CACHE_TTL:
						att = sel_biome.get_attractor_state()
						if not att.is_empty():
							_story_attractor_cache[sel_biome_name] = att.duplicate()
							_story_attractor_cache[sel_biome_name]["phrame"] = Engine.get_physics_frames()
					else:
						att = cached
					var att_emojis: Array = att.get("emojis", [])
					if not att_emojis.is_empty():
						var gap: float = float(att.get("eigenvalue_gap", 0.0))
						var att_lbl := Label.new()
						att_lbl.text = "  → %s  (gap %.2f — %s)" % [
							" ".join(PackedStringArray(att_emojis.slice(0, 4))),
							gap,
							"sharp" if gap > 0.1 else "diffuse",
						]
						att_lbl.add_theme_font_size_override("font_size", 11)
						att_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
						_body_box.add_child(att_lbl)

	# === INSPECT PANEL (E expands; F flattens) ===
	if _story_inspect_open:
		_body_box.add_child(_make_spacer(6))
		_body_box.add_child(_make_story_inspect_panel())
	_body_box.add_child(_make_spacer(8))

	# === TRAJECTORY ===
	_body_box.add_child(_make_section_header("trajectory (last 5)"))
	var traj: Array = engine.trajectory.last(5) if engine.trajectory != null else []
	if traj.is_empty():
		_body_box.add_child(_make_muted_label("(no steps yet)", 10))
	else:
		for entry in traj:
			var verb := str(entry.get("verb", ""))
			var verb_chip := ("[%s] " % verb) if verb != "" else ""
			var spk := str(entry.get("speaker", ""))
			var t := Label.new()
			t.text = "  %s%s · %s → %s" % [verb_chip, spk, str(entry.get("from_node", "")), str(entry.get("to_node", ""))]
			t.add_theme_font_size_override("font_size", 10)
			t.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
			_body_box.add_child(t)

	_body_box.add_child(_make_spacer(8))
	_body_box.add_child(_make_muted_label("GHJKL; pick chatter   ·   1/2/3 pick icon   ·   Q harmonize / R express / E inspect / F flatten   ·   W parent / S child node", 10))

func _make_story_inspect_panel() -> Control:
	# Detail panel for the selected chatter line. Surfaces the data Q/R will
	# move when fired: chatter emojis, target faction standing, topic node.
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.13, 0.9)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	panel.add_child(box)

	var engine = _story_engine()
	if engine == null:
		var lbl := Label.new()
		lbl.text = "(story engine unavailable)"
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
		box.add_child(lbl)
		return panel

	var chatter: Array = engine.recent_chatter(6)
	if chatter.is_empty():
		var lbl2 := Label.new()
		lbl2.text = "(no chatter to inspect)"
		lbl2.add_theme_font_size_override("font_size", 11)
		lbl2.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
		box.add_child(lbl2)
		return panel

	var idx := clampi(_story_chatter_idx, 0, chatter.size() - 1)
	var ev: Dictionary = chatter[idx]

	box.add_child(_make_section_header("inspect ▾"))

	var emojis: Array = ev.get("emojis", [])
	if not emojis.is_empty():
		box.add_child(_make_kv_row("emojis", " ".join(PackedStringArray(emojis))))

	var faction: String = str(ev.get("faction", ""))
	if faction != "":
		box.add_child(_make_kv_row("speaker", faction))
		var farm = InstrumentLocator.resolve_active_farm(self)
		if farm and "faction_standings" in farm:
			var standings: Dictionary = farm.faction_standings
			if standings.has(faction):
				box.add_child(_make_kv_row("standing", "%+.2f" % float(standings[faction])))

	var topic: String = str(ev.get("topic_node", ""))
	if topic != "":
		box.add_child(_make_kv_row("topic", topic))

	var biome: String = str(ev.get("biome", ""))
	if biome != "":
		box.add_child(_make_kv_row("biome", biome))

	var hint := Label.new()
	hint.text = "Q harmonize toward · R express outward · F to flatten"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	box.add_child(hint)

	return panel

func _story_engine() -> Node:
	if Engine.has_singleton("StoryEngine"):
		return Engine.get_singleton("StoryEngine")
	var root := get_tree().root if is_inside_tree() else null
	if root != null and root.has_node("StoryEngine"):
		return root.get_node("StoryEngine")
	return null

## Pick the player's 3 active Icons. Golden cut: top 3 known icons by harvest count
## (or just the first 3 if no count). Falls back to the default label if none.
func _story_icons() -> Array:
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm == null or not farm.has_method("get_known_icons"):
		return []
	var icons: Array = farm.get_known_icons()
	if icons.is_empty():
		return []
	# No harvest-count metric in the golden cut; just take first 3.
	var slice := icons.slice(0, mini(3, icons.size()))
	return slice

func _ensure_story_chatter_wired() -> void:
	if _story_chatter_connected:
		return
	var engine = _story_engine()
	if engine == null:
		return
	if engine.has_signal("chatter_emitted") and not engine.chatter_emitted.is_connected(_on_story_chatter):
		engine.chatter_emitted.connect(_on_story_chatter)
	if engine.has_signal("trajectory_advanced") and not engine.trajectory_advanced.is_connected(_on_story_trajectory):
		engine.trajectory_advanced.connect(_on_story_trajectory)
	var player_event_log = get_node_or_null("/root/PlayerEventLog")
	if player_event_log != null and player_event_log.has_signal("event_added") and not player_event_log.event_added.is_connected(_on_player_event_added):
		player_event_log.event_added.connect(_on_player_event_added)
	_story_chatter_connected = true

func _on_player_event_added(_entry: Dictionary) -> void:
	if _current_tab == Tab.STORY and is_active:
		_refresh_body()

func _on_story_chatter(_speaker: String, _faction: String, _line: String, _topic: String) -> void:
	if _current_tab == Tab.STORY and is_active:
		_refresh_body()

## WASD on Story tab: W (step=-1) follows trajectory backward (parent — first incoming edge);
## S (step=+1) follows the *cursor* forward without measuring (peek at selected edge's target).
func _story_crawl(step: int) -> void:
	var engine = _story_engine()
	if engine == null:
		return
	var focus_id: String = _story_focus_node if _story_focus_node != "" else engine.default_ui_focus()
	if focus_id == "":
		return
	if step > 0:
		# S: peek at selected outgoing edge's to_node.
		var outgoing: Array = engine.graph.get_outgoing_edges(focus_id)
		if outgoing.is_empty():
			return
		var idx := clampi(_story_edge_idx, 0, outgoing.size() - 1)
		var target: String = outgoing[idx].to_node
		if target != "" and engine.graph.nodes.has(target):
			_story_focus_node = target
			_story_edge_idx = 0
			_refresh_body()
	else:
		# W: step back to first incoming edge's from_node.
		var incoming_ids: Array = engine.graph.incoming.get(focus_id, [])
		if incoming_ids.is_empty():
			return
		var first_in = engine.graph.edges.get(incoming_ids[0], null)
		if first_in == null:
			return
		var src: String = first_in.from_node
		if src != "" and engine.graph.nodes.has(src):
			_story_focus_node = src
			_story_edge_idx = 0
			_refresh_body()

func _on_story_trajectory(_from: String, to_node: String, _edge: String) -> void:
	# When trajectory advances (system or player E), auto-follow the focus.
	if _story_focus_node == "":
		# If user hasn't manually overridden focus, the argmax will track automatically.
		pass
	else:
		# User had manual focus; system advance moves it to the new target.
		_story_focus_node = to_node
		_story_edge_idx = 0
	if _current_tab == Tab.STORY and is_active:
		_refresh_body()

# =============================================================================
# BODY: BALANCE — experimental action cost / timescale inspector.
# =============================================================================

func _build_balance_body() -> void:
	_refresh_balance_snapshot()
	_ensure_balance_settings_loaded()

	# === SETTINGS LIST (Q − value · E reset · R + value · GHJKL; pick) ===
	_body_box.add_child(_make_section_header("settings"))
	var page_size: int = ITEM_KEYS.size()
	var page_start: int = _balance_setting_page * page_size
	var page_end: int = mini(page_start + page_size, _balance_settings.size())
	for i in range(page_start, page_end):
		_body_box.add_child(_make_balance_setting_row(i, i - page_start))
	var page_count: int = max(1, int(ceil(float(_balance_settings.size()) / float(page_size))))
	if page_count > 1:
		_body_box.add_child(_make_muted_label(
			"Q − value  ·  R + value  ·  E reset  ·  GHJKL; pick  ·  A/D page (%d/%d)" % [
				_balance_setting_page + 1, page_count], 11))
	else:
		_body_box.add_child(_make_muted_label(
			"Q − value  ·  R + value  ·  E reset  ·  GHJKL; pick", 11))
	_body_box.add_child(_make_spacer(6))

	# === BELOW: read-only action-cost inspector (kept for context) ===
	if _balance_snapshot.is_empty():
		_body_box.add_child(_make_muted_label("(action cost inspector unavailable — no active farm)", 11))
		return
	_body_box.add_child(_make_section_header("profile"))
	var profile_id := str(_balance_snapshot.get("profile_id", "default"))
	var profile_name := str(_balance_snapshot.get("profile_display_name", profile_id))
	_body_box.add_child(_make_kv_row("id", profile_id))
	_body_box.add_child(_make_kv_row("name", profile_name))

	_body_box.add_child(_make_spacer(4))
	_body_box.add_child(_make_section_header("actions"))

	if _balance_action_keys.is_empty():
		_body_box.add_child(_make_muted_label("no actions configured.", 12))
	else:
		var total := _balance_action_keys.size()
		var act_page_size := ITEM_KEYS.size()
		var act_page := int(float(_balance_action_idx) / float(act_page_size))
		var start := act_page * act_page_size
		var end: int = mini(start + act_page_size, total)
		for i in range(start, end):
			_body_box.add_child(_make_balance_action_row(i, i - start))
		var pages := int(ceil(float(total) / float(act_page_size)))
		_body_box.add_child(_make_muted_label(
			"action (%d/%d, p%d/%d) — read-only inspector" % [_balance_action_idx + 1, total, act_page + 1, pages],
			11,
		))

	_body_box.add_child(_make_spacer(4))
	_body_box.add_child(_make_section_header("selected action detail"))
	if _balance_action_idx < _balance_action_keys.size():
		var action: String = _balance_action_keys[_balance_action_idx]
		var costs: Dictionary = _balance_snapshot.get("action_costs", {})
		_body_box.add_child(_make_kv_row("cost", _format_cost(costs.get(action, {}))))
		var roi_notes: Dictionary = _balance_snapshot.get("roi_notes", {})
		_body_box.add_child(_make_kv_row("roi", str(roi_notes.get(action, "—"))))

	var quest: Dictionary = _balance_snapshot.get("quest_rewards", {})
	var quest_ratio = quest.get("resource_reward_base_ratio", null)
	if quest_ratio != null:
		_body_box.add_child(_make_kv_row("quest reward ratio", "%.2f" % float(quest_ratio)))

	if not _balance_biomes.is_empty():
		_body_box.add_child(_make_spacer(4))
		_body_box.add_child(_make_section_header("timescale"))
		var biome_name: String = _balance_biomes[_balance_biome_idx]
		_body_box.add_child(_make_kv_row(
			"biome",
			"%s  (%d/%d)" % [biome_name, _balance_biome_idx + 1, _balance_biomes.size()],
		))
		if bool(_balance_projection.get("ok", false)):
			var stride := int(_balance_projection.get("recommended_stride", -1))
			var dt := float(_balance_projection.get("recommended_dt", -1.0))
			var top := str(_balance_projection.get("top_emoji", ""))
			var top_p := float(_balance_projection.get("top_probability", 0.0))
			if stride >= 0 and dt > 0.0:
				_body_box.add_child(_make_kv_row("recommend", "stride %d  dt %.4f" % [stride, dt]))
			if top != "":
				_body_box.add_child(_make_kv_row("top target", "%s  p=%.3f" % [top, top_p]))
		else:
			_body_box.add_child(_make_muted_label("projection unavailable", 11))

	_body_box.add_child(_make_spacer(4))
	_body_box.add_child(_make_muted_label("read-only. write ops stay in the experimental chatter page.", 10))

func _make_balance_setting_row(idx: int, slot_idx: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var key_str: String = ITEM_KEYS[slot_idx] if slot_idx < ITEM_KEYS.size() else "?"
	row.add_child(_make_key_chip(key_str))

	var setting: Dictionary = _balance_settings[idx]
	var cat_lbl := Label.new()
	cat_lbl.text = str(setting.get("category", ""))
	cat_lbl.add_theme_font_size_override("font_size", 11)
	cat_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	cat_lbl.custom_minimum_size = Vector2(70, 0)
	row.add_child(cat_lbl)

	var name_lbl := Label.new()
	name_lbl.text = str(setting.get("label", setting.get("id", "—")))
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var value_lbl := Label.new()
	value_lbl.text = _balance_setting_format(setting)
	value_lbl.add_theme_font_size_override("font_size", 13)
	value_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE)
	row.add_child(value_lbl)

	var selected := idx == _balance_setting_idx
	var c := UIStyleFactory.COLOR_TAB_ACTIVE if selected else UIStyleFactory.COLOR_ITEM_IDLE
	name_lbl.add_theme_color_override("font_color", c)
	if selected:
		name_lbl.text = "▸ " + name_lbl.text
	return row

func _make_balance_action_row(idx: int, slot_idx: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var key_str: String = ITEM_KEYS[slot_idx] if slot_idx < ITEM_KEYS.size() else "?"
	row.add_child(_make_key_chip(key_str))

	var action_name: String = _balance_action_keys[idx]
	var name_lbl := Label.new()
	name_lbl.text = action_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var costs: Dictionary = _balance_snapshot.get("action_costs", {})
	var cost_lbl := Label.new()
	cost_lbl.text = _format_cost(costs.get(action_name, {}))
	cost_lbl.add_theme_font_size_override("font_size", 12)
	cost_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE)
	row.add_child(cost_lbl)

	var selected := idx == _balance_action_idx
	var c := UIStyleFactory.COLOR_TAB_ACTIVE if selected else UIStyleFactory.COLOR_ITEM_IDLE
	name_lbl.add_theme_color_override("font_color", c)
	if selected:
		name_lbl.text = "▸ " + name_lbl.text
	return row

# =============================================================================
# BODY: GUIDE — pick a section with GHJKL, see prose.
# =============================================================================

func _build_guide_body() -> void:
	_body_box.add_child(_make_section_header("pick a section"))
	var picker := HBoxContainer.new()
	picker.add_theme_constant_override("separation", 12)
	picker.alignment = BoxContainer.ALIGNMENT_CENTER
	_body_box.add_child(picker)
	for i in range(GUIDE_ITEMS.size()):
		var key_str := str(ITEM_KEYS[i]) if i < ITEM_KEYS.size() else ""
		var item := Label.new()
		item.add_theme_font_size_override("font_size", 13)
		item.text = "[%s] %s" % [key_str, str(GUIDE_ITEMS[i].get("title", ""))]
		if i == _guide_item:
			item.add_theme_color_override("font_color", UIStyleFactory.COLOR_TAB_ACTIVE)
		else:
			item.add_theme_color_override("font_color", UIStyleFactory.COLOR_ITEM_IDLE)
		picker.add_child(item)

	_body_box.add_child(_make_spacer(6))

	var section_id := str(GUIDE_ITEMS[_guide_item].get("id", ""))
	match section_id:
		"loop":     _guide_core_loop()
		"tools":    _guide_four_tools()
		"biomes":   _guide_biomes_economy()
		"try":      _guide_things_to_try()
		"ref":      _guide_quick_reference()
		"verbs":    _guide_verbs_table()
		"glossary": _guide_glossary()

func _guide_core_loop() -> void:
	_body_box.add_child(_make_section_header("the core loop: R · E · Q"))
	_body_box.add_child(_make_body("Press 8 to enter the Ace frame, then:"))
	_body_box.add_child(_make_action_row("R", "Plant", "Invest energy — jolt population toward the north pole (screw in)."))
	_body_box.add_child(_make_action_row("E", "Measure", "Read the price — collapse the quantum state (Born rule)."))
	_body_box.add_child(_make_action_row("Q", "Harvest", "Extract energy — reward = surprisal −kT·log p, rare pays more (screw out)."))
	_body_box.add_child(_make_body(
		"R screws in (plant = invest energy), E reads the price (measure), Q screws out (harvest = extract). "
		+ "Selecting a plot auto-binds its terminal — no separate Explore. Same direction in every tool."))

func _guide_four_tools() -> void:
	_body_box.add_child(_make_section_header("the seven archetype frames (4-0)"))
	_body_box.add_child(_make_action_row("4", "Spark",     "Lindbladian jolt — SEALED while the enclave holds (nothing pumps or drains in v0; Act 2 opens it)."))
	_body_box.add_child(_make_action_row("5", "Icon",      "Inject a dual-emoji qubit from the neighborhood's installed signature."))
	_body_box.add_child(_make_action_row("6", "Merchant", "Faction contracts (energy dyad): Q=Sell, E=Read Price, R=Buy, F=Tip. Price = −kT·log p."))
	_body_box.add_child(_make_action_row("7", "Captain",   "Biome lifecycle: Q=cull, R=discover."))
	_body_box.add_child(_make_action_row("8", "Ace", "Energy dyad: Q=harvest (extract), E=measure (price), R=plant (invest)."))
	_body_box.add_child(_make_action_row("9", "Operator",  "Gate building: Q=break, E=inspect, R=gate."))
	_body_box.add_child(_make_action_row("0", "Druid",     "Unitary rotations + Hadamard. 1/2/3 = X / Y / Z."))
	_body_box.add_child(_make_spacer(4))
	_body_box.add_child(_make_body(
		"Re-press the active hat to toggle back to Ace (default toolkit). "
		+ "Hold Shift+Q/E/R to apply the verb to every valid plot at once."))

func _guide_biomes_economy() -> void:
	_body_box.add_child(_make_section_header("biomes"))
	_body_box.add_child(_make_body(
		"Up to 6 biome slots on TYUIOP. Each biome carries its own physics — the Hamiltonian "
		+ "couplings run live; its webway (the authored Lindblad food web) is sealed while the "
		+ "enclave holds. A neighborhood is an icon signature plus a biome. Plots live on GHJKL; "
		+ "(left → right). The ' key toggles select-all."))
	_body_box.add_child(_make_spacer(4))
	_body_box.add_child(_make_section_header("economy"))
	_body_box.add_child(_make_body(
		"Harvest pays the surprisal energy of the outcome: reward = −kT·log p (rare outcomes "
		+ "pay more; kT is the biome's market temperature). Learning icon via quests grants "
		+ "up to 4× purity bonus on seasonal reaps."))

func _guide_things_to_try() -> void:
	_body_box.add_child(_make_section_header("a few experiments"))
	_body_box.add_child(_make_body("Make a Bell pair: Operator (9) → pick two plots → R. Then Ace (8) → measure one, watch the other collapse."))
	_body_box.add_child(_make_body("Hadamard everything: Druid (0) → E → measure. Repeat — watch 50/50 emerge."))
	_body_box.add_child(_make_body("Open N: apply a Hadamard, watch off-diagonal terms appear; measure, watch them vanish."))
	_body_box.add_child(_make_body("Build a GHZ: entangle A↔B, then B↔C. Measure any one — all collapse."))
	_body_box.add_child(_make_body("Farm a Berry loop: track a qubit, steer it in a closed circle on its sphere, and when it ripens (Ω past 2π) incorporate the axis — a faction will mark the moment."))
	_body_box.add_child(_make_body("Read a faction's mood: quest board (C) → E on any offer. Resonance is how the biome's live state sits with their axioms — court them by steering it."))
	_body_box.add_child(_make_body("Watch yourself: M → Eigenstate shows You · Tr(ρ²). Idle five minutes and the fog reclaims you; act, and your identity resolves."))
	_body_box.add_child(_make_body("See the loom: M → Graph → drill into a biome. Gold edges are the entanglement you wove; dark orange channels are the sealed webway, waiting for Act 2."))
	_body_box.add_child(_make_body("Read the compass: same drill-down — 🧭 shows the biome's deep state and its gap. Evolve all you like, the depths never move; measure, and they jump. That's the campaign's second invariant."))
	_body_box.add_child(_make_body("Spell a braid word: Hadamard then CNOT weaves a thread; CNOT then Hadamard weaves nothing. Same chores, opposite worlds — order is the point."))

func _guide_quick_reference() -> void:
	_body_box.add_child(_make_section_header("verbs"))
	_body_box.add_child(_make_action_row("Q", "Screw out",        "Retreat / shallower / safe variant / quit"))
	_body_box.add_child(_make_action_row("E", "Pause + inspect", "Snapshot state; sim pauses as side-effect"))
	_body_box.add_child(_make_action_row("R", "Screw in",        "Commit / deeper / advance / resume"))
	_body_box.add_child(_make_action_row("E ↓", "Drill in",     "Hadamard / Measure / open detail / open submenu"))
	_body_box.add_child(_make_action_row("F ↑", "Flatten",      "Collapses whatever E opened. No-op if nothing is open."))
	_body_box.add_child(_make_action_row("Tab", "Cycle mode",   "Advance the current frame's sub-mode (was F)"))
	_body_box.add_child(_make_action_row("1/2/3", "Pick sub-mode", "Direct sub-mode select within current frame"))
	_body_box.add_child(_make_action_row("4-0", "Frame hat",    "Pick archetype frame; re-press toggles to Ace"))
	_body_box.add_child(_make_action_row("WASD", "Spin cylinder", "W/S rotate between rings (frame/biome/plot/surface), A/D step around the active ring"))
	_body_box.add_child(_make_spacer(4))
	_body_box.add_child(_make_section_header("rows"))
	_body_box.add_child(_make_action_row("4-0",         "Frames",  ""))
	_body_box.add_child(_make_action_row("T-Y-U-I-O-P", "Biomes",  ""))
	_body_box.add_child(_make_action_row("G-H-J-K-L-;", "Plots",   ""))
	_body_box.add_child(_make_action_row("Z-X-C-V-B-N-M", "Surfaces", "Top-level menus (system / self / quests / atlas / biome / network / map)"))
	_body_box.add_child(_make_action_row("'",            "Bulk plots","Toggle: check all plots in active biome, or clear if any are checked"))
	_body_box.add_child(_make_action_row("Shift+QER",    "Bulk",    "apply to all valid plots"))

# Verbs reference — moved here from EscapeMenu's old Verbs tab. Reads the
# 7-hat × QERF table out of ToolConfig so it stays in sync with whatever the
# active toolkit actually does.
const _VERBS_HAT_KEYS := ["4", "5", "6", "7", "8", "9", "0"]
const _VERBS_FRAME_ORDER := ["spark", "icon", "merchant", "captain", "ace", "operator", "druid"]

func _guide_verbs_table() -> void:
	_body_box.add_child(_make_section_header("hats and verbs"))
	_body_box.add_child(_make_body(
		"Q/E/R/F per hat. Reference only — the verbs execute on the gameplay "
		+ "surface, not here. 1/2/3 sub-modes (where shown) remap Q/R."))
	_body_box.add_child(_make_spacer(4))

	for i in range(_VERBS_FRAME_ORDER.size()):
		var frame_name: String = _VERBS_FRAME_ORDER[i]
		var hat_key: String = _VERBS_HAT_KEYS[i]
		var frame_def: Dictionary = ToolConfig.get_frame(frame_name)
		var label_name: String = str(frame_def.get("name", frame_name))
		_body_box.add_child(_make_section_header("[%s] %s" % [hat_key, label_name]))

		var mode_name: String = ToolConfig.get_frame_mode_name(frame_name)
		var mode_actions: Dictionary = frame_def.get("actions", {}).get(mode_name, {})
		for key in ["Q", "E", "R", "F"]:
			var info: Dictionary = mode_actions.get(key, {})
			var verb_label: String = str(info.get("label", ""))
			var hint: String = str(info.get("hint", ""))
			if verb_label == "" or verb_label == "-":
				continue
			_body_box.add_child(_make_action_row(key, verb_label, hint))

		var modes: Array = frame_def.get("modes", [])
		if modes.size() > 1:
			_body_box.add_child(_make_muted_label(
				"sub-modes: %s   ·   1-%d direct-pick" % [
					" / ".join(modes), modes.size()], 11))
		_body_box.add_child(_make_spacer(4))

func _guide_glossary() -> void:
	if _glossary_reg == null:
		_glossary_reg = GlossaryRegistry.new()
		_glossary_reg.load_all()
	_body_box.add_child(_make_section_header("glossary"))
	_body_box.add_child(_make_body("Locked vocabulary — one source of truth."))
	_body_box.add_child(_make_spacer(4))
	_body_box.add_child(_make_section_header("canonical terms"))
	_body_box.add_child(_make_body("The core nouns used across X."))
	if _glossary_reg.size() == 0:
		_body_box.add_child(_make_body("[no glossary terms loaded]"))
		return
	_render_glossary_terms(GLOSSARY_CANONICAL_TERMS, false)
	_body_box.add_child(_make_spacer(4))
	_body_box.add_child(_make_section_header("full glossary"))
	_body_box.add_child(_make_body("Alphabetical reference for the rest of the terms."))
	_body_box.add_child(_make_spacer(4))
	_render_glossary_terms(_glossary_reg.all_terms_sorted(), true)

func _render_glossary_terms(terms: Array, include_related: bool) -> void:
	for term_name in terms:
		var entry := _glossary_reg.get_term(str(term_name))
		if entry.is_empty():
			continue
		var short_def := str(entry.get("short_def", ""))
		_body_box.add_child(_make_kv_row(str(term_name), short_def))
		if include_related:
			var related: Array = entry.get("related", [])
			if not related.is_empty():
				_body_box.add_child(_make_muted_label(
					"→  " + "  ·  ".join(related), 11))
		_body_box.add_child(_make_spacer(2))

# =============================================================================
# HELPERS
# =============================================================================

func _make_section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text.to_upper()
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", COLOR_HEADER)
	return lbl

func _make_kv_row(key: String, value: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var k := Label.new()
	k.text = key
	k.add_theme_font_size_override("font_size", 12)
	k.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	k.custom_minimum_size = Vector2(140, 0)
	row.add_child(k)
	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 13)
	v.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(v)
	return row

func _make_action_row(key_text: String, label: String, hint: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var k := Label.new()
	k.text = "[%s]" % key_text
	k.add_theme_font_size_override("font_size", 13)
	k.add_theme_color_override("font_color", UIStyleFactory.COLOR_KEY_CHIP)
	k.custom_minimum_size = Vector2(70, 0)
	row.add_child(k)
	var n := Label.new()
	n.text = label
	n.add_theme_font_size_override("font_size", 13)
	n.add_theme_color_override("font_color", UIStyleFactory.COLOR_VERB_ACTIVE)
	n.custom_minimum_size = Vector2(150, 0)
	row.add_child(n)
	if hint != "":
		var d := Label.new()
		d.text = hint
		d.add_theme_font_size_override("font_size", 12)
		d.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(d)
	return row

func _make_key_chip(key_text: String) -> Label:
	var lbl := Label.new()
	lbl.text = "[%s]" % key_text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_KEY_CHIP)
	lbl.custom_minimum_size = Vector2(32, 0)
	return lbl

func _make_muted_label(text: String, icon_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", icon_size)
	lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl

func _make_body(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl

func _make_spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

# =============================================================================
# CHATTER BUBBLE (Z Story page)
# =============================================================================

const CHATTER_EMOJI_SIZE_MIN := 14
const CHATTER_EMOJI_SIZE_MAX := 24
const CHATTER_EMOJI_ALPHA_MIN := 0.45
const CHATTER_EMOJI_ALPHA_MAX := 1.0
const CHATTER_MAX_CONNECTIONS := 6

## Render one chatter event as a PanelContainer "bubble".
##   header: speaker chip (left) + topic biome chip (right)
##   body: emojis sized + alpha-modulated by per-qubit measurement marginal
##   footer: connection chips (other live biomes the speaker is native to)
func _make_chatter_bubble(ev: Dictionary, selected: bool, key_str: String) -> PanelContainer:
	var bubble := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.16, 0.88)
	sb.border_color = UIStyleFactory.COLOR_TAB_ACTIVE if selected else Color(0.25, 0.30, 0.38, 0.9)
	sb.set_border_width_all(2 if selected else 1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	bubble.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	bubble.add_child(vbox)

	# === HEADER: [G] 🌿 Hearth Keepers              [🌳 StarterForest] ===
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var key_label := Label.new()
	key_label.text = "[%s]" % key_str
	key_label.add_theme_font_size_override("font_size", 11)
	key_label.add_theme_color_override("font_color", UIStyleFactory.COLOR_KEY_CHIP)
	key_label.custom_minimum_size = Vector2(28, 0)
	header.add_child(key_label)

	var speaker_label := Label.new()
	speaker_label.text = "%s %s" % [str(ev.get("speaker", "")), str(ev.get("faction", ""))]
	speaker_label.add_theme_font_size_override("font_size", 13)
	speaker_label.add_theme_color_override("font_color",
		UIStyleFactory.COLOR_TAB_ACTIVE if selected else UIStyleFactory.COLOR_VALUE)
	header.add_child(speaker_label)

	var spacer_h := Control.new()
	spacer_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer_h)

	var biome_name := str(ev.get("biome", ""))
	if biome_name != "":
		header.add_child(_make_story_chip("[%s]" % biome_name, COLOR_HEADER))
	vbox.add_child(header)

	# === BODY: emojis sized + tinted by marginal at the measured pole ===
	var body := HBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 12)
	var emojis: Array = ev.get("emojis", [])
	var marginals: Array = ev.get("marginals", [])
	for j in range(emojis.size()):
		var emoji := str(emojis[j])
		var m: float = float(marginals[j]) if j < marginals.size() else 0.5
		var size_px: int = int(round(lerp(float(CHATTER_EMOJI_SIZE_MIN), float(CHATTER_EMOJI_SIZE_MAX), clampf(m, 0.0, 1.0))))
		var alpha: float = lerp(CHATTER_EMOJI_ALPHA_MIN, CHATTER_EMOJI_ALPHA_MAX, clampf(m, 0.0, 1.0))
		var atom := Label.new()
		atom.text = emoji
		atom.add_theme_font_size_override("font_size", size_px)
		atom.modulate = Color(1.0, 1.0, 1.0, alpha)
		body.add_child(atom)
	vbox.add_child(body)

	# === FOOTER: connection chips ===
	var connections: Array = ev.get("connections", [])
	if not connections.is_empty():
		var footer := HBoxContainer.new()
		footer.add_theme_constant_override("separation", 6)
		var also_label := Label.new()
		also_label.text = "also:"
		also_label.add_theme_font_size_override("font_size", 10)
		also_label.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
		footer.add_child(also_label)
		var visible_count := mini(connections.size(), CHATTER_MAX_CONNECTIONS)
		for ci in range(visible_count):
			footer.add_child(_make_story_chip(str(connections[ci]), UIStyleFactory.COLOR_MUTED))
		if connections.size() > visible_count:
			var more_label := Label.new()
			more_label.text = "+%d" % (connections.size() - visible_count)
			more_label.add_theme_font_size_override("font_size", 10)
			more_label.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
			footer.add_child(more_label)
		vbox.add_child(footer)

	return bubble

## Small chip helper — used for biome / connection labels in chatter bubbles.
func _make_story_chip(text: String, color: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.20, 0.26, 0.85)
	sb.border_color = Color(0.28, 0.32, 0.40, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", color)
	chip.add_child(lbl)
	return chip

# =============================================================================
# QERF DISPATCH
# =============================================================================

# =============================================================================
# INSPECT TEXT — what E pops up as a toast (OverlayBase calls get_inspect_text).
# =============================================================================

func get_inspect_text() -> String:
	match _current_tab:
		Tab.STORY:
			return _story_inspect_text()
		Tab.SELF:
			return _self_inspect_text()
		_:
			return ""

func _story_inspect_text() -> String:
	# Show the most recent event from PlayerEventLog at full message detail.
	var player_event_log = get_node_or_null("/root/PlayerEventLog")
	var recent: Array = player_event_log.get_recent(1, 1) if player_event_log and player_event_log.has_method("get_recent") else []
	if recent.is_empty():
		return ""
	var ev: Dictionary = recent[0]
	var msg: String = str(ev.get("message", ""))
	var path: String = str(ev.get("path", ""))
	if path != "":
		msg += "\n→ open via %s" % path
	return msg

func _self_inspect_text() -> String:
	# When Self tab is showing, E pops up the spotlight faction's nature card
	# in toast form (useful when the spotlight panel is below-fold on the
	# scroll container).
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm == null or not "faction_standings" in farm:
		return ""
	var standings: Dictionary = farm.faction_standings
	var spot: String = _top_other_faction_by_magnitude(standings)
	if spot == "":
		return ""
	var card: Dictionary = FactionCard.gather(spot, farm)
	if not bool(card.get("present", false)):
		return ""
	var lines: Array[String] = []
	lines.append("%s · standing %+.2f" % [spot, float(card.get("standing", 0.0))])
	var sig: Array = card.get("signature", [])
	if not sig.is_empty():
		lines.append("speaks: " + " ".join(sig))
	var bio: Array = card.get("biomes_of_presence", [])
	if not bio.is_empty():
		lines.append("biomes: " + ", ".join(bio))
	return "\n".join(lines)

func _on_action_q() -> void:
	match _current_tab:
		Tab.BALANCE: _nudge_balance_setting(-1)  # Q = − value
		Tab.STORY:   _story_apply_verb("R")  # Q label "Harmonize" → engine R (player aligns toward target)
		_: pass

func _on_action_e() -> void:
	match _current_tab:
		Tab.BALANCE:
			_reset_balance_setting()  # E = reset selected tunable to default
		Tab.STORY:
			_story_inspect_open = not _story_inspect_open  # E = pause + inspect (toggle panel)
			_refresh_body()
		_:
			pass

func _on_action_r() -> void:
	match _current_tab:
		Tab.BALANCE: _nudge_balance_setting(1)  # R = + value
		Tab.STORY:   _story_apply_verb("E")  # R label "Express" → engine E (strong commit / mass shift)
		Tab.SELF:
			# R = screw in = commit: assign cursor's icon to the selected icon slot.
			var farm = InstrumentLocator.resolve_active_farm(self)
			if farm == null:
				return
			var icons: Array = farm.get_known_icons()
			if icons.is_empty() or _self_picker_icon < 0 or _self_picker_icon >= icons.size():
				return
			var instr = InstrumentLocator.resolve_quantum_instrument(self)
			if instr and instr.has_method("action_set_active_icon_slot"):
				instr.action_set_active_icon_slot(_self_picker_slot, _self_picker_icon)
				_refresh_body()
		_: pass

func _on_action_f() -> void:
	match _current_tab:
		Tab.STORY:
			# F = play + flatten the inspect panel (PlayerShell handles global play).
			if _story_inspect_open:
				_story_inspect_open = false
				_refresh_body()
		_: pass

func _story_apply_verb(verb: String) -> void:
	var engine = _story_engine()
	if engine == null:
		return
	var chatter: Array = engine.recent_chatter(6)
	if chatter.is_empty():
		return
	var idx := clampi(_story_chatter_idx, 0, chatter.size() - 1)
	var ev: Dictionary = chatter[idx]
	var emojis: Array = ev.get("emojis", [])
	var faction: String = str(ev.get("faction", ""))
	var topic_node: String = str(ev.get("topic_node", ""))
	engine.express_icon_on_chatter(_story_icon_idx, verb, emojis, faction, topic_node)
	_refresh_body()

# =============================================================================
# SURFACE WIRING
# =============================================================================

func _show_tab(tab: int) -> void:
	if _current_tab == tab and frame_id == TAB_TO_FRAME.get(tab, frame_id):
		return
	_current_tab = tab
	var target_frame: String = TAB_TO_FRAME.get(tab, FRAME_SELF)
	if frame_id != target_frame:
		var prev := frame_id
		frame_id = target_frame
		frame_changed.emit(target_frame, prev)
		_emit_snapshot()
		if tab == Tab.BALANCE:
			_refresh_balance_snapshot()
		if tab == Tab.STORY:
			# Reset edge cursor when entering Story; ui_focus stays as last override (or argmax).
			_story_edge_idx = 0
	_render_all()

func _on_frame_changed(new_frame_id: String, _prev_frame_id: String) -> void:
	var target_tab: int = FRAME_TO_TAB.get(new_frame_id, Tab.SELF)
	if _current_tab != target_tab:
		_current_tab = target_tab
		if _current_tab == Tab.BALANCE:
			_refresh_balance_snapshot()
		_render_all()

# =============================================================================
# INPUT
# =============================================================================

func _on_unhandled_key(keycode: int, _event: InputEvent) -> bool:
	if TAB_BY_KEYCODE.has(keycode):
		_show_tab(int(TAB_BY_KEYCODE[keycode]))
		return true
	if ITEM_BY_KEYCODE.has(keycode):
		_select_item_in_tab(int(ITEM_BY_KEYCODE[keycode]))
		return true
	# Icon slot selection (1/2/3) on Story tab — the player's 3 expression icons.
	if _current_tab == Tab.STORY:
		match keycode:
			KEY_1:
				_story_icon_idx = 0
				_refresh_body()
				return true
			KEY_2:
				_story_icon_idx = 1
				_refresh_body()
				return true
			KEY_3:
				_story_icon_idx = 2
				_refresh_body()
				return true
	# Icon slot selection (1/2/3) on Self tab — picker target slot.
	if _current_tab == Tab.SELF:
		match keycode:
			KEY_1:
				_self_picker_slot = 0
				_refresh_body()
				return true
			KEY_2:
				_self_picker_slot = 1
				_refresh_body()
				return true
			KEY_3:
				_self_picker_slot = 2
				_refresh_body()
				return true
	for kc in ITEM_BY_KEYCODE.keys():
		if kc == keycode:
			return true
	for kc in TAB_BY_KEYCODE.keys():
		if kc == keycode:
			return true
	return false

func _select_item_in_tab(slot: int) -> void:
	match _current_tab:
		Tab.BALANCE:
			_ensure_balance_settings_loaded()
			var page_size := ITEM_KEYS.size()
			var global_idx := _balance_setting_page * page_size + slot
			if global_idx < _balance_settings.size() and _balance_setting_idx != global_idx:
				_balance_setting_idx = global_idx
				_refresh_body()
		Tab.GUIDE:
			if slot < GUIDE_ITEMS.size() and _guide_item != slot:
				_guide_item = slot
				_refresh_body()
		Tab.STORY:
			# GHJKL; selects a chatter line — the QERF target.
			var engine = _story_engine()
			if engine == null:
				return
			var chatter: Array = engine.recent_chatter(6)
			if slot < chatter.size() and _story_chatter_idx != slot:
				_story_chatter_idx = slot
				_refresh_body()
		Tab.SELF:
			# GHJKL; moves the picker cursor over visible known_icons.
			var farm = InstrumentLocator.resolve_active_farm(self)
			if farm == null:
				return
			var icons: Array = farm.get_known_icons()
			if icons.is_empty():
				return
			var page_size := ITEM_KEYS.size()
			var target := _self_picker_page * page_size + slot
			if target < icons.size() and _self_picker_icon != target:
				_self_picker_icon = target
				_refresh_body()
		_:
			pass

func _on_navigate(direction: Vector2i) -> void:
	# Per KEYBOARD_GRAMMAR.md "Selection layer":
	#   W/S = step OUTER (tabs)
	#   A/D = step INNER (items / pages within active tab)
	if direction.y != 0:
		var n := TAB_ROW.size()
		_show_tab(wrapi(_current_tab + signi(direction.y), 0, n))
		return
	if direction.x == 0:
		return
	var step: int = signi(direction.x)
	match _current_tab:
		Tab.STORY:
			# Story crawl walks parent/child along graph topology.
			_story_crawl(step)
		Tab.SELF:
			# Page through known_icons (6 per page).
			var farm = InstrumentLocator.resolve_active_farm(self)
			if farm == null:
				return
			var icons: Array = farm.get_known_icons()
			if icons.is_empty():
				return
			var page_size := ITEM_KEYS.size()
			var max_page: int = max(0, int(float(icons.size() - 1) / float(page_size)))
			_self_picker_page = clampi(_self_picker_page + step, 0, max_page)
			_self_picker_icon = clampi(_self_picker_icon, _self_picker_page * page_size, mini((_self_picker_page + 1) * page_size, icons.size()) - 1)
			_refresh_body()
		Tab.BALANCE:
			# A/D pages the settings list when there are more entries than
			# GHJKL; can show in one row.
			_ensure_balance_settings_loaded()
			var page_size: int = ITEM_KEYS.size()
			var max_page: int = max(0, int(float(_balance_settings.size() - 1) / float(page_size)))
			_balance_setting_page = clampi(_balance_setting_page + step, 0, max_page)
			_balance_setting_idx = clampi(_balance_setting_idx,
				_balance_setting_page * page_size,
				mini((_balance_setting_page + 1) * page_size, _balance_settings.size()) - 1)
			_refresh_body()
		Tab.GUIDE:
			_guide_item = wrapi(_guide_item + step, 0, GUIDE_ITEMS.size())
			_refresh_body()
		_:
			pass

# =============================================================================
# BALANCE DATA
# =============================================================================

func _cycle_balance_action(step: int) -> void:
	if _balance_action_keys.is_empty():
		return
	_balance_action_idx = posmod(_balance_action_idx + step, _balance_action_keys.size())
	_refresh_body()

func _cycle_balance_biome(step: int) -> void:
	if _balance_biomes.is_empty():
		return
	_balance_biome_idx = posmod(_balance_biome_idx + step, _balance_biomes.size())
	_refresh_balance_projection()
	_refresh_body()

# =============================================================================
# BALANCE — settings tunables (Q − value / R + value / E reset)
# =============================================================================

# Static catalog of tunables Balance exposes. value_path is read/written
# through GameState.balance_workbench_config (defaults from BalanceConfig).
# music_volume rides alongside as a non-config tunable handled directly via
# MusicManager.
# The audio row isn't a balance-config knob (no value_path); kept here. Every
# economy/physics knob is DERIVED from BalanceConfig.TUNABLES via board_specs() — the
# single source of truth — so the board never duplicates defaults/metadata. open_only
# rows (Lindbladian-only) are filtered out in the closed system.
const _MUSIC_ROW := {"id": "music_volume", "label": "Music volume", "category": "Audio", "value_path": [], "kind": "music_pct", "step": 5, "min": 0, "max": 100, "default": 70}

func _ensure_balance_settings_loaded() -> void:
	if _balance_settings.is_empty():
		_balance_settings = [_MUSIC_ROW.duplicate(true)]
		var closed: bool = not BalanceConfig.dissipative_enabled()
		for d in BalanceConfig.board_specs():
			if closed and bool(d.get("open_only", false)):
				continue  # dead knob in the closed system
			_balance_settings.append(d.duplicate(true))
	_balance_setting_idx = clampi(_balance_setting_idx, 0, max(0, _balance_settings.size() - 1))
	var page_size: int = ITEM_KEYS.size()
	var max_page: int = max(0, int(float(_balance_settings.size() - 1) / float(page_size)))
	_balance_setting_page = clampi(_balance_setting_page, 0, max_page)

func _balance_setting_value(setting: Dictionary) -> Variant:
	var kind: String = str(setting.get("kind", "float"))
	if kind == "music_pct":
		var music = get_node_or_null("/root/MusicManager")
		if music and music.has_method("get_volume"):
			return int(round(float(music.get_volume()) * 100.0))
		return int(setting.get("default", 70))
	var path: Array = setting.get("value_path", [])
	if path.is_empty():
		return setting.get("default", 0.0)
	var gsm = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if gsm and "balance_workbench_config" in gsm:
		var cfg = gsm.balance_workbench_config
		if typeof(cfg) == TYPE_DICTIONARY:
			var node = cfg
			for key in path:
				if typeof(node) != TYPE_DICTIONARY or not node.has(key):
					return setting.get("default", 0.0)
				node = node[key]
			return node
	return setting.get("default", 0.0)

func _balance_setting_set_value(setting: Dictionary, value: Variant) -> void:
	var kind: String = str(setting.get("kind", "float"))
	if kind == "music_pct":
		var music = get_node_or_null("/root/MusicManager")
		if music and music.has_method("set_volume"):
			music.set_volume(clampf(float(value) / 100.0, 0.0, 1.0))
		return
	var path: Array = setting.get("value_path", [])
	if path.is_empty():
		return
	var gsm = get_node_or_null("/root/GameStateManager")
	if not gsm or not ("current_state" in gsm) or not gsm.current_state:
		return
	if gsm.current_state.has_method("set_balance_config_value"):
		gsm.current_state.set_balance_config_value(path, value)
	# Apply LIVE to the running economy too — not just the saved config — so board edits
	# take effect immediately. Builds the same nested patch the rig balance_patch uses and
	# routes it through BalanceService.apply_patch → FarmEconomy overrides.
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm:
		var patch: Dictionary = {}
		var cursor: Dictionary = patch
		for i in range(path.size() - 1):
			cursor[str(path[i])] = {}
			cursor = cursor[str(path[i])]
		cursor[str(path[path.size() - 1])] = value
		BalanceService.apply_patch(farm, patch)

func _balance_setting_format(setting: Dictionary) -> String:
	var kind: String = str(setting.get("kind", "float"))
	var v = _balance_setting_value(setting)
	match kind:
		"music_pct":
			return "%d%%" % int(v)
		"int":
			return "%d" % int(v)
		"float":
			return "%.2f" % float(v)
		_:
			return str(v)

func _nudge_balance_setting(direction: int) -> void:
	_ensure_balance_settings_loaded()
	if _balance_settings.is_empty():
		return
	var setting: Dictionary = _balance_settings[_balance_setting_idx]
	var kind: String = str(setting.get("kind", "float"))
	var step: float = float(setting.get("step", 1.0))
	var lo = setting.get("min", 0.0)
	var hi = setting.get("max", 100.0)
	var current = _balance_setting_value(setting)
	var next
	match kind:
		"music_pct", "int":
			next = clampi(int(current) + direction * int(step), int(lo), int(hi))
		_:
			next = clampf(float(current) + direction * step, float(lo), float(hi))
	_balance_setting_set_value(setting, next)
	_refresh_body()

func _reset_balance_setting() -> void:
	_ensure_balance_settings_loaded()
	if _balance_settings.is_empty():
		return
	var setting: Dictionary = _balance_settings[_balance_setting_idx]
	_balance_setting_set_value(setting, setting.get("default", 0.0))
	_refresh_body()

func _refresh_balance_snapshot() -> void:
	var farm = InstrumentLocator.resolve_active_farm(self)
	if not farm:
		_balance_snapshot = {}
		_balance_action_keys = []
		_balance_biomes = []
		_balance_projection = {}
		return
	_balance_snapshot = BalanceService.get_snapshot(farm)
	var keys: Array[String] = []
	var costs: Dictionary = _balance_snapshot.get("action_costs", {})
	for k in costs.keys():
		keys.append(str(k))
	keys.sort()
	_balance_action_keys = keys
	if _balance_action_idx >= _balance_action_keys.size():
		_balance_action_idx = 0

	_balance_biomes = []
	if "grid" in farm and farm.grid and farm.grid.has_method("get_biome_names"):
		for n in farm.grid.get_biome_names():
			_balance_biomes.append(str(n))
		_balance_biomes.sort()
	if _balance_biome_idx >= _balance_biomes.size():
		_balance_biome_idx = 0
	_refresh_balance_projection()

func _refresh_balance_projection() -> void:
	_balance_projection = {}
	if _balance_biomes.is_empty():
		return
	var biome_name: String = _balance_biomes[_balance_biome_idx]
	var inst = InstrumentLocator.resolve_quantum_instrument(self)
	if not inst:
		return
	if inst.has_method("recommend_timescale"):
		_balance_projection = inst.recommend_timescale(biome_name, 8)
	if _balance_projection.is_empty() and inst.has_method("get_timescale_projection"):
		_balance_projection = inst.get_timescale_projection(biome_name, 8)

func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "(none)"
	var parts: Array[String] = []
	var keys = cost.keys()
	keys.sort()
	for emoji in keys:
		parts.append("%s%d" % [str(emoji), int(cost[emoji])])
	return " ".join(parts)

# =============================================================================
# SURFACE CONTRACT
# =============================================================================

func get_visible_data() -> Dictionary:
	var payload: Dictionary = {
		"tab": _current_tab,
		"frame_label": str(TAB_ROW[_current_tab].get("name", "")) if _current_tab < TAB_ROW.size() else "",
		"guide_section": str(GUIDE_ITEMS[_guide_item].get("id", "")) if _current_tab == Tab.GUIDE else "",
	}
	if _current_tab == Tab.BALANCE and not _balance_snapshot.is_empty():
		payload["balance"] = {
			"profile_id": _balance_snapshot.get("profile_id", ""),
			"selected_action": _balance_action_keys[_balance_action_idx] if _balance_action_idx < _balance_action_keys.size() else "",
			"selected_biome": _balance_biomes[_balance_biome_idx] if _balance_biome_idx < _balance_biomes.size() else "",
			"projection_ok": bool(_balance_projection.get("ok", false)),
		}
	return payload

func get_transitions() -> Array:
	return [
		{"surface_id": "farm", "reason": "return to invoking surface"},
	]
