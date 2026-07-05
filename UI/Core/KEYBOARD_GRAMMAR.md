# SpaceWheat Keyboard Grammar

Canonical reference for the input model. If runtime code disagrees with
this doc, treat the newer source as authority and update this doc on the
next pass — but do flag the drift, because three places (this doc,
`UI/Core/InputBindingRegistry.gd`, and `UI/Overlays/ControlsOverlay.gd`)
all describe bindings and any one of them can rot independently. See
*Maintenance note* at the bottom.

---

## TLDR

> Every input is **`ACTION × SELECTION`**.
>
> - **`ACTION`** = a verb (Q/E/R/F) along a sub-mode-selected axis (1/2/3).
> - **`SELECTION`** = a position on a 4-ring selection cylinder
>   (ZXCVBNM surface / 4-0 hat / TYUIOP biome / GHJKL; plot).
> - **WASD** spins the cylinder; **row keys teleport** to a slot directly.
> - **ESC** unwinds the overlay stack; **Z/X/C/V/B/N/M** teleports between
>   top-level surfaces.
>
> Eight keys (QERF + WASD) span four navigation axes. A fifth axis-selector
> row (1/2/3) chooses which axis Q/R fires along.

---

## The algebra: ACTION × SELECTION

Every player input composes two orthogonal layers:

```
  ACTION:    (axis: 1 2 3) (verb: Q E R F)
  SELECTION: (outer: Z X C V B N M)
             (upper: 4-0)
             (lower: T Y U I O P)
             (bottom: G H J K L ;)
```

The action layer answers *what verb am I firing*. The selection layer
answers *what am I firing it at*. The composition reads "do X to Y."
Both layers are sticky: pick once, then keep firing — only the verb
needs a fresh keypress per action.

### Eight keys, five axes

| Key block | Axis | Role |
|---|---|---|
| Q / R     | depth (z)              | screw out / screw in (right-hand rule). REMAPPED by sub-mode 1/2/3. |
| E / F     | time (t)               | pause+inspect / play+flatten. INVARIANT across sub-modes. |
| W / S     | ring-selection         | rotate cursor outwards/inwards across the cylinder rings. Wraps. |
| A / D     | position-on-ring       | step prev/next around the active ring. |
| 1 / 2 / 3 | axis-selector for Q/R  | which axis the depth verbs operate along inside the active hat. |

The "4D + axis-selector" framing is deliberate: WASD covers the whole
selection geometry; QERF covers depth and time; 1/2/3 chooses which
axis Q/R fires along. No two keys do the same job.

---

## The 4-ring selection cylinder

```
  Z X C V B N M   ← OUTER  ring: top-level surfaces
  4 5 6 7 8 9 0   ← UPPER  ring: hat / archetype scope
  T Y U I O P     ← LOWER  ring: biome row / surface frame slots
  G H J K L ;     ← BOTTOM ring: plot row / surface item slots (transitional)
  W A S D         ← spin pad: W/S rotate between rings (wraps),
                                A/D step around the active ring
```

The cylinder is **closed** — W/S wraps top-to-bottom (S past GHJKL; →
ZXCVBNM; W past ZXCVBNM → GHJKL;). The naming (outer / upper / lower /
bottom) is just descriptive convenience; geometrically there is no top
or bottom.

- **`Z-X-C-V-B-N-M`** — OUTER ring. Top-level surfaces (see *Surfaces*
  below). Each key direct-jumps to its surface; WASD-with-cursor-on-outer
  cycles between open surfaces.
- **`4-0`** select the **archetype hat** (see `docs/ARCHETYPE_FRAMES.md`).
  Two roles per key: *action role* (active toolkit verbs Q/E/R/F) and
  *selection role* (upper cylinder ring; future will gate which biomes
  appear in TYUIOP). Sticky. Re-pressing the active hat toggles back to
  **Ace** (default toolkit).
- **`T-Y-U-I-O-P`** — LOWER ring. At gameplay: biome slot 1–6. Inside
  an open surface: frame slot 1–6.
- **`G-H-J-K-L-;`** — BOTTOM ring. At gameplay: plot slot 1–6 in the
  active biome. Inside a surface: item slots within the active frame.
  Left-to-right ordering (`G`=plot 0 .. `;`=plot 5). Transitional — plot
  information will eventually unify into other rings.
- **`W A S D`** spins the cylinder:
  - `W` / `S` rotate the cursor between rings (wraps both directions).
  - `A` / `D` step prev/next around the active ring.

Every direct row key is a **teleport**: jump to that ring + slot in one
keystroke. WASD-crawl is the gradual alternative.

### Surfaces may under-fill TYUIOP

A surface is welcome to bind only the frame slots it actually
populates; unbound row keys are no-ops on that surface, the same way
an empty Q/R chip is honest. Six slots are *available*, not required.
Slot ordering still matches the keyboard (T=first, P=sixth) so muscle
memory carries across surfaces. An overlay that today binds only
T/Y/U/O is making a real statement: "this surface has four frames; I
and P are reserved for future content or are intentionally absent."

### Pure visual overlays

A surface may declare itself a magnifier-only overlay: all four QERF
chips empty, no TYUIOP claims, no `[`/`]` cycling. Keys forward
through to the surface beneath via
`SurfaceRegistry.get_topmost_excluding(self)`. The B microscope is
the canonical example — it reads the live plot selection from the
instrument and renders a richer view, but it never changes selection,
never owns verbs, and never blocks the hat. Pure overlays are exempt
from the QERF "every chip is honest" framing because they have no
chips at all.

### Frame-local TYUIOP override

Most surfaces use TYUIOP for direct-jump between their frames (`T`=first
frame, `Y`=second, etc.). A frame whose *purpose* is to manipulate the
TYUIOP axis itself — currently only N's Map frame (binding biomes to
TYUIOP slots) — consumes TYUIOP for content selection instead. To exit
such a frame, use `W` to spin the cursor outwards to the surface-frame
ring then `A`/`D` to step to a sibling frame, or `ESC` to close the
surface entirely. This is the rare exception.

---

## The QERF action quartet — depth and time

```
              F   (time + : play / forward / flatten)
              ↑
   Q  ← ← ←   ●   → → →  R     (depth: screw out | screw in)
              ↓
              E   (time − : pause / inspect / snapshot)
```

### Q ↔ R — the depth/screw axis

Right-hand rule. Curl the fingers of your right hand around a screw.

- **R = screw IN** = thumb away. Entering, committing, advancing,
  pumping, **investing** (Plant / Buy / Spark-north). "Save and resume"
  lives on R: screw back into the session.
- **Q = screw OUT** = thumb toward you. Leaving, retreating, undoing,
  draining, **extracting** (Harvest / Sell / Spark-south). "Quit" lives
  on Q: unscrew yourself from the session.

The energy dyad makes this physical on the energy-touching hats:
**Q extracts energy** from the field (reward = surprisal `−kT·log p` —
rare outcomes pay more), **R invests energy** into it. **E reads the
price** (Measure — collapse + pause). One scarcity law on both poles;
selecting a plot auto-binds its terminal, so there is no separate
"Explore" verb.

> **Regimes (openness is a place).** On closed ground measure/pop is a
> **full projective collapse** — measurement is the only irreversible act,
> and the Hamiltonian re-spreads the collapsed qubit over the following
> ticks (time + H is the "pump"). Every hat is always selectable, but the
> Lindblad **verbs** — Spark's jolt (4) and Merchant's contracts (6) —
> refuse per-plot wherever the target biome's regime runs closed, and run
> live wherever it leaks (the wet landmarks boot open before the endgame
> door). Ace's **R = Plant** is a **coherent Rabi pulse** — unitary, legal
> everywhere, and unable to purify: a faded plot needs measurement, or the
> Spark. See `docs/CLOSED_SYSTEM.md`.

#### The session is the axis, not the target

Q/R is always anchored to the **player's current session**, not to the
object on the other end of the action. The slot, scenario, gate, or
value being acted on is *selection*, not depth.

- **Load slot** lives on **Q** — it abandons the current run to take
  the slot's state. Same shape as quit.
- **Save slot** lives on **R** — it preserves the current run by
  committing forward. Same shape as save & resume.
- **Start new scenario** lives on **Q** — it ends the current run to
  begin a different one. The new scenario is *what's at the other
  end*, not the axis.

When a menu has only one session-shaped verb (e.g., "run dev action"
in the Dev tab), the other pole is honestly empty. Two-pole menus like
ZT (quit / save & resume) are the target shape; one-pole menus are
fine but indicate you have less to offer the player here.

Q/R is **not list navigation.** Stepping between items belongs to WASD
(A/D across the focused ring, W/S across rings). A surface that wires
Q/R to "previous / next item" is conflating depth with selection — fix
the binding, not the doc.

**Allowed exception — 2D viewport view-control.** When a surface frame
*is* a continuous 2D viewport (M's Atlas page renders a biome × faction
cluster; M's Graph page embeds a `GraphEdit` of the broad federation /
neighborhood cluster), Q/R may adjust orbit / pan / zoom locally — the
screw metaphor still applies (R = zoom in / pull closer; Q = zoom out /
push away). The Graph page also lets `GraphEdit` own drag/scroll pan
directly. List-stepping on Q/R remains forbidden everywhere.

### E ↕ F — the time axis

E and F are exact opposites. Wherever E **opens** something, F **closes**
it. Same gesture, flipped.

**E — pause / inspect / expand / broker.** E is wired at PlayerShell:
any E press pauses the live simulation. That's a global truth, not
something each tool re-implements. Holding E shows hovertext / detail.
The simulation stays paused until F unpauses it.

E in a tool can mean *both* the verb the tool defines AND the global
pause. Hadamard a qubit on Druid → world freezes so you can read the
new state. Measure a register on Ace → time stops on the outcome.

In menus, E **expands** the focused item — opens a detail panel,
surfaces hovertext, drills one level in. Pause is the side-effect; the
expansion is the primary verb.

A surface may legitimately leave E **empty** ("just pause, no
expansion"). An empty E slot is honest.

**F — play / forward / flatten / page.**

- **Sim is paused** → F resumes normal-speed evolution.
- **Sim is running** → F is a no-op at the shell level. A specific
  surface may bind F to "pulse / fast-forward / advance one phrame" as
  a view-level action.
- **Text or dialogue overlay is open** → F pages forward. ("Press F to
  continue.") Per-overlay binding, not a shell primitive.
- **E has opened a detail panel in a menu** → F **flattens** it
  (collapses back to the base view). The F chip shows "flatten" only
  when there is something to collapse; otherwise "—".

**F is never "back," never "drill out," never "cancel," never
navigation.** Those belong to ESC and the ZXCVBNM ring. F is always
about the direction of time or the depth of information: forward,
flowing, flat.

**Physical note:** R and F sit on the right side of the QERF cluster —
the "go" keys. Q and E are on the left/down side — the "stop and look"
keys. The keyboard topology mirrors the grammar.

### Q-drill-out vs F-flatten — two ways to close

| Close via | Closes what | Why |
|---|---|---|
| **Q** | the *deepest* R-drill (one level) | screw-out is the inverse of R's screw-in |
| **F** | any open E-snapshot | flatten is the inverse of E's expand |
| **ESC** | the entire overlay | back-out the whole stack one level |

The closing key the player uses should match the axis the player opened
with. The chips advertise both.

---

## Sub-mode (1/2/3) — the 5th axis

`1` / `2` / `3` directly select **which axis** Q/R fires along inside
the active hat. The choice is sticky. Frames with fewer sub-modes
ignore unused slots. E/F is invariant — sub-mode does **not** remap E/F.

Three hats consume multi-mode: **Merchant** (1=thermal / 2=dephase /
3=damp), **Druid** (1=X / 2=Y / 3=Z), and **Spark** (1=shift ⚡ /
2=bridge 🌉 — Majorana spans). The other four hats (Icon, Captain,
Ace, Operator) have a single sub-mode each, so 1/2/3 are no-ops there.

Action-space size:

```
  3 sub-modes × 2 (Q vs R) per multi-mode hat   = 6 depth verbs
  7 hats × up-to-6                              ≤ 42 archetypal verbs
  + the always-on E/F pair on top of every one of them
```

---

## Hats and frames

The table is descriptive — when a verb is empty that's fine; the chip
still exists and the row still has four slots. Source of truth:
`Core/GameState/ToolConfig.gd`.

| Hat | Frame    | Sub-mode (1/2/3 active?)  | Q (out/less)  | E (pause + inspect)   | R (in/more)   | F (play/flatten) |
|----|-----------|--------------------------|---------------|-----------------------|---------------|------------------|
| 4  | Spark     | shift ⚡ / bridge 🌉      | Spark S · Fuse | Gauge 🔍 · Bridge card | Spark N · Span | (global F) · Braid 🪢 |
| 5  | Icon      | inject (single)          | Trim Icon     | (open picker; pause)  | Add Icon      | Track ⌖          |
| 6  | Merchant  | thermal / dephase / damp | Export 📤     | Order book !          | Import 📥 (dephase: refused) | Settle ✔  |
| 7  | Captain   | biomes (single)          | Cull          | Compass               | Discover      | (global F)       |
| 8  | Ace       | probe (single)           | Harvest       | Measure               | Plant         | Reap ⌛ (season)  |
| 9  | Operator  | gate (single)            | Break gate    | Inspect               | Build gate    | (global F)       |
| 0  | Druid     | X / Y / Z                | rot−          | Hadamard              | rot+          | (global F)       |

F is handled globally by PlayerShell — frames don't define a per-mode F
verb. The only way a per-frame F appears is if a frame has a verb that
genuinely wants to ride the play-axis, which is rare by design.

---

## Surfaces (🌾 + Z X C V B N M)

The outer ring of the cylinder. Each key direct-jumps to its surface.
ZXCVBNM swaps overlays unconditionally; ESC unwinds the stack one level.
A/D on the surface ring cycle includes **FarmView** (index 0, no key) —
the ring is now closed: ... M → FarmView → X → Z → C → V → B → N → M ...

| Key | Surface | What it is |
|----|---------|------------|
| *(none)* | **FarmView** | The game itself. Navigable via A/D only; no direct key. Permanent base of the overlay stack. |
| **Z** | system (EscapeMenu) | Run / Keep / New / Levels / Dev. Save/load, scenarios, settings, dev tools. Also reachable via ESC. |
| **X** | self / playthrough (ControlsOverlay) | Self / Story / Verbs / Chatter / Guide. Player faction posture, story trajectory, vocab, how-to-play. |
| **C** | quest pipeline | Manifold / market / commitments / arc. Receives pair-scope handoffs from N's Network frame. |
| **V** | vocab atlas | Atoms, icons, signatures, affinities, relations — context-free, stripped of biome-local execution. |
| **B** | biome microscope | `supports` (single — pure visual overlay; keys forward to surface beneath). The magnifier lens. |
| **N** | Lindbladian network | Network / Bridges (G/H/J: bridges/gates/links) / Selector (TYUIOP slot binding) / Live (chatter) / Whole / Matrix. |
| **M** | global map | Biome × faction map. Cross-biome / cluster-scale views. `T`Vectors `Y`Eigenstate `U`Drift `I`Bits `O`Atlas `P`Graph. Atlas page allows Q/R for orbit / zoom (2D viewport exception). **`P` Graph** = the BroadGraph: a whole-world federation `GraphEdit` (one node per live biome, shared-vocabulary seams) — `GHJKL;`/`W·S` pick a biome, `E` drills into its neighborhood cluster (live population bars, coherent/webway/sink edges, 🌐 ports), `F` returns to the federation. |

`N → C` is a deliberate two-step loop. N's Network frame selects a
relation and seeds scope; C consumes the pending scope on open and shows
the contract board for that relation, falling back to current-biome
scope when no handoff exists. The N/C status readouts expose the
selected edge and scope source so the player can tell handoff from
fallback at a glance.

---

## Going back

There is no QERF "back" key. Two paths instead:

- **ESC** closes the topmost overlay one level. Hit it enough times and
  you're back in the main game. In the main game, ESC opens the system
  menu (Z).
- **The ZXCVBNM ring teleports.** Each key abandons the current
  overlay and swaps to its surface unconditionally. No risk of being
  trapped in a deep stack. Also reachable via WASD spin.

---

## Confirm chord

When a dangerous or irreversible action triggers (quit, restart, full
reset), the surface enters a **confirm state** rather than executing
immediately. The principle: **the trigger key becomes the safe commit.**

```
  trigger → confirm      safe commit   force commit   resume   cancel
     Q    →  [screen]  :     Q          F              R        E
```

| Pending action | Q             | E        | R        | F                    |
|----------------|---------------|----------|----------|----------------------|
| Quit           | save & quit   | cancel   | resume   | quit without saving  |
| Restart        | save & restart| restart anyway | cancel | —              |
| Full reset     | confirm reset | —        | cancel   | —                    |
| Reset settings | confirm reset | —        | cancel   | —                    |

Double-tap **Q** (QQ) is the *safe* version — same side, fast,
comfortable, autosave first. The **QF chord** (Q then F) is the *force*
version — left side to enter, right side to fire. Two distinct
keystrokes in two different keyboard regions; the physical distance
encodes the weight of the decision. The keyboard forces you to reach.

F as the force-commit key is grammatically consistent: F = forward =
"push through without looking back." The dangerous choice and the play
button are the same verb, applied to an irreversible decision.

F only appears on Quit because only Quit has a meaningful "force"
variant. Full reset and reset settings have no pre-existing state to
preserve, so there is nothing to skip.

### Gameplay destructive actions (QF only)

For irreversible gameplay Q-verbs (Harvest, Break gate, Cull biome, Trim
icon), only the QF path applies — there is no QQ safe variant. Q
enters a **pending state** (gold toast: "press F to confirm, any
other key cancels"). F fires the action; any other key cancels silently.
The toast auto-expires after ~5 s if the player does nothing.

---

## Mechanics — side-effect peek (E and F)

E and F are the only **overloaded** keys in the grammar: their primary
meaning (the per-tool / per-menu verb) and their secondary meaning (the
global pause / play side-effect) both have to fire from the same press.

`PlayerShell._input` peeks at the event before the existing exclusive
chain runs. The peek fires the side-effect (`paused = true` / `paused =
false`) but does **not** call `set_input_as_handled()` and does **not**
return. The event continues through the normal dispatch chain — overlay
stack, shell actions, then `Farm._unhandled_input` →
`QuantumInstrumentInput` — exactly as before. Whoever was going to
handle E (a menu's `_on_action_e`, or the live tool's
`_perform_action("E")`) still gets it.

```
PlayerShell._input(event):
    # 1. Side-effect peek — observe E / F without consuming.
    if e_pressed_this_event(event): _set_global_paused(true)
    elif f_pressed_this_event(event): _set_global_paused(false)
    # NO set_input_as_handled, NO return — keep going

    # 2. Existing exclusive dispatch (unchanged):
    if overlay_stack.route_input(event): consume → return
    if _handle_shell_action(event):     consume → return
    # else falls to Farm._unhandled_input → QII (Hadamard etc.)
```

The pause flag is `paused: bool` on **PlayerShell** with a
`paused_changed(is_paused)` signal. `Farm._physics_process` checks
`_is_globally_paused()` first and short-circuits when true.

**Unpause discipline:** strict — only F unpauses. Other keys (Q, R,
numbers, Tab, navigation) do not auto-unpause. Predictable; the
alternative ("any non-E unpauses") creates surprises when pressing 1
to switch sub-mode resumes the sim. Ship strict; relax later if
playtesters get stuck.

---

## Modifiers and overloads

- **`Shift + Q/E/R`** applies the verb to **every checked plot at once**
  (bulk). `Shift + Q` is the canonical "Mass Harvest."
- **`Shift + GHJKL;`** toggles a plot's checkbox without moving the
  cursor highlight (multi-select gesture).
- **`'`** (apostrophe) toggles bulk select / clear all on the active
  biome's plots. Empty selection → check every register. Non-empty →
  clear all checks.
- **`-` / `=`** = simulation time scale — **wiring pending**: PlayerShell
  currently stubs both (logs and returns). The GranularityController
  hookup is planned; until it lands these keys do nothing.
- **`Shift + -` / `Shift + =`** = simulation resolution (dt). Coarser /
  finer substeps, multiplicative jump.
- **`Tab`** cycles the **hat** (4-0) — the same step WASD does when
  the cursor is on the frame ring, but as a one-key shortcut.

---

## Reserved keys (single source of truth)

| Key | Role |
|---|---|
| `ESC` | Close topmost overlay (back one level). At gameplay, opens Z (system menu). The only "back" key — F does not unwind. |
| `Enter` / `Space` | Confirm / activate the selected item in menus. |
| `Backspace` | Reserved (no binding). |
| `F12` | Postcard — capture the view with the physics watermark + sidecar certificate (`user://postcards/`). |
| `[` / `]` | Reserved (no binding). WASD already crawls the whole selection block; `[/]` next to TYUIOP would gain no functionality. |
| `,` / `.` | Reserved (no binding). With ZXCVBNM joining the cylinder, A/D on the bottom ring covers the same gesture. |
| `` ` `` | Reserved (no binding). |
| `\` | Reserved (no binding). |
| `/` | Reserved (no binding). |

The `[/]` `,/.` `` ` `` `\` `/` keys are deliberately no-ops. WASD's
spin + the row keys' direct-jump cover the entire 4-ring cylinder; an
extra cycle pair would either duplicate WASD or scatter functionality
into a less-discoverable place. Future features that need a binding
should claim from this reserved set rather than overloading an existing
key.

---

## Why this grammar

**Eight keys, four navigation axes, one mental model on every surface.**
WASD spins the 4-ring selection cylinder (W/S rotate between rings, A/D
step around the active ring). Q/R drills depth (right-hand rule). E/F
flips the time axis (snapshot vs flow). Sub-mode 1/2/3 picks which axis
Q/R fires along inside the active hat. No two keys do the same job.

**Q and R encode direction in the world, not just on a list.** Q
unthreads you from the simulation; R threads you in. This is why "quit"
lives on Q and "save and resume" lives on R: they are the screw-out
and screw-in of the whole session.

**E and F are genuinely symmetric.** E opens the world (snapshot,
freeze, expand). F closes it (flatten, resume, page). The time axis
is a toggle. You don't need to remember a separate "close detail"
binding — F is already there.

**The confirm chord encodes risk in physical distance.** Q (left side)
to enter the confirm screen; Q again (same side, comfortable) for the
safe commit, or F (right side) for the force commit. The keyboard
forces the player to reach to execute the dangerous path. No explicit
"are you sure?" dialogue needed; the distance IS the "are you sure."

**Empty slots are honest.** The simulator is intentionally sparse —
most plots are doing little or nothing at any given moment. The control
scheme matches: empty Q / R / E slots are not bugs, they're
communication. An empty E slot still pauses. An empty F slot means
"there is nothing to flatten and nothing to page."

---

## Maintenance note — duplicated authorities

The keyboard grammar lives in three places that drift independently:

1. **This file** (`UI/Core/KEYBOARD_GRAMMAR.md`) — canonical reference.
2. **`UI/Core/InputBindingRegistry.gd`** — actual runtime bindings.
3. **`UI/Overlays/ControlsOverlay.gd`** — in-game help text the player
   reads.

Long-term, ControlsOverlay's help text should auto-generate from
`InputBindingRegistry` so there is no third manually-maintained list.
TODO: remove the hand-written rows in `_build_keys_section` and have
them read from `InputBindingRegistry.get_global_bindings()` plus the
row tables. Until then, **any binding change must update all three.**

---

## Open questions

1. **F pulse / fast-forward as a view-level action.** PlayerShell F is
   classical (clear pause). "Pulse / fast-forward / advance one phrame"
   is left for a specific view to wire — shape (tap vs hold, ramp vs
   snap) decides at that point.
2. **Hold-E hovertext window.** Hovertext appears after some hold
   duration — what threshold? Probably ~150ms.
3. **F in dialogue vs F in sim.** When dialogue is open during a running
   sim, does F page the text AND clear the pause, or only page? Lean
   toward page-only — text takes priority, sim pause is implicit while
   dialogue is up.
4. **QF chord discoverability.** The force-quit path only appears as a
   verb chip in the quit-confirm screen. This is correct (it should be
   hard to find accidentally), but may need a one-time tutorial note.
