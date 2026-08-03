class_name CognifoldTraceView
extends Control
# Standalone reasoning-transparency instrument (NOT part of the game): loads an umwelt
# cognifold-trace JSON and renders that belief-field through SpaceWheat's 3D cognifold
# renderer (QuantumField3D), UNCHANGED, by wrapping the trace in a minimal farm/grid/biome
# whose viz_cache is the UmweltVizCache adapter. Run standalone:
#   DISPLAY=:0 SW_COGNIFOLD_TRACE=res://scratch_cognifold_sample.json \
#     SW_SHOT=/abs/out.png godot scenes/CognifoldTraceView.tscn
# LIVE mode — point it at a stepping umweltd and watch a mind think in real time:
#   SW_COGNIFOLD_URL=http://127.0.0.1:7073/worlds/<world>/cognifold \
#     [SW_COGNIFOLD_POLL_S=2.0] [UMWELTD_API_KEY=...] godot scenes/CognifoldTraceView.tscn
# The poll loop reuses the filmstrip tween machinery verbatim: each fresh response becomes
# the next frame and the field glides to it in Bloch-vector space. A quiet world is
# LEGITIMATELY still — the daemon steps on ingest only; stillness means no events, not breakage.
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
var _farm = null               # kept so live mode can respawn bubbles on topology change
var _live_url := ""            # non-empty → live polling mode (SW_COGNIFOLD_URL)
var _http: HTTPRequest = null
var _live_pending := false
var _live_cur: Dictionary = {} # the frame the field last settled on (tween source)
# THE DARK BANNER. A quiet world and a dead daemon look IDENTICAL in a belief field —
# both are a still picture. Before this, a failed first poll rendered an empty window and
# a lost daemon froze the field, with the only evidence on stderr. That is the same class
# of lie as the file-side vitals that read "alive" through a 12h umweltd outage. The
# instrument must say which of the two it is, on screen, where the eye already is.
var _dark: Label = null
var _last_ok_ms := 0
var _live_fails := 0


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
	## Belief-field registers carry no BasePlot infra (no pump/drain flags to read) — nil means
	## QuantumField3D._rebuild_lindblad_glyphs correctly draws no glyphs here, not an error.
	func get_plot(_grid_pos):
		return null


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
	# Precedence: SW_COGNIFOLD_URL (LIVE: poll a stepping umweltd) → SW_COGNIFOLD_TRACE_DIR
	# (a dir of *.json frames → animated filmstrip) → SW_COGNIFOLD_TRACE (a single trace file)
	# → a PLAIN launch defaults to the committed live filmstrip (the field animates as a real
	# umwelt walk evolves), falling back to the single forecast trace if the filmstrip is absent.
	_live_url = OS.get_environment("SW_COGNIFOLD_URL")
	if _live_url != "":
		_start_live_poll()
		if OS.has_environment("SW_SHOT"):
			_dev_capture()
		return   # field is built lazily, on the first successful response
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
	_build_field()
	# filmstrip playback: _process continuously tweens the vc from frame A→B, advancing the
	# pair every _frame_s. The renderer keeps its persistent bubbles (same biome + register
	# count) and animates SMOOTHLY to each new state, so the picture IS the belief-field
	# evolving — and the cyan memory-trail becomes a continuous arc, not a staircase.
	if _frames.size() > 1 and OS.get_environment("SW_COGNIFOLD_FRAME_S").is_valid_float():
		_frame_s = maxf(0.05, float(OS.get_environment("SW_COGNIFOLD_FRAME_S")))
	set_process(_frames.size() > 1)
	if OS.has_environment("SW_SHOT"):
		_dev_capture()


func _build_field() -> void:
	var bname := "belief-field: " + str(_vc.world)
	var biome = _Biome.new(_vc, bname)
	_farm = _Farm.new(_Grid.new({bname: biome}))
	add_child(_farm)   # keep the holder Node tree-managed (no orphan on exit)
	_field = QuantumField3DScript.new()
	_field.name = "QuantumField3D"
	add_child(_field)
	_field.connect_to_farm(_farm)


func _process(delta: float) -> void:
	if _vc == null:
		return
	if _live_url != "":
		# live mode: glide toward the most recent response and HOLD there (no wrap) —
		# the next poll supplies the next leg. A quiet world legitimately sits still.
		_play_t = minf(1.0, _play_t + delta / _frame_s)
		_vc.set_blend(_play_t)
		return
	if _frames.size() < 2:
		return
	_play_t += delta / _frame_s
	while _play_t >= 1.0:
		_play_t -= 1.0
		_frame_idx = (_frame_idx + 1) % _frames.size()
		_vc.load_frame_pair(_frames[_frame_idx], _frames[(_frame_idx + 1) % _frames.size()])
	_vc.set_blend(_play_t)


# ---- live mode: the instrument as a MEMBRANE over a stepping umweltd ---------------
## Poll GET <SW_COGNIFOLD_URL> (a /worlds/<name>/cognifold endpoint) every
## SW_COGNIFOLD_POLL_S seconds and tween the field to each fresh trace. The tween spans
## the poll gap, so consecutive responses read as continuous motion — the filmstrip
## machinery pointed at the network instead of a directory.
func _start_live_poll() -> void:
	_frame_s = 2.0
	var poll_env := OS.get_environment("SW_COGNIFOLD_POLL_S")
	if poll_env.is_valid_float():
		_frame_s = maxf(0.25, float(poll_env))
	_http = HTTPRequest.new()
	_http.timeout = maxf(4.0, _frame_s * 2.0)
	add_child(_http)
	_http.request_completed.connect(_on_live_response)
	var t := Timer.new()
	t.wait_time = _frame_s
	t.timeout.connect(_poll_live)
	add_child(t)
	t.start()
	set_process(true)
	_dark = Label.new()
	_dark.add_theme_color_override("font_color", Color(1.0, 0.72, 0.24))
	_dark.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_dark.add_theme_constant_override("outline_size", 6)
	_dark.position = Vector2(18, 14)
	_dark.z_index = 4096
	add_child(_dark)
	_set_dark("◌ waiting for the first frame — %s" % _live_url)
	print("[cognifold] LIVE mode: polling %s every %.2fs" % [_live_url, _frame_s])
	_poll_live()


## The banner's wording, which must never overstate what we know. Before any frame has
## landed the field is EMPTY (nothing to trust); after one has, the picture on screen is
## real but STALE, and how stale is the number that matters.
func _dark_text(reason: String) -> String:
	if _last_ok_ms == 0:
		return "⚠ DARK — %s\n%s\nno frame has ever arrived; this field is empty, not calm" % [
			reason, _live_url]
	var age := float(Time.get_ticks_msec() - _last_ok_ms) / 1000.0
	return "⚠ STALE — %s\nlast good frame %.0fs ago (%d failed polls)\nthis picture is frozen, not quiet" % [
		reason, age, _live_fails]


## Show a banner, or hide it entirely when text is empty. Never silently swallow a state.
func _set_dark(text: String) -> void:
	if _dark == null:
		return
	_dark.text = text
	_dark.visible = text != ""


func _poll_live() -> void:
	if _live_pending or _http == null:
		return
	var headers := PackedStringArray()
	var key := OS.get_environment("UMWELTD_API_KEY")
	if key != "":
		headers.append("X-API-Key: " + key)
	if _http.request(_live_url, headers) == OK:
		_live_pending = true


func _on_live_response(result: int, code: int, _hdrs: PackedStringArray, body: PackedByteArray) -> void:
	_live_pending = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_live_fails += 1
		push_warning("[cognifold] live poll failed (result=%d http=%d) — field holds last state" % [result, code])
		_set_dark(_dark_text("no answer (result=%d http=%d)" % [result, code]))
		return
	var d = JSON.parse_string(body.get_string_from_utf8())
	if typeof(d) != TYPE_DICTIONARY or not (d.get("registers", null) is Array):
		_live_fails += 1
		push_warning("[cognifold] live poll returned a non-trace payload — ignored")
		_set_dark(_dark_text("not a cognifold trace"))
		return
	_live_fails = 0
	_last_ok_ms = Time.get_ticks_msec()
	_set_dark("")   # a still field from here on is a QUIET WORLD, not a dead one
	if _field == null:
		if _vc.load_frame(d):
			_live_cur = d
			_build_field()
			print("[cognifold] LIVE first frame: world='%s' registers=%d"
				% [str(_vc.world), _vc.get_num_qubits()])
		return
	var n: int = (d.get("registers") as Array).size()
	if n != _vc.get_num_qubits():
		# topology changed (world regrew) — reload flat and respawn the field's bubbles
		_vc.load_frame(d)
		_live_cur = d
		_play_t = 1.0
		_field.connect_to_farm(_farm)
		return
	_vc.load_frame_pair(_live_cur, d)
	_live_cur = d
	_play_t = 0.0


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
