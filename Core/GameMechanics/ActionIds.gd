class_name ActionIds
extends RefCounted

## Canonical action ids shared across UI, economy, and rig layers.

const INJECT_VOCAB := "inject_vocabulary"
const LINDBLAD_PUMP := "lindblad_pump"
const LINDBLAD_DRAIN := "lindblad_drain"
const DISCOVER_BIOME := "discover_biome"
const REMOVE_BIOME := "remove_biome"
const SPARK_NORTH := "spark_north"
const SPARK_SOUTH := "spark_south"

const ACTION_ALIASES: Dictionary = {
	"icon_injection": INJECT_VOCAB,
	"pump": LINDBLAD_PUMP,
	"drain": LINDBLAD_DRAIN,
	"lindblad_drive": LINDBLAD_PUMP,
	"lindblad_decay": LINDBLAD_DRAIN,
}


static func normalize_action(action: String) -> String:
	if action == "":
		return ""
	return str(ACTION_ALIASES.get(action, action))
