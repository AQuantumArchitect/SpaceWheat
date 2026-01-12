# Tool Reorganization Proposals - Visual Reference

**Date:** 2026-01-12

Quick reference for comparing reorganization schemes.

---

## SCHEME A: Pure Quantum Physics Categories

```
┌─────────────────────────────────────────────────────────────┐
│ 🌾 Tool 1: AGRICULTURE                                      │
├─────────────────────────────────────────────────────────────┤
│ Q: Plant submenu (biome-parametric)                         │
│ E: Harvest single                                           │
│ R: Harvest batch                                            │
│                                                             │
│ Philosophy: Farming separate from quantum                   │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 📋 Tool 2: STATE PREPARATION                                │
├─────────────────────────────────────────────────────────────┤
│ Q: Create pure state → |0⟩, |1⟩, |+⟩, |-⟩, custom           │
│ E: Create mixed state → maximally mixed, thermal, custom    │
│ R: Reset to |0⟩ (ground state)                              │
│                                                             │
│ Exposes: 19 state management operations                     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ ⚛️ Tool 3: UNITARY OPERATIONS                               │
├─────────────────────────────────────────────────────────────┤
│ Q: Single-qubit gates → X, Y, Z, H, S, T                    │
│ E: Two-qubit gates → CNOT, CZ, SWAP                         │
│ R: Hamiltonian evolution → custom H, preset couplings       │
│                                                             │
│ Exposes: 9 gates + Hamiltonian operators + integrators      │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 📉 Tool 4: NON-UNITARY OPERATIONS                           │
├─────────────────────────────────────────────────────────────┤
│ Q: Measure → single, batch, peek                            │
│ E: Lindblad operators → decay, transfer, gated              │
│ R: Decoherence control → T1, T2, rate tuning                │
│                                                             │
│ Exposes: 6 measurement types + 13 Lindblad operators        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 🔗 Tool 5: ENTANGLEMENT                                     │
├─────────────────────────────────────────────────────────────┤
│ Q: Create Bell state → Φ+, Φ-, Ψ+, Ψ-                       │
│ E: Create cluster → GHZ, W, Cluster, custom                 │
│ R: Analyze topology → pattern recognition                   │
│                                                             │
│ Exposes: 12 entanglement operations + topological analysis  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 🔬 Tool 6: QUANTUM ANALYSIS                                 │
├─────────────────────────────────────────────────────────────┤
│ Q: State properties → purity, entropy, coherence            │
│ E: Semantic analysis → octant, attractor personality        │
│ R: Quantum algorithms → Deutsch-Jozsa, Grover, custom       │
│                                                             │
│ Exposes: 8 state metrics + 27 semantic/topological features │
└─────────────────────────────────────────────────────────────┘
```

**Pros:**
- ✅ Highest quantum physics rigor
- ✅ Best for educational/research gameplay
- ✅ Exposes ALL quantum infrastructure

**Cons:**
- ❌ Steep learning curve
- ❌ Breaks existing player muscle memory
- ❌ No energy extraction (spark system orphaned)

---

## SCHEME B: Gameplay-Oriented Categories

```
┌─────────────────────────────────────────────────────────────┐
│ 🌱 Tool 1: FARMING                                          │
├─────────────────────────────────────────────────────────────┤
│ Q: Plant submenu (biome-parametric)                         │
│ E: Entangle (Bell Φ+)                                       │
│ R: Measure & Harvest                                        │
│                                                             │
│ Philosophy: Keep Tool 1 unchanged (80% gameplay)            │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ ⚛️ Tool 2: QUANTUM CONTROL                                  │
├─────────────────────────────────────────────────────────────┤
│ Q: Single-qubit gates → X, Y, Z, H, S, T                    │
│ E: Two-qubit gates → CNOT, CZ, SWAP                         │
│ R: Advanced control → Hamiltonian, Lindblad, Pump/Reset     │
│                                                             │
│ Exposes: Gates + Hamiltonians + Lindblad (merges Tools 4+5) │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 🔍 Tool 3: OBSERVATION                                      │
├─────────────────────────────────────────────────────────────┤
│ Q: Peek state (non-destructive)                             │
│ E: Measure single (collapse)                                │
│ R: Inspect properties → purity, entropy, coherence          │
│                                                             │
│ Exposes: All measurement types + state property inspection  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 🔗 Tool 4: ENTANGLEMENT                                     │
├─────────────────────────────────────────────────────────────┤
│ Q: Create Bell → Φ+, Φ-, Ψ+, Ψ-                             │
│ E: Create cluster → GHZ, W, Cluster                         │
│ R: Analyze topology → pattern recognition                   │
│                                                             │
│ Exposes: Entanglement + graph tracking + topology           │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ ⚡ Tool 5: ENERGY & RESOURCES                               │
├─────────────────────────────────────────────────────────────┤
│ Q: Energy tap → first 3 discovered emojis                   │
│ E: Spark extraction → coherence → population                │
│ R: Energy analysis → real vs imaginary, regime              │
│                                                             │
│ Exposes: Full spark system + population transfer            │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 🌍 Tool 6: ENVIRONMENT                                      │
├─────────────────────────────────────────────────────────────┤
│ Q: Assign to biome → dynamic biomes                         │
│ E: Semantic navigation → octant, adjacent regions           │
│ R: Attractor analysis → personality, trajectory             │
│                                                             │
│ Exposes: Biomes + semantic octants + attractor personalities│
└─────────────────────────────────────────────────────────────┘
```

**Pros:**
- ✅ Minimal disruption to Tool 1 (player familiarity)
- ✅ Consolidates confusing Tools 4+5
- ✅ Gameplay-focused language
- ✅ Exposes semantic/topological features

**Cons:**
- ❌ Tool 2 becomes catch-all "Quantum Control"
- ❌ Less quantum physics rigor
- ❌ No quantum algorithms exposed

---

## SCHEME C: Hybrid Physics + Gameplay (RECOMMENDED)

```
┌─────────────────────────────────────────────────────────────┐
│ 🌾 Tool 1: CULTIVATION                                      │
├─────────────────────────────────────────────────────────────┤
│ Q: Plant submenu                                            │
│ E: Entangle (Bell Φ+)                                       │
│ R: Measure & Harvest                                        │
│                                                             │
│ Philosophy: Keep Tool 1 unchanged (player familiarity)      │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 🔄 Tool 2: QUANTUM GATES                                    │
├─────────────────────────────────────────────────────────────┤
│ Q: Basic gates → X, Y, Z, H                                 │
│ E: Phase gates → S, T, custom phase                         │
│ R: Two-qubit gates → CNOT, CZ, SWAP                         │
│                                                             │
│ Exposes: All 9 gates, organized by type                     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 🧪 Tool 3: QUANTUM LAB                                      │
├─────────────────────────────────────────────────────────────┤
│ Q: Hamiltonian evolution → custom couplings                 │
│ E: Lindblad operators → decay, transfer, gated              │
│ R: Integrator selection → Euler, Cayley, Expm, RK4          │
│                                                             │
│ Exposes: Operator construction + advanced evolution         │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 📊 Tool 4: MEASUREMENT & ANALYSIS                           │
├─────────────────────────────────────────────────────────────┤
│ Q: Measure → single, batch, peek                            │
│ E: State properties → purity, entropy, coherence            │
│ R: Quantum algorithms → Deutsch-Jozsa, Grover               │
│                                                             │
│ Exposes: Measurement + state metrics + quantum algorithms   │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 🔗 Tool 5: TOPOLOGY & PATTERNS                              │
├─────────────────────────────────────────────────────────────┤
│ Q: Create entanglement → Bell, GHZ, W, Cluster              │
│ E: Analyze topology → pattern recognition                   │
│ R: Semantic analysis → octant, attractor personality        │
│                                                             │
│ Exposes: Entanglement + topology + semantic octants         │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ ⚡ Tool 6: ENERGY & BIOMES                                  │
├─────────────────────────────────────────────────────────────┤
│ Q: Assign biome → dynamic biomes                            │
│ E: Energy tap → discovered emojis                           │
│ R: Spark extraction → coherence → population                │
│                                                             │
│ Exposes: Biome management + full spark system               │
└─────────────────────────────────────────────────────────────┘
```

**Pros:**
- ✅ Keeps Tool 1 unchanged (player familiarity)
- ✅ Gates organized by conceptual clarity
- ✅ "Quantum Lab" for advanced users
- ✅ Exposes semantic/topological prominently
- ✅ Quantum algorithms accessible
- ✅ Energy + biomes integrated naturally

**Cons:**
- ❌ Tool 3 may be intimidating (advanced physics)
- ❌ No state preparation exposed explicitly

---

## Feature Exposure Comparison

| Feature | Current | Scheme A | Scheme B | Scheme C |
|---------|---------|----------|----------|----------|
| **Basic Gates (X,Y,Z,H)** | Tool 5 | Tool 3 | Tool 2 | Tool 2 |
| **Phase Gates (S,T)** | Tool 5 | Tool 3 | Tool 2 | Tool 2 |
| **Two-Qubit Gates** | Tool 5 | Tool 3 | Tool 2 | Tool 2 |
| **Entangle (Bell)** | Tool 1 | Tool 5 | Tool 4 | Tool 5 |
| **GHZ/W/Cluster** | ❌ | Tool 5 | Tool 4 | Tool 5 |
| **Measurement** | Tool 2 | Tool 4 | Tool 3 | Tool 4 |
| **Peek (non-collapse)** | Tool 2 | Tool 4 | Tool 3 | Tool 4 |
| **Hamiltonian Evolution** | ❌ | Tool 3 | Tool 2 | Tool 3 |
| **Lindblad Operators** | Tool 4 | Tool 4 | Tool 2 | Tool 3 |
| **Pump/Reset** | Tool 4 | Tool 2 | Tool 2 | Tool 3 |
| **Energy Tap** | Tool 4 | ❌ | Tool 5 | Tool 6 |
| **Spark Extraction** | ❌ | ❌ | Tool 5 | Tool 6 |
| **Semantic Octants** | ❌ | Tool 6 | Tool 6 | Tool 5 |
| **Attractor Analysis** | ❌ | Tool 6 | Tool 6 | Tool 5 |
| **Topological Patterns** | ❌ | Tool 5 | Tool 4 | Tool 5 |
| **Quantum Algorithms** | ❌ | Tool 6 | ❌ | Tool 4 |
| **State Properties** | ❌ | Tool 6 | Tool 3 | Tool 4 |
| **Integrator Selection** | ❌ | Tool 3 | ❌ | Tool 3 |
| **Biome Assignment** | Tool 6 | ❌ | Tool 6 | Tool 6 |

---

## Decision Matrix

### Choose **Scheme A** if:
- Target audience: Physics students, researchers, quantum enthusiasts
- Priority: Educational rigor over accessibility
- Willing to retrain existing players
- Want to expose maximum quantum infrastructure

### Choose **Scheme B** if:
- Target audience: General gamers
- Priority: Minimal disruption, player retention
- Want gameplay-focused language
- Okay with losing some quantum rigor

### Choose **Scheme C** if: ⭐ **RECOMMENDED**
- Target audience: Mixed (casual + enthusiasts)
- Priority: Balance between rigor and accessibility
- Want to expose semantic/topological features prominently
- Want quantum algorithms accessible
- Best overall compromise

---

## Implementation Roadmap (for chosen scheme)

### Phase 1: Update Tool Definitions (2-3 hours)
- Modify `Core/GameState/ToolConfig.gd`
- Update `TOOL_ACTIONS` dictionary
- Add new submenu definitions

### Phase 2: Update Action Routing (3-4 hours)
- Modify `UI/FarmInputHandler.gd`
- Route Q/E/R actions to correct handlers
- Add handlers for new features

### Phase 3: Create UI Panels (4-6 hours)
- Semantic octant indicator panel
- Attractor personality panel
- State properties inspector
- Quantum algorithm runner UI

### Phase 4: Test All Flows (2-3 hours)
- Test each tool's Q/E/R actions
- Test all submenus
- Verify new features work

### Phase 5: Documentation (1-2 hours)
- Update TOOLS_INTERFACES_CATALOGUE.md
- Create player migration guide
- Update in-game help text

**Total Estimate:** 12-18 hours

---

## Recommendation Summary

**Recommended:** **Scheme C (Hybrid Physics + Gameplay)**

**Rationale:**
1. Preserves Tool 1 (80% of gameplay, player familiarity)
2. Organizes quantum operations by clear conceptual boundaries
3. Exposes advanced features (semantic octants, attractors, algorithms)
4. Integrates energy system naturally with biomes
5. "Quantum Lab" tool provides growth path for advanced players
6. Best balance of accessibility + depth

**Next Steps:**
1. Get user confirmation on Scheme C (or alternative)
2. Begin Phase 1 implementation
3. Create migration plan for existing saves/players
