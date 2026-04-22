extends Control

## FpsDisplay — always-visible projection HUD: top-left corner.
## Timer-driven (signal push), never polls in _process.

const UIStyleFactory = preload("res://UI/Core/UIStyleFactory.gd")
const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")

var _fps_label: Label


func _ready() -> void:
	_build_ui()
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_update_fps)
	add_child(timer)


func _update_fps() -> void:
	var fps := Engine.get_frames_per_second()
	var farm := InstrumentLocator.resolve_active_farm(self)
	var phz := UIStyleFactory.get_physics_fps_from_farm(farm)
	var sr := UIStyleFactory.get_slice_rate_from_farm(farm)
	var slices: float = sr.slices
	var biomes: int = sr.biomes

	if slices > 0.0:
		_fps_label.text = "FPS %d | PhHz %.1f | Evol %.0f/s [%dB]" % [fps, phz, slices, biomes]
	elif phz > 0.0:
		_fps_label.text = "FPS %d | PhHz %.1f" % [fps, phz]
	else:
		_fps_label.text = "FPS %d" % fps


func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var scaffold := UIStyleFactory.create_hud_scaffold(
		UIStyleFactory.COLOR_HUD_BG,
		UIStyleFactory.COLOR_PANEL_BORDER,
		6, 4
	)
	var panel: PanelContainer = scaffold.panel
	var vbox: VBoxContainer = scaffold.vbox

	_fps_label = UIStyleFactory.create_hud_label("FPS --", UIStyleFactory.COLOR_TEXT_SUBTITLE, 11)
	vbox.add_child(_fps_label)

	add_child(panel)
