class_name ControlsOverlay
extends "res://UI/Core/Surface.gd"

## Z — Controls / Legend Surface.
##
## Keyboard grammar matches the rest of the game (and X):
##   TYUI   = tabs (Live / Verbs / Keys / Guide), top row, same as biome select
##   GHJKL; = items within the active tab, same row as plot slots
##   [ / ]  = cycle tabs (surface frame cycle)
##   , / .  = cycle top-level menus
##   E ↓    = drill into focused item (open detail / submenu) when applicable
##   F ↑    = pop overlay depth; spam F to escape back to main game
##   W/S, A/D, arrows = navigate items / tabs
##   Z/ESC  = close
##
## Z deliberately omits the in-panel verb chip palette: Z's body IS the legend,
## so duplicating QER labels inside it would be redundant.
##
## frame_ids = [live, verbs, keys, guide] — one per tab.

const MenuRegistry = preload("res://UI/Core/MenuRegistry.gd")
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")

# =============================================================================
# TABS / FRAMES
# =============================================================================

enum Tab { SHEET, LIVE, VERBS, KEYS, GUIDE }

const TAB_ROW := [
	{"key": "T", "tab": Tab.SHEET, "name": "Sheet", "frame": "sheet"},
	{"key": "Y", "tab": Tab.LIVE,  "name": "Live",  "frame": "live"},
	{"key": "U", "tab": Tab.VERBS, "name": "Verbs", "frame": "verbs"},
	{"key": "I", "tab": Tab.KEYS,  "name": "Keys",  "frame": "keys"},
	{"key": "O", "tab": Tab.GUIDE, "name": "Guide", "frame": "guide"},
]

const TAB_BY_KEYCODE := {
	KEY_T: Tab.SHEET,
	KEY_Y: Tab.LIVE,
	KEY_U: Tab.VERBS,
	KEY_I: Tab.KEYS,
	KEY_O: Tab.GUIDE,
}

# Left-to-right slot keys (diverges from HOMEROW_KEYS by design — same convention as X).
const ITEM_KEYS := ["G", "H", "J", "K", "L", ";"]
const ITEM_BY_KEYCODE := {
	KEY_G: 0,
	KEY_H: 1,
	KEY_J: 2,
	KEY_K: 3,
	KEY_L: 4,
	KEY_SEMICOLON: 5,
}

const FRAME_SHEET := "sheet"
const FRAME_LIVE := "live"
const FRAME_VERBS := "verbs"
const FRAME_KEYS := "keys"
const FRAME_GUIDE := "guide"

const TAB_TO_FRAME := {
	Tab.SHEET: FRAME_SHEET,
	Tab.LIVE: FRAME_LIVE,
	Tab.VERBS: FRAME_VERBS,
	Tab.KEYS: FRAME_KEYS,
	Tab.GUIDE: FRAME_GUIDE,
}
const FRAME_TO_TAB := {
	FRAME_SHEET: Tab.SHEET,
	FRAME_LIVE: Tab.LIVE,
	FRAME_VERBS: Tab.VERBS,
	FRAME_KEYS: Tab.KEYS,
	FRAME_GUIDE: Tab.GUIDE,
}

# Verbs tab: 7 archetype frames, GHJKL; selects which one (matches hat order).
const VERBS_ITEMS := ["Spark", "Icon", "Socialite", "Captain", "Scientist", "Operator", "Druid"]
const VERBS_FRAME_ORDER: Array = [
	"spark", "icon", "socialite", "captain", "scientist", "operator", "druid",
]
const VERBS_HAT_KEYS: Array = ["4", "5", "6", "7", "8", "9", "0"]

# Guide tab: 5 sections, GHJKL selects which.
const GUIDE_ITEMS := [
	{"id": "loop",     "title": "Core Loop"},
	{"id": "tools",    "title": "Four Tools"},
	{"id": "biomes",   "title": "Biomes & Economy"},
	{"id": "try",      "title": "Things to Try"},
	{"id": "ref",      "title": "Quick Reference"},
]

# =============================================================================
# COLORS
# =============================================================================

const COLOR_TAB_ACTIVE := Color(1.0, 0.9, 0.3, 1.0)
const COLOR_TAB_IDLE := Color(0.6, 0.7, 0.85, 0.85)
const COLOR_ITEM_ACTIVE := Color(1.0, 0.9, 0.3, 1.0)
const COLOR_ITEM_IDLE := Color(0.75, 0.82, 0.92, 0.9)
const COLOR_KEY_CHIP := Color(0.55, 0.85, 1.0, 0.95)
const COLOR_MUTED := Color(0.55, 0.6, 0.7, 0.85)
const COLOR_VALUE := Color(0.95, 0.95, 0.85, 1.0)
const COLOR_HEADER := Color(0.55, 0.7, 0.85, 0.9)
const COLOR_VERB := Color(0.95, 0.75, 0.35, 1.0)

# =============================================================================
# STATE
# =============================================================================

var _current_tab: int = Tab.SHEET
var _verbs_item: int = 0    # 0..6 → archetype frame index (Spark..Druid)
var _guide_item: int = 0    # index into GUIDE_ITEMS
var overlay_source = null

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
	panel_title = "Controls"
	panel_title_size = 22
	panel_size_mode = PanelSizeMode.LARGE
	panel_border_color = Color(0.5, 0.5, 0.3, 0.8)
	navigation_mode = NavigationMode.CALLBACK
	use_scroll_container = true
	content_spacing = 8
	surface_id = "Z"
	frame_ids = [FRAME_SHEET, FRAME_LIVE, FRAME_VERBS, FRAME_KEYS, FRAME_GUIDE]
	frame_id = TAB_TO_FRAME.get(_current_tab, FRAME_SHEET)


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
	_close_hint.text = "[Z] close   ·   TYUIO tabs   ·   GHJKL; items   ·   [/] cycle   ·   [F] back"
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
	var beneath := _snapshot_beneath()
	var sid := str(beneath.get("surface_id", "—")) if not beneath.is_empty() else "—"
	var fid := str(beneath.get("frame_id", "—")) if not beneath.is_empty() else "—"
	_status_line.text = "Z legend  ·  active surface: %s / %s" % [sid, fid]


func _refresh_tab_row() -> void:
	if _tab_labels.is_empty():
		return
	for entry in TAB_ROW:
		var key_str := str(entry.get("key", ""))
		var tab_enum = int(entry.get("tab", Tab.LIVE))
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
		Tab.SHEET: _build_sheet_body()
		Tab.LIVE:  _build_live_body()
		Tab.VERBS: _build_verbs_body()
		Tab.KEYS:  _build_keys_body()
		Tab.GUIDE: _build_guide_body()


# =============================================================================
# BODY: SHEET — character summary (player-as-entity).
# Compact synthesis; full per-faction detail lives on V `affinity`.
# =============================================================================

func _build_sheet_body() -> void:
	var farm = InstrumentLocator.resolve_active_farm(self)
	_body_box.add_child(_make_section_header("you"))

	# Signature count — the player's signature width.
	var icon_count := _player_vocab_count(farm)
	_body_box.add_child(_make_kv_row("Known pairs", "%d" % icon_count))

	# Standings — who is the player to the world?
	var standings: Dictionary = farm.faction_standings if farm and "faction_standings" in farm else {}
	var nonzero_count := 0
	var positive_total := 0.0
	var negative_total := 0.0
	var top_rows: Array = []
	for fname in standings.keys():
		var s = standings[fname]
		if s == null:
			continue
		var sc: float = s.scalar() if s.has_method("scalar") else 0.0
		if absf(sc) > 0.0001:
			nonzero_count += 1
		if sc > 0.0:
			positive_total += sc
		else:
			negative_total += sc
		top_rows.append({"faction": str(fname), "scalar": sc})
	top_rows.sort_custom(func(a, b): return absf(float(a.scalar)) > absf(float(b.scalar)))

	_body_box.add_child(_make_kv_row(
		"Relationships",
		"%d active  ·  Σ+ %.2f  ·  Σ− %.2f" % [nonzero_count, positive_total, negative_total],
	))

	_body_box.add_child(_make_spacer(6))
	_body_box.add_child(_make_section_header("strongest ties"))
	if top_rows.is_empty():
		_body_box.add_child(_make_muted_label(
			"No relationships yet. Settle contracts in C to build standings.",
			12,
		))
	else:
		var shown := 0
		for row in top_rows:
			if shown >= 5:
				break
			var sc: float = row.scalar
			var sign_char := "+" if sc >= 0.0 else "−"
			_body_box.add_child(_make_kv_row(
				str(row.faction),
				"%s%.2f" % [sign_char, absf(sc)],
			))
			shown += 1
		if top_rows.size() > 5:
			_body_box.add_child(_make_muted_label(
				"… %d more on V `affinity`" % (top_rows.size() - 5),
				11,
			))

	_body_box.add_child(_make_spacer(6))
	var ptr := _make_muted_label(
		"Detail: V `affinity` (per-faction channels)  ·  V `signatures` (your axial Bloch)  ·  M `field` (where you sit in ρ)",
		11,
	)
	_body_box.add_child(ptr)


func _player_vocab_count(farm) -> int:
	if farm == null:
		return 0
	# IconLexicon is the canonical icon home; counts of "world-built" pairs
	# are the player's known-symbol set.
	if "icon_lexicon" in farm and farm.icon_lexicon and farm.icon_lexicon.has_method("get_all_world_built"):
		var v = farm.icon_lexicon.get_all_world_built()
		if v is Array:
			return v.size()
	return 0


# =============================================================================
# BODY: LIVE — read the surface beneath Z and show its current contract.
# =============================================================================

func _build_live_body() -> void:
	var snap := _snapshot_beneath()
	if snap.is_empty():
		_body_box.add_child(_make_muted_label("No surface is currently mounted beneath Z.", 13))
		return

	var sid := str(snap.get("surface_id", "—"))
	var fid := str(snap.get("frame_id", "—"))
	var ctx := str(snap.get("context_id", ""))
	_body_box.add_child(_make_section_header("active surface"))
	_body_box.add_child(_make_kv_row("Surface", sid))
	_body_box.add_child(_make_kv_row("Frame", fid))
	if ctx != "":
		_body_box.add_child(_make_kv_row("Context", ctx))
	var focus_dict: Dictionary = snap.get("object_focus", {})
	if focus_dict and not focus_dict.is_empty() and focus_dict.get("id") != null:
		_body_box.add_child(_make_kv_row(
			"Focus",
			"%s (%s)" % [str(focus_dict.get("id")), str(focus_dict.get("type", "?"))]))

	_body_box.add_child(_make_spacer(6))
	_body_box.add_child(_make_section_header("verbs (live)"))
	var actions: Array = snap.get("available_actions", [])
	var any_verb := false
	for a in actions:
		if not (a is Dictionary):
			continue
		var aid := str(a.get("action_id", "")).to_upper()
		var lbl := str(a.get("label", ""))
		if aid == "" or lbl == "":
			continue
		_body_box.add_child(_make_action_row(aid, lbl, str(a.get("family", ""))))
		any_verb = true
	if not any_verb:
		_body_box.add_child(_make_muted_label("(no live verbs published)", 11))

	var transitions: Array = snap.get("transitions", [])
	if transitions.size() > 0:
		_body_box.add_child(_make_spacer(6))
		_body_box.add_child(_make_section_header("transitions"))
		for t in transitions:
			if not (t is Dictionary):
				continue
			_body_box.add_child(_make_kv_row(
				"→ %s" % str(t.get("surface_id", "")),
				str(t.get("reason", ""))))


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
	for key in ["Q", "E", "R"]:
		var info: Dictionary = mode_actions.get(key, {})
		var label := str(info.get("label", ""))
		var hint := str(info.get("hint", ""))
		if label == "" or label == "-":
			continue
		_body_box.add_child(_make_action_row(key, label, hint))
	_body_box.add_child(_make_action_row("F", "Cancel / drill out",
		"Closes any open picker; otherwise no-op"))

	var modes: Array = frame_def.get("modes", [])
	if modes.size() > 1:
		_body_box.add_child(_make_spacer(4))
		_body_box.add_child(_make_muted_label(
			"Sub-modes: %s   ·   Tab cycles, 1-%d direct-pick" % [
				" / ".join(modes), modes.size()], 11))


# =============================================================================
# BODY: KEYS — global key reference, grouped.
# =============================================================================

func _build_keys_body() -> void:
	_body_box.add_child(_make_section_header("archetype frames (4-0)"))
	for hat_key in VERBS_HAT_KEYS:
		var frame_name: String = ToolConfig.HAT_KEY_TO_FRAME.get(hat_key, "")
		if frame_name == "":
			continue
		var frame_def: Dictionary = ToolConfig.get_frame(frame_name)
		_body_box.add_child(_make_action_row(hat_key, str(frame_def.get("name", frame_name)),
			str(frame_def.get("description", ""))))
	_body_box.add_child(_make_action_row("1/2/3", "Sub-mode within active frame", ""))

	_body_box.add_child(_make_spacer(6))
	_body_box.add_child(_make_section_header("biomes (T-Y-U-I-O-P)"))
	for entry in InputBindingRegistry.get_biome_entries():
		_body_box.add_child(_make_action_row(
			str(entry.get("key", "")), str(entry.get("label", "")),
			str(entry.get("description", ""))))

	_body_box.add_child(_make_spacer(6))
	_body_box.add_child(_make_section_header("plots (G-H-J-K-L-;)"))
	for entry in InputBindingRegistry.get_plot_entries():
		_body_box.add_child(_make_action_row(
			str(entry.get("key", "")), str(entry.get("label", "")),
			str(entry.get("description", ""))))
	_body_box.add_child(_make_action_row(
		InputBindingRegistry.SELECT_ALL_KEY, "Select / Clear All",
		"Toggle all plots across every biome"))

	_body_box.add_child(_make_spacer(6))
	_body_box.add_child(_make_section_header("overlays (top-level)"))
	for entry in MenuRegistry.get_top_level_menus():
		_body_box.add_child(_make_action_row(
			str(entry.get("key_label", "")),
			str(entry.get("display_name", "")),
			str(entry.get("description", ""))))

	_body_box.add_child(_make_spacer(6))
	_body_box.add_child(_make_section_header("global"))
	for entry in InputBindingRegistry.get_global_bindings():
		_body_box.add_child(_make_action_row(
			str(entry.get("key", "")), str(entry.get("label", "")),
			str(entry.get("description", ""))))


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
	_body_box.add_child(_make_body("Press 8 to enter the Scientist frame, then:"))
	_body_box.add_child(_make_action_row("Q", "Explore (in)", "Bind a terminal to a quantum register."))
	_body_box.add_child(_make_action_row("E", "Measure (select)", "Collapse the quantum state (Born rule)."))
	_body_box.add_child(_make_action_row("R", "Pop (out)", "Harvest credits proportional to the measured outcome."))
	_body_box.add_child(_make_body(
		"Q reaches in, E observes, R pulls out. Same direction in every tool."))


func _guide_four_tools() -> void:
	_body_box.add_child(_make_section_header("the seven archetype frames (4-0)"))
	_body_box.add_child(_make_action_row("4", "Spark",     "Lindbladian: drain / transfer / pump. 1/2/3 = thermal / dephase / damp."))
	_body_box.add_child(_make_action_row("5", "Icon",      "Inject a dual-emoji qubit from your faction signature."))
	_body_box.add_child(_make_action_row("6", "Socialite", "Faction politics (placeholder)."))
	_body_box.add_child(_make_action_row("7", "Captain",   "Biome lifecycle: Q=discover, R=cull."))
	_body_box.add_child(_make_action_row("8", "Scientist", "Probe: Q=explore, E=measure, R=pop."))
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
	_body_box.add_child(_make_body("Make a Bell pair: Operator (9) → pick two plots → Q. Then Scientist (8) → measure one, watch the other collapse."))
	_body_box.add_child(_make_body("Hadamard everything: Druid (0) → E → measure. Repeat — watch 50/50 emerge."))
	_body_box.add_child(_make_body("Open N: apply a Hadamard, watch off-diagonal terms appear; measure, watch them vanish."))
	_body_box.add_child(_make_body("Build a GHZ: entangle A↔B, then B↔C. Measure any one — all collapse."))


func _guide_quick_reference() -> void:
	_body_box.add_child(_make_section_header("verbs"))
	_body_box.add_child(_make_action_row("Q", "Prev / In",      "Back, drill in, confirm"))
	_body_box.add_child(_make_action_row("E", "Select / Detail", "Interact / observe"))
	_body_box.add_child(_make_action_row("R", "Next / Out",      "Forward, advance, extract"))
	_body_box.add_child(_make_action_row("E ↓", "Drill in",        "Hadamard / Measure / open detail / open submenu"))
	_body_box.add_child(_make_action_row("F ↑", "Drill out",       "Back / pop overlay / cancel pending. Spam to escape."))
	_body_box.add_child(_make_action_row("Tab", "Cycle mode",      "Advance the current frame's sub-mode (was F)"))
	_body_box.add_child(_make_action_row("1/2/3", "Pick sub-mode", "Direct sub-mode select within current frame"))
	_body_box.add_child(_make_action_row("4-0", "Frame hat",       "Pick archetype frame; re-press toggles to Ace"))
	_body_box.add_child(_make_action_row("WASD", "Crawl grid",     "A/D = ±1 plot, W/S = ±1 biome"))
	_body_box.add_child(_make_action_row("[ / ]", "Frame cycle",   "Pages within open surface; biomes when none open"))
	_body_box.add_child(_make_action_row(", / .", "Menu cycle",    "Cycles top-level menu overlays"))
	_body_box.add_child(_make_spacer(4))
	_body_box.add_child(_make_section_header("rows"))
	_body_box.add_child(_make_action_row("4-0",        "Frames",  ""))
	_body_box.add_child(_make_action_row("T-Y-U-I-O-P", "Biomes", ""))
	_body_box.add_child(_make_action_row("G-H-J-K-L-;", "Plots",  ""))
	_body_box.add_child(_make_action_row("'",           "All plots", "toggle"))
	_body_box.add_child(_make_action_row("Shift+QER",   "Bulk",  "apply to all valid plots"))


# =============================================================================
# HELPERS — same shape as X.
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
# SURFACE WIRING
# =============================================================================

func set_overlay_source(source) -> void:
	overlay_source = source
	if _body_box:
		_refresh_body()


func _show_tab(tab: int) -> void:
	if _current_tab == tab and frame_id == TAB_TO_FRAME.get(tab, frame_id):
		return
	_current_tab = tab
	var target_frame: String = TAB_TO_FRAME.get(tab, FRAME_LIVE)
	if frame_id != target_frame:
		var prev := frame_id
		frame_id = target_frame
		frame_changed.emit(target_frame, prev)
		_emit_snapshot()
	_render_all()


func _on_frame_changed(new_frame_id: String, _prev_frame_id: String) -> void:
	var target_tab: int = FRAME_TO_TAB.get(new_frame_id, Tab.LIVE)
	if _current_tab != target_tab:
		_current_tab = target_tab
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
	# Swallow consumed row keys so gameplay doesn't leak under the modal.
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
		Tab.GUIDE:
			if slot < GUIDE_ITEMS.size() and _guide_item != slot:
				_guide_item = slot
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
		Tab.VERBS:
			_verbs_item = wrapi(_verbs_item + step, 0, VERBS_ITEMS.size())
			_refresh_body()
		Tab.GUIDE:
			_guide_item = wrapi(_guide_item + step, 0, GUIDE_ITEMS.size())
			_refresh_body()
		_:
			pass


# =============================================================================
# LIVE-VIEW POLLING
# =============================================================================

func _process(_delta: float) -> void:
	if not visible or not is_active:
		return
	if _current_tab == Tab.LIVE:
		_refresh_status_line()
		_refresh_body()


# =============================================================================
# SNAPSHOT
# =============================================================================

func _snapshot_beneath() -> Dictionary:
	var registry := _surface_registry()
	if registry and registry.has_method("get_snapshot_beneath"):
		var snap = registry.get_snapshot_beneath(self)
		if snap is Dictionary:
			return snap
	return {}


func get_visible_data() -> Dictionary:
	var beneath := _snapshot_beneath()
	var payload: Dictionary = {
		"tab": _current_tab,
		"frame_label": str(TAB_ROW[_current_tab].get("name", "")) if _current_tab < TAB_ROW.size() else "",
		"active_surface_contract": beneath,
		"verbs_tool": _verbs_item + 1 if _current_tab == Tab.VERBS else 0,
		"guide_section": str(GUIDE_ITEMS[_guide_item].get("id", "")) if _current_tab == Tab.GUIDE else "",
	}
	if _current_tab == Tab.SHEET:
		var farm = InstrumentLocator.resolve_active_farm(self)
		var standings: Dictionary = farm.faction_standings if farm and "faction_standings" in farm else {}
		var nonzero := 0
		for fname in standings.keys():
			var s = standings[fname]
			if s != null and s.has_method("scalar") and absf(s.scalar()) > 0.0001:
				nonzero += 1
		payload["sheet"] = {
			"icon_count": _player_vocab_count(farm),
			"relationship_count": nonzero,
		}
	return payload


func get_transitions() -> Array:
	return [
		{"surface_id": "farm", "reason": "return to invoking surface"},
	]
