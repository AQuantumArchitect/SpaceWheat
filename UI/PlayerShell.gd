## PlayerShell - Player-level UI layer
## Handles:
## - Overlay/menu system (Z/X/C/V/B/N/M ring, ESC stack unwinds)
## - Player inventory/resource panel
## - Keyboard help, settings
## - Farm loading/switching (when implemented)
##
## This layer STAYS when farm changes

class_name PlayerShell
extends Control

# Access autoload safely (avoids compile-time errors)
@onready var _verbose = get_node_or_null("/root/VerboseConfig")

# QuantumHUDPanel REMOVED - content merged into InspectorOverlay (N key)
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const MenuSelectionRowClass = preload("res://UI/Widgets/MenuSelectionRow.gd")
const FpsDisplay = preload("res://UI/HUD/FpsDisplay.gd")

var current_farm_ui = null  # FarmUI instance (from scene)
var overlay_manager = null
var quest_manager: QuestManager = null
var farm: Node = null
var farm_ui_container: Control = null
var action_bar_manager = null  # ActionBarManager - manages bottom toolbars
var ui_context_controller: UIContextController = null
var layout_manager: Node = null  # UILayoutManager
var logger_config_panel = null  # Logger configuration UI
var snapshot_service = null  # Snapshot/diagnostics node (set by BootManager)
var quantum_instrument = null  # Unified action interface (set by BootManager)
var instrument_input = null  # Projection of current_farm_ui.instrument_input for diagnostics/tests
## cursor_layer (0=surface 1=frame 2=biome 3=plot) is owned by QII (the instrument),
## co-located with current_plot_idx. PlayerShell forwards the raw ring keys and
## paints from QII's cursor_layer_changed signal — it no longer holds the state.
var advanced_mode_enabled: bool = false
# quantum_hud_panel REMOVED - content merged into InspectorOverlay (N key)
var menu_row: MenuSelectionRowClass = null  # Bottom-stack ZXCVBNM ring (owned by ActionBarManager)
var fps_display: Control = null  # Top-left FPS projection display
var _hint_toast_stack: VBoxContainer = null  # Bottom-right stack of ephemeral hint toasts
var _quest_biome_connected: bool = false
var _overlay_open_frame: Dictionary = {}  # overlay_name -> Engine frame opened

## Unified Overlay Stack Management (replaces modal_stack)
var overlay_stack: OverlayStackManager = null
## Permanent bottom-of-stack sentinel. Makes gameplay a navigable surface-ring position.
var play_base: PlayBaseOverlay = null  # stack sentinel — NOT the farm container (UI/FarmView.gd)

## Global pause flag — driven by E (pause) / F (resume) peek in _input.
## See UI/Core/KEYBOARD_GRAMMAR.md "Mechanics — side-effect peek".
## Read by Farm._physics_process to short-circuit sim evolution.
var paused: bool = false
signal paused_changed(is_paused: bool)

# Debounce for the menu-swallow honesty toast (see the bleed-through guard).
var _last_swallow_toast_ms: int = -10000


## Public pause toggle for pointer chrome (the time-flow chip) — the mouse's E/F.
func toggle_paused() -> void:
	_set_global_paused(not paused)

## Farm-attached state. False at title (PlayerShell exists but no Farm yet);
## true once BootManager finishes wiring the runtime. Toggled by AppRoot via
## set_farm_attached(). Farm-bound chrome (action bars, biome tab bar, FPS,
## quantum mode indicator, touch buttons, the FarmUIContainer itself) is only
## visible when this is true. Shell-level overlays (X, Z) stay reachable
## either way.
var _farm_attached: bool = false


func _input(event: InputEvent) -> void:
	# Layer 1: High-priority input routing (overlays + shell actions).

	# Before the exclusive consume-or-fall-through chain runs, we peek at
	# E and F as side-effects (pause / resume). The peek does NOT consume
	# the event — primary verbs still fire through normal dispatch. See
	# UI/Core/KEYBOARD_GRAMMAR.md "Mechanics — side-effect peek".
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	# Side-effect peek: E pauses, F resumes. No set_input_as_handled,
	# no return — fall through to normal dispatch so tools/menus still
	# receive their primary E/F verb.
	if event.keycode == KEY_E:
		_set_global_paused(true)
	elif event.keycode == KEY_F:
		_set_global_paused(false)

	var stack_size = overlay_stack.size() if overlay_stack else 0
	_verbose.debug("input", "⌨️", "PlayerShell._input() KEY: %s, overlay_stack: %d" % [event.keycode, stack_size])

	# LAYER 1: Overlay input (highest priority) - uses unified OverlayStackManager
	if overlay_stack and not overlay_stack.is_empty():
		var top_overlay = overlay_stack.get_top()
		_verbose.debug("input", "→", "Routing to overlay: %s" % top_overlay.name)
		var consumed = overlay_stack.route_input(event)
		_verbose.debug("input", "→", "Overlay consumed: %s" % consumed)
		if consumed:
			_mark_input_handled()
			return

		# Bleed-through guard (one input authority). When a real menu is open above
		# the farm base, that menu owns the gameplay action keys. If its surface did
		# not claim the key, swallow it here so it can NOT fall through to the
		# main-game dispatcher and fire a phantom strike / plot-select / hat-switch.
		# Transparent magnifier overlays (B / BiomeInspector) are the explicit
		# exception: they pass QERF through to the plot beneath by design. ESC and
		# ring navigation (ZXCVBNM / WSAD) are never gameplay-action keys, so
		# back-out and surface-switching keep working while a menu is up.
		if _any_menu_open() and not _overlay_is_transparent(top_overlay) and _is_gameplay_action_key(event.keycode):
			_verbose.debug("input", "🚧", "Swallowed gameplay key %d — menu open, not a menu action" % event.keycode)
			# Honest swallow (fleet: "pressed 5, nothing changed" — the guard
			# ate it silently). Debounced so key-mash doesn't stack toasts.
			var now := Time.get_ticks_msec()
			if now - _last_swallow_toast_ms > 4000:
				_last_swallow_toast_ms = now
				show_hint("Menu open — Esc to act on the field.", 2)
			_mark_input_handled()
			return

	# Direct-pick keys anchor the instrument's internal cursor_layer (it drives
	# the plot-ring lifecycle: entering layer 3 auto-selects a plot, which
	# REVEALS its bubble). This must run only when the key actually reaches
	# gameplay — placed BEFORE overlay routing it fired behind open menus
	# (owner: "pressed G in X>I and the bubble appeared in the background").
	# Anchors do NOT mark the event as handled.
	if event is InputEventKey and instrument_input:
		var kc = event.keycode
		if kc in [KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B, KEY_N, KEY_M]:
			instrument_input.set_cursor_layer(0)
		elif kc in [KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]:
			instrument_input.set_cursor_layer(1)
		elif kc in [KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P]:
			instrument_input.set_cursor_layer(2)
		elif kc in [KEY_G, KEY_H, KEY_J, KEY_K, KEY_L, KEY_SEMICOLON]:
			instrument_input.set_cursor_layer(3)

	# LAYER 2: Shell actions
	if _handle_shell_action(event):
		_mark_input_handled()
		return

	# LAYER 3: Fall through to Farm._unhandled_input()


func _mark_input_handled() -> void:
	# During restart PlayerShell can receive input while not in tree.
	if not is_inside_tree():
		return
	var vp := get_viewport()
	if vp:
		vp.set_input_as_handled()


## Spawn an ephemeral corner-toast. importance: 1=blue, 2=teal, 3=gold.
## Importance < 2 is logged only; no toast is shown.
func show_hint(bbcode_text: String, importance: int = 1, path: String = "") -> void:
	if importance < 2:
		return
	if not _hint_toast_stack or not is_inside_tree():
		return
	var toast := HintToast.new()
	_hint_toast_stack.add_child(toast)
	toast.show_text(bbcode_text, importance, path)


## Returns the most-recently-spawned live toast, or null.
func _topmost_toast() -> HintToast:
	if not _hint_toast_stack:
		return null
	var n: int = _hint_toast_stack.get_child_count()
	if n == 0:
		return null
	var node = _hint_toast_stack.get_child(n - 1)
	return node if node is HintToast else null


func _set_global_paused(value: bool) -> void:
	# Set the global sim-pause flag. Idempotent. Read by Farm._physics_process.
	if paused == value:
		return
	paused = value
	paused_changed.emit(paused)
	_verbose.info("input", "⏸" if value else "▶", "Sim %s" % ("paused" if value else "resumed"))
	# State change is player-visible in text too (fleet: "unclear if paused").
	show_hint("⏸ time paused — F plays on" if value else "▶ time flows", 2)


func _handle_shell_action(event: InputEvent) -> bool:
	# Handle shell-level actions (overlay toggles, menu)

	# All menus are mutually exclusive - opening one closes others.

	# Shell menus (Z, X, ESC): system-level panels
	# Game overlays (C, V, B, N, M): game content overlays
	# TAB: current-tool mode-cycle alias (only when no menu active)
	var keycode = event.keycode

	# Toast grammar: F flattens topmost toast, E pauses its decay — but ONLY when
	# the key would otherwise be idle. A toast must never shadow a primary verb
	# (anti-gating: no silent hindrance): not a modal's E/F (submenu slot, the
	# Cull/Trim/Break confirm chord), and not a frame-declared E/F verb (Icon-F
	# Track, Ace-F Fast-Fwd, Merchant-F Settle, …). The old form intercepted F
	# whenever ANY toast was live, so the first Track/confirm press silently
	# flattened a hint instead of acting ("press F twice" bug).
	var top_toast := _topmost_toast()
	var modal_owns_ef: bool = instrument_input != null and instrument_input.has_method("owns_ef_keys") and bool(instrument_input.owns_ef_keys())
	if top_toast != null and not modal_owns_ef:
		if keycode == KEY_F and ToolConfig.get_action(ToolConfig.get_current_frame(), "F").is_empty():
			top_toast.flatten()
			return true
		if keycode == KEY_E and ToolConfig.get_action(ToolConfig.get_current_frame(), "E").is_empty():
			top_toast.pause_decay()
			return true

	# ESC unwinds ONE level, innermost first:
	#   open overlay/menu → close it
	#   else a gameplay modal (submenu → pending confirm → plot selection) → unwind it
	#   else (nothing left) → open the system (escape) menu
	if keycode == KEY_ESCAPE:
		if _any_menu_open():
			_close_all_menus()
			return true
		if instrument_input and instrument_input.has_method("try_escape_unwind") \
				and instrument_input.try_escape_unwind():
			return true
		_open_escape_menu()
		return true

	var menu_entry = MenuRegistry.get_menu_for_keycode(keycode)
	if not menu_entry.is_empty():
		var overlay_name = str(menu_entry.get("overlay_name", ""))
		var menu_group = str(menu_entry.get("menu_group", ""))
		if menu_group == "game":
			_toggle_farm_overlay(overlay_name)
		else:
			_toggle_shell_menu(overlay_name)
		return true

	# , / . are reserved per KEYBOARD_GRAMMAR.md "Selection layer (4 rings)" —
	# the cylinder's outer ring (ZXCVBNM) is reachable via WASD spin to
	# cursor_layer=0 + A/D, so ,/. would only duplicate that gesture.
	# Intentionally unhandled.

	# - / = (and Shift variants) — simulation stride/speed + resolution. Owned by
	# QII._unhandled_key_input → GranularityController; PlayerShell must NOT claim
	# them here or it shadows the real handler (the keys would go dead). Fall through.

	# [ / ] are reserved per KEYBOARD_GRAMMAR.md — WASD already crawls the
	# whole 4-0 / TYUIOP / GHJKL; selection block, so a separate cycle
	# pair next to TYUIOP would gain no functionality. Intentionally
	# unhandled here.

	# TAB only works when no menu is active
	if _any_menu_open():
		return false

	if keycode == KEY_TAB:
		_cycle_frame_hat(1)
		return true

	# WASD is handled by the early-pierce block in _input() — not here.

	return false


## Pin the crawl ring to the surface layer (0). Used when a menu opens. No-op if
## the instrument isn't wired yet (pre-boot).
func _pin_cursor_surface() -> void:
	if instrument_input and instrument_input.has_method("set_cursor_layer"):
		instrument_input.set_cursor_layer(0)


## Route a tapped/clicked action key (Q/E/R/F) to the same handler as the keyboard path.
## Connected to ActionPreviewRow.action_pressed for touch/mouse parity.
func _route_action_key(action_key: String) -> void:
	# Overlay first — mirrors the keyboard fallthrough order.
	if overlay_stack and not overlay_stack.is_empty():
		var top = overlay_stack.get_top()
		if top and top.has_method("handle_action") and top.handle_action(action_key):
			return
	# No overlay — route to instrument actions (gameplay Q/E/R/F).
	if instrument_input and instrument_input.has_method("invoke_action"):
		instrument_input.invoke_action(action_key)


## Cursor-layer paint hook. The amber active-ring border died with the WASD
## crawl (2026-07-08) — the only remaining render-side effect is the plot
## grid's ring state (selected-plot lifecycle visuals).
func _paint_cursor_layer(layer: int) -> void:
	var pgd = current_farm_ui.plot_grid_display if current_farm_ui and "plot_grid_display" in current_farm_ui else null
	if pgd and pgd.has_method("set_active_ring"):
		pgd.set_active_ring(layer == 3)


func _cycle_frame_hat(delta: int) -> void:
	# Used by TAB and by step_active_layer when WASD cursor is on the frame layer.
	if instrument_input and instrument_input.has_method("cycle_frame_hat"):
		instrument_input.cycle_frame_hat(delta)


# =============================================================================
# MENU MANAGEMENT (unified for all menus)
# =============================================================================

func _any_menu_open() -> bool:
	# Check if any menu (shell or farm) is currently open.
	# size() > 1 because FarmView is the permanent bottom (index 0) — it
	# doesn't count as "a menu open."
	if overlay_stack and overlay_stack.size() > 1:
		return true
	return false


## Keys that drive the live farm loop. While a (non-transparent) menu is open
## these must never leak past the menu into the main-game dispatcher.
## QERF = item axis · GHJKL; = plot select · TYUIOP = biome select ·
## 4-0 = hat frames · 1/2/3 = sub-mode. ZXCVBNM/WSAD/ESC are deliberately absent
## (ring navigation + back-out stay live with a menu up).
const _GAMEPLAY_ACTION_KEYS: Array = [
	KEY_Q, KEY_E, KEY_R, KEY_F,
	KEY_G, KEY_H, KEY_J, KEY_K, KEY_L, KEY_SEMICOLON,
	KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P,
	KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0,
	KEY_1, KEY_2, KEY_3,
]


func _is_gameplay_action_key(kc: int) -> bool:
	return kc in _GAMEPLAY_ACTION_KEYS


func _overlay_is_transparent(ov) -> bool:
	# A magnifier-only surface (e.g. BiomeInspector / B) declares itself transparent
	# so its keys pass through to the gameplay beneath instead of being swallowed.
	return ov != null and "is_transparent_overlay" in ov and ov.is_transparent_overlay


func _close_all_menus() -> void:
	# Close all open menus (shell and farm).
	if overlay_manager:
		overlay_manager.close_all_overlays()


func _open_escape_menu() -> void:
	# Open escape menu (closes other menus first).
	_close_all_menus()
	if overlay_manager:
		overlay_manager.open_overlay("escape_menu")
	_pin_cursor_surface()


func _toggle_shell_menu(menu_name: String) -> void:
	# Toggle a shell menu (Z=escape_menu/system, X=controls/playthrough).

	# Shell menus close all other menus when opening.
	if not overlay_manager:
		return

	match menu_name:
		"escape_menu":
			overlay_manager.toggle_overlay("escape_menu")

		"controls":
			overlay_manager.toggle_overlay("controls")

	_pin_cursor_surface()


func _toggle_farm_overlay(overlay_name: String) -> void:
	# Toggle a farm overlay (C, V, B, N keys).

	# Farm overlays close all other menus when opening.
	if not overlay_manager:
		return

	# Pre-boot: there is no farm to inspect. Refuse rather than opening an
	# overlay that would render against null data.
	if not _farm_attached:
		return

	var overlay = overlay_manager.get_overlay(overlay_name) if overlay_manager.has_overlay(overlay_name) else null
	if overlay and overlay_stack and overlay_stack.has_overlay(overlay):
		var opened_frame = int(_overlay_open_frame.get(overlay_name, -999999))
		var frame_delta = Engine.get_process_frames() - opened_frame
		# Guard against duplicate key/touch events causing open-then-instant-close flash.
		if frame_delta <= 1:
			_verbose.debug("ui", "⏱️", "Ignoring rapid re-toggle for '%s' (frame delta=%d)" % [overlay_name, frame_delta])
			return

	overlay_manager.toggle_overlay(overlay_name)
	if overlay and overlay_stack and overlay_stack.has_overlay(overlay):
		_overlay_open_frame[overlay_name] = Engine.get_process_frames()
	else:
		_overlay_open_frame.erase(overlay_name)
	_pin_cursor_surface()


func _cycle_menu_overlay(delta: int) -> void:
	# Cycle the surface ring: A/D on cursor_layer 0 (ZXCVBNM).
	# Includes "play" (FarmView) at index 0 — the full ring now wraps.
	if not overlay_manager or not overlay_stack:
		return

	var menus = MenuRegistry.get_top_level_menus()
	if menus.is_empty():
		return

	# PlayBase at top → play (index 0). Otherwise find the open registered overlay.
	var current_idx := 0
	var top = overlay_stack.get_top()
	if top and top != play_base:
		for i in range(menus.size()):
			var entry_name = str(menus[i].get("overlay_name", ""))
			if entry_name == "" or not overlay_manager.has_overlay(entry_name):
				continue
			if overlay_manager.get_overlay(entry_name) == top:
				current_idx = i
				break

	var n = menus.size()
	var next_idx = (current_idx + delta + n) % n
	var next_entry = menus[next_idx]
	var next_group = str(next_entry.get("menu_group", ""))
	var next_name  = str(next_entry.get("overlay_name", ""))

	match next_group:
		"play":
			overlay_manager.close_all_overlays()
		"game":
			_toggle_farm_overlay(next_name)
		_:
			_toggle_shell_menu(next_name)


func _ready() -> void:
	# Initialize player shell UI - children defined in scene
	_verbose.info("boot", "🎪", "PlayerShell initializing...")
	advanced_mode_enabled = _resolve_advanced_mode()

	# Add to group so overlay buttons can find us
	add_to_group("player_shell")

	# CRITICAL: Ensure PlayerShell fills its parent (FarmView)
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Process input even when game is paused (for ESC menu, etc.)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Create unified overlay stack manager (before any overlays)
	overlay_stack = OverlayStackManager.new()
	add_child(overlay_stack)
	_verbose.info("ui", "✅", "OverlayStackManager created")

	# Push the play sentinel as the permanent bottom of the stack. Makes
	# gameplay a navigable surface-ring position. Never popped; never
	# registered with overlay_manager (so toggle_overlay radio logic ignores it).
	play_base = PlayBaseOverlay.new()
	play_base.name = "PlayBase"  # anonymous stack bases make forensics unreadable
	add_child(play_base)
	overlay_stack.push_base(play_base)
	_verbose.info("ui", "🌾", "PlayBase pushed as permanent stack base")

	# Get reference to containers from scene
	farm_ui_container = get_node("FarmUIContainer")
	var overlay_layer = get_node("OverlayLayer")
	var action_bar_layer = get_node("ActionBarLayer")

	# CRITICAL: FarmUIContainer must pass input through to PlotGridDisplay/QuantumForceGraph
	farm_ui_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_verbose.info("ui", "✅", "FarmUIContainer mouse_filter set to IGNORE for plot/bubble input")

	# CRITICAL: ActionBarLayer needs explicit size for ActionBarManager to work
	# It has full anchors (0,0,1,1) which will maintain this size, but during _ready()
	# the anchors haven't taken effect yet. Set size to viewport size (what anchors will do).
	# Use set_deferred to avoid warning about opposite anchors.
	var viewport_size = get_viewport_rect().size
	action_bar_layer.set_deferred("size", viewport_size)
	_verbose.info("ui", "✅", "ActionBarLayer sized for action bar creation: %.0f × %.0f" % [viewport_size.x, viewport_size.y])

	# Create and initialize UILayoutManager
	layout_manager = UILayoutManager.new()
	add_child(layout_manager)

	# Create quest manager (before overlays, since overlays need it)
	quest_manager = QuestManager.new()
	add_child(quest_manager)
	_verbose.info("ui", "✅", "Quest manager created")

	# Subscribe to PlayerEventLog so importance-2+ entries spawn toasts.
	var player_event_log = get_node_or_null("/root/PlayerEventLog")
	if player_event_log and not player_event_log.event_added.is_connected(_on_player_event_added):
		player_event_log.event_added.connect(_on_player_event_added)

	# ═══════════════════════════════════════════════════════════════
	# CREATE ACTION BARS DIRECTLY IN ActionBarLayer
	# ═══════════════════════════════════════════════════════════════
	action_bar_manager = ActionBarManager.new()
	action_bar_manager.set_layout_manager(layout_manager)
	action_bar_manager.create_action_bars(action_bar_layer)

	# Wire action chip taps → same handlers as keyboard Q/E/R/F.
	var apr = action_bar_manager.get_action_row()
	if apr and apr.has_signal("action_pressed"):
		apr.action_pressed.connect(_route_action_key)

	_verbose.info("ui", "✅", "Action bars created")
	# ═══════════════════════════════════════════════════════════════

	# Create overlay manager and add to overlay layer
	overlay_manager = OverlayManager.new()
	overlay_layer.add_child(overlay_manager)

	# Setup overlay manager with proper dependencies
	overlay_manager.setup(layout_manager, quest_manager)

	# Connect overlay stack and overlay manager bidirectionally
	if overlay_stack:
		overlay_manager.set_overlay_stack(overlay_stack)

	# Initialize overlays (ZXCVBNM top-level menus; ESC opens/closes system menu)
	overlay_manager.create_overlays(overlay_layer)

	# Create logger config panel (debug tool, currently unbound from top-level keys)
	logger_config_panel = LoggerConfigPanel.new()
	overlay_layer.add_child(logger_config_panel)
	overlay_manager.register_overlay("logger", logger_config_panel)
	_verbose.info("ui", "✅", "Logger config panel created (unbound debug overlay)")

	# Create UI context controller after all bars/overlays are present.
	ui_context_controller = UIContextController.new()
	add_child(ui_context_controller)
	ui_context_controller.setup(action_bar_manager, overlay_stack, overlay_manager)

	# QuantumHUDPanel REMOVED - content merged into InspectorOverlay (N key)

	# MenuSelectionRow now lives at the bottom of the cylinder stack — owned
	# by ActionBarManager alongside the other 3 selection rings. Wire its
	# overlay_manager here so it can dispatch overlay toggles on click.
	if action_bar_manager and action_bar_manager.has_method("get_menu_row"):
		var menu_widget = action_bar_manager.get_menu_row()
		if menu_widget and menu_widget.has_method("set_overlay_manager"):
			menu_widget.set_overlay_manager(overlay_manager)
		menu_row = menu_widget

	# Create FPS display (top-left projection display)
	fps_display = FpsDisplay.new()
	fps_display.name = "FpsDisplay"
	overlay_layer.add_child(fps_display)
	_verbose.info("ui", "✅", "FPS display created")

	# Hint-toast stack (bottom-right corner; ephemeral pop-ups)
	_hint_toast_stack = VBoxContainer.new()
	_hint_toast_stack.name = "HintToastStack"
	_hint_toast_stack.alignment = BoxContainer.ALIGNMENT_END
	_hint_toast_stack.add_theme_constant_override("separation", 6)
	_hint_toast_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_toast_stack.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint_toast_stack.offset_left = -340
	_hint_toast_stack.offset_top = -260
	_hint_toast_stack.offset_right = -16
	_hint_toast_stack.offset_bottom = -120
	# Above every overlay tier (OverlayStackManager tops out at Z_TIER_SYSTEM 18 + stack size)
	_hint_toast_stack.z_index = 100
	overlay_layer.add_child(_hint_toast_stack)
	_apply_top_strip_layout()
	if layout_manager and layout_manager.has_signal("layout_changed"):
		InstrumentLocator._safe_connect(layout_manager.layout_changed, _on_layout_changed)

	# Connect overlay signals
	_connect_overlay_signals()

	# Default to title-screen mode: only shell overlays (X, Z) reachable; all
	# farm-bound chrome hidden until AppRoot calls set_farm_attached(true)
	# after the boot pipeline finishes.
	set_farm_attached(false)

	_verbose.info("ui", "✅", "Overlay manager created")
	_verbose.info("boot", "✅", "PlayerShell ready (shell-only; awaiting farm)")


func warm_shell_surfaces(force_refresh: bool = false) -> void:
	# Prewarm shell-level overlays and caches before title-screen exposure.
	# Safe to call after _ready; no-op if overlay manager is missing.
	if overlay_manager and overlay_manager.has_method("warm_shell_surfaces"):
		overlay_manager.warm_shell_surfaces(force_refresh)


func set_farm_attached(attached: bool) -> void:
	# Toggle visibility of every farm-bound chrome element. Called by AppRoot:
	#   - false at construction and on return-to-title
	#   - true after BootManager.boot_ui completes
	# Shell overlays (escape_menu, controls_overlay) stay independent — they're
	# children of overlay_manager and toggled by their own keys.
	_farm_attached = attached

	if farm_ui_container:
		farm_ui_container.visible = attached
	var action_bar_layer = get_node_or_null("ActionBarLayer")
	if action_bar_layer:
		action_bar_layer.visible = attached
	if menu_row:
		menu_row.visible = attached
	if fps_display:
		fps_display.visible = attached


func is_farm_attached() -> bool:
	return _farm_attached


func _resolve_advanced_mode() -> bool:
	var env_mode := RuntimeEnv.advanced_mode_tristate()
	if env_mode == 1:
		return true
	if env_mode == 0:
		return false
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and "current_state" in gsm and gsm.current_state:
		if "advanced_mode_enabled" in gsm.current_state:
			return bool(gsm.current_state.advanced_mode_enabled)
	return OS.is_debug_build()


func _on_layout_changed(_layout: Dictionary) -> void:
	_apply_top_strip_layout()


func _apply_top_strip_layout() -> void:
	var top_offset = 54.0
	var side_inset = 200.0
	var indicator_size = Vector2(200, 40)
	var _menu_row_height = 55.0

	if layout_manager:
		if layout_manager.has_method("get_resource_bar_height") and layout_manager.has_method("get_top_strip_gap"):
			top_offset = layout_manager.get_resource_bar_height() + layout_manager.get_top_strip_gap()
		if layout_manager.has_method("get_top_strip_side_inset"):
			side_inset = layout_manager.get_top_strip_side_inset()
		if layout_manager.has_method("get_quantum_indicator_size"):
			indicator_size = layout_manager.get_quantum_indicator_size()
		if layout_manager.has_method("get_action_row_height"):
			_menu_row_height = layout_manager.get_action_row_height()

	if fps_display:
		fps_display.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		fps_display.offset_left = -310
		fps_display.offset_top = 4
		fps_display.offset_right = -8
		fps_display.offset_bottom = 28


func _connect_overlay_signals() -> void:
	# Connect non-toolbar overlay signals that still matter at the shell layer.
	var quest_board = overlay_manager.get("quest_board")
	if quest_board:
		_verbose.info("ui", "✅", "Quest board signals connected")

func get_farm_ui():
	# Get the currently loaded FarmUI instance
	return current_farm_ui


func clear_farm_ui() -> void:
	# Remove any FarmUI / QuantumInstrumentInput / FarmSurface / SnapshotService
	# left over from the previous session so a fresh boot can re-attach cleanly.
	# PlayerShell itself stays alive (overlays, action bars, layout manager are
	# all preserved). Called by AppRoot.restart_from_pending_boot.
	if current_farm_ui and is_instance_valid(current_farm_ui):
		current_farm_ui.queue_free()
	current_farm_ui = null
	instrument_input = null
	farm = null
	if farm_ui_container:
		for child in farm_ui_container.get_children():
			child.queue_free()
	for child_name in ["QuantumInstrumentInput", "FarmSurface", "SnapshotService"]:
		var node = get_node_or_null(child_name)
		if node and is_instance_valid(node):
			node.queue_free()
	snapshot_service = null
	quantum_instrument = null


func load_farm_ui(farm_ui: Control) -> void:
	# Load an already-instantiated FarmUI into the farm container.

	# Called by BootManager.boot() in Stage 3C to add the FarmUI.
	# Action bars are already created in _ready(), so no reparenting needed.
	# Defensive: clear any leftover FarmUI before mounting the new one.
	if current_farm_ui and is_instance_valid(current_farm_ui):
		clear_farm_ui()
	current_farm_ui = farm_ui

	# Add to container
	if farm_ui_container:
		farm_ui_container.add_child(farm_ui)
		_verbose.info("ui", "✔", "FarmUI mounted in container")
		if layout_manager and farm_ui.has_method("inject_layout_manager"):
			farm_ui.inject_layout_manager(layout_manager)

	# Note: farm_setup_complete fires before instrument_input is created.
	# The actual connection is done by BootManager calling connect_to_quantum_input() later.
	# We don't connect here anymore to avoid the "instrument_input not ready" warning.
	if not farm_ui.has_signal("farm_setup_complete"):
		push_error("FarmUI missing farm_setup_complete signal!")
	else:
		_verbose.info("ui", "⏳", "Waiting for BootManager to create QuantumInstrumentInput...")

func connect_to_quantum_input() -> void:
	# Connect to QuantumInstrumentInput after it's created.

	# Called by BootManager after instrument_input is created and injected into farm_ui.
	# Wires the Musical Spindle input system to the UI components.
	var farm_ui = current_farm_ui
	if not farm_ui or not farm_ui.instrument_input:
		push_warning("connect_to_quantum_input called but instrument_input not ready!")
		return

	var local_instrument_input = farm_ui.instrument_input
	self.instrument_input = local_instrument_input

	# Cylinder outer-ring step: when WASD A/D fires on cursor_layer=0
	# (the ZXCVBNM surface ring), QII emits surface_ring_step_requested
	# and we route it to the existing menu-overlay cycle.
	if local_instrument_input.has_signal("surface_ring_step_requested"):
		if not local_instrument_input.surface_ring_step_requested.is_connected(_cycle_menu_overlay):
			local_instrument_input.surface_ring_step_requested.connect(_cycle_menu_overlay)

	# QII owns cursor_layer; repaint the active ring whenever it changes.
	if local_instrument_input.has_signal("cursor_layer_changed"):
		if not local_instrument_input.cursor_layer_changed.is_connected(_paint_cursor_layer):
			local_instrument_input.cursor_layer_changed.connect(_paint_cursor_layer)

	# Initial paint for the instrument's starting layer (signal only fires on change).
	_paint_cursor_layer(local_instrument_input.cursor_layer)

	# Connect quest_manager to economy (CRITICAL for quest completion!)
	if quest_manager and farm_ui.farm and farm_ui.farm.economy:
		quest_manager.connect_to_economy(farm_ui.farm.economy)
		_verbose.info("ui", "✅", "QuestManager connected to economy")
		_connect_quest_manager_to_biomes(farm_ui)
	# Wire farm reference for story-flag predicate evaluation
	if quest_manager and farm_ui.farm and quest_manager.has_method("connect_to_farm"):
		quest_manager.connect_to_farm(farm_ui.farm)

	# Progressive disclosure: hat/menu rows re-derive visibility from story flags
	# now (farm just attached) and on every future flag fire.
	if quest_manager and quest_manager.has_signal("story_flag_fired") \
			and not quest_manager.story_flag_fired.is_connected(_on_progression_flag_fired):
		quest_manager.story_flag_fired.connect(_on_progression_flag_fired)
	_refresh_ui_progression()

	if ui_context_controller:
		ui_context_controller.bind_quantum_input(instrument_input)
		ui_context_controller.bind_farm_ui(farm_ui)
		_verbose.info("ui", "✔", "UIContextController bound to QuantumInstrumentInput")


func _on_progression_flag_fired(_flag_id: String, _flag_data: Dictionary) -> void:
	_refresh_ui_progression()


## Rebuild the hat + menu button rows against current story progress.
## Visual-only disclosure: keys for hidden chrome keep working.
func _refresh_ui_progression() -> void:
	if action_bar_manager:
		var tool_row = action_bar_manager.get("tool_selection_row")
		if tool_row and tool_row.has_method("refresh_progression"):
			tool_row.refresh_progression()
		var m_row = action_bar_manager.get("menu_selection_row")
		if m_row and m_row.has_method("refresh_progression"):
			m_row.refresh_progression()


func _connect_quest_manager_to_biomes(farm_ui: Control) -> void:
	if _quest_biome_connected:
		return
	if not quest_manager or not farm_ui or not farm_ui.farm:
		return

	var local_instrument_input = farm_ui.instrument_input
	if not local_instrument_input:
		push_warning("_connect_quest_manager_to_biomes called before QuantumInstrumentInput ready")
		return

	var farm_ref = farm_ui.farm
	var abm = get_node_or_null("/root/ActiveBiomeManager")

	if abm and abm.has_signal("active_biome_changed"):
		var biome_callable = Callable(self, "_handle_active_biome_change").bind(farm_ref)
		InstrumentLocator._safe_connect(abm.active_biome_changed, biome_callable)
		var active_biome = abm.get_active_biome() if abm.has_method("get_active_biome") else ""
		if active_biome != "":
			biome_callable.call(active_biome, "")

	_quest_biome_connected = true


func _handle_active_biome_change(biome_name: String, _old_biome: String, farm_ref: Node) -> void:
	if not quest_manager or not farm_ref or not farm_ref.grid or not farm_ref.grid.has_biomes() or biome_name == "":
		return

	var biome = farm_ref.grid.get_biome(biome_name)
	if biome:
		quest_manager.connect_to_biome(biome)


# =============================================================================
# PLAYER EVENT TOAST — PlayerEventLog → HintToast for importance ≥ 2
# (Signal translation lives in PlayerEventBridge autoload.)
# =============================================================================

func _on_player_event_added(entry: Dictionary) -> void:
	var imp: int = int(entry.get("importance", 1))
	if imp < 2:
		return
	show_hint(str(entry.get("message", "")), imp, str(entry.get("path", "")))
