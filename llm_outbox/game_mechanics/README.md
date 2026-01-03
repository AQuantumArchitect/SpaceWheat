# Game Mechanics Documentation

Comprehensive documentation of SpaceWheat's core gameplay mechanics, from quantum state creation to resource extraction.

## Quick Navigation

### Core Farming Loop
1. **[Plant](01_plant_mechanic.md)** - Create quantum superposition, inject missing emojis
2. **[Harvest](02_harvest_mechanic.md)** - Measure state, extract resources based on coherence

### Passive Income
3. **[Energy Tap](03_energy_tap_mechanic.md)** - Continuous probability drain, multi-harvest

### Evolution Control (Buffs)
4. **[Boost Coupling](04_boost_coupling_mechanic.md)** - Increase Hamiltonian strength (faster evolution)
5. **[Tune Decoherence](05_tune_decoherence_mechanic.md)** - Reduce Lindblad rates (higher purity)

---

## Mechanic Comparison Table

| Mechanic | Action Type | Quantum Effect | Classical Effect | Cost | Reusable? |
|----------|-------------|----------------|------------------|------|-----------|
| **Plant** | Active | Creates ρ projection | None | Evolution time | No (harvest clears) |
| **Harvest** | Active | Measurement (Born rule) | Adds emoji-credits | None | No (one-time) |
| **Energy Tap** | Passive | Drains P(emoji) | Accumulates credits | Plot slot | Yes (multi-harvest) |
| **Boost Coupling** | Buff | H[i,j] × 1.5 | Faster coherence growth | Free | Temporary |
| **Tune Decoherence** | Buff | γ × 0.5 | Higher purity at harvest | 10 wheat/plot | Temporary |

---

## Data Flow Diagrams

### Plant → Harvest Flow
```
User plants wheat at (2,0)
  ↓
BasePlot.plant() called with biome
  ↓
BiomeBase.create_projection("🌾", "👥")
  ├─ Check bath: 🌾 exists ✅, 👥 missing ❌
  ├─ Inject 👥: bath.inject_emoji("👥", labor_icon, amplitude)
  │   ├─ Expand Hilbert space: 6 → 7 dimensions
  │   ├─ Rebuild Hamiltonian with H[🌾][👥] = 0.25
  │   └─ Normalize: Tr(ρ) = 1
  └─ Create DualEmojiQubit(🌾, 👥, θ=π/2, bath)
  ↓
Plot quantum_state initialized
  ├─ radius ≈ 0 (maximally mixed subspace)
  ├─ theta ≈ π/2 (equal probabilities)
  └─ purity ≈ 0.5 (mixed 2-state)
  ↓
Quantum evolution: dρ/dt = -i[H, ρ] + L(ρ)
  ├─ Hamiltonian drives coherent oscillations
  ├─ Lindblad causes decoherence
  └─ Coherence grows: r≈0 → r≈0.5 (3-5 seconds)
  ↓
User harvests plot
  ↓
BasePlot.harvest()
  ├─ Auto-measure if not measured
  ├─ Born rule: outcome ∈ {🌾, 👥} based on probabilities
  ├─ Extract yield: (r × 0.9 + berry × 0.1) × 10 × (2.0 × purity)
  └─ Clear plot: quantum_state = null
  ↓
Farm._process_harvest_outcome()
  ├─ Convert yield to credits (×10)
  └─ Add to economy: emoji_credits[outcome] += credits
```

### Energy Tap Flow
```
User discovers 👥 emoji (via harvest)
  ↓
farm.grid.register_emoji_discovery("👥")
  ↓
Vocabulary updated: discovered_vocabulary["👥"] = timestamp
  ↓
User opens Tool 4 → Q (Energy Tap submenu)
  ↓
ToolConfig._generate_energy_tap_submenu()
  ├─ Query: farm.grid.get_available_tap_emojis() → ["🌾", "👥", "🍄"]
  ├─ Map to Q/E/R buttons
  └─ Return dynamic submenu
  ↓
User presses E (Tap 👥)
  ↓
FarmGrid.plant_energy_tap(Vector2i(2,0), "👥")
  ├─ Validate: 👥 in discovered_vocabulary ✅
  ├─ Configure plot: tap_target_emoji = "👥"
  ├─ Set: tap_base_rate = 0.5
  └─ Mark planted
  ↓
Every frame: _process(delta)
  ├─ Get: p_target = bath.get_probability("👥")
  ├─ Calculate: drain_rate = 0.5 × coupling × p_target
  ├─ Accumulate: tap_accumulated_resource += drain_rate × delta
  └─ Drain bath: reduce P(👥) slightly
  ↓
User harvests tap (later)
  ↓
harvest_energy_tap()
  ├─ Extract: yield = int(accumulated × 10)
  ├─ Reset: accumulated = 0.0
  └─ Keep tap active! (not destroyed)
```

### Evolution Control Flow
```
User plants wheat, wants faster evolution
  ↓
Presses Tool 4 → Q (Boost Coupling)
  ↓
FarmInputHandler._action_boost_coupling([Vector2i(2,0)])
  ├─ Get plot quantum_state: north="🌾", south="👥"
  ├─ Get biome for position
  └─ Call: biome.boost_hamiltonian_coupling("🌾", "👥", 1.5)
      ├─ Get current: H[🌾][👥] = 0.25
      ├─ Multiply: 0.25 × 1.5 = 0.375
      ├─ Set: H.set_element(wheat_idx, labor_idx, 0.375)
      └─ Mark: operators_dirty = true
  ↓
Next evolution step: bath.evolve(dt)
  ├─ Rebuild Hamiltonian (if dirty)
  ├─ Apply: dρ/dt = -i[H, ρ] + L(ρ)
  └─ Faster oscillations due to stronger coupling!
  ↓
Result: Coherence grows ~40% faster (5s → 3.3s to same level)
```

---

## Physics Cheat Sheet

### Observables
- **radius**: Bloch vector length, coherence strength [0, 1]
- **theta**: Polar angle, determines P(north) vs P(south)
- **purity**: Tr(ρ²), quantum vs classical mixing [1/N, 1]
- **coherence_ab**: |ρ[i][j]|, off-diagonal density matrix element
- **probability**: ρ[i][i], diagonal density matrix element

### Evolution
- **Hamiltonian**: -i[H, ρ] - drives coherent oscillations
- **Lindblad**: L(ρ) - drives decoherence (purity decay)
- **Time scale**: τ ≈ 1/H[i,j] - oscillation period

### Measurement
- **Born rule**: P(outcome) = ρ[outcome][outcome] / Tr(ρ_subspace)
- **Collapse**: ρ → partial collapse toward outcome (strength=0.5)
- **Outcome**: emoji ∈ {north, south} (or "?" if r≈0)

### Conversion
- **Current**: yield = max(1, (r×0.9 + berry×0.1) × 10 × (2.0×purity))
- **Recommended**: yield = population×100 + coherence×50 + evolution_bonus
- **Rate**: 1 quantum unit = 10 credits

---

## Implementation Notes

### Tool Actions
All mechanics accessible via Tool system (1-6 on number keys):
- Tool 1 Q: Plant wheat
- Tool 1 R: Harvest
- Tool 4 Q→submenu: Place energy tap (dynamic emoji selection)
- Tool 4 Q: Boost coupling
- Tool 4 E: Tune decoherence

### Key Methods
- `BasePlot.plant()` - Lines 74-109
- `BasePlot.measure()` - Lines 111-137
- `BasePlot.harvest()` - Lines 140-207
- `BiomeBase.create_projection()` - Lines 468-550
- `QuantumBath.inject_emoji()` - Lines 152-187
- `FarmGrid.plant_energy_tap()` - Lines 482-520

### Common Gotchas
1. **Planting on wrong biome**: Wheat must be on BioticFlux plots (2-5)
2. **Harvesting too early**: r≈0 produces "?" outcomes
3. **Decoherence tuning cost**: 10 wheat is often more than benefit
4. **Tap vocabulary gating**: Can't tap undiscovered emojis
5. **Boost/tune not saved**: Temporary per-session only

---

## Testing

### Manual Tests
```bash
# Plant and verify injection
godot --headless -s Tests/test_wheat_injection.gd

# Full plant→evolve→harvest cycle
godot --headless -s Tests/test_complete_wheat_cycle.gd

# Check Hamiltonian coupling
godot --headless -s Tests/test_hamiltonian_simple.gd
```

### Console Debug Commands
```gdscript
# Check bath emojis
print(farm.biotic_flux_biome.bath.emoji_list)

# Check Hamiltonian coupling
var H = biome.bath._hamiltonian
print("H[🌾][👥] = ", H.get_element(wheat_idx, labor_idx).abs())

# Check plot state
var plot = farm.grid.get_plot(Vector2i(2, 0))
print("Radius: ", plot.quantum_state.radius)
print("Purity: ", plot.quantum_state.purity)
```

---

## Future Enhancements

### Suggested Improvements
1. **Save boost/tune state** - Make Hamiltonian/Lindblad modifications persistent
2. **Rebalance tune decoherence** - Reduce cost or increase benefit
3. **Fix "?" outcomes** - Route to labor or show as separate resource
4. **Dimension-agnostic yields** - Adopt population + coherence formula
5. **Advanced taps** - Allow targeting emoji pairs, not just singles
6. **Coupling networks** - Visualize Hamiltonian graph between emojis

### Experimental Mechanics
- **Quantum annealing**: Slowly reduce Hamiltonian to find ground state
- **Echo sequences**: Apply gate-inverse pairs to extend coherence time
- **Multi-qubit gates**: CNOT, SWAP between adjacent plots
- **Measurement feedback**: Use outcome to influence next planting

---

For higher-level context, see parent directory's [README.md](../README.md).
