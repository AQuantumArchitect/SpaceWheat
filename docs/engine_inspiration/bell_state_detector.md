# Bell State Detector

**Source file:** `Core/QuantumSubstrate/BellStateDetector.gd` (archived — safe to delete)

## The idea
Three adjacent farm plots can form a quantum entanglement topology based purely on their spatial arrangement. Line → GHZ; L-shape → W state; T-shape → cluster state. The *layout of plots IS the quantum gate*, with no additional player configuration needed.

## What's interesting
The mapping of entanglement class to grid geometry is elegant and fully deterministic:
- **GHZ (line):** all-or-nothing correlation — all three plots measure the same outcome. Strong synchronized production bursts.
- **W state (L-shape):** exactly one plot is "different." Robust against loss — destroying one plot doesn't collapse the others. Good for resilient farm layouts.
- **Cluster state (T-shape):** one-way computation ready; designed for measurement-based gates. The perpendicular arm acts as an ancilla.

Each state has distinct strategic implications without any extra player input beyond tile placement — spatial arrangement IS the choice.

## Implementation notes
- Detection is a pure geometry calculation on `Vector2i` positions, no quantum math involved. Cheap to run every time plots are placed or moved.
- `state_strength` is always exactly 0.0 or 1.0 (binary match). A graduated version (allowing gaps, diagonal stretches, or near-miss arrangements) would give softer discovery curves.
- The L-shape checker iterates all 6 permutations of 3 points; T-shape checks all 3 center candidates. Both are O(1) for 3 plots.
- Currently no connection to the actual Hamiltonian; this was a classifier stub, not an actor.

## Connections
- **BiomeBase quantum state** — GHZ/W/Cluster bonuses could appear as temporary Hamiltonian coupling modifiers when the plot triplet is detected.
- **BellStateDetector + ENTANGLEMENT_STRATEGIES.md** — the existing inspiration doc describes Bell-pair playstyles; this class is the missing recognition layer that could fire those bonuses automatically.
- **BiomeDensityMatrixMutator** — a natural place to apply state-specific decoherence rates (W state more robust; GHZ fragile).
