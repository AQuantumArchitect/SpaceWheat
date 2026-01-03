# Tool 6: BIOME Reassignment System Design

## Current Status

**Implementation**: ⚠️ UI Complete, Backend Partial
**UI**: ✅ Complete (dynamic submenu generates from 4 biomes)
**Backend**: ⚠️ Partial (biome system exists, reassignment logic missing)

```
Q: Biome Assignment (Dynamic - shows discovered biomes)
├─ Q: Assign to BioticFlux 🌾
├─ E: Assign to Market 💰
├─ R: Assign to Forest 🌍
└─ (Kitchen: Assign to Kitchen 🍳) [4th biome if discoverable]

E: Clear Assignment (❌)
R: Inspect Plot (🔍)
```

---

## Current System Context

### The 4 Biomes

**BioticFlux** (🌾):
- Focus: Wheat growth via Lindblad incoming
- Emojis: 🌾🍄👥☀️🌙🐂
- Special: Mushroom composting (Lindblad operators)

**Market** (💰):
- Focus: Trading dynamics, economic growth
- Emojis: 🐂🐻💰📦🏛️🏚️
- Special: Pure market mechanics (not yet detailed)

**Forest** (🌍):
- Focus: Ecology, predator-prey dynamics
- Emojis: 🐺🦅🐇🦌🌿☀️💧🍂 (+ 14 more from Markov derivation)
- Special: Lotka-Volterra derived from Markov chain

**Kitchen** (🍳):
- Focus: Bread production, transformation
- Emojis: 🌾🌊🔥✨
- Special: Ingredient transformation (baking)

### Current Assignment Status
- Plots pre-assigned to biomes at farm initialization (hardcoded grid layout)
- Assignment visible in plot visualization
- Affects which biome's quantum bath governs plot evolution
- Layout: `[M] [M] [B] [B] [B] [B] / [F] [F] [F] [F] [K] [K]`

---

## Questions for Design

### Question 1: DYNAMIC REASSIGNMENT - IS IT ALLOWED?

**Can players move plots between biomes after initial setup?**

#### Option A: Plots Locked to Initial Biome
- Player cannot reassign plots
- Biome assignment set at farm creation
- Biome acts as permanent plot property
- Implications:
  - Simplest implementation (no changes needed)
  - Game design: spatial strategy (what's in what region?)
  - No reassignment complexity

#### Option B: Plots Freely Reassignable (No Cost)
- Player can reassign any plot to any biome at any time
- Cost: 0 resources
- Reassignment instant
- Implications:
  - Maximum flexibility
  - Player can optimize for each biome's advantages
  - Risk: Removes spatial constraint (players just use best biome)
  - Trivializes biome choice

#### Option C: Reassignment with Resource Cost
- Player can reassign, but costs resources
- Cost: 10 🌾 per reassignment (soil preparation?)
- Or: 5 👥 (labor to transplant)
- Or: 1 💰 (infrastructure change)
- Implications:
  - Players can optimize but with economic cost
  - Encourages thoughtful reassignment
  - Adds interesting decisions (worth the cost?)

#### Option D: Temporal Restriction
- Plots can reassign only between harvest cycles
- Cannot reassign while planted
- Measured plots can't reassign (have to harvest first)
- Implications:
  - Temporal strategy (when to switch?)
  - Prevents mid-growth switching
  - Adds planning constraint

**Recommendation needed**: Should reassignment be allowed, and if so, what's the cost model?

---

### Question 2: QUANTUM STATE ON REASSIGNMENT

**What happens to a plot's quantum state when reassigned to a different biome?**

#### Option A: State Preserved (Transferred)
- Moving wheat from BioticFlux to Market keeps quantum state
- Density matrix transfers to new biome's bath
- State continues evolving under new biome's Hamiltonian
- Implications:
  - Plot's quantum history is preserved
  - Creates interesting hybrid states (wheat in market dynamics)
  - Requires careful density matrix transfer

#### Option B: State Partially Reset
- Only population numbers transfer, not coherence
- Reassigned plot gets fresh coherence in new biome
- Purity reduced to 0.5 (reset to |0+1⟩ superposition)
- Implications:
  - Reassignment is disruptive (loses quantum properties)
  - Cost is both economic AND quantum (purity loss)
  - Makes reassignment strategic sacrifice

#### Option C: Complete State Reset
- Reassignment clears everything
- Plot becomes equivalent to freshly planted
- Quantum state resets to biome's default
- Implications:
  - Reassignment is "replanting" essentially
  - Simplest implementation (no state transfer)
  - Reassignment has high cost (lose all quantum work)
  - Makes reassignment very consequential

#### Option D: Biome-Dependent Behavior
- Some biomes preserve state, others reset
- BioticFlux → Market: Preserve (both growth-based)
- BioticFlux → Forest: Reset (ecological disruption)
- Forest → Kitchen: Reset (preparation needed)
- Implications:
  - Different biome pairs have different rules
  - High complexity but asymmetric strategy
  - Requires player knowledge

**Recommendation needed**: How should quantum state behave during reassignment?

---

### Question 3: INSPECTION & PLOT INFORMATION

**What should the Inspect Plot action reveal?**

#### Option A: Minimal Information
- Show: Plant type (wheat/mushroom/tomato)
- Show: Current biome
- Show: Planted or Measured status
- Don't show: Quantum state details

#### Option B: Full Quantum Inspector
- Show: All quantum state (purity, θ, coherence)
- Show: North/South emoji basis
- Show: Expected yield at harvest
- Show: Measurement cost (if applicable)
- Show: Which gates applied
- Show: Which plots entangled with

#### Option C: Gameplay-Focused Inspector
- Show: Plant maturity progress (3 days until ready)
- Show: Current biome effects (rate boosts, special mechanics)
- Show: Harvest prediction (yield estimate)
- Don't show: Raw quantum metrics (too technical)

#### Option D: Biome-Specific Inspection
- Different biomes show different info
- BioticFlux: Quantum state + growth rate
- Market: Profit projections + trading dynamics
- Forest: Ecological role + predation threats
- Kitchen: Ingredient readiness + recipe compatibility

**Recommendation needed**: What information should inspection reveal?

---

## Current System Context

### How Biomes Currently Work

Each biome has:
- `quantum_bath`: QuantumBath managing N-dimensional Hilbert space
- `producible_emojis`: Which resources can be created
- `measure_plot_in_biome()`: Custom measurement logic
- Plots receive quantum projections from their biome's bath

When plot planted:
1. Biome's bath injects new emoji (plot quantum state)
2. Creates 2D projection (north_emoji ↔ south_emoji)
3. Bath evolves density matrix via Lindblad operators
4. Measurement collapses to measurement outcome

### Plot-Biome Relationship

Currently: Plot `plot_biome_assignments[pos]` stores which biome
- If reassignment allowed, this needs to update
- But also need to transfer quantum state to new bath
- Current code expects plot.quantum_state.bath to match biome.quantum_bath

### Integration Points

**FarmGrid.reassign_plot(pos: Vector2i, new_biome: String) needs**:
- Validation (is new_biome valid?)
- Cost deduction (if costs exist)
- Quantum state transfer (if preserving state)
- Lookup update (`plot_biome_assignments[pos] = new_biome`)
- Signals for UI update

---

## Implementation Sequence (After Design Approval)

1. Design decision: Is reassignment allowed? (A, B, C, or D)
2. Design decision: How does quantum state behave? (A, B, C, or D)
3. Design decision: What does inspection show? (A, B, C, or D)
4. If reassignment allowed:
   - Implement cost validation
   - Implement quantum state transfer (if needed)
   - Implement reassignment backend method
   - Wire Tool 6 Q action to reassignment
5. Implement inspection UI/logic
   - Decide which quantum metrics to display
   - Create display panel
   - Wire Tool 6 R action to inspection
6. Wire Tool 6 E (clear assignment)
   - Return plot to default/biome-less state
   - Handle quantum state of cleared plot
7. Integration testing
   - Test reassignment during different plot states
   - Test measurement after reassignment
   - Test entanglement across reassignment
8. Edge case testing
   - Entangled plots reassigned separately
   - Harvest immediately after reassignment
   - Reassignment during measurement

**Estimated effort**: 3-4 hours (after design is approved)

---

## Questions for External Review

1. **Gameplay philosophy**: Should biomes be "permanent" constraints or "flexible" tools?
2. **Complexity budget**: Is reassignment system worth the implementation effort?
3. **Strategic depth**: Should reassignment add interesting decisions or feel like busywork?
4. **Quantum realism**: Should quantum state be preserved (realistic) or reset (gameplay-driven)?
5. **Information design**: Should players see raw quantum metrics or simplified gameplay indicators?

---

## Risk Assessment

**Risk**: Reassignment trivializes biome choice
- **Mitigation**: Add resource cost, temporal restrictions, or quantum state cost

**Risk**: Quantum state transfer during reassignment breaks bath invariants
- **Mitigation**: Only allow reassignment for simple states (unmeasured plots only)

**Risk**: Inspection panel becomes too complex with too much information
- **Mitigation**: Start with minimal info (plant type, biome, status), add advanced metrics later

**Risk**: Entanglement becomes problematic across biome boundaries
- **Mitigation**: Clarify: are entangled plots in same biome, or can cross biome?
- **Answer needed**: If plot A in BioticFlux entangles with plot B in Market, what happens to entanglement when one reassigns?

---

## Questions Needing Clarification

1. **Entanglement across biomes**: Currently, can plots from different biomes be entangled?
2. **Bath boundaries**: Does reassignment move a plot between quantum baths, or is there one global bath?
3. **Gates and reassignment**: If plot has gates applied, what happens when reassigned?

