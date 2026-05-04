class_name FactionAffinity
extends RefCounted

## FactionAffinity — continuous [0,1] relationship scalar per emoji.
##
## Reads from the faction density matrix:
##     affinity(emoji) = Σ_{f ∈ speakers(emoji)} ρ[f, f]   (clamped [0,1])
##
## Optionally blended with the player's per-faction standing channels:
##     affinity ← clamp(affinity + 0.15 · mean(standing.scalar()), 0, 1)
##
## High affinity = the player's mythos state has mass on factions that speak
## this emoji. Used by ProbeActions for cost/reward weighting.


## Returns affinity ∈ [0,1] for a single emoji.
static func get_affinity(emoji: String, farm) -> float:
	if emoji == "":
		return 0.0
	var density = farm.faction_density
	var base: float = density.affinity_for_emoji(emoji)
	var standing_bonus: float = _standing_bonus_for_emoji(emoji, farm, density)
	return clampf(base + standing_bonus, 0.0, 1.0)


static func _standing_bonus_for_emoji(emoji: String, farm, density) -> float:
	# Average standing.scalar() across factions that speak this emoji,
	# weighted ±0.15. Returns 0 if no standings exist or no factions speak it.
	var standings: Dictionary = farm.faction_standings
	if standings.is_empty():
		return 0.0
	var speakers: Array = density.factions_speaking(emoji)
	if speakers.is_empty():
		return 0.0
	var total: float = 0.0
	var count: int = 0
	for fname in speakers:
		if standings.has(fname):
			var s = standings[fname]
			if s != null:
				total += s.scalar()
				count += 1
	if count == 0:
		return 0.0
	return (total / float(count)) * 0.15


## Pair affinity for an emoji pair — uses the minimum so the harder pole
## dominates. Matches the measurement semantics: either pole could be sampled,
## and the less-familiar one is what sets the difficulty.
static func get_pair_affinity(north_emoji: String, south_emoji: String, farm) -> float:
	return minf(get_affinity(north_emoji, farm), get_affinity(south_emoji, farm))
