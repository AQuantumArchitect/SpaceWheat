# SpaceWheat Keyboard Grammar

The whole game is keyboard-first. Every key has a place in the grammar
below; nothing is "hold for help" filler. This doc is canonical for the
binding model, but if it conflicts with newer runtime code, newer overlay
comments, or fresher timestamps, treat the newer source as authority and
update this doc on the next pass.

---

## Eight keys, four axes

The grammar resolves into **four orthogonal 1D axes**, with eight keys
(QERF + WASD) covering them. Every menu, every tool, every surface uses
the same eight keys with the same axial meaning. What differs per
surface is *what content lives along which axis*, never which key
navigates.

```
                       F   (t axis: time forward / play / flatten)
                       ↑
   Q ← ← ←   ●   → → → R     (depth axis: screw out / screw in)
                       ↓
                       E   (t axis: time stop / inspect / snapshot)

                       W   (selection axis: move OUTWARDS one layer)
                       ↑
   A ← ← ●  → → D            (selection axis: step prev / next ACROSS the focused layer)
                       ↓
                       S   (selection axis: move INWARDS one layer)
```

- **A ↔ D** — step prev / next across the focused selection layer
  (the layer the cursor is currently parked on).
- **W ↔ S** — move the cursor outward / inward across the nested
  selection hierarchy (4-0 hat → TYUIOP biome → GHJKL; plot).
- **Q ↔ R** — depth, screwed via the right-hand rule. Q = screw out
  / one level shallower. R = screw in / one level deeper. **Not list
  navigation** — picking items lives on WASD.
- **E ↔ F** — temporal axis. E stops time and snapshots; F lets
  time flow and flattens the snapshot.

Three orthogonal 1D flows (selection-layer-cursor + step-across,
information-depth, time) cover the geometry. The "4D" framing is
metaphorical — Q/R is not a physical z-axis, it's information depth.
What matters is that no two keys do the same job.

---

## The four spatial rows

```
  1 2 3           ← sub-mode (axis selector for Q/R; action layer)
  4 5 6 7 8 9 0   ← outer selection: hat / archetype scope
  T Y U I O P     ← middle selection: biome row (6 slots, direct jump)
  G H J K L ;     ← inner selection: plot row (6 slots, direct jump)
  W A S D         ← crawl the 3-tier selection (W out / S in / A,D across)
```

- **`4`–`9, 0`** select the **archetype hat** (see
  `docs/ARCHETYPE_FRAMES.md`). The hat carries **two roles** that the
  player presses one row of keys for:
    *Action role* — picks the active toolkit verbs (Q/E/R/F mapping):
    `4`=Spark, `5`=Icon, `6`=Merchant, `7`=Captain, `8`=Ace,
    `9`=Operator, `0`=Druid.
    *Selection role* — the OUTERMOST tier of the 3-tier selection
    hierarchy (4-0 / TYUIOP / GHJKL;). Future: also gates which biomes
    appear in the TYUIOP pool, so the hat is a "world view."
  Sticky in both senses. Re-pressing the active hat toggles back to
  **Ace** (no hat = default toolkit).
- **`1`–`3`** select the **sub-mode within the current frame** — i.e.,
  which axis the depth verbs `Q/R` operate along (see *Action × Selection
  algebra* below). `E/F` stays on the time axis regardless of sub-mode.
- **`T-Y-U-I-O-P`** = MIDDLE selection. At gameplay, biome slot 1–6.
  At an open surface, frame slots 1–6 within that surface.
- **`G-H-J-K-L-;`** = INNER selection. At gameplay, plot slot 1–6
  within the active biome. At a surface, item slots within the active
  frame. (Left-to-right; diverges from the legacy right-to-left
  HOMEROW_KEYS index.)
- **`W A S D`** crawls the 3-tier selection block:
  - `W` / `S` = move the cursor OUTWARDS / INWARDS across the
    layer hierarchy (plot ↔ biome ↔ hat).
  - `A` / `D` = step prev / next ACROSS the focused layer.
  - WASD covers the whole 4-0 / TYUIOP / GHJKL; block, so
    `[ / ]` is not needed for selection cycling and is unbound.
- **`'`** = bulk select / clear all in the inner layer (all plots in
  the active biome; future menu bulk-select).
- **`-`** / **`=`** = simulation granularity / speed
  (slow-down / speed-up). See *Modifiers* below for shift-modifier
  variants.

---

## Action × Selection algebra

Every player input is a composition of two orthogonal layers:

```
  ACTION:    (axis: 1-3)  (verb: Q E R F)
  SELECTION: (outer: 4-0)  (middle: T Y U I O P)  (inner: G H J K L ;)
```

The action layer answers *what verb am I firing*. The selection layer
answers *what am I firing it at*. The composition reads "do X to Y."
Both layers are sticky: pick once, then keep firing — only the verb
needs a fresh keypress per action.

### Action layer

```
  1 2 3       sub-mode within the active hat. Selects WHICH AXIS the
              depth verbs Q/R operate on. Sticky. Frames with fewer
              sub-modes ignore unused slots.

  Q E R F     the verb quartet:
                Q ↔ R   depth (screw out / screw in)
                         REMAPPED by the 1/2/3 sub-mode.
                E ↕ F   time (pause+inspect / play+flatten)
                         INVARIANT — sub-mode does NOT remap E/F.
```

Action-space size in the live game:

```
  3 sub-modes × 2 (Q vs R) per hat   =  6 depth verbs per hat
  7 hats × 6                          = 42 archetypal verbs
  + the always-on E/F pair on top of every one of them
```

### Selection layer (3 nested tiers)

```
  4 5 6 7 8 9 0   OUTER  — hat / archetype scope. Sticky.
                  Currently selects the active toolkit (the action
                  layer's "frame"). Future: also gates which biomes
                  appear in the TYUIOP pool, so the hat is the player's
                  "world view" — both what verbs are available AND what
                  subject matter is in scope. The hat row carries
                  this dual role on a single keystroke.

  T Y U I O P     MIDDLE — biome row at gameplay; frame slots inside an
                  open surface. Sticky.

  G H J K L ;     INNER  — plot row inside the active biome at gameplay;
                  item slots inside the active frame in a surface.
                  Sticky.

  W A S D         crawl pad — navigates the layer cursor and steps
                  within the focused layer:
                    W   move cursor OUTWARDS    (plot → biome → hat)
                    S   move cursor INWARDS     (hat → biome → plot)
                    A   step PREV across the focused layer
                    D   step NEXT across the focused layer
```

WASD covers the entire 3-tier selection block — there is no separate
cycle pair for it. Direct-jump on a row key teleports the cursor to
that layer and slot in one keystroke; WASD is the gradual / explicit
alternative.

### Frame-local TYUIOP override

Surfaces normally use TYUIOP to direct-jump between their frames
(T = first frame, Y = second, etc.). A frame whose explicit purpose is
to manipulate the TYUIOP axis itself — e.g., binding biomes to TYUIOP
slots in N's Map frame — consumes TYUIOP for content selection instead.
The recursion is intentional: the frame for editing TYUIOP is *addressed
by* TYUIOP.

To exit such a frame, use WASD: `W` moves the cursor OUTWARDS to the
surface-frame layer, then `A`/`D` steps to a sibling frame.
Alternatively `ESC` closes the surface entirely.

This is the rare exception. Most surfaces leave TYUIOP on its default
frame-jump duty.

---

## The QERF action quartet — four primary actions

QERF is the primary action row. `QER` as the primary concept is
deprecated; the player now reads the full four-chip cluster: `Q`, `E`,
`R`, and `F`. Surfaces fill these chips with local verbs, and a chip may
legitimately be empty (`—`) when that surface has nothing to say there.
The row still resolves onto the same two axes, but the UI contract is
four actions, not three. The other two axes (x and y) still ride WASD,
see *Six keys span 4D* above.

```
              F   (play / forward / flatten)
              ↑
   Q  ← ← ←   ●   → → →  R     (z axis: screw out / less depth | screw in / more depth)
              ↓
              E   (pause / inspect / snapshot)
```

### The two axes under the quartet

- **Q ↔ R — the depth/screw axis (z).** Right-hand rule. Q = screw out,
  shallower, retreat, remove, import. R = screw in, deeper, commit,
  add, export. **Not list navigation** — picking items lives on WASD.
  Same screw motion in tools and menus.
- **E ↕ F — the time axis (t).** E stops the world to look at it
  (snapshot, freeze, expand, inspect, broker). F lets the world move
  again (play, flow, flatten, page, force-commit in confirm screens).
  Exact opposites on the same axis.

### Q and R — the right-hand rule

Think of a screw. Right-hand rule: curl the fingers of your right hand
around the barrel, thumb pointing away from you.

- **Fingers curl right → thumb points away = screw IN** = **R**. You are
  entering, committing, advancing. Going deeper into the simulation. Save
  and resume (go back in). Rotate+. Pump. Pop.
- **Fingers curl left → thumb points toward you = screw OUT** = **Q**. You
  are leaving, retreating, undoing. Stepping out of the simulation. Quit.
  Rotate−. Drain. Explore (surface a terminal to look at, not to fire).

The screw mnemonic makes the axis viscerally spatial, not abstract. When
you press Q you are physically turning the world counter-clockwise. When
you press R you are threading yourself in. This is why "quit" lives on Q
and "resume" lives on R: quit = unscrew yourself from the session; resume
= screw back in.

**Q/R is not list navigation.** Stepping between items in a card grid,
between rows in a table, or between slots in a row uses **WASD** — A/D
to step across the focused layer, W/S to move outwards/inwards across
the selection hierarchy. Q/R operates orthogonally on the *depth* axis:
open the focused thing's interior with R, back out with Q. A surface
that wires Q/R to "previous / next item" is conflating the depth axis
with the selection layer — fix the binding, not the doc.

**Allowed exception — 2D viewport view-control.** When a surface frame
is itself a 2D viewport (M's Atlas page renders a biome × faction
cluster), Q/R may adjust orbit / pan / zoom locally. The verbs are
acting on a continuous view, not on a list — the depth/screw metaphor
still applies (R = zoom in / pull closer; Q = zoom out / push away).
List-stepping on Q/R remains forbidden everywhere.

**Physical note:** R and F are adjacent on the keyboard — both sit on the
right side of the QERF cluster. They are the "go" keys. Q and E are on the
left / down side — the "stop and look" keys. The keyboard topology reflects
the grammar.

### E — pause / inspect / expand / broker

E is wired at the **PlayerShell** level: any E press pauses the live
simulation. That's a global truth, not something each tool re-implements.
Holding E shows hovertext / detail. The simulation stays paused until F
explicitly unpauses it.

This means E in a tool can mean *both* the verb the tool defines AND a
pause. Examples that emerge naturally:

- **Tool 1 E = Hadamard** also pauses the sim. Apply a Hadamard, the
  world freezes, you read what just happened.
- **Tool 3 probe E = Measure** also pauses. Collapse the state, freeze,
  observe.
- **Tool 2 E = Transfer** also pauses. Move population, freeze on the
  result.

In menus, E **expands** the focused item — opens a detail panel, surfaces
hovertext, drills one level in. The global pause is the side-effect; the
expansion is the primary verb.

A surface may legitimately leave E **empty** ("just pause, no expansion").
An empty E slot is honest, not a placeholder. The simulator is sparse on
purpose; the control scheme matches that posture.

### F — play / forward / flatten / page

F is the play half of the time axis and the complement of E. Wherever E
**opens** something, F **closes** it. They are the same gesture, flipped.

- **Sim is paused** → F resumes normal-speed evolution.
- **Sim is running** → F is a no-op at the shell level. A specific
  surface may bind F to "pulse / fast-forward / advance one phrame" as
  a view-level action.
- **Text or dialogue overlay is open** → F pages forward through it.
  ("Press F to continue.") Per-overlay binding, not a shell primitive.
- **E has opened a detail panel in a menu** → F **flattens** it (collapses
  back to the base view). The F chip shows "flatten" only when there is
  something to collapse; otherwise it shows "—" (honest empty).

The flatten behavior follows directly from F being E's opposite on the time
axis. You don't need to remember a separate "close detail" binding — F is
already there, already means "return to flow."

**F is never "back," never "drill out," never "cancel," never navigation.**
Those belong to ESC and the ZXCVBNM ring. F is always about the direction
of time or the depth of information: forward, flowing, flat.

### Live-frame action quartet (per `Core/GameState/ToolConfig.gd`)

The table is descriptive, not prescriptive — when a verb is empty,
that's fine; the chip still exists and the row still has four slots.
Merchant and Ace are the current frame names; older Socialite/Scientist
labels are stale.

| Hat | Frame      | Sub-mode               | Q (out/less)  | E (pause + inspect)   | R (in/more)   | F (play/flatten) |
|----|------------|------------------------|---------------|-----------------------|---------------|------------------|
| 4  | Spark      | shift                  | S.Pole (↓1×)  | Cost preview (pause)  | N.Pole (↑1×)  | (global F)       |
| 5  | Icon       | inject                 | Add Icon      | (open picker; pause)  | Trim Icon     | (global F)       |
| 6  | Merchant   | thermal / dephase / damp | Treaty 🧺  | Broker 🤝             | Tribute 📜    | Tip 💬           |
| 7  | Captain    | biomes                 | Discover      | (open picker; pause)  | Cull          | (global F)       |
| 8  | Ace        | probe                  | Explore       | Measure               | Pop           | (global F)       |
| 9  | Operator   | gate                   | Build gate    | Inspect               | Break gate    | (global F)       |
| 0  | Druid      | X / Y / Z              | rot−          | Hadamard              | rot+          | (global F)       |

F is handled globally by PlayerShell — frames don't define a per-mode F
verb. The only way a per-frame F appears is if a frame genuinely has a
verb that wants to ride the play-axis, which is rare by design.

### Menu action quartet — depth and time, never item nav

In a menu surface the four action chips resolve as:

- **Q — screw OUT.** Drill out of the focused item back to the parent
  level. At the top level (no drill open), Q is the surface-level
  "retreat" — the safe variant of an action (e.g., save before
  quitting). Always screw-out, never "previous item."
- **R — screw IN.** Drill into the focused item to the next level
  deeper. In an action menu: the affirmative commit (e.g., save and
  resume). Always screw-in, never "next item."
- **E — stop time + snapshot.** Open the focused item's detail panel
  / hovertext. Sim pauses globally as a side effect; the panel is the
  primary verb. Transient — paired with F.
- **F — let time flow + flatten.** Closes any E-snapshot, pages forward
  through visible text, or empty ("—"). Never "back," never
  navigation.

**Items are picked with WASD, not Q/R.** A/D step the cursor along x;
W/S step along y. Direct-jump strips (TYUIOP for biome row, GHJKL; for
plot row) teleport along whichever axis the surface assigns them to.

**Q-drill-out vs F-flatten — two ways to close.** They are different
axes:

| Close via | Closes what | Why |
|---|---|---|
| **Q** | the *deepest* R-drill (one level) | screw-out is the inverse of R's screw-in |
| **F** | any open E-snapshot | flatten is the inverse of E's expand |
| **ESC** | the entire overlay | back-out the whole stack one level |

A menu may legitimately use the same UI for both R-drill and E-snapshot
when it has only one inner level — but the closing key the player uses
should match the axis the player opened with. The chips advertise
both.

Menus do not define their own "back" key. See *Going back* below.

---

## Confirm modal grammar

When a dangerous or irreversible action is triggered (quit, restart, full
reset), the surface enters a **confirm state** rather than executing
immediately. The confirm state has its own verb grammar built on a single
principle: **the trigger key becomes the safe commit**.

### Trigger-key pattern

1. Press the trigger key (e.g., Q = quit). → Confirm screen appears.
2. In the confirm screen:
   - **Trigger key again (Q)** = safe commit: do the thing, but carefully
     (autosave first, then execute). Double-tapping the trigger = the
     gentle version.
   - **F** = force commit: do the thing without any ceremony (no save, no
     hesitation). This is the **QF chord** — Q to enter, F to fire. Two
     deliberately separated key regions.
   - **R** = resume: right-hand rule, screw back in. The physical opposite
     of the trigger. Go back to what you were doing.
   - **E** = cancel: pause and reconsider. Inspect the decision and choose
     not to act.

### The QF chord

```
  trigger → confirm      safe commit   force commit   resume   cancel
     Q    →  [screen]  :     Q          F              R        E
```

QF (Q then F) is the "quit without saving" path. The chord requires two
distinct keystrokes in two different keyboard regions — left side to enter
the confirm, right side to fire. The physical distance encodes the weight
of the decision. Accidental fire requires crossing the whole cluster.

Compare to double-tap Q (QQ): both keys are on the same side, fast and
comfortable. QQ is the *safe* version — save first, then quit. QF is the
*hard* version — no save, just go. The keyboard forces you to reach.

F as the force-commit key is also grammatically consistent: F = forward =
"push through without looking back." The dangerous choice and the play
button are the same verb, applied to an irreversible decision.

### Confirm verb labels

| Pending action | Q             | E        | R        | F                    |
|----------------|---------------|----------|----------|----------------------|
| Quit           | save & quit   | cancel   | resume   | quit without saving  |
| Restart        | save & restart| restart anyway | cancel | —              |
| Full reset     | confirm reset | —        | cancel   | —                    |
| Reset settings | confirm reset | —        | cancel   | —                    |

F only appears on Quit because only Quit has a meaningful "force" variant
that's distinct from the safe commit. Full reset and reset settings have no
pre-existing state to preserve, so there is nothing to skip.

---

## Mechanics — side-effect peek (E and F)

E and F are the first **overloaded** keys in the grammar: their primary
meaning (the per-tool / per-menu verb) and their secondary meaning (the
global pause / play side-effect) both have to fire from the same press.
Every other key follows an exclusive consume-or-fall-through pattern. E
and F break that, and they need a different dispatch shape.

### The peek-then-dispatch pattern

`PlayerShell._input()` peeks at the event before the existing exclusive
chain runs. The peek fires the side-effect (set paused / clear paused)
but does **not** call `set_input_as_handled()` and does **not** return.
The event then continues through the normal dispatch chain — overlays,
shell actions, then `Farm._unhandled_input` → `QuantumInstrumentInput`
— exactly as today. Whoever was going to handle E (a menu's
`_on_action_e`, or the live tool's `_perform_action("E")`) still gets
it.

```
PlayerShell._input(event):
    # 1. Side-effect peek — observe E / F without consuming.
    if e_pressed_this_event(event):
        _set_global_paused(true)
        # NO set_input_as_handled, NO return — keep going
    elif f_pressed_this_event(event):
        _set_global_paused(false)
        # NO set_input_as_handled, NO return — keep going

    # 2. Existing exclusive dispatch (unchanged):
    if overlay_stack.route_input(event): consume → return
    if _handle_shell_action(event):     consume → return
    # else: falls to Farm._unhandled_input → QuantumInstrumentInput
    # which fires Tool 1 E = Hadamard etc. as today.
```

Shipped today: the PlayerShell peek is **classical** — E sets `paused
= true`, F sets `paused = false`. No pulse / no fast-forward at the
shell level. "Pulse the sim faster" is left as a future view-level
action that some surface might offer; PlayerShell stays pure pause/play.

### Properties

- **The peek doesn't consume.** Pressing E during Tool 1 still fires
  Hadamard *and* freezes the world. Pressing E with the X menu open
  fires X's `_on_action_e` (expand the focused item) *and* freezes
  the world underneath.
- **The peek runs before consumption.** Even if a downstream layer
  swallows the event, the side-effect already happened. Pause is a
  global truth — it shouldn't be gated on whether anything wanted the
  primary verb.
- **Tools and menus stay unchanged.** No tool code knows about pause.
  No menu code knows about pause. The pause flag is read by whoever
  drives the sim tick (`Farm._physics_process` or sibling).

### Where the pause flag lives

A `paused: bool` on **PlayerShell** with a `paused_changed(is_paused)`
signal. `Farm._physics_process` checks `_is_globally_paused()` first
and short-circuits when true (caches the PlayerShell ref the first
time it's resolved). Setter:

- `_set_global_paused(value)` — idempotent; emits `paused_changed`
  on transition. Called by E peek (true) and F peek (false).

### Unpause discipline

Strict: only F unpauses. Other keys (Q, R, numbers, Tab, navigation)
do **not** auto-unpause. The player explicitly chooses pause and play.
This is predictable; the alternative ("any non-E unpauses") creates
surprises when pressing 1 to switch tools resumes the sim. Ship strict;
relax later if playtesters get stuck.

---

## Going back — ESC and the ZXCVBNM ring

There is no QERF "back" key. Two paths instead:

- **ESC** closes the topmost overlay. Hit ESC enough times and you're
  back in the main game. In the main game, ESC opens the system menu.
- **ZXCVBNM (the top-level menu ring)**: the ring now reads
  `Z → X → C → V → B → N → M`. Each key abandons the current overlay
  and swaps to its surface directly. There is no risk of being trapped
  in a deep stack because every top-level key is an unconditional
  teleport. `ESC` unwinds; the ring swaps.
- **`N → C` is a deliberate two-step loop.** `N`'s Network page selects a
  relation and seeds scope; the selector page is a browseable atlas. `C`
  consumes the pending scope on open and shows the contract board for that
  relation, or falls back to current-biome scope when no handoff exists.
  The N/C status readouts expose the selected edge and scope source so the
  player can tell handoff from fallback at a glance.
- **`M`'s Atlas page is a local exception.** `Q` / `R` zoom and rotate the
  biome × faction cluster view only when `M` is on its Atlas page. That does
  not change the global QERF grammar; it is surface-local view control.

`,` / `.` cycle through the menu ring (Z X C V B N M sibling surfaces)
without leaving the open one. WASD covers within-surface navigation
(crawl the 3-tier selection block); the row keys (4-0 / TYUIOP /
GHJKL;) direct-jump to a slot.

### Surface roles

- **Z** (and ESC) is the **system surface** (EscapeMenu) — Run / Keep /
  New / Levels / Dev. Save/load, scenarios, settings, dev tools.
- **X** is the **playthrough/self surface** — Self / Story / Verbs /
  Chatter / Guide. Player faction posture, story trajectory, vocabulary,
  and how-to-play. Built on ControlsOverlay.
- **C** is the **quest pipeline** — manifold / market / commitments /
  arc. Receives pair-scope handoffs from N's Network frame.
- **V** is the context-free vocabulary atlas: atoms, icons, signatures,
  affinities, and relations, stripped of biome-local execution.
- **B** is the biome microscope: `supports` for the active plot, `whole`
  for the whole-biome summary, and `matrix` / `probabilities` /
  `subspace` / `eigen` for the math lens.
- **N** is the biome-to-biome **Lindbladian network** — Network (live
  tensor edges), Bridges (lateral structure), Map (TYUIOP slot binding),
  Live (chatter activity).
- **M** is the global biome × faction map. Cross-biome / cluster-scale
  views, not local plot analysis.

The Z↔X swap (Z = system, X = self) landed in the recent refactor;
older comments and memory entries that put the system menu on X are
stale.

---

## Pagination and surface cycling

- **`T` / `Y` / `U` / `I` / `O` / `P`** direct-jump to page slots in
  the current surface when that surface exposes enough pages. Surfaces
  with fewer pages ignore the unused slots. **Exception**: a frame
  whose explicit purpose is to manipulate the TYUIOP axis itself may
  consume TYUIOP for content selection — see *Frame-local TYUIOP
  override*. To exit such a frame use WASD (W out, A/D step) or ESC.
- **`,` / `.`** cycle through top-level menu overlays (the Z X C V B N M
  ring) without leaving the open one. Pure meta-nav between sibling
  surfaces — not a selection-layer step.
- **`Tab`** cycles the **hat** (4-0) — the same step WASD does when
  the cursor is on the frame layer, but as a one-key shortcut. The
  1-3 sub-mode row sits directly under the left hand and is fast
  enough as a direct-press; it doesn't need a cycle key.
- **`M` Atlas page** uses `Q` / `R` for orbit / zoom locally — surface-
  local view control on a 2D viewport, not list nav.
- **`[` / `]`**, **`` ` ``**, **`\\`**, **`/`** are unbound. WASD already
  covers the whole 4-0 / TYUIOP / GHJKL; selection block, so a separate
  cycle pair would be redundant; `[/]` would gain no functionality
  sitting next to TYUIOP for direct-jump anyway.
- **`F`** does not appear in this list. F is a verb (play / flatten);
  navigation belongs to commas, Tab, and WASD.

PlayerShell.gd (`UI/PlayerShell.gd:188-237`) owns the routing for
`,/.`, TAB, and WASD. Direct-jump dispatch for the row keys
(4-0 / TYUIOP / GHJKL;) lives in the active surface or in the
gameplay input handler.

---

## Modifiers

- **`Shift + Q/E/R`** applies the verb to **every checked plot at once**
  (bulk). `Shift + R` is the canonical "Mass Pop."
- **`-` / `=`** = simulation granularity / speed. `-` slows the sim
  (coarser substeps); `=` speeds it up (finer substeps). Bare keys, no
  modifier required — they sit at the right end of the number row,
  away from the action region, so accidental presses are uncommon.
- **`Shift + -` / `Shift + =`** = larger granularity step (multiplicative
  jump rather than additive).
- **`'`** (apostrophe) = bulk select / clear all in the inner layer
  (toggle). Not a modifier strictly, but it lives on the same row of
  meaning ("apply to many at once").

---

## Reserved / out-of-grammar

| Key | Role |
|---|---|
| `ESC` | Close topmost overlay (back one level). At gameplay, opens Z (system menu). The only "back" key — F does not unwind. |
| `Enter` / `Space` | Confirm / activate the selected item in menus. |
| `Backspace` | Reserved (no binding). |
| `[` / `]` | Reserved (no binding). WASD already crawls the whole selection block; `[/]` next to TYUIOP would gain no functionality. |
| `` ` `` (backtick) | Reserved (no binding). |
| `\` (backslash) | Reserved (no binding). |
| `/` (slash) | Reserved (no binding). |

The `[/]` `` ` `` `\` `/` keys are deliberately left as no-ops. WASD's
crawl + the row keys' direct-jump cover the entire selection space; an
extra cycle pair would either duplicate WASD or scatter functionality
into a less-discoverable place. Future features that need a binding
should claim from this reserved set rather than overloading an
existing key.

---

## Why this grammar

**Eight keys, four axes, one mental model on every surface.** The
grammar collapses to: WASD crawls the 3-tier selection block (W out,
S in, A/D step across), Q/R drills depth (screwed by the right-hand
rule), E/F flips the time axis (snapshot vs flow). Selection layer +
information depth + time = three orthogonal flows; WASD + QERF = eight
keys.

The four spatial rows give the player a consistent geometry: 4-0 picks
the outer scope (hat / archetype), 1-3 picks the action axis within
the active hat, TYUIOP picks the middle slot (biome or surface frame),
GHJKL; picks the inner slot (plot or item), WASD crawls between them.
The QERF quartet gives depth and time: Q/R on depth, E/F on time.

**Q and R encode direction in the world, not just on a list.** Pressing
Q unthreads you from the simulation — you are leaving, retreating,
stepping out. Pressing R threads you in — you are committing, entering,
advancing into the next state. This is why "quit" lives on Q and "save
and resume" lives on R: they are the screw-out and screw-in of the whole
session. The right-hand rule gives the player a physical anchor for an
otherwise arbitrary distinction.

**E and F are genuinely symmetric.** E opens the world — it expands a
detail panel, collapses a quantum state, freezes time so you can read
what just happened. F closes it — it flattens the panel, resumes
evolution, pages past text that's blocking the view. You don't need to
remember "E opens, [some other key] closes." F is already there, already
means "unfreeeze, move on, flatten what was expanded." The time axis is
a toggle: E takes the snapshot, F discards it and continues.

**The confirm chord encodes risk in physical distance.** Dangerous
actions require a two-key sequence with different spatial properties:
Q (left side) to enter the confirm screen, then either Q again (safe
commit — same side, comfortable, fast) or F (right side, adjacent to R
— force commit, deliberate reach). The keyboard forces the player to
cross the cluster to execute the dangerous path. No explicit "are you
sure?" dialogue is needed; the distance IS the "are you sure."

**The time axis matters** because SpaceWheat is a continuous physics
simulation, not a turn-based puzzler. The player needs first-class
controls for "stop and look" and "go and proceed." E pausing the sim
as a side-effect of every E action is the elegance: Hadamard a qubit
and the world freezes so you can read the new state; Measure a register
and time stops on the outcome. The verb and the pause are the same press.

**Empty slots are honest.** The simulator is intentionally sparse — most
plots are doing little or nothing at any given moment. The control scheme
matches: empty Q / R / E slots are not bugs, they're communication. An
empty E slot still pauses. An empty F slot means "there is nothing to
flatten and nothing to page." Showing "—" in the chip is more truthful
than hiding the chip or filling it with a placeholder verb.

ESC and the ZXCVBNM ring eliminate the need for a "back" verb on QERF.
ESC unwinds; the ring teleports. Two distinct gestures, neither of which
has to share keys with the action grammar.

Sub-mode picking lives on `1`-`3` direct-press (under the left hand,
fast enough to need no cycle key). Hat cycling lives on Tab as the
one-key shortcut; the same gesture is also reachable through WASD on
the frame layer. F stays a verb (play / flatten) and never carries
navigation; selection cycling lives on WASD + the row keys; `,` /
`.` cycles the top-level menu ring.

---

## Open questions

1. **F pulse / fast-forward as a view-level action.** PlayerShell F
   is classical (clear pause). "Pulse / fast-forward / advance one
   phrame" is left for a specific view to wire as its own binding —
   shape (tap vs hold, ramp vs snap) decides at that point.
2. **Hold-E hovertext window.** Hovertext appears after some hold
   duration; what's the threshold? Too short = noisy; too long =
   discoverability cost. Probably ~150ms.
3. **F in dialogue vs F in sim.** When dialogue is open during a
   running sim, does F page the text AND clear the pause flag, or only
   page the text? Lean toward "page-only" — text takes priority, sim
   pause is implicit while dialogue is up.
4. **QF chord discoverability.** The force-quit path (QF) is not
   surfaced anywhere during normal play — only appears as a verb chip
   in the quit-confirm screen. This is correct (it should be hard to
   find accidentally), but may need a one-time tutorial note.
