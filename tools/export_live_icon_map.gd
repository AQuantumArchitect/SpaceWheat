extends SceneTree

const GameStateManager = preload("res://Core/GameState/GameStateManager.gd")

func _ready():
    var gsm = get_node_or_null("/root/GameStateManager")
    if not gsm:
        gsm = GameStateManager.new()
        gsm.name = "GameStateManager"
        get_tree().root.add_child(gsm)
    var farm = await gsm.start_session(0, "default")
    await farm.ready
    if not (farm.biome_evolution_batcher and farm.biome_evolution_batcher.has_method("get_global_icon_map")):
        print("No biome batcher yet")
        quit()
        return
    var icon_map = farm.biome_evolution_batcher.get_global_icon_map()
    var file = FileAccess.open("/tmp/starter_forest_iconmap.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(icon_map, "\t"))
    file.close()
    print("exported icon map")
    quit()
