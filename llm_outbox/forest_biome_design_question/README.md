# Forest Biome Design Question - Documentation Package

## Overview
This package contains comprehensive documentation for an external design review of the SpaceWheat Forest Biome quantum representation.

## Problem Statement
The Forest biome currently spawns individual organism instances (leading to 100+ mice), but we need a **conceptual/platonic** representation where ONE qubit per organism type encodes population dynamics.

## Contents

### Documentation Files
1. **01_system_architecture.md** - Core system architecture
   - DualEmojiQubit fundamentals
   - Bloch sphere physics
   - Three-layer evolution (Hamiltonian, Lindblad, Measurement)
   - Skating rink visualization

2. **02_biotic_flux_example.md** - Working reference implementation
   - How BioticFlux successfully uses quantum mechanics
   - Celestial cycling, crop growth, spring forces
   - Clear separation of concerns
   - Why this pattern works

3. **03_current_forest_implementation.md** - Current problematic approach
   - QuantumOrganism class (agent-based)
   - Reproduction logic causing population explosion
   - Why individual instances don't scale
   - Comparison to BioticFlux

4. **04_observed_problem.md** - What we see in practice
   - Test logs showing 100+ organism spawns
   - Agentic vs conceptual simulation
   - Platonic projection concept
   - Visualization clutter

5. **05_design_question.md** - Open design questions
   - What should theta/phi/radius represent for populations?
   - How to encode predator-prey dynamics?
   - How to handle multi-species interactions?
   - How to visualize population dynamics?

### Code Files (for reference)
Located in repository at:
- `Core/Environment/BiomeBase.gd` - Abstract biome class
- `Core/Environment/BioticFluxBiome.gd` - Working example (1258 lines)
- `Core/Environment/ForestEcosystem_Biome.gd` - Current forest implementation
- `Core/Environment/QuantumOrganism.gd` - Agent-based organism class
- `Core/QuantumSubstrate/DualEmojiQubit.gd` - Quantum state representation
- `Core/Visualization/QuantumForceGraph.gd` - Visualization system
- `Tests/QuantumForceGraphTest.gd` - Multi-biome test scene

### Test Logs
- `test_out.log` - Working tri-biome visualization output
- `forest_test2.log` - Forest organism spawn explosion (the problem)

## How to Use This Package

1. **Start with 01_system_architecture.md** to understand the quantum framework
2. **Read 02_biotic_flux_example.md** to see a working pattern
3. **Review 03_current_forest_implementation.md** to understand what's not working
4. **Study 04_observed_problem.md** for concrete evidence of the issue
5. **Engage with 05_design_question.md** for open exploration

## What We're Asking

**NOT:**
- Debugging help
- Code review
- Implementation details

**YES:**
- Design exploration
- Conceptual mapping ideas
- Alternative interpretations of theta/phi/radius for populations
- Analogies from other quantum/population systems
- Trade-off analysis

## Core Question

> How do we design a quantum representation where ONE qubit per organism type encodes population dynamics, using only (theta, phi, radius) and the three-layer evolution architecture (Hamiltonian, Lindblad, Measurement)?

## Constraints

**Must preserve:**
- Bloch sphere representation
- Three-layer architecture
- Skating rink visualization
- Emoji-based semantics
- Food web topology

**Must avoid:**
- Spawning individual agents
- Classical population tracking
- Breaking quantum formalism

## Contact Context

This is for **external design review**. The documentation is intentionally descriptive and open-ended to enable fresh perspectives on the problem.

Thank you for considering this design challenge!
