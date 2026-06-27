class_name GameRoot
extends Control

const FarmViewScene = preload("res://scenes/FarmView.tscn")

signal game_started(farm: Node)

var farm: Node = null
var farm_view: Control = null
var player_shell = null  # Borrowed from AppRoot — app-lifetime, never owned here
var quantum_viz: QuantumForceGraph = null
var _starting: bool = false
var _started: bool = false

@onready var _verbose = get_node_or_null("/root/VerboseConfig")


func _ready() -> void:
	name = "GameRoot"
	add_to_group("game_root")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS


func start(request: Dictionary = {}) -> Node:
	if _starting or _started:
		return farm
	_starting = true

	var boot_request := SaveStore.normalize_boot_request(request)
	var boot_mgr = get_node_or_null("/root/BootManager")
	if not boot_mgr:
		push_error("GameRoot: BootManager not found")
		_starting = false
		return null

	farm = await boot_mgr.boot_session(boot_request, self)
	if not farm:
		push_error("GameRoot: core boot failed")
		_starting = false
		return null

	_mount_farm_view(bool(boot_request.headless))
	if bool(boot_request.headless):
		farm_view.finalize_runtime_mount(true)
		_mark_started()
		return farm

	player_shell = _resolve_player_shell()
	if player_shell == null:
		push_error("GameRoot: PlayerShell not available — AppRoot must construct it before start()")
		_starting = false
		return null

	_mount_quantum_visualization()
	farm_view.attach_runtime(farm, player_shell, quantum_viz, false)
	farm_view.prepare_runtime_visuals(false)

	await boot_mgr.boot_runtime(farm, player_shell, quantum_viz)
	farm_view.finalize_runtime_mount(false)

	_maybe_show_welcome(farm, player_shell)
	_mark_started()
	return farm


## First-run onboarding: show the welcome / how-to-play splash once, before the player has
## been onboarded (tutorial_seen unset). Dismissing it begins the tutorial (WelcomeOverlay).
func _maybe_show_welcome(farm, shell) -> void:
	if farm == null or shell == null or not ("story_flags_fired" in farm):
		return
	# Rig automation skips the blocking splash (RIG_SKIP_WELCOME=1, set by rig_client). Treat
	# it as already-onboarded so headed automation matches headless: begin the tutorial now,
	# no modal in the way. Set RIG_SKIP_WELCOME=0 to exercise the splash itself.
	if OS.get_environment("RIG_SKIP_WELCOME") == "1":
		var qm = shell.quest_manager if "quest_manager" in shell else null
		if qm != null and qm.has_method("maybe_start_tutorial"):
			qm.maybe_start_tutorial(farm)
		return
	if farm.story_flags_fired.has("tutorial_seen"):
		return
	var om = shell.overlay_manager if "overlay_manager" in shell else null
	if om != null and om.has_method("open_overlay"):
		om.open_overlay("welcome")


func teardown_visuals() -> void:
	# PlayerShell is owned by AppRoot and survives GameRoot teardown — never
	# queue_free it here. AppRoot.restart_from_pending_boot calls
	# player_shell.clear_farm_ui() before re-entering start().
	if farm_view and is_instance_valid(farm_view) and farm_view.has_method("teardown_runtime"):
		farm_view.teardown_runtime()
	if quantum_viz and is_instance_valid(quantum_viz):
		quantum_viz.queue_free()
	player_shell = null
	quantum_viz = null


func _exit_tree() -> void:
	teardown_visuals()


func _mark_started() -> void:
	_starting = false
	_started = true
	game_started.emit(farm)
	if _verbose:
		_verbose.info("boot", ">", "GameRoot ready")


func _mount_farm_view(is_headless: bool) -> void:
	farm_view = FarmViewScene.instantiate()
	farm_view.name = "FarmView"
	add_child(farm_view)
	if farm_view.has_method("attach_runtime"):
		farm_view.attach_runtime(farm, null, null, is_headless)


func _resolve_player_shell() -> Node:
	# AppRoot owns PlayerShell across the app lifetime.
	var app_roots = get_tree().get_nodes_in_group("app_root")
	if app_roots.size() > 0 and app_roots[0].has_method("get_player_shell"):
		return app_roots[0].get_player_shell()
	# Fallback: group lookup directly on the shell.
	var shells = get_tree().get_nodes_in_group("player_shell")
	return shells[0] if shells.size() > 0 else null


func _mount_quantum_visualization() -> void:
	quantum_viz = QuantumForceGraph.new()
	quantum_viz.name = "QuantumForceGraph"
	add_child(quantum_viz)
	quantum_viz.top_level = true
	quantum_viz.position = Vector2.ZERO
	quantum_viz.z_index = 40
