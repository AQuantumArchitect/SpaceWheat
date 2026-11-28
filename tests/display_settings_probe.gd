extends SceneTree

## display_settings_probe.gd — display mode persistence (#150).
## Runs DisplaySettings against a temp config and a recording apply hook, so no
## real window changes. One DISP line per check.
##   godot --headless --audio-driver Dummy --script tests/display_settings_probe.gd
## tests/test_display_settings.py runs it.

const Script_ := preload("res://Core/Settings/DisplaySettings.gd")


func _init() -> void:
	call_deferred("_run")


func _emit(check: String, data: Dictionary) -> void:
	data["check"] = check
	print("DISP " + JSON.stringify(data))


func _make(path: String, applied: Array) -> Node:
	var ds: Node = Script_.new()
	ds.config_path = path
	ds._apply_to_window = func(mode: String) -> void: applied.append(mode)
	return ds


func _run() -> void:
	var path := OS.get_environment("SW_PROBE_USER_DIR_PREFIX").path_join("display_probe.cfg")
	DirAccess.remove_absolute(path)

	# Pre-existing audio key must survive.
	var seed := ConfigFile.new()
	seed.set_value("audio", "music_volume", 0.7)
	seed.save(path)

	var applied_a: Array = []
	var a := _make(path, applied_a)
	_emit("default", {"mode": a.load_saved_mode(), "fullscreen": a.is_fullscreen()})
	a.set_fullscreen(true)
	_emit("set", {"applied": applied_a, "live": a.current_mode()})
	a.toggle()
	a.toggle()
	_emit("toggle", {"applied": applied_a})

	# "Next boot": a fresh instance reads the file and applies it once.
	var applied_b: Array = []
	var b := _make(path, applied_b)
	b.apply(b.load_saved_mode())
	var cfg := ConfigFile.new()
	cfg.load(path)
	_emit("reload", {
		"stored": cfg.get_value("display", "window_mode", ""),
		"applied": applied_b,
		"music": cfg.get_value("audio", "music_volume", -1.0),
	})
	cfg.set_value("display", "window_mode", "garbage")
	cfg.save(path)
	_emit("garbage", {"mode": b.load_saved_mode()})
	quit(0)
