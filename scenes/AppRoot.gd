class_name AppRoot
extends Control

const GameRootClass = preload("res://scenes/GameRoot.gd")
const PlayerShellScene = preload("res://UI/PlayerShell.tscn")

@onready var _verbose = get_node_or_null("/root/VerboseConfig")

var game_root = null
var player_shell = null

# Re-entrancy guard for the boot pipeline. start_game() and restart_from_pending_boot()
# both create a GameRoot, and restart_from_pending_boot() nulls game_root then awaits two
# frames before start_game() runs — a window in which a SECOND trigger (a second
# continue/start key, _maybe_auto_start, another restart) would pass the bare
# `game_root == null` check and boot a duplicate GameRoot. Two GameRoots = two FarmUIs +
# two action bars stacked: one dead instance on top (stuck on Ace, captions never change,
# input swallowed) over a live one. This flag makes the pipeline single-instance.
var _booting: bool = false

var _title_layer: Control = null
var _title_hint: Label = null


func _ready() -> void:
	name = "AppRoot"
	add_to_group("app_root")
	# set_anchors_preset() alone keeps the current offsets to preserve the visual rect
	# under the new anchors -- for a freshly created (0,0)-sized Control added to an
	# ALREADY-sized root Window, that computes offsets equal to -window_size, which
	# exactly cancels the anchor scaling and permanently collapses size to (0,0). Only
	# the "_and_offsets_" form actually zeroes the offsets so the rect spans the parent.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS

	_install_emoji_font_fallback()
	_create_player_shell()
	if player_shell:
		await get_tree().process_frame
		if player_shell.has_method("warm_shell_surfaces"):
			player_shell.warm_shell_surfaces(true)
	_build_title()
	call_deferred("_maybe_auto_start")


## Bundle-deterministic emoji text: append Twemoji-Mozilla (COLR) to the default UI
## font's fallback chain. Without a bundled font every raw-Label emoji was a host-OS
## lottery — Windows DirectWrite sends FE0F-stripped symbols (☀ ⚙ ⛰ …) to monochrome
## Segoe UI Symbol and lacks newer glyphs (🪼) entirely, while the Linux dev box
## resolves them via Noto Color Emoji, so "works here, tofu there". Twemoji-Mozilla
## matches the twemoji SVGs the Sprite3D/EmojiDisplay path already draws, so text
## and sprite glyphs now come from ONE artwork family on every platform.
func _install_emoji_font_fallback() -> void:
	var emoji_font: FontFile = load("res://Assets/Fonts/TwemojiMozilla.ttf")
	if emoji_font == null:
		push_warning("AppRoot: TwemojiMozilla.ttf missing — emoji text falls back to OS fonts")
		return
	var base := ThemeDB.fallback_font
	if base == null:
		return
	var fallbacks: Array = base.fallbacks
	for f in fallbacks:
		if f == emoji_font:
			return
	fallbacks.append(emoji_font)
	base.fallbacks = fallbacks


func _input(event: InputEvent) -> void:
	# Pre-boot title input splits in two: the no-brainer keys (F / R / Enter /
	# Space / a click — "I just want to play") skip save detection entirely
	# and boot a fresh Demos run directly. Mashing through the title must
	# never land a player in someone else's mid-run save with no explanation
	# — that fork used to live behind these same keys via the X menu's RUN
	# tab, so two mashes of F could silently reload whatever save was newest
	# on disk. X is the one deliberate "show me more" key: it still opens the
	# full system menu (continue THIS save, pick a scenario, load a specific
	# slot). Once X is open the player_shell handles everything (including
	# ESC to close). Once a game has started, this handler stays out of the way.
	if game_root:
		return
	if not player_shell:
		return
	if _x_is_open():
		return

	var open_menu := false
	var start_fresh := false
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_X:
				open_menu = true
			KEY_F, KEY_R, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				start_fresh = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		start_fresh = true

	if open_menu:
		get_viewport().set_input_as_handled()
		_open_x_to_keep_tab()
	elif start_fresh:
		get_viewport().set_input_as_handled()
		_start_fresh_demo()


func start_game(request: Dictionary = {}) -> void:
	if _booting:
		if _verbose:
			_verbose.warn("boot", "⛔", "start_game ignored — a boot is already in progress")
		return
	if game_root and is_instance_valid(game_root):
		return

	_booting = true
	var boot_request = SaveStore.normalize_boot_request(request)
	_begin_loading()

	game_root = GameRootClass.new()
	game_root.name = "GameRoot"
	add_child(game_root)
	# GameRoot must sit BELOW PlayerShell in sibling order: both are full-rect
	# Control siblings of AppRoot (no CanvasLayer actually separates them, despite
	# a comment in _mount_quantum_visualization() claiming one does), and Godot's
	# same-layer input hit-testing picks the LATER sibling first. Left at the
	# default append order (added after PlayerShell), QuantumField3D's full-screen
	# MOUSE_FILTER_STOP rect silently ate every click meant for the HUD chrome
	# (menu row, hat row, biome row, Q/E/R/F chips) sitting visually on top of it
	# -- invisible while the field was stuck at size (0,0) (see dde8dcde), but a
	# real, severe regression the moment that bug was fixed and the field started
	# actually covering the screen.
	move_child(game_root, 0)
	await game_root.start(boot_request)

	# Boot pipeline finished — flip the shell into farm-attached mode so the
	# action bars, biome tab bar, FPS readout, etc. become visible.
	if player_shell and is_instance_valid(player_shell) and player_shell.has_method("set_farm_attached"):
		player_shell.set_farm_attached(true)
	_booting = false


func restart_from_pending_boot() -> void:
	if _booting:
		if _verbose:
			_verbose.warn("boot", "⛔", "restart_from_pending_boot ignored — a boot is already in progress")
		return
	# Hold the guard across the whole teardown — the two awaited frames below leave
	# game_root null, which is exactly the window a duplicate boot would slip through.
	_booting = true
	if game_root and is_instance_valid(game_root):
		game_root.queue_free()
		game_root = null
		await get_tree().process_frame
		await get_tree().process_frame
	if player_shell and is_instance_valid(player_shell):
		if player_shell.has_method("set_farm_attached"):
			player_shell.set_farm_attached(false)
		if player_shell.has_method("clear_farm_ui"):
			player_shell.clear_farm_ui()
	# Release immediately before start_game re-takes it — no await between, so the
	# handoff is atomic (start_game sets _booting = true synchronously at entry).
	_booting = false
	await start_game(_consume_pending_boot_request())


func return_to_title() -> void:
	if game_root and is_instance_valid(game_root):
		game_root.queue_free()
	game_root = null
	if player_shell and is_instance_valid(player_shell):
		if player_shell.has_method("set_farm_attached"):
			player_shell.set_farm_attached(false)
		if player_shell.has_method("clear_farm_ui"):
			player_shell.clear_farm_ui()
	if _title_layer:
		_title_layer.visible = true


func get_player_shell() -> Node:
	return player_shell


func _maybe_auto_start() -> void:
	var request = _peek_pending_boot_request()
	var should_start := RuntimeEnv.is_headless() or bool(request.get("_pending", false)) or RuntimeEnv.autostart()
	if should_start:
		await start_game(_consume_pending_boot_request())


func _peek_pending_boot_request() -> Dictionary:
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.pending_boot and gsm.pending_boot.requested:
		return {
			"_pending": true,
			"slot": gsm.pending_boot.slot,
			"scenario_id": gsm.pending_boot.scenario_id,
			"headless": RuntimeEnv.is_headless(),
		}
	return {
		"_pending": false,
		"slot": -1,
		"scenario_id": SaveStore.DEFAULT_SCENARIO_ID,
		"headless": RuntimeEnv.is_headless(),
	}


func _consume_pending_boot_request() -> Dictionary:
	var request = _peek_pending_boot_request()
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.pending_boot and gsm.pending_boot.requested:
		gsm.pending_boot.clear()
		if _verbose:
			_verbose.info("boot", ">", "AppRoot consumed pending boot request: slot=%d scenario=%s" % [
				int(request.get("slot", -1)),
				str(request.get("scenario_id", SaveStore.DEFAULT_SCENARIO_ID)),
			])
	request.erase("_pending")
	return SaveStore.normalize_boot_request(request)


## The title screen's no-brainer path. Bypasses save detection entirely — F,
## R, Enter, Space, or a click on the raw title always reaches a fresh "The
## Demos" run, never a leftover save. A player who wants to continue or load
## a specific slot presses X for the full system menu instead.
func _start_fresh_demo() -> void:
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and "session_lifecycle" in gsm:
		gsm.session_lifecycle.request_fresh_restart(false, SaveStore.DEFAULT_SCENARIO_ID)


func _open_x_to_keep_tab() -> void:
	# Title-screen entrypoint: open the X system surface so the player can
	# start a new game or load a save. Currently EscapeMenu serves as X.
	if not player_shell:
		return
	player_shell._open_escape_menu()


func _x_is_open() -> bool:
	if not player_shell:
		return false
	var om = player_shell.get("overlay_manager")
	if om == null:
		return false
	var x = om.get("escape_menu")
	if x == null or not is_instance_valid(x):
		return false
	if "is_active" in x:
		return bool(x.is_active)
	return bool(x.visible)


func _create_player_shell() -> void:
	# PlayerShell is app-lifetime. It's instantiated here, before any GameRoot
	# exists, so the X surface (and the rest of the shell-level overlays) are
	# reachable from the title screen — no separate title menu needed.
	# RuntimeMount.stage_ui later attaches farm-side things (FarmUI,
	# QuantumInstrumentInput, FarmSurface, SnapshotService) to this same shell.
	player_shell = PlayerShellScene.instantiate()
	player_shell.name = "PlayerShell"
	player_shell.z_index = 10
	add_child(player_shell)


func _build_title() -> void:
	# Control sibling of PlayerShell. z_index 11 sits above PlayerShell's
	# bare-Control z 10 (so the title shows even when farm chrome is hidden)
	# but below OverlayLayer's effective z 40 (so X / Z overlays open above
	# the title when the player invokes them).
	_title_layer = Control.new()
	_title_layer.name = "TitleLayer"
	_title_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_layer.z_index = 11
	add_child(_title_layer)
	_title_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Solid backdrop so the titlecard is centered against a clean field
	# (rather than whatever the empty viewport renders).
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.045, 0.04, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_layer.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Centered titlecard image, letterboxed to whatever viewport shape.
	var titlecard := TextureRect.new()
	titlecard.texture = load("res://Assets/spacewheat_titlecard.png")
	titlecard.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	titlecard.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	titlecard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_layer.add_child(titlecard)
	titlecard.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Hint floats near the bottom, centered horizontally on the right third
	# of the screen (anchor_left=2/3 → anchor_right=1.0 spans the right
	# third; CenterContainer centers the label inside that band).
	var hint_box := CenterContainer.new()
	hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_layer.add_child(hint_box)
	hint_box.anchor_left = 2.0 / 3.0
	hint_box.anchor_right = 1.0
	hint_box.anchor_top = 1.0
	hint_box.anchor_bottom = 1.0
	hint_box.offset_left = 0
	hint_box.offset_right = 0
	hint_box.offset_top = -78    # 10 px lower than the prior -88
	hint_box.offset_bottom = -22 # 10 px lower than the prior -32

	# Version stamp, bottom-left — the one place a player can read which build
	# they're on (bug reports quote it; itch builds carry the same string).
	var version_lbl := Label.new()
	version_lbl.text = BuildInfo.display()
	version_lbl.add_theme_font_size_override("font_size", 13)
	version_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.8, 0.55))
	version_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	version_lbl.add_theme_constant_override("outline_size", 4)
	version_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_layer.add_child(version_lbl)
	version_lbl.anchor_top = 1.0
	version_lbl.anchor_bottom = 1.0
	version_lbl.offset_left = 12
	version_lbl.offset_top = -32
	version_lbl.offset_bottom = -12

	_title_hint = Label.new()
	_title_hint.text = "Click — or F — to play  ·  X for menu"
	_title_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_hint.add_theme_font_size_override("font_size", 24)
	_title_hint.add_theme_color_override("font_color", Color(0.95, 0.97, 0.88, 1.0))
	_title_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_title_hint.add_theme_constant_override("outline_size", 8)
	hint_box.add_child(_title_hint)

	# Resize to viewport on layout changes (window resize / DPI). We also
	# explicitly set the size now so the first paint is correct even if
	# anchor resolution hasn't propagated through AppRoot yet.
	var vp_size := get_viewport_rect().size
	if vp_size.x > 0 and vp_size.y > 0:
		_title_layer.set_size(vp_size)
	get_viewport().size_changed.connect(_on_viewport_resized)

	if _verbose:
		var tex_ok := titlecard.texture != null
		_verbose.info("boot", "🎬", "Title built: layer=%s vp=%s titlecard=%s" % [
			str(_title_layer.size),
			str(vp_size),
			"loaded" if tex_ok else "MISSING"
		])


func _on_viewport_resized() -> void:
	if _title_layer and is_instance_valid(_title_layer):
		_title_layer.set_size(get_viewport_rect().size)


func _begin_loading() -> void:
	if _title_hint:
		_title_hint.text = "Loading..."
	if _title_layer:
		_title_layer.visible = true
	var boot_mgr = get_node_or_null("/root/BootManager")
	if not boot_mgr:
		return
	boot_mgr.core_systems_ready.connect(_on_boot_core_ready, CONNECT_ONE_SHOT)
	boot_mgr.visualization_ready.connect(_on_boot_viz_ready, CONNECT_ONE_SHOT)
	boot_mgr.game_ready.connect(_on_boot_game_ready, CONNECT_ONE_SHOT)


func _on_boot_core_ready() -> void:
	if _title_hint:
		_title_hint.text = "Loading world..."


func _on_boot_viz_ready() -> void:
	if _title_hint:
		_title_hint.text = "Starting..."


func _on_boot_game_ready() -> void:
	if _title_layer:
		_title_layer.visible = false
