extends "res://tests/smoke_test_base.gd"

## Packet budget: first packet is 1, and a 1-biome measurement cannot license
## a 6-biome stall. Run: godot --headless --path . --script tests/batcher_budget_smoke.gd

func _init() -> void:
	print("\n=== Batcher packet budget ===")
	var batcher := BiomeEvolutionBatcher.new()
	_check(batcher.use_phase_lnn == false,
		"phase-shadow LNN stays off — it modulates ρ and is not quantum mechanics")
	_check(batcher._affordable_batch_size(21) == 1,
		"first packet (no timing) is 1, not the uncapped Fibonacci 21")
	_check(batcher._affordable_batch_size(21, 6) == 1,
		"first 6-biome packet is also 1")

	# After a 1-biome 30ms / 5-step packet: per-active-biome-step = 6.0
	batcher._avg_ms_per_step = 6.0
	_check(batcher._affordable_batch_size(21, 1) == 4,
		"1-biome after 6ms/step: floor(25/6)=4")
	var six: int = batcher._affordable_batch_size(21, 6)
	_check(six == 1,
		"6-biome after the same 1-biome measurement: floor(25/(6*6))=1 (got %d)" % six)
	_finish("batcher_budget_smoke")
