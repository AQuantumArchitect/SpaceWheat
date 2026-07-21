class_name CognifoldTraceView
extends Control
# Standalone reasoning-transparency instrument (NOT part of the game): loads an umwelt
# cognifold-trace JSON and renders that belief-field through SpaceWheat's 3D cognifold
# renderer (QuantumField3D), UNCHANGED, by wrapping the trace in a minimal farm/grid/biome
# whose viz_cache is the UmweltVizCache adapter. Run standalone:
#   DISPLAY=:0 SW_COGNIFOLD_TRACE=res://scratch_cognifold_sample.json \
#     SW_SHOT=/abs/out.png godot scenes/CognifoldTraceView.tscn
# Proves the thesis: the same cognifold that draws the farm draws a reasoning field —
# register = belief, Bloch point = value + confidence, edges = couplings.

const UmweltVizCacheScript = preload("res://Core/Visualization/UmweltVizCache.gd")
# CognifoldForecastField extends the shipped QuantumField3D and adds the forward self-forecast
# ladder; it degrades to the base renderer for any register whose gauge carries no forecast,
# so it is always safe to use here.
const QuantumField3DScript = preload("res://Core/Visualization/CognifoldForecastField.gd")
const DEFAULT_TRACE := "res://Core/Visualization/cognifold_forecast_grid.json"
const DEFAULT_FILMSTRIP := "res://Core/Visualization/cognifold_filmstrip"

var _field = null
var _vc = null                 # the live UmweltVizCache (swapped in place during filmstrip playback)
var _frames: Array = []        # parsed trace dicts, one per filmstrip frame (empty = single trace)
var _frame_idx := 0
var _play_t := 0.0             # tween position within the current frame pair [0,1)
var _frame_s := 1.2            # seconds per frame


## Minimal farm/grid/biome so QuantumField3D's farm-shaped read path resolves to our adapter
## with zero changes to the renderer. _biome_ok() only needs `viz_cache` + get_biome_type();
## _get_active_biome() falls through get_all_biomes() when ActiveBiomeManager doesn't know us.
class _Biome:
	var viz_cache
	var _name: String
	func _init(vc, nm: String) -> void:
		viz_cache = vc
		_name = nm
	func get_biome_type() -> String:
		return _name


class _Grid:
	var _biomes: Dictionary
	func _init(biomes: Dictionary) -> void:
		_biomes = biomes
	func get_all_biomes() -> Dictionary:
		return _biomes
	func get_biome(n):
		return _biomes.get(n)


## QuantumField3D.connect_to_farm(farm: Node) is typed Node, so the farm holder must be a Node
## (the grid/biome are plain RefCounted — accessed only as properties/methods).
class _Farm extends Node:
	var grid
	func _init(g) -> void:
		grid = g


func _ready() -> void:
	name = "CognifoldTraceView"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vc = UmweltVizCacheScript.new()
	_vc = vc
	# Precedence: SW_COGNIFOLD_TRACE_DIR (a dir of *.json frames → animated filmstrip) →
	# SW_COGNIFOLD_TRACE (a single trace file) → a PLAIN launch defaults to the committed live
	# filmstrip (the field animates as a real umwelt walk evolves), falling back to the single
	# forecast trace if the filmstrip is absent.
	var dir_env := OS.get_environment("SW_COGNIFOLD_TRACE_DIR")
	var file_env := OS.get_environment("SW_COGNIFOLD_TRACE")
	if dir_env == "" and file_env == "":
		dir_env = DEFAULT_FILMSTRIP
	if dir_env != "":
		_frames = _load_frames_dir(dir_env)
	if _frames.size() >= 2 and vc.load_frame_pair(_frames[0], _frames[1]):
		print("[cognifold] filmstrip frames=%d world='%s' registers=%d"
			% [_frames.size(), str(vc.world), vc.get_num_qubits()])
	else:
		_frames = []
		var path := file_env if file_env != "" else DEFAULT_TRACE
		if not vc.load_trace(path):
			push_error("CognifoldTraceView: could not load cognifold trace: " + path)
			return
		print("[cognifold] loaded trace world='%s' registers=%d" % [str(vc.world), vc.get_num_qubits()])
	var bname := "belief-field: " + str(vc.world)
	var biome = _Biome.new(vc, bname)
	var farm = _Farm.new(_Grid.new({bname: biome}))
	add_child(farm)   # keep the holder Node tree-managed (no orphan on exit)
	_field = QuantumField3DScript.new()
	_field.name = "QuantumField3D"
	add_child(_field)
	_field.connect_to_farm(farm)
	# filmstrip playback: _process continuously tweens the vc from frame A→B, advancing the
	# pair every _frame_s. The renderer keeps its persistent bubbles (same biome + register
	# count) and animates SMOOTHLY to each new state, so the picture IS the belief-field
	# evolving — and the cyan memory-trail becomes a continuous arc, not a staircase.
	if _frames.size() > 1 and OS.get_environment("SW_COGNIFOLD_FRAME_S").is_valid_float():
		_frame_s = maxf(0.05, float(OS.get_environment("SW_COGNIFOLD_FRAME_S")))
	set_process(_frames.size() > 1)
	if OS.has_environment("SW_SHOT"):
		_dev_capture()


func _process(delta: float) -> void:
	if _frames.size() < 2 or _vc == null:
		return
	_play_t += delta / _frame_s
	while _play_t >= 1.0:
		_play_t -= 1.0
		_frame_idx = (_frame_idx + 1) % _frames.size()
		_vc.load_frame_pair(_frames[_frame_idx], _frames[(_frame_idx + 1) % _frames.size()])
	_vc.set_blend(_play_t)


func _load_frames_dir(dir_path: String) -> Array:
	var frames: Array = []
	var da := DirAccess.open(dir_path)
	if da == null:
		return frames
	var names: Array[String] = []
	da.list_dir_begin()
	var fn := da.get_next()
	while fn != "":
		if not da.current_is_dir() and fn.ends_with(".json"):
			names.append(fn)
		fn = da.get_next()
	da.list_dir_end()
	names.sort()   # frame_000, frame_001, … play in order
	for nm in names:
		var f := FileAccess.open(dir_path.path_join(nm), FileAccess.READ)
		if f == null:
			continue
		var d = JSON.parse_string(f.get_as_text())
		if typeof(d) == TYPE_DICTIONARY:
			frames.append(d)
	return frames




func _dev_capture() -> void:
	var d := OS.get_environment("SW_SHOT_DELAY")
	await get_tree().create_timer(float(d) if d.is_valid_float() else 4.5).timeout
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(OS.get_environment("SW_SHOT"))
		print("SW_SHOT_SAVED:", OS.get_environment("SW_SHOT"))
	get_tree().quit()
