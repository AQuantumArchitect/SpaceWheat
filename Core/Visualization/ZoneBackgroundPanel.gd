class_name ZoneBackgroundPanel
extends Control

## ZoneBackgroundPanel — one flat Mini-Metro zone: color field + silhouette
## band + live quantum tint. Two of these swap inside BiomeBackground for the
## swipe transition.
##
## Silhouettes are PROCEDURAL (seeded by biome-name hash): deterministic per
## biome, resolution-independent, tinted by the theme's ink — no image assets.
## Which painter runs comes from visual_themes.json (theme.silhouette_id), so
## all 163+ biomes resolve emergently.
##
## Live tint (values pushed by BiomeBackground from BiomeBase.get_ambient_scalars,
## polled ≤2 Hz — never computed here):
##   warmth  w = 0.5 − 0.5·tanh((gap − 0.52)/0.07)   rigid=cold/mono, plural=warm
##   shimmer a = 0.04·tanh(var_h / 0.1)              restless zones breathe

var biome_name: String = ""
var zone_theme: Dictionary = {}

## Smoothed live-tint state (targets pushed via set_ambient_targets).
var _warmth: float = 0.0
var _shimmer_amp: float = 0.0
var _warmth_target: float = 0.0
var _shimmer_target: float = 0.0
var _clock: float = 0.0

## Deterministic per-biome silhouette geometry, rebuilt on biome/size change.
var _sil_shapes: Array = []  # of {kind: "poly"/"line"/"dot", pts/from/to/pos, w}
var _sil_built_for: String = ""
var _sil_built_size: Vector2 = Vector2.ZERO

const BASELINE_FRAC := 0.88  # silhouette ground line (above the action bar)


func set_zone(p_biome_name: String) -> void:
	biome_name = p_biome_name
	zone_theme = BiomeVisualTheme.get_theme(p_biome_name)
	_sil_built_for = ""  # force geometry rebuild
	queue_redraw()


func set_ambient_targets(gap: float, var_h: float) -> void:
	_warmth_target = 0.5 - 0.5 * tanh((gap - 0.52) / 0.07)
	_shimmer_target = 0.04 * tanh(var_h / 0.1)


func _process(delta: float) -> void:
	if not visible or zone_theme.is_empty():
		return
	_clock += delta
	var k := 1.0 - exp(-2.0 * delta)  # slow tint settle
	_warmth = lerpf(_warmth, _warmth_target, k)
	_shimmer_amp = lerpf(_shimmer_amp, _shimmer_target, k)
	queue_redraw()


func _draw() -> void:
	if zone_theme.is_empty() or size.x <= 1.0:
		return
	var base: Color = zone_theme.get("base", Color(0.1, 0.1, 0.12))
	var warm: Color = zone_theme.get("warm", base)
	var ink: Color = zone_theme.get("ink", Color(0, 0, 0))

	# Flat field: cold/mono when rigid, pulled toward the warm duo when plural,
	# with a slow lightness breath when the biome is restless.
	var field: Color = base.lerp(warm, 0.35 * _warmth)
	field.s = field.s * (0.5 + 0.5 * _warmth) + 0.0
	var breath: float = 1.0 + _shimmer_amp * sin(TAU * 0.15 * _clock)
	field.v = clampf(field.v * breath, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), field)

	# Silhouette band.
	if _sil_built_for != biome_name or _sil_built_size != size:
		_build_silhouette()
	var sil: Color = ink
	sil.a = 0.5
	# Plural duo-tone: the band leans toward the warm second color.
	sil = sil.lerp(Color(warm.r, warm.g, warm.b, 0.5), 0.4 * _warmth)
	var ground_y: float = size.y * BASELINE_FRAC
	var ground: Color = sil
	ground.a = sil.a * 0.5
	draw_rect(Rect2(Vector2(0, ground_y), Vector2(size.x, size.y - ground_y)), ground)
	for shape in _sil_shapes:
		match shape.kind:
			"poly":
				draw_colored_polygon(shape.pts, sil)
			"line":
				draw_line(shape.from, shape.to, sil, shape.w, true)
			"dot":
				draw_circle(shape.pos, shape.w, sil)


# ============================================================================
# Procedural silhouettes — deterministic from hash(biome_name)
# ============================================================================

## Tiny deterministic LCG so painters never touch global randomness.
var _lcg_state: int = 1

func _srand(seed_val: int) -> void:
	_lcg_state = (seed_val if seed_val > 0 else -seed_val) | 1

func _rand() -> float:
	_lcg_state = int((_lcg_state * 1103515245 + 12345) % 2147483648)
	return float(_lcg_state) / 2147483648.0

func _randf_range(a: float, b: float) -> float:
	return a + (b - a) * _rand()


func _build_silhouette() -> void:
	_sil_shapes.clear()
	_sil_built_for = biome_name
	_sil_built_size = size
	_srand(hash(biome_name))
	var w: float = size.x
	var base_y: float = size.y * BASELINE_FRAC
	var unit: float = size.y * 0.01  # 1% viewport height
	match str(zone_theme.get("silhouette_id", "horizon")):
		"treeline":
			var x := 0.0
			while x < w:
				var tw := _randf_range(2.6, 5.0) * unit
				var th := _randf_range(4.0, 11.0) * unit
				_sil_shapes.append({"kind": "poly", "pts": PackedVector2Array([
					Vector2(x, base_y), Vector2(x + tw * 0.5, base_y - th), Vector2(x + tw, base_y)])})
				x += tw * _randf_range(0.6, 0.95)
		"rooftops":
			var x := 0.0
			while x < w:
				var bw := _randf_range(4.0, 8.0) * unit
				var bh := _randf_range(2.5, 6.5) * unit
				_sil_shapes.append({"kind": "poly", "pts": PackedVector2Array([
					Vector2(x, base_y), Vector2(x, base_y - bh),
					Vector2(x + bw, base_y - bh), Vector2(x + bw, base_y)])})
				if _rand() > 0.5:  # gable
					_sil_shapes.append({"kind": "poly", "pts": PackedVector2Array([
						Vector2(x, base_y - bh), Vector2(x + bw * 0.5, base_y - bh - _randf_range(1.2, 2.4) * unit),
						Vector2(x + bw, base_y - bh)])})
				if _rand() > 0.7:  # chimney
					var cx := x + bw * _randf_range(0.2, 0.7)
					_sil_shapes.append({"kind": "poly", "pts": PackedVector2Array([
						Vector2(cx, base_y - bh), Vector2(cx, base_y - bh - 1.6 * unit),
						Vector2(cx + 0.7 * unit, base_y - bh - 1.6 * unit), Vector2(cx + 0.7 * unit, base_y - bh)])})
				x += bw + _randf_range(0.5, 2.0) * unit
		"field":
			# Rolling ground + sparse wheat stalks — the lone field.
			var x := 0.0
			while x < w:
				if _rand() > 0.45:
					var sx := x + _randf_range(0.0, 2.0) * unit
					var sh := _randf_range(2.0, 4.5) * unit
					_sil_shapes.append({"kind": "line", "from": Vector2(sx, base_y),
							"to": Vector2(sx, base_y - sh), "w": 1.5})
					for k in range(3):
						var hy := base_y - sh + float(k) * 0.5 * unit
						_sil_shapes.append({"kind": "line", "from": Vector2(sx, hy),
								"to": Vector2(sx + (0.9 - 0.2 * k) * unit, hy - 0.5 * unit), "w": 1.2})
				x += _randf_range(3.0, 7.0) * unit
		"gantry":
			var x := _randf_range(0.0, 4.0) * unit
			while x < w:
				var gh := _randf_range(5.0, 12.0) * unit
				var gw := _randf_range(5.0, 9.0) * unit
				_sil_shapes.append({"kind": "line", "from": Vector2(x, base_y), "to": Vector2(x, base_y - gh), "w": 2.2})
				_sil_shapes.append({"kind": "line", "from": Vector2(x + gw, base_y), "to": Vector2(x + gw, base_y - gh * 0.8), "w": 2.2})
				_sil_shapes.append({"kind": "line", "from": Vector2(x, base_y - gh), "to": Vector2(x + gw, base_y - gh * 0.8), "w": 1.8})
				_sil_shapes.append({"kind": "line", "from": Vector2(x, base_y - gh * 0.5), "to": Vector2(x + gw, base_y - gh * 0.8), "w": 1.0})
				x += gw + _randf_range(3.0, 8.0) * unit
		"starline":
			for i in range(24):
				_sil_shapes.append({"kind": "dot", "pos": Vector2(_randf_range(0, w),
						base_y - _randf_range(1.0, 14.0) * unit), "w": _randf_range(0.8, 1.8)})
			_sil_shapes.append({"kind": "line", "from": Vector2(0, base_y), "to": Vector2(w, base_y), "w": 1.2})
		"waves":
			for row in range(2):
				var y0 := base_y - (1.5 + 1.6 * row) * unit
				var amp := (0.8 + 0.4 * row) * unit
				var px := 0.0
				var prev := Vector2(0, y0)
				while px < w:
					px += 8.0
					var p := Vector2(px, y0 + sin(px * 0.03 + row * 2.1) * amp)
					_sil_shapes.append({"kind": "line", "from": prev, "to": p, "w": 1.6})
					prev = p
		"spires":
			var x := _randf_range(0.0, 3.0) * unit
			while x < w:
				var sw := _randf_range(1.2, 2.6) * unit
				var sh := _randf_range(6.0, 14.0) * unit
				_sil_shapes.append({"kind": "poly", "pts": PackedVector2Array([
					Vector2(x, base_y), Vector2(x + sw * 0.5, base_y - sh), Vector2(x + sw, base_y)])})
				x += sw + _randf_range(2.0, 7.0) * unit
		"lattice":
			var step := 3.2 * unit
			var x := 0.0
			while x < w:
				_sil_shapes.append({"kind": "line", "from": Vector2(x, base_y),
						"to": Vector2(x + step, base_y - step), "w": 1.0})
				_sil_shapes.append({"kind": "line", "from": Vector2(x, base_y - step),
						"to": Vector2(x + step, base_y), "w": 1.0})
				x += step
		_:  # horizon
			_sil_shapes.append({"kind": "line", "from": Vector2(0, base_y), "to": Vector2(w, base_y), "w": 2.0})
			for i in range(3):
				var mx := _randf_range(0.1, 0.9) * w
				var mw := _randf_range(1.5, 3.0) * unit
				var mh := _randf_range(2.0, 5.0) * unit
				_sil_shapes.append({"kind": "poly", "pts": PackedVector2Array([
					Vector2(mx, base_y), Vector2(mx, base_y - mh),
					Vector2(mx + mw, base_y - mh), Vector2(mx + mw, base_y)])})
