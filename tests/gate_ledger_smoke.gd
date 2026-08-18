extends "res://tests/smoke_test_base.gd"

## Pins the 2026-08-17 durable gate ledger (the reap-stall fix) at unit level:
## - gate_sequence_contains reads lifetime counters, so a counted gate can
##   never be evicted by later play (the old 64-row ring forgot a reap done
##   ~64 keypresses before its quest existed),
## - an explicit success:false action never records (a broke player mashing
##   Shift+F got "Need 🍼×1" refusals while silently completing the step),
## - the counters serialize/restore (the ring was never saved — a load wiped
##   the reap the quest was about to credit),
## - gate_order still reads the ORDERED ring (counts can't spell braid words).
## Plus the contract-purity filter against the REAL QuestManager:
## commitment_quests() excludes auto-advancing tutorial steps and keeps
## market/ARC/manual-delivery commitments, in insertion order.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Gate ledger smoke ===")

	var svc := QuestStateProjectionService.new()
	var reap_pred := {"type": "gate_sequence_contains", "gate": "reap", "count": 1}

	# Success records; explicit failure does not; no success key counts.
	svc.record_action("reap", {"success": true, "rite_credits": 2})
	_check(int(svc.gate_counters.get("reap", 0)) == 1, "a successful gate counts once")
	svc.record_action("reap", {"success": false})
	_check(int(svc.gate_counters.get("reap", 0)) == 1, "a refused gate never counts")
	svc.record_action("accept_quest", {"quest_id": 7})
	_check(int(svc.gate_counters.get("accept_quest", 0)) == 1,
		"bookkeeping payloads without a success key still count")
	_check(svc.evaluate_predicate(reap_pred) >= 1.0, "reap predicate satisfied at one gate")

	# Eviction immunity: bury the reap under 300 later actions — far past the
	# ring — and the predicate must not forget it.
	for i in range(300):
		svc.record_action("probe_cycle", {})
	_check(svc.evaluate_predicate(reap_pred) >= 1.0,
		"300 later actions cannot evict a counted gate")
	_check(svc.get_snapshot()["recent_actions"].size() <= 256,
		"the ordered ring stays bounded")

	# Substring semantics preserved: "bell" matches "gate_inject:bell".
	svc.record_action("gate_inject:bell", {"success": true})
	var bell_pred := {"type": "gate_sequence_contains", "gate": "bell", "count": 1}
	_check(svc.evaluate_predicate(bell_pred) >= 1.0,
		"substring match still credits namespaced gates")

	# Save/load roundtrip: counters survive; a fresh service restored from the
	# serialized dict satisfies the same predicates with an empty ring.
	var saved: Dictionary = svc.serialize_gate_counters()
	var svc2 := QuestStateProjectionService.new()
	_check(svc2.evaluate_predicate(reap_pred) == 0.0, "a fresh service starts at zero")
	svc2.restore_gate_counters(saved)
	_check(svc2.evaluate_predicate(reap_pred) >= 1.0,
		"restored counters satisfy the predicate with an empty ring (the load-wipe stall is dead)")
	svc2.restore_gate_counters({})
	_check(svc2.evaluate_predicate(reap_pred) == 0.0,
		"a pre-ledger save restores empty, not stale")

	# gate_order still spells from the ORDERED ring, not the counters.
	var svc3 := QuestStateProjectionService.new()
	svc3.record_action("cnot", {"success": true})
	svc3.record_action("hadamard", {"success": true})
	var word := {"type": "gate_order", "gates": ["hadamard", "cnot"]}
	_check(svc3.evaluate_predicate(word) < 1.0,
		"gate_order needs the order, not just the counts")
	svc3.record_action("cnot", {"success": true})
	_check(svc3.evaluate_predicate(word) >= 1.0, "gate_order completes in order")

	# --- contract purity against the REAL QuestManager rule ---
	var qm := QuestManager.new()
	root.add_child(qm)
	await process_frame
	var auto_step := {"id": 1, "category": "TUTORIAL",
		"state_predicates": [{"type": "gate_sequence_contains", "gate": "measure", "count": 1}]}
	var manual_delivery := {"id": 2, "category": "TUTORIAL", "type": 1,
		"resource": "🌾", "quantity": 2, "state_predicates": []}
	var market := {"id": 3, "category": "", "resource": "🪵", "quantity": 4}
	var arc := {"id": 4, "category": "ARC",
		"state_predicates": [{"type": "coherence_at_least", "value": 0.3}]}
	_check(qm.tutorial_auto_advances(auto_step), "predicate tutorial steps auto-advance")
	_check(not qm.tutorial_auto_advances(manual_delivery),
		"the manual DELIVERY step does not auto-advance")
	_check(not qm.tutorial_auto_advances(arc), "ARC quests never auto-advance")
	qm.active_quests = {1: auto_step, 2: manual_delivery, 3: market, 4: arc}
	var commitments: Array = qm.commitment_quests()
	var ids: Array = []
	for q in commitments:
		ids.append(int(q.get("id", -1)))
	_check(ids == [2, 3, 4],
		"Commitments = manual delivery + market + ARC, insertion order; auto-advancing steps stay off the CONTRACTS board")
	qm.queue_free()

	_finish("Gate ledger smoke")
