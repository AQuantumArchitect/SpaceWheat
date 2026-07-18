extends SceneTree

## Semantica explorer (W3b) — browsable-load proof.
## Run: SEMANTICA_EXPLORER=1 godot --headless --script tests/semantica_explorer_load_proof.gd
##
## Proves the ONE-WAY COMPILER's output (Core/Config/semantica/*.biome.json,
## *.icons.json, compiled by 🍄/🧪/semantica_compiler.py from an umwelt world
## spec) loads into the live registries and is browsable: the compiled biome
## exists by name, carries its organ-plot emojis, and its axis icons carry
## real H physics (rabi_coupling > 0). This is the "look" proof stood in for
## headless-native terms — BiomeRegistry/IconRegistry ARE what a `look`
## ultimately reads through BiomeBase/PlotGridDisplay.
##
## Also proves boot-neutrality: with the flag OFF (the default a player boots
## with), the compiled biome must NOT appear.

const IconRegistryS = preload("res://Core/Factions/IconRegistry.gd")

var passed = 0
var failed = 0


func _init():
	print("\n=== Semantica explorer load proof ===")
	print("SEMANTICA_EXPLORER=%s" % OS.get_environment("SEMANTICA_EXPLORER"))

	# IconRegistry is normally an autoload (/root/IconRegistry); a bare --script
	# SceneTree run has no autoloads, so boot it manually (same idiom as
	# tests/run_authority_topology.gd).
	var icon_reg := IconRegistryS.new()
	icon_reg.name = "IconRegistry"
	root.add_child(icon_reg)

	BiomeRegistry.reset_shared()
	var reg = BiomeRegistry.get_shared()
	var yurt_mood = reg.get_by_name("YurtMood")

	if RuntimeEnv.semantica_explorer():
		_check(yurt_mood != null, "YurtMood biome loads when SEMANTICA_EXPLORER=1")
		if yurt_mood != null:
			_check(yurt_mood.discovered, "YurtMood is discovered (browsable, no unlock gate)")
			_check(yurt_mood.emojis.size() >= 8, "YurtMood carries organ + axis emojis (>=8, got %d)" % yurt_mood.emojis.size())
			_check(yurt_mood.plot_layout.size() == 7, "YurtMood has 7 plots, one per organ (got %d)" % yurt_mood.plot_layout.size())
			_check(not yurt_mood.atom_components.is_empty(), "YurtMood carries sparse L (atom_components non-empty)")

			print("\n--- simulated `look`: organ plots ---")
			var organ_names = ["wargen_head", "potato_seat", "roc_muscle", "succession",
				"lane_spacewheat", "lane_bar", "lane_semantica"]
			var organ_icons = ["🧠", "🥔", "🦅", "🪢", "🌾", "🍺", "🧬"]
			for i in range(yurt_mood.plot_layout.size()):
				var glyph = organ_icons[i] if i < organ_icons.size() else "?"
				var oname = organ_names[i] if i < organ_names.size() else "?"
				print("  plot %d [%s]  %s  x=%.2f" % [i, glyph, oname, yurt_mood.plot_layout[i].get("x", 0.0)])
			print("  biome emojis: %s" % [yurt_mood.emojis])

		# Icon axes: pull physics via IconRegistry (autoload).
		var axes = [["Activity", "🔥", "💤"], ["Confidence", "✅", "🔮"],
			["Blocked", "🟢", "🚧"], ["Freshness", "✨", "🍂"], ["Coordination", "🤝", "🏃"]]
		print("\n--- simulated `look`: axis icons (H physics) ---")
		var all_have_rabi := true
		for row in axes:
			var physics = icon_reg.get_icon_physics_by_pair(row[1], row[2])
			var rabi = float(physics.get("rabi_coupling", 0.0))
			print("  %s  %s/%s  rabi_coupling=%.3f" % [row[0], row[1], row[2], rabi])
			if rabi <= 0.0:
				all_have_rabi = false
		_check(all_have_rabi, "every compiled axis icon carries rabi_coupling > 0")
	else:
		_check(yurt_mood == null, "YurtMood biome does NOT load when SEMANTICA_EXPLORER unset (boot-neutral)")

	print("\nResult: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
		print("  PASS  %s" % label)
	else:
		failed += 1
		push_error("  FAIL  %s" % label)
