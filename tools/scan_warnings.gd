## scan_warnings.gd — force-load every .gd to trigger GDScript parse warnings.
## Run: godot --headless --script res://tools/scan_warnings.gd 2>&1
extends SceneTree

func _init() -> void:
	_scan_dir("res://")
	print("=== scan complete ===")
	quit()


func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not fname.begins_with("."):
			var full := path.trim_suffix("/") + "/" + fname
			if dir.current_is_dir():
				_scan_dir(full)
			elif fname.ends_with(".gd") and not full.contains("/.venv/") and not full.contains("/.godot/"):
				var _s = load(full)  # forces parse → emits SHADOWED_* warnings
		fname = dir.get_next()
