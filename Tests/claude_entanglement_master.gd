extends SceneTree

## 🌀 CLAUDE HUNTS ENTANGLEMENT MASTER - v2 "for fun" rig
## This version uses ProbeHandler + GateActionHandler (v2 pipeline).

const ProbeHandler = preload("res://UI/Handlers/ProbeHandler.gd")
const GateActionHandler = preload("res://UI/Handlers/GateActionHandler.gd")

var farm = null
var plot_pool = null
var biotic_flux = null

var scene_loaded := false
var game_ready := false
var frame_count := 0

var entanglements_created := 0
var explored_positions: Array[Vector2i] = []


func _init():
	print("\n" + "=".repeat(80))
	print("🌀 CLAUDE HUNTS ENTANGLEMENT MASTER (v2 rig, for fun)")
	print("=".repeat(80))
	print("Mission:")
	print("  1. Create entanglement via Tool 3 handlers")
	print("  2. Test cluster + bell pair + CNOT")
	print("  3. Bail if it is awful")
	print("=".repeat(80) + "\n")


func _process(_delta):
	frame_count += 1
	if frame_count == 5 and not scene_loaded:
		_load_scene()


func _load_scene():
	print("📦 Loading FarmView...")
	var scene = load("res://scenes/FarmView.tscn")
	if scene:
		var instance = scene.instantiate()
		root.add_child(instance)
		scene_loaded = true
		var boot = root.get_node_or_null("/root/BootManager")
		if boot:
			boot.game_ready.connect(_on_game_ready)
	else:
		print("❌ Failed to load FarmView.tscn")
		quit(1)


func _on_game_ready():
	if game_ready:
		return
	game_ready = true

	_find_components()
	if not _validate_components():
		quit(1)
		return

	await _execute_master_plan()
	_print_final_report()
	quit(0)


func _find_components():
	var farm_view = root.get_node_or_null("FarmView")
	if farm_view and "farm" in farm_view:
		farm = farm_view.farm
		plot_pool = farm.plot_pool if farm else null
		biotic_flux = farm.biotic_flux_biome if farm else null

	print("📋 Components: Farm=%s Pool=%s Biome=%s" % [
		farm != null, plot_pool != null, biotic_flux != null
	])


func _validate_components() -> bool:
	return farm != null and plot_pool != null and biotic_flux != null and farm.grid != null


func _execute_master_plan():
	print("\n📋 STRATEGY: Explore terminals, then entangle\n")

	var grid_width = farm.grid.grid_width
	var grid_height = farm.grid.grid_height
	var max_positions = min(plot_pool.pool_size, grid_width * grid_height)

	explored_positions = _collect_positions(max_positions, grid_width, grid_height)
	print("🌱 PHASE 1: EXPLORE %d positions (bind terminals)" % explored_positions.size())

	var explore_result = ProbeHandler.explore(farm, plot_pool, explored_positions)
	if not explore_result.success:
		print("   ❌ Explore failed: %s" % explore_result.get("message", "unknown"))
		return

	print("   ✅ Explored %d/%d positions" % [
		explore_result.explored_count,
		explored_positions.size()
	])

	print("\n🔗 PHASE 2: Entanglement patterns")

	var cluster_result = GateActionHandler.cluster(farm, explored_positions)
	if cluster_result.success:
		entanglements_created += cluster_result.entanglement_count
		print("   ✅ Cluster: %d entanglements (%d terminals)" % [
			cluster_result.entanglement_count,
			cluster_result.terminal_count
		])
	else:
		print("   ❌ Cluster failed: %s" % cluster_result.get("message", "unknown"))

	if explored_positions.size() >= 2:
		var bell_pair_positions = [explored_positions[0], explored_positions[1]]
		var bell_result = GateActionHandler.create_bell_pair(farm, bell_pair_positions)
		if bell_result.success:
			entanglements_created += 1
			print("   ✅ Bell pair created at %s ↔ %s" % bell_pair_positions)
		else:
			print("   ❌ Bell pair failed: %s" % bell_result.get("message", "unknown"))

	if explored_positions.size() >= 4:
		var cnot_positions = explored_positions.slice(0, 4)
		var cnot_result = GateActionHandler.apply_cnot(farm, cnot_positions)
		if cnot_result.success:
			print("   ✅ CNOT applied to %d pair(s)" % cnot_result.pair_count)
		else:
			print("   ❌ CNOT failed: %s" % cnot_result.get("message", "unknown"))

	print("\n🔍 PHASE 3: Inspect entanglement")
	var inspect_positions = explored_positions.slice(0, min(6, explored_positions.size()))
	var inspect_result = GateActionHandler.inspect_entanglement(farm, inspect_positions)
	if inspect_result.success:
		for info in inspect_result.entanglement_info:
			print("   Plot %s -> entangled with %s" % [
				info.position,
				info.entangled_with
			])
	else:
		print("   ❌ Inspect failed: %s" % inspect_result.get("message", "unknown"))


func _collect_positions(limit: int, grid_width: int, grid_height: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for y in range(grid_height):
		for x in range(grid_width):
			if positions.size() >= limit:
				return positions
			positions.append(Vector2i(x, y))
	return positions


func _print_final_report():
	print("\n" + "=".repeat(80))
	print("📊 ENTANGLEMENT MASTER QUEST COMPLETE - FINAL REPORT")
	print("=".repeat(80))

	var wheat = farm.economy.get_resource("🌾") if farm and farm.economy else 0
	var labor = farm.economy.get_resource("👥") if farm and farm.economy else 0

	print("\n💰 Final Resources:")
	print("   🌾 Wheat: %d credits" % wheat)
	print("   👥 Labor: %d credits" % labor)

	print("\n🔗 Entanglement Statistics:")
	print("   Total entanglements created (rig count): %d" % entanglements_created)

	if farm and farm.goals:
		print("   Goal progress: %d/10" % farm.goals.progress["entanglement_count"])
	else:
		print("   Goal progress: n/a (goals not available)")

	print("\n" + "=".repeat(80))
