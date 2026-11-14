class_name ObjectiveTargets
extends Object

## One mechanism for "the button the gold toast / objective is asking for".
##
## UIProgression.objective_target() names a key ("U", "R", "C", ...). Any
## control that IS that key's button registers against the id here; the
## ObjectiveSpotlight resolves the live target, tints it gold (the gold toast's
## own color) and breathes it. No per-button special cases: a new button joins
## by calling register(); the target is always derived from objective state.
##
## Also owns the retirement rule for the main action verbs: once the player has
## used Q, E or R MAIN_ACTION_USES times, their highlight stays dark. The counts
## persist in Farm.highlight_uses (GameState.highlight_uses on disk).

## HintToast importance-3 gold border (UI/Widgets/ActFilament.BORDER_GOLD).
const GOLD := Color(1.0, 0.82, 0.2, 0.95)
## Modulate that reads as that gold on a white-ish glyph/label.
const GOLD_MODULATE := Color(1.0, 0.82, 0.2, 1.0)

const MAIN_ACTIONS := ["Q", "E", "R"]
const MAIN_ACTION_USES := 3

# id -> Array[Control]. Only visible-in-tree controls resolve, so the C and X
# overlays can both register their own "U" tab and the open one wins.
static var _registry: Dictionary = {}


static func register(id: String, control: Control) -> void:
	if control == null or id == "":
		return
	var list: Array = _registry.get(id, [])
	list = list.filter(func(c): return is_instance_valid(c))
	if not list.has(control):
		list.append(control)
	_registry[id] = list


## First registered control for id that is alive and on screen, else null.
static func resolve(id: String) -> Control:
	for c in _registry.get(id, []):
		if is_instance_valid(c) and (c as Control).is_visible_in_tree():
			return c
	return null


static func clear_registry() -> void:
	_registry.clear()


static func uses_of(farm, action_key: String) -> int:
	if farm == null or not ("highlight_uses" in farm) or not (farm.highlight_uses is Dictionary):
		return 0
	return int(farm.highlight_uses.get(action_key, 0))


static func note_use(farm, action_key: String) -> void:
	if farm == null or not (action_key in MAIN_ACTIONS):
		return
	if not ("highlight_uses" in farm) or not (farm.highlight_uses is Dictionary):
		return
	farm.highlight_uses[action_key] = uses_of(farm, action_key) + 1


## True once a main action has been used enough that it no longer glows.
static func is_retired(farm, action_key: String) -> bool:
	return action_key in MAIN_ACTIONS and uses_of(farm, action_key) >= MAIN_ACTION_USES
