class_name BlochSphereWidget
extends Control

## Bloch sphere wireframe renderer with trail, heatmap, and Berry phase flash.
##
## Call update_state(x, y, z, r) each frame with Cartesian Bloch coordinates.
## The widget draws an oblique-projected wireframe sphere, shows the current
## state as a bright dot, accumulates a fading trail, bins visit history into
## a heatmap, and flashes green when azimuthal phase wraps 2π (Berry loop).

# ── Configuration ────────────────────────────────────────────────────────────

## Number of line segments per great circle (higher = smoother, 48 is plenty)
const WIRE_SEGMENTS := 48

## Default max trail length (recent positions kept as fading dots)
const TRAIL_MAX_DEFAULT := 100

## Azimuthal tilt: rotation around Z-axis (camera swings right)
const AZ_TILT := PI / 5.5  # ~33°
## Elevation tilt: rotation around X-axis (camera looks slightly down)
const EL_TILT := PI / 7.0  # ~26° — makes equator visible as an ellipse

## Heatmap resolution (latitude × longitude bins on sphere surface)
const HEAT_LAT := 8
const HEAT_LON := 12
const HEAT_TOTAL := HEAT_LAT * HEAT_LON

## Per-frame decay multiplier for heatmap bins (prevents saturation)
const HEAT_DECAY := 0.997

## Minimum visit count to render a heatmap dot
const HEAT_THRESHOLD := 0.5

# ── Colors ───────────────────────────────────────────────────────────────────

const COLOR_WIRE_FRONT := Color(0.35, 0.45, 0.6, 0.35)
const COLOR_WIRE_BACK := Color(0.2, 0.25, 0.35, 0.12)
const COLOR_DOT := Color(1.0, 0.95, 0.35, 1.0)
const COLOR_DOT_SHADOW := Color(0.0, 0.0, 0.0, 0.35)
const COLOR_TRAIL_BRIGHT := Color(0.45, 0.78, 1.0, 0.55)
const COLOR_TRAIL_DIM := Color(0.3, 0.5, 0.8, 0.04)
const COLOR_POLE_N := Color(0.3, 0.55, 0.85, 0.55)  # matches bar north
const COLOR_POLE_S := Color(0.85, 0.4, 0.25, 0.55)   # matches bar south
const COLOR_HEAT_COLD := Color(0.18, 0.22, 0.45, 0.25)
const COLOR_HEAT_HOT := Color(1.0, 0.55, 0.1, 0.55)
const COLOR_BERRY := Color(0.25, 1.0, 0.5, 0.7)
const COLOR_BG := Color(0.06, 0.07, 0.1, 0.5)

# ── State ────────────────────────────────────────────────────────────────────

var _current := Vector3.ZERO
var _current_r := 0.0

var _trail: Array[Vector3] = []

var _heatmap := PackedFloat64Array()
var _heat_max := 1.0
var _heat_frame := 0  # for periodic max recompute

var _berry_accum := 0.0
var _last_phi := 0.0
var _has_last := false
var _berry_flash := 0.0
var _berry_loops := 0  # total completed loops

## If true, show axis letter labels (X, Z) on the large version
var show_axis_labels := false

## If true, show numeric Bloch coords below sphere
var show_coords := false

## Configurable trail length — set higher for the detail view
var trail_max: int = TRAIL_MAX_DEFAULT

## Configurable heatmap decay — closer to 1.0 = longer memory
var heat_decay: float = HEAT_DECAY

# Precomputed trig for two-axis projection
var _caz := cos(AZ_TILT)
var _saz := sin(AZ_TILT)
var _cel := cos(EL_TILT)
var _sel := sin(EL_TILT)


func _init() -> void:
	_heatmap.resize(HEAT_TOTAL)
	_heatmap.fill(0.0)
	custom_minimum_size = Vector2(70, 70)


# ── Public API ───────────────────────────────────────────────────────────────

func update_state(bx: float, by: float, bz: float, r: float) -> void:
	"""Feed new Bloch vector. Call once per frame from the inspector."""
	_current = Vector3(bx, by, bz)
	_current_r = r

	var is_pure_enough := r > 0.02

	# Trail
	if is_pure_enough:
		_trail.push_back(Vector3(bx, by, bz))
		if _trail.size() > trail_max:
			_trail.pop_front()

	# Heatmap bin
	if is_pure_enough:
		var len := maxf(sqrt(bx * bx + by * by + bz * bz), 0.001)
		var theta := acos(clampf(bz / len, -1.0, 1.0))
		var phi := atan2(by, bx)
		var lat := clampi(int(theta / PI * HEAT_LAT), 0, HEAT_LAT - 1)
		var lon := clampi(int((phi + PI) / TAU * HEAT_LON), 0, HEAT_LON - 1)
		_heatmap[lat * HEAT_LON + lon] += 1.0

	# Heatmap decay + max recompute (every 30 frames)
	_heat_frame += 1
	if _heat_frame >= 30:
		_heat_frame = 0
		var batch_decay := pow(heat_decay, 30.0)
		_heat_max = 1.0
		for i in range(HEAT_TOTAL):
			_heatmap[i] *= batch_decay
			if _heatmap[i] > _heat_max:
				_heat_max = _heatmap[i]

	# Berry phase accumulation
	if r > 0.1:
		var phi := atan2(by, bx)
		if _has_last:
			var dphi := phi - _last_phi
			# Unwrap to [-π, π]
			while dphi > PI:
				dphi -= TAU
			while dphi < -PI:
				dphi += TAU
			_berry_accum += dphi
			if absf(_berry_accum) >= TAU:
				_berry_flash = 1.0
				_berry_loops += 1
				_berry_accum = fmod(_berry_accum, TAU)
		_last_phi = phi
		_has_last = true

	# Flash decay
	if _berry_flash > 0.0:
		_berry_flash = maxf(_berry_flash - 0.025, 0.0)

	queue_redraw()


func clear_history() -> void:
	"""Reset trail, heatmap, and Berry accumulator."""
	_trail.clear()
	_heatmap.fill(0.0)
	_heat_max = 1.0
	_berry_accum = 0.0
	_has_last = false
	_berry_flash = 0.0
	_berry_loops = 0
	queue_redraw()


func get_berry_loops() -> int:
	return _berry_loops


# ── Projection ───────────────────────────────────────────────────────────────

func _sphere_radius() -> float:
	return minf(size.x, size.y) / 2.0 - 4.0


func _center() -> Vector2:
	return size / 2.0


func _project(v: Vector3) -> Vector2:
	"""Two-axis orthographic projection: Rz(az) then Rx(el), project to screen XY."""
	# After Rz(az): x' = x*caz - y*saz, y' = x*saz + y*caz, z' = z
	# After Rx(el): screen_x = x', screen_y = -(y'*sel + z'*cel)
	var sx := v.x * _caz - v.y * _saz
	var sy := -((v.x * _saz + v.y * _caz) * _sel + v.z * _cel)
	return _center() + Vector2(sx, sy) * _sphere_radius()


func _depth(v: Vector3) -> float:
	"""Depth toward viewer (positive = front-facing)."""
	return (v.x * _saz + v.y * _caz) * _cel - v.z * _sel


# ── Drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	var c := _center()
	var r := _sphere_radius()

	# Background disc
	draw_circle(c, r + 1.0, COLOR_BG)

	# Heatmap layer (behind wireframe)
	_draw_heatmap()

	# Wireframe: 3 great circles
	# Equator (z=0 plane): spans X and Y axes
	_draw_circle_on_sphere(Vector3.RIGHT, Vector3.UP)
	# Prime meridian (y=0 plane): spans X and Z axes
	_draw_circle_on_sphere(Vector3.RIGHT, Vector3.BACK)
	# Side meridian (x=0 plane): spans Y and Z axes
	_draw_circle_on_sphere(Vector3.UP, Vector3.BACK)

	# Trail (behind dot, in front of wireframe)
	_draw_trail()

	# Pole markers
	var np := _project(Vector3(0, 0, 1))
	var sp := _project(Vector3(0, 0, -1))
	draw_circle(np, 2.5, COLOR_POLE_N)
	draw_circle(sp, 2.5, COLOR_POLE_S)

	# Current state dot
	if _current_r > 0.02:
		var pos := _project(_current)
		draw_circle(pos + Vector2(1, 1), 3.5, COLOR_DOT_SHADOW)
		draw_circle(pos, 3.5, COLOR_DOT)

	# Berry phase flash ring
	if _berry_flash > 0.01:
		var flash_color := COLOR_BERRY
		flash_color.a = _berry_flash * 0.7
		draw_arc(c, r + 2.0, 0.0, TAU, 36, flash_color, 2.0, true)
		flash_color.a = _berry_flash * 0.3
		draw_arc(c, r - 2.0, 0.0, TAU, 36, flash_color, 1.5, true)

	# Axis labels (large mode only)
	if show_axis_labels:
		_draw_axis_labels()

	# Numeric coords (optional)
	if show_coords and _current_r > 0.02:
		_draw_coords()


func _draw_circle_on_sphere(u: Vector3, v: Vector3) -> void:
	"""Draw a great circle defined by two orthogonal basis vectors in the plane."""
	var prev := _project(u)
	for i in range(1, WIRE_SEGMENTS + 1):
		var angle := TAU * float(i) / WIRE_SEGMENTS
		var point_3d := u * cos(angle) + v * sin(angle)
		var point_2d := _project(point_3d)
		var d := _depth(point_3d)
		var color := COLOR_WIRE_FRONT if d >= 0.0 else COLOR_WIRE_BACK
		draw_line(prev, point_2d, color, 1.0, true)
		prev = point_2d


func _draw_trail() -> void:
	var count := _trail.size()
	if count == 0:
		return
	var max_idx := count - 1
	for i in range(count):
		var t := float(i) / maxf(max_idx, 1.0)
		var color := COLOR_TRAIL_DIM.lerp(COLOR_TRAIL_BRIGHT, t)
		var d := _depth(_trail[i])
		if d < 0.0:
			color.a *= 0.25  # dim back-facing trail points
		var dot_r := lerpf(1.0, 2.5, t)
		draw_circle(_project(_trail[i]), dot_r, color)


func _draw_heatmap() -> void:
	if _heat_max < HEAT_THRESHOLD:
		return
	for lat in range(HEAT_LAT):
		var theta := (float(lat) + 0.5) / HEAT_LAT * PI
		var sin_theta := sin(theta)
		var cos_theta := cos(theta)
		for lon in range(HEAT_LON):
			var val := _heatmap[lat * HEAT_LON + lon]
			if val < HEAT_THRESHOLD:
				continue
			var t := clampf(val / _heat_max, 0.0, 1.0)
			var phi := (float(lon) + 0.5) / HEAT_LON * TAU - PI
			var v := Vector3(sin_theta * cos(phi), sin_theta * sin(phi), cos_theta)
			var pos := _project(v)
			var d := _depth(v)
			var color := COLOR_HEAT_COLD.lerp(COLOR_HEAT_HOT, t)
			if d < 0.0:
				color.a *= 0.2
			var dot_r := lerpf(2.5, 5.5, t)
			draw_circle(pos, dot_r, color)


func _draw_axis_labels() -> void:
	# X axis tip
	var x_pos := _project(Vector3(1.15, 0, 0))
	draw_string(ThemeDB.fallback_font, x_pos - Vector2(3, -3), "X",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_WIRE_FRONT)
	# Z axis tip (above north pole)
	var z_pos := _project(Vector3(0, 0, 1.15))
	draw_string(ThemeDB.fallback_font, z_pos - Vector2(3, 10), "Z",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_WIRE_FRONT)


func _draw_coords() -> void:
	var len := maxf(sqrt(_current.x ** 2 + _current.y ** 2 + _current.z ** 2), 0.001)
	var theta := acos(clampf(_current.z / len, -1.0, 1.0))
	var phi := atan2(_current.y, _current.x)
	var text := "r=%.2f θ=%.2f φ=%.2f" % [_current_r, theta, phi]
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 9)
	var x_offset := (size.x - text_size.x) / 2.0
	draw_string(font, Vector2(x_offset, size.y - 2), text,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color(0.5, 0.55, 0.65, 0.7))
