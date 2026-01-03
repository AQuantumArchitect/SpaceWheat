# SpaceWheat LLM Documentation Export

This directory contains comprehensive documentation of SpaceWheat's quantum farming mechanics, organized for external review, advisement, and future reference.

## Directory Structure

```
llm_outbox/
├── README.md (this file)
├── quantum_mechanics/          # Quantum physics analysis and conversion systems
└── game_mechanics/             # Individual game mechanic deep-dives
```

---

## Quantum Mechanics Documentation

📁 **Location**: `llm_outbox/quantum_mechanics/`

### Files

1. **quantum_state_properties_investigation.md** (380 lines)
   - Investigation of quantum state properties: radius, coherence, theta, purity
   - Analysis of `.energy` property (REMOVED during bath-first refactor)
   - Identifies radius (coherence) as the actual resource, NOT theta
   - Injection and extraction mechanisms across all tools
   - Test verification that emoji injection works correctly

2. **wheat_farming_system_verified_WORKING.md** (369 lines)
   - Comprehensive verification that dual-emoji wheat planting works
   - Emoji injection mechanism explained (👥 auto-injected during planting)
   - Icon physics integration (Hamiltonian coupling H[🌾][👥] = 0.25)
   - Quantum evolution growth rates (23× coherence increase in 0.5s)
   - Expected gameplay flow and common issues

3. **quantum_classical_conversion_analysis.md** (450 lines)
   - INITIAL analysis of quantum→classical resource conversion (contains ERRORS)
   - Current formula: `yield = max(1, (radius × 0.9 + berry_phase × 0.1) × 10 × (2.0 × purity))`
   - Identified 5 issues with current system
   - Berry phase bonus recommendation (LATER CORRECTED)
   - **Note**: See revised analysis for corrected physics

4. **quantum_classical_conversion_revised.md** (492 lines)
   - CORRECTED analysis accounting for dimensionality problem
   - Critical user insight: "radius tends to be very small because they are sharing a unitary space with upwards of 20 peers"
   - Berry phase properly explained (geometric phase, NOT entanglement)
   - 6 alternative conversion mechanisms proposed
   - **Recommended**: Hybrid system (Population + Coherence + Evolution bonuses)
   - Dimension-agnostic formulas for fair yields across biome sizes

### Key Physics Concepts

- **Density Matrix Formalism**: ρ (rho), Tr(ρ) = 1
- **Bloch Sphere**: theta, phi, radius (coherence)
- **Purity**: Tr(ρ²) - quantum vs classical mixing
- **Coherence**: Off-diagonal density matrix elements |ρ[i][j]|
- **Berry Phase**: Geometric phase from cyclic evolution (NOT entanglement!)
- **Master Equation**: dρ/dt = -i[H, ρ] + L(ρ)
- **Born Rule**: Measurement probabilities from diagonal elements

### Critical Discoveries

1. ✅ **Emoji injection works** - BiomeBase.create_projection() auto-injects missing emojis
2. ✅ **Icon physics integrated** - Injection brings full Hamiltonian + Lindblad operators
3. ✅ **Evolution verified** - Coherence builds from r≈0 to r≈0.5+ over 3-5 seconds
4. ⚠️ **Dimensionality problem** - Large baths (20+ emojis) have inherently small radius
5. ⚠️ **Current formula issues** - Purity multiplier double-counts, ignores dimensionality

---

## Game Mechanics Documentation

📁 **Location**: `llm_outbox/game_mechanics/`

### Files

1. **01_plant_mechanic.md**
   - How planting creates quantum superposition (🌾↔👥)
   - Automatic emoji injection with full Icon physics
   - Bath expansion (6→7 dimensions) during injection
   - Hamiltonian coupling creation (H[🌾][👥] = 0.25)
   - Initial state analysis (maximally mixed → r≈0)
   - Evolution dynamics and debugging tips

2. **02_harvest_mechanic.md**
   - Born rule measurement (collapse to definite outcome)
   - Partial collapse mechanism (collapse_strength = 0.5)
   - Resource extraction formula (current + recommended alternatives)
   - The "?" outcome issue explained
   - Plot state clearing after harvest
   - Berry phase accumulation across replants

3. **03_energy_tap_mechanic.md**
   - Passive resource generation via probability drain
   - Dynamic submenu generation from discovered vocabulary
   - Vocabulary discovery system (progression gating)
   - Continuous accumulation every frame
   - Multi-harvest (tap remains after harvest)
   - Strategic placement and economics

4. **04_boost_coupling_mechanic.md**
   - Hamiltonian coupling strength amplification
   - Effect: Faster coherent oscillations (H[i,j] × 1.5)
   - Evolution time reduction (~40% speedup)
   - Use cases: Fast farming, synchronization, weak coupling rescue
   - Persistence (temporary per-session, not saved)
   - Debugging Hamiltonian matrix inspection

5. **05_tune_decoherence_mechanic.md**
   - Lindblad operator rate reduction (γ × 0.5)
   - Effect: Slower purity decay, higher yields
   - Resource cost: 10 wheat credits per plot
   - Economics: Currently NOT viable (negative ROI)
   - Rebalancing recommendations
   - Synergy with boost_coupling

### Core Mechanics Summary

| Mechanic | Type | Effect | Cost | Persistence |
|----------|------|--------|------|-------------|
| **Plant** | Active | Create quantum state, inject emojis | Free (evolution time) | Per-plot |
| **Harvest** | Active | Measure state, extract resources | None | Clears plot |
| **Energy Tap** | Passive | Continuous probability drain | Plot slot | Multi-harvest |
| **Boost Coupling** | Buff | Faster evolution (H[i,j] × 1.5) | Free | Temporary |
| **Tune Decoherence** | Buff | Higher purity (γ × 0.5) | 10 wheat/plot | Temporary |

---

## Critical Files Referenced

### Core Game Files
- `Core/GameMechanics/BasePlot.gd` - Plot planting, measurement, harvest logic
- `Core/Environment/BiomeBase.gd` - Emoji injection, projection creation
- `Core/QuantumSubstrate/QuantumBath.gd` - Density matrix evolution, observables
- `Core/QuantumSubstrate/DualEmojiQubit.gd` - Stateless projection lens
- `Core/GameMechanics/FarmGrid.gd` - Plot management, biome assignments
- `Core/GameMechanics/FarmEconomy.gd` - Resource storage, conversion rates
- `Core/Farm.gd` - High-level orchestration, harvest routing

### UI/Input Files
- `UI/FarmInputHandler.gd` - Action handlers for all mechanics
- `Core/GameState/ToolConfig.gd` - Dynamic submenu generation

### Test Files Created
- `Tests/test_wheat_injection.gd` - Verifies emoji injection works
- `Tests/test_complete_wheat_cycle.gd` - Full plant→evolve→harvest test
- `Tests/test_hamiltonian_simple.gd` - Coupling strength verification

---

## Key Insights & Recommendations

### What Works
1. ✅ **Bath-First Architecture** - All quantum state lives in QuantumBath density matrix
2. ✅ **Automatic Emoji Injection** - Missing emojis injected with full Icon physics
3. ✅ **Icon-Driven Physics** - Hamiltonian + Lindblad from Icon definitions
4. ✅ **Real Quantum Evolution** - Master equation with observable coherence growth

### What Needs Improvement
1. ⚠️ **Quantum→Classical Conversion** - Current formula double-counts, ignores dimensionality
2. ⚠️ **"?" Harvest Outcomes** - Measuring r≈0 states produces invisible credits
3. ⚠️ **Decoherence Tuning Economics** - Cost (10 wheat) > benefit (2-5 credits)
4. ⚠️ **Persistence** - Hamiltonian boosts and Lindblad tunings not saved

### Recommended Changes
1. **Adopt hybrid conversion formula** (quantum_classical_conversion_revised.md):
   ```
   base_yield = (P(north) + P(south)) × 100
   quantum_bonus = |ρ[north][south]| × 50
   evolution_bonus = base × (berry_phase/5) × 0.2
   total = base + quantum + evolution
   ```

2. **Fix "?" outcomes** - Route to labor (👥) or track as separate resource

3. **Rebalance decoherence tuning**:
   - Option A: Reduce cost (10 → 2 wheat)
   - Option B: Increase benefit (reduction 0.5 → 0.2)
   - Option C: Make permanent for biome (infrastructure upgrade)

4. **Implement persistence** - Save Hamiltonian boosts and Lindblad reductions

---

## For External Reviewers

### Physics Accuracy
- Density matrix formalism correctly implemented
- Master equation evolution (Hamiltonian + Lindblad)
- Born rule measurement
- Proper Hermitian constraints maintained
- Berry phase usage CORRECTED (was conflated with entanglement)

### Game Design
- Resource economy balanced around quantum mechanics
- Progression gating via vocabulary discovery
- Strategic depth: Active vs passive income, evolution speed vs purity
- Clear quantum advantage (entanglement, superposition bonuses)

### Architecture Quality
- Clean separation: Bath (quantum state) vs Qubit (projection view)
- Dynamic emoji injection enables compositional gameplay
- Icon system provides modular physics definitions
- Biome-specific customization via Icon sets

### Known Technical Debt
- Dimensionality scaling (yields unfair for large baths)
- Persistence system incomplete (boosts/tunings not saved)
- Economics unbalanced (decoherence tuning not viable)
- Visualization lag behind physics (bubbles don't always reflect actual bath state)

---

## Version Information

**Documentation Created**: 2026-01-02
**Game Version**: Bath-First Architecture (post-qubit-first refactor)
**Codebase State**: Working injection system, verified wheat farming cycle
**Test Coverage**: Emoji injection ✅, Hamiltonian coupling ✅, Evolution growth ✅

---

## Contact & Questions

For questions about this documentation or the underlying physics/mechanics:
- Review the markdown files in this directory
- Cross-reference with actual code files (paths provided)
- Run test files to verify claimed behavior
- Check git history for implementation evolution

**Key Decision Point**: Should we adopt the revised quantum→classical conversion formula? See `quantum_mechanics/quantum_classical_conversion_revised.md` for full analysis.
