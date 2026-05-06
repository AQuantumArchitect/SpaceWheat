class_name ControlsOverlay
extends "res://UI/Core/Surface.gd"

## Z — self / story / sociolite mirror.
## The most personal overlay: the player looking inward, with experimental
## chatter and faction-term sculpting on the chatter page.
##
## Keyboard grammar matches the rest of the game (and X):
##   TYUIO  = tabs (Self / Story / Verbs / Chatter / Guide), top row
##   GHJKL; = items within the active tab, same row as plot slots
##   [ / ]  = cycle tabs (surface frame cycle)
##   , / .  = cycle top-level menus
##   Q ←   = prev item / retreat (Chatter: prev action)
##   R →   = next item / advance (Chatter: next action)
##   E ↓   = inspect / refresh
##   F ↑   = flatten: collapses whatever E opened. No open panel → no-op.
##            F is never "back" and never navigation — those belong to ESC / [ ].
##   W/S    = navigate items within the active tab (Chatter: cycle biome)
##   Z/ESC  = close
##
## frame_ids = [self, story, verbs, balance, guide] — one per tab; the
## balance frame currently presents the experimental chatter workbench.

const MenuRegistry    = preload("res://UI/Core/MenuRegistry.gd")
const ToolConfig      = preload("res://Core/GameState/ToolConfig.gd")
const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")
const BalanceService  = preload("res://Core/GameMechanics/BalanceService.gd")
const FactionAxes     = preload("res://Core/Factions/FactionAxes.gd")
const FactionRegistry = preload("res://Core/Factions/FactionRegistry.gd")
const IconLexicon     = preload("res://Core/Factions/IconLexicon.gd")

# =============================================================================
# TABS / FRAMES
# =============================================================================

enum Tab { SELF, STORY, VERBS, BALANCE, GUIDE }

const TAB_ROW := [
	{"key": "T", "tab": Tab.SELF,    "name": "Self",    "frame": "self"},
	{"key": "Y", "tab": Tab.STORY,   "name": "Story",   "frame": "story"},
	{"key": "U", "tab": Tab.VERBS,   "name": "Verbs",   "frame": "verbs"},
	{"key": "I", "tab": Tab.BALANCE, "name": "Chatter", "frame": "balance"},
	{"key": "O", "tab": Tab.GUIDE,   "name": "Guide",   "frame": "guide"},
]

const TAB_BY_KEYCODE := {
	KEY_T: Tab.SELF,
	KEY_Y: Tab.STORY,
	KEY_U: Tab.VERBS,
	KEY_I: Tab.BALANCE,
	KEY_O: Tab.GUIDE,
}

# Left-to-right slot keys (same convention as X).
const ITEM_KEYS := ["G", "H", "J", "K", "L", ";"]
const ITEM_BY_KEYCODE := {
	KEY_G: 0,
	KEY_H: 1,
	KEY_J: 2,
	KEY_K: 3,
	KEY_L: 4,
	KEY_SEMICOLON: 5,
}

const FRAME_SELF    := "self"
const FRAME_STORY   := "story"
const FRAME_VERBS   := "verbs"
const FRAME_BALANCE := "balance"
const FRAME_GUIDE   := "guide"

const TAB_TO_FRAME := {
	Tab.SELF:    FRAME_SELF,
	Tab.STORY:   FRAME_STORY,
	Tab.VERBS:   FRAME_VERBS,
	Tab.BALANCE: FRAME_BALANCE,
	Tab.GUIDE:   FRAME_GUIDE,
}
const FRAME_TO_TAB := {
	FRAME_SELF:    Tab.SELF,
	FRAME_STORY:   Tab.STORY,
	FRAME_VERBS:   Tab.VERBS,
	FRAME_BALANCE: Tab.BALANCE,
	FRAME_GUIDE:   Tab.GUIDE,
}

# Verbs tab: 7 archetype frames, GHJKL; selects which one (matches hat order).
const VERBS_ITEMS := ["Spark", "Icon", "Merchant", "Captain", "Ace", "Operator", "Druid"]
const VERBS_FRAME_ORDER: Array = [
	"spark", "icon", "merchant", "captain", "ace", "operator", "druid",
]
const VERBS_HAT_KEYS: Array = ["4", "5", "6", "7", "8", "9", "0"]

# Guide tab: 5 sections, GHJKL selects which.
const GUIDE_ITEMS := [
	{"id": "loop",   "title": "Core Loop"},
	{"id": "tools",  "title": "Four Tools"},
	{"id": "biomes", "title": "Biomes & Economy"},
	{"id": "try",    "title": "Things to Try"},
	{"id": "ref",    "title": "Quick Reference"},
]

# =============================================================================
# COLORS
# =============================================================================

const COLOR_TAB_ACTIVE  := Color(1.0, 0.9, 0.3, 1.0)
const COLOR_TAB_IDLE    := Color(0.6, 0.7, 0.85, 0.85)
const COLOR_ITEM_ACTIVE := Color(1.0, 0.9, 0.3, 1.0)
const COLOR_ITEM_IDLE   := Color(0.75, 0.82, 0.92, 0.9)
const COLOR_KEY_CHIP    := Color(0.55, 0.85, 1.0, 0.95)
const COLOR_MUTED       := Color(0.55, 0.6, 0.7, 0.85)
const COLOR_VALUE       := Color(0.95, 0.95, 0.85, 1.0)
const COLOR_HEADER      := Color(0.55, 0.7, 0.85, 0.9)
const COLOR_VERB        := Color(0.95, 0.75, 0.35, 1.0)

# =============================================================================
# STATE
# =============================================================================

var _current_tab: int = Tab.SELF
var _verbs_item: int = 0    # 0..6 → archetype frame index (Spark..Druid)
var _guide_item: int = 0    # index into GUIDE_ITEMS

# Story graph state (the new Story page — quantum narrative substrate)
var _story_focus_node: String = ""    # current ui_focus; "" = use density.argmax
var _story_edge_idx: int = 0          # cursor into focused node's outgoing edges (read-only context)
var _story_chatter_idx: int = 0       # GHJKL; cursor into visible chatter feed (the QERF target)
var _story_icon_idx: int = 0          # 0/1/2; selected via 1/2/3 keys
var _story_chatter_connected: bool = false

# Self tab icon picker state.
var _self_picker_slot: int = 0     # which active slot (0/1/2) is being rebound
var _self_picker_pair: int = 0     # cursor into known_pairs (GHJKL; navigates)
var _self_picker_page: int = 0     # page of known_pairs (6 per page)

# Experimental chatter state (mirrors EscapeMenu.gd; refreshed on demand).
var _balance_action_idx: int = 0
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
	panel_title = "Mirror"
	panel_title_size = 22
	panel_size_mode = PanelSizeMode.LARGE
	panel_border_color = Color(0.5, 0.5, 0.3, 0.8)
	navigation_mode = NavigationMode.CALLBACK
	use_scroll_container = true
	content_spacing = 8
	surface_id = "Z"
	frame_ids = [FRAME_SELF, FRAME_STORY, FRAME_VERBS, FRAME_BALANCE, FRAME_GUIDE]
	frame_id = TAB_TO_FRAME.get(_current_tab, FRAME_SELF)


# =============================================================================
# BUILD
# =============================================================================

func _build_content(container: Control) -> void:
	_status_line = Label.new()
	_status_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_line.add_theme_font_size_override("font_size", 12)
	_status_line.add_theme_color_override("font_color", COLOR_MUTED)
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
	_close_hint.add_theme_color_override("font_color", COLOR_MUTED)
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
			lbl.add_theme_color_override("font_color", COLOR_TAB_ACTIVE)
		else:
			lbl.text = "[%s] %s" % [key_str, name_str]
			lbl.add_theme_color_override("font_color", COLOR_TAB_IDLE)


func _refresh_body() -> void:
	if not _body_box:
		return
	for child in _body_box.get_children():
		child.queue_free()
	match _current_tab:
		Tab.SELF:    _build_self_body()
		Tab.STORY:   _build_story_body()
		Tab.VERBS:   _build_verbs_body()
		Tab.BALANCE: _build_balance_body()
		Tab.GUIDE:   _build_guide_body()


# =============================================================================
# BODY: SELF — the mirror. 12-axis posture strip + faction standings.
# =============================================================================

func _build_self_body() -> void:
	var farm = InstrumentLocator.resolve_active_farm(self)

	# The Demos — the player faction biome rendered as icons + marginal bars.
	# No Hamiltonian on faction biomes, so these only move when quest rewards or
	# consume_grants explicitly write to them. Stillness is the point.
	_build_our_faction_view(farm)

	_body_box.add_child(_make_spacer(8))
	_build_icon_picker(farm)
	_body_box.add_child(_make_spacer(8))
	_body_box.add_child(_make_section_header("posture"))

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

		var faction_reg := FactionRegistry.new()
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
			for atom in faction.signature:
				if atom in atom_axis:
					var info: Array = atom_axis[atom]
					weighted_bits[info[0]] += w * float(info[1])
					weight_per_axis[info[0]] += w

		for i in range(FactionAxes.AXIS_COUNT):
			if weight_per_axis[i] > 0.0:
				axis_bias[i] = clampf(weighted_bits[i] / weight_per_axis[i], 0.0, 1.0)

	# Render posture strip — two columns of 6 axes each.
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
		name_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		name_lbl.custom_minimum_size = Vector2(100, 0)
		row.add_child(name_lbl)

		var bar_lbl := Label.new()
		var filled := int(round(bias * 8.0))
		bar_lbl.text = "█".repeat(filled) + "░".repeat(8 - filled)
		bar_lbl.add_theme_font_size_override("font_size", 11)
		bar_lbl.add_theme_color_override("font_color", COLOR_VALUE)
		row.add_child(bar_lbl)

		var pct_lbl := Label.new()
		pct_lbl.text = "%s %s" % [label1, pole1]
		pct_lbl.add_theme_font_size_override("font_size", 11)
		pct_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		row.add_child(pct_lbl)

		grid.add_child(row)

	if standings.is_empty():
		_body_box.add_child(_make_spacer(4))
		_body_box.add_child(_make_muted_label(
			"no faction standing yet — posture is pure mixed state (50/50 on every axis).", 11,
		))

	# Top faction ties.
	if not standings.is_empty():
		_body_box.add_child(_make_spacer(8))
		_body_box.add_child(_make_section_header("strongest ties"))
		var top_rows: Array = []
		for fname in standings.keys():
			var s = standings[fname]
			if s == null:
				continue
			var sc: float = s.scalar() if s.has_method("scalar") else 0.0
			if absf(sc) > 0.0001:
				top_rows.append({"faction": str(fname), "scalar": sc})
		top_rows.sort_custom(func(a, b): return absf(float(a.scalar)) > absf(float(b.scalar)))
		var shown := 0
		for row in top_rows:
			if shown >= 3:
				break
			var sc: float = row.scalar
			var sign_char := "+" if sc >= 0.0 else "−"
			_body_box.add_child(_make_kv_row(str(row.faction), "%s%.2f" % [sign_char, absf(sc)]))
			shown += 1
		if top_rows.size() > 3:
			_body_box.add_child(_make_muted_label(
				"… %d more on V `affinity`" % (top_rows.size() - 3), 11,
			))

	# Vocabulary lexicon
	_body_box.add_child(_make_spacer(8))
	_build_lexicon_section(farm)


func _build_lexicon_section(farm) -> void:
	_body_box.add_child(_make_section_header("lexicon"))
	if farm == null:
		_body_box.add_child(_make_muted_label("(farm not loaded)", 11))
		return

	var lex = null
	if farm.has_method("_ensure_icon_lexicon"):
		lex = farm._ensure_icon_lexicon()
	elif "icon_lexicon" in farm and farm.icon_lexicon != null:
		lex = farm.icon_lexicon

	if lex == null:
		_body_box.add_child(_make_muted_label("(lexicon not available)", 11))
		return

	var known_pairs: Array = farm.known_pairs if "known_pairs" in farm else []
	var discovered: Dictionary = IconLexicon.discovered_set_from_vocabulary(known_pairs)
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
		var owner := str(rec.get("owner_faction", ""))
		var label_text := "%s↔%s  %s" % [p0, p1, icon_name]
		if owner != "":
			label_text += "  · %s" % owner
		var row := Label.new()
		row.text = label_text
		row.add_theme_font_size_override("font_size", 11)
		row.add_theme_color_override("font_color", COLOR_VALUE)
		_body_box.add_child(row)


## Z Self tab — Icon Picker. The player's 3 active expression slots, with
## a paginated list of known_pairs for rebinding via 1/2/3 + GHJKL; + E.
##
## Controls (Self tab only):
##   1/2/3      — pick which slot (0/1/2) to rebind
##   GHJKL;     — cursor through visible known_pairs (page of 6)
##   W/S        — page through known_pairs (6 per page)
##   E          — assign cursor's pair to selected slot
func _build_icon_picker(farm) -> void:
	_body_box.add_child(_make_section_header("icons · expression"))
	if farm == null or not farm.has_method("get_known_pairs"):
		_body_box.add_child(_make_muted_label("(farm not loaded)", 11))
		return
	var pairs: Array = farm.get_known_pairs()
	var slots: Array = farm.active_icon_slots if "active_icon_slots" in farm else [0,1,2]

	# Active slots row (1/2/3)
	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 14)
	for i in range(3):
		var slot_idx: int = int(slots[i]) if i < slots.size() else i
		var pair_str := "?"
		if slot_idx >= 0 and slot_idx < pairs.size():
			var p: Dictionary = pairs[slot_idx]
			pair_str = "%s%s" % [str(p.get("north", "·")), str(p.get("south", "·"))]
		var sel := (i == _self_picker_slot)
		var lbl := Label.new()
		lbl.text = "[%d] %s" % [i + 1, pair_str]
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color",
			COLOR_ITEM_ACTIVE if sel else COLOR_ITEM_IDLE)
		slot_row.add_child(lbl)
	_body_box.add_child(slot_row)
	_body_box.add_child(_make_spacer(4))

	# Known-pairs page (GHJKL; cursor)
	if pairs.is_empty():
		_body_box.add_child(_make_muted_label("(no known pairs yet — incorporate icons via the Icon hat)", 11))
		return

	var page_size := ITEM_KEYS.size()  # 6
	var max_page: int = max(0, (pairs.size() - 1) / page_size)
	_self_picker_page = clampi(_self_picker_page, 0, max_page)
	var start := _self_picker_page * page_size
	var end := mini(start + page_size, pairs.size())
	_self_picker_pair = clampi(_self_picker_pair, start, end - 1)

	var pair_row := HBoxContainer.new()
	pair_row.add_theme_constant_override("separation", 10)
	for i in range(start, end):
		var p: Dictionary = pairs[i]
		var key_str: String = ITEM_KEYS[i - start]
		var pair_str := "%s%s" % [str(p.get("north", "·")), str(p.get("south", "·"))]
		var sel := (i == _self_picker_pair)
		var lbl := Label.new()
		lbl.text = "[%s] %s" % [key_str, pair_str]
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color",
			COLOR_ITEM_ACTIVE if sel else COLOR_ITEM_IDLE)
		pair_row.add_child(lbl)
	_body_box.add_child(pair_row)

	# Page indicator + hints
	var hint := Label.new()
	hint.text = "page %d/%d   ·   1/2/3 slot   ·   GHJKL; cursor   ·   W/S page   ·   E assign" % [_self_picker_page + 1, max_page + 1]
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", COLOR_MUTED)
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
		var name := str(icon.get("name", ""))
		var m0: float = qc.get_marginal(q, 0) if qc.has_method("get_marginal") else 0.5
		var bias: float = clampf(1.0 - m0, 0.0, 1.0)  # how far toward pole_1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_lbl := Label.new()
		name_lbl.text = "%s %s" % [p0, name]
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		name_lbl.custom_minimum_size = Vector2(120, 0)
		row.add_child(name_lbl)
		var bar_lbl := Label.new()
		var filled := int(round(bias * 8.0))
		bar_lbl.text = "█".repeat(filled) + "░".repeat(8 - filled)
		bar_lbl.add_theme_font_size_override("font_size", 11)
		bar_lbl.add_theme_color_override("font_color", COLOR_VALUE)
		row.add_child(bar_lbl)
		var pole_lbl := Label.new()
		pole_lbl.text = p1
		pole_lbl.add_theme_font_size_override("font_size", 11)
		pole_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		row.add_child(pole_lbl)
		_body_box.add_child(row)


# =============================================================================
# BODY: STORY — narrative log skeleton (placeholder until story_log exists).
# =============================================================================

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

	# === FOCUS NODE ===
	_body_box.add_child(_make_section_header("focus · %s · act %d" % [focus_node.display_name, focus_node.act]))
	var beat := Label.new()
	beat.text = str(focus_node.arc_beat) if focus_node.arc_beat != "" else "(no beat text)"
	beat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	beat.add_theme_font_size_override("font_size", 13)
	beat.add_theme_color_override("font_color", COLOR_VALUE)
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
		charge_lbl.add_theme_color_override("font_color", COLOR_MUTED)
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
				COLOR_ITEM_ACTIVE if is_selected else COLOR_ITEM_IDLE)
			_body_box.add_child(lbl)

	_body_box.add_child(_make_spacer(8))

	# === ICON ROW ===
	_body_box.add_child(_make_section_header("icon · expression"))
	var icons: Array = _story_icon_pairs()
	var icon_row := HBoxContainer.new()
	icon_row.add_theme_constant_override("separation", 18)
	for i in range(3):
		var pair: Dictionary = icons[i] if i < icons.size() else {}
		var sel := (i == _story_icon_idx)
		var pair_text := "%s%s" % [str(pair.get("north", "·")), str(pair.get("south", "·"))]
		var ilbl := Label.new()
		ilbl.text = "[%d] %s" % [i + 1, pair_text]
		ilbl.add_theme_font_size_override("font_size", 14)
		ilbl.add_theme_color_override("font_color",
			COLOR_ITEM_ACTIVE if sel else COLOR_ITEM_IDLE)
		icon_row.add_child(ilbl)
	_body_box.add_child(icon_row)
	_body_box.add_child(_make_spacer(4))

	# === ACTION ROW ===
	_body_box.add_child(_make_action_row("Q", "Withdraw", "redirect narrative attention away from this topic"))
	_body_box.add_child(_make_action_row("R", "Reinforce", "focus narrative attention on this chatter's topic"))
	_body_box.add_child(_make_action_row("F", "Harmonize", "lossless — no attention shift; records intent"))
	_body_box.add_child(_make_action_row("E", "Express", "strong focus shift + commit into trajectory"))
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
					var att: Dictionary = sel_biome.get_attractor_state()
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
						att_lbl.add_theme_color_override("font_color", COLOR_MUTED)
						_body_box.add_child(att_lbl)
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
			t.add_theme_color_override("font_color", COLOR_MUTED)
			_body_box.add_child(t)

	_body_box.add_child(_make_spacer(8))
	_body_box.add_child(_make_muted_label("GHJKL; pick chatter   ·   1/2/3 pick icon   ·   QERF express   ·   WASD crawl graph", 10))


func _story_engine() -> Node:
	if Engine.has_singleton("StoryEngine"):
		return Engine.get_singleton("StoryEngine")
	var root := get_tree().root if is_inside_tree() else null
	if root != null and root.has_node("StoryEngine"):
		return root.get_node("StoryEngine")
	return null


## Pick the player's 3 active Icons. Golden cut: top 3 known pairs by harvest count
## (or just the first 3 if no count). Falls back to placeholder if none.
func _story_icon_pairs() -> Array:
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm == null or not farm.has_method("get_known_pairs"):
		return []
	var pairs: Array = farm.get_known_pairs()
	if pairs.is_empty():
		return []
	# No harvest-count metric in the golden cut; just take first 3.
	var slice := pairs.slice(0, mini(3, pairs.size()))
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
	_story_chatter_connected = true


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
# BODY: VERBS — pick a tool with GHJK, see its QERF labels.
# =============================================================================

func _build_verbs_body() -> void:
	_body_box.add_child(_make_section_header("pick a frame"))
	var picker := HBoxContainer.new()
	picker.add_theme_constant_override("separation", 14)
	picker.alignment = BoxContainer.ALIGNMENT_CENTER
	_body_box.add_child(picker)
	for i in range(VERBS_ITEMS.size()):
		var key_str := str(ITEM_KEYS[i]) if i < ITEM_KEYS.size() else ""
		var hat := str(VERBS_HAT_KEYS[i]) if i < VERBS_HAT_KEYS.size() else ""
		var item := Label.new()
		item.add_theme_font_size_override("font_size", 13)
		item.text = "[%s/%s] %s" % [key_str, hat, VERBS_ITEMS[i]]
		if i == _verbs_item:
			item.add_theme_color_override("font_color", COLOR_ITEM_ACTIVE)
		else:
			item.add_theme_color_override("font_color", COLOR_ITEM_IDLE)
		picker.add_child(item)

	_body_box.add_child(_make_spacer(6))

	var frame_name: String = VERBS_FRAME_ORDER[_verbs_item] if _verbs_item < VERBS_FRAME_ORDER.size() else ""
	var frame_def: Dictionary = ToolConfig.get_frame(frame_name)
	var label_name := str(frame_def.get("name", frame_name))
	var hat_key := str(VERBS_HAT_KEYS[_verbs_item]) if _verbs_item < VERBS_HAT_KEYS.size() else ""
	_body_box.add_child(_make_section_header("[%s] %s" % [hat_key, label_name]))

	var mode_name = ToolConfig.get_frame_mode_name(frame_name)
	var mode_actions: Dictionary = frame_def.get("actions", {}).get(mode_name, {})
	for key in ["Q", "E", "R", "F"]:
		var info: Dictionary = mode_actions.get(key, {})
		var label := str(info.get("label", ""))
		var hint := str(info.get("hint", ""))
		if key == "F" and (label == "" or label == "-"):
			label = "Cancel / drill out"
			hint = "Closes any open picker; otherwise no-op"
		if label == "" or label == "-":
			continue
		# Reference display — key badge shows what the verb does on the TOOL surface,
		# not here. Use muted documentation style rather than interactive chip.
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var key_lbl := Label.new()
		key_lbl.text = "[%s]" % key
		key_lbl.add_theme_font_size_override("font_size", 12)
		key_lbl.add_theme_color_override("font_color", COLOR_KEY_CHIP)
		key_lbl.custom_minimum_size = Vector2(28, 0)
		row.add_child(key_lbl)
		var verb_lbl := Label.new()
		verb_lbl.text = label
		verb_lbl.add_theme_font_size_override("font_size", 12)
		verb_lbl.add_theme_color_override("font_color", COLOR_ITEM_IDLE)
		verb_lbl.custom_minimum_size = Vector2(100, 0)
		row.add_child(verb_lbl)
		if hint != "":
			var hint_lbl := Label.new()
			hint_lbl.text = hint
			hint_lbl.add_theme_font_size_override("font_size", 11)
			hint_lbl.add_theme_color_override("font_color", COLOR_MUTED)
			hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(hint_lbl)
		_body_box.add_child(row)

	_body_box.add_child(_make_spacer(4))
	_body_box.add_child(_make_muted_label(
		"Reference only — these verbs execute on the tool surface, not here.", 10))

	var modes: Array = frame_def.get("modes", [])
	if modes.size() > 1:
		_body_box.add_child(_make_spacer(4))
		_body_box.add_child(_make_muted_label(
			"Sub-modes: %s   ·   Tab cycles, 1-%d direct-pick" % [
				" / ".join(modes), modes.size()], 11))


# =============================================================================
# BODY: CHATTER — experimental action cost / timescale inspector for Z.
# =============================================================================

func _build_balance_body() -> void:
	_refresh_balance_snapshot()
	if _balance_snapshot.is_empty():
		_body_box.add_child(_make_muted_label("chatter snapshot unavailable (no active farm).", 12))
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
		var page_size := ITEM_KEYS.size()
		var page := _balance_action_idx / page_size
		var start := page * page_size
		var end: int = mini(start + page_size, total)
		for i in range(start, end):
			_body_box.add_child(_make_balance_action_row(i, i - start))
		var pages := int(ceil(float(total) / float(page_size)))
		_body_box.add_child(_make_muted_label(
			"Q/R action (%d/%d, p%d/%d)  ·  W/S biome" % [_balance_action_idx + 1, total, page + 1, pages],
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
	cost_lbl.add_theme_color_override("font_color", COLOR_VALUE)
	row.add_child(cost_lbl)

	var selected := idx == _balance_action_idx
	var c := COLOR_ITEM_ACTIVE if selected else COLOR_ITEM_IDLE
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
			item.add_theme_color_override("font_color", COLOR_ITEM_ACTIVE)
		else:
			item.add_theme_color_override("font_color", COLOR_ITEM_IDLE)
		picker.add_child(item)

	_body_box.add_child(_make_spacer(6))

	var section_id := str(GUIDE_ITEMS[_guide_item].get("id", ""))
	match section_id:
		"loop":   _guide_core_loop()
		"tools":  _guide_four_tools()
		"biomes": _guide_biomes_economy()
		"try":    _guide_things_to_try()
		"ref":    _guide_quick_reference()


func _guide_core_loop() -> void:
	_body_box.add_child(_make_section_header("the core loop: Q · E · R"))
	_body_box.add_child(_make_body("Press 8 to enter the Ace frame, then:"))
	_body_box.add_child(_make_action_row("Q", "Explore (in)", "Bind a terminal to a quantum register."))
	_body_box.add_child(_make_action_row("E", "Measure (select)", "Collapse the quantum state (Born rule)."))
	_body_box.add_child(_make_action_row("R", "Pop (out)", "Harvest credits proportional to the measured outcome."))
	_body_box.add_child(_make_body(
		"Q reaches in, E observes, R pulls out. Same direction in every tool."))


func _guide_four_tools() -> void:
	_body_box.add_child(_make_section_header("the seven archetype frames (4-0)"))
	_body_box.add_child(_make_action_row("4", "Spark",     "Lindbladian: drain / transfer / pump. 1/2/3 = thermal / dephase / damp."))
	_body_box.add_child(_make_action_row("5", "Icon",      "Inject a dual-emoji qubit from your faction signature."))
	_body_box.add_child(_make_action_row("6", "Merchant", "Faction contracts: Q=import, E=broker, R=export, F=tip."))
	_body_box.add_child(_make_action_row("7", "Captain",   "Biome lifecycle: Q=discover, R=cull."))
	_body_box.add_child(_make_action_row("8", "Ace", "Probe: Q=explore, E=measure, R=pop."))
	_body_box.add_child(_make_action_row("9", "Operator",  "Gate building: Q=build, E=inspect, R=break."))
	_body_box.add_child(_make_action_row("0", "Druid",     "Unitary rotations + Hadamard. 1/2/3 = X / Y / Z."))
	_body_box.add_child(_make_spacer(4))
	_body_box.add_child(_make_body(
		"Re-press the active hat to toggle back to Ace (default toolkit). "
		+ "Hold Shift+Q/E/R to apply the verb to every valid plot at once."))


func _guide_biomes_economy() -> void:
	_body_box.add_child(_make_section_header("biomes"))
	_body_box.add_child(_make_body(
		"Up to 6 biome slots on TYUIOP. Each has its own Hamiltonian — different physics, "
		+ "different feel. Plots live on GHJKL; (left → right). The ' key toggles select-all."))
	_body_box.add_child(_make_spacer(4))
	_body_box.add_child(_make_section_header("economy"))
	_body_box.add_child(_make_body(
		"Measurements convert quantum probability to emoji-credits at 10:1. Learning icon "
		+ "via quests grants up to 4× purity bonus on seasonal reaps."))


func _guide_things_to_try() -> void:
	_body_box.add_child(_make_section_header("a few experiments"))
	_body_box.add_child(_make_body("Make a Bell pair: Operator (9) → pick two plots → Q. Then Ace (8) → measure one, watch the other collapse."))
	_body_box.add_child(_make_body("Hadamard everything: Druid (0) → E → measure. Repeat — watch 50/50 emerge."))
	_body_box.add_child(_make_body("Open N: apply a Hadamard, watch off-diagonal terms appear; measure, watch them vanish."))
	_body_box.add_child(_make_body("Build a GHZ: entangle A↔B, then B↔C. Measure any one — all collapse."))


func _guide_quick_reference() -> void:
	_body_box.add_child(_make_section_header("verbs"))
	_body_box.add_child(_make_action_row("Q", "Prev / In",       "Back, drill in, confirm"))
	_body_box.add_child(_make_action_row("E", "Select / Detail", "Interact / observe"))
	_body_box.add_child(_make_action_row("R", "Next / Out",      "Forward, advance, extract"))
	_body_box.add_child(_make_action_row("E ↓", "Drill in",     "Hadamard / Measure / open detail / open submenu"))
	_body_box.add_child(_make_action_row("F ↑", "Flatten",      "Collapses whatever E opened. No-op if nothing is open."))
	_body_box.add_child(_make_action_row("Tab", "Cycle mode",   "Advance the current frame's sub-mode (was F)"))
	_body_box.add_child(_make_action_row("1/2/3", "Pick sub-mode", "Direct sub-mode select within current frame"))
	_body_box.add_child(_make_action_row("4-0", "Frame hat",    "Pick archetype frame; re-press toggles to Ace"))
	_body_box.add_child(_make_action_row("WASD", "Crawl grid",  "A/D = ±1 plot, W/S = ±1 biome"))
	_body_box.add_child(_make_action_row("[ / ]", "Frame cycle","Pages within open surface; biomes when none open"))
	_body_box.add_child(_make_action_row(", / .", "Menu cycle", "Cycles top-level menu overlays"))
	_body_box.add_child(_make_spacer(4))
	_body_box.add_child(_make_section_header("rows"))
	_body_box.add_child(_make_action_row("4-0",         "Frames",  ""))
	_body_box.add_child(_make_action_row("T-Y-U-I-O-P", "Biomes",  ""))
	_body_box.add_child(_make_action_row("G-H-J-K-L-;", "Plots",   ""))
	_body_box.add_child(_make_action_row("'",            "All plots","toggle"))
	_body_box.add_child(_make_action_row("Shift+QER",    "Bulk",    "apply to all valid plots"))


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
	k.add_theme_color_override("font_color", COLOR_MUTED)
	k.custom_minimum_size = Vector2(140, 0)
	row.add_child(k)
	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 13)
	v.add_theme_color_override("font_color", COLOR_VALUE)
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
	k.add_theme_color_override("font_color", COLOR_KEY_CHIP)
	k.custom_minimum_size = Vector2(70, 0)
	row.add_child(k)
	var n := Label.new()
	n.text = label
	n.add_theme_font_size_override("font_size", 13)
	n.add_theme_color_override("font_color", COLOR_VERB)
	n.custom_minimum_size = Vector2(150, 0)
	row.add_child(n)
	if hint != "":
		var d := Label.new()
		d.text = hint
		d.add_theme_font_size_override("font_size", 12)
		d.add_theme_color_override("font_color", COLOR_MUTED)
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(d)
	return row


func _make_key_chip(key_text: String) -> Label:
	var lbl := Label.new()
	lbl.text = "[%s]" % key_text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", COLOR_KEY_CHIP)
	lbl.custom_minimum_size = Vector2(32, 0)
	return lbl


func _make_muted_label(text: String, size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", COLOR_MUTED)
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
	sb.border_color = COLOR_ITEM_ACTIVE if selected else Color(0.25, 0.30, 0.38, 0.9)
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
	key_label.add_theme_color_override("font_color", COLOR_KEY_CHIP)
	key_label.custom_minimum_size = Vector2(28, 0)
	header.add_child(key_label)

	var speaker_label := Label.new()
	speaker_label.text = "%s %s" % [str(ev.get("speaker", "")), str(ev.get("faction", ""))]
	speaker_label.add_theme_font_size_override("font_size", 13)
	speaker_label.add_theme_color_override("font_color",
		COLOR_ITEM_ACTIVE if selected else COLOR_VALUE)
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
		also_label.add_theme_color_override("font_color", COLOR_MUTED)
		footer.add_child(also_label)
		var visible_count := mini(connections.size(), CHATTER_MAX_CONNECTIONS)
		for ci in range(visible_count):
			footer.add_child(_make_story_chip(str(connections[ci]), COLOR_MUTED))
		if connections.size() > visible_count:
			var more_label := Label.new()
			more_label.text = "+%d" % (connections.size() - visible_count)
			more_label.add_theme_font_size_override("font_size", 10)
			more_label.add_theme_color_override("font_color", COLOR_MUTED)
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

func _on_action_q() -> void:
	match _current_tab:
		Tab.BALANCE: _cycle_balance_action(-1)
		Tab.STORY:   _story_apply_verb("Q")
		_: pass


func _on_action_e() -> void:
	match _current_tab:
		Tab.BALANCE:
			_refresh_balance_snapshot()
			_refresh_body()
		Tab.STORY:
			_story_apply_verb("E")
		Tab.SELF:
			# Assign cursor's known_pair to the selected slot (Icon picker).
			var farm = InstrumentLocator.resolve_active_farm(self)
			if farm == null or not farm.has_method("set_active_icon_slot"):
				return
			var pairs: Array = farm.get_known_pairs()
			if pairs.is_empty() or _self_picker_pair < 0 or _self_picker_pair >= pairs.size():
				return
			farm.set_active_icon_slot(_self_picker_slot, _self_picker_pair)
			_refresh_body()
		_:
			pass


func _on_action_r() -> void:
	match _current_tab:
		Tab.BALANCE: _cycle_balance_action(1)
		Tab.STORY:   _story_apply_verb("R")
		_: pass


func _on_action_f() -> void:
	match _current_tab:
		Tab.STORY: _story_apply_verb("F")
		_: pass


func _story_apply_verb(verb: String) -> void:
	var engine = _story_engine()
	if engine == null:
		return
	# Verb target = the selected chatter line (the QERF target on Story tab).
	var chatter: Array = engine.recent_chatter(6)
	if chatter.is_empty():
		# Nothing to express on; fall back to graph-edge action so QERF still does
		# *something* visible (legacy substrate verbs from earlier phase).
		_story_apply_substrate_verb(verb)
		return
	var idx := clampi(_story_chatter_idx, 0, chatter.size() - 1)
	var ev: Dictionary = chatter[idx]
	var emojis: Array = ev.get("emojis", [])
	var faction: String = str(ev.get("faction", ""))
	var topic_node: String = str(ev.get("topic_node", ""))
	engine.express_icon_on_chatter(_story_icon_idx, verb, emojis, faction, topic_node)
	_refresh_body()


# Legacy substrate-verb path (acts on graph edges from the focused node).
# Kept for cases when there's no chatter to target yet.
func _story_apply_substrate_verb(verb: String) -> void:
	var engine = _story_engine()
	if engine == null:
		return
	var focus_id: String = _story_focus_node if _story_focus_node != "" else engine.default_ui_focus()
	if focus_id == "":
		return
	var outgoing: Array = engine.graph.get_outgoing_edges(focus_id)
	if outgoing.is_empty():
		return
	var idx := clampi(_story_edge_idx, 0, outgoing.size() - 1)
	var edge = outgoing[idx]
	var result: Dictionary = engine.apply_player_action(_story_icon_idx, verb, edge.id)
	if verb == "E" and result.get("success", false):
		var advanced_to: String = str(result.get("advanced_to", ""))
		if advanced_to != "":
			_story_focus_node = advanced_to
			_story_edge_idx = 0
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
		Tab.VERBS:
			if slot < VERBS_ITEMS.size() and _verbs_item != slot:
				_verbs_item = slot
				_refresh_body()
		Tab.BALANCE:
			var page_size := ITEM_KEYS.size()
			var page := _balance_action_idx / page_size
			var global_idx := page * page_size + slot
			if global_idx < _balance_action_keys.size() and _balance_action_idx != global_idx:
				_balance_action_idx = global_idx
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
			# GHJKL; moves the picker cursor over visible known_pairs.
			var farm = InstrumentLocator.resolve_active_farm(self)
			if farm == null:
				return
			var pairs: Array = farm.get_known_pairs()
			if pairs.is_empty():
				return
			var page_size := ITEM_KEYS.size()
			var target := _self_picker_page * page_size + slot
			if target < pairs.size() and _self_picker_pair != target:
				_self_picker_pair = target
				_refresh_body()
		_:
			pass


func _on_navigate(direction: Vector2i) -> void:
	if direction.x != 0:
		var n := TAB_ROW.size()
		_show_tab(wrapi(_current_tab + signi(direction.x), 0, n))
		return
	if direction.y == 0:
		return
	var step: int = signi(direction.y)
	match _current_tab:
		Tab.STORY:
			# WASD on Story: y = parent/child along graph topology, x handled above for tabs;
			# but x-axis on STORY is also used to step through edges (sibling crawl).
			# direction.y was the only branch reached here.
			_story_crawl(step)
		Tab.SELF:
			# W/S pages through known_pairs (6 per page).
			var farm = InstrumentLocator.resolve_active_farm(self)
			if farm == null:
				return
			var pairs: Array = farm.get_known_pairs()
			if pairs.is_empty():
				return
			var page_size := ITEM_KEYS.size()
			var max_page: int = max(0, (pairs.size() - 1) / page_size)
			_self_picker_page = clampi(_self_picker_page + step, 0, max_page)
			_self_picker_pair = clampi(_self_picker_pair, _self_picker_page * page_size, mini((_self_picker_page + 1) * page_size, pairs.size()) - 1)
			_refresh_body()
		Tab.VERBS:
			_verbs_item = wrapi(_verbs_item + step, 0, VERBS_ITEMS.size())
			_refresh_body()
		Tab.BALANCE:
			_cycle_balance_biome(step)
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
		"verbs_tool": _verbs_item + 1 if _current_tab == Tab.VERBS else 0,
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
