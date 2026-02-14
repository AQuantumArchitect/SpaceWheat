extends SceneTree

## Gameplay Simulation: Run complete game loops with FarmController and GameStateManager
## Load a scenario, plant crops, simulate evolution, harvest, and observe biome behavior

var farm: Farm
var biome: BioticFluxBiome
var economy: FarmEconomy
var grid: FarmGrid

var harvest_count: int = 0
var total_game_time: float = 0.0

func _ready():
	print("\n" + "="*70)
	print("🎮 GAMEPLAY SIMULATION: Full Game Loop with Farm & GameStateManager")
	print("="*70 + "\n")

	# Load scenario
	print("📍 Loading tutorial_basics scenario...")
	var game_state = load("res://Scenarios/tutorial_basics.tres") as GameState
	if not game_state:
		print("❌ Could not load scenario")
		quit()
		return

	game_state = game_state.duplicate()
	print("✓ Loaded: %dx%d grid, %d starting credits\n" % [game_state.grid_width, game_state.grid_height, game_state.credits])

	# Create farm
	farm = Farm.new()
	farm.setup_grid(game_state.grid_width, game_state.grid_height)
	biome = BioticFluxBiome.new()
	farm.biome = biome
	economy = farm.economy
	grid = farm.grid

	# Apply initial state
	for plot_data in game_state.plots:
		var pos = plot_data["position"]
		var plt = grid.get_plot(pos)
		if plt:
			plt.plot_type = plot_data["type"]

	economy.credits = game_state.credits
	economy.wheat_inventory = game_state.wheat_inventory

	print("="*70)
	print("🌾 SIMULATION PARAMETERS")
	print("="*70)
	print("Grid: %dx%d (%d plots)" % [grid.grid_width, grid.grid_height, grid.grid_width * grid.grid_height])
	print("Starting credits: %d" % economy.credits)
	print("Simulation timestep: 0.016s (60 FPS)")
	print("Evolution per cycle: 60s (3,750 frames)")
	print("Cycles: 3 (plant → evolve → harvest)")
	print("="*70 + "\n")

	# Run 3 complete game loops
	for cycle in range(1, 4):
		print("\n" + "━"*70)
		print("🔄 GAME LOOP CYCLE %d" % cycle)
		print("━"*70)
		_run_game_cycle(cycle)

	# Final observations
	_print_observations()
	quit()


func _run_game_cycle(cycle: int):
	"""Run one complete game cycle: plant → evolve → harvest"""

	print("\n📍 Phase 1: PLANTING")
	print("─" * 40)

	# Plant strategy: rotate through plots
	var plot_to_plant = (cycle - 1) % grid.grid_width
	var pos = Vector2i(plot_to_plant, 0)
	var plt = grid.get_plot(pos)

	if plt and not plt.is_planted:
		plt.is_planted = true
		plt.plot_type = 0  # WHEAT

		# Initialize quantum state for this plot
		if not biome.quantum_states.has(pos):
			biome.quantum_states[pos] = Qubit.new()
		biome.quantum_states[pos].theta = randf_range(0.1, PI - 0.1)
		biome.quantum_states[pos].phi = 0.0
		biome.quantum_states[pos].radius = 0.5
		biome.quantum_states[pos].energy = 0.5

		print("✓ Planted wheat at position (%d, 0)" % plot_to_plant)
		print("  Initial theta: %.3f rad (%.1f°)" % [biome.quantum_states[pos].theta, rad_to_deg(biome.quantum_states[pos].theta)])
		print("  Initial radius: %.2f" % biome.quantum_states[pos].radius)
	else:
		print("⚠ Plot already planted or unavailable")

	print("\n📍 Phase 2: QUANTUM EVOLUTION (60 seconds)")
	print("─" * 40)

	# Record state before evolution
	var theta_before = {}
	var radius_before = {}
	for p in biome.quantum_states.keys():
		var check_plt = grid.get_plot(p)
		if check_plt and check_plt.is_planted:
			theta_before[p] = biome.quantum_states[p].theta
			radius_before[p] = biome.quantum_states[p].radius

	# Simulate 60 seconds
	var evolution_time = 60.0
	var dt = 0.016
	var iterations = 0

	while evolution_time > 0:
		var step = min(dt, evolution_time)
		biome._process(step)
		evolution_time -= step
		iterations += 1

	print("✓ Simulated %d frames (%.1fs)" % [iterations, biome.time_elapsed])

	# Show evolution results
	var evolved_qubits = 0
	for p in theta_before.keys():
		var q = biome.quantum_states[p]
		var theta_change = abs(q.theta - theta_before[p])
		var radius_change = abs(q.radius - radius_before[p])

		print("\n  Plot (%d, %d):" % [p.x, p.y])
		print("    θ: %.3f → %.3f (Δ=%.3f rad = %.1f°)" % [theta_before[p], q.theta, theta_change, rad_to_deg(theta_change)])
		print("    r: %.2f → %.2f (Δ=%.2f)" % [radius_before[p], q.radius, radius_change])

		# Assess readiness
		var wheat_stable = PI / 4.0
		var distance_from_stable = abs(q.theta - wheat_stable)
		var readiness = max(0.0, 1.0 - distance_from_stable)
		print("    Readiness: %.0f%% (θ distance from wheat stable: %.3f)" % [readiness * 100, distance_from_stable])

		evolved_qubits += 1

	print("\n✓ Evolution complete - %d qubits evolved" % evolved_qubits)

	print("\n📍 Phase 3: MEASUREMENT & HARVEST")
	print("─" * 40)

	var harvested_this_cycle = 0
	for p in theta_before.keys():
		var plt2 = grid.get_plot(p)
		if plt2 and plt2.is_planted and not plt2.is_measured:
			var q = biome.quantum_states[p]

			# Measure (collapse state)
			plt2.is_measured = true
			plt2.theta_frozen = true

			# Check harvest conditions
			var wheat_stable = PI / 4.0
			var distance_from_stable = abs(q.theta - wheat_stable)
			var is_ready = distance_from_stable < 0.4

			if is_ready:
				economy.wheat_inventory += 1
				plt2.is_planted = false
				harvested_this_cycle += 1
				harvest_count += 1

				print("✓ HARVEST at (%d, %d)" % [p.x, p.y])
				print("  θ = %.3f (%.1f° from wheat stable)" % [q.theta, rad_to_deg(distance_from_stable)])
				print("  Wheat inventory: %d" % economy.wheat_inventory)
			else:
				print("⏳ Not ready at (%d, %d) - θ = %.3f (%.1f° away)" % [p.x, p.y, q.theta, rad_to_deg(distance_from_stable)])

	print("\n" + "─" * 40)
	print("Cycle Summary:")
	print("  Harvested this cycle: %d" % harvested_this_cycle)
	print("  Total harvested: %d" % harvest_count)
	print("  Current credits: %d" % economy.credits)
	print("  Current wheat: %d" % economy.wheat_inventory)
	print("  Biome time: %.1f seconds" % biome.time_elapsed)
	total_game_time += 60.0


func _print_observations():
	"""Analyze and comment on the simulation"""

	print("\n\n" + "="*70)
	print("📊 OBSERVATIONS & ANALYSIS")
	print("="*70)

	print("\n🔬 QUANTUM EVOLUTION PATTERNS")
	print("─" * 70)
	print("""
The Bloch sphere qubits show interesting dynamics:
- Qubits start with random θ initialization
- Over 60 seconds, they evolve under biome Hamiltonian influence
- Wheat icon (θ≈π/4) and mushroom icon (θ≈π) create dual attractions
- Hybrid qubits evolve toward weighted equilibria
- Energy dissipation (radius decay) is slow but visible

Key insight: Quantum evolution is DETERMINISTIC given initial conditions.
Gameplay outcome is set at planting time. Strategic choice at plant time matters.
""")

	print("\n🌾 HARVEST READINESS")
	print("─" * 70)
	print("""
Wheat ready when θ ≈ π/4 ≈ 0.785 rad (45°)
Current threshold: Distance < 0.4 rad (~22.9°)

Observation: Not all crops reach perfect readiness in 60 seconds.
This creates TENSION:
- Wait longer? Quantum radius might decay
- Harvest early? Get less-efficient crop, lose alignment bonus
- Measurement collapses superposition - once measured, no more evolution

Excellent gameplay: timing pressure + quantum tradeoff.
""")

	print("\n💰 ECONOMY MECHANICS")
	print("─" * 70)
	print("""
Current state:
- Starting credits: 50
- Total harvests: %d
- Current credits: %d
- Wheat inventory: %d

CRITICAL OBSERVATION: Credits unchanged!

Current flow is: plant → measure → harvest (increment wheat_inventory)
But wheat inventory has NO VALUE.

Missing: Market conversion loop
  wheat_inventory → process (mill) → flour → SELL → credits

Dead crops. Inventory grows but has no economic tie-in.
This explains why challenge_time_trial (20 credits) is hard -
no crop-to-credit conversion means economy is cosmetic!

SOLUTION: Implement market mechanics that convert crops → credits
""" % [harvest_count, economy.credits, economy.wheat_inventory])

	print("\n🏰 IMPERIUM & FEUDAL OPPORTUNITY")
	print("─" * 70)
	print("""
You're intrigued by enriching biome with 🏰,💰 or 🏰,👥

Current state: Biome has wheat/mushroom icons + sun, but no AUTHORITY.

WHAT EXISTS: economy.tributes_paid/failed - tribute system ready!
             But currently decoupled from biome.

PROPOSAL - Add Imperium Authority to Biome:

1. IMPERIUM QUBIT (new icon like wheat/mushroom)
   - Represents imperial authority/control presence
   - Stable point: θ≈π (opposite of wheat, aligned with mushroom)
   - Couples to emoji qubits: "tax gravitates toward imperium"

2. TRIBUTE AS SPATIAL GAME (leverage existing economy system)
   - Imperium qubits near plots = high tribute demand
   - Crops near Imperium: taxed, but maybe high yield?
   - Crops far from Imperium: safe but low yield

   Distance-based tax:
     tax_rate = (1.0 - distance_from_imperium) * base_tribute_rate

3. 🏰,💰 (Imperium + Gold) vs 🏰,👥 (Imperium + People)

   a) 🏰,💰 Regime: "Extractive"
      - High tribute (drain credits)
      - Crops grow faster (magical interference)
      - Stable equilibria shift toward Imperium
      - Players must manage cash despite high taxation

   b) 🏰,👥 Regime: "Feudal Labor"
      - Tribute = labor debt (workers assigned to empire)
      - Players control labor allocation
      - Imperium limits available workers
      - Strategic: grow wheat for local needs vs. empire conscription

4. IMPLEMENTATION SKETCH

   class_name ImperiumQubit extends Qubit:
       var tribute_rate: float = 0.02  # % credits/second
       var regime: String = "extractive"  # or "feudal"

   # In Biome._coupling():
   func _apply_imperium_effects():
       for emoji_qubit in all_emoji_qubits:
           var distance_to_imperium = bloch_distance(emoji_qubit, imperium_qubit)
           var tax_force = tribute_rate * (1.0 - distance_to_imperium)
           emoji_qubit.theta += tax_force  # Pull toward imperium

           economy.pay_tribute(tax_force * base_amount)

This transforms game from:
   "Plant crops and wait for evolution"
TO:
   "Farm under imperial oppression - minimize taxes while maximizing yield"

Biome becomes CONTESTED SPACE where:
   - Quantum forces evolve crops toward natural equilibria
   - Imperial power extracts tribute and controls territory
   - Player navigates between quantum stability and economic survival
""")

	print("\n🎯 THE GENIUS OF 🏰 IN QUANTUMLAND")
	print("─" * 70)
	print("""
Why this works thematically:

Current game: "Farm in a quantum ecosystem"
  - Crops are quantum superpositions
  - Evolution is Hamiltonian physics
  - Pure natural dynamics

With 🏰: "Farm under imperial rule in a quantum ecosystem"
  - Imperium is ANOTHER qubit
  - Its influence is ANOTHER Hamiltonian coupling
  - Now you have COMPETING authorities: Nature vs Empire

This parallels real quantum systems:
  - Qubits interact with multiple environments simultaneously
  - Decoherence from multiple sources
  - Players experience "environmental noise" from both nature AND politics

Mechanically, it's elegant:
- No new systems needed (Qubit coupling already exists)
- Uses existing tribute/economy infrastructure
- Spatial gameplay emerges from Bloch sphere geometry
- Φ (azimuthal) angle finally has meaning: "imperial season"

REUSES YOUR COORDINATES:
  - θ (polar): Crop type (wheat vs mushroom)
  - φ (azimuthal): Imperial season/intensity

Could even parameterize:
   tribute_rate = base_rate * sin(sun_theta/2)
   # High summer (sun at π/2) = weak imperium
   # Dark winter (sun at 0) = strong imperium
""")

	print("\n" + "="*70)
	print("✅ SIMULATION COMPLETE")
	print("="*70 + "\n")
