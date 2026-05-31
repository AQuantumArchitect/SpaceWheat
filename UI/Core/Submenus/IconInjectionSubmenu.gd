class_name IconInjectionSubmenu
extends RefCounted

## Signature Injection Submenu
## Dynamic submenu for Icon frame Q action showing icon options sorted by biome affinity
## Supports F-cycling through multiple pages of options



static func generate_submenu(biome, farm, page: int = 0) -> Dictionary:
	# Generate dynamic submenu for icon injection.

	# Args:
	# biome: Current biome
	# farm: Farm instance (icon owner)
	# page: Page number for F-cycling (0 = first 3, 1 = next 3, etc.)

	# Returns:
	# Submenu with icon options sorted by affinity
	var options = _collect_options(biome, farm)

	if options.is_empty():
		return BaseSubmenu.empty_submenu(
			"icon_injection",
			"Inject Icon",
			"No icon available"
		)

	# Sort by affinity and apply costs
	options = _sort_by_affinity(options, biome)
	options = BaseSubmenu.apply_cost_to_options(options, farm.economy if farm else null)

	var pagination = BaseSubmenu.paginate(options, page)
	var actions = BaseSubmenu.build_actions(pagination.page_options, _build_icon_action)

	return BaseSubmenu.build_result(
		"icon_injection",
		"Inject Icon",
		pagination,
		actions
	)


static func _collect_options(biome, farm) -> Array:
	# Collect icons that can be injected into biome.

	# An icon is injectable if:
	# - Player has learned it (in known_icons)
	# - NOT already in biome's quantum computer
	var options: Array = []

	if not farm:
		return options

	# Gather all known icons
	var icons: Array = _collect_injectable_icons(farm, biome)
	var seen: Dictionary = {}

	for icon in icons:
		var north = icon.get("north", "")
		var south = icon.get("south", "")

		if north == "" or south == "" or north == south:
			continue

		# Dedupe
		var key = "%s|%s" % [north, south]
		if seen.has(key):
			continue
		seen[key] = true

		# Build option with cost
		options.append({
			"north": north,
			"south": south,
			"label": "%s/%s" % [north, south],
			"cost": _get_injection_cost(farm, south),
			"enabled": true
		})

	return options


static func _sort_by_affinity(options: Array, biome) -> Array:
	# Sort icon options by descending affinity to biome.
	for option in options:
		var icon = {"north": option.get("north", ""), "south": option.get("south", "")}
		var affinity = BiomeAlignmentCalculator.calculate_affinity(icon, biome)
		option["affinity"] = affinity
		option["hint"] = "Affinity: %.2f" % affinity

	return BaseSubmenu.sort_by_field(options, "affinity", true)


static func _build_icon_action(option: Dictionary) -> Dictionary:
	# Build action data for an icon option.
	return {
		"action": "inject_icon",
		"icon": {
			"north": option.get("north", ""),
			"south": option.get("south", "")
		},
		"label": option.get("label", ""),
		"hint": option.get("hint", ""),
		"affinity": option.get("affinity", 0.0),
		"cost": option.get("cost", {}),
		"cost_display": option.get("cost_display", ""),
		"can_afford": option.get("can_afford", true),
		"enabled": option.get("enabled", true)
	}


static func _get_injection_cost(farm, south_emoji: String) -> Dictionary:
	# Get cost for injecting a icon.
	return ActionCostRuntime.get_action_cost(farm, "inject_icon", {"south_emoji": south_emoji})


static func _collect_known_icons(farm_ref) -> Array:
	if farm_ref and farm_ref.has_method("get_known_icons"):
		return farm_ref.get_known_icons()
	return []


static func _collect_injectable_icons(farm_ref, biome = null) -> Array:
	var known = _collect_known_icons(farm_ref)
	var filtered: Array = []
	var seen: Dictionary = {}
	for icon in known:
		if not (icon is Dictionary):
			continue
		var north = str(icon.get("north", ""))
		var south = str(icon.get("south", ""))
		if north == "" or south == "" or north == south:
			continue
		if biome and biome.viz_cache and biome.viz_cache.has_metadata():
			if biome.viz_cache.get_qubit(north) >= 0 or biome.viz_cache.get_qubit(south) >= 0:
				continue
		var key = "%s|%s" % [north, south]
		if seen.has(key):
			continue
		seen[key] = true
		filtered.append({"north": north, "south": south})
	return filtered
