extends SceneTree

const GameStateManager = preload("res://Core/GameState/GameStateManager.gd")
const BootManager = preload("res://Core/Boot/BootManager.gd")

func _ready():
    var gsm = get_node_or_null("/root/GameStateManager")
    if not gsm:
        gsm = GameStateManager.new()
        gsm.name = "GameStateManager"
        get_tree().root.add_child(gsm)
    var boot_manager = get_node_or_null("/root/BootManager")
    if not boot_manager:
        boot_manager = BootManager.new()
        boot_manager.name = "BootManager"
        get_tree().root.add_child(boot_manager)
    var farm = await boot_manager.boot_session({"slot": -1, "scenario_id": "new_game_easy", "headless": true}, null)
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
