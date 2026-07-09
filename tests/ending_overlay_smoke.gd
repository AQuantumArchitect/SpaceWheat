extends SceneTree

## EndingOverlay smoke: walk every ceremony stage with the most hostile inputs
## (null farm, null shell, no postcards on disk) and assert it neither crashes
## nor leaks. The headed look is verified by the screenshot pass; this guards
## the control flow.

var passed: int = 0
var failed: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== EndingOverlay smoke ===")

	var overlay := EndingOverlay.new()
	overlay.name = "EndingOverlay"
	root.add_child(overlay)
	overlay.begin(null, null)
	await process_frame
	_check(overlay._stage == EndingOverlay.STAGE_TITLE, "begin() lands on the title stage")

	# Montage with zero postcards must skip straight to stats, not hang.
	overlay._enter_stage(EndingOverlay.STAGE_MONTAGE)
	await process_frame
	_check(overlay._stage == EndingOverlay.STAGE_STATS, "empty montage skips to stats")

	overlay._enter_stage(EndingOverlay.STAGE_CREDITS)
	await process_frame
	_check(overlay._content.get_child_count() > 0, "credits stage builds a roll")

	overlay._enter_stage(EndingOverlay.STAGE_DOOR)
	await process_frame
	_check(overlay._stage == EndingOverlay.STAGE_DOOR, "door stage reached")

	var finished := [false]
	overlay.ceremony_finished.connect(func(): finished[0] = true)
	overlay._close()
	await process_frame
	await process_frame
	_check(finished[0], "ceremony_finished emitted on close")
	_check(root.get_node_or_null("EndingOverlay") == null, "overlay frees itself")

	print("Result: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
		print("  PASS  %s" % label)
	else:
		failed += 1
		print("  FAIL  %s" % label)
