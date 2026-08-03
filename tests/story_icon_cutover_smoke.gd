extends SceneTree

## story_icon_cutover_smoke.gd
##
## Verifies the story/quest cutover now reads live icon physics from the shared
## icon atlas instead of faction-level old physics.

const FactionRegistryCls = preload("res://Core/Factions/FactionRegistry.gd")
const StoryEngine = preload("res://Core/Story/StoryEngine.gd")

var passed: int = 0
var failed: int = 0


var _ran := false


func _process(_delta: float) -> bool:
	# Run on the first frame, not _init/_initialize: production statics
	# (StoryEngine/QuestRewards) resolve /root/IconRegistry via absolute
	# get_node paths, which only work once the scene tree is active.
	if _ran:
		return false
	_ran = true
	_run_test()
	return false


func _run_test() -> void:
	print("\n=== Story / icon cutover smoke ===")
	# Load the canonical economy config the way boot does — QuestRewards'
	# tuning contract is "no code defaults, config must be whole".
	var econ: Dictionary = FarmVariableGraph.parse_graph_lines(FarmVariableGraph.load_graph_lines())
	QuestRewards.set_reward_tuning_overrides(econ.get("patch", {}).get("quest_rewards", {}))
	var freg = FactionRegistryCls.new()
	var icon_registry = _resolve_icon_registry()
	_check(icon_registry != null, "shared icon registry resolves")

	var factions := ["Verdant Pulse", "Mycelial Web"]
	for faction_name in factions:
		var faction = freg.get_by_name(faction_name)
		_check(faction != null, "%s loads" % faction_name)
		if faction == null:
			continue
		var physics: Dictionary = icon_registry.get_cloud_physics(faction.cloud) if icon_registry != null else {}
		_check(not physics.is_empty(), "%s projects live signature physics" % faction_name)
		_check(not physics.get("hamiltonian", {}).is_empty(), "%s has projected hamiltonian terms" % faction_name)
		_check(not physics.get("self_energies", {}).is_empty(), "%s has projected self energies" % faction_name)

		var convo = StoryEngine.compose_socialite_voice(faction_name, null, freg)
		_check(not convo.get("initial", {}).is_empty(), "%s conversation initial weights" % faction_name)
		_check(not convo.get("transitions", {}).is_empty(), "%s conversation transitions" % faction_name)

		var reward = QuestRewards.plan_resource_rewards({
			"faction": faction_name,
			"faction_signature": faction.cloud.duplicate(),
			"quantity": 8,
		}, faction.to_dict())
		_check(reward is Dictionary and not reward.is_empty(), "%s reward plan projects from icon physics" % faction_name)
		_check(_reward_keys_are_in_signature(reward, faction.cloud), "%s reward keys stay inside signature" % faction_name)

		var live_reward = QuestRewards.generate_reward({
			"faction": faction_name,
			"faction_signature": faction.cloud.duplicate(),
			"available_emojis": faction.cloud.duplicate(),
			"resource": faction.cloud[0] if faction.cloud.size() > 0 else "",
			"quantity": 8,
			"reward_multiplier": 1.0,
		}, null, faction.cloud.duplicate())
		_check(not live_reward.resource_rewards.is_empty(), "%s completion reward stays icon-based without icon fallback" % faction_name)
		_check(_reward_keys_are_in_signature(live_reward.resource_rewards, faction.cloud), "%s completion rewards stay inside signature" % faction_name)

	var rotatable = _find_rotatable_emoji(icon_registry)
	_check(rotatable != "", "found rotatable atom coupling")
	if rotatable != "":
		var atom = icon_registry.get_atom(rotatable)
		var before = atom.hamiltonian_couplings.duplicate(true)
		var changed = icon_registry.rotate_phase_for_emoji(rotatable, 0.2)
		var atom_after = icon_registry.get_atom(rotatable)
		var after = atom_after.hamiltonian_couplings if atom_after != null else {}
		_check(changed, "phase rotation mutates at least one atom")
		_check(before != after, "phase rotation changes the coupling map")

	print("Result: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _reward_keys_are_in_signature(reward, signature: Array) -> bool:
	var sig: Dictionary = {}
	for emoji in signature:
		sig[str(emoji)] = true
	for emoji in reward.keys():
		if not sig.has(str(emoji)):
			push_error("reward key not in signature: %s" % str(emoji))
			return false
	return true


func _find_rotatable_emoji(icon_registry) -> String:
	if icon_registry == null or not icon_registry.has_method("get_all_atoms"):
		return ""
	for atom in icon_registry.get_all_atoms():
		if atom == null or not atom.has_method("get_coupled_emojis"):
			continue
		for value in atom.hamiltonian_couplings.values():
			if value is Vector2:
				return str(atom.emoji)
			if value is Array and value.size() == 2:
				return str(atom.emoji)
	return ""


func _resolve_icon_registry():
	# Headless SceneTree runs skip project autoloads; install the registry at
	# /root/IconRegistry so every production static that resolves the autoload
	# path (StoryEngine, QuestRewards, FactionDensityMatrix) finds it.
	var icon_registry = root.get_node_or_null("/root/IconRegistry") if root else null
	if icon_registry != null and icon_registry.has_method("get_cloud_physics"):
		return icon_registry
	icon_registry = load("res://Core/Factions/IconRegistry.gd").new()
	icon_registry.name = "IconRegistry"
	root.add_child(icon_registry)
	return icon_registry


func _check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
		print("  PASS  %s" % label)
	else:
		failed += 1
		print("  FAIL  %s" % label)
