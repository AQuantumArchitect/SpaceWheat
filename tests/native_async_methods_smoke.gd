extends SceneTree

func _init() -> void:
	if not ClassDB.class_exists("MultiBiomeLookaheadEngine"):
		push_error("MultiBiomeLookaheadEngine missing")
		quit(1)
		return
	var engine = ClassDB.instantiate("MultiBiomeLookaheadEngine")
	if engine == null:
		push_error("MultiBiomeLookaheadEngine instantiate failed")
		quit(1)
		return
	for method_name in [
		"submit_lookahead_job",
		"is_lookahead_job_running",
		"is_lookahead_job_complete",
		"take_completed_lookahead_job",
		"cancel_lookahead_job",
		"set_node_positions",
	]:
		if not engine.has_method(method_name):
			push_error("missing method: %s" % method_name)
			quit(1)
			return
	print("native async methods smoke ok")
	quit(0)
