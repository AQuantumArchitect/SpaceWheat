class_name ActionIds
extends RefCounted

## Canonical action ids shared across UI, economy, and rig layers.

const INJECT_ICON := "inject_icon"
const LINDBLAD_PUMP := "lindblad_pump"
const LINDBLAD_DRAIN := "lindblad_drain"
const SPARK_NORTH := "spark_north"
const SPARK_SOUTH := "spark_south"
const ENTER_ICON := "enter_icon"

const ACTION_ALIASES: Dictionary = {
	"icon_injection": INJECT_ICON,
	"pump": LINDBLAD_PUMP,
	"drain": LINDBLAD_DRAIN,
	"lindblad_drive": LINDBLAD_PUMP,
	"lindblad_decay": LINDBLAD_DRAIN,
}


static func normalize_action(action: String) -> String:
	if action == "":
		return ""
	return str(ACTION_ALIASES.get(action, action))
