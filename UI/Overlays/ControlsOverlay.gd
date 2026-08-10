class_name ControlsOverlay
extends "res://UI/Core/Surface.gd"

## X — playthrough surface (X key).
## This run's identity, narrative, economy, and how-to-play. Where Z holds
## save/system/identity ("which truth"), X holds the *current* truth: who you
## are in this playthrough, what's happened, what to do.
##
## Keyboard grammar matches the rest of the game (and Z):
##   TYUIO  = tabs (Self / Story / · / Arc / Guide), top row
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
## frame_ids = [self, story, arc, guide] — one per tab.

const PredicateGloss = preload("res://Core/Quests/PredicateGloss.gd")
const ToolConfig      = preload("res://Core/GameState/ToolConfig.gd")

# =============================================================================
# TABS / FRAMES
# =============================================================================

enum Tab { SELF, STORY, ARC, GUIDE }

const TAB_ROW := [
	{"key": "T", "tab": Tab.SELF,    "name": "Self",    "frame": "self"},
	{"key": "Y", "tab": Tab.STORY,   "name": "Story",   "frame": "story"},
	# U slot intentionally empty — live quest pipeline lives on C (QuestBoard).
	{"key": "I", "tab": Tab.ARC,     "name": "Arc",     "frame": "arc"},
	{"key": "O", "tab": Tab.GUIDE,   "name": "Guide",   "frame": "guide"},
]

const TAB_BY_KEYCODE := {
	KEY_T: Tab.SELF,
	KEY_Y: Tab.STORY,
	# KEY_U intentionally empty (quest pipeline → C)
	KEY_I: Tab.ARC,
	KEY_O: Tab.GUIDE,
}

# Left-to-right slot keys (same convention as X).
# 7-slot item labels (G-; plus '); keycode→slot via
# InputBindingRegistry.plot_index_for_keycode(kc, 7) (shared ring source).
const ITEM_KEYS := ["G", "H", "J", "K", "L", ";", "'"]

const FRAME_SELF    := "self"
const FRAME_STORY   := "story"
const FRAME_ARC     := "arc"
const FRAME_GUIDE   := "guide"

const TAB_TO_FRAME := {
	Tab.SELF:    FRAME_SELF,
	Tab.STORY:   FRAME_STORY,
	Tab.ARC:     FRAME_ARC,
	Tab.GUIDE:   FRAME_GUIDE,
}
const FRAME_TO_TAB := {
	FRAME_SELF:    Tab.SELF,
	FRAME_STORY:   Tab.STORY,
	FRAME_ARC:     Tab.ARC,
	FRAME_GUIDE:   Tab.GUIDE,
}

# Arc tab (I) — the Demos story spine: fired/unfired story flags + arc-quest offers.
const MAX_VISIBLE_ITEMS := 6
const COLOR_ARC_FIRED := Color(0.5, 0.75, 0.55, 0.85)
const COLOR_ARC_UNFIRED := Color(0.85, 0.7, 0.4, 0.95)
const COLOR_ARC_HEADER := Color(0.7, 0.6, 0.85, 0.95)
## Narrative-lane row tint (What Survives / What Connects / What Fades / What Turns).
const LANE_COLORS := {
	"survives": Color(0.55, 0.8, 0.55, 0.95),
	"connects": Color(0.55, 0.7, 0.9, 0.95),
	"fades": Color(0.75, 0.68, 0.6, 0.95),
	"turns": Color(0.85, 0.7, 0.5, 0.95),
}

# Guide tab: 7 sections, GHJKL;' selects which. The Verbs section absorbs
# what used to live on Z's I tab — the 7-hat × QERF reference.
# Glossary (') is the final section; projects Core/Documentation/glossary/*.md live.
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
const GLOSSARY_CANONICAL_TERMS := ["enclave", "measurement", "berry", "invariant", "bath", "fading", "knot", "bridge", "soul", "webway", "resonance", "biome", "faction", "icon"]

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
# Story-tab rebuild is DEBOUNCED: chatter/trajectory/activity signals only mark
# dirty; _process rebuilds at most once per heartbeat. StoryEngine can emit 6+
# chatter events per tick — a synchronous _refresh_body() per event was the
# 17k-objects / 1-2 FPS freeze (positive feedback: low FPS → more events/frame).
# Same heartbeat law as QuestBoard.BOARD_HEARTBEAT_S, slower cadence: a story
# rebuild reshapes ~35 autowrapped paragraphs (~300ms) — at chatter cadence
# (1/s) that alone halves FPS. 2s latency on ambient chatter is imperceptible.
const STORY_HEARTBEAT_S := 2.0
var _story_body_dirty: bool = false   # full rebuild (trajectory advance — rare)
var _story_live_dirty: bool = false   # live sections only (chatter/activity)
var _story_heartbeat_accum: float = 0.0
# Story-tab section boxes (children of _body_box while the story tab is built).
# Live boxes hold the feeds; the static box holds the expensive autowrapped
# prose that must NOT be re-shaped on ambient chatter.
var _story_live_top: VBoxContainer = null
var _story_static_mid: VBoxContainer = null
var _story_live_bot: VBoxContainer = null
# Cap the rendered story log; older beats collapse into a muted count line
# (same pattern as the board's "… N more not shown").
const STORY_LOG_VISIBLE := 40
var _story_inspect_open: bool = false        # E toggles a chatter detail panel; F flattens it
const ATTRACTOR_CACHE_TTL: int = 60          # ~1 second at 60Hz physics

# Self tab icon picker state.
var _self_picker_slot: int = 0     # which active slot (0/1/2) is being rebound
var _self_picker_icon: int = 0     # cursor into known_icons (GHJKL; navigates)
var _self_picker_page: int = 0     # page of known_icons (6 per page)

# Arc tab state.
var _arc_selected_idx: int = 0        # GHJKL; cursor — ABSOLUTE index into _arc_rows()
var _arc_page: int = 0                # A/D page over the 6-row window (57 flags, 6 slots)
var _arc_signal_connected: bool = false

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
	frame_ids = [FRAME_SELF, FRAME_STORY, FRAME_ARC, FRAME_GUIDE]
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
	_close_hint.text = "ESC close   ·   T Y I O tabs   ·   G H J K L ; ' items"
	_close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_close_hint.add_theme_font_size_override("font_size", 11)
	_close_hint.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	container.add_child(_close_hint)

	_render_all()


# The overlay is BUILT once at boot, before the quest manager exists —
# the arc badge's locator walk finds nothing then. Refresh on every
# activation, or the badge is invisible exactly where it matters most:
# the first open.
func _on_activated() -> void:
	_refresh_tab_row()

func _build_tab_row(container: Control) -> void:
	_tab_row_box = HBoxContainer.new()
	_tab_row_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_tab_row_box.add_theme_constant_override("separation", 18)
	container.add_child(_tab_row_box)
	_tab_labels.clear()
	for entry in TAB_ROW:
		var lbl := Label.new()
		lbl.name = "XTab_%s" % str(entry.get("key", ""))
		lbl.add_theme_font_size_override("font_size", 15)
		ClickWire.attach(lbl, _show_tab.bind(int(entry.get("tab", 0))))
		_tab_row_box.add_child(lbl)
		_tab_labels[str(entry.get("key", ""))] = lbl

# =============================================================================
# RENDER
# =============================================================================

func _render_all() -> void:
	_refresh_status_line()
	_refresh_tab_row()
	_refresh_body()
	_declare_tab_actions()


## Chip honesty (fleet playtest: "[R] - but R actually works"): declare the
## verbs each tab really handles so the action bar names them; keys with no
## declared label are gated to no-ops by OverlayBase.
func _declare_tab_actions() -> void:
	var infos: Dictionary = {}
	match _current_tab:
		Tab.STORY:
			infos = {
				"Q": {"label": "Harmonize"},
				"E": {"label": "Inspect"},
				"R": {"label": "Express"},
				"F": {"label": "▶ Play"},
			}
		Tab.ARC:
			infos = {
				"Q": {"label": "Dismiss"},
				"E": {"label": "Refresh"},
				"R": {"label": "Accept"},
			}
		Tab.SELF:
			infos = {
				"R": {"label": "Assign"},
			}
		_:
			infos = {}
	push_action_infos(infos)

func _refresh_status_line() -> void:
	if not _status_line:
		return
	_status_line.text = "Z · self mirror"

func _refresh_tab_row() -> void:
	if _tab_labels.is_empty():
		return
	# Pending arc offers badge the Arc tab. The ACTIVITY line sends players
	# to X, but both blind round-2 testers stalled there — the last hop to
	# [I] needs its own glow (anti-gating: the door must LOOK like a door).
	var arc_waiting := 0
	var qm = _arc_quest_manager()
	if qm != null and "story_offers" in qm and qm.story_offers is Dictionary:
		arc_waiting = qm.story_offers.size()
	for entry in TAB_ROW:
		var key_str := str(entry.get("key", ""))
		var tab_enum = int(entry.get("tab", Tab.SELF))
		var name_str := str(entry.get("name", ""))
		if tab_enum == Tab.ARC and arc_waiting > 0:
			name_str = "%s 📜%d" % [name_str, arc_waiting]
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
		Tab.ARC:     _build_arc_body()
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

	# Alignment panel — read-only: who you are pinned as, and how every other
	# faction overlaps your alignment state.
	_body_box.add_child(_make_spacer(8))
	_render_faction_attachment_panel(farm)

	# Vocabulary lexicon
	_body_box.add_child(_make_spacer(8))
	_build_lexicon_section(farm)

## Alignment panel — read-only. Renders the pinned faction (who you ARE, set
## by the scenario) and every other faction ranked by overlap with your
## alignment state. Attach/detach verbs are future work (tracked in
## docs/DEADWOOD_2026-07-05.md era notes); until they land this panel shows
## only what is true.
func _render_faction_attachment_panel(farm) -> void:
	_body_box.add_child(_make_section_header("alignment — who you stand nearest"))
	if farm == null or not "player_alignment" in farm or farm.player_alignment == null:
		_body_box.add_child(_make_muted_label("(no player alignment in this run)", 11))
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
	# sig column = SIGNATURE progress: signature is the faction's set of ICONS
	# (2-emoji axes), NOT its cloud (atoms). The old code counted cloud atoms
	# against get_known_emojis() — cloud-recognition, which diverges for 7/99
	# factions (Millwright's Union teaches Lumber 🪓/🪵 outside its 6-atom
	# cloud; Carrion Throne's cloud holds 👥 so it read 1/8 at boot with zero
	# icons incorporated). Incorporation lives in farm.known_icons; pair
	# identity goes through IconRegistry's VS16-normalized keys (d1-04 wave-2).
	var known_icons: Array = farm.known_icons if farm != null and "known_icons" in farm else []
	# Autoload resolved by node path, not bare identifier — a bare IconRegistry
	# fails script compile under the `-s` headless harness, where autoload
	# globals aren't populated (defect class test_surface_headless_smoke exposed
	# in BiomeInspectorOverlay; idiom per IconCard.gd:67). Static calls route
	# through the instance too — legal in GDScript, keeps one resolution.
	var icon_registry = (Engine.get_main_loop().root.get_node_or_null("/root/IconRegistry")
		if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	var incorporated: Dictionary = (icon_registry.discovered_set_from_icons(known_icons)
		if icon_registry != null else {})

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
		var sig_icons: Array = (icon_registry.get_icons_for_faction(str(fname))
			if icon_registry != null else [])
		var sig_total: int = sig_icons.size()
		var sig_known: int = 0
		for rec in sig_icons:
			if not (rec is Dictionary):
				continue
			if icon_registry.is_icon_discovered(str(rec.get("pole_0", "")), str(rec.get("pole_1", "")), incorporated):
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
		_body_box.add_child(_make_muted_label("no named icons discovered yet — complete quests to learn faction vocabulary", 11))
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
		_body_box.add_child(_make_muted_label("incorporate icons to unlock expression slots", 11))
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
	hint.text = "page %d/%d   ·   1/2/3 slot   ·   GHJKL; cursor   ·   A/D page   ·   R assign" % [_self_picker_page + 1, max_page + 1]
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
	_body_box.add_child(hint)
	if max_page > 0:
		_body_box.add_child(_make_nav_pager("page %d/%d" % [_self_picker_page + 1, max_page + 1]))

func _build_our_faction_view(farm) -> void:
	_body_box.add_child(_make_section_header("the demos"))
	var biome = null
	if farm and farm.grid and farm.grid.has_method("get_biome"):
		biome = farm.grid.get_biome("TheDemos")
	# QC may be null on first open (farm still settling); degrade gracefully.
	var qc = null
	if biome != null and biome.get("quantum_computer") != null:
		qc = biome.quantum_computer
	# Autoload by node path, not bare identifier (see _render_faction_standings_grid).
	var icon_registry = (Engine.get_main_loop().root.get_node_or_null("/root/IconRegistry")
		if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	var icons: Array = (icon_registry.get_icons_for_faction("The Demos")
		if icon_registry != null else [])
	if icons.is_empty():
		_body_box.add_child(_make_muted_label("the demos has no icons yet.", 11))
		return
	for q in range(icons.size()):
		var icon: Dictionary = icons[q] if (icons[q] is Dictionary) else {}
		var p0 := str(icon.get("pole_0", "?"))
		var p1 := str(icon.get("pole_1", "?"))
		var binding_name := str(icon.get("name", ""))
		var m0: float = qc.get_marginal(q, 0) if (qc != null and qc.has_method("get_marginal")) else 0.5
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

	var cloud: Array = card.get("cloud", [])
	if not cloud.is_empty():
		_body_box.add_child(_make_spacer(4))
		var cloud_lbl := Label.new()
		cloud_lbl.text = "cloud  " + " ".join(cloud)
		cloud_lbl.add_theme_font_size_override("font_size", 11)
		cloud_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
		_body_box.add_child(cloud_lbl)

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
func _render_berry_phase_section(farm, parent: Control) -> void:
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
	parent.add_child(_make_section_header("berry phase"))
	for row in rows:
		var lbl := Label.new()
		# Phase target reference: 4π ≈ 12.566 (full sphere). Show progress against that.
		var ratio: float = float(row.phase) / TAU / 2.0  # phase / (4π)
		lbl.text = "%s · %d consumed · phase %.2f rad (%.0f%% of 4π)" % [
			str(row.biome), int(row.count), float(row.phase), ratio * 100.0
		]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE)
		parent.add_child(lbl)
	parent.add_child(_make_spacer(8))

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

	# Three section boxes, same visual order as before. The static middle
	# holds the expensive prose (autowrapped story-log/beat paragraphs shape
	# at ~15ms EACH on add_child); the live top/bottom hold the feeds ambient
	# chatter refreshes. The debounce refills ONLY the live boxes, so chatter
	# never re-shapes the whole tab — full rebuilds stay on tab switches,
	# keypresses, and trajectory advances (story-flag fires, rare).
	_story_live_top = VBoxContainer.new()
	_story_live_top.add_theme_constant_override("separation", 4)
	_body_box.add_child(_story_live_top)
	_story_static_mid = VBoxContainer.new()
	_story_static_mid.add_theme_constant_override("separation", 4)
	_body_box.add_child(_story_static_mid)
	_story_live_bot = VBoxContainer.new()
	_story_live_bot.add_theme_constant_override("separation", 4)
	_body_box.add_child(_story_live_bot)
	_fill_story_live_top()
	_fill_story_static_mid(engine, focus_id, focus_node, outgoing)
	_fill_story_live_bot(engine)

## Live top section: activity feed. Cheap; refilled by the chatter debounce.
func _fill_story_live_top() -> void:
	var box := _story_live_top
	# === ACTIVITY FEED (PlayerEventLog ring buffer, newest first) ===
	const ACTIVITY_VISIBLE := 12
	var player_event_log = get_node_or_null("/root/PlayerEventLog")
	var recent_events: Array = player_event_log.get_recent(ACTIVITY_VISIBLE, 1) if player_event_log and player_event_log.has_method("get_recent") else []
	var total_events: int = player_event_log.get_recent(player_event_log.MAX_EVENTS, 1).size() if player_event_log and player_event_log.has_method("get_recent") else 0
	var header_text: String = "activity"
	if total_events > recent_events.size():
		header_text = "activity (%d of %d)" % [recent_events.size(), total_events]
	box.add_child(_make_section_header(header_text))
	if recent_events.is_empty():
		box.add_child(_make_muted_label("No events yet.", 12))
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
			box.add_child(ev_lbl)
	box.add_child(_make_spacer(8))

## Static middle section: berry phase, story log, focus, edges, icons, actions.
## The expensive paragraphs live here — rebuilt only on full _refresh_body().
func _fill_story_static_mid(engine, focus_id: String, focus_node, outgoing: Array) -> void:
	var box := _story_static_mid
	# === BERRY PHASE (gates story flags forest_evolving → forest_communion) ===
	var berry_farm = InstrumentLocator.resolve_active_farm(self)
	if berry_farm != null:
		_render_berry_phase_section(berry_farm, box)

	# === STORY LOG (fired arc beats, newest first) ===
	var story_farm = InstrumentLocator.resolve_active_farm(self)
	var story_log: Array = story_farm.story_log if story_farm != null and "story_log" in story_farm else []
	if not story_log.is_empty():
		var log_visible: int = mini(story_log.size(), STORY_LOG_VISIBLE)
		box.add_child(_make_section_header("story (%d)" % story_log.size()))
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
			box.add_child(beat_lbl)
		if story_log.size() > log_visible:
			box.add_child(_make_muted_label(
				"… %d older entries" % (story_log.size() - log_visible), 11))
		box.add_child(_make_spacer(8))

	# === FOCUS NODE ===
	# Focus = where graph ATTENTION sits (boot seeds density on the act-0 node),
	# NOT what has happened. The beat prose narrates a past event, so it renders
	# only once the flag actually fired — before that, the pane looks forward.
	var focus_fired: bool = story_farm != null and "story_flags_fired" in story_farm \
			and story_farm.story_flags_fired.has(focus_id)
	# "lens" in the header: FOCUS follows the expressed faction/spine — it is a
	# viewpoint, not your position. A fleet winner read a lens switch as the
	# story "regressing Act 5 → Act 0".
	var focus_header := "focus (lens) · %s · act %d" % [focus_node.display_name, focus_node.act]
	if not focus_fired:
		focus_header += " · approaching"
	box.add_child(_make_section_header(focus_header))
	box.add_child(_make_nav_pager("A crawl back · crawl forward D"))
	if focus_fired:
		var beat := Label.new()
		beat.text = str(focus_node.arc_beat) if focus_node.arc_beat != "" else "(no beat text)"
		beat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		beat.add_theme_font_size_override("font_size", 13)
		beat.add_theme_color_override("font_color", UIStyleFactory.COLOR_VALUE)
		box.add_child(beat)
	else:
		var ahead := _make_muted_label(
			"Nothing has happened here yet — the story is leaning this way. Its beat is written when you make it true.", 12)
		box.add_child(ahead)
		var focus_qm = _arc_quest_manager()
		if focus_qm != null and not focus_node.predicates.is_empty():
			var fscore: float = focus_qm.evaluate_flag_score({"predicates": focus_node.predicates})
			var fire_at: float = focus_qm.FLAG_FIRE_THRESHOLD
			var prog := Label.new()
			prog.text = "%.2f / %.2f %s" % [fscore, fire_at, _ratio_bar(fscore / fire_at, 6)]
			prog.add_theme_font_size_override("font_size", 11)
			prog.add_theme_color_override("font_color", _score_color(fscore))
			box.add_child(prog)
	box.add_child(_make_spacer(6))

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
		box.add_child(charge_lbl)

	# Density / coherence summary
	var density_w: float = float(engine.graph.density.get(focus_id, 0.0))
	var coh: float = engine.graph.coherence()
	var coh_word: String = "diffuse" if coh < 0.35 else ("moderate" if coh < 0.7 else "focused")
	var summary := Label.new()
	summary.text = "attention here: %.2f   ·   narrative focus: %.2f (%s)" % [density_w, coh, coh_word]
	summary.add_theme_font_size_override("font_size", 11)
	summary.add_theme_color_override("font_color", COLOR_HEADER)
	box.add_child(summary)
	box.add_child(_make_spacer(8))

	# === EDGES ===
	box.add_child(_make_section_header("edges from here"))
	if outgoing.is_empty():
		box.add_child(_make_muted_label("(no outgoing edges)", 11))
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
			box.add_child(lbl)

	box.add_child(_make_spacer(8))

	# === ICON ROW ===
	box.add_child(_make_section_header("icon · expression"))
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
	box.add_child(icon_row)
	box.add_child(_make_spacer(4))

	# === ACTION ROW (canonical Q E R F left-to-right) ===
	box.add_child(_make_action_row("Q", "Harmonize", "yield self toward target — alignment drifts toward this chatter's emoji palette"))
	var e_label := "flatten" if _story_inspect_open else "inspect ▾"
	var e_desc := "close detail panel" if _story_inspect_open else "open chatter detail (pauses sim)"
	box.add_child(_make_action_row("E", e_label, e_desc))
	box.add_child(_make_action_row("R", "Express", "push self outward — strong commit: alignment + mass shift + phase rotation"))
	var f_label := "flatten" if _story_inspect_open else "—"
	var f_desc := "close detail panel" if _story_inspect_open else ""
	box.add_child(_make_action_row("F", f_label, f_desc))
	box.add_child(_make_spacer(8))

## Live bottom section: chatter bubbles, inspect panel, trajectory, key hints.
## Refilled by the chatter debounce.
func _fill_story_live_bot(engine) -> void:
	var box := _story_live_bot
	# === CHATTER BUBBLES (cursor target for QERF) ===
	box.add_child(_make_section_header("chatter — GHJKL; selects target"))
	var chatter: Array = engine.recent_chatter(6)
	if chatter.is_empty():
		box.add_child(_make_muted_label("(silence so far — wait for socialites)", 10))
		_story_chatter_idx = 0
	else:
		_story_chatter_idx = clampi(_story_chatter_idx, 0, chatter.size() - 1)
		for i in range(chatter.size()):
			var sel := (i == _story_chatter_idx)
			var key_str: String = ITEM_KEYS[i] if i < ITEM_KEYS.size() else " "
			box.add_child(_make_chatter_bubble(chatter[i], sel, key_str))
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
						box.add_child(att_lbl)

	# === INSPECT PANEL (E expands; F flattens) ===
	if _story_inspect_open:
		box.add_child(_make_spacer(6))
		box.add_child(_make_story_inspect_panel())
	box.add_child(_make_spacer(8))

	# === TRAJECTORY ===
	box.add_child(_make_section_header("trajectory (last 5)"))
	var traj: Array = engine.trajectory.last(5) if engine.trajectory != null else []
	if traj.is_empty():
		box.add_child(_make_muted_label("(no steps yet)", 10))
	else:
		for entry in traj:
			var verb := str(entry.get("verb", ""))
			var verb_chip := ("[%s] " % verb) if verb != "" else ""
			var spk := str(entry.get("speaker", ""))
			var t := Label.new()
			t.text = "  %s%s · %s → %s" % [verb_chip, spk, str(entry.get("from_node", "")), str(entry.get("to_node", ""))]
			t.add_theme_font_size_override("font_size", 10)
			t.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
			box.add_child(t)

	box.add_child(_make_spacer(8))
	box.add_child(_make_muted_label("GHJKL; pick chatter   ·   1/2/3 pick icon   ·   Q harmonize / R express / E inspect / F flatten   ·   W parent / S child node", 10))

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
				var s = standings[faction]
				if s != null and s.has_method("scalar"):
					box.add_child(_make_kv_row("standing", "%+.2f" % float(s.scalar())))

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
		_story_live_dirty = true

func _on_story_chatter(_speaker: String, _faction: String, _line: String, _topic: String) -> void:
	if _current_tab == Tab.STORY and is_active:
		_story_live_dirty = true

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
		_story_body_dirty = true

## Debounced Story-tab refresh: at most one update per STORY_HEARTBEAT_S, no
## matter how many chatter/trajectory/activity events arrived in between.
## Chatter/activity refill only the live section boxes; a trajectory advance
## (story-flag fire, rare) rebuilds the whole body since focus/edges moved.
func _process(delta: float) -> void:
	_story_heartbeat_accum += delta
	if _story_heartbeat_accum < STORY_HEARTBEAT_S:
		return
	_story_heartbeat_accum = 0.0
	if not (_story_body_dirty or _story_live_dirty):
		return
	var full := _story_body_dirty
	_story_body_dirty = false
	_story_live_dirty = false
	if _current_tab == Tab.STORY and is_active and visible:
		if full:
			_refresh_body()
		else:
			_refresh_story_live()

## Refill ONLY the live story sections (activity feed + chatter/trajectory).
## The static middle (berry, story log, focus, edges — the ~15ms-per-paragraph
## prose) is left untouched, so ambient chatter costs ~a tenth of a rebuild.
func _refresh_story_live() -> void:
	if not (is_instance_valid(_story_live_top) and is_instance_valid(_story_live_bot)):
		_refresh_body()
		return
	var engine = _story_engine()
	if engine == null or engine.graph == null:
		return
	for child in _story_live_top.get_children():
		child.queue_free()
	for child in _story_live_bot.get_children():
		child.queue_free()
	_fill_story_live_top()
	_fill_story_live_bot(engine)

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

	if GUIDE_ITEMS.size() > 1:
		_body_box.add_child(_make_nav_pager("section %d/%d" % [_guide_item + 1, GUIDE_ITEMS.size()]))
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
	# Quantities are READ from the same cost authority the action-bar badges use
	# (ActionCostRuntime → FarmEconomy/EconomyConstants) — never hardcoded prose
	# numbers that can drift from the real price (d1-03 literalist finding).
	var farm = InstrumentLocator.resolve_active_farm(self)
	var economy = ActionCostRuntime.resolve_economy(farm)
	var explore_cost: Dictionary = ActionCostRuntime.get_action_cost(economy, "explore", {})
	var explore_bread := int(round(float(explore_cost.get("🍞", 1))))
	var strike_cost: Dictionary = ActionCostRuntime.get_action_cost(economy, "measure", {})
	var strike_people := int(round(float(strike_cost.get("👥", 1))))

	_body_box.add_child(_make_section_header("the core loop: F · R · Q (tap · tap · tap)"))
	_body_box.add_child(_make_body("Press 8 to enter the Ace frame (you start there), then:"))
	_body_box.add_child(_make_action_row("F", "Explore", "Mount an expedition to an unexplored plot — costs %d🍞 (breaking bread opens doors). Binds the register so it can be struck. A tap on an unexplored plot does the same." % explore_bread))
	_body_box.add_child(_make_action_row("R", "Strike", "Collapse the quantum state (Born rule) — the game's one irreversible act; a social encounter that costs %d👥 base (unfamiliar pairs cost more). The bubble freezes cyan with its answer. A tap on a live bubble does the same." % strike_people))
	_body_box.add_child(_make_action_row("Q", "Extract", "Harvest the frozen answer, free — reward = surprisal −kT·log p, rare pays more (a certain outcome pays the floor: let the state evolve before you strike). The bubble returns to live evolution. A tap on a frozen bubble does the same."))
	_body_box.add_child(_make_action_row("E", "Pause", "Stop time and look — E is the universal \"tell me more\" on every surface."))
	_body_box.add_child(_make_body(
		"F explores, R strikes, Q extracts — that's the farming heartbeat, and tapping a plot walks the same three beats. "
		+ "On an explored plot F returns to its other meaning: play on / fast-forward (double down and let the odds spin). "
		+ "Shift+F reaps the whole season — time runs, every plot settles, the harvest lands at once."))

func _guide_four_tools() -> void:
	_body_box.add_child(_make_section_header("the seven archetype frames (4-0)"))
	_body_box.add_child(_make_action_row("4", "Spark",     "One-shot Lindblad jolt — fires only on open (wet) ground; on closed ground the chips grey (openness is a place). The dissipative kick that re-purifies. E reads the gauge. Mode 2 (🌉): Majorana bridges — R spans, F braids, Q fuses, E reads the card — never sealed, any regime."))
	_body_box.add_child(_make_action_row("5", "Icon",      "Inject a dual-emoji qubit from the neighborhood's installed signature."))
	_body_box.add_child(_make_action_row("6", "Merchant", "Standing contracts with the country you stand in (wet ground only). 1/2/3 picks the channel: thermal ~ (keeps the field warm) · dephase . (sells phase for heat; no buying it back) · damp | (pins and pays). Q=Export, E=order book, R=Import, F=Settle. Price = −kT·log p."))
	_body_box.add_child(_make_action_row("7", "Captain",   "Biome lifecycle: Q=cull, E=compass, R=discover."))
	_body_box.add_child(_make_action_row("8", "Ace", "Measurement vantage: Q=extract the yield, E=pause+inspect, R=strike (collapse), F=fast-forward / reap the season."))
	_body_box.add_child(_make_action_row("9", "Operator",  "Gate building: Q=break, E=inspect, R=gate."))
	_body_box.add_child(_make_action_row("0", "Druid",     "Unitary rotations + Hadamard. 1/2/3 = X / Y / Z."))
	_body_box.add_child(_make_spacer(4))
	_body_box.add_child(_make_body(
		"Re-press the active hat to toggle back to Ace (default toolkit). "
		+ "Hold Shift+Q/E/R to apply the verb to every valid plot at once."))

func _guide_biomes_economy() -> void:
	_body_box.add_child(_make_section_header("biomes"))
	_body_box.add_child(_make_body(
		"Up to 6 biome slots on TYUIOP. Each biome carries its own physics — the coherent "
		+ "couplings run live; its webway (the authored food web) is sealed while the "
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
	_body_box.add_child(_make_body("See the loom: M → Graph → drill into a biome. Gold edges are the entanglement you wove; dark orange channels are the webway — sealed where the country runs closed, live where it runs wet."))
	_body_box.add_child(_make_body("Read the compass: same drill-down — 🧭 shows the biome's deep state and its gap. Evolve all you like, the depths never move; measure, and they jump. That's the campaign's second invariant."))
	_body_box.add_child(_make_body("Spell a braid word: Hadamard then CNOT weaves a thread; CNOT then Hadamard weaves nothing. Same chores, opposite worlds — order is the point."))
	_body_box.add_child(_make_body("Visit the wet country (post-story): some biomes run OPEN — the Bath drinks phase there and the world goes gray while nothing moves. Superpose something bright and stand witness."))
	_body_box.add_child(_make_body("Keep a dying thing: in the wet country, measurement pins what it touches (Zeno). Watch the Lamplighters' horn — stop watching and the drain wins."))
	_body_box.add_child(_make_body("Bank a knot: track a forest qubit (Icon F) through TWO closed loops — the record keeps the walks, and the knot card reads their mutual winding. Nothing links on the sphere; the link lives one floor up."))
	_body_box.add_child(_make_body("Raise a span: Spark 🌉 mode, R on a qubit here, R on a qubit in another biome — one fermion split between two shores. Anchor an end at home and the Bath can never touch it. Braid (F), then fuse (Q) — reading it spends it."))

func _guide_quick_reference() -> void:
	_body_box.add_child(_make_section_header("verbs"))
	_body_box.add_child(_make_action_row("Q", "Screw out",        "Retreat / shallower / safe variant / quit"))
	_body_box.add_child(_make_action_row("E", "Pause + inspect", "Snapshot state; sim pauses as side-effect"))
	_body_box.add_child(_make_action_row("R", "Screw in",        "Commit / deeper / advance / resume"))
	_body_box.add_child(_make_action_row("E ↓", "Drill in",     "Hadamard / Measure / open detail / open submenu"))
	_body_box.add_child(_make_action_row("F ↑", "Flatten",      "Collapses whatever E opened. No-op if nothing is open."))
	_body_box.add_child(_make_action_row("Tab", "Cycle hat",   "Advance the archetype frame (4-0)"))
	_body_box.add_child(_make_action_row("1/2/3", "Pick sub-mode", "Direct sub-mode select within current frame"))
	_body_box.add_child(_make_action_row("4-0", "Frame hat",    "Pick archetype frame; re-press toggles to Ace"))
	_body_box.add_child(_make_action_row("WASD", "Spin cylinder", "W/S rotate between rings (frame/biome/plot/surface), A/D step around the active ring"))
	_body_box.add_child(_make_action_row("F12", "Postcard",    "Capture the view with the physics watermark in the pixels + a certificate (user://postcards/)"))
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
	return OverlayChrome.kv_row(key, value)

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
	return OverlayChrome.key_chip(key_text)

func _make_muted_label(text: String, icon_size: int) -> Label:
	return OverlayChrome.muted_label(text, icon_size)

func _make_body(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl

func _make_spacer(h: int) -> Control:
	return OverlayChrome.spacer(h)

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
		Tab.ARC:
			return _arc_inspect_text()
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
	var cloud: Array = card.get("cloud", [])
	if not cloud.is_empty():
		lines.append("speaks: " + " ".join(cloud))
	var bio: Array = card.get("biomes_of_presence", [])
	if not bio.is_empty():
		lines.append("biomes: " + ", ".join(bio))
	return "\n".join(lines)

func _on_action_q() -> void:
	match _current_tab:
		Tab.STORY:   _story_apply_verb("R")  # Q label "Harmonize" → engine R (player aligns toward target)
		Tab.ARC:     _acknowledge_selected_arc()  # Q = dismiss the arc-quest beat
		_: pass

func _on_action_e() -> void:
	match _current_tab:
		Tab.STORY:
			_story_inspect_open = not _story_inspect_open  # E = pause + inspect (toggle panel)
			_refresh_body()
		Tab.ARC:
			_refresh_body()  # E = refresh the arc timeline
		_:
			pass

func _on_action_r() -> void:
	match _current_tab:
		Tab.STORY:   _story_apply_verb("E")  # R label "Express" → engine E (strong commit / mass shift)
		Tab.ARC:     _accept_selected_arc()  # R = accept the arc/tutorial quest into active
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
# BODY: ARC — the Demos story spine (fired/unfired flags + arc-quest offers).
# Moved from C/QuestBoard: this is a narrative view and reads next to Story.
# =============================================================================

# Arc resolves its quest manager lazily (like the farm), matching how every
# other read on this surface goes through InstrumentLocator — no injected member.
func _arc_quest_manager():
	return InstrumentLocator.resolve_quest_manager(self, InstrumentLocator.resolve_active_farm(self))

func _ensure_arc_signal() -> void:
	if _arc_signal_connected:
		return
	var qm = _arc_quest_manager()
	if qm and qm.has_signal("story_flag_fired") and not qm.story_flag_fired.is_connected(_on_arc_flag_changed):
		qm.story_flag_fired.connect(_on_arc_flag_changed)
		_arc_signal_connected = true

func _on_arc_flag_changed(_flag_id: String, _flag: Dictionary) -> void:
	if _current_tab == Tab.ARC:
		_refresh_body()

func _build_arc_body() -> void:
	var rows: Array = _arc_rows()
	if rows.is_empty():
		_body_box.add_child(_make_muted_label("no story flags loaded", 12))
		return
	# A/D pages the 6-row window over ALL rows — 57 flags used to compete for
	# six slots with a muted "… N more not shown" and no way to reach them.
	var page_count: int = maxi(1, int(ceil(float(rows.size()) / float(MAX_VISIBLE_ITEMS))))
	_arc_page = clampi(_arc_page, 0, page_count - 1)
	_body_box.add_child(_make_arc_chapter_header())
	var base: int = _arc_page * MAX_VISIBLE_ITEMS
	for i in range(MAX_VISIBLE_ITEMS):
		var idx: int = base + i
		if idx < rows.size():
			_body_box.add_child(_make_arc_row(rows[idx], ITEM_KEYS[i], idx == _arc_selected_idx, idx))
		else:
			_body_box.add_child(_make_empty_row(ITEM_KEYS[i]))
	if page_count > 1:
		_body_box.add_child(_make_arc_pager(page_count))
	_body_box.add_child(_make_spacer(6))
	_body_box.add_child(_make_muted_label("Q dismiss  ·  R accept  ·  E refresh  ·  GHJKL; pick  ·  A/D page", 11))

## Builds Arc tab rows: arc-quest offers first, then unfired flags (by score
## desc), then fired flags. (The manifold "on-edge" boost lives on C; X has no
## edge scope, so rows sort purely by score then fired-state.)
func _arc_rows() -> Array:
	var rows: Array = []
	var qm = _arc_quest_manager()
	if qm == null:
		return rows
	if qm.has_method("get_story_offers"):
		for q in qm.get_story_offers():
			if q is Dictionary and str(q.get("category", "")) in ["ARC", "TUTORIAL"]:
				rows.append({"kind": "arc_quest", "data": q})

	if not qm.has_method("get_all_story_flags"):
		return rows

	var farm = InstrumentLocator.resolve_active_farm(self)
	var fired_set: Dictionary = {}
	if farm != null and "story_flags_fired" in farm:
		fired_set = farm.story_flags_fired

	var unfired: Array = []
	var fired: Array = []
	for flag in qm.get_all_story_flags():
		var fid := str(flag.get("id", ""))
		if fired_set.has(fid):
			fired.append({"kind": "flag_fired", "flag": flag})
		else:
			var pred_scores: Array = []
			for pred in flag.get("predicates", []):
				if pred is Dictionary:
					pred_scores.append({"pred": pred, "score": qm.evaluate_predicate_score(pred)})
			unfired.append({
				"kind": "flag_unfired",
				"flag": flag,
				"score": qm.evaluate_flag_score(flag),
				"pred_scores": pred_scores,
			})

	# Spine order: earliest act first, then score. Pure score-desc buried the
	# next SPINE gate (village_identity, act 4, low score pre-buildout) below
	# high-scoring side-branch beats and past the 6-row cap — three marathons
	# of agents never saw the buildout row and diagnosed the campaign as
	# deadlocked. "What's next" must lead the list.
	var by_spine = func(a, b):
		var aa := int(a.flag.get("act", 99))
		var ab := int(b.flag.get("act", 99))
		if aa != ab:
			return aa < ab
		# Within an act: spine before lane rows ("what's next" leads; the
		# What-Survives/Connects/Fades teaching ladders follow), then score.
		var a_lane: bool = StoryAtlas.lane_of(str(a.flag.get("display_name", "")))["lane"] != ""
		var b_lane: bool = StoryAtlas.lane_of(str(b.flag.get("display_name", "")))["lane"] != ""
		if a_lane != b_lane:
			return b_lane
		return float(a.score) > float(b.score)
	unfired.sort_custom(by_spine)
	for u in unfired: rows.append(u)
	for f in fired: rows.append(f)
	return rows

## Mouse parity for GHJKL; row selection (wave-4 sensor wall: rows had no
## click affordance at all, only the R-accept chip did — a mouse player
## could never pick WHICH row to accept). Clicking a row selects it, same
## as pressing its key chip's keyboard letter.
func _select_arc_row(idx: int) -> void:
	var rows: Array = _arc_rows()
	if idx < 0 or idx >= rows.size() or _arc_selected_idx == idx:
		return
	_arc_selected_idx = idx
	_refresh_body()


## Mouse parity for A/D paging (wave-3 sensor wall, reconfirmed wave-4: the
## "page N/M · A/D" footer was inert text). Two small clickable glyphs reuse
## the same _on_navigate() the A/D keys already call — one authority, no
## duplicated paging logic. Shared across every tab that pages via A/D (Arc,
## Self, Story, Guide — mouse-only campaign wave 15: Arc alone had this, the
## other three tabs' own _on_navigate() cases were still mouse-unreachable).
func _make_nav_pager(label_text: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var prev_lbl := _make_muted_label("◀", 11)
	prev_lbl.name = "NavPagerPrev"
	ClickWire.attach(prev_lbl, _on_navigate.bind(Vector2i(-1, 0)))
	row.add_child(prev_lbl)
	# AUTOWRAP_OFF: this label sits in a shrink-to-fit centered HBoxContainer
	# with no width budget — an autowrap label in that layout collapses to a
	# near-zero minimum width and wraps after nearly every character.
	var page_lbl := _make_muted_label(label_text, 10)
	page_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(page_lbl)
	var next_lbl := _make_muted_label("▶", 11)
	next_lbl.name = "NavPagerNext"
	ClickWire.attach(next_lbl, _on_navigate.bind(Vector2i(1, 0)))
	row.add_child(next_lbl)
	return row

func _make_arc_pager(page_count: int) -> Control:
	return _make_nav_pager("page %d/%d" % [_arc_page + 1, page_count])


func _make_arc_row(entry: Dictionary, key_str: String, selected: bool, idx: int) -> Control:
	var kind := str(entry.get("kind", ""))
	var row := PanelContainer.new()
	row.name = "ArcRow_%d" % idx
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_width_left = 4 if selected else 1
	if kind == "arc_quest":
		sb.bg_color = Color(0.08, 0.12, 0.10, 0.92) if not selected else Color(0.12, 0.20, 0.14, 0.95)
		sb.border_color = Color(0.3, 0.6, 0.4, 0.6) if not selected else Color(0.5, 0.9, 0.55, 0.95)
	elif kind == "flag_fired":
		sb.bg_color = Color(0.08, 0.10, 0.10, 0.85) if not selected else Color(0.12, 0.16, 0.14, 0.95)
		sb.border_color = Color(0.3, 0.5, 0.4, 0.45) if not selected else COLOR_ARC_FIRED
	else:
		sb.bg_color = Color(0.10, 0.10, 0.13, 0.85) if not selected else Color(0.18, 0.16, 0.10, 0.95)
		sb.border_color = Color(0.5, 0.45, 0.35, 0.5) if not selected else COLOR_ARC_UNFIRED
	row.add_theme_stylebox_override("panel", sb)
	ClickWire.attach(row, _select_arc_row.bind(idx))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	row.add_child(vbox)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(top_hbox)
	top_hbox.add_child(_make_key_chip(key_str))

	if kind == "arc_quest":
		var data: Dictionary = entry.get("data", {})
		var badge := Label.new()
		badge.text = "[QUEST]"
		badge.add_theme_font_size_override("font_size", 11)
		badge.add_theme_color_override("font_color", Color(0.5, 0.9, 0.55, 0.95))
		badge.custom_minimum_size = Vector2(60, 0)
		top_hbox.add_child(badge)
		var body_lbl := Label.new()
		body_lbl.text = str(data.get("body", str(data.get("source_flag", "campaign quest"))))
		body_lbl.add_theme_font_size_override("font_size", 12)
		body_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_TAB_ACTIVE if selected else UIStyleFactory.COLOR_ITEM_IDLE)
		body_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if selected else TextServer.AUTOWRAP_OFF
		body_lbl.clip_text = not selected
		top_hbox.add_child(body_lbl)
		if selected:
			var hint_str: String = str(data.get("hint", data.get("tutorial_hint", "")))
			if hint_str != "":
				var hint_lbl := Label.new()
				hint_lbl.text = "    hint: %s" % hint_str
				hint_lbl.add_theme_font_size_override("font_size", 11)
				hint_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
				hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				vbox.add_child(hint_lbl)
			# d1-01: the literalist's line — the actual firing rule in plain math,
			# hand-authored per quest def but dimmer/smaller than the flavor body above.
			var math_note_str: String = str(data.get("math_note", ""))
			if math_note_str != "":
				var math_lbl := Label.new()
				math_lbl.text = "    math: %s" % math_note_str
				math_lbl.add_theme_font_size_override("font_size", 10)
				math_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
				math_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				vbox.add_child(math_lbl)
		return row

	var flag: Dictionary = entry.get("flag", {})
	var act_n: int = int(flag.get("act", 0))
	var act_lbl := Label.new()
	# Lane tag: the What-Survives/Connects/Fades ladders were invisible as
	# lanes — 22 flags carried them only inside display_name prose.
	var lane_tag := StoryAtlas.lane_tag(str(flag.get("display_name", "")))
	act_lbl.text = ("act %d · %s" % [act_n, lane_tag]) if lane_tag != "" else "act %d" % act_n
	act_lbl.add_theme_font_size_override("font_size", 11)
	act_lbl.add_theme_color_override("font_color",
			LANE_COLORS.get(str(StoryAtlas.lane_of(str(flag.get("display_name", "")))["lane"]), COLOR_ARC_HEADER))
	act_lbl.custom_minimum_size = Vector2(48, 0)
	top_hbox.add_child(act_lbl)

	var name_lbl := Label.new()
	name_lbl.text = str(flag.get("display_name", flag.get("id", "?")))
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_TAB_ACTIVE if selected else UIStyleFactory.COLOR_ITEM_IDLE)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(name_lbl)

	if kind == "flag_fired":
		var fired_lbl := Label.new()
		fired_lbl.text = "✓ FIRED"
		fired_lbl.add_theme_font_size_override("font_size", 11)
		fired_lbl.add_theme_color_override("font_color", COLOR_ARC_FIRED)
		top_hbox.add_child(fired_lbl)
		return row

	# Unfired — show score + per-predicate breakdown. Percent-of-threshold
	# leads: the filament chip says "91%", so this must say 91% too (fleet #4
	# read "0.77/0.85" and "91%" as two different systems).
	var score: float = float(entry.get("score", 0.0))
	var score_lbl := Label.new()
	score_lbl.text = "%d%% %s (%.2f / 0.85)" % [int(round(clampf(score / 0.85, 0.0, 1.0) * 100.0)), _ratio_bar(score / 0.85, 6), score]
	score_lbl.add_theme_font_size_override("font_size", 11)
	score_lbl.add_theme_color_override("font_color", _score_color(score))
	top_hbox.add_child(score_lbl)

	if selected:
		var pred_scores: Array = entry.get("pred_scores", [])
		for ps in pred_scores:
			var pred: Dictionary = ps.get("pred", {})
			var ps_score: float = float(ps.get("score", 0.0))
			var pred_lbl := Label.new()
			pred_lbl.text = "    %s · %.2f %s" % [PredicateGloss.summary(pred, _arc_quest_manager()), ps_score, _ratio_bar(ps_score, 5)]
			pred_lbl.add_theme_font_size_override("font_size", 10)
			pred_lbl.add_theme_color_override("font_color", _score_color(ps_score))
			vbox.add_child(pred_lbl)
			# d1-02: the literal rule, generated from config — dimmer/smaller than the
			# player-voice summary above it (the math game's literalist deserves the formula).
			var formula_lbl := Label.new()
			formula_lbl.text = "        %s" % PredicateGloss.formula(pred, _arc_quest_manager())
			formula_lbl.add_theme_font_size_override("font_size", 9)
			formula_lbl.add_theme_color_override("font_color", UIStyleFactory.COLOR_MUTED)
			vbox.add_child(formula_lbl)

	return row

func _make_arc_chapter_header() -> Control:
	var lbl := _make_muted_label(_current_chapter_label(), 12)
	lbl.add_theme_color_override("font_color", Color(0.78, 0.72, 0.45, 0.95))
	return lbl

## Current chapter — StoryAtlas's contiguous-prefix current act, NOT max act
## fired: act-5's second_loop needs only an act-1 flag, so a player who closed
## a second loop in act 2 used to read "Chapter IV" here (act inflation).
func _current_chapter_label() -> String:
	var farm = InstrumentLocator.resolve_active_farm(self)
	var qm = _arc_quest_manager()
	var act := 0
	if farm != null and "story_flags_fired" in farm and qm != null and qm.has_method("get_all_story_flags"):
		act = StoryAtlas.current_act(farm.story_flags_fired, qm.get_all_story_flags())
	return "The Demos · %s" % StoryAtlas.chapter_for_act(act)

func _arc_inspect_text() -> String:
	var rows: Array = _arc_rows()
	if _arc_selected_idx < 0 or _arc_selected_idx >= rows.size():
		return ""
	var entry: Dictionary = rows[_arc_selected_idx]
	var kind := str(entry.get("kind", ""))
	if kind == "arc_quest":
		var data: Dictionary = entry.get("data", {})
		var body := str(data.get("body", str(data.get("source_flag", "campaign quest"))))
		var hint := str(data.get("hint", ""))
		var math_note := str(data.get("math_note", ""))
		var out := body
		if hint != "":
			out += "\nhint: %s" % hint
		if math_note != "":
			out += "\nmath: %s" % math_note
		return out
	var flag: Dictionary = entry.get("flag", {})
	var lines: Array[String] = []
	lines.append("%s · act %d" % [str(flag.get("display_name", flag.get("id", "?"))), int(flag.get("act", 0))])
	lines.append("The Demos · %s" % StoryAtlas.chapter_for_act(int(flag.get("act", 0))))
	if kind == "flag_fired":
		lines.append("✓ FIRED")
		return "\n".join(lines)
	# unfired — show predicate summaries + the literal formula beneath each (d1-02)
	for ps in entry.get("pred_scores", []):
		var pred: Dictionary = ps.get("pred", {})
		lines.append("· %s · %.2f" % [PredicateGloss.summary(pred, _arc_quest_manager()), float(ps.get("score", 0.0))])
		lines.append("    %s" % PredicateGloss.formula(pred, _arc_quest_manager()))
	return "\n".join(lines)

## Accept the selected arc/tutorial offer into active quests (R). Without this,
## arc offers could only be dismissed, never worked on — they would dead-end.
func _accept_selected_arc() -> void:
	var qm = _arc_quest_manager()
	if qm == null:
		return
	var rows: Array = _arc_rows()
	if _arc_selected_idx < 0 or _arc_selected_idx >= rows.size():
		return
	var entry: Dictionary = rows[_arc_selected_idx]
	if str(entry.get("kind", "")) != "arc_quest":
		return
	var data: Dictionary = entry.get("data", {})
	if qm.has_method("accept_quest") and qm.accept_quest(data):
		_refresh_body()

func _acknowledge_selected_arc() -> void:
	var qm = _arc_quest_manager()
	if qm == null:
		return
	var rows: Array = _arc_rows()
	if _arc_selected_idx < 0 or _arc_selected_idx >= rows.size():
		return
	var entry: Dictionary = rows[_arc_selected_idx]
	if str(entry.get("kind", "")) != "arc_quest":
		return
	var qid: int = int(entry.get("data", {}).get("id", -1))
	if qid >= 0 and qm.has_method("dismiss_story_offer"):
		qm.dismiss_story_offer(qid)
	_refresh_body()

func _ratio_bar(ratio: float, length: int) -> String:
	return OverlayChrome.ratio_bar(ratio, length)

func _score_color(score: float) -> Color:
	if score >= 0.85:
		return Color(0.5, 0.9, 0.55, 1.0)
	if score >= 0.5:
		return Color(0.85, 0.85, 0.5, 1.0)
	return UIStyleFactory.COLOR_MUTED

func _make_empty_row(key_str: String) -> Control:
	return OverlayChrome.empty_row(_make_key_chip(key_str))

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
		if tab == Tab.STORY:
			# Reset edge cursor when entering Story; ui_focus stays as last override (or argmax).
			_story_edge_idx = 0
		if tab == Tab.ARC:
			_ensure_arc_signal()  # live-refresh the timeline when a beat fires while open
	_render_all()

func _on_frame_changed(new_frame_id: String, _prev_frame_id: String) -> void:
	var target_tab: int = FRAME_TO_TAB.get(new_frame_id, Tab.SELF)
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
	# A/D = step INNER (items/pages within the active tab) — _on_navigate has
	# always implemented this per-tab (Arc paging, Self icon paging, Story
	# crawl, Guide paging) but was never wired to a keypress (wave-3 sensor
	# wall: the Arc tab's own "page 1/11 · A/D" footer did nothing on D).
	if keycode == KEY_A:
		_on_navigate(Vector2i(-1, 0))
		return true
	if keycode == KEY_D:
		_on_navigate(Vector2i(1, 0))
		return true
	var ctrl_item := InputBindingRegistry.plot_index_for_keycode(keycode, ITEM_KEYS.size())
	if ctrl_item >= 0:
		_select_item_in_tab(ctrl_item)
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
	if InputBindingRegistry.plot_index_for_keycode(keycode, ITEM_KEYS.size()) >= 0:
		return true
	for kc in TAB_BY_KEYCODE.keys():
		if kc == keycode:
			return true
	return false

func _select_item_in_tab(slot: int) -> void:
	match _current_tab:
		Tab.ARC:
			# GHJKL; selects an arc beat on the CURRENT page (A/D pages).
			var rows: Array = _arc_rows()
			var abs_idx: int = _arc_page * MAX_VISIBLE_ITEMS + slot
			if slot < MAX_VISIBLE_ITEMS and abs_idx < rows.size() and _arc_selected_idx != abs_idx:
				_arc_selected_idx = abs_idx
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
		Tab.GUIDE:
			_guide_item = wrapi(_guide_item + step, 0, GUIDE_ITEMS.size())
			_refresh_body()
		Tab.ARC:
			# Page the 6-row window; the selection follows onto the new page
			# so GHJKL; and QER always act on something visible.
			var rows: Array = _arc_rows()
			var max_page: int = max(0, int(float(maxi(rows.size(), 1) - 1) / float(MAX_VISIBLE_ITEMS)))
			var new_page: int = clampi(_arc_page + step, 0, max_page)
			if new_page != _arc_page:
				_arc_page = new_page
				_arc_selected_idx = clampi(_arc_selected_idx,
						_arc_page * MAX_VISIBLE_ITEMS,
						mini((_arc_page + 1) * MAX_VISIBLE_ITEMS, maxi(rows.size(), 1)) - 1)
				_refresh_body()
		_:
			pass

# =============================================================================
# SURFACE CONTRACT
# =============================================================================

func get_visible_data() -> Dictionary:
	var payload: Dictionary = {
		"tab": _current_tab,
		"frame_label": str(TAB_ROW[_current_tab].get("name", "")) if _current_tab < TAB_ROW.size() else "",
		"guide_section": str(GUIDE_ITEMS[_guide_item].get("id", "")) if _current_tab == Tab.GUIDE else "",
	}
	return payload

func get_transitions() -> Array:
	return [
		{"surface_id": "farm", "reason": "return to invoking surface"},
	]
