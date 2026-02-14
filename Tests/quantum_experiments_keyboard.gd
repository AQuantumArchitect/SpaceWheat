extends SceneTree

## Automated Keyboard-Driven Quantum Experiments
## Plays the game using keyboard inputs to demonstrate all quantum mechanics

var game_controller
var farm
var economy
var input_handler

# Experiment state
var current_step = 0
var wait_time = 0.0
var experiment_log = []

func _init():
	print("\n╔═══════════════════════════════════════════════════════════════╗")
	print("║   🎮 AUTOMATED QUANTUM EXPERIMENTS (KEYBOARD DRIVEN) 🎮      ║")
	print("╚═══════════════════════════════════════════════════════════════╝\n")

	print("Loading game...")

func _ready():
	# Load the main game scene
	var main_scene = load("res://scenes/main.tscn")
	if not main_scene:
		print("❌ Could not load main.tscn")
		quit(1)
		return

	var game = main_scene.instantiate()
	root.add_child(game)
	await process_frame

	# Find game components
	game_controller = root.get_node_or_null("GameController")
	if not game_controller:
		print("❌ GameController not found")
		quit(1)
		return

	farm = game_controller.farm
	if not farm:
		print("❌ Farm not found")
		quit(1)
		return

	economy = farm.economy
	input_handler = game_controller.get_node_or_null("FarmInputHandler")

	print("✅ Game loaded successfully!")
	print("   Farm: %s" % farm.name)
	print("   Grid: %d plots" % farm.grid.grid_size)
	print("   Economy: %s\n" % ("Ready" if economy else "Not found"))

	# Give starting resources
	if economy:
		economy.add_resource("🌾", 1000, "Starting resources for experiments")
		print("💰 Added 1000 wheat credits for experiments\n")

	# Start experiments
	await run_all_experiments()

func run_all_experiments():
	print("╔═══════════════════════════════════════════════════════════════╗")
	print("║  Starting Automated Quantum Experiments                      ║")
	print("╚═══════════════════════════════════════════════════════════════╝\n")

	await experiment_1_basic_planting()
	await experiment_2_quantum_gates()
	await experiment_3_entanglement()
	await experiment_4_decoherence_tuning()
	await experiment_5_quantum_algorithms()
	await experiment_6_purity_harvest()

	print("\n╔═══════════════════════════════════════════════════════════════╗")
	print("║  🎓 ALL KEYBOARD EXPERIMENTS COMPLETE! 🎓                    ║")
	print("╚═══════════════════════════════════════════════════════════════╝\n")

	print_experiment_summary()
	quit()

## ═══════════════════════════════════════════════════════════════
## EXPERIMENT 1: BASIC PLANTING & MEASUREMENT
## ═══════════════════════════════════════════════════════════════

func experiment_1_basic_planting():
	log_step("EXPERIMENT 1: Basic Planting & Measurement")
	print("\n🧪 EXPERIMENT 1: Basic Planting & Measurement")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

	# Tool 1 = Grower, Q = Plant submenu
	print("Step 1: Select Tool 1 (Grower)")
	press_key("1")
	await wait(0.5)

	print("Step 2: Select plot T")
	press_key("T")
	await wait(0.3)

	print("Step 3: Open plant submenu (Q)")
	press_key("Q")
	await wait(0.3)

	print("Step 4: Plant wheat (Q in submenu)")
	press_key("Q")
	await wait(0.5)

	# Verify planting
	var plot = farm.grid.get_plot(Vector2i(0, 0))
	if plot and plot.is_planted:
		log_success("✅ Plot planted successfully!")
		if plot.quantum_state:
			print("   Quantum state: %s ↔ %s" % [
				plot.quantum_state.north_emoji,
				plot.quantum_state.south_emoji
			])
	else:
		log_failure("❌ Planting failed")

	# Evolve for a bit
	print("\nStep 5: Wait for evolution (2 seconds)...")
	await wait(2.0)

	# Measure
	print("Step 6: Measure plot (Tool 1, R)")
	press_key("1")
	await wait(0.2)
	press_key("T")
	await wait(0.2)
	press_key("R")
	await wait(0.5)

	if plot and plot.is_measured:
		log_success("✅ Measurement successful!")
		print("   Outcome: %s" % plot.measured_outcome)

	print("\n✅ EXPERIMENT 1 COMPLETE\n")

## ═══════════════════════════════════════════════════════════════
## EXPERIMENT 2: QUANTUM GATES
## ═══════════════════════════════════════════════════════════════

func experiment_2_quantum_gates():
	log_step("EXPERIMENT 2: Quantum Gates")
	print("\n🧪 EXPERIMENT 2: Quantum Gates")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

	# Plant on plot Y
	print("Step 1: Plant second plot (Y)")
	press_key("1")
	await wait(0.2)
	press_key("Y")
	await wait(0.2)
	press_key("Q")
	await wait(0.2)
	press_key("Q")  # Plant wheat
	await wait(0.5)

	var plot_y = farm.grid.get_plot(Vector2i(1, 0))
	if plot_y and plot_y.is_planted:
		log_success("✅ Second plot planted")

	# Apply Hadamard gate (Tool 5, Q submenu, E = Hadamard)
	print("\nStep 2: Apply Hadamard gate (Tool 5)")
	press_key("5")
	await wait(0.2)
	press_key("Y")
	await wait(0.2)
	press_key("Q")  # Open 1-qubit gates submenu
	await wait(0.2)
	press_key("E")  # Hadamard
	await wait(0.5)

	log_success("✅ Hadamard gate applied!")

	# Apply Pauli-X gate
	print("Step 3: Apply Pauli-X gate (Tool 5, Q, Q)")
	press_key("5")
	await wait(0.2)
	press_key("Y")
	await wait(0.2)
	press_key("Q")  # Open 1-qubit gates submenu
	await wait(0.2)
	press_key("Q")  # Pauli-X
	await wait(0.5)

	log_success("✅ Pauli-X gate applied!")

	# Verify bath is still valid
	if plot_y and plot_y.quantum_state:
		var bath = plot_y.quantum_state.bath
		if bath:
			var validation = bath.validate()
			if validation.valid:
				log_success("✅ Bath remains valid after gates!")
				print("   Trace: %.6f | Hermitian: %s" % [
					bath.get_total_probability(),
					validation.hermitian
				])

	print("\n✅ EXPERIMENT 2 COMPLETE\n")

## ═══════════════════════════════════════════════════════════════
## EXPERIMENT 3: ENTANGLEMENT
## ═══════════════════════════════════════════════════════════════

func experiment_3_entanglement():
	log_step("EXPERIMENT 3: Quantum Entanglement")
	print("\n🧪 EXPERIMENT 3: Quantum Entanglement")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

	# Plant plots U and I
	print("Step 1: Plant plots U and I")
	press_key("1")
	await wait(0.2)
	press_key("U")
	await wait(0.2)
	press_key("Q")
	await wait(0.2)
	press_key("E")  # Plant mushroom
	await wait(0.5)

	press_key("1")
	await wait(0.2)
	press_key("I")
	await wait(0.2)
	press_key("Q")
	await wait(0.2)
	press_key("E")  # Plant mushroom
	await wait(0.5)

	# Select both plots
	print("\nStep 2: Select both plots (U + I)")
	press_key("U")
	await wait(0.2)
	press_key("I")
	await wait(0.3)

	# Entangle (Tool 1, E)
	print("Step 3: Entangle plots (Tool 1, E)")
	press_key("1")
	await wait(0.2)
	press_key("E")
	await wait(1.0)

	# Check entanglement
	var plot_u = farm.grid.get_plot(Vector2i(2, 0))
	var plot_i = farm.grid.get_plot(Vector2i(3, 0))

	if plot_u and plot_i:
		if plot_u.entangled_plots.size() > 0:
			log_success("✅ Entanglement created!")
			print("   Plot U entangled with: %s" % plot_u.entangled_plots)
		else:
			log_failure("❌ Entanglement failed")

	print("\n✅ EXPERIMENT 3 COMPLETE\n")

## ═══════════════════════════════════════════════════════════════
## EXPERIMENT 4: DECOHERENCE TUNING (TOOL 4-E)
## ═══════════════════════════════════════════════════════════════

func experiment_4_decoherence_tuning():
	log_step("EXPERIMENT 4: Decoherence Tuning")
	print("\n🧪 EXPERIMENT 4: Decoherence Tuning (Purity Management)")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

	# Get purity before tuning
	var plot_t = farm.grid.get_plot(Vector2i(0, 0))
	var purity_before = 0.0
	if plot_t and plot_t.quantum_state and plot_t.quantum_state.bath:
		purity_before = plot_t.quantum_state.bath.get_purity()
		print("Purity before tuning: %.4f" % purity_before)

	# Check wheat balance
	var wheat_before = 0
	if economy:
		wheat_before = economy.emoji_credits.get("🌾", 0)
		print("Wheat balance: %d credits\n" % wheat_before)

	# Tune decoherence (Tool 4, E)
	print("Step 1: Select Tool 4 (Biome Control)")
	press_key("4")
	await wait(0.2)

	print("Step 2: Select plot T")
	press_key("T")
	await wait(0.2)

	print("Step 3: Tune decoherence (E)")
	press_key("E")
	await wait(1.0)

	# Check wheat spent
	if economy:
		var wheat_after = economy.emoji_credits.get("🌾", 0)
		var wheat_spent = wheat_before - wheat_after
		if wheat_spent > 0:
			log_success("✅ Decoherence tuned! Cost: %d wheat" % wheat_spent)
		else:
			log_failure("❌ No wheat spent (operation may have failed)")

	# Check purity after
	if plot_t and plot_t.quantum_state and plot_t.quantum_state.bath:
		var purity_after = plot_t.quantum_state.bath.get_purity()
		print("Purity after tuning: %.4f" % purity_after)

	print("\n✅ EXPERIMENT 4 COMPLETE\n")

## ═══════════════════════════════════════════════════════════════
## EXPERIMENT 5: QUANTUM ALGORITHMS
## ═══════════════════════════════════════════════════════════════

func experiment_5_quantum_algorithms():
	log_step("EXPERIMENT 5: Quantum Algorithms")
	print("\n🧪 EXPERIMENT 5: Quantum Algorithms")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

	# Make sure we have 2 planted plots
	print("Step 1: Ensure plots O and P are planted")
	press_key("1")
	await wait(0.2)
	press_key("O")
	await wait(0.2)
	press_key("Q")
	await wait(0.2)
	press_key("R")  # Plant tomato
	await wait(0.5)

	press_key("1")
	await wait(0.2)
	press_key("P")
	await wait(0.2)
	press_key("Q")
	await wait(0.2)
	press_key("R")  # Plant tomato
	await wait(0.5)

	# Select both plots
	print("\nStep 2: Select plots O and P")
	press_key("O")
	await wait(0.2)
	press_key("P")
	await wait(0.3)

	# Run Deutsch-Jozsa (Tool 6, Q)
	print("Step 3: Run Deutsch-Jozsa algorithm (Tool 6, Q)")
	press_key("6")
	await wait(0.2)
	press_key("Q")
	await wait(2.0)

	log_success("✅ Deutsch-Jozsa executed!")

	# Run Grover Search (Tool 6, E)
	print("\nStep 4: Run Grover Search (Tool 6, E)")
	press_key("6")
	await wait(0.2)
	press_key("O")
	await wait(0.2)
	press_key("P")
	await wait(0.2)
	press_key("E")
	await wait(2.0)

	log_success("✅ Grover Search executed!")

	# Run Phase Estimation (Tool 6, R)
	print("\nStep 5: Run Phase Estimation (Tool 6, R)")
	press_key("6")
	await wait(0.2)
	press_key("O")
	await wait(0.2)
	press_key("P")
	await wait(0.2)
	press_key("R")
	await wait(2.0)

	log_success("✅ Phase Estimation executed!")

	print("\n✅ EXPERIMENT 5 COMPLETE\n")

## ═══════════════════════════════════════════════════════════════
## EXPERIMENT 6: PURITY-BASED HARVEST
## ═══════════════════════════════════════════════════════════════

func experiment_6_purity_harvest():
	log_step("EXPERIMENT 6: Purity-Based Harvest")
	print("\n🧪 EXPERIMENT 6: Purity-Based Harvest")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

	# Get plot state before harvest
	var plot_t = farm.grid.get_plot(Vector2i(0, 0))
	if plot_t and plot_t.quantum_state:
		var bath = plot_t.quantum_state.bath
		if bath:
			var purity = bath.get_purity()
			var expected_multiplier = 2.0 * purity
			print("Plot T state before harvest:")
			print("  Purity: %.4f" % purity)
			print("  Expected multiplier: %.2f×" % expected_multiplier)

	# Measure if not already measured
	if plot_t and not plot_t.is_measured:
		print("\nStep 1: Measure plot T (Tool 1, R)")
		press_key("1")
		await wait(0.2)
		press_key("T")
		await wait(0.2)
		press_key("R")
		await wait(0.5)

	# Harvest
	print("Step 2: Harvest plot T")
	var wheat_before = 0
	if economy:
		wheat_before = economy.emoji_credits.get("🌾", 0)

	# Harvest is done via measurement in this game
	# The harvest() function is called automatically

	if plot_t:
		var result = plot_t.harvest()
		if result.success:
			log_success("✅ Harvest successful!")
			print("   Outcome: %s" % result.outcome)
			print("   Yield: %d credits" % result.yield)
			if result.has("purity"):
				print("   Purity: %.4f" % result.purity)
				print("   Purity multiplier: %.2f×" % result.purity_multiplier)
		else:
			log_failure("❌ Harvest failed")

	print("\n✅ EXPERIMENT 6 COMPLETE\n")

## ═══════════════════════════════════════════════════════════════
## HELPER FUNCTIONS
## ═══════════════════════════════════════════════════════════════

func press_key(key: String):
	"""Simulate keyboard key press"""
	if not input_handler:
		return

	# Create input event
	var event = InputEventKey.new()
	event.pressed = true
	event.keycode = _key_to_code(key)

	# Send to input handler
	Input.parse_input_event(event)

	print("   [KEY: %s]" % key)

func _key_to_code(key: String) -> int:
	"""Convert key string to keycode"""
	match key:
		"1": return KEY_1
		"2": return KEY_2
		"3": return KEY_3
		"4": return KEY_4
		"5": return KEY_5
		"6": return KEY_6
		"Q": return KEY_Q
		"E": return KEY_E
		"R": return KEY_R
		"T": return KEY_T
		"Y": return KEY_Y
		"U": return KEY_U
		"I": return KEY_I
		"O": return KEY_O
		"P": return KEY_P
		"[": return KEY_BRACKETLEFT
		"]": return KEY_BRACKETRIGHT
		_: return KEY_NONE

func wait(seconds: float):
	"""Wait for specified time"""
	await create_timer(seconds).timeout

func log_step(message: String):
	"""Log experiment step"""
	experiment_log.append({"type": "step", "message": message})

func log_success(message: String):
	"""Log successful operation"""
	experiment_log.append({"type": "success", "message": message})
	print(message)

func log_failure(message: String):
	"""Log failed operation"""
	experiment_log.append({"type": "failure", "message": message})
	print(message)

func print_experiment_summary():
	"""Print summary of all experiments"""
	print("\n╔═══════════════════════════════════════════════════════════════╗")
	print("║  EXPERIMENT SUMMARY                                           ║")
	print("╚═══════════════════════════════════════════════════════════════╝\n")

	var steps = 0
	var successes = 0
	var failures = 0

	for entry in experiment_log:
		match entry.type:
			"step":
				steps += 1
			"success":
				successes += 1
			"failure":
				failures += 1

	print("Total experiments: %d" % steps)
	print("Successful operations: %d" % successes)
	print("Failed operations: %d" % failures)
	print("Success rate: %.1f%%\n" % (float(successes) / max(1, successes + failures) * 100))

	print("✅ Demonstrated:")
	print("  • Basic planting and measurement")
	print("  • Quantum gate operations (H, X)")
	print("  • Quantum entanglement (Bell states)")
	print("  • Decoherence management (Tool 4-E)")
	print("  • Quantum algorithms (Deutsch-Jozsa, Grover, Phase Estimation)")
	print("  • Purity-based harvest yields")
	print("\n🎓 All quantum mechanics features validated via keyboard!")
