extends SceneTree

## Headless entry point: compose the access tree across all factions × all
## unlocked biomes for the default scenario, pretty-print to stdout, write
## decorated JSON to /tmp/authority_tree.json.
##
## Run: godot --headless --script res://tests/run_authority_compose.gd [-- <faction_name>]

const AdapterScript    = preload("res://Core/Factions/AuthorityAdapter.gd")
const BiomeRegistryS   = preload("res://Core/Biomes/BiomeRegistry.gd")


func _init() -> void:
	var only_faction := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		only_faction = String(args[0])

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

	print("[authority-compose] factions=%d  biomes=%d" % [factions.size(), biomes.size()])
	if factions.is_empty() or biomes.is_empty():
		printerr("[authority-compose] empty roster — aborting")
		quit(1)
		return

	var adapter = AdapterScript.new()
	var tree: Dictionary = adapter.compose_access_tree(factions, biomes)
	for fname in tree.keys():
		print("\n=== %s ===" % fname)
		for entry in tree[fname]:
			var icons_str = " ".join(entry.get("icons", []))
			var hats_str = " · ".join(entry.get("hats", []))
			if hats_str == "":
				hats_str = "(none)"
			print("  %-24s  fit=%.3f  icons=[%s]  hats=%s" % [
				entry.get("biome", "?"),
				float(entry.get("fit", 0.0)),
				icons_str,
				hats_str,
			])

	var out_path := "/tmp/authority_tree.json"
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(tree, "  "))
		f.close()
		print("\n[authority-compose] wrote %s" % out_path)
	else:
		printerr("[authority-compose] could not write %s" % out_path)

	quit(0)
