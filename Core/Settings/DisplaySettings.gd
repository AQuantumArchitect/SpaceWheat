extends Node
## Display mode (Fullscreen / Windowed): apply, persist, F11.
##
## Autoload. Applies the saved mode in _ready (the earliest settings load we
## have; autoloads run before the main scene's first frame). The mode shares
## user://settings.cfg with MusicManager, under [display] window_mode.
## Escape → Balance's "Display" row and F11 both call set_fullscreen().

const CONFIG_PATH := "user://settings.cfg"
const SECTION := "display"
const KEY := "window_mode"
const MODE_WINDOWED := "windowed"
const MODE_FULLSCREEN := "fullscreen"

## Overridable in tests so no real window is touched.
var config_path: String = CONFIG_PATH
var last_applied_mode: String = ""
var _apply_to_window: Callable = Callable(self, "_apply_to_display_server")


func _ready() -> void:
	set_process_unhandled_key_input(true)
	apply(load_saved_mode())


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		toggle()
		get_viewport().set_input_as_handled()


func load_saved_mode() -> String:
	var config := ConfigFile.new()
	if config.load(config_path) != OK:
		return MODE_WINDOWED
	return _normalize(str(config.get_value(SECTION, KEY, MODE_WINDOWED)))


func save_mode(mode: String) -> void:
	var config := ConfigFile.new()
	config.load(config_path)  # keep the audio keys; a missing file is fine
	config.set_value(SECTION, KEY, _normalize(mode))
	config.save(config_path)


func current_mode() -> String:
	return last_applied_mode if last_applied_mode != "" else load_saved_mode()


func is_fullscreen() -> bool:
	return current_mode() == MODE_FULLSCREEN


## Apply without saving (boot path).
func apply(mode: String) -> void:
	last_applied_mode = _normalize(mode)
	_apply_to_window.call(last_applied_mode)


## Apply live and persist.
func set_mode(mode: String) -> void:
	apply(mode)
	save_mode(last_applied_mode)


func set_fullscreen(on: bool) -> void:
	set_mode(MODE_FULLSCREEN if on else MODE_WINDOWED)


func toggle() -> void:
	set_fullscreen(not is_fullscreen())


func _normalize(mode: String) -> String:
	return MODE_FULLSCREEN if mode == MODE_FULLSCREEN else MODE_WINDOWED


func _apply_to_display_server(mode: String) -> void:
	if RuntimeEnv.is_headless() or OS.has_feature("web"):
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if mode == MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_WINDOWED
	)
