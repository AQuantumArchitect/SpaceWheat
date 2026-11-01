class_name ReelRunner
extends Node

## The Gallery, G1 (docs/ENGINE_FRONTIER.md, Part II): attract reels.
##
## A reel is DATA — a JSON file of timed presentation steps driven through the
## same action surface the rig uses. The piece plays itself: a kiosk loop for
## an exhibition screen, living documentation, trailer source, and (because
## measurement is seeded) a determinism regression theater — a reel that
## desyncs is a determinism bug found for free.
##
## Boot: set SW_REEL=<path> in the environment, or pass --reel=<path> as a
## user arg (godot -- --reel=Core/Gallery/reels/first_light.reel.json). WorldBuilder
## attaches the runner once the simulation starts. ANY key or click stops the
## reel and hands the session to the player — the kiosk exit.
##
## Reel format (JSON; one verb per step):
##   {"title": "...", "loop": true, "steps": [
##     {"caption": "text", "secs": 4.0},          — toast a line, hold for secs
##     {"wait": 2.0},                              — let the physics breathe
##     {"focus_biome": "StarterForest"},           — make a biome active
##     {"icon": {"biome": "StarterForest"}},       — inject the active icon
##     {"gate": {"gate": "hadamard", "biome": "...", "positions": [[0,0]]}},
##     {"measure": {"position": [0,0]}},           — Born sample + collapse
##     {"reap": true},                             — the seasonal rite
##     {"bridge": {"op": "build"|"braid"|"fuse", ...}}, — What Connects verbs
##     {"postcard": true}                          — self-documenting reel (G2)
##   ]}

var farm: Node = null
var _instrument = null
var _steps: Array = []
var _loop: bool = false
var _title: String = ""
var _running: bool = false


static func maybe_attach(farm_node: Node) -> void:
	# Attach a runner iff a reel is requested (env SW_REEL or --reel=path).
	var path := OS.get_environment("SW_REEL")
	if path == "":
		for arg in OS.get_cmdline_user_args():
			var s := str(arg)
			if s.begins_with("--reel="):
				path = s.substr(7)
				break
	if path == "" or farm_node == null:
		return
	if not FileAccess.file_exists(path):
		push_warning("ReelRunner: reel not found: %s" % path)
		return
	var runner := ReelRunner.new()
	runner.name = "ReelRunner"
	runner.farm = farm_node
	if runner.load_reel(path):
		farm_node.add_child(runner)


func load_reel(path: String) -> bool:
	# One JSON-load authority (slop knot #7); the warning below still covers
	# missing and wrong-shape reels, parse errors are additionally loud.
	var res: Dictionary = preload("res://Core/Config/JsonFileLoader.gd").load_json(
		path, {"context": "ReelRunner", "required": false})
	var data = res.data
	if not res.ok or not (data is Dictionary) or not (data.get("steps", null) is Array):
		push_warning("ReelRunner: malformed reel: %s" % path)
		return false
	_title = str(data.get("title", path.get_file()))
	_loop = bool(data.get("loop", false))
	# Recording mode: SW_REEL_ONCE=1 plays the reel exactly once, then quits the
	# whole app — so `--write-movie` finalizes a clean single-pass capture instead
	# of looping the kiosk forever.
	if OS.get_environment("SW_REEL_ONCE") != "":
		_loop = false
	_steps = data.get("steps")
	return true


func _ready() -> void:
	set_process_unhandled_input(true)
	_running = true
	_run()


func _unhandled_input(event: InputEvent) -> void:
	# The kiosk exit: any press hands the session to the player.
	if not _running:
		return
	var pressed: bool = (event is InputEventKey and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if pressed:
		_running = false
		_caption("⏹ reel ended — the farm is yours", 2.0)
		queue_free()


func _run() -> void:
	await get_tree().process_frame
	_instrument = InstrumentLocator.resolve_quantum_instrument(self)
	_caption("▶ %s" % _title, 2.5)
	await _sleep(2.5)
	while _running:
		for step in _steps:
			if not _running or not is_inside_tree():
				return
			await _do_step(step)
		if not _loop:
			break
		await _sleep(2.0)
	_running = false
	if OS.get_environment("SW_REEL_ONCE") != "":
		get_tree().quit()
		return
	queue_free()


func _do_step(step) -> void:
	if not (step is Dictionary):
		return
	if step.has("wait"):
		await _sleep(float(step["wait"]))
	elif step.has("caption"):
		var secs := float(step.get("secs", 4.0))
		_caption(str(step["caption"]), secs)
		await _sleep(secs)
	elif step.has("focus_biome"):
		var abm = get_node_or_null("/root/ActiveBiomeManager")
		if abm != null and abm.has_method("set_active_biome"):
			abm.set_active_biome(str(step["focus_biome"]))
		await _sleep(0.5)
	elif step.has("icon"):
		var icon_args: Dictionary = step["icon"] if step["icon"] is Dictionary else {}
		if _instrument != null:
			_instrument.action_inject_icon(str(icon_args.get("biome", "")))
		await _sleep(0.5)
	elif step.has("gate"):
		var g: Dictionary = step["gate"] if step["gate"] is Dictionary else {}
		if _instrument != null and _instrument.has_method("gate_inject"):
			_instrument.gate_inject(str(g.get("gate", "")), _positions(g))
		await _sleep(0.5)
	elif step.has("measure"):
		var m: Dictionary = step["measure"] if step["measure"] is Dictionary else {}
		var pos := _positions(m)
		if _instrument != null and not pos.is_empty():
			_instrument.action_measure(pos[0])
		await _sleep(0.5)
	elif step.has("reap"):
		if _instrument != null:
			_instrument.action_reap()
		await _sleep(0.5)
	elif step.has("bridge"):
		_do_bridge(step["bridge"] if step["bridge"] is Dictionary else {})
		await _sleep(0.5)
	elif step.has("postcard"):
		# Reels can document themselves (PostcardCapture, G2).
		var cap = get_tree().get_first_node_in_group("postcard_capture")
		if cap != null and cap.has_method("capture"):
			cap.capture()
		await _sleep(1.0)


func _do_bridge(cmd: Dictionary) -> void:
	if farm == null or not ("bridge_register" in farm) or farm.bridge_register == null:
		push_warning("[Reel] bridge step skipped — no bridge_register on farm")
		return
	var op := str(cmd.get("op", ""))
	var res: Dictionary = {}
	match op:
		"build":
			res = farm.bridge_register.build(
				cmd.get("a", {}) if cmd.get("a", {}) is Dictionary else {},
				cmd.get("b", {}) if cmd.get("b", {}) is Dictionary else {})
		"braid":
			res = farm.bridge_register.braid(int(cmd.get("id", 1)), str(cmd.get("end", "a")))
		"fuse":
			res = farm.bridge_register.fuse(int(cmd.get("id", 1)), randf())
	# A reel is a promise to the viewer — a silently failed op means the captions
	# narrate physics that never happened. Say so where the author will see it.
	if not bool(res.get("success", true)):
		push_warning("[Reel] bridge %s failed: %s" % [op, str(res.get("error", res.get("message", "?")))])
	else:
		print("[Reel] bridge %s ok" % op)


## Sibling: rig_listener._parse_positions — intentionally divergent, not slop:
## that one also accepts {x,y} dicts and "(x,y)" strings and only falls back to
## biome positions when the arg is absent; this one falls back whenever parsing
## yields nothing and honors a singular `position` key.
func _positions(d: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var raw = d.get("positions", [])
	if (not (raw is Array) or raw.is_empty()) and d.has("position"):
		raw = [d.get("position")]
	if raw is Array:
		for entry in raw:
			if entry is Array and entry.size() >= 2:
				out.append(Vector2i(int(entry[0]), int(entry[1])))
	if out.is_empty():
		var biome := str(d.get("biome", ""))
		if biome != "" and _instrument != null and _instrument.has_method("get_biome_positions"):
			for pos in _instrument.get_biome_positions(biome):
				out.append(pos)
	return out


func _caption(text: String, _secs: float) -> void:
	var shell = InstrumentLocator.resolve_player_shell(self)
	if shell != null and shell.has_method("show_hint"):
		shell.show_hint(text, 2, "")


func _sleep(secs: float) -> void:
	await get_tree().create_timer(maxf(0.05, secs)).timeout
