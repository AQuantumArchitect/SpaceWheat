# Archetype Frames — the new outer ring

The 8-archetype cube (`docs/CHARACTER_ARCHETYPES.md`) lifts above the
keyboard as the **outermost selector**. Pressing an archetype hat key
swaps the action vocabulary that `1`/`2`/`3` + QERF reaches. Same biome
×plot grid, same verb cross — different verbs imposed.

This supersedes the earlier "QERF → 2D nav, digits → universal slot
selector" migration proposal. QERF keeps its axial-verb semantics.

## Decided 2026-04-27

- Drop **Ace** — it's the null/default hat. No key needed; pressing
  nothing = being Ace.
- 7 archetype frames on the top row. 1/2/3 selects sub-mode within the
  current frame. QERF keeps its grammar (Q/R item axis, E pause+inspect,
  F play+continue).

## The keyboard stack

```
4 5 6 7 8 9 0   archetype hat row     (7 of 8 cube vertices; Ace dropped)
1 2 3           sub-mode within current archetype frame
T Y U I O P     biome slot row
G H J K L ;     plot slot row
W A S D         crawl ±1 in biome × plot
Q E R F         verb cross — Q/R item, E pause+inspect, F play+continue
[ ]   , .       frame / menu-ring cycling
Z X C V B N M   top-level menu ring
ESC             unwind
```

## Hat assignments (live wiring as of 2026-04-28)

Self-face on the left of the row, World-face on the right. The two
Quantum-Pulse vertices (Spark, Druid) bookend — cast-pulse on both ends.

| Key | Archetype | Cube coords    | Live wiring                                          |
|-----|-----------|----------------|------------------------------------------------------|
| `4` | Spark     | (Self, Q, P)   | Pole shift (spend pole emoji → one-shot shove)       |
| `5` | Icon      | (Self, Q, F)   | Icon injection (faction-signature qubits)            |
| `6` | Socialite | (Self, C, F)   | Faction contracts (drain=treaty / transfer=broker / pump=tribute) |
| `7` | Captain   | (World, C, F)  | Biome lifecycle (discover / cull)          |
| `8` | Scientist | (World, C, P)  | Probe (explore / measure / pop)            |
| `9` | Operator  | (World, Q, F)  | Gate building (build / inspect / break)    |
| `0` | Druid     | (World, Q, P)  | Unitary (X/Y/Z rotations, Hadamard)        |

## What each frame currently exposes

| Frame     | Sub-modes               | Q             | E (pause + inspect)       | R              | F       |
|-----------|-------------------------|---------------|---------------------------|----------------|---------|
| Spark     | shift                   | S.Pole (↓1×)  | Cost preview (pause)      | N.Pole (↑1×)   | —       |
| Icon      | inject                  | Add icon      | (open picker; pause)      | Trim icon      | —       |
| Socialite | thermal / dephase / damp | Treaty 🧺   | Broker 🤝                 | Tribute 📜     | Tip 💬  |
| Captain   | biomes                  | Discover   | (reserved)           | Cull        |
| Scientist | probe                   | Explore    | Measure              | Pop         |
| Operator  | gate                    | Build gate | Inspect              | Break gate  |
| Druid     | X / Y / Z               | rot−       | Hadamard             | rot+        |

## How this redistributes today's tool groups (current wiring)

After the 2026-04-28 redistribution the four legacy tool groups now
live as follows:

- **Tool 1 (Unitary)** → **Druid** (the wise quantum priest casts the
  reversible gates)
- **Tool 2 (Lindblad)** → **Spark** (instant cast-pulses into the
  dissipative bath)
- **Tool 3 (Measure)** → **Scientist** (probe only; the gate sub-mode
  moved to Operator)
- **Tool 4 (Meta)** → **Captain** (biome lifecycle only; the
  signature/icon-injection sub-mode moved to Icon)
- **New: Operator** holds gate building (build / inspect / break)
- **New: Icon** holds icon injection — the player inserts dual-emoji
  qubits drawn from their own faction signature
- **Socialite** stays a placeholder pending quest-layer wiring

`Core/GameState/ToolConfig.gd` is the live config; the data lives in
its `ARCHETYPE_FRAMES` dict, with `GROUP_TO_FRAME` / `FRAME_TO_GROUP`
shims keeping any unmigrated int-keyed callsite working.

## Behavior rules

- **Soft tint, never hard filter.** Every frame can still cycle to every
  biome and every plot. The frame changes what 1/2/3 + QERF *do* there;
  it does NOT gate access to anything. Non-resonant biomes/plots dim
  but stay reachable.
- **Manual hat-press only** (for now). No context-implicit frame switch
  on opening a surface. Predictable beats clever pre-launch.
- **Pressing the current frame's hat again** toggles back to Ace (null
  hat = default toolkit, not narrowed by any lens).
- **Sticky frame.** Press once, stays until another hat or ESC.
- **Self-face vs World-face HUD.** Self-face frames (Spark/Icon/Socialite)
  tint the player's own state ring; World-face frames (Captain/Scientist
  /Operator/Druid) emphasize biome/plot rendering. Mostly a presentation
  difference.
- **Tab is reclaimed** — direct-pick on 1/2/3 makes Tab redundant for
  mode cycling. Free for future use.

## Ace = no frame

When no hat is pressed:

- The player is in **Ace** (S, C, P) — the wanderer-default.
- 1/2/3 + QERF default to a baseline toolkit (TBD — probably a stripped
  Scientist-style probe or whatever the player last used).
- Ace is the *resting state*, not a missing state.

## Open questions

1. **Default Ace toolkit.** What does 1/2/3 + QERF actually do with no
   frame selected? Last-used frame's bindings? A frameless probe? TBD.
2. **Submenu modes.** Some current tool modes have submenus (gate
   picker, icon injection). Do they live as a 4th sub-slot, a chip in
   QERF, or a Shift+digit detail surface?
3. **Frame chip in HUD.** Visual treatment for the active frame —
   color tint, glyph in top-row, both?
4. **Shift+digit** for "open this frame's detail surface" (e.g.
   Shift+0 opens Druid's gate library catalog) — reasonable, deferred.
5. **Frame ordering.** The Self-left/World-right layout is one option;
   axis-grouped (all Quantum together) is another. Pick after some
   playtesting once frames are wired.

## Status

- Decided 2026-04-27. Supersedes `project_keymap_migration_proposal.md`
  (QERF-as-nav direction).
- No code yet. Wiring order: ArchetypeFrameConfig data shape →
  PlayerShell hat dispatch → per-frame surface rendering →
  ToolConfig retirement.
- `Core/GameState/ToolConfig.gd` stays live until frames are fully
  wired. Don't delete.

## Related

- `docs/CHARACTER_ARCHETYPES.md` — the cube itself
- `UI/Core/KEYBOARD_GRAMMAR.md` — current grammar (will be amended)
- `Core/GameState/ToolConfig.gd` — current tool-group system being
  redistributed
