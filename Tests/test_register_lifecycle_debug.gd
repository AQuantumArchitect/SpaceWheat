#!/usr/bin/env -S godot --headless -s
extends SceneTree

## DEBUG: Register Lifecycle Investigation
## Traces what happens to registers through EXPLORE→MEASURE→POP

const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")

var farm = null
var grid = null
var economy = null
var plot_pool = null
var biome = null

var frame_count = 0
var scene_loaded = false
var tests_done = false

func _init():
	print("\n" + "═".repeat(80))
	print("🔍 REGISTER LIFECYCLE DEBUG")
	print("═".repeat(80))

func _process(_delta):
	frame_count += 1

	if frame_count == 5 and not scene_loaded:
		print("\n⏳ Frame 5: Loading scene...")
		var scene = load("res://scenes/FarmView.tscn")
		if scene:
			var instance = scene.instantiate()
			root.add_child(instance)
			scene_loaded = true
			var boot_manager = root.get_node_or_null("/root/BootManager")
			if boot_manager:
				boot_manager.game_ready.connect(_on_game_ready)

func _on_game_ready():
	if tests_done:
		return
	tests_done = true

	print("\n✅ Game ready! Starting register lifecycle debug...\n")

	var fv = root.get_node_or_null("FarmView")
	if not fv or not fv.farm:
		print("❌ Farm not found")
		quit(1)
		return

	farm = fv.farm
	grid = farm.grid
	economy = farm.economy
	plot_pool = farm.terminal_pool
	biome = grid.biomes.values()[0]

	economy.add_resource("💰", 10000, "test_bootstrap")

	print("   Biome: %s" % biome.get_biome_type())
	print("   Total registers (qubits): %d" % biome.quantum_computer.register_map.num_qubits)
	print()

	_test_register_lifecycle()

	quit()

# ═══════════════════════════════════════════════════════════════════════════

func _test_register_lifecycle():
	print("─".repeat(80))
	print("TRACING: EXPLORE → MEASURE → POP cycle")
	print("─".repeat(80))

	var max_cycles = 5
	var cycle = 0

	for cycle_num in range(max_cycles):
		cycle = cycle_num + 1
		print("\n╔ CYCLE %d" % cycle)
		print("║")

		# 1. Check pool state before EXPLORE
		print("║ [BEFORE EXPLORE]")
		_print_register_state("   ", biome)
		_print_terminal_pool_state("   ", plot_pool)

		# 2. EXPLORE
		print("║")
		print("║ [EXPLORE]")
		var explore_result = ProbeActions.action_explore(plot_pool, biome)

		if not explore_result.get("success"):
			print("║ ❌ EXPLORE FAILED: %s" % explore_result.get("error"))
			print("║")
			print("╚ STOPPING - No more registers available!")
			break

		var terminal = explore_result["terminal"]
		var register_id = explore_result["register_id"]
		print("║ ✅ Terminal %s bound to register %d" % [terminal.terminal_id, register_id])

		# 3. Check state after EXPLORE
		print("║")
		print("║ [AFTER EXPLORE]")
		_print_register_state("   ", biome)

		# 4. MEASURE
		print("║")
		print("║ [MEASURE]")
		var measure_result = ProbeActions.action_measure(terminal, biome)

		if not measure_result.get("success"):
			print("║ ❌ MEASURE FAILED: %s" % measure_result.get("error"))
			continue

		var outcome = measure_result.get("outcome")
		var recorded_prob = measure_result.get("recorded_probability", 0)
		print("║ ✅ Measured outcome: %s (prob=%.4f)" % [outcome, recorded_prob])

		# 5. Check state after MEASURE
		print("║")
		print("║ [AFTER MEASURE]")
		_print_register_state("   ", biome)

		# 6. POP
		print("║")
		print("║ [POP]")
		var pop_result = ProbeActions.action_pop(terminal, plot_pool, economy)

		if not pop_result.get("success"):
			print("║ ❌ POP FAILED: %s" % pop_result.get("error"))
			continue

		var credits = pop_result.get("credits", 0)
		print("║ ✅ Terminal popped, gained %d 💰" % int(credits))

		# 7. Check state after POP
		print("║")
		print("║ [AFTER POP]")
		_print_register_state("   ", biome)
		_print_terminal_pool_state("   ", plot_pool)

		print("║")
		print("╚ Cycle %d complete\n" % cycle)

	print("\n" + "─".repeat(80))
	print("SUMMARY: Completed %d/%d cycles" % [cycle, max_cycles])
	print("═".repeat(80) + "\n")

# ═══════════════════════════════════════════════════════════════════════════

func _print_register_state(prefix: String, biome_inst):
	"""Print which registers are bound/unbound and to which terminals"""
	var unbound = biome_inst.get_unbound_registers()
	var bound_count = biome_inst.get_bound_register_count()
	var total = biome_inst.get_total_register_count()

	print("%s📊 Registers: %d unbound, %d bound, %d total" % [prefix, unbound.size(), bound_count, total])
	print("%s   Unbound IDs: %s" % [prefix, unbound])

	# Show which terminals are bound
	if biome_inst._bound_registers:
		print("%s   Bound mapping: %s" % [prefix, str(biome_inst._bound_registers)])
	else:
		print("%s   Bound mapping: empty")

func _print_terminal_pool_state(prefix: String, pool_inst):
	"""Print which terminals are bound/unbound"""
	var unbound = pool_inst.get_unbound_terminals()
	var unbound_count = unbound.size()
	var total = pool_inst._terminals.size()
	var bound_count = total - unbound_count

	print("%s🎫 Terminals: %d unbound, %d bound, %d total" % [prefix, unbound_count, bound_count, total])

	# Show terminal states
	for terminal in pool_inst._terminals:
		var state = "UNBOUND"
		if terminal.is_bound:
			state = "BOUND(reg=%d)" % terminal.bound_register_id
		if terminal.is_measured:
			state += " MEASURED"
		print("%s   %s: %s" % [prefix, terminal.terminal_id, state])
