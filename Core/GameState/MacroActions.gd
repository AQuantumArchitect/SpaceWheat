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
##   - inject_vocabulary  (expand a biome's signature / density matrix)
##   - remove_vocabulary  (trim a biome's signature)
##
## Thin wrapper around QuantumInstrument.action_* methods — no policy, only
## routing.

const KIND_DISCOVER_BIOME := "discover_biome"
const KIND_REMOVE_BIOME := "remove_biome"
const KIND_INJECT_VOCABULARY := "inject_vocabulary"
const KIND_INJECT_VOCABULARY_PAIR := "inject_vocabulary_pair"
const KIND_REMOVE_VOCABULARY := "remove_vocabulary"

const KINDS := [
	KIND_DISCOVER_BIOME,
	KIND_REMOVE_BIOME,
	KIND_INJECT_VOCABULARY,
	KIND_INJECT_VOCABULARY_PAIR,
	KIND_REMOVE_VOCABULARY,
]


## Is `action_name` a macro/meta action that must route through this module?
static func is_macro_action(action_name: String) -> bool:
	return action_name in KINDS


## Dispatch a macro action against a QuantumInstrument.
##
## args keys (by kind):
##   discover_biome:          (none)
##   remove_biome:            (none)
##   inject_vocabulary:       biome_name
##   inject_vocabulary_pair:  biome_name, icon {north, south}
##   remove_vocabulary:       biome_name, grid_pos (Vector2i)
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
		KIND_INJECT_VOCABULARY:
			var biome_name: String = args.get("biome_name", "")
			return instrument.action_inject_vocabulary(biome_name)
		KIND_INJECT_VOCABULARY_PAIR:
			var biome_name: String = args.get("biome_name", "")
			var pair: Dictionary = args.get("icon", {})
			return instrument.action_inject_vocabulary_pair(biome_name, pair)
		KIND_REMOVE_VOCABULARY:
			var biome_name: String = args.get("biome_name", "")
			var grid_pos: Vector2i = args.get("grid_pos", Vector2i.ZERO)
			return instrument.action_remove_vocabulary(biome_name, grid_pos)
		_:
			return {"success": false, "error": "unknown_macro_action", "message": "Unknown macro action: %s" % kind}
