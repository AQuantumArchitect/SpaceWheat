# Closed Quantum System

SpaceWheat runs as a **closed** quantum system: every biome's density matrix ρ evolves by
**unitary von-Neumann dynamics only** — `dρ/dt = −i[H,ρ]` — with **no Lindblad
dissipators** (no pump, drain, or decay). Every bubble therefore stays **pure** forever:
**r = 1**, i.e. `Tr(ρ²) = 1`.

The earlier **open** system (Lindbladian pump/drain/decay, mixed states, entropy
extraction) is preserved behind a single flag as the future **open-quantum DLC**.

## The one switch

`BalanceConfig.physics.system_mode` — `"closed"` (default) | `"open"`.
Read it via `BalanceConfig.is_closed_system(config := {})` (honours
`DEFAULTS < _physics_override < explicit config`). Flipping to `"open"` re-enables the
entire Lindbladian path — that flag *is* the DLC scaffold. Nothing is deleted; the open
machinery and the `biomes.json` Lindblad authoring are **dormant**, not gone.

## What changes in closed mode

| Concern | Open (DLC) | Closed (default) |
|---|---|---|
| Evolution | `−i[H,ρ] + Σ Lₖ·` | `−i[H,ρ]` only (purity conserved) |
| Lindblad operators | built from `atom_components` | **none built** (`LindbladBuilder` returns `[]`) |
| Measure / pop | weak ensemble drain (η) | **full projective collapse** (`project_qubit`) |
| Reap | sink flux + entropy-bank `kT·ΔS` (drain) | **seasonal mass-measurement**: Born-sample + collapse every register, surprisal payout |
| Contract exercise | `apply_atomic_drain` | **projective collapse** |
| Regeneration | external pump refills population | **the Hamiltonian** re-spreads a collapsed qubit (time + H *is* the pump) |
| Spark / Merchant hats | live drive/drain/pump | **disabled** (greyed out; actions inert) |
| Pricing | `−kT·log p`, kT from diagonal entropy | **unchanged** — a pure superposition still has nonzero diagonal entropy |

## Why it's a gate, not a rewrite

1. **Keep ρ; skip the L term.** Building zero Lindblad operators leaves `_evolve_step`'s
   dissipator loop iterating an empty array, so only the unitary term runs and purity is
   conserved by theorem. Gating at the single build site
   (`LindbladBuilder.build_from_atoms`) also starves the C++ engine
   (`BiomeEvolutionBatcher.register_biome` feeds triplets from `qc.lindblad_operators`),
   so **no native recompile** is needed.
2. **The Hamiltonian is the regeneration mechanism.** After a collapse the qubit is a
   definite basis state; rabi + cross couplings rotate it back into superposition over the
   following ticks. `hamiltonian_coupling_scale` is the master **regrowth / edge-of-chaos**
   dial (tune it in the rig `reservoir_sweep`, now a 1D H-scan in closed mode).
3. **Measurement is the only irreversible act** — "measurement IS the economy."

## Canonical data

`biomes.json` (`atom_components`: `decay` / `lindblad_outgoing` / `lindblad_incoming` /
`gated_lindblad_source` / `cross_biome_flows`) and `icons.json` are **untouched**. The
Lindblad authoring is dormant DLC content; `icons.json` already owns the Hamiltonian that
drives closed-system play.

## Verification

- The gate lives at `LindbladBuilder.build_from_atoms` (closed → 0 operators, open →
  rebuilt from the same data); `tests/test_drain_qubit.gd` covers the weak-measurement
  drain invariants on the open path. (A dedicated headless gate test is still to be
  written — the old `Tests/test_closed_system.gd` no longer exists.)
- Live purity/regeneration must be checked in the rig (`./🍄/🎛️/🟢.sh`): the native
  Eigen matrix backend only syncs ρ under a full game boot, so numeric evolution isn't
  drivable from an isolated `--script`. Pop an axis → one surprisal-priced resource; the
  qubit pins then re-spreads under H; purity holds at 1.

See memory `project_closed_system_migration.md` for the per-stage change log.

Design notes for the eventual open-system return (Act 2) — including the post-mortem of
why the first H+L attempt failed and the role-separation law that prevents a repeat —
live in [docs/inspiration/OPEN_SYSTEM_ACT2.md](inspiration/OPEN_SYSTEM_ACT2.md).
