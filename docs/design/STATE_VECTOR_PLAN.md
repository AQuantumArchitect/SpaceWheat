# Scoping: state-vector representation for the closed (coherent) system

## Why

In the closed system ρ is **always a rank-1 projector** `|ψ⟩⟨ψ|` — the exact unitary kernel
guarantees it. Carrying the full `2ⁿ × 2ⁿ` density matrix to represent a state that lives
in a `2ⁿ` subspace is redundant open-system machinery. The research-grade closed kernel's
natural object is the **state vector `|ψ⟩`**:

- **r = 1 becomes unrepresentable-otherwise**, not maintained. There is no purity to drift
  or to restore — `‖ψ‖ = 1` is the only invariant, and it's a single normalization.
- **Cheaper:** evolution is `|ψ⟩ ← U|ψ⟩` — `O(d²)` per step and `O(d²)` storage, versus
  `ρ ← UρU†` at `O(d³)`/`O(d²·²)`... (two `d×d` mults) and `O(d²)` storage.
- **Honest:** the formulation matches the physics — a closed system is a ray in Hilbert
  space, full stop.

This is the deepest "less videogame, more research-grade visualizer" cleanup. It is also
the **highest blast radius**, because the entire readout/visualization layer currently
consumes ρ. Hence: scoped here, not yet implemented.

## The hard constraint: the switch must survive

The two-generator isolation (`coherent_dynamics` ⊥ `dissipative_dynamics`) is non-negotiable.
A state vector **cannot** represent a mixed state, so it is valid **only** in pure-coherent
mode. The moment dissipation is on (open DLC, or pure-Lindbladian), the state is generally
mixed and **must** be a density matrix. So the representation itself becomes mode-dependent:

| mode | state object |
|---|---|
| pure-coherent (closed, default) | `|ψ⟩` state vector |
| any dissipative mode (DLC / pure-L) | `ρ` density matrix (today's path) |

The design must let you flip the dissipative switch and have the engine **promote** `|ψ⟩ → ρ = |ψ⟩⟨ψ|`
(and, going the other way, only when re-entering pure-coherent from a pure state). This is
the same "throw a switch" discipline, now at the representation layer.

## Recommended architecture: a `QuantumState` seam

Don't scatter `if state_vector`/`if density_matrix` across the codebase. Introduce one
abstraction that both representations implement, and make every reader go through it.

```
QuantumState (interface)
  ├─ PureState   : holds ψ (PackedVector of 2ⁿ amplitudes); evolution U|ψ⟩
  └─ MixedState  : holds ρ (today's ComplexMatrix);          evolution UρU† + dissipators
  shared read API (the ONLY thing visualizers may call):
    get_marginal(qubit, pole)        density_matrix()  → ρ (PureState builds |ψ⟩⟨ψ| on demand)
    get_population(emoji)            reduced_density(qubits)  (partial trace, for entanglement/MI)
    get_purity()  (PureState ≡ 1)    get_entropy()  (diagonal Shannon — same as today)
    project(qubit, pole)             born_sample(...)
```

- **`density_matrix()` is the compatibility bridge:** `PureState.density_matrix()` returns
  `|ψ⟩⟨ψ|`, so every existing ρ-reader (Bloch viz, market pricing, attractor, inspector)
  keeps working unchanged during migration. Optimize hot readers to read ψ directly later.
- **`QuantumComputer` owns a `QuantumState`** instead of a bare `density_matrix`. Its
  `initialize_*`, `evolve`, `project_qubit`, `get_*` delegate. The two-generator switch
  chooses which concrete state to instantiate at build/realize time.
- **Entanglement / MI** (the one place a pure global state still needs matrices): compute
  the **reduced** density matrix of the relevant qubits by partial trace of `|ψ⟩⟨ψ|`.
  Cheap for few-qubit marginals; this is standard and keeps the visualizer correct.

## Migration stages (each independently shippable + verifiable)

1. **Define the seam.** Add `QuantumState` interface + `MixedState` wrapper around today's
   `density_matrix` (pure refactor, zero behavior change). Route `QuantumComputer` reads
   through it. Verify: full suite + rig identical to now.
2. **Add `PureState`.** Implement ψ storage, `U|ψ⟩` evolution, `project`, Born sample,
   `density_matrix()` = outer product, `reduced_density()` = partial trace. Unit-test
   against `MixedState` for identical observables on pure inputs.
3. **Switch wiring.** In pure-coherent mode, `QuantumComputer` instantiates `PureState`;
   otherwise `MixedState`. Promotion `|ψ⟩ → ρ` when the dissipative switch flips on.
   Verify the four quadrants (the existing `closed_quadrants.py`) still hold, plus a new
   check: pure-coherent now reports `get_purity() == 1.0` bit-exactly (no eigen-projection
   init needed — ψ is born normalized).
4. **Optimize hot readers** (optional, later) to consume ψ directly instead of materializing
   ρ — Bloch vectors, marginals, populations. Pure perf; guarded by the seam.
5. **Retire the closed-mode ρ scaffolding** that becomes dead: `_collapse_to_dominant_eigenstate`,
   `_init_pure_ground_state` (PureState inits to the H ground eigenvector directly), the
   unitary-cache `UρU†` path (becomes `U|ψ⟩`). The `expm` propagator U is still built the
   same way; only its application changes.

## What this is NOT

- Not a change to the **open** path. `MixedState` is exactly today's ρ engine — the DLC and
  pure-Lindbladian modes are untouched. "Get clean, not changed."
- Not a physics change. Same H, same propagator, same observables — only the storage of a
  pure state becomes honest.

## Cost / risk

- **Reward:** exact r=1 by representation, ~d× less memory + a faster hot path, and a kernel
  that reads like the textbook. Strong for a publishable "Godot-4 quantum visualizer."
- **Risk:** the seam touches every ρ reader. Mitigated by stage 1 (introduce the seam with
  zero behavior change) and `density_matrix()` keeping all readers working until each is
  migrated. The partial-trace for entanglement is the only genuinely new math.
- **Effort:** stage 1–3 are the real work (the seam + PureState + switch). 4–5 are cleanup.

## Decision needed from you

Proceed to stage 1 (define the seam — safe, zero-behavior-change refactor) now, or hold the
whole state-vector move until after the open-mode "turn H off, run pure Lindbladian" pass is
exercised more? The seam (stage 1) is valuable regardless — it's where the representation
switch will live.
