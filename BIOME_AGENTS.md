# Biome-Crafting Agent Guide — SpaceWheat

This file is for agents working **specifically on the biome/faction physics
layer** — mutating biome Lindbladians, tuning factions, running the assay
toolkit. It is NOT a general onboarding guide for the Godot game, rendering,
UI, or game logic. If you are working on anything outside `Core/Biomes/`,
`Core/Factions/`, or `tools/`, stop here — you want a different doc.

Scope:
- ✅ Read and mutate `Core/Biomes/data/biomes.json`
- ✅ Read and add to `Core/Factions/data/factions.json`
- ✅ Run and add scripts under `tools/`
- ❌ Don't touch `.gd` / `.tscn` / Godot scene assets
- ❌ Don't touch `Core/Boot/`, `Core/Audio/`, `Core/Diagnostics/`, or any
  subsystem that isn't Biomes or Factions
- ❌ Don't modify the bundled cache or its builder

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
  "icon_components": {
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

Lindblad operator types (on each emoji):
- `decay: {rate, target}` — `√rate · |target⟩⟨emoji|`. Target outside biome = drain to sink.
- `lindblad_outgoing: {target: rate}` — same, multiple targets.
- `lindblad_incoming: {source: rate}` — `√rate · |emoji⟩⟨source|`. Source "🗑" = external pump.
- `gated_lindblad_source: [{target, gate, rate, power, inverse}]` —
  rate-modulated jump from `emoji` to `target`, where effective rate = `rate · ρ_gate^power`. This is the **nonlinearity** that makes bistability, tristability, oscillators, and gradient memories possible.

**Variation selectors matter.** `biome_audit.strip_fe0f` removes `️` from the biome's `emojis` list on load, but NOT from inner dict keys/values. If you write `❄️` in `icon_components` it won't match the stripped `❄` — so always use bare codepoints (`❄`, `⚙`, etc.) for emoji keys inside Lindblad specs.

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
2. **Read its current `icon_components`.** Don't destroy the existing lore;
   add or tune, don't delete unless necessary.
3. **Edit `Core/Biomes/data/biomes.json`** (via a Python script — the file
   is large and editing by hand is error-prone). Surgical changes: raising a
   `decay.rate`, adding one `gated_lindblad_source`, adjusting a `power`.
4. **Re-run the relevant assay** to confirm the score moved in the right
   direction. If other assays regressed, check whether that matters.
5. **Commit with a message explaining what physics moved and why.**

### What works and what doesn't (observed empirically)

- **Simple biomes mutate cleanly; crufty ones resist.** Biomes with few
  `icon_components` tune well. Biomes with lots of pre-existing gated
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

**Runtime requirements:**
- Python 3, numpy.

**Do NOT grant access to:**
- `*.gd`, `*.tscn`, `*.gdshader` files outside the two referenced above
- `Core/Boot/`, `Core/Audio/`, `Core/AI/`, `Core/Diagnostics/`, `Core/Environment/`, `Core/Config/` (other than `FarmVariableGraph/default.jsonl` for read-only context if needed)
- `Assets/` directory
- `.github/`, build caches, anything under `tools/BuildBundledCache*`
