extends SceneTree

## Drive the REAL UILayoutManager at small logical sizes and print JSON.
## Run: godot --headless --script tests/layout_touch_probe.gd

const Layout := preload("res://UI/Managers/UILayoutManager.gd")


func _case(size: Vector2, touch: bool) -> Dictionary:
	var lm = Layout.new()
	lm.viewport_size = size
	lm.is_touch_device = touch
	var modals := {}
	for mode in ["small", "medium", "large"]:
		var m: Vector2 = lm.get_modal_size(mode)
		modals[mode] = [m.x, m.y]
	var out := {
		"size": [size.x, size.y],
		"touch": touch,
		"modals": modals,
		"touch_min": lm.get_touch_min_size(),
		"action_row_h": lm.get_action_row_height(),
		"chip_h_30": lm.ensure_min_hit(30.0),
		"chip_h_60": lm.ensure_min_hit(60.0),
	}
	lm.free()
	return out


func _init() -> void:
	var cases := []
	for size in [Vector2(1280, 720), Vector2(1024, 600), Vector2(640, 360)]:
		for touch in [false, true]:
			cases.append(_case(size, touch))
	print(JSON.stringify({"cases": cases}))
	quit()
