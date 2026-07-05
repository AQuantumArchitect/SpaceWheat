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
- `W A S D` moves within the biome × plot lattice.
- `Q E R F` is the verb cross.
- `[` `]` `,` `.` cycles frame/menu rings.
- `Z X C V B N M` opens the top-level menu ring.
- `ESC` unwinds.

## The keyboard stack

```
4 5 6 7 8 9 0   archetype hat row     (7 of 8 cube vertices; null hat has no key)
1 2 3           sub-mode within current archetype frame
T Y U I O P     biome slot row
G H J K L ;     plot slot row
W A S D         crawl ±1 in biome × plot
Q E R F         verb cross — Q/R item, E pause+inspect, F play+continue
[ ]   , .       frame / menu-ring cycling
Z X C V B N M   top-level menu ring
ESC             unwind
```

## Hat assignments

Self-face frames sit on the left of the row, World-face frames on the
right. Spark and Druid bookend the set.

| Key | Archetype | Cube coords    | Live wiring                                          |
|-----|-----------|----------------|------------------------------------------------------|
| `4` | Spark     | (Self, Q, P)   | Pole shift (spend pole emoji → one-shot shove)       |
| `5` | Icon      | (Self, Q, F)   | Icon injection (faction-signature qubits)            |
| `6` | Merchant  | (Self, C, F)   | Faction contracts (drain=treaty / transfer=broker / pump=tribute) |
| `7` | Captain   | (World, C, F)  | Biome lifecycle (discover / cull)          |
| `8` | Ace       | (Self, C, P)   | Energy dyad (plant / measure / harvest / reap) |
| `9` | Operator  | (World, Q, F)  | Gate building (build / inspect / break)    |
| `0` | Druid     | (World, Q, P)  | Unitary (X/Y/Z rotations, Hadamard)        |

> **Regimes:** openness is a *place*, not a setting. On closed ground (the
> enclave, and every biome whose regime runs closed) Spark's jolt mode and
> Merchant's Lindblad drives sit greyed out — a closed system has no
> pump/drain. The post-story **wet country** (per-biome `regime`,
> `docs/OPEN_CAMPAIGN.md`) runs the same verbs live. Spark's 🌉 bridge
> mode (mode 2) is **never** sealed. See `docs/CLOSED_SYSTEM.md`.

## Frame wiring

| Frame     | Sub-modes                | Q              | E (pause + inspect)       | R             | F                  |
|-----------|--------------------------|----------------|---------------------------|---------------|--------------------|
| Spark     | shift ⚡ / bridge 🌉      | S.Pole · Fuse  | Pause · Bridge card       | N.Pole · Span | — · Braid 🪢       |
| Icon      | inject                   | Trim icon      | Inspect qubit             | Add icon (incorporate when ripe) | Track ⌖ |
| Merchant  | thermal / dephase / damp | Export 📤      | Read Price !              | Import 📥     | Tip 💬             |
| Captain   | biomes                   | Cull           | Compass (discover peek)   | Add Biome     | —                  |
| Ace       | probe                    | Harvest        | Measure                   | Plant         | Reap ⌛ (season)   |
| Operator  | gate                     | Break gate     | Inspect                   | Build gate    | —                  |
| Druid     | X / Y / Z                | rot−           | Hadamard                  | rot+          | —                  |

## Live wiring

`Core/GameState/ToolConfig.gd` owns the live frame map in
`ARCHETYPE_FRAMES`.

- **Spark** handles pole shifts.
- **Icon** handles icon injection.
- **Merchant** handles faction contracts.
- **Captain** handles biome lifecycle.
- **Ace** handles the energy dyad: plant / measure / harvest / reap.
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
