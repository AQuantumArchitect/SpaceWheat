extends SceneTree

## tests/smoke_test_base.gd — shared pass/fail harness for headless SceneTree
## smoke tests (slop-patrol 2026-07-29, Tier 2 knot #6).
##
## Extend BY PATH, not by class_name, so the editor class cache never needs a
## `godot --headless --import` pass after adding a test:
##
##     extends "res://tests/smoke_test_base.gd"
##
## Subclasses run their checks from _init() — or from a _process() first-frame
## guard when they touch /root/* autoload paths (production statics resolved
## via absolute get_node only work once the scene tree is active; see
## tests/story_icon_cutover_smoke.gd for the pattern) — then call
## _finish("suite name").
##
## Convention: `_check(cond, label)` — condition FIRST, label second. The
## historical per-file copies disagreed on this order (test_icon_relations.gd
## was label-first), which is exactly the footgun this base retires.

var passed: int = 0
var failed: int = 0


func _check(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  PASS  %s" % label)
	else:
		failed += 1
		if detail.is_empty():
			printerr("  FAIL  %s" % label)
		else:
			printerr("  FAIL  %s %s" % [label, detail])


func _fail(label: String) -> void:
	_check(false, label)


## Print the canonical summary line and quit with the pass/fail exit code.
func _finish(suite: String = "Result") -> void:
	print("\n%s: %d passed, %d failed" % [suite, passed, failed])
	_exit_by_result()


## For tests that print their own custom summary: quit-only tail.
func _exit_by_result() -> void:
	quit(0 if failed == 0 else 1)
