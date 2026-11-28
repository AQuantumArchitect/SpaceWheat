extends SceneTree
# Headless probe for #143: SFX default, shared settings file, legacy migration.
func _initialize() -> void:
	var sfx = load("res://Core/Audio/SFXRegistry.gd")
	var cfg := ConfigFile.new()
	var out := {}
	out["default_const"] = sfx.DEFAULT_SFX_VOLUME
	out["same_file"] = sfx.CONFIG_PATH == "user://settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sfx.LEGACY_CONFIG_PATH))
	var a = sfx.new()
	out["initial"] = a._sfx_volume
	a._load_volume_preference()
	out["first_run"] = a._sfx_volume
	# music key must survive an SFX save
	cfg.set_value("audio", "music_volume", 0.2)
	cfg.save("user://settings.cfg")
	a.set_volume(0.4)
	var b = sfx.new()
	b._load_volume_preference()
	out["roundtrip"] = b._sfx_volume
	cfg.load("user://settings.cfg")
	out["music_kept"] = cfg.get_value("audio", "music_volume", -1.0)
	# legacy migration
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings.cfg"))
	var old := ConfigFile.new()
	old.set_value("audio", "sfx_volume", 0.15)
	old.save(sfx.LEGACY_CONFIG_PATH)
	var c = sfx.new()
	c._load_volume_preference()
	out["migrated"] = c._sfx_volume
	cfg.load("user://settings.cfg")
	out["migrated_saved"] = cfg.get_value("audio", "sfx_volume", -1.0)
	out["legacy_gone"] = not FileAccess.file_exists(sfx.LEGACY_CONFIG_PATH)
	print("SFXPROBE " + JSON.stringify(out))
	quit(0)
