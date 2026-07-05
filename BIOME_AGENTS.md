# Biome-Crafting Agent Guide — SpaceWheat

This file is for agents working **specifically on the biome/faction physics
layer** — mutating biome Lindbladians, tuning factions, running the assay
toolkit. It is NOT a general onboarding guide for the Godot game, rendering,
UI, or game logic. If you are working on anything outside `Core/Biomes/`,
`Core/Factions/`, or `tools/`, stop here — you want a different doc.

> 🍄 **Playing the game as an agent?** You want `🍄/README.txt` and
> `🍄/🗺️_ARCHITECTURE.md` instead — that's the milk-hunt rig, arena system,
> and full data-flow map for LLM agents that play SpaceWheat headlessly.

Scope:
- ✅ Read and mutate `Core/Biomes/data/biomes.json`
- ✅ Read and add to `Core/Factions/data/factions.json`
- ✅ Run and add scripts under `tools/`
- ❌ Don't touch `.gd` / `.tscn` / Godot scene assets
- ❌ Don't touch `Core/Boot/`, `Core/Audio/`, `Core/Diagnostics/`, or any
  subsystem that isn't Biomes or Factions
- ❌ Don't modify the bundled cache or its builder

> **v0 seal note (2026-07):** the shipped game runs CLOSED — `LindbladBuilder`
> builds zero operators, so the `atom_components` Lindblad authoring in this
> guide (webway / decay / pumps) is dormant data at runtime until the open
> expansion. Author it anyway: Act 2 inherits everything, and headless tooling
> can exercise it via `BalanceConfig.set_physics_override({"dissipative_dynamics": true})`.
> See `docs/CLOSED_SYSTEM.md` and `docs/glossary/webway.md`.

---

## Player faction
The player IS the faction "The Demos" (biome `TheDemos`). See `🍄/PLAYER_FACTION.md` for
identity, physics, and authoring rules.

---

## What this project is

SpaceWheat is a Godot game whose world is a **quantum-Hamiltonian garden**.
Each biome is a small open-system quantum simulator. Players interact with
biomes whose steady-state populations encode real physics: dark states,
topological edges, Zeno latches, chiral clocks, laser gain, bistable phases,
limit cycles, gradient memories, etc. The game is designed so that **gameplay
hooks live in the physics, not on top of it** — if you want a biome that
"remembers" or "oscillates" or "needs to be kindled", you build that into the
Lindbladian and the physics takes care of the rest.

---

## Vocabulary: atoms vs. pair-icons

Two layers, different jobs:

- **Atoms** (single emojis like `⚱`, `🪔`, `💀`) are the *physics* primitives:
  basis states the simulator integrates. They are the keys of every H, L,
  `self_energies`, `atom_components`, faction `sig`, biome `emojis`. ~227 unique.
- **Pair-icons** (`{name, pole_0, pole_1}` like `{Combat, ⚔, ⚱}`) are the
  *named* two-state axes the player ever sees by name. They are owned by
  **factions** (`icons[]`), registered in `IconLexicon`. ~166 pairs / ~160
  names. **Biomes do NOT own icons** — a biome is a cloud of atoms + Lindblad L.
  The icons a biome hosts are *inferred from its `native_factions`* at
  neighborhood-realization time (`Biome.get_neighborhood_icons()`); pole-pairing
  is a neighborhood concern, never a biome property.

The word "icon" is reserved for pair-icons. The single-emoji-keyed Lindblad
spec on each biome is `atom_components` (formerly `icon_components`).
Player-facing vocab discovery flows through pair-icons via
`IconLexicon.is_pair_discovered(p0, p1, discovered_set)` —
`VocabularyEvolution.discovered_vocabulary` is the source of truth for which
pairs the player has seen.

---

## The two data files that matter

Everything interesting lives in:

```
Core/Factions/data/factions.json   — 95+ factions.
Core/Biomes/data/biomes.json       — 60+ biomes.
```

### Factions contribute the Hamiltonian

Each faction has:

```json
{
  "name": "Lamplighters",
  "sig": ["🌉", "🪔", "📯", "🗼", "🏁"],
  "self_energies": {"🌉": 0.0, "🪔": 0.0, ...},
  "hamiltonian": {
    "🌉": {"🪔": 0.3},
    "🪔": {"🌉": 0.3, "📯": 0.8},
    ...
  },
  "bits": [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1]
}
```

- `sig`: which emojis this faction "speaks"
- `self_energies`: diagonal H terms
- `hamiltonian`: off-diagonal terms. Scalar = real. `[re, im]` = complex
  coupling (chiral / imaginary H). Must be Hermitian: `H[a][b] = H[b][a]*`
  (imag parts flip sign on swap).
- `bits`: 12-axis alignment vector (see `Core/Factions/FactionAxes.gd`).

**Frobenius normalization** — the runtime divides each faction's H by its
Frobenius norm before adding it to a biome. This keeps strong factions from
dominating. **Tooling consequence:** in `tools/biome_audit.py`'s
`compute_faction_baselines`, the returned coupling dict has each Hermitian
edge summed from BOTH iteration directions — so it's 2× the actual matrix
element. Halve it when building Hilbert-space H. See
`tools/zeno_assay.py:build_H` for the correct pattern.

### Biomes contribute the Lindbladian

Each biome has:

```json
{
  "name": "ShrineOfAshes",
  "emojis": ["⚱", "🕯", "📿", "💀"],
  "native_factions": ["Memory Merchants", "..."],
  "atom_components": {
    "💀": {
      "lindblad_incoming": {"🗑": 2.5},
      "gated_lindblad_source": [
        {"target": "⚱", "gate": "⚱", "rate": 25.0, "power": 2}
      ]
    },
    "⚱": {"decay": {"rate": 0.3, "target": "🗑"}}
  }
}
```

Lindblad operator types (on each emoji). Two ecological readings of these edges:
**sink-decay** (target/source is the sink `🗑` — population leaves the biome,
lowering entropy) vs the **webway** (non-sink inter-atom edges — population
recirculates across the atom cloud, holding entropy up). See
`docs/glossary/webway.md`.
- `decay: {rate, target}` — `√rate · |target⟩⟨emoji|`. Target `🗑` = sink-decay;
  target = another in-cloud atom = a webway edge.
- `lindblad_outgoing: {target: rate}` — same, multiple targets (webway when non-sink).
- `lindblad_incoming: {source: rate}` — `√rate · |emoji⟩⟨source|`. Source `🗑` =
  external **pump** (the only edge that raises population from outside); other
  source = a webway edge. A biome with no pump and a net-draining webway → `S → 0`.
- `gated_lindblad_source: [{target, gate, rate, power, inverse}]` —
  rate-modulated jump from `emoji` to `target`, where effective rate = `rate · ρ_gate^power`. This is the **nonlinearity** that makes bistability, tristability, oscillators, and gradient memories possible.

**Variation selectors matter.** `biome_audit.strip_fe0f` removes `️` from the biome's `emojis` list on load, but NOT from inner dict keys/values. If you write `❄️` in `atom_components` it won't match the stripped `❄` — so always use bare codepoints (`❄`, `⚙`, etc.) for emoji keys inside Lindblad specs.

---

## The assay toolkit (`tools/`)

Each assay has a **physics-first header comment** — read those to learn the
circuit before tweaking. Running `python3 tools/<assay>.py --help` lists the
CLI flags.

| Script | Measures | Biome it demos |
|---|---|---|
| `tools/eit_assay.py` | Λ dark-state interference | NullingChamber |
| `tools/ssh_assay.py` | 1D-chain edge mode (chiral symmetry) | Lanternfall |
| `tools/zeno_assay.py` | Measurement-induced freezing | ZenoLatch, Clinic |
| `tools/clock_assay.py` | Persistent current in a chiral triangle | WheelOfHours |
| `tools/gain_assay.py` | Steady-state population inversion | LaserGlint |
| `tools/transition_assay.py` | Bistable phase (history-dependent steady state) | TwofacedTide, ShrineOfAshes, MnemonicHive |
| `tools/biome_audit.py` | Per-faction/per-emoji baselines, archetype census | (general-purpose helper) |

All six assays use the same data-loading helpers from `biome_audit.py`. If
you add a new assay, import its `load_factions`, `load_biomes`,
`compute_faction_baselines` rather than rolling your own — and remember the
Hermitian-edge double-count quirk (halve `cre`/`cim` before building H if
absolute magnitudes matter).

---

## How to mutate a biome

1. **Pick a biome.** Something that already has a "near-miss" score on one of
   the assays. Run `python3 tools/<assay>.py --top 10` to find candidates.
2. **Read its current `atom_components`.** Don't destroy the existing lore;
   add or tune, don't delete unless necessary.
3. **Edit `Core/Biomes/data/biomes.json`** (via a Python script — the file
   is large and editing by hand is error-prone). Surgical changes: raising a
   `decay.rate`, adding one `gated_lindblad_source`, adjusting a `power`.
4. **Re-run the relevant assay** to confirm the score moved in the right
   direction. If other assays regressed, check whether that matters.
5. **Commit with a message explaining what physics moved and why.**

### What works and what doesn't (observed empirically)

- **Simple biomes mutate cleanly; crufty ones resist.** Biomes with few
  `atom_components` tune well. Biomes with lots of pre-existing gated
  Lindblads (TidalPools, HorizonFracture, GildedRot) have tangled
  fixed-point landscapes where one-knob mutations get absorbed into noise.
  For those, either strip their gated structure first or leave them alone.
- **Self-gated Lindblads (target == gate == src) are pure dephasing**, not
  population transfer. If you want an autocatalytic pump feeding `X`, put
  the `gated_lindblad_source` on a DIFFERENT emoji (a reservoir) with
  `target: X, gate: X`. See TwofacedTide and MnemonicHive for the pattern.
- **Saturable external pumps couple all latches.** The master-equation
  integrator in `tools/transition_assay.py` uses `saturation = max(0, 1 - trace(ρ))`,
  which means a biome with two "independent" bistable latches will find their
  saturation budgets competing and they'll either flip together or only one
  will fire. Giving each latch's reservoir its own linear decay (so it can't
  accumulate up to saturation) is the workaround — see MnemonicHive.
- **Variation selectors silently break.** `❄️` vs `❄`, `⚙️` vs `⚙`.
  Use bare codepoints in Lindblad dict keys.

---

## Current circuit shelf

```
EIT dark-state detector      NullingChamber + 22 accidentals
SSH topological edge trap    Lanternfall
Zeno latch                   ZenoLatch, Clinic
Chiral clock / persistent I  WheelOfHours, TidalPools
Laser gain                   LaserGlint, DemolitionSite, others
Bistable phase               ShrineOfAshes (0.95), TwofacedTide (0.82), ColdLab (0.54)
Tristable                    Village (hot/cold/quiet)
Critical slowdown            BrittleDawn
2-bit memory imprint         MnemonicHive
Gradient memory (partial)    SporeLibrary (two mutually-exclusive thresholds)
Limit-cycle oscillator       MothGarden (rock-paper-scissors predator chain)
Self-erasing one-shot        OrbitalStrike (trigger depletes the carrier)
Serenity attractor           MeditationGarden (unique dominant steady state)
Null / vacuum attractor      FreshwaterSpring (drain-only)
Polyculture                  PastoralCommons (5-site stable ecosystem)
Seed-dependent multi-atom    Village (again — 10+ distinct asymptotic states)
```

---

## Where physics actually lives (parallel authorities)

The runtime carries multiple computation paths. When debugging or extending,
know which one you're touching.

**Canonical authorities (build-time write, run-time read):**
- **Hamiltonian** — `icons.json` via `IconRegistry.get_icon_physics_by_pair`,
  composed by `HamiltonianBuilder.build_from_icons`. Lives on
  `quantum_computer.hamiltonian`.
- **Lindblad / decay** — `biome.atom_components` (in biomes.json), composed
  by `LindbladBuilder.build_from_atoms`. Lives on
  `quantum_computer.lindblad_operators`.

**Live-evolution authorities (every tick):**
- `QuantumComputer.evolve(dt)` — canonical Lindblad master equation integrator
  (GDScript). Reads H + L from above.
- **`MultiBiomeLookaheadEngine` (C++)** — *silent twin*. Holds its OWN copy of
  H + L, registered via `BiomeEvolutionBatcher._register_biome_with_engine`.
  Computes 13-step lookahead in the background; results are played back into
  `density_matrix` by `BiomeEvolutionBatcher._apply_buffered_step`. **For
  batched biomes (the default) this is the production tick path** — GDScript
  `evolve()` is bypassed. Any in-place mutation of H or L MUST call
  `BiomeEvolutionBatcher.mark_for_reregister(name)` or the C++ engine replays
  stale physics. (Dim changes auto-detect; same-dim H mutations don't.)
- `FactionDensityMatrix` (`QuantumMythosEngine` C++) — separate 12-qubit
  emoji-basis engine. Independent H + L. Drives factions / market lattice /
  story flags. **Read-only from biomes** — does not write back.

**Discrete event mutators (intentional, scoped):**
- Gates (`apply_gate`, `apply_gate_2q`)
- Measurement / collapse / drain (`_project_qubit`, `drain_qubit`,
  `BiomeDensityMatrixMutator.collapse_register`,
  `ProbeActions._drain_register`)
- Boot/load: `initialize_*`, `GameStateSerializer` density hydration

**Mirror caches (UI may read these, NOT the live QC):**
- `viz_cache` (per biome) — populated by lookahead snapshots
- Bloch / MI / purity buffers in `BiomeLookaheadBuffer`
- `force_graph_engine.cpp` particle layout (visual layout only)

**Authority discipline for biome-crafters:**
- Never edit `faction.hamiltonian` / `faction.self_energies` expecting biome
  H to change. Those feed `FactionDensityMatrix` only.
- Edit icons.json to change H. Edit `biome.atom_components` to change L.
- After any in-place H mutation (e.g. `inject_coupling`), confirm
  `BiomeEvolutionBatcher.mark_for_reregister` is called — otherwise the C++
  twin will keep emitting old physics.

---

## Open to-dos

- **Genuine time-crystal / clean limit-cycle demo** — MothGarden works but
  amplitude is small. A tighter predator-prey or delay-feedback architecture
  could improve it.
- **Multi-level gradient memory** — SporeLibrary shows 2-level "mutually
  exclusive" behavior. True gradient would need three or more co-active
  independent latches, which probably requires a saturation-cap rework in
  `tools/transition_assay.py`.
- **Dissipative state preparation** — engineer a biome whose unique steady
  state is a specific coherent superposition (Bell pair etc).
- **Coupled biomes** — not yet attempted.

---

## Files a biome-crafting bot actually needs

**Required (read + write):**
- `Core/Biomes/data/biomes.json` — all biomes
- `Core/Factions/data/factions.json` — all factions

**Required (read + execute):**
- `tools/biome_audit.py` — data-loading + Frobenius + archetype helpers
- `tools/eit_assay.py`, `tools/ssh_assay.py`, `tools/zeno_assay.py`,
  `tools/clock_assay.py`, `tools/gain_assay.py`, `tools/transition_assay.py`
  — the six assays
- `tools/emoji_graph.py` — if it exists / whatever other supporting scripts

**Read-only references:**
- `BIOME_AGENTS.md` (this file)
- `Core/Factions/FactionAxes.gd` — the 12-axis `bits` taxonomy (read to
  choose reasonable `bits` vectors for new factions)

**Also safe to read but not required:**
- `Core/Biomes/BiomeBuilder.gd` and `Core/Factions/IconBuilder.gd` — the
  runtime consumers. Read if a mutation behaves unexpectedly and you suspect
  a runtime convention you don't know about.
- `README.md` at repo root (if present).

**Emoji SVG sync:** when adding new emojis to `biomes.json` or `factions.json`, run `python3 🍄/🛠️/sync_emoji_pipeline.py` from the project root. It derives the full required set from game data, downloads missing twemoji SVGs, and rebuilds `Assets/emoji_svg/emoji_index.json` with normalized keys. Text-fallback warnings at boot are the symptom that this needs re-running.

**Runtime requirements:**
- Python 3, numpy.

**Do NOT grant access to:**
- `*.gd`, `*.tscn`, `*.gdshader` files outside the two referenced above
- `Core/Boot/`, `Core/Audio/`, `Core/AI/`, `Core/Diagnostics/`, `Core/Environment/`, `Core/Config/` (other than `FarmVariableGraph/default.jsonl` for read-only context if needed)
- `Assets/` directory
- `.github/`, build caches, anything under `tools/BuildBundledCache*`
