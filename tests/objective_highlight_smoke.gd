extends "res://tests/smoke_test_base.gd"

## #117: a control registered against an objective target id is what the
## spotlight tints gold. Dummy controls stand in for a row, a verb chip, a tab.

const ObjectiveSpotlightScript = preload("res://UI/Widgets/ObjectiveSpotlight.gd")


class FarmStub:
	extends RefCounted
	var highlight_uses: Dictionary = {}


var _ran := false


## Run on the first frame, not in _init(): only then is /root inside the tree,
## so is_visible_in_tree() (what ObjectiveTargets.resolve reads) can be true.
func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run()
	return false


func _run() -> void:
	ObjectiveTargets.clear_registry()
	var root_ctl := Control.new()
	get_root().add_child(root_ctl)
	var spot = ObjectiveSpotlightScript.new()
	root_ctl.add_child(spot)

	for id in ["row:G", "R", "U", "F"]:
		var c := Control.new()
		c.size = Vector2(40, 20)
		root_ctl.add_child(c)
		ObjectiveTargets.register(id, c)
		var got := ObjectiveTargets.resolve(id)
		_check(got == c, "%s resolves to its registered control" % id)
		spot._start_pulse(got)
		_check(c.modulate.is_equal_approx(ObjectiveTargets.GOLD_MODULATE),
			"%s is tinted gold by the spotlight" % id)
		spot._stop_pulse()

	var hidden := Control.new()
	root_ctl.add_child(hidden)
	hidden.visible = false
	ObjectiveTargets.register("row:H", hidden)
	_check(ObjectiveTargets.resolve("row:H") == null, "a hidden control never resolves")
	_check(ObjectiveTargets.row_id("J") == "row:J", "row ids are row:<key>")

	var farm := FarmStub.new()
	for k in range(ObjectiveTargets.MAIN_ACTION_USES):
		_check(not ObjectiveTargets.is_retired(farm, "Q"), "Q glows before use %d" % (k + 1))
		ObjectiveTargets.note_use(farm, "Q")
	_check(ObjectiveTargets.is_retired(farm, "Q"), "Q retires after 3 uses")
	_check(not ObjectiveTargets.is_retired(farm, "U"), "non-main keys never retire")
	_finish("Objective highlight smoke")
