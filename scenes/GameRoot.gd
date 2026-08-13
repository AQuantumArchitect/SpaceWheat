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
	# same fix as AppRoot._ready(): the "_and_offsets_" form is required so this
	# freshly created Control's rect actually spans its (already real-sized) parent
	# instead of baking in offsets that cancel the anchor scaling back to zero.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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

	var headless := bool(boot_request.headless)
	_mount_farm_view(headless)

	player_shell = _resolve_player_shell()
	if player_shell == null:
		# Bare boot with no shell (a non-AppRoot headless smoke that never built one):
		# finalize the farm world and stop — there is nothing to drive.
		farm_view.finalize_runtime_mount(headless)
		_mark_started()
		return farm

	# ONE boot path, headless or headed: stage the shell + instrument against the SAME
	# app-owned PlayerShell a human drives, so the rig shares the real UI instead of
	# hand-mounting a parallel one. The visualization is the only headed-exclusive step
	# (no render target headless); boot_runtime + FarmView no-op the viz wiring there.
	if not headless:
		_mount_quantum_visualization()
	farm_view.attach_runtime(farm, player_shell, quantum_viz, headless)
	farm_view.prepare_runtime_visuals(headless)

	await boot_mgr.boot_runtime(farm, player_shell, quantum_viz)
	farm_view.finalize_runtime_mount(headless)

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
	if RuntimeEnv.skip_welcome():
		var qm = shell.quest_manager if "quest_manager" in shell else null
		if qm != null and qm.has_method("maybe_start_tutorial"):
			qm.maybe_start_tutorial(farm)
		return
	if farm.story_flags_fired.has("tutorial_seen"):
		_show_boot_recap(farm, shell)
		return
	var om = shell.overlay_manager if "overlay_manager" in shell else null
	if om != null and om.has_method("open_overlay"):
		om.open_overlay("welcome")


## Returning-player bookend: one warm toast placing them back in their story —
## the next beat's act + name and how many contracts are open. No modal.
func _show_boot_recap(farm_ref, shell) -> void:
	if shell == null or not shell.has_method("show_hint"):
		return
	var qm = shell.quest_manager if "quest_manager" in shell else null
	if qm == null:
		return
	var bits: Array[String] = []
	if qm.has_method("get_all_story_flags") and "story_flags_fired" in farm_ref:
		var best_score := -1.0
		var best_flag: Dictionary = {}
		for flag in qm.get_all_story_flags():
			if not (flag is Dictionary):
				continue
			if farm_ref.story_flags_fired.has(str(flag.get("id", ""))):
				continue
			var s: float = qm.evaluate_flag_score(flag)
			if s > best_score:
				best_score = s
				best_flag = flag
		if not best_flag.is_empty():
			bits.append("Act %d — [b]%s[/b] (%d%%)" % [int(best_flag.get("act", 0)),
					str(best_flag.get("display_name", best_flag.get("id", ""))),
					int(clampf(best_score / 0.85, 0.0, 1.0) * 100.0)])
	if qm.has_method("get_active_quests"):
		var n: int = qm.get_active_quests().size()
		if n > 0:
			bits.append("%d contract%s open" % [n, "" if n == 1 else "s"])
	if bits.is_empty():
		return
	shell.show_hint("🌾 " + "  ·  ".join(bits), 2)


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
	_run_boot_env_hooks()


## The env hooks that fire once the game is actually up, in order.
##
## SW_LOAD_PATH used to live INSIDE _dev_screenshot(), which meant "load this
## checkpoint into the live field" was only reachable by ALSO asking for a
## screenshot — and the screenshot quits the game the moment it lands. So the
## richest state the game can be in (a late-act save: several biomes, many live
## registers, the full coupling graph) could be photographed but never simply
## RUN. That is precisely the state a performance pass has to measure, so the
## load is its own step now and the screenshot composes on top of it.
func _run_boot_env_hooks() -> void:
	if OS.has_environment("SW_LOAD_PATH"):
		var gsm = get_node_or_null("/root/GameStateManager")
		if gsm != null and ("save_load" in gsm) and gsm.save_load != null:
			# load_and_apply_path re-points the view at the farm it builds
			# (SaveLoadCoordinator.rebind_view_to_farm) — this used to hand-roll that
			# re-point here, which left the real path-load lane rendering the pre-load
			# world for everyone who was not taking a dev screenshot (#519).
			await gsm.save_load.load_and_apply_path(OS.get_environment("SW_LOAD_PATH"))
			await get_tree().process_frame
	if OS.has_environment("SW_SHOT"):
		await _dev_screenshot()


func _dev_screenshot() -> void:
	# dev-only (SW_SHOT env): once the game is up, capture the live screen then quit,
	# so a display-less builder can SEE headed output.
	var _delay := OS.get_environment("SW_SHOT_DELAY")
	await get_tree().create_timer(float(_delay) if _delay.is_valid_float() else 4.5).timeout
	# SW_TAP_TEST=<reg>: simulate a real tap on the 3D field's register <reg> (default 0)
	# through the pick geometry, so the pick→node_clicked→handle_bubble_tap chain can be
	# verified headed. Waits for the game's response before the capture.
	if OS.has_environment("SW_TAP_TEST"):
		var f3d = get_node_or_null("QuantumField3D")
		if f3d != null and f3d.has_method("dev_tap_register"):
			var reg_env := OS.get_environment("SW_TAP_TEST")
			var reg := int(reg_env) if reg_env.is_valid_int() else 0
			var gp = f3d.dev_tap_register(reg)
			print("SW_TAP_TEST tapped grid_pos=", gp)
			await get_tree().create_timer(1.6).timeout
			# edge tap: the orb's outer half, where the old satellite-first pick order
			# used to steal the click and dive into a fractal world
			if f3d.has_method("dev_tap_register_edge"):
				var gpe = f3d.dev_tap_register_edge(reg)
				print("SW_TAP_TEST edge-tapped grid_pos=", gpe)
				await get_tree().create_timer(1.6).timeout
	# SW_TAP_PORTAL=<i>: click portal <i> to dive into that biome (fractal nav check).
	if OS.has_environment("SW_TAP_PORTAL"):
		var f3dp = get_node_or_null("QuantumField3D")
		if f3dp != null and f3dp.has_method("dev_tap_portal"):
			var pe := OS.get_environment("SW_TAP_PORTAL")
			var pidx := int(pe) if pe.is_valid_int() else 0
			print("SW_TAP_PORTAL dove to ", f3dp.dev_tap_portal(pidx))
			await get_tree().create_timer(2.0).timeout
	# SW_CHAIN_TEST=0,1[,2…]: simulate a chain-swipe across those register orbs to verify the
	# 3D swipe → chain_swiped → apply_chain_gate (bell/cluster) dispatch, headed.
	if OS.has_environment("SW_CHAIN_TEST"):
		var f3dc = get_node_or_null("QuantumField3D")
		if f3dc != null and f3dc.has_method("dev_chain"):
			var regs := []
			for part in OS.get_environment("SW_CHAIN_TEST").split(","):
				if part.strip_edges().is_valid_int():
					regs.append(int(part.strip_edges()))
			print("SW_CHAIN_TEST chained ", f3dc.dev_chain(regs))
			await get_tree().create_timer(1.6).timeout
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(OS.get_environment("SW_SHOT"))
		print("SW_SHOT_SAVED:", OS.get_environment("SW_SHOT"))
	get_tree().quit()


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


## 3D cognifold renderer toggle. The DEFAULT is now the 3D field (the sprint flip). Force the
## legacy 2D renderer with --classic-2d / SW_CLASSIC_2D (the fallback lane + 2D-regression
## harness, kept for one release); force 3D explicitly with --field3d / SW_FIELD_3D. An
## explicit 2D request always wins over an explicit 3D one.
func _field3d_enabled() -> bool:
	# Explicit overrides (2D wins ties): env first, then command-line + user args.
	if OS.has_environment("SW_CLASSIC_2D"):
		return false
	if OS.has_environment("SW_FIELD_3D"):
		return true
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if a == "--classic-2d":
			return false
		if a == "--field3d":
			return true
	return true  # DEFAULT: 3D cognifold field (--classic-2d falls back to the legacy 2D)


func _mount_quantum_visualization() -> void:
	# 3D cognifold renderer toggle (see _field3d_enabled). With it OFF the path below is
	# byte-for-byte the original 2D renderer.
	if _field3d_enabled():
		var field3d = load("res://Core/Visualization/QuantumField3D.gd").new()
		field3d.name = "QuantumField3D"
		add_child(field3d)
		# NOT top_level: a Control needs its parent's rect to resolve PRESET_FULL_RECT
		# anchors. GameRoot is full-rect, so the field fills it; the app HUD (PlayerShell)
		# is a plain Control sibling of GameRoot under AppRoot, NOT a CanvasLayer -- it
		# stays on top of the field purely because AppRoot.start_game() sibling-orders
		# GameRoot below it (move_child(game_root, 0)). Don't reorder GameRoot after
		# PlayerShell without also fixing that, or the field's full-screen
		# MOUSE_FILTER_STOP rect will eat every HUD click again.
		field3d.z_index = 0
		# quantum_viz stays null so RuntimeMount skips its QuantumForceGraph-only staging
		# (atlas batchers, layout_calculator, quantum_nodes). FarmView wires the 3D field
		# through its `field3d` slot instead — same node_clicked/chain_swiped/connect_to_farm
		# contract, so a tap in the 3D field dispatches through handle_bubble_tap exactly
		# like a 2D bubble tap.
		if farm_view:
			farm_view.field3d = field3d
		quantum_viz = null
		return
	quantum_viz = QuantumForceGraph.new()
	quantum_viz.name = "QuantumForceGraph"
	add_child(quantum_viz)
	quantum_viz.top_level = true
	quantum_viz.position = Vector2.ZERO
	quantum_viz.z_index = 40
