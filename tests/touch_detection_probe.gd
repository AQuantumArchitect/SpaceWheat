extends SceneTree

var RE = load("res://Core/Config/RuntimeEnv.gd")

func _init() -> void:
	var ok := true
	ok = ok and RE.touch_from(true, false)
	ok = ok and RE.touch_from(false, true)
	ok = ok and RE.touch_from(true, true)
	ok = ok and not RE.touch_from(false, false)
	# Plain headless run has no touchscreen.
	ok = ok and not RE.is_touch()
	print("TOUCH_PROBE_OK" if ok else "TOUCH_PROBE_FAIL")
	quit(0 if ok else 1)
