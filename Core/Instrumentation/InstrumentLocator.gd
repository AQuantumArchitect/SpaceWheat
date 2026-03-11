class_name InstrumentLocator
extends RefCounted

## InstrumentLocator - shared resolver for PlayerShell/SnapshotService/QuantumInstrument/QuestManager.

static func resolve_player_shell(scope: Node) -> Node:
	if not scope:
		return null
	var tree = scope.get_tree()
	if not tree:
		return null
	var shells = tree.get_nodes_in_group("player_shell")
	for shell in shells:
		if shell:
			return shell
	if tree.root:
		return tree.root.get_node_or_null("/root/FarmView/PlayerShell")
	return null


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
