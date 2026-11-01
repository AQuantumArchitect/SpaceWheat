# Archetype Frames — the new outer ring

The 8-archetype cube (`docs/CHARACTER_ARCHETYPES.md`) sits above the
keyboard as the outer frame selector. Pressing a hat key swaps the
action vocabulary that `1`/`2`/`3` + QERF reaches. Same biome × plot
grid, same verb cross, different verbs per frame.

QERF keeps its axial-verb semantics.

## Current keyboard stack

- `4 5 6 7 8 9 0` selects the active archetype frame.
- `1 2 3` selects a sub-mode within that frame.
- `T Y U I O P` selects biome slots.
- `G H J K L ;` selects plot slots.
- `W A S D` moves within the biome × plot lattice (W/S spin rings, A/D step).
- `Q E R F` is the verb cross.
- `Z X C V B N M` opens the top-level menu ring.
- `ESC` unwinds one level (overlay → submenu → pending confirm → plot
  deselect → system menu).

> `[` `]` `,` `.` are **reserved no-ops** — WASD already crawls the whole
> ring cylinder, so a separate cycle pair gains nothing. Canonical bindings:
> `UI/Core/InputBindingRegistry.gd`; full grammar: `UI/Core/KEYBOARD_GRAMMAR.md`.

## The keyboard stack

```
4 5 6 7 8 9 0   archetype hat row     (7 of 8 cube vertices; null hat has no key)
1 2 3           sub-mode within current archetype frame
T Y U I O P     biome slot row
G H J K L ;     plot slot row
W A S D         crawl: W/S spin rings, A/D step ±1 around the active ring
Q E R F         verb cross — Q/R item, E pause+inspect, F play+continue
Z X C V B N M   top-level menu ring
ESC             unwind one level (overlay → submenu → confirm → deselect → menu)
[ ] , .         reserved no-ops (WASD already covers the whole cylinder)
```

## Hat assignments

Self-face frames sit on the left of the row, World-face frames on the
right. Spark and Druid bookend the set.

| Key | Archetype | Cube coords    | Live wiring                                          |
|-----|-----------|----------------|------------------------------------------------------|
| `4` | Spark     | (Self, Q, P)   | One-shot Lindblad jolt (wet country) / 🌉 bridges     |
| `5` | Icon      | (Self, Q, F)   | Signature growth: F-track a qubit's Berry phase → ripen → R-incorporate into your signature (empty plot: R injects) |
| `6` | Merchant  | (Self, C, F)   | Standing Bath contracts: thermal / dephase / damp     |
| `7` | Captain   | (World, C, F)  | Biome lifecycle (discover / cull)          |
| `8` | Ace       | (Self, C, P)   | Player vantage (gather / pause / strike / fast-fwd) |
| `9` | Operator  | (World, Q, F)  | Gate building (build / inspect / break)    |
| `0` | Druid     | (World, Q, P)  | Unitary (X/Y/Z rotations, Hadamard)        |

> **Regimes:** openness is a *place*, not a setting — and the keyboard is
> never sealed. Every hat is always selectable; the Lindblad **verbs**
> (Spark's jolt, Merchant's contracts) refuse per-plot wherever the target
> biome's regime runs closed (`is_open_here`), and run live wherever it
> leaks — including the wet landmarks that boot open *before* the endgame
> door. The island can never be mixed: `Farm`'s channel tick skips closed
> ground by construction. Spark's 🌉 bridge mode is never sealed in any
> regime. **Plant** is gone from Ace entirely (it was a drive) — it lives
> only on Spark; Ace is the measurement vantage. See `docs/CLOSED_SYSTEM.md`.

## Frame wiring

| Frame     | Sub-modes                | Q              | E (pause + inspect)       | R             | F                  |
|-----------|--------------------------|----------------|---------------------------|---------------|--------------------|
| Spark     | shift ⚡ / bridge 🌉      | S.Pole · Fuse  | Gauge 🔍 · Bridge card    | N.Pole · Span | — · Braid 🪢       |
| Icon      | inject 📖 / mirror 🪞    | Trim icon · Release | Inspect qubit · **Compare** 🪞 (Δγ + spinor sign vs reference) | Add icon / **Incorporate** (tracked+ripe) · **Stay Home** ⌂ | **Track** ⌖ (Berry phase) · — |
| Merchant  | thermal ~ / dephase . / damp \| | Export 📤 | Order book !             | Import 📥 (dephase: refused) | Settle ✔ |
| Captain   | biomes                   | Cull           | Compass (discover peek)   | Add Biome     | —                  |
| Ace       | probe                    | Gather         | Pause ⏸                   | Strike !      | Fast-Fwd ⏩        |
| Operator  | gate )( / compass 🧭     | Break gate · **Comb** 🪮 (tree gauge-fix) | Inspect · **Loops** 🔍 (β₁, Wilson) | Build gate · **Turn** 🧭 (gauge flip) | — · **Shake** 🎲 (scramble) |
| Druid     | X / Y / Z                | rot−           | Hadamard                  | rot+          | —                  |

## Live wiring

`Core/GameState/ToolConfig.gd` owns the live frame map in
`ARCHETYPE_FRAMES`.

- **Spark** handles the one-shot jolt (wet country) and Majorana bridges.
- **Icon** is the signature-growth loop. **F** toggles Berry-phase tracking on
  the focused qubit (and resumes play); under the live Hamiltonian an excited
  qubit traces solid angle until it ripens (phase → 2π). **R** on a tracked+ripe
  qubit *incorporates* its icon into the player's signature (grows `known_icons`,
  the source story flags gate on) — this is harvesting an already-realized
  register, NOT biome injection, so it routes through `player_progress.discover_icon`,
  not `inject_icon_pair`. On an empty plot, **R** injects a new icon into the biome.
  The Berry-phase ripening is the cost; incorporate charges no resources.
- **Merchant** handles standing Bath contracts — the sub-mode IS the
  channel: thermal (detailed balance, keeps the field warm), dephase
  (pure phase damping — export only; no contract sells phase back), damp
  (one-way, pins and pays). F settles; E reads the real order book.
- **Captain** handles biome lifecycle.
- **Ace** is the player vantage: gather / pause / strike / fast-forward.
- **Operator** handles gate building.
- **Druid** handles unitary gates.

## Behavior rules

- **Soft tint, never hard filter.** Every frame can still cycle to every
  biome and every plot. The frame changes what 1/2/3 + QERF *do* there;
  it does NOT gate access to anything. Non-resonant biomes/plots dim
  but stay reachable.
- **Manual hat-press only** (for now). No context-implicit frame switch
  on opening a surface. Predictable beats clever pre-launch.
- **Pressing the current frame's hat again** clears the selection and
  returns to the Ace probe toolkit.
- **Sticky frame.** Press once, stays until another hat or ESC.
- **Self-face vs World-face HUD.** Self-face frames (Spark/Icon/Merchant/Ace)
  tint the player's own state ring; World-face frames (Captain/Operator/Druid)
  emphasize biome/plot rendering. Mostly a presentation difference.
- **Tab cycles the hat** (4-0) — the one-key version of the WASD
  frame-ring step. Sub-modes are direct-picked on 1/2/3.

## No-hat state

When no hat is pressed, the runtime uses the Ace probe toolkit.

## Source of truth

`Core/GameState/ToolConfig.gd` owns the live frame map and action labels.

## Related

- `docs/CHARACTER_ARCHETYPES.md` — the cube vocabulary
- `UI/Core/KEYBOARD_GRAMMAR.md` — current grammar
- `Core/GameState/ToolConfig.gd` — live frame configuration
