extends Object

## Contextual patches for the Captain frame's chips.
##
## R is Add Biome (a weighted random draw) EXCEPT while a story door is open
## and its biome is not on the spindle: then R charts THAT biome (owner
## decision — story biomes are reached deliberately, never by luck, and not for
## free). Farm.chart_target() is the one authority; the chip, the controls
## reference and the dispatcher all read it, so what the chip says is what R
## does. The action id stays "discover_biome" — Farm.discover_biome branches.


static func resolve_r(ctx) -> Dictionary:
	if ctx == null:
		return {}
	return chart_patch(ctx.farm)


## {label, hint, cost} when R will chart, else {}.
static func chart_patch(farm) -> Dictionary:
	var biome := chart_biome(farm)
	if biome == "":
		return {}
	var cost: Dictionary = CampaignRuntime.chart_cost()
	var price := ""
	for emoji in cost:
		price += "%s×%d" % [emoji, int(cost[emoji])]
	return {
		"label": chart_label(biome),
		"hint": "Chart %s — the open story door's biome, loaded deliberately (not a random draw). Costs %s." % [biome, price],
		"cost": cost,
	}


static func chart_biome(farm) -> String:
	if farm == null or not is_instance_valid(farm) or not farm.has_method("chart_target_biome"):
		return ""
	return str(farm.chart_target_biome())


static func chart_label(biome: String) -> String:
	return "Chart %s" % biome
