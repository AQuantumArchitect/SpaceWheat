# Entanglement Gameplay Mechanics

## Overview
When two plots are entangled, their harvest outcomes become **correlated**. This transforms farming from independent choices into a strategic resource management puzzle.

## Bell States as Gameplay Modes

### |Φ+⟩ - "Same" Correlation (Synchronized Harvest)
**Physics**: `(|00⟩ + |11⟩)/√2` - Perfectly correlated outcomes
**Gameplay**: Both plots collapse to the **same emoji**
- Both get 🌾 (wheat) **OR** both get 👥 (labor)
- Probability of same: ~100%
- **Strategic Use**: Synchronized resource production
  - Two wheat plots → guaranteed both 🌾 or both 👥
  - Useful for: Coordinating harvests, predictable yields
- **Risk**: If you need one resource, you might get the other instead!

### |Ψ+⟩ - "Opposite" Correlation (Complementary Harvest)
**Physics**: `(|01⟩ + |10⟩)/√2` - Anti-correlated outcomes
**Gameplay**: Plots collapse to **opposite emojis**
- One gets 🌾, the other gets 👥
- Probability of opposite: ~100%
- **Strategic Use**: Diversified resource production
  - One plot guaranteed 🌾, one guaranteed 👥
  - Useful for: Balanced resource economy, reducing risk
- **Benefit**: Hedging - you always get both resource types
- **Trade-off**: Can't get lucky with both yields from same plot type

## Gameplay Loop: Entangled Farming

### 1. Establish Entanglement
```
Player clicks "Entangle" on two adjacent plots
→ Choose Bell state: Same (Φ+) or Opposite (Ψ+)?
→ Cost: 1 Conspiracy Node energy (or other quantum resource)
→ Plots are now quantum-linked
→ Visual indicator: Glowing line between plots
```

### 2. Growth Phase (Synchronized)
```
Both plots grow together:
├─ Energy growth: Sun → both grow exponentially together
├─ Theta evolution: Both affected by sun/moon Hamiltonian
├─ Decoherence: Both decay in tandem
└─ Measurement still forbidden (alive superposition)
```

### 3. Strategic Decision: Harvest Timing
```
Player must choose WHEN to measure both plots together
(Measuring one collapses both instantly!)

Optimal timing depends on:
├─ Current energy level (radius)
├─ Theta position (which emoji is most likely)
├─ Bell state type (what do you WANT to harvest?)
└─ Resource needs (what's more valuable right now?)
```

### 4. Entangled Measurement & Harvest
```
Click harvest on plot A (which is entangled with B)
→ BOTH plots measured simultaneously
→ Outcomes correlated according to Bell state:
   ├─ Φ+ (Same): A=🌾 → B=🌾 (auto-sync)
   └─ Ψ+ (Opposite): A=🌾 → B=👥 (complementary)

Result:
├─ Plot A yields: frozen_energy × collapsed_emoji_a
├─ Plot B yields: frozen_energy × collapsed_emoji_b
└─ Both plots reset (ready for next cycle)
```

## Entanglement Payoffs

### Pure Same-Correlation (Φ+) Farm
```
Scenario: Wheat field ↔ Wheat field
┌─────────────────┬──────────────────┐
│ Entanglement    │ Outcomes         │
├─────────────────┼──────────────────┤
│ Both at 0.5     │ Both 🌾 (5 wheat)│
│ energy, 60% 🌾  │ OR both 👥 (5    │
│                 │ labor)           │
└─────────────────┴──────────────────┘

Advantage: Predictable! Energy 0.5 + good theta = reliable harvest
Disadvantage: 40% chance both collapse to labor (loss!)
```

### Pure Opposite-Correlation (Ψ+) Farm
```
Scenario: Wheat ↔ Tomato field
┌──────────────────┬───────────────────┐
│ Entanglement     │ Outcomes          │
├──────────────────┼───────────────────┤
│ Energy 0.5       │ Wheat: 5 units    │
│ Wheat 60% north  │ Tomato: 5 units   │
│ (🌾), Tomato 60% │ (complementary)   │
│ north (🍅)       │                   │
└──────────────────┴───────────────────┘

Advantage: Always get both resources! Hedging strategy
Disadvantage: Can't maximize one resource type
```

## Entanglement Mechanics in Code

### Creating Entanglement
```gdscript
# In FarmGrid or GameController
func create_entanglement(plot_a_pos: Vector2i, plot_b_pos: Vector2i, bell_state: String):
    var plot_a = get_plot(plot_a_pos)
    var plot_b = get_plot(plot_b_pos)

    if not plot_a.quantum_state or not plot_b.quantum_state:
        return false

    # Create EntangledPair
    var pair = EntangledPair.new()
    pair.qubit_a_id = plot_a.plot_id
    pair.qubit_b_id = plot_b.plot_id
    pair.north_emoji_a = plot_a.get_plot_emojis()["north"]
    pair.south_emoji_a = plot_a.get_plot_emojis()["south"]
    pair.north_emoji_b = plot_b.get_plot_emojis()["north"]
    pair.south_emoji_b = plot_b.get_plot_emojis()["south"]

    # Create specified Bell state
    match bell_state:
        "same":
            pair.create_bell_phi_plus()
        "opposite":
            pair.create_bell_psi_plus()

    # Link qubits to pair
    plot_a.quantum_state.entangled_pair = pair
    plot_a.quantum_state.is_qubit_a = true
    plot_b.quantum_state.entangled_pair = pair
    plot_b.quantum_state.is_qubit_a = false

    # Store in grid
    entangled_pairs.append(pair)
    return true
```

### Measurement (Both Plots)
```gdscript
# In WheatPlot.measure()
func measure(icon_network = null, paired_plot = null) -> String:
    if quantum_state.entangled_pair:
        # ENTANGLED: Measure BOTH simultaneously
        var pair = quantum_state.entangled_pair
        var result = pair.measure_both()

        var my_result = result["a"] if quantum_state.is_qubit_a else result["b"]
        var other_result = result["b"] if quantum_state.is_qubit_a else result["a"]

        # Both freeze their energy
        quantum_state.freeze_energy_on_measurement()
        paired_plot.quantum_state.freeze_energy_on_measurement()

        return my_result
    else:
        # UNENTANGLED: Measure normally
        quantum_state.freeze_energy_on_measurement()
        return quantum_state.measure()
```

### Harvest (Both Plots)
```gdscript
# When player harvests entangled plot A
# → Both plots A and B harvest together

func harvest_entangled_pair(plot_a: WheatPlot, plot_b: WheatPlot) -> Dictionary:
    var result_a = plot_a.harvest()  # Uses measured_energy from pair measurement
    var result_b = plot_b.harvest()

    return {
        "plot_a": result_a,
        "plot_b": result_b,
        "correlation_type": plot_a.quantum_state.entangled_pair.get_measurement_correlation()["type"],
        "total_yield_a": result_a["yield"],
        "total_yield_b": result_b["yield"]
    }
```

## Gameplay Strategies

### Strategy 1: Synchronize High-Yield Crops
Create |Φ+⟩ entanglement between two wheat plots when both have high energy and favorable theta.
- **Upside**: If theta good, both harvest well
- **Downside**: If theta bad, both fail together
- **Use**: When confident in quantum state

### Strategy 2: Risk Hedging
Create |Ψ+⟩ between wheat and tomato with opposite emoji preferences.
- **Upside**: Guaranteed to get both 🌾 and 🍅
- **Use**: When you need balanced resources
- **Plan ahead**: Don't create opposite if one crop is in bad shape

### Strategy 3: Energy Amplification
Entangle two plots with high coherence (both in superposition).
- Both grow exponentially together (energy multiplication)
- More total energy than independent plots
- **Cost**: Must coordinate harvest timing precisely

### Strategy 4: Theta Targeting
Use sun/moon Hamiltonian to push both theta toward desired emoji together.
- Sun phase pushes both toward 🌾
- Moon phase lets both drift freely
- **Entanglement amplifies effect**: Two plots drifting = coordinated uncertainty

## Resource Costs & UI

### Entanglement Costs
```
Create |Φ+⟩ (Same): 2 Conspiracy Node energy
Create |Ψ+⟩ (Opposite): 1 Conspiracy Node energy + 1 Labor

Rationale:
- Same correlation is harder to maintain (requires stronger coupling)
- Opposite is cheaper but less predictable
```

### UI Display
```
On entangled plots:
┌─────────────────┐
│ 🌾 Plot A       │
│ θ: 45°, r: 0.6 │
│ ↔ ENTANGLED ↔   │  ← Glowing link
│ 🍅 Plot B       │
│ θ: 50°, r: 0.55│
│ [Φ+] Same      │  ← Bell state indicator
└─────────────────┘

On hover: Show correlation strength + predicted outcomes
```

## Physics ↔ Gameplay Bridge

**Quantum Property** → **Gameplay Mechanic**
- Bell state (|Φ+⟩/|Ψ+⟩) → Correlation type (same/opposite)
- Measurement correlation → Harvest outcome linkage
- Entanglement entropy → Uncertainty/risk level
- Concurrence → Strength of coupling (cost inversely)

---

## Example: Full Game Turn with Entanglement

### Turn 1: Plant & Entangle
```
Day 1, Morning:
  Action: Plant wheat at (0,0) and (1,0)
  → Both start radius=0.3, theta=π/2
  → Cost: 0.4 labor (0.2 each)

  Action: Entangle with |Φ+⟩ (Same)
  → Cost: 2 node energy
  → Both plots now quantum-linked
```

### Turn 2-5: Growth Under Sun/Moon
```
Days 2-3 (Sun phase):
  - Energy grows: 0.3 → 0.5 → 0.7 (exponential)
  - Theta biased: π/2 → 0.4 rad (toward 🌾)
  - Plots grow in sync

Day 4 (Moon phase):
  - Energy stalls: 0.7 (no growth)
  - Theta drifts: back toward π/2
  - Still perfectly entangled
```

### Turn 5: Harvest Entangled Pair
```
Day 5, Evening (Energy: 0.7, Theta: 0.6 rad)
  P(🌾) ≈ 70%, P(👥) ≈ 30%

  Action: Harvest Plot A (at (0,0))
  → Triggers BOTH plots' measurement:
    • Both measured simultaneously
    • |Φ+⟩ correlation: outcomes must be same
    • Outcome: BOTH collapse to 🌾 (70% chance)
    • Result: A gets 7 wheat, B gets 7 wheat ✓

    OR outcome: BOTH collapse to 👥 (30% chance)
    • Result: A gets 7 labor, B gets 7 labor ✗ (oops!)
```

## Success Metrics

A good entanglement gameplay system should:
- ✅ **Encourage cooperation**: Players benefit from planning paired harvests
- ✅ **Create meaningful choices**: Same vs Opposite has real trade-offs
- ✅ **Reward strategic thinking**: Timing harvest based on theta + energy
- ✅ **Show quantum properties intuitively**: Correlation ↔ outcome linkage is obvious
- ✅ **Enable advanced strategies**: Energy pooling, theta manipulation, risk hedging
