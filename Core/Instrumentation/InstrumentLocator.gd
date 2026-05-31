class_name InstrumentLocator
extends RefCounted

## InstrumentLocator - shared resolver for PlayerShell/SnapshotService/QuantumInstrument/QuestManager.

static func resolve_player_shell(scope: Node) -> Node:
	if not scope:
		return null
	var tree: SceneTree
	if scope.is_inside_tree():
		tree = scope.get_tree()
	if not tree:
		return null
	var shells = tree.get_nodes_in_group("player_shell")
	for shell in shells:
		if shell:
			return shell
	if tree.root:
		return tree.root.get_node_or_null("/root/FarmView/PlayerShell")
	return null


static func _safe_connect(sig, callable) -> bool:
	if not sig.is_connected(callable):
		sig.connect(callable)
		return true
	return false


static func _safe_disconnect(sig, callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


static func resolve_farm_view(_scope = null, _farm_node = null):
	var main_loop = Engine.get_main_loop()
	var tree = main_loop as SceneTree if main_loop is SceneTree else null
	if not tree or not tree.root:
		return null
	return tree.root.find_child("FarmView", true, false)


static func resolve_active_farm(scope: Node) -> Node:
	if not scope:
		return null
	var gsm = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if gsm and gsm.has_method("get_active_farm"):
		var active_farm = gsm.get_active_farm()
		if active_farm:
			return active_farm
	var tree: SceneTree
	if scope.is_inside_tree():
		tree = scope.get_tree()
	if not tree or not tree.root:
		return null
	var farm_view_farm = tree.root.get_node_or_null("/root/FarmView/Farm")
	if farm_view_farm:
		return farm_view_farm
	return tree.root.get_node_or_null("/root/Farm")


static func resolve_active_farm_main_loop() -> Node:
	var gsm = (Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if gsm and gsm.has_method("get_active_farm"):
		var active_farm = gsm.get_active_farm()
		if active_farm:
			return active_farm
	var main_loop = Engine.get_main_loop()
	var tree = main_loop as SceneTree if main_loop is SceneTree else null
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
