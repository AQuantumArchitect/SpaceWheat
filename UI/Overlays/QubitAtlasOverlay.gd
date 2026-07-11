class_name QubitAtlasOverlay
extends "res://UI/Core/Surface.gd"

## V — Icon Understanding Surface.
##
## The canonical home for icon (qubit) detail — biome-agnostic, faction-agnostic.
## Pairs with X (player faction) and B (biome microscope): both call IconCard;
## V is where the player explores the icon dimension on its own terms.
##
## Tabs (TYUIO):
##   T  Lexicon    — owned icons, paginated cards (current main view)
##   Y  Affinity   — same icons sorted by player-↔-icon affinity desc
##   U  Alignment  — 12 canonical axes; icons grouped by axis pole
##   I  Coverage   — biome × icon matrix
##   O  Hints      — undiscovered icons with progress hints
##
## Controls:
##   T-O    = direct-jump tab
##   GHJKL; = item picker within frame
##   A/D    = page prev/next on Lexicon and Hints (the paginated grids)
##   E      = inspect (toast via OverlayBase)
##   Q/R/F  = empty — V is read-only reference, no session state to commit
##   ESC    = close

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const HAT_INCLUSION_THRESHOLD := 0.45  # matches AuthorityAdapter

# Surface frames (TYUIOP)
const FRAME_LEXICON   := "lexicon"
const FRAME_AFFINITY  := "affinity"
const FRAME_ALIGNMENT := "alignment"  # 12-axis alignment view (icons by axis pole)
const FRAME_COVERAGE  := "coverage"
const FRAME_HINTS     := "hints"
const FRAME_SUBSPACE  := "subspace"  # single-qubit subspace projection (migrated from B)

const FRAME_LABELS_LOCAL := {
	FRAME_LEXICON:   "Lexicon",
	FRAME_AFFINITY:  "Affinity",
	FRAME_ALIGNMENT: "Alignment",
	FRAME_COVERAGE:  "Coverage",
	FRAME_HINTS:     "Hints",
	FRAME_SUBSPACE:  "Subspace",
}

const TAB_ROW := [
	{"key": "T", "frame": FRAME_LEXICON,   "name": "Lexicon"},
	{"key": "Y", "frame": FRAME_AFFINITY,  "name": "Affinity"},
	{"key": "U", "frame": FRAME_ALIGNMENT, "name": "Alignment"},
	{"key": "I", "frame": FRAME_COVERAGE,  "name": "Coverage"},
	{"key": "O", "frame": FRAME_HINTS,     "name": "Hints"},
	{"key": "P", "frame": FRAME_SUBSPACE,  "name": "Subspace"},
]

const TAB_BY_KEYCODE := {
	KEY_T: FRAME_LEXICON,
	KEY_Y: FRAME_AFFINITY,
	KEY_U: FRAME_ALIGNMENT,
	KEY_I: FRAME_COVERAGE,
	KEY_O: FRAME_HINTS,
	KEY_P: FRAME_SUBSPACE,
}

# Layout constants
const CARDS_PER_PAGE := 9
const CARD_MIN_SIZE := Vector2(160, 130)
const GRID_COLUMNS := 3
const BAR_HEIGHT := 12
const EMOJI_SIZE := 28
const BADGE_SIZE := 11

# Colors
const COLOR_NORTH := Color(0.4, 0.7, 1.0, 0.9)
const COLOR_SOUTH := Color(1.0, 0.5, 0.3, 0.9)
const COLOR_YIELD := Color(1.0, 0.85, 0.3, 1.0)
const COLOR_BIOME_TAG := Color(0.5, 0.6, 0.7, 0.8)
const COLOR_UNDISCOVERED := Color(0.3, 0.3, 0.35, 0.5)
const COLOR_HINT := Color(0.6, 0.6, 0.5, 0.6)
const COLOR_AFFINITY_BAR_BG := Color(0.12, 0.12, 0.16, 0.7)
const COLOR_AFFINITY_BAR_FILL := Color(0.55, 0.85, 0.65, 0.95)
const COLOR_AXIS_CHIP_BG := Color(0.18, 0.22, 0.32, 0.85)
const COLOR_AXIS_CHIP_FG := Color(0.78, 0.86, 1.0, 0.95)
const AFFINITY_BAR_HEIGHT := 3
const SPEAKER_DOT_SIZE := Vector2(6, 6)
const COLOR_COVERAGE_BG := Color(0.1, 0.12, 0.16, 0.8)
const COLOR_COVERAGE_FILL := Color(0.3, 0.6, 0.4, 0.8)
const COLOR_GLOW_HIGH := Color(0.4, 0.7, 1.0, 0.3)
const COLOR_GLOW_LOW := Color(0.2, 0.2, 0.3, 0.1)

# State
var _current_page := 0
var _total_pages := 1
var _known_icons: Array = []
var _all_biome_icons: Array = []  # [{north, south, biome_name}]
var _biome_registry: BiomeRegistry = null

# Subspace frame helper — built lazily on first _build_subspace_body.
var _subspace_views: BiomeStateViews = null
var _subspace_view_node: Control = null

# UI references
var _header_label: Label
var _page_label: Label
var _cards_grid: GridContainer
var _coverage_container: VBoxContainer
var _card_nodes: Array = []  # Array of card VBoxContainers for live update
var _tab_row_box: HBoxContainer = null
var _tab_labels: Dictionary = {}  # key str → Label
var _frame_stub_label: Label = null  # shown for frames without a builder yet
var _dynamic_box: VBoxContainer = null  # per-frame body (cleared on rebuild)
var _detail_box: VBoxContainer = null   # IconCard drill-in for selected item
var _selected_idx: int = 0              # per current frame's selected item index
var _bookmarks: Dictionary = {}         # session pins: "north|south" -> true

func _init():
	overlay_name = "icon"
	overlay_icon = "📖"
	panel_title = "📖 Qubit Atlas"
	panel_size_mode = PanelSizeMode.LARGE
	show_dimmer = true
	dimmer_color = Color(0, 0, 0, 0.75)
	use_scroll_container = true
	# Surface contract
	surface_id = "V"
	frame_ids = [FRAME_LEXICON, FRAME_AFFINITY, FRAME_ALIGNMENT, FRAME_COVERAGE, FRAME_HINTS, FRAME_SUBSPACE]
	frame_id = FRAME_LEXICON
	# V is a read-only reference surface — no session state to commit (R) or
	# unwind (Q) on most frames. Lexicon/Affinity carry stub Q/R for
	# Forget/Bookmark (TODOs); other frames are honest empty. Pagination on
	# Lexicon/Hints lives on A/D. Default labels match the Lexicon frame
	# since FRAME_LEXICON is the starting frame.
	push_action_label_strings({"Q": "Discorporate", "E": "inspect ▾", "R": "Bookmark", "F": "—"})

func _build_content(container: Control) -> void:
	_biome_registry = BiomeRegistry.new()

	# Header stats
	_header_label = Label.new()
	_header_label.add_theme_font_size_override("font_size", 13)
	_header_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(_header_label)

	_build_tab_row(container)

	var sep_top := HSeparator.new()
	sep_top.add_theme_color_override("color", Color(0.3, 0.4, 0.5, 0.4))
	container.add_child(sep_top)

	# Per-frame stub label (shown when current frame has no dedicated builder yet).
	_frame_stub_label = Label.new()
	_frame_stub_label.add_theme_font_size_override("font_size", 13)
	_frame_stub_label.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	_frame_stub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_frame_stub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_frame_stub_label.visible = false
	container.add_child(_frame_stub_label)

	# Per-frame body (cleared and rebuilt each _rebuild_display call).
	_dynamic_box = VBoxContainer.new()
	_dynamic_box.add_theme_constant_override("separation", 6)
	_dynamic_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_dynamic_box)

	# Detail panel — IconCard drill-in for the currently-selected item.
	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 4)
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_detail_box)

func _on_activated() -> void:
	_refresh_data()
	_rebuild_display()

func _build_tab_row(container: Control) -> void:
	_tab_row_box = HBoxContainer.new()
	_tab_row_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_tab_row_box.add_theme_constant_override("separation", 18)
	container.add_child(_tab_row_box)
	_tab_labels.clear()
	for entry in TAB_ROW:
		var lbl := Label.new()
		lbl.name = "AtlasTab_%s" % str(entry.get("key", ""))
		lbl.add_theme_font_size_override("font_size", 14)
		ClickWire.attach(lbl, _switch_frame.bind(str(entry.get("frame", ""))))
		_tab_row_box.add_child(lbl)
		_tab_labels[str(entry.get("key", ""))] = lbl


## Card/row click twin of the GHJKL; keys.
func _select_card(idx: int) -> void:
	if _selected_idx != idx:
		_selected_idx = idx
		_rebuild_display()


## One tab-switch authority — keyboard (TAB_BY_KEYCODE) and tab clicks land here.
func _switch_frame(target_frame: String) -> void:
	if target_frame == "" or target_frame == frame_id:
		return
	frame_id = target_frame
	_selected_idx = 0
	_current_page = 0
	_refresh_action_labels()
	_rebuild_display()

func _refresh_tab_row() -> void:
	if _tab_labels.is_empty():
		return
	for entry in TAB_ROW:
		var key_str := str(entry.get("key", ""))
		var fid := str(entry.get("frame", ""))
		var name_str := str(entry.get("name", ""))
		var lbl: Label = _tab_labels.get(key_str, null)
		if lbl == null:
			continue
		if fid == frame_id:
			lbl.text = "[%s] %s" % [key_str, name_str.to_upper()]
			lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_TAB_ACTIVE)
		else:
			lbl.text = "[%s] %s" % [key_str, name_str]
			lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_TAB_IDLE)

# Plot-ring keycode→slot via InputBindingRegistry.plot_index_for_keycode (shared source).

# Direct-jump tab via T/Y/U/I/O; GHJKL; selects within current frame.
func _on_unhandled_key(keycode: int, _event: InputEvent) -> bool:
	if TAB_BY_KEYCODE.has(keycode):
		_switch_frame(str(TAB_BY_KEYCODE[keycode]))
		return true
	var slot: int = InputBindingRegistry.plot_index_for_keycode(keycode, 6)
	if slot >= 0:
		if _selected_idx != slot:
			_selected_idx = slot
			_rebuild_display()
		return true
	# A/D pages the grid frames (Lexicon, Hints). Other frames have ≤6 items
	# fully visible, so A/D is unbound there.
	if keycode == KEY_A or keycode == KEY_D:
		if frame_id == FRAME_LEXICON or frame_id == FRAME_HINTS:
			var step := -1 if keycode == KEY_A else 1
			var pages: int = max(_total_pages, 1)
			_current_page = (_current_page + step + pages) % pages
			_selected_idx = 0
			_rebuild_display()
			return true
	return false

func _on_action_q() -> void:
	# Discorporate (un-incorporate) the selected known icon — the inverse of the
	# Icon-hat R "Incorporate". Lexicon/Affinity only; the last voice is protected.
	if frame_id != FRAME_LEXICON and frame_id != FRAME_AFFINITY:
		return
	var pair := _selected_pair_for_frame()
	var north := str(pair.get("north", ""))
	var south := str(pair.get("south", ""))
	if north == "" or not bool(pair.get("known", false)):
		_flash("Discorporate: select an incorporated icon")
		return
	var gsm = _gsm_node()
	if gsm == null or gsm.player_progress == null:
		return
	if not gsm.player_progress.discorporate_icon(north, south):
		_flash("Can't discorporate %s/%s — your last voice stays" % [north, south])
		return
	_bookmarks.erase(north + "|" + south)
	_notify_story("discorporate", north, south)
	_refresh_data()
	_selected_idx = 0
	_rebuild_display()
	_flash("Discorporated %s / %s" % [north, south])

func _on_action_r() -> void:
	# Bookmark (pin) the selected icon — a player-side favorites mark (★ on the
	# card). Session-scoped for now; persistence can layer in later.
	if frame_id != FRAME_LEXICON and frame_id != FRAME_AFFINITY:
		return
	var pair := _selected_pair_for_frame()
	var north := str(pair.get("north", ""))
	var south := str(pair.get("south", ""))
	if north == "":
		return
	var key := north + "|" + south
	if _bookmarks.has(key):
		_bookmarks.erase(key)
		_flash("Unbookmarked %s / %s" % [north, south])
	else:
		_bookmarks[key] = true
		_flash("★ Bookmarked %s / %s" % [north, south])
	_rebuild_display()

func _on_action_f() -> void:
	pass  # V is read-only — nothing to flatten or page-advance here.

## (north, south, known) for the selected item on the Lexicon/Affinity frames.
func _selected_pair_for_frame() -> Dictionary:
	match frame_id:
		FRAME_LEXICON:
			var items: Array = _get_display_items()
			var idx: int = _current_page * CARDS_PER_PAGE + _selected_idx
			if idx >= 0 and idx < items.size():
				return {"north": str(items[idx].get("north", "")), "south": str(items[idx].get("south", "")), "known": bool(items[idx].get("known", false))}
		FRAME_AFFINITY:
			if _selected_idx >= 0 and _selected_idx < _known_icons.size():
				var ic = _known_icons[_selected_idx]
				return {"north": str(ic.get("north", "")), "south": str(ic.get("south", "")), "known": true}
	return {}

func _gsm_node():
	return (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)

func _notify_story(kind: String, north: String, south: String) -> void:
	var se = (Engine.get_main_loop().root.get_node_or_null("/root/StoryEngine") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if se != null and se.has_method("note_player_action"):
		se.note_player_action([north, south], kind)

func _flash(msg: String) -> void:
	var ps: Node = _find_player_shell()
	if ps != null and ps.has_method("show_hint"):
		ps.show_hint(msg, 2, "")

func _refresh_action_labels() -> void:
	if frame_id == FRAME_LEXICON or frame_id == FRAME_AFFINITY:
		push_action_label_strings({"Q": "Discorporate", "E": "inspect ▾", "R": "Bookmark", "F": "—"})
	else:
		push_action_label_strings({"Q": "—", "E": "inspect ▾", "R": "—", "F": "—"})

func _process(_delta: float) -> void:
	if not visible or not is_active:
		return
	_update_live_bars()

# =============================================================================
# DATA
# =============================================================================

func _refresh_data() -> void:
	# Known icons come from the active Farm (canonical signature owner). (The old
	# gsm.get_player_icons() call was dead — no such method exists — so this view
	# silently showed 0 known icons; surfaced while wiring V/Q Discorporate.)
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm != null and farm.has_method("get_known_icons"):
		_known_icons = farm.get_known_icons()
	else:
		_known_icons = []

	_all_biome_icons = _collect_all_biome_icons()

	var total_possible = _all_biome_icons.size()
	_total_pages = max(1, ceili(float(_get_display_items().size()) / float(CARDS_PER_PAGE)))
	_current_page = clampi(_current_page, 0, _total_pages - 1)

	# Header text
	var _bonus_pct = _known_icons.size() * 300  # Each known icon = 4x = +300% on its emojis
	_header_label.text = "%d / %d icons learned" % [_known_icons.size(), total_possible]
	if _known_icons.size() > 0:
		_header_label.text += "    |    Harvest bonus active on %d icons" % _known_icons.size()

func _collect_all_biome_icons() -> Array:
	# Get every icon from every exportable biome.
	var icons = []
	var seen = {}
	for biome in _biome_registry.get_all():
		if biome.name.begins_with("_"):
			continue
		var emojis = biome.emojis
		for i in range(0, emojis.size() - 1, 2):
			var key = emojis[i] + "|" + emojis[i + 1]
			if not seen.has(key):
				seen[key] = true
				icons.append({"north": emojis[i], "south": emojis[i + 1], "biome": biome.name})
	return icons

func _get_display_items() -> Array:
	# Build ordered display list: known icons first, then undiscovered hints.
	var items = []
	var known_set = {}
	for icon in _known_icons:
		var key = icon.get("north", "") + "|" + icon.get("south", "")
		known_set[key] = true
		items.append({"north": icon.north, "south": icon.south, "known": true,
			"biome": _find_biome_for_icon(icon.north, icon.south)})

	for bp in _all_biome_icons:
		var key = bp.north + "|" + bp.south
		if not known_set.has(key):
			items.append({"north": bp.north, "south": bp.south, "known": false,
				"biome": bp.biome})
	return items

func _find_biome_for_icon(north: String, south: String) -> String:
	for bp in _all_biome_icons:
		if bp.north == north and bp.south == south:
			return bp.biome
	return ""

# =============================================================================
# DISPLAY BUILD
# =============================================================================

func _rebuild_display() -> void:
	_refresh_tab_row()
	_clear_dynamic()
	if _frame_stub_label:
		_frame_stub_label.visible = false

	match frame_id:
		FRAME_LEXICON:   _build_lexicon_body()
		FRAME_AFFINITY:  _build_affinity_body()
		FRAME_ALIGNMENT: _build_alignment_body()
		FRAME_COVERAGE:  _build_coverage_body()
		FRAME_HINTS:     _build_hints_body()
		FRAME_SUBSPACE:  _build_subspace_body()
		_:
			if _frame_stub_label:
				_frame_stub_label.text = "%s — no builder." % str(FRAME_LABELS_LOCAL.get(frame_id, frame_id))
				_frame_stub_label.visible = true

	_render_selected_icon_card()

func _clear_dynamic() -> void:
	_card_nodes.clear()
	_cards_grid = null
	_page_label = null
	_coverage_container = null
	if _dynamic_box:
		for child in _dynamic_box.get_children():
			child.queue_free()
	if _detail_box:
		for child in _detail_box.get_children():
			child.queue_free()

# =============================================================================
# FRAME BUILDERS
# =============================================================================

# T — Lexicon: paginated grid of owned + undiscovered icon cards (current behavior).
func _build_lexicon_body() -> void:
	var items: Array = _get_display_items()
	if items.is_empty():
		_dynamic_box.add_child(_muted_label("No icons in registry yet."))
		return
	var pages: int = max(1, ceili(float(items.size()) / float(CARDS_PER_PAGE)))
	_total_pages = pages
	_current_page = clampi(_current_page, 0, pages - 1)

	_cards_grid = GridContainer.new()
	_cards_grid.columns = GRID_COLUMNS
	_cards_grid.add_theme_constant_override("h_separation", 10)
	_cards_grid.add_theme_constant_override("v_separation", 10)
	_cards_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dynamic_box.add_child(_cards_grid)

	var start: int = _current_page * CARDS_PER_PAGE
	var end_idx: int = mini(start + CARDS_PER_PAGE, items.size())
	_selected_idx = clampi(_selected_idx, 0, max(0, end_idx - start - 1))
	for i in range(start, end_idx):
		var card: PanelContainer = _build_card(items[i], (i - start) == _selected_idx)
		ClickWire.attach(card, _select_card.bind(i - start))
		_cards_grid.add_child(card)
		_card_nodes.append({"node": card, "data": items[i]})

	if pages > 1:
		_page_label = Label.new()
		_page_label.text = "Page %d / %d  ·  A/D step page" % [_current_page + 1, pages]
		_page_label.add_theme_font_size_override("font_size", 12)
		_page_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
		_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_dynamic_box.add_child(_page_label)

# Y — Affinity: known icons sorted by IconCard.affinity descending.
func _build_affinity_body() -> void:
	var farm = InstrumentLocator.resolve_active_farm(self)
	if _known_icons.is_empty():
		_dynamic_box.add_child(_muted_label(
			"No icons learned yet — affinity is the player's pull toward an icon.\nLearn icons via quest rewards (C) to populate this view."))
		return
	var rows: Array = []
	for icon in _known_icons:
		if not (icon is Dictionary):
			continue
		var north: String = str(icon.get("north", ""))
		if north == "":
			continue
		var card: Dictionary = IconCard.gather(north, farm)
		rows.append({
			"north": north,
			"south": str(icon.get("south", "")),
			"affinity": float(card.get("affinity", 0.0)),
			"speakers": card.get("faction_speakers", []),
			"is_axial": bool(card.get("is_axial", false)),
			"axis_label": str(card.get("axis_label", "")),
		})
	rows.sort_custom(func(a, b): return float(a.affinity) > float(b.affinity))

	_dynamic_box.add_child(_section_header("affinity (player ↔ icon)"))
	_selected_idx = clampi(_selected_idx, 0, max(0, rows.size() - 1))
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var is_sel: bool = (i == _selected_idx)
		var key_str: String = ""
		if i < ITEM_KEYS_INNER.size():
			key_str = ITEM_KEYS_INNER[i]
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		var key_chip := Label.new()
		key_chip.text = "[%s]" % key_str if key_str != "" else "  "
		key_chip.add_theme_font_size_override("font_size", 11)
		key_chip.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0, 0.95))
		key_chip.custom_minimum_size = Vector2(28, 0)
		hbox.add_child(key_chip)
		var icon_lbl := Label.new()
		icon_lbl.text = "%s / %s" % [row.north, row.south]
		icon_lbl.add_theme_font_size_override("font_size", 14)
		icon_lbl.custom_minimum_size = Vector2(80, 0)
		icon_lbl.add_theme_color_override("font_color",
			COLOR_YIELD if is_sel else Color(0.85, 0.9, 1.0))
		hbox.add_child(icon_lbl)
		var bar_lbl := Label.new()
		var filled: int = int(round(float(row.affinity) * 8.0))
		bar_lbl.text = "█".repeat(filled) + "░".repeat(8 - filled)
		bar_lbl.add_theme_font_size_override("font_size", 11)
		bar_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.85))
		hbox.add_child(bar_lbl)
		var aff_lbl := Label.new()
		aff_lbl.text = "%.2f" % float(row.affinity)
		aff_lbl.add_theme_font_size_override("font_size", 11)
		aff_lbl.custom_minimum_size = Vector2(40, 0)
		aff_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
		hbox.add_child(aff_lbl)
		var speakers_arr: Array = row.speakers
		if not speakers_arr.is_empty():
			var sp_lbl := Label.new()
			sp_lbl.text = " · " + ", ".join(speakers_arr)
			sp_lbl.add_theme_font_size_override("font_size", 10)
			sp_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
			sp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(sp_lbl)
		_dynamic_box.add_child(hbox)

# U — Alignment: 12 canonical axes; ✓ for owned poles, ◌ for unknown.
# When the active scenario sets `attached_faction`, also show that faction's
# per-axis bias bar centered on each row.
func _build_alignment_body() -> void:
	var farm = InstrumentLocator.resolve_active_farm(self)
	var known_set: Dictionary = {}
	if farm and farm.has_method("get_known_emojis"):
		for e in farm.get_known_emojis():
			known_set[str(e)] = true

	var pinned_name: String = farm.get_pinned_faction_name() if farm != null else ""
	var player_alignment = farm.player_alignment if (farm != null and "player_alignment" in farm) else null
	var header_text: String = "alignment (12 canonical axes)"
	if pinned_name != "":
		header_text = "alignment — %s" % pinned_name
	_dynamic_box.add_child(_section_header(header_text))

	var pinned_faction = null
	if farm != null and pinned_name != "" and "faction_density" in farm \
			and farm.faction_density != null \
			and farm.faction_density.has_method("get_registry"):
		var reg = farm.faction_density.get_registry()
		if reg != null and reg.has_method("get_by_name"):
			pinned_faction = reg.get_by_name(pinned_name)
	if pinned_faction != null and "invested_hats" in pinned_faction \
			and pinned_faction.invested_hats is Array \
			and not pinned_faction.invested_hats.is_empty():
		var hats_lbl := _muted_label("hats invested: " + " · ".join(pinned_faction.invested_hats))
		_dynamic_box.add_child(hats_lbl)
		var generated_line := _build_generated_hats_line(pinned_faction, farm)
		if generated_line != null:
			_dynamic_box.add_child(generated_line)

	var n: int = FactionAxes.AXIS_COUNT
	_selected_idx = clampi(_selected_idx, 0, max(0, n - 1))
	for i in range(n):
		var axis: Dictionary = FactionAxes.get_axis(i)
		if axis.is_empty():
			continue
		var pole_0: String = str(axis.get("pole_0", "?"))
		var pole_1: String = str(axis.get("pole_1", "?"))
		var label_0: String = str(axis.get("label_0", ""))
		var label_1: String = str(axis.get("label_1", ""))
		var has_0: bool = known_set.has(pole_0)
		var has_1: bool = known_set.has(pole_1)
		var is_sel: bool = (i == _selected_idx)
		var key_str: String = ""
		if i < ITEM_KEYS_INNER.size():
			key_str = ITEM_KEYS_INNER[i]
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		var key_chip := Label.new()
		key_chip.text = "[%s]" % key_str if key_str != "" else "  "
		key_chip.add_theme_font_size_override("font_size", 11)
		key_chip.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0, 0.95))
		key_chip.custom_minimum_size = Vector2(28, 0)
		hbox.add_child(key_chip)
		var pole_lbl := Label.new()
		pole_lbl.text = "%s %s   ↔   %s %s" % [
			"✓" if has_0 else "◌", pole_0,
			pole_1, "✓" if has_1 else "◌",
		]
		pole_lbl.add_theme_font_size_override("font_size", 13)
		pole_lbl.add_theme_color_override("font_color",
			COLOR_YIELD if is_sel else Color(0.85, 0.9, 1.0))
		hbox.add_child(pole_lbl)
		if player_alignment != null:
			var bias: float = float(player_alignment.axis_marginal(i, 1)) \
				- float(player_alignment.axis_marginal(i, 0))
			hbox.add_child(_build_alignment_bias_bar(bias))
		var name_lbl := Label.new()
		name_lbl.text = "  %s ↔ %s" % [label_0, label_1]
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)
		_dynamic_box.add_child(hbox)

func _build_alignment_bias_bar(bias: float) -> Control:
	var clamped: float = clamp(bias, -1.0, 1.0)
	var holder := HBoxContainer.new()
	holder.custom_minimum_size = Vector2(80, 4)
	holder.add_theme_constant_override("separation", 0)

	var left_pad := Control.new()
	left_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_pad.size_flags_stretch_ratio = max(1.0 + min(clamped, 0.0), 0.0001)
	holder.add_child(left_pad)

	if clamped < 0.0:
		var left_fill := ColorRect.new()
		left_fill.color = COLOR_AFFINITY_BAR_FILL
		left_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_fill.size_flags_stretch_ratio = max(-clamped, 0.0001)
		holder.add_child(left_fill)

	var center_tick := ColorRect.new()
	center_tick.color = Color(0.55, 0.6, 0.7, 0.6)
	center_tick.custom_minimum_size = Vector2(1, 4)
	holder.add_child(center_tick)

	if clamped > 0.0:
		var right_fill := ColorRect.new()
		right_fill.color = COLOR_AFFINITY_BAR_FILL
		right_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_fill.size_flags_stretch_ratio = max(clamped, 0.0001)
		holder.add_child(right_fill)

	var right_pad := Control.new()
	right_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_pad.size_flags_stretch_ratio = max(1.0 - max(clamped, 0.0), 0.0001)
	holder.add_child(right_pad)
	return holder

# I — Coverage: per-biome icons-known-of-total bars.
func _build_coverage_body() -> void:
	_dynamic_box.add_child(_section_header("biome coverage"))
	_coverage_container = VBoxContainer.new()
	_coverage_container.add_theme_constant_override("separation", 4)
	_dynamic_box.add_child(_coverage_container)
	_rebuild_coverage()

# O — Hints: undiscovered icons with biome-source breadcrumb.
func _build_hints_body() -> void:
	var unknowns: Array = []
	var known_set: Dictionary = {}
	for icon in _known_icons:
		if icon is Dictionary:
			known_set[str(icon.get("north","")) + "|" + str(icon.get("south",""))] = true
	for bp in _all_biome_icons:
		var key_str: String = str(bp.north) + "|" + str(bp.south)
		if not known_set.has(key_str):
			unknowns.append({
				"north": bp.north, "south": bp.south, "biome": bp.biome,
				"known": false,
			})
	if unknowns.is_empty():
		_dynamic_box.add_child(_muted_label("All icons learned. Lexicon is complete."))
		return
	_dynamic_box.add_child(_section_header("hints (%d undiscovered)" % unknowns.size()))
	_cards_grid = GridContainer.new()
	_cards_grid.columns = GRID_COLUMNS
	_cards_grid.add_theme_constant_override("h_separation", 10)
	_cards_grid.add_theme_constant_override("v_separation", 10)
	_cards_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dynamic_box.add_child(_cards_grid)
	# Page hints same as Lexicon — but live updates aren't useful for unknowns.
	var pages: int = max(1, ceili(float(unknowns.size()) / float(CARDS_PER_PAGE)))
	_total_pages = pages
	_current_page = clampi(_current_page, 0, pages - 1)
	var start: int = _current_page * CARDS_PER_PAGE
	var end_idx: int = mini(start + CARDS_PER_PAGE, unknowns.size())
	_selected_idx = clampi(_selected_idx, 0, max(0, end_idx - start - 1))
	for i in range(start, end_idx):
		_cards_grid.add_child(_build_card(unknowns[i], (i - start) == _selected_idx))
	if pages > 1:
		_page_label = Label.new()
		_page_label.text = "Page %d / %d  ·  A/D step page" % [_current_page + 1, pages]
		_page_label.add_theme_font_size_override("font_size", 12)
		_page_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
		_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_dynamic_box.add_child(_page_label)

# =============================================================================
# SUBSPACE — single-qubit subspace projection (migrated from B)
# =============================================================================

func _build_subspace_body() -> void:
	var farm = InstrumentLocator.resolve_active_farm(self)
	var abm = (Engine.get_main_loop().root.get_node_or_null("/root/ActiveBiomeManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	var active_biome = null
	if abm and farm and "grid" in farm and farm.grid != null:
		var atom_name: String = abm.get_active_biome() if abm.has_method("get_active_biome") else ""
		if atom_name != "" and farm.grid.has_method("get_biome"):
			active_biome = farm.grid.get_biome(atom_name)
	if active_biome == null:
		_dynamic_box.add_child(_muted_label("No active biome — subspace projection unavailable."))
		return
	if _subspace_views == null:
		_subspace_views = BiomeStateViews.new()
		_subspace_view_node = _subspace_views.build_subspace_view()
	if _subspace_view_node and _subspace_view_node.get_parent():
		_subspace_view_node.get_parent().remove_child(_subspace_view_node)
	_subspace_views.set_biome(active_biome)
	_subspace_views.update_view(FRAME_SUBSPACE)
	if _subspace_view_node:
		_dynamic_box.add_child(_subspace_view_node)

# =============================================================================
# ICONCARD DRILL-IN
# =============================================================================

const ITEM_KEYS_INNER: Array = ["G", "H", "J", "K", "L", ";"]

# Renders an IconCard panel below the dynamic body for the currently-selected item.
func _render_selected_icon_card() -> void:
	var farm = InstrumentLocator.resolve_active_farm(self)
	var emoji: String = _selected_emoji_for_frame()
	if emoji == "" or farm == null:
		return
	var card: Dictionary = IconCard.gather(emoji, farm)
	if not bool(card.get("present", false)):
		return
	_detail_box.add_child(_section_header("· %s ·" % str(card.get("icon_name", emoji))))
	var icon_lbl := Label.new()
	icon_lbl.text = "%s ↔ %s" % [emoji, str(card.get("complement", ""))]
	icon_lbl.add_theme_font_size_override("font_size", 14)
	icon_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_detail_box.add_child(icon_lbl)
	if bool(card.get("is_axial", false)):
		var ax_lbl := Label.new()
		ax_lbl.text = "alignment axis: %s" % str(card.get("axis_label", ""))
		ax_lbl.add_theme_font_size_override("font_size", 11)
		ax_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
		_detail_box.add_child(ax_lbl)
	var aff_lbl := Label.new()
	aff_lbl.text = "affinity %.2f   ·   %s" % [
		float(card.get("affinity", 0.0)),
		"known ✓" if bool(card.get("player_known", false)) else "unknown",
	]
	aff_lbl.add_theme_font_size_override("font_size", 11)
	aff_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_detail_box.add_child(aff_lbl)
	var speakers: Array = card.get("faction_speakers", [])
	if not speakers.is_empty():
		var sp_lbl := Label.new()
		sp_lbl.text = "spoken by  " + ", ".join(speakers)
		sp_lbl.add_theme_font_size_override("font_size", 11)
		sp_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
		_detail_box.add_child(sp_lbl)
	var biomes: Array = card.get("biomes_present", [])
	if not biomes.is_empty():
		var bio_lbl := Label.new()
		bio_lbl.text = "in biomes  " + ", ".join(biomes)
		bio_lbl.add_theme_font_size_override("font_size", 11)
		bio_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
		_detail_box.add_child(bio_lbl)
	var atom: Dictionary = card.get("atom_summary", {})
	if not atom.is_empty():
		var phys_lbl := Label.new()
		phys_lbl.text = "ε=%.2f   ·   γ=%.3f" % [
			float(atom.get("self_energy", 0.0)),
			float(atom.get("decay_rate", 0.0)),
		]
		phys_lbl.add_theme_font_size_override("font_size", 11)
		phys_lbl.add_theme_color_override("font_color", Color(0.6, 0.45, 0.9, 0.9))
		_detail_box.add_child(phys_lbl)

## Returns the emoji that should drive the IconCard for the current frame's selection.
func _selected_emoji_for_frame() -> String:
	match frame_id:
		FRAME_LEXICON:
			var items: Array = _get_display_items()
			var start: int = _current_page * CARDS_PER_PAGE
			var idx: int = start + _selected_idx
			if idx < items.size():
				return str(items[idx].get("north", ""))
		FRAME_AFFINITY:
			if _selected_idx < _known_icons.size():
				return str(_known_icons[_selected_idx].get("north", ""))
		FRAME_ALIGNMENT:
			var axis: Dictionary = FactionAxes.get_axis(_selected_idx)
			return str(axis.get("pole_0", ""))
		FRAME_HINTS:
			var unknowns: Array = _hints_unknowns()
			var start_h: int = _current_page * CARDS_PER_PAGE
			var idx_h: int = start_h + _selected_idx
			if idx_h < unknowns.size():
				return str(unknowns[idx_h].get("north", ""))
		FRAME_COVERAGE:
			return _coverage_selected_emoji()
	return ""

func _coverage_selected_emoji() -> String:
	# Mirror _rebuild_coverage's biome ordering, then return the first known
	# emoji in the selected biome (or first unknown if none owned).
	var known_set: Dictionary = {}
	for icon in _known_icons:
		known_set[str(icon.get("north", "")) + "|" + str(icon.get("south", ""))] = true
	var biome_pairs: Dictionary = {}
	for bp in _all_biome_icons:
		var bname: String = str(bp.biome)
		if not biome_pairs.has(bname):
			biome_pairs[bname] = {"total": 0, "known": 0}
		biome_pairs[bname].total += 1
		if known_set.has(str(bp.north) + "|" + str(bp.south)):
			biome_pairs[bname].known += 1
	var sorted_biomes: Array = biome_pairs.keys()
	sorted_biomes.sort_custom(func(a, b): return biome_pairs[b].known < biome_pairs[a].known)
	var visible_list: Array = []
	for bname in sorted_biomes:
		if visible_list.size() >= 8:
			break
		if int(biome_pairs[bname].total) > 0:
			visible_list.append(bname)
	if _selected_idx < 0 or _selected_idx >= visible_list.size():
		return ""
	var target_biome: String = String(visible_list[_selected_idx])
	var fallback: String = ""
	for bp in _all_biome_icons:
		if String(bp.biome) != target_biome:
			continue
		var key: String = str(bp.north) + "|" + str(bp.south)
		if known_set.has(key):
			return str(bp.north)
		if fallback == "":
			fallback = str(bp.north)
	return fallback

func _hints_unknowns() -> Array:
	var known_set: Dictionary = {}
	for icon in _known_icons:
		if icon is Dictionary:
			known_set[str(icon.get("north","")) + "|" + str(icon.get("south",""))] = true
	var out: Array = []
	for bp in _all_biome_icons:
		var key: String = str(bp.north) + "|" + str(bp.south)
		if not known_set.has(key):
			out.append({"north": bp.north, "south": bp.south, "biome": bp.biome})
	return out

# E pops up an inspect toast (OverlayBase calls get_inspect_text after _on_action_e).
func get_inspect_text() -> String:
	var farm = InstrumentLocator.resolve_active_farm(self)
	var emoji: String = _selected_emoji_for_frame()
	if emoji == "" or farm == null:
		# Fallback: describe the active hat frame so E is always informative.
		var def := ToolConfig.get_frame(ToolConfig.get_current_frame())
		var name_str := str(def.get("name", ""))
		var desc_str := str(def.get("description", ""))
		if desc_str != "":
			return "%s — %s" % [name_str, desc_str]
		return ""
	var card: Dictionary = IconCard.gather(emoji, farm)
	if not bool(card.get("present", false)):
		return ""
	var lines: Array[String] = []
	lines.append("%s · %s ↔ %s" % [
		str(card.get("icon_name", "")), emoji, str(card.get("complement", "")),
	])
	if bool(card.get("is_axial", false)):
		lines.append("axis: %s" % str(card.get("axis_label", "")))
	lines.append("affinity %.2f   ·   %s" % [
		float(card.get("affinity", 0.0)),
		"known ✓" if bool(card.get("player_known", false)) else "unknown",
	])
	var speakers: Array = card.get("faction_speakers", [])
	if not speakers.is_empty():
		lines.append("spoken by " + ", ".join(speakers))
	var biomes: Array = card.get("biomes_present", [])
	if not biomes.is_empty():
		lines.append("biomes: " + ", ".join(biomes))
	return "\n".join(lines)

# Fallback: return the selected hat button's tooltip (set from ToolConfig description).
# Fires when get_inspect_text() returns "" (no icon selected in the current frame).
func get_hovered_tooltip() -> String:
	if _cached_tool_row == null or not is_instance_valid(_cached_tool_row):
		_cached_tool_row = get_tree().get_root().find_child("ToolSelectionRow", true, false) as Control
	if _cached_tool_row != null and _cached_tool_row.has_method("get_selected_button_tooltip"):
		return _cached_tool_row.get_selected_button_tooltip()
	return ""

# Small helpers (mirror what BiomeInspectorOverlay uses).
func _section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.7, 0.85, 0.9))
	return lbl

func _muted_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	return lbl

## Compose the authority-adapter result for (pinned faction × active biome)
## and render a muted "generated for X: ..." line. Returns null if any input
## is missing — the caller skips the row in that case.
func _build_generated_hats_line(faction, farm) -> Label:
	if faction == null or farm == null:
		return null
	var biome_name := ""
	if farm.has_method("_get_active_biome_manager"):
		var mgr = farm._get_active_biome_manager()
		if mgr != null and mgr.has_method("get_active_biome"):
			biome_name = String(mgr.get_active_biome())
	if biome_name == "":
		return null
	var biome = BiomeRegistry.get_shared().get_by_name(biome_name)
	if biome == null:
		return null
	var adapter = AuthorityAdapter.new()
	var tree: Dictionary = adapter.compose_access_tree([faction], [biome])
	var entries: Array = tree.get(String(faction.name), [])
	if entries.is_empty():
		return null
	var entry: Dictionary = entries[0]
	var hats: Array = entry.get("hats", [])
	var scores: Dictionary = entry.get("scores", {})
	var fit: float = float(entry.get("fit", 0.0))

	# Push visibility ring to ToolSelectionRow: dim hats below threshold.
	var passing: Dictionary = {}
	for hat_name in scores.keys():
		if float(scores[hat_name]) >= HAT_INCLUSION_THRESHOLD:
			passing[hat_name] = float(scores[hat_name])
	_push_hat_dim_mask(passing)

	var text: String = ""
	if hats.is_empty():
		text = "generated for %s: (none above threshold)    fit %.2f" % [biome_name, fit]
	else:
		text = "generated for %s: %s    fit %.2f" % [biome_name, " · ".join(hats), fit]
	return _muted_label(text)

## Push a dim/bright mask to the ToolSelectionRow. Locates the row by name
## in the scene tree; caches after first find.
var _cached_tool_row: Control = null
func _push_hat_dim_mask(passing_hats: Dictionary) -> void:
	if _cached_tool_row == null or not is_instance_valid(_cached_tool_row):
		_cached_tool_row = get_tree().get_root().find_child("ToolSelectionRow", true, false) as Control
	if _cached_tool_row == null:
		return
	if _cached_tool_row.has_method("set_hat_dim_mask"):
		_cached_tool_row.set_hat_dim_mask(passing_hats)

func _build_card(item: Dictionary, is_selected: bool = false) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = CARD_MIN_SIZE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style = StyleBoxFlat.new()
	style.bg_color = UIStyleFactory.COLOR_CARD_BG
	style.border_color = COLOR_YIELD if (is_selected or item.known) else UIStyleFactory.COLOR_CARD_BORDER
	style.set_border_width_all(3 if is_selected else (2 if item.known else 1))
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	if item.known:
		_build_known_card_content(vbox, item)
	else:
		_build_undiscovered_card_content(vbox, item)

	return card

func _build_known_card_content(vbox: VBoxContainer, item: Dictionary) -> void:
	# North emoji
	var north_label = Label.new()
	north_label.text = item.north
	north_label.add_theme_font_size_override("font_size", EMOJI_SIZE)
	north_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(north_label)

	# Probability bar container (will be updated live)
	var bar_container = _create_probability_bar()
	bar_container.name = "ProbBar"
	vbox.add_child(bar_container)

	# South emoji
	var south_label = Label.new()
	south_label.text = item.south
	south_label.add_theme_font_size_override("font_size", EMOJI_SIZE)
	south_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(south_label)

	var farm = InstrumentLocator.resolve_active_farm(self)
	var card_data: Dictionary = IconCard.gather(String(item.north), farm)

	var affinity_val: float = float(card_data.get("affinity", 0.0))
	vbox.add_child(_build_affinity_ribbon(affinity_val))

	if bool(card_data.get("is_axial", false)):
		var axis_label_text: String = String(card_data.get("axis_label", ""))
		if axis_label_text != "":
			vbox.add_child(_build_axis_chip(axis_label_text))

	var bottom = HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 6)
	vbox.add_child(bottom)

	if _bookmarks.has(String(item.north) + "|" + String(item.south)):
		var star := Label.new()
		star.text = "★"
		star.add_theme_font_size_override("font_size", BADGE_SIZE)
		star.add_theme_color_override("font_color", COLOR_YIELD)
		bottom.add_child(star)

	var biome_label = Label.new()
	biome_label.text = _short_biome_name(item.biome)
	biome_label.add_theme_font_size_override("font_size", BADGE_SIZE)
	biome_label.add_theme_color_override("font_color", COLOR_BIOME_TAG)
	bottom.add_child(biome_label)

	var speakers: Array = card_data.get("faction_speakers", []) as Array
	if not speakers.is_empty():
		bottom.add_child(_build_speaker_dots(speakers))

	var yield_label = Label.new()
	yield_label.text = "4x"
	yield_label.add_theme_font_size_override("font_size", BADGE_SIZE)
	yield_label.add_theme_color_override("font_color", COLOR_YIELD)
	bottom.add_child(yield_label)

func _build_affinity_ribbon(affinity: float) -> Control:
	var clamped: float = clamp(affinity, 0.0, 1.0)
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, AFFINITY_BAR_HEIGHT)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := StyleBoxFlat.new()
	bg.bg_color = COLOR_AFFINITY_BAR_BG
	bg.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("panel", bg)

	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 0)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar.add_child(inner)

	var fill := ColorRect.new()
	fill.color = COLOR_AFFINITY_BAR_FILL
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.size_flags_stretch_ratio = max(clamped, 0.0001)
	inner.add_child(fill)

	var rest := Control.new()
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rest.size_flags_stretch_ratio = max(1.0 - clamped, 0.0001)
	inner.add_child(rest)
	return bar

func _build_axis_chip(text: String) -> Control:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_AXIS_CHIP_BG
	style.set_corner_radius_all(4)
	style.set_content_margin_all(3)
	chip.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", BADGE_SIZE)
	label.add_theme_color_override("font_color", COLOR_AXIS_CHIP_FG)
	chip.add_child(label)
	return chip

func _build_speaker_dots(speakers: Array) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var max_dots: int = min(speakers.size(), 2)
	for i in range(max_dots):
		var name_str: String = String(speakers[i])
		var dot := ColorRect.new()
		dot.custom_minimum_size = SPEAKER_DOT_SIZE
		dot.color = _speaker_dot_color(name_str)
		box.add_child(dot)
	return box

func _speaker_dot_color(faction_name: String) -> Color:
	var h: int = faction_name.hash()
	var hue: float = float(h % 360) / 360.0
	return Color.from_hsv(hue, 0.55, 0.9, 0.95)

func _build_undiscovered_card_content(vbox: VBoxContainer, item: Dictionary) -> void:
	# Question marks
	var q_label = Label.new()
	q_label.text = "?"
	q_label.add_theme_font_size_override("font_size", EMOJI_SIZE)
	q_label.add_theme_color_override("font_color", COLOR_UNDISCOVERED)
	q_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(q_label)

	# Empty bar
	var bar = _create_probability_bar()
	bar.name = "ProbBar"
	# Set to empty
	var fill = bar.get_node_or_null("Fill")
	if fill:
		fill.size_flags_stretch_ratio = 0.0
	vbox.add_child(bar)

	# Second question mark
	var q_label2 = Label.new()
	q_label2.text = "?"
	q_label2.add_theme_font_size_override("font_size", EMOJI_SIZE)
	q_label2.add_theme_color_override("font_color", COLOR_UNDISCOVERED)
	q_label2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(q_label2)

	# Hint: biome source
	var hint_label = Label.new()
	hint_label.text = _short_biome_name(item.biome)
	hint_label.add_theme_font_size_override("font_size", BADGE_SIZE)
	hint_label.add_theme_color_override("font_color", COLOR_HINT)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint_label)

func _create_probability_bar() -> HBoxContainer:
	# Create a north/south probability bar.
	var bar = HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_constant_override("separation", 0)

	# Background
	var bg = StyleBoxFlat.new()
	bg.bg_color = UIStyleFactory.COLOR_BAR_BG
	bg.set_corner_radius_all(3)

	var bar_panel = PanelContainer.new()
	bar_panel.add_theme_stylebox_override("panel", bg)
	bar_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_panel.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.add_child(bar_panel)

	# Inner HBox for the two fill segments
	var inner = HBoxContainer.new()
	inner.add_theme_constant_override("separation", 1)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar_panel.add_child(inner)

	var north_fill = ColorRect.new()
	north_fill.name = "NorthFill"
	north_fill.color = UIStyleFactory.COLOR_BAR_NORTH
	north_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	north_fill.size_flags_stretch_ratio = 0.5
	inner.add_child(north_fill)

	var south_fill = ColorRect.new()
	south_fill.name = "SouthFill"
	south_fill.color = UIStyleFactory.COLOR_BAR_SOUTH
	south_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	south_fill.size_flags_stretch_ratio = 0.5
	inner.add_child(south_fill)

	return bar

# =============================================================================
# LIVE UPDATE
# =============================================================================

func _update_live_bars() -> void:
	# Update probability bars from live quantum state.
	var gsm = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if not gsm:
		return
	var farm = gsm.get_active_farm() if gsm.has_method("get_active_farm") else null
	if not farm:
		return

	for card_info in _card_nodes:
		var data = card_info.data
		if not data.known:
			continue

		var card_node: PanelContainer = card_info.node
		if card_node == null or not is_instance_valid(card_node):
			continue
		var bar = _find_prob_bar(card_node)
		if not bar:
			continue

		# Aggregate population across all active biomes
		var p_north := 0.0
		var p_south := 0.0
		var count := 0

		var biomes = farm.biomes if "biomes" in farm else {}
		for biome_name in biomes:
			var biome = biomes[biome_name]
			if not biome or not biome.quantum_computer:
				continue
			var qc = biome.quantum_computer
			if qc.has(data.north) and qc.has(data.south):
				p_north += qc.get_population(data.north)
				p_south += qc.get_population(data.south)
				count += 1

		if count > 0:
			p_north /= count
			p_south /= count
		else:
			p_north = 0.5
			p_south = 0.5

		# Clamp to avoid zero-width
		p_north = maxf(p_north, 0.02)
		p_south = maxf(p_south, 0.02)

		var north_fill = bar.get_node_or_null("NorthFill")
		var south_fill = bar.get_node_or_null("SouthFill")
		if not north_fill or not south_fill:
			# Navigate into the panel container
			var panel = bar.get_child(0) if bar.get_child_count() > 0 else null
			var inner = panel.get_child(0) if panel and panel.get_child_count() > 0 else null
			if inner and inner.get_child_count() >= 2:
				north_fill = inner.get_child(0)
				south_fill = inner.get_child(1)

		if north_fill and south_fill:
			north_fill.size_flags_stretch_ratio = p_north
			south_fill.size_flags_stretch_ratio = p_south

		# Purity glow on card border
		_update_card_glow(card_node, data, farm)

func _update_card_glow(card: PanelContainer, data: Dictionary, farm) -> void:
	# Modulate card border brightness based on marginal purity.
	var max_purity := 0.0
	var biomes = farm.biomes if "biomes" in farm else {}
	for biome_name in biomes:
		var biome = biomes[biome_name]
		if not biome or not biome.quantum_computer:
			continue
		var qc = biome.quantum_computer
		if not qc.has(data.north):
			continue
		var q = qc.qubit(data.north)
		if q >= 0:
			var mp = qc.get_marginal_purity(null, q)
			max_purity = maxf(max_purity, mp)

	# Lerp border color: dim when mixed (0.5), bright when pure (1.0)
	var t = clampf((max_purity - 0.5) * 2.0, 0.0, 1.0)
	var glow_color = COLOR_GLOW_LOW.lerp(COLOR_GLOW_HIGH, t)

	var style = card.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		var new_style = style.duplicate()
		new_style.border_color = COLOR_YIELD.lerp(COLOR_YIELD.lightened(0.4), t)
		new_style.shadow_color = glow_color
		new_style.shadow_size = int(t * 6)
		card.add_theme_stylebox_override("panel", new_style)

func _find_prob_bar(card: PanelContainer) -> HBoxContainer:
	# Find the probability bar in a card node tree.
	var vbox = card.get_child(0) if card.get_child_count() > 0 else null
	if not vbox:
		return null
	for child in vbox.get_children():
		if child is HBoxContainer and child.name == "ProbBar":
			return child
	return null

# =============================================================================
# COVERAGE SECTION
# =============================================================================

func _rebuild_coverage() -> void:
	if _coverage_container == null:
		return
	for child in _coverage_container.get_children():
		child.queue_free()

	var known_set = {}
	for icon in _known_icons:
		var key = icon.get("north", "") + "|" + icon.get("south", "")
		known_set[key] = true

	# Group icons by biome
	var biome_icons: Dictionary = {}  # biome_name → {total, known}
	for bp in _all_biome_icons:
		var bname = bp.biome
		if not biome_icons.has(bname):
			biome_icons[bname] = {"total": 0, "known": 0}
		biome_icons[bname].total += 1
		var key = bp.north + "|" + bp.south
		if known_set.has(key):
			biome_icons[bname].known += 1

	# Sort by known count descending
	var sorted_biomes = biome_icons.keys()
	sorted_biomes.sort_custom(func(a, b): return biome_icons[b].known < biome_icons[a].known)

	# Show top biomes (limit to avoid overflow)
	var shown = 0
	for bname in sorted_biomes:
		if shown >= 8:
			break
		var info = biome_icons[bname]
		if info.total == 0:
			continue

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_coverage_container.add_child(row)

		# Biome name
		var name_label = Label.new()
		name_label.text = _short_biome_name(bname)
		name_label.custom_minimum_size = Vector2(100, 0)
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		row.add_child(name_label)

		# Progress bar
		var bar_bg = PanelContainer.new()
		bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar_bg.custom_minimum_size = Vector2(0, 14)
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = COLOR_COVERAGE_BG
		bg_style.set_corner_radius_all(3)
		bar_bg.add_theme_stylebox_override("panel", bg_style)
		row.add_child(bar_bg)

		var fill_ratio = float(info.known) / float(info.total)
		var fill = ColorRect.new()
		fill.color = COLOR_COVERAGE_FILL
		fill.anchor_right = fill_ratio
		fill.anchor_bottom = 1.0
		fill.offset_left = 2
		fill.offset_top = 2
		fill.offset_bottom = -2
		bar_bg.add_child(fill)

		# Count
		var count_label = Label.new()
		count_label.text = "%d/%d" % [info.known, info.total]
		count_label.custom_minimum_size = Vector2(40, 0)
		count_label.add_theme_font_size_override("font_size", 12)
		count_label.add_theme_color_override("font_color",
			COLOR_YIELD if info.known == info.total else Color(0.6, 0.65, 0.7))
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(count_label)

		shown += 1

# =============================================================================
# HELPERS
# =============================================================================

func _short_biome_name(biome_name: String) -> String:
	# Convert CamelCase to spaced: StarterForest → Starter Forest, truncated.
	if biome_name.is_empty():
		return "?"
	var result = ""
	for i in range(biome_name.length()):
		var c = biome_name[i]
		if i > 0 and c == c.to_upper() and c != c.to_lower():
			result += " "
		result += c
	if result.length() > 14:
		result = result.left(12) + ".."
	return result

func get_visible_data() -> Dictionary:
	return {
		"frame_id": frame_id,
		"frame_label": String(FRAME_LABELS_LOCAL.get(frame_id, frame_id)),
		"page_index": _current_page + 1,
		"page_count": _total_pages,
		"selected_index": _selected_idx,
		"selected_emoji": _selected_emoji_for_frame(),
		"known_icon_count": _known_icons.size(),
	}

func get_snapshot() -> Dictionary:
	return get_visible_data()
