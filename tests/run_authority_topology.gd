extends SceneTree

## Headless entry point: compose the (icon-cloud → neighborhood → induced
## neighborhood loadout → composer → topology) bundle for one or all factions, pretty-
## print to stdout, write decorated JSON to /tmp/authority_topology.json.
##
## Run: godot --headless --script res://tests/run_authority_topology.gd [-- <faction_name>]

const AdapterScript    = preload("res://Core/Factions/AuthorityAdapter.gd")
const BiomeRegistryS   = preload("res://Core/Biomes/BiomeRegistry.gd")
const IconRegistryS    = preload("res://Core/Factions/IconRegistry.gd")


func _init() -> void:
	var only_faction := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		only_faction = String(args[0])
	call_deferred("_run", only_faction)


func _run(only_faction: String) -> void:

	# Boot the IconRegistry once so the adapter can resolve /root/IconRegistry.
	var icon_reg := IconRegistryS.new()
	icon_reg.name = "IconRegistry"
	root.add_child(icon_reg)

	var freg = FactionRegistry.new()
	freg.load_factions()
	var breg = BiomeRegistryS.new()

	var factions: Array = []
	if only_faction != "":
		var f = freg.get_by_name(only_faction)
		if f != null:
			factions = [f]
	else:
		factions = freg.get_all() if freg.has_method("get_all") else []

	var biomes: Array = breg.get_all() if breg.has_method("get_all") else []
	print("[authority-topology] factions=%d  biomes=%d" % [factions.size(), biomes.size()])
	if factions.is_empty() or biomes.is_empty():
		printerr("[authority-topology] empty roster — aborting")
		quit(1)
		return

	var parent := Node.new()
	parent.name = "TopologyHarness"
	root.add_child(parent)

	var adapter = AdapterScript.new()
	var topology: Dictionary = adapter.compose_topology(factions, biomes, parent)

	for fname in topology.keys():
		var rec: Dictionary = topology[fname]
		print("\n=== %s ===" % fname)
		var cloud: Array = rec.get("faction_cloud", [])
		print("faction_cloud (%d atoms): %s" % [cloud.size(), " ".join(cloud)])
		var via_cloud: Array = rec.get("siblings_via_cloud", [])
		var via_cloud_names := []
		for n in via_cloud:
			via_cloud_names.append("%s(%s/%s)" % [
				str(n.get("name", "?")),
				str(n.get("pole_0", "?")),
				str(n.get("pole_1", "?")),
			])
		print("siblings_via_cloud (%d): %s" % [via_cloud.size(), ", ".join(via_cloud_names)])
		var sibs: Array = rec.get("siblings", [])
		var sib_names := []
		for s in sibs:
			sib_names.append("%s(%s/%s)" % [
				str(s.get("name", "?")),
				str(s.get("pole_0", "?")),
				str(s.get("pole_1", "?")),
			])
		print("siblings (%d): %s" % [sibs.size(), ", ".join(sib_names) if not sib_names.is_empty() else "—"])
		var hood_rows: Array = rec.get("neighborhoods", [])
		print("neighborhoods (%d):" % hood_rows.size())
		for b in hood_rows:
			var icons_arr: Array = b.get("induced_signature", [])
			var icon_names := []
			for ic in icons_arr:
				icon_names.append(str(ic.get("name", "?")))
			var source_label: String = str(b.get("source", "?"))
			print("  %-24s overlap=%d  [%s] signature=[%s]  fit=%.3f" % [
				str(b.get("biome", "?")),
				int(b.get("overlap", 0)),
				source_label,
				", ".join(icon_names),
				float(b.get("fit", 0.0)),
			])
			var edges: Array = b.get("edges", [])
			if not edges.is_empty():
				var edge_pieces := []
				for e in edges:
					edge_pieces.append("%s=%.2f" % [str(e.get("hat", "?")), float(e.get("score", 0.0))])
				print("      %s" % "  ".join(edge_pieces))
		var stats: Dictionary = rec.get("stats", {})
		var cov: Dictionary = stats.get("hat_coverage", {})
		var cov_pieces := []
		for hk in cov.keys():
			cov_pieces.append("%s=%d" % [str(hk), int(cov[hk])])
		print("hat_coverage: %s" % ("  ".join(cov_pieces) if not cov_pieces.is_empty() else "—"))
		print("edges: %d" % int(stats.get("edge_count", 0)))

	var out_path := "/tmp/authority_topology.json"
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(topology, "  "))
		f.close()
		print("\n[authority-topology] wrote %s" % out_path)
	else:
		printerr("[authority-topology] could not write %s" % out_path)

	parent.free()
	icon_reg.free()

	quit(0)
