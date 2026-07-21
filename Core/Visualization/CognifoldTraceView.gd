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
const QuantumField3DScript = preload("res://Core/Visualization/QuantumField3D.gd")
const DEFAULT_TRACE := "res://Core/Visualization/cognifold_sample_grid.json"

var _field = null


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
	var path := OS.get_environment("SW_COGNIFOLD_TRACE")
	if path == "":
		path = DEFAULT_TRACE
	var vc = UmweltVizCacheScript.new()
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
	if OS.has_environment("SW_SHOT"):
		_dev_capture()


func _dev_capture() -> void:
	var d := OS.get_environment("SW_SHOT_DELAY")
	await get_tree().create_timer(float(d) if d.is_valid_float() else 4.5).timeout
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(OS.get_environment("SW_SHOT"))
		print("SW_SHOT_SAVED:", OS.get_environment("SW_SHOT"))
	get_tree().quit()
