extends "res://tests/smoke_test_base.gd"

## Save compatibility floor smoke — uses the owner's REAL April 2026 save
## (tests/fixtures/pre_beta_save_v3.tres, the one that half-loaded into
## garbage on 2026-07-10: missing tunables, -2^63 credit payouts, degenerate
## Village ρ). The floor must refuse it cleanly and keep fresh v4 saves
## loadable.

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Save floor smoke ===")

	SaveStore.ensure_save_dir()
	var fixture := "res://tests/fixtures/pre_beta_save_v3.tres"
	var slot0 := SaveStore.get_save_path(0)
	var src := FileAccess.open(fixture, FileAccess.READ)
	_check(src != null, "fixture readable")
	if src == null:
		_finish()
		return
	var dst := FileAccess.open(slot0, FileAccess.WRITE)
	dst.store_buffer(src.get_buffer(src.get_length()))
	dst.close()
	src.close()

	_check(SaveStore.peek_save_version(slot0) == 3, "April save declares v3")
	_check(not SaveStore.is_save_compatible(slot0), "v3 is below the beta floor")
	_check(SaveStore.load_state(0) == null, "load_state refuses the pre-beta save")
	var info := SaveStore.get_save_info(0)
	_check(bool(info.get("exists", false)), "slot still reads as existing (file kept)")
	_check(info.get("compatible", true) == false, "slot info marked incompatible")
	_check(str(info.get("summary", "")).find("incompatible") >= 0, "slot summary says incompatible")

	# A fresh save written by THIS build must stamp v4 and load fine.
	var fresh = SaveStore.load_scenario("demos_normal")
	_check(fresh != null, "demos_normal scenario loads")
	if fresh != null:
		_check(fresh.save_version == SaveStore.MIN_COMPATIBLE_SAVE_VERSION,
			"fresh state carries the beta-floor version (v4)")
		_check(SaveStore.save_state(fresh, 0) == OK, "fresh save overwrites slot 0")
		_check(SaveStore.peek_save_version(slot0) == 4, "written save declares v4")
		_check(SaveStore.load_state(0) != null, "v4 save loads")

	# Clean up so other smokes see an empty dir.
	var dir = DirAccess.open(SaveStore.SAVE_DIR)
	if dir and dir.file_exists(slot0.get_file()):
		dir.remove(slot0.get_file())

	_finish()

