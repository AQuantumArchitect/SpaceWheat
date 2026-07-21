extends Node
# Dev-only headed screenshot harness. Runs SHOT_SCENE for a moment then saves a PNG
# so the (display-less) builder can SEE 3D output. Not shipped (dev tool).

func _ready() -> void:
	var scene := OS.get_environment("SHOT_SCENE")
	if scene != "" and ResourceLoader.exists(scene):
		add_child(load(scene).instantiate())
	await get_tree().create_timer(3.0).timeout
	var img := get_viewport().get_texture().get_image()
	var out := OS.get_environment("SHOT_OUT")
	if out == "":
		out = "res://_shot.png"
	img.save_png(out)
	print("SHOT_SAVED:", out, " ", img.get_width(), "x", img.get_height())
	get_tree().quit()
