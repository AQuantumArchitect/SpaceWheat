# Design Decisions Needed - External Advisement Request

## Summary

Testing of all 6 tools reveals that 4 tools have complete UI but incomplete backend implementations. Before backend development can proceed, architectural decisions are needed.

**Tools Needing Design Input**:
1. **Tool 3 (Industry)** - Building placement system
2. **Tool 2 (Quantum)** - Gate persistence & measurement triggers
3. **Tool 5 (Gates)** - Quantum gate application mechanics
4. **Tool 6 (Biome)** - Plot reassignment rules

**Status**:
- ✅ Tool 1 (Grower): Fully implemented
- ✅ Tool 4 (Biome Control): 90% complete, minimal decisions needed
- ⚠️ Tools 2, 5, 6: UI complete, backend pending design
- ❌ Tool 3: UI stub only, needs full design

---

## Quick Decision Matrix

| Tool | Question | Impact | Options |
|------|----------|--------|---------|
| **3** | Building locations? | UI layout, gameplay space | Grid overlay / Floating UI / Scene nodes |
| **3** | Building effects? | Economy, quantum evolution | Cost multipliers / Emoji generation / Rate boost |
| **2** | Gates persist after harvest? | Game complexity, strategy | Yes / No / Optional |
| **2** | Measurement triggers? | Automation, player control | Auto at maturity / Manual toggle / Threshold-based |
| **5** | Gate restrictions? | Difficulty, strategy | None / No gates on measured / No stacked gates |
| **6** | Plots switch biomes? | Flexibility, economy | Yes (free) / Yes (cost) / No |
| **6** | Reassignment resets state? | Quantum mechanics consistency | Yes / No / Partial reset |

---

## Detailed Questions by Tool

See individual files:
- `TOOL_3_INDUSTRY.md` - Building system design
- `TOOL_2_QUANTUM.md` - Gate infrastructure questions
- `TOOL_5_GATES.md` - Quantum operations questions
- `TOOL_6_BIOME.md` - Reassignment mechanics

---

## Next Steps After Advisement

1. **Receive external guidance** on design decisions
2. **Claude (local)** implements based on approved designs
3. **Testing bots** validate implementations
4. **Integration testing** ensures no regressions
5. **Deployment** when all tools working

---

## Current System State for Context

### What's Working ✅

**Tool 1 (Grower)**:
- Plant crops (wheat, mushroom, tomato)
- Entangle adjacent plots (Bell φ+ states)
- Measure plots (convert to measured state)
- Harvest plots (quantum yield calculation)

**Tool 4 (Biome Control)**:
- Energy tap system (UI dynamically generates from vocabulary)
- Pump/Reset submenu (handlers already coded)
- Decoherence tuning (partially implemented)

### What's Ready for Backend ⚠️

**Tool 2 (Quantum)**:
- UI for gate building exists
- Gate types defined (Bell, clusters)
- Measurement trigger UI present
- Batch measure UI ready
- Missing: Gate construction logic, trigger mechanism

**Tool 5 (Gates)**:
- Gate selection UI complete
- Gate options defined (Pauli-X/Z, Hadamard, CNOT, CZ, SWAP)
- Action handlers exist but stubbed
- Missing: Unitary matrix operations, gate application logic

**Tool 6 (Biome)**:
- Biome assignment UI dynamic (generates from 4 biomes)
- Biome list: BioticFlux, Market, Forest, Kitchen
- Clear assignment UI present
- Plot inspection UI skeleton exists
- Missing: Reassignment backend, plot state handling

### What Needs Full Design ❌

**Tool 3 (Industry)**:
- UI submenu exists (Mill, Market, Kitchen options)
- Action handlers stubbed
- Missing: Building placement system, cost model, effects model
- Needs: Complete architectural design before coding

---

## Quantum-Rigorous Interface Alignment

Current implementation partially follows the Phase 1-4 plan from the Manifest:
- **Phase 1 (Core Plumbing)**: ✅ 80% - Block embedding working, mode system in place
- **Phase 2 (Energy Taps)**: ✅ 60% - UI ready, drain operators pending
- **Phase 3 (Measurement)**: ⚠️ 40% - Soft measurement working, POSTSELECT_COSTED partial
- **Phase 4 (Pump/Reset)**: ✅ 70% - Handlers coded, integration pending

See `../MANIFEST_ALIGNMENT/` for detailed phase breakdown.

---

## Questions for External Advisors

1. **Design coherence**: Do the proposed designs for Tools 2, 3, 5, 6 align with overall game vision?
2. **Phase alignment**: Should we prioritize phase completion vs. tool completion?
3. **Scope**: Should all 6 tools be fully functional before v1.0 release, or is a subset acceptable?
4. **Complexity**: Are there any proposed designs that are overengineered or undersupported?

---

## File Contents

This folder contains:
- `OVERVIEW.md` - This file
- `TOOL_3_INDUSTRY.md` - 5 design questions for building system
- `TOOL_2_QUANTUM.md` - 4 design questions for gate infrastructure
- `TOOL_5_GATES.md` - 3 design questions for gate operations
- `TOOL_6_BIOME.md` - 3 design questions for reassignment
- `DECISION_MATRIX.md` - Comparison table of all options

