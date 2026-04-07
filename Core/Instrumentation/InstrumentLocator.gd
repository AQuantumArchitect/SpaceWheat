class_name InstrumentLocator
extends RefCounted

## InstrumentLocator - shared resolver for PlayerShell/SnapshotService/QuantumInstrument/QuestManager.

static func _resolve_tree(scope: Node) -> SceneTree:
	if not scope:
		return null
	return scope.get_tree()


static func _resolve_main_loop_tree() -> SceneTree:
	var main_loop = Engine.get_main_loop()
	return main_loop as SceneTree if main_loop is SceneTree else null


static func resolve_root_node(scope: Node, path: String):
	var tree = _resolve_tree(scope)
	if not tree or not tree.root:
		return null
	return tree.root.get_node_or_null(path)


static func resolve_main_loop_root_node(path: String):
	var tree = _resolve_main_loop_tree()
	if not tree or not tree.root:
		return null
	return tree.root.get_node_or_null(path)

static func resolve_player_shell(scope: Node) -> Node:
	if not scope:
		return null
	var tree = _resolve_tree(scope)
	if not tree:
		return null
	var shells = tree.get_nodes_in_group("player_shell")
	for shell in shells:
		if shell:
			return shell
	if tree.root:
		return tree.root.get_node_or_null("/root/FarmView/PlayerShell")
	return null


static func resolve_game_state_manager(scope: Node):
	return resolve_root_node(scope, "/root/GameStateManager")


static func resolve_game_state_manager_main_loop():
	return resolve_main_loop_root_node("/root/GameStateManager")


static func resolve_active_farm(scope: Node) -> Node:
	if not scope:
		return null
	var gsm = resolve_game_state_manager(scope)
	if gsm and gsm.has_method("get_active_farm"):
		var active_farm = gsm.get_active_farm()
		if active_farm:
			return active_farm
	var tree = _resolve_tree(scope)
	if not tree or not tree.root:
		return null
	var farm_view_farm = tree.root.get_node_or_null("/root/FarmView/Farm")
	if farm_view_farm:
		return farm_view_farm
	return tree.root.get_node_or_null("/root/Farm")


static func resolve_active_farm_main_loop() -> Node:
	var gsm = resolve_game_state_manager_main_loop()
	if gsm and gsm.has_method("get_active_farm"):
		var active_farm = gsm.get_active_farm()
		if active_farm:
			return active_farm
	var tree = _resolve_main_loop_tree()
	if not tree or not tree.root:
		return null
	var farm_view_farm = tree.root.get_node_or_null("/root/FarmView/Farm")
	if farm_view_farm:
		return farm_view_farm
	return tree.root.get_node_or_null("/root/Farm")


static func resolve_snapshot_service(scope: Node):
	var shell = resolve_player_shell(scope)
	if shell and "snapshot_service" in shell and shell.snapshot_service:
		return shell.snapshot_service
	return null


static func resolve_quantum_instrument(scope: Node):
	var shell = resolve_player_shell(scope)
	if shell and "quantum_instrument" in shell and shell.quantum_instrument:
		return shell.quantum_instrument
	var snap = resolve_snapshot_service(scope)
	if snap and "instrument" in snap and snap.instrument:
		return snap.instrument
	return null


static func resolve_quest_manager(scope: Node, farm_ref: Node = null):
	if farm_ref and "quest_manager" in farm_ref and farm_ref.quest_manager:
		return farm_ref.quest_manager
	var shell = resolve_player_shell(scope)
	if shell and "quest_manager" in shell and shell.quest_manager:
		return shell.quest_manager
	var tree = scope.get_tree() if scope else null
	if tree and tree.root:
		var qm = tree.root.get_node_or_null("/root/QuestManager")
		if qm:
			return qm
	return null


static func resolve_active_biome_manager(scope: Node):
	return resolve_root_node(scope, "/root/ActiveBiomeManager")


static func resolve_active_biome_manager_main_loop():
	return resolve_main_loop_root_node("/root/ActiveBiomeManager")


static func resolve_player_vocabulary(scope: Node):
	return resolve_root_node(scope, "/root/PlayerVocabulary")


static func resolve_player_vocabulary_main_loop():
	return resolve_main_loop_root_node("/root/PlayerVocabulary")


static func resolve_vocabulary_evolution(scope: Node):
	return resolve_root_node(scope, "/root/VocabularyEvolution")


static func resolve_vocabulary_evolution_main_loop():
	return resolve_main_loop_root_node("/root/VocabularyEvolution")


static func resolve_icon_registry(scope: Node):
	return resolve_root_node(scope, "/root/IconRegistry")


static func resolve_icon_registry_main_loop():
	return resolve_main_loop_root_node("/root/IconRegistry")


static func resolve_verbose_config(scope: Node):
	return resolve_root_node(scope, "/root/VerboseConfig")


static func resolve_verbose_config_main_loop():
	return resolve_main_loop_root_node("/root/VerboseConfig")


static func resolve_observation_frame(scope: Node):
	return resolve_root_node(scope, "/root/ObservationFrame")


static func resolve_observation_frame_main_loop():
	return resolve_main_loop_root_node("/root/ObservationFrame")


static func resolve_music_manager(scope: Node):
	return resolve_root_node(scope, "/root/MusicManager")


static func resolve_music_manager_main_loop():
	return resolve_main_loop_root_node("/root/MusicManager")


static func resolve_action_chain_tracker(scope: Node):
	return resolve_root_node(scope, "/root/ActionChainTracker")


static func resolve_action_chain_tracker_main_loop():
	return resolve_main_loop_root_node("/root/ActionChainTracker")


static func resolve_visual_asset_registry(scope: Node):
	return resolve_root_node(scope, "/root/VisualAssetRegistry")


static func resolve_visual_asset_registry_main_loop():
	return resolve_main_loop_root_node("/root/VisualAssetRegistry")


static func resolve_touch_input_manager(scope: Node):
	return resolve_root_node(scope, "/root/TouchInputManager")


static func resolve_touch_input_manager_main_loop():
	return resolve_main_loop_root_node("/root/TouchInputManager")


static func resolve_ui_performance_tracker(scope: Node):
	return resolve_root_node(scope, "/root/UIPerformanceTracker")


static func resolve_ui_performance_tracker_main_loop():
	return resolve_main_loop_root_node("/root/UIPerformanceTracker")
