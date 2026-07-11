# Biome: FungalNetworks — Campaign & Tutorial Notes

> **Scope banner (2026-07-11):** written before the closed-native migration —
> this doc treats open-system Lindblad physics as the working baseline. The
> base game is closed (zero Lindblad operators; see `docs/CLOSED_SYSTEM.md`).
> Valid as design reference for the open / wet-country DLC content only.

**Lore pitch:** Networked fungal colonies thrive in moonlight and moisture,
spreading through insects and spores, cycling between health and death.

**Physics pitch:** A five-qubit open system demonstrating a multiplicative
AND gate, a natural bistability in the sky axis, and a player-buildable
wet-night latch. The biome starts stable and predictable; a player-triggered
regime change turns it wild.

---

## The Five Axes (what the player reads)

Each axis is a qubit — two named poles, one bright, one dim. Population
(brightness) is the probability of finding that site occupied if you measure.

| Axis | Pole 0 | Pole 1 | Physics role |
|---|---|---|---|
| **Insect** | 🦗 cricket | 🐜 ant | Two insect vectors; Locusts faction couples them strongly (H ≈ 0.6). They hop between each other constantly. |
| **Kingdom** | 🍄 fungus | 🦠 microbe | Two life kingdoms; *no direct H coupling* — their populations are independent observables. Measuring Kingdom tells you which domain is dominant right now. |
| **Decompose** | 🍂 litter | 💀 death | Two ends of the rot cycle; Mycelial Web runs a chiral H triangle across 🍄/🍂/💀 — this is where the tiny rot-clock lives. |
| **Sky** | 🌙 moon | ☀ sun | Naturally bistable: the sun has two steady-state levels (near-zero or ~0.10) depending on starting conditions. Moon is stable at ~0.17 and is the gate source for the wet-night bloom. |
| **Bath** | 🌧 rain | 🧫 dish | The wild/calm toggle qubit. Rain is consumed rapidly by the AND gate; dish is the controlled substrate. See "The Toggle" below. |

---

## What the Biome Does (current steady state)

At rest, from an empty start:

```
🦗 0.09   🐜 0.05   — insects circulating in their Locust channel
🍄 0.15   🦠 0.13   — fungi slightly dominant; moon feeds mushroom via H
🍂 0.14   💀 0.15   — rot cycle balanced; death ≈ litter (normal ecology)
🌙 0.16   ☀ 0.00   — moon active; sun in its dark phase (bistable, see below)
🌧 0.02   🧫 0.09   — rain consumed fast; dish is the background substrate
```

The biome is **calm by default**. Rain falls and immediately disappears into
the microbial bloom; the dish-culture substrate (fed by Mossline Brokers' H)
is the steady background driver of bacteria.

### The rot clock

The Mycelial Web faction runs imaginary (chiral) H couplings across
🍄 ↔ 🍂 ↔ 💀. This is a persistent current — population flows around the
triangle slightly faster in one direction than the other. The effect is
small at steady state but becomes visible if you deplete one site: the
triangle will refill it from the non-depleted side before the other.

### Sun bistability

The sun (☀) has two stable levels: dark (~0.00) if you start from an empty
system, bright (~0.10) if you start from a fully-loaded system. The sky axis
is the player's first encounter with **history-dependent steady states** —
what the biome "remembers" about how it was seeded. This is not a bug. Probe
it by loading the biome from scratch vs. from a full save.

---

## The AND Gate (wet-night bacteria bloom)

The bacteria (🦠) have an extra pump term:

> **extra flux into 🦠 = 1.5 · ρ(🌙) · ρ(🌧)**

Both the moon AND rain must be present for the gate to fire strongly. With
🌙 at its natural 0.17, the AND channel is **4× stronger than the
unconditional rain pump** — so when it fires, it dominates.

When the AND gate fires, rain is consumed rapidly (🌧 drops from 0.07 → 0.02)
and transferred straight into bacteria. The transfer is physical: the Lindblad
jump operator literally moves probability amplitude from the rain site into the
microbe site. The mushroom gets a smaller boost too (🍄 gets 0.02 of each rain
unit), because moon-fed moisture also feeds the hyphal network.

**What the player sees:** on a wet night, bacteria are bright and rain is dim.
On a dry night, bacteria are dimmer and litter/death cycle at a steadier pace.
The sky and bath axes are coupled to the kingdom axis through this gate.

---

## The Wild/Calm Toggle

The Bath qubit's two poles have physically different behaviors:

**Wild mode — 🌧 populated:**
- AND gate active: rain × moonlight → bacteria bloom (nonlinear)
- Rain consumed fast; mushroom gets a weather spike
- Sensitive to sky state (moon population changes the gain)
- Slightly history-dependent (bloom amplitude varies with seed)

**Calm mode — 🧫 populated:**
- Rain depleted; AND gate starved
- Only linear Mossline + Locusts H drives 🦠 ↔ 🧫 (smooth substrate culture)
- Predictable, steady, substrate-controlled

An **X gate on the Bath qubit** swaps which pole is populated, swapping
regimes. But steady-state evolution will pull things back — the system wants
to settle at Bath ≈ (🌧: 0.02, 🧫: 0.09) because that's the natural balance
point. The kick is a transient perturbation, not a latch.

---

## Player Mission: Close the Moisture Loop (Latch Wild Mode)

This is the campaign hook for this biome. The AND gate is built; the
infrastructure to hold wild mode permanently is not — the player builds it.

**What's missing:** a Lindblad term that replenishes 🌧 from within the biome.
Rain currently only comes from the external source pump (🗑 → 🌧 at rate 0.4).
If the player depletes 🌧 into the bloom, the source pump can't keep up alone.

**How to close the loop:** add a decay channel from a biome atom back to 🌧.
Candidates (sorted by lore fit):

| Source | Rate to 🌧 | Story |
|---|---|---|
| 🦗 cricket | ~0.05 | Crickets stir moisture from leaf litter |
| 🍂 litter | ~0.03 | Decomposing leaves release water |
| 💀 death | ~0.02 | Rot sweats out water |

Any of these closes the loop. Once closed, moisture cycles back from the
ecology into more rain, rain drives bloom, bloom feeds more litter/death, more
litter/death sweats moisture. Wild mode becomes self-sustaining.

**Mechanically:** the player uses Tool 2 (Lindblad) to inject the new decay
term. The biome locks into wild mode permanently — bacteria stay bright,
rain stays low (consumed), the AND gate never starves.

**What this teaches:** Lindblad terms are the physical environment's rules.
You can change the rules. Adding a decay channel is like connecting a pipe —
water (probability) now flows through it. This is the first mission where
the player modifies the open-system dynamics rather than just measuring them.

---

## Faction Landscape

| Faction | Active atoms (in-biome) | What they contribute |
|---|---|---|
| **Mycelial Web** | 🌙, 🍄, 🍂, 💀 | The rot clock + strong 🌙↔🍄 coupling (moonlight feeds mushroom) |
| **Locusts** | 🦗, 🐜, 🦠, 🧫 | Insect hopping + 🦠↔🧫 culture loop |
| **Mossline Brokers** | 🦠, 🧫 | Dense 🦠↔🧫 (0.6) — steady microbial culture; adds chiral phase to microbe evolution |
| **Plague Vectors** | 🦠, 💀 | Strong 🦠→💀 coupling (0.52) — microbes kill; the "plague" pressure on the system |
| **Celestial Archons** | 🌙, ☀ | Diagonal self-energies (ε☀=1.0, ε🌙=0.8) — sky energy levels; weak ☀↔🌙 coupling (0.025) is why Sun is bistable |
| **Flesh Architects** | 🧫 | Off-biome mostly; contributes a small 🧫↔🧵 channel that leaks into the void |

The Celestial Archons' asymmetric self-energies (☀ sits higher than 🌙) are
why the sun is bistable — with high energy it's a metastable state that needs
population to maintain; empty system can't climb to it.

---

## Assay Scores

| Assay | Score | Notes |
|---|---|---|
| `transition_assay` bistability | **0.100** (☀) | Sun bistability; pre-existing, not engineered |
| `transition_assay` after AND gate | **0.100** (☀) | AND gate doesn't disrupt the bistability |
| `gain_assay` | (not run) | No population inversion designed here |
| `ssh_assay` | (not run) | No chain topology |

Run `python3 tools/transition_assay.py --biome FungalNetworks` to reproduce.

---

## Implementation Files

- `Core/Biomes/data/biomes.json` — source of truth for all specs above
- `tools/mutate_fungalnetworks.py` — added 🌧, re-paired to 5 axes
- `tools/mutate_fungalnetworks_and_gate.py` — wired the AND gate
- Commits: `b2716bb` (structure), `c41f27e` (AND gate)
