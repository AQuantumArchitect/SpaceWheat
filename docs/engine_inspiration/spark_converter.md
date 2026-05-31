# Spark Converter (Coherence-to-Population Trade)

**Source file:** `Core/QuantumSubstrate/SparkConverter.gd` (archived — safe to delete)

## The idea
A player-triggered mechanic: spend quantum coherence (off-diagonal density matrix elements) to boost a specific resource's population (diagonal elements). Coherence represents "quantum potential" — flexibility and future optionality — which you irreversibly trade away for an immediate observable gain. Higher coherence → more extractable energy; extraction causes dephasing.

## What's interesting
- **Coherence as currency** — the off-diagonal magnitude (`energy.imaginary`) is a real quantity in the density matrix that is otherwise invisible to the player. Sparks make it legible and spendable. This is a clean physics-grounded mechanic with no fictional hand-waving.
- **Three-regime readout** — `get_energy_status()` classifies the biome as `high_coherence`, `balanced`, or `mostly_classical` based on `coherence_ratio`. Players learn to read the regime before deciding whether to spark.
- **Asymmetric trade** — extraction efficiency is 0.8 (20% of coherence is "lost" converting). Decoherence strength is 2× the extraction fraction — so extracting 10% dephases as if 20% decayed. The trade is deliberately unfavourable at high fractions, discouraging full extraction.
- The trace collapse recovery (`if abs(trace) < 1e-10`) initializes to maximally mixed state rather than erroring. Graceful degradation.

## Implementation notes
- `extract_spark(qc, target_emoji, fraction)` modifies the density matrix in-place — no duplicate/restore. The caller must checkpoint state before calling if rollback is needed.
- Population injection distributes evenly across all basis states where the target qubit is in the target pole. For a 4-qubit system with one target qubit, this is 8 states — equal injection into each.
- `compute_energy_split()` is called on `density_matrix` directly; this method must exist on DensityMatrix (check before reinstating).
- Renormalization at the end (`_renormalize_density_matrix`) corrects for any floating-point trace drift introduced by the dephasing + injection. This is safe but means the final state is not exactly what the Lindblad propagator would produce.
- The `regime` string is used for colour coding (`get_regime_color`); a biome HUD showing the regime live would be low-cost and high-readability.

## Connections
- **QuantumInstrument action dispatch** — Sparks are a live action type alongside probe, drain, and measure; the frame-hat is Spark.
- **ProbeActions** — existing action dispatch; Spark extraction is a natural sibling action.
- **BiomeBase quantum state / QuantumComputer** — `extract_spark` needs `qc.density_matrix`, `qc.register_map`, and `qc.get_population`. All already on QuantumComputer.
- **Story flags** — a `first_spark` flag could fire a narrative beat explaining the coherence/population tradeoff as in-world lore.
- **SparkConverter + ENTANGLEMENT_STRATEGIES.md** — entangled plots would have shared coherence; sparking one could partially dephase the other (cross-plot decoherence event).
