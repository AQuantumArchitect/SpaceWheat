class_name MacroActions
extends RefCounted

## MacroActions - Façade for world-level structural actions.
##
## Extracts the four structural operations into a single dispatch point so any
## caller (farm input, M overlay, headless runner, tests) can invoke them the
## same way:
##
##   - discover_biome     (bring a biome into the spindle)
##   - remove_biome       (cull a biome from the live pool)
##   - inject_icon        (expand a biome's signature / density matrix)
##   - remove_icon        (trim a biome's signature)
##
## Thin wrapper around QuantumInstrument.action_* methods — no policy, only
## routing.

const KIND_DISCOVER_BIOME := "discover_biome"
const KIND_REMOVE_BIOME := "remove_biome"
const KIND_INJECT_ICON := "inject_icon"
const KIND_INJECT_ICON_PAIR := "inject_icon_pair"
const KIND_REMOVE_ICON := "remove_icon"

const KINDS := [
	KIND_DISCOVER_BIOME,
	KIND_REMOVE_BIOME,
	KIND_INJECT_ICON,
	KIND_INJECT_ICON_PAIR,
	KIND_REMOVE_ICON,
]


## Is `action_name` a macro/meta action that must route through this module?
static func is_macro_action(action_name: String) -> bool:
	return action_name in KINDS


## Dispatch a macro action against a QuantumInstrument.
##
## args keys (by kind):
##   discover_biome:          (none)
##   remove_biome:            (none)
##   inject_icon:       biome_name
##   inject_icon_pair:  biome_name, icon {north, south}
##   remove_icon:       biome_name, grid_pos (Vector2i)
##
## Returns the raw instrument result Dictionary (success flag, cost, message).
static func dispatch(instrument, kind: String, args: Dictionary = {}) -> Dictionary:
	if instrument == null:
		return {"success": false, "error": "no_instrument", "message": "No QuantumInstrument provided"}
	match kind:
		KIND_DISCOVER_BIOME:
			return instrument.action_discover_biome()
		KIND_REMOVE_BIOME:
			return instrument.action_remove_biome()
		KIND_INJECT_ICON:
			var biome_name: String = args.get("biome_name", "")
			return instrument.action_inject_icon(biome_name)
		KIND_INJECT_ICON_PAIR:
			var biome_name: String = args.get("biome_name", "")
			var icon: Dictionary = args.get("icon", {})
			return instrument.action_inject_icon_pair(biome_name, icon)
		KIND_REMOVE_ICON:
			var biome_name: String = args.get("biome_name", "")
			var grid_pos: Vector2i = args.get("grid_pos", Vector2i.ZERO)
			return instrument.action_remove_icon(biome_name, grid_pos)
		_:
			return {"success": false, "error": "unknown_macro_action", "message": "Unknown macro action: %s" % kind}
