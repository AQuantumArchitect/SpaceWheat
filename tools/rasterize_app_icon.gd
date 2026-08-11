extends SceneTree

## Rasterise Assets/icon.svg (and icon_small.svg) into every size the shipped
## artifacts need, using Godot's OWN ThorVG rasteriser — so the .ico frames and
## PWA icons are pixel-identical to what the engine draws for the window icon.
## Anything else (Inkscape, a Python SVG library) would be a second renderer and
## a second chance to disagree.
##
## Small frames deliberately use icon_small.svg: below ~48px the wheat glyph,
## equator and axis turn to mush, so those sizes get ball + ring + dot only.
##
## Run: godot --headless --path . -s tools/rasterize_app_icon.gd

const OUT_DIR := "res://Assets/icon_raster"
const SMALL_AT_OR_BELOW := 48

# Every size any shipped artifact asks for.
const SIZES: Array[int] = [16, 24, 32, 48, 64, 128, 144, 180, 256, 512, 1024]


func _init() -> void:
	var full := _read("res://Assets/icon.svg")
	var small := _read("res://Assets/icon_small.svg")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var failed := 0
	for size in SIZES:
		var svg: String = small if size <= SMALL_AT_OR_BELOW else full
		var img := Image.new()
		# The source viewBox is 512 square, so scale is just the ratio.
		var err := img.load_svg_from_string(svg, float(size) / 512.0)
		if err != OK:
			push_error("load_svg_from_string failed at %dpx: %d" % [size, err])
			failed += 1
			continue
		# ThorVG rounds; force the exact edge length so .ico frames are honest.
		if img.get_width() != size or img.get_height() != size:
			img.resize(size, size, Image.INTERPOLATE_LANCZOS)
		var path := "%s/icon_%d.png" % [OUT_DIR, size]
		err = img.save_png(path)
		if err != OK:
			push_error("save_png failed for %s: %d" % [path, err])
			failed += 1
			continue
		print("wrote %s (%dx%d, %s)" % [path, img.get_width(), img.get_height(),
			"small" if size <= SMALL_AT_OR_BELOW else "full"])

	if failed > 0:
		push_error("%d icon size(s) failed" % failed)
		quit(1)
		return
	print("all %d sizes rasterised" % SIZES.size())
	quit(0)


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("cannot open %s" % path)
		quit(1)
		return ""
	return f.get_as_text()
