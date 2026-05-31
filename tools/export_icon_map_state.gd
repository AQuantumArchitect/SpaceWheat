extends SceneTree


func _ready():
    var path = ProjectSettings.globalize_path("user://saves/save_slot_2.tres")
    var state = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
    if not state:
        push_error("Failed to load %s" % path)
        quit()
        return
    var snapshot = state.atom_map_snapshot
    var file = FileAccess.open("/tmp/starter_forest_iconmap.json", FileAccess.WRITE)
    if not file:
        push_error("Failed to open output file")
        quit()
        return
    file.store_string(JSON.stringify({"icon_map": snapshot, "source": state.atom_map_snapshot_source, "time": state.atom_map_snapshot_time}, "\t"))
    file.close()
    print("IconMap exported")
    quit()
