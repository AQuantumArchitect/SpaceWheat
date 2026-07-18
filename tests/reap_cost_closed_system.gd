@tool
extends SceneTree

## tests/reap_cost_closed_system.gd — pin d1-06: BalanceService.get_reap_cost()
## must NEVER silently return {} because the closed (non-dissipative) system
## is active. Reap cost is an INVENTORY spend (🍼 Midwife tokens), not a
## quantum-physics cost — the quantum state itself is unitary and never
## depletes (r=1), but the game-economy fee for a reap read is real in BOTH
## open and closed modes. This was tried once (commit 9f415622, "zero all
## action costs in Hamiltonian-only mode") and explicitly reverted by owner
## ruling (commit 65311d32): "Inventory costs are REAL in both systems... the
## escape from the resource spiral is the vocabulary-reward multiplier, not
## free actions." dissipative_enabled() must stay a pure PHYSICS gate
## (Lindblad pump/drain), never wired into reap pricing again.
##
## Run: godot --headless -s tests/reap_cost_closed_system.gd


func _init() -> void:
	print("\n=== REAP COST / CLOSED SYSTEM TEST (d1-06) ===")
	var failures: int = 0

	# Test 1: closed system (dissipative OFF — the shipped native default):
	# get_reap_cost() must return a real, non-empty cost, never {}.
	BalanceConfig.merge_physics_override({"dissipative_dynamics": false})
	if BalanceConfig.dissipative_enabled():
		print("FAIL: could not force dissipative_dynamics=false for the closed-mode check")
		failures += 1
	var closed_cost: Dictionary = BalanceService.get_reap_cost(null, 0)
	if closed_cost.is_empty():
		print("FAIL: get_reap_cost() returned {} in closed (non-dissipative) mode — reap would be silently free")
		failures += 1
	elif not closed_cost.has(EconomyConstants.MIDWIFE_EMOJI):
		print("FAIL: closed-mode reap cost missing %s, got %s" % [EconomyConstants.MIDWIFE_EMOJI, str(closed_cost)])
		failures += 1

	# Test 2: open system (dissipative ON): reap cost must still be charged,
	# and — since reap is an inventory spend independent of the quantum
	# generator — the SAME cost as closed mode for the same reap_count.
	BalanceConfig.merge_physics_override({"dissipative_dynamics": true})
	if not BalanceConfig.dissipative_enabled():
		print("FAIL: could not force dissipative_dynamics=true for the open-mode check")
		failures += 1
	var open_cost: Dictionary = BalanceService.get_reap_cost(null, 0)
	if open_cost.is_empty():
		print("FAIL: get_reap_cost() returned {} in open (dissipative) mode")
		failures += 1
	elif not open_cost.has(EconomyConstants.MIDWIFE_EMOJI):
		print("FAIL: open-mode reap cost missing %s, got %s" % [EconomyConstants.MIDWIFE_EMOJI, str(open_cost)])
		failures += 1

	if not closed_cost.is_empty() and not open_cost.is_empty():
		if int(closed_cost[EconomyConstants.MIDWIFE_EMOJI]) != int(open_cost[EconomyConstants.MIDWIFE_EMOJI]):
			print("FAIL: reap cost diverged between open/closed mode (%s vs %s) — reap pricing must not read dissipative_enabled()" % [
				str(closed_cost), str(open_cost)])
			failures += 1

	# Test 3: with no farm/economy attached (get_tuning_value has nothing to
	# read — the honest "config incomplete" case BalanceService.gd:224 warns
	# about by design, no code-default), get_reap_cost_sequence() degrades to
	# [] and get_reap_cost() falls back to the documented single-charge
	# constant {🍼: 1} — still never {}. This is the exact shape a
	# partially-booted export would hit, which is what d1-06 worried about.
	BalanceConfig.merge_physics_override({"dissipative_dynamics": false})
	var seq: Array = BalanceService.get_reap_cost_sequence(null)
	if not seq.is_empty():
		print("FAIL: expected get_reap_cost_sequence(null) to degrade to [] with no economy attached, got %s" % str(seq))
		failures += 1
	var fallback_cost: Dictionary = BalanceService.get_reap_cost(null, 3)
	if fallback_cost != {EconomyConstants.MIDWIFE_EMOJI: 1}:
		print("FAIL: no-economy fallback reap cost expected {%s: 1}, got %s" % [EconomyConstants.MIDWIFE_EMOJI, str(fallback_cost)])
		failures += 1

	# Test 4: empty-cost contract sanity (documents WHY {} would be dangerous,
	# so nobody re-adds a `return {}` early-exit without seeing this fail):
	# EconomyConstants treats an empty cost dict as "free" system-wide — no
	# error, no distinct UI state, spends nothing. Confirms get_reap_cost()
	# must not produce {}, since downstream code cannot tell "free by design"
	# apart from "config lookup silently failed."
	var preflight_empty: Dictionary = EconomyConstants.preflight_cost({}, null)
	if not bool(preflight_empty.get("ok", false)):
		print("FAIL: expected EconomyConstants.preflight_cost({}, null) to auto-pass (documents the free-action contract)")
		failures += 1
	if not bool(EconomyConstants.commit_cost({}, null)):
		print("FAIL: expected EconomyConstants.commit_cost({}, null) to auto-succeed (documents the free-action contract)")
		failures += 1

	BalanceConfig.clear_physics_override()

	print()
	if failures == 0:
		print("✅ REAP COST / CLOSED SYSTEM PASS — all 4 checks green")
		quit(0)
	else:
		print("❌ REAP COST / CLOSED SYSTEM FAIL — %d check(s) failed" % failures)
		quit(1)
