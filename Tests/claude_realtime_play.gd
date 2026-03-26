#!/usr/bin/env -S godot -s
extends SceneTree

## claude_realtime_play.gd - Real-time interactive gameplay testing
## Run with: godot --script res://Tests/claude_realtime_play.gd
##
## This script plays the game in REAL-TIME with visual display.
## Two play modes:
##   1. SENSIBLE - Methodical farming: explore→measure→pop, with overlays
##   2. CHAOS - Rapid random inputs, edge cases, stress testing
##
## Usage:
##   godot --script res://Tests/claude_realtime_play.gd [sensible|chaos|both]
##   Default: both (sensible first, then chaos)

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")

# ============================================================================
# CONFIGURATION
# ============================================================================

## Play mode: "sensible", "chaos", or "both"
var play_mode: String = "both"

## Duration settings (seconds)
var sensible_duration: float = 45.0   # Time for sensible play
var chaos_duration: float = 30.0      # Time for chaos play

## Action delays
var sensible_action_delay: float = 0.6  # Time between sensible actions
var chaos_action_delay: float = 0.08    # Time between chaos actions (FAST!)

# ============================================================================
# STATE
# ============================================================================

var farm = null
var player_shell = null
var input_handler = null
var overlay_manager = null
var terminal_pool = null
var economy = null
var active_biome_manager = null

var frame_count: int = 0
var scene_loaded: bool = false
var game_ready: bool = false
var playing: bool = false

var current_phase: String = ""
var phase_start_time: float = 0.0
var last_action_time: float = 0.0

# Stats tracking
var stats = {
	"explores": 0,
	"measures": 0,
	"pops": 0,
	"gates_applied": 0,
	"overlays_opened": 0,
	"mode_switches": 0,
	"errors": [],
	"interesting_events": []
}

# Chaos mode state
var chaos_keys: Array = []
var chaos_key_index: int = 0


func _init():
	print("")
	print("=" .repeat(70))
	print("  CLAUDE REALTIME PLAY - SpaceWheat Interactive Testing")
	print("=".repeat(70))
	print("")

	# Parse command line args
	var args = OS.get_cmdline_args()
	for arg in args:
		if arg == "sensible":
			play_mode = "sensible"
		elif arg == "chaos":
			play_mode = "chaos"
		elif arg == "both":
			play_mode = "both"

	print("Play mode: %s" % play_mode.to_upper())
	print("")


func _process(delta: float) -> bool:
	frame_count += 1

	# Load scene
	if frame_count == 5 and not scene_loaded:
		_load_scene()
		return false

	# Wait for game
	if not game_ready:
		return false

	# Play the game
	if playing:
		_play_frame(delta)

	return false


func _load_scene():
	print("Loading FarmView...")
	var scene = load("res://scenes/FarmView.tscn")
	if scene:
		var instance = scene.instantiate()
		root.add_child(instance)
		scene_loaded = true

		var boot = root.get_node_or_null("/root/BootManager")
		if boot:
			boot.game_ready.connect(_on_game_ready)
	else:
		print("ERROR: Failed to load FarmView.tscn")
		quit(1)


func _on_game_ready():
	if game_ready:
		return
	game_ready = true

	print("\nGame ready! Finding components...\n")
	_find_components()

	# Start playing
	_start_playing()


func _find_components():
	var farm_view = root.get_node_or_null("FarmView")
	if farm_view and "farm" in farm_view:
		farm = farm_view.farm
		if farm:
			economy = farm.economy
			terminal_pool = farm.terminal_pool if "terminal_pool" in farm else null
	var boot = root.get_node_or_null("/root/BootManager")
	if not farm and boot and "farm" in boot:
		farm = boot.farm
		if farm:
			economy = farm.economy
			terminal_pool = farm.terminal_pool if "terminal_pool" in farm else null

	player_shell = _find_node(root, "PlayerShell")
	if player_shell:
		overlay_manager = player_shell.get("overlay_manager")
		input_handler = player_shell.get_node_or_null("QuantumInstrumentInput")
		if not input_handler:
			for child in player_shell.get_children():
				if child.name == "QuantumInstrumentInput":
					input_handler = child
					break
	if not farm and input_handler and "farm" in input_handler:
		farm = input_handler.farm
		if farm:
			economy = farm.economy
			terminal_pool = farm.terminal_pool if "terminal_pool" in farm else null

	active_biome_manager = root.get_node_or_null("/root/ActiveBiomeManager")

	print("Components: Farm=%s Shell=%s Input=%s TerminalPool=%s" % [
		farm != null, player_shell != null, input_handler != null, terminal_pool != null
	])


func _find_node(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found = _find_node(child, target_name)
		if found:
			return found
	return null


# ============================================================================
# GAME CONTROL
# ============================================================================

func _start_playing():
	playing = true

	# Build chaos key list
	_build_chaos_keys()

	# Start first phase
	if play_mode == "sensible" or play_mode == "both":
		_start_phase("sensible")
	else:
		_start_phase("chaos")


func _start_phase(phase: String):
	current_phase = phase
	phase_start_time = Time.get_ticks_msec() / 1000.0
	last_action_time = phase_start_time

	print("")
	print("-".repeat(70))
	print("  PHASE: %s" % phase.to_upper())
	print("-".repeat(70))
	print("")

	# Ensure we're in play mode at start
	ToolConfig.set_mode("play")


func _play_frame(delta: float):
	var current_time = Time.get_ticks_msec() / 1000.0
	var phase_elapsed = current_time - phase_start_time
	var since_last_action = current_time - last_action_time

	# Check phase completion
	match current_phase:
		"sensible":
			if phase_elapsed >= sensible_duration:
				if play_mode == "both":
					_start_phase("chaos")
				else:
					_finish_playtest()
				return

			if since_last_action >= sensible_action_delay:
				_play_sensible_action()
				last_action_time = current_time

		"chaos":
			if phase_elapsed >= chaos_duration:
				_finish_playtest()
				return

			if since_last_action >= chaos_action_delay:
				_play_chaos_action()
				last_action_time = current_time


func _finish_playtest():
	playing = false

	print("")
	print("=".repeat(70))
	print("  PLAYTEST COMPLETE")
	print("=".repeat(70))
	print("")
	print("Stats:")
	print("  Explores: %d" % stats.explores)
	print("  Measures: %d" % stats.measures)
	print("  Pops: %d" % stats.pops)
	print("  Gates applied: %d" % stats.gates_applied)
	print("  Overlays opened: %d" % stats.overlays_opened)
	print("  Mode switches: %d" % stats.mode_switches)

	if stats.errors.size() > 0:
		print("")
		print("Errors found: %d" % stats.errors.size())
		for err in stats.errors:
			print("  - %s" % err)

	if stats.interesting_events.size() > 0:
		print("")
		print("Interesting events: %d" % stats.interesting_events.size())
		for evt in stats.interesting_events.slice(0, 10):
			print("  - %s" % evt)

	print("")
	print("=".repeat(70))

	# Exit after a moment
	var timer = Timer.new()
	root.add_child(timer)
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(func(): quit(0 if stats.errors.is_empty() else 1))
	timer.start()


# ============================================================================
# SENSIBLE PLAY - Methodical farming
# ============================================================================

## Sensible play state
var sensible_state = {
	"cycle_step": 0,        # 0=explore, 1=wait, 2=measure, 3=wait, 4=pop, 5=wait
	"terminals_explored": 0,
	"overlay_checked": false,
	"gates_tried": false,
	"lindblad_tried": false,
	"navigation_done": false,
	"plot_cursor": 0,
	"biome_cursor": 0
}

func _play_sensible_action():
	var step = sensible_state.cycle_step

	match step:
		0:  # EXPLORE
			_sensible_explore()
			sensible_state.cycle_step = 1

		1:  # Wait/navigate
			if not sensible_state.navigation_done and randf() < 0.3:
				_sensible_navigate()
				sensible_state.navigation_done = true
			else:
				sensible_state.navigation_done = false
				sensible_state.cycle_step = 2

		2:  # MEASURE
			_sensible_measure()
			sensible_state.cycle_step = 3

		3:  # Wait/check overlays
			if not sensible_state.overlay_checked and randf() < 0.2:
				_sensible_check_overlay()
				sensible_state.overlay_checked = true
			else:
				sensible_state.overlay_checked = false
				sensible_state.cycle_step = 4

		4:  # POP
			_sensible_pop()
			sensible_state.cycle_step = 5

		5:  # Wait/try gates or lindblad
			if not sensible_state.gates_tried and randf() < 0.15:
				_sensible_try_gates()
				sensible_state.gates_tried = true
			elif not sensible_state.lindblad_tried and randf() < 0.2:
				_sensible_try_lindblad()
				sensible_state.lindblad_tried = true
			else:
				sensible_state.gates_tried = false
				sensible_state.lindblad_tried = false
				sensible_state.terminals_explored += 1
				sensible_state.cycle_step = 0


func _sensible_explore():
	print("[SENSIBLE] Selecting Tool 3 (Probe)")
	_send_key(KEY_3)
	_select_sensible_plot()

	print("[SENSIBLE] Q = EXPLORE")
	_send_key(KEY_Q)
	stats.explores += 1


func _sensible_navigate():
	if randf() < 0.5:
		_cycle_sensible_plot()
	else:
		_cycle_sensible_biome()


func _sensible_measure():
	_select_sensible_plot()
	print("[SENSIBLE] E = MEASURE")
	_send_key(KEY_E)
	stats.measures += 1


func _sensible_pop():
	_select_sensible_plot()
	print("[SENSIBLE] R = POP")
	_send_key(KEY_R)
	stats.pops += 1


func _sensible_check_overlay():
	var overlays = [
		{"key": KEY_C, "name": "Quest Board"},
		{"key": KEY_V, "name": "Semantic Map"},
		{"key": KEY_N, "name": "Inspector"},
		{"key": KEY_K, "name": "Controls"}
	]
	var overlay = overlays[randi() % overlays.size()]

	print("[SENSIBLE] Opening overlay: %s" % overlay.name)
	_send_key(overlay.key)
	stats.overlays_opened += 1

	# Close immediately (frame timing handles delay)
	print("[SENSIBLE] Closing overlay with ESC")
	_send_key(KEY_ESCAPE)


func _sensible_try_gates():
	print("[SENSIBLE] Selecting Tool 1 (Unitary/Gates)")
	_send_key(KEY_1)
	_select_sensible_plot()

	var gates = ["Q (Pauli-X)", "E (Hadamard)", "R (Pauli-Z)"]
	var keys = [KEY_Q, KEY_E, KEY_R]
	var idx = randi() % 3

	print("[SENSIBLE] Applying gate: %s" % gates[idx])
	_send_key(keys[idx])
	stats.gates_applied += 1

	# Switch back to probe
	_send_key(KEY_3)


func _sensible_try_lindblad():
	print("[SENSIBLE] Selecting Tool 2 (Lindblad)")
	_send_key(KEY_2)
	_select_sensible_plot()

	print("[SENSIBLE] Q = DRAIN")
	_send_key(KEY_Q)
	stats.interesting_events.append("Attempted Lindblad drain")

	# Switch back to probe
	_send_key(KEY_3)


# ============================================================================
# CHAOS PLAY - Break everything!
# ============================================================================

func _build_chaos_keys():
	# All the keys we might press
	chaos_keys = [
		# Tool selection
		KEY_1, KEY_2, KEY_3, KEY_4,
		# Actions
		KEY_Q, KEY_E, KEY_R, KEY_F,
		# Biome keys
		KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P,
		# Plot keys
		KEY_J, KEY_K, KEY_L, KEY_SEMICOLON, KEY_APOSTROPHE,
		# Overlays
		KEY_C, KEY_V, KEY_B, KEY_N, KEY_K,
		# Mode switch
		KEY_TAB,
		# ESC (but not too often)
		KEY_ESCAPE
	]


func _play_chaos_action():
	# Weighted random - some actions more likely than others
	var action_roll = randf()

	if action_roll < 0.3:
		# 30% - Rapid tool switching + QER
		_chaos_rapid_tool_qer()
	elif action_roll < 0.5:
		# 20% - Navigation spam
		_chaos_navigation_spam()
	elif action_roll < 0.65:
		# 15% - Overlay rapid toggle
		_chaos_overlay_spam()
	elif action_roll < 0.75:
		# 10% - Mode switching
		_chaos_mode_switch()
	elif action_roll < 0.85:
		# 10% - Location key spam
		_chaos_location_spam()
	else:
		# 15% - Pure random key
		_chaos_random_key()


func _chaos_rapid_tool_qer():
	var tool = randi() % 4 + 1
	print("[CHAOS] Tool %d → QER spam" % tool)

	_send_key(KEY_1 + tool - 1)

	# Rapid fire QER
	for i in range(randi() % 5 + 1):
		var action_key = [KEY_Q, KEY_E, KEY_R][randi() % 3]
		_send_key(action_key)

		match action_key:
			KEY_Q: stats.explores += 1
			KEY_E: stats.measures += 1
			KEY_R: stats.pops += 1


func _chaos_navigation_spam():
	var nav_keys = [KEY_J, KEY_K, KEY_L, KEY_SEMICOLON, KEY_APOSTROPHE]
	var count = randi() % 10 + 3

	print("[CHAOS] Plot-selection spam x%d" % count)

	for i in range(count):
		_send_key(nav_keys[randi() % 4])


func _chaos_overlay_spam():
	var overlay_keys = [KEY_C, KEY_V, KEY_B, KEY_N, KEY_K]
	var count = randi() % 4 + 2

	print("[CHAOS] Overlay spam x%d" % count)

	for i in range(count):
		var key = overlay_keys[randi() % overlay_keys.size()]
		_send_key(key)
		stats.overlays_opened += 1

		# Sometimes ESC, sometimes another overlay
		if randf() < 0.5:
			_send_key(KEY_ESCAPE)


func _chaos_mode_switch():
	print("[CHAOS] Mode switch spam")

	for i in range(randi() % 5 + 2):
		_send_key(KEY_TAB)
		stats.mode_switches += 1

		# Do something in the new mode
		var key = [KEY_Q, KEY_E, KEY_R, KEY_F][randi() % 4]
		_send_key(key)


func _chaos_location_spam():
	var loc_keys = [KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P]
	var count = randi() % 6 + 2

	print("[CHAOS] Location key spam x%d" % count)

	for i in range(count):
		_send_key(loc_keys[randi() % loc_keys.size()])


func _chaos_random_key():
	var key = chaos_keys[randi() % chaos_keys.size()]
	print("[CHAOS] Random key: %s" % _key_name(key))
	_send_key(key)


func _key_name(keycode: int) -> String:
	match keycode:
		KEY_1: return "1"
		KEY_2: return "2"
		KEY_3: return "3"
		KEY_4: return "4"
		KEY_Q: return "Q"
		KEY_E: return "E"
		KEY_R: return "R"
		KEY_F: return "F"
		KEY_T: return "T"
		KEY_Y: return "Y"
		KEY_U: return "U"
		KEY_I: return "I"
		KEY_O: return "O"
		KEY_P: return "P"
		KEY_J: return "J"
		KEY_C: return "C"
		KEY_V: return "V"
		KEY_B: return "B"
		KEY_N: return "N"
		KEY_K: return "K"
		KEY_L: return "L"
		KEY_SEMICOLON: return ";"
		KEY_APOSTROPHE: return "'"
		KEY_TAB: return "TAB"
		KEY_ESCAPE: return "ESC"
	return "Key_%d" % keycode


func _get_sensible_plot_keys() -> Array[int]:
	return [KEY_J, KEY_K, KEY_L, KEY_SEMICOLON, KEY_APOSTROPHE]


func _get_available_biome_keycodes() -> Array[int]:
	if active_biome_manager and active_biome_manager.has_method("get_slot_count") and active_biome_manager.has_method("get_slot_key"):
		var keys: Array[int] = []
		for slot_idx in range(int(active_biome_manager.get_slot_count())):
			var key_name = str(active_biome_manager.get_slot_key(slot_idx))
			var keycode = OS.find_keycode_from_string(key_name)
			if keycode != KEY_NONE and keycode != KEY_UNKNOWN:
				keys.append(keycode)
		if not keys.is_empty():
			return keys
	return [KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P]


func _select_sensible_plot() -> void:
	var plot_keys = _get_sensible_plot_keys()
	if plot_keys.is_empty():
		return
	var idx = int(sensible_state.plot_cursor) % plot_keys.size()
	var keycode = plot_keys[idx]
	print("[SENSIBLE] Select plot: %s" % _key_name(keycode))
	_send_key(keycode)


func _cycle_sensible_plot() -> void:
	var plot_keys = _get_sensible_plot_keys()
	if plot_keys.is_empty():
		return
	sensible_state.plot_cursor = (int(sensible_state.plot_cursor) + 1) % plot_keys.size()
	_select_sensible_plot()


func _cycle_sensible_biome() -> void:
	var biome_keys = _get_available_biome_keycodes()
	if biome_keys.is_empty():
		return
	sensible_state.biome_cursor = (int(sensible_state.biome_cursor) + 1) % biome_keys.size()
	var keycode = biome_keys[int(sensible_state.biome_cursor)]
	print("[SENSIBLE] Switch biome: %s" % _key_name(keycode))
	_send_key(keycode)


# ============================================================================
# INPUT SIMULATION
# ============================================================================

func _send_key(keycode: int):
	var press = InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	press.echo = false

	_route_key_event(press)

	# Release
	var release = InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	release.echo = false
	_route_key_event(release)


func _route_key_event(event: InputEventKey) -> void:
	var viewport: Viewport = root
	if player_shell and player_shell.has_method("_input"):
		player_shell._input(event)
		if viewport and viewport.is_input_handled():
			return
	if input_handler and input_handler.has_method("_unhandled_key_input"):
		input_handler._unhandled_key_input(event)
		if viewport and viewport.is_input_handled():
			return
	if input_handler and input_handler.has_method("_input"):
		input_handler._input(event)
