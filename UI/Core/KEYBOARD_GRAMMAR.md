# SpaceWheat Keyboard Grammar

The whole game is keyboard-first. Every key has a place in the grammar
below; nothing is "hold for help" filler. This doc is canonical — when
the bindings drift, fix the bindings, not this doc.

---

## The four spatial rows

```
  4 5 6 7 8 9 0   ← archetype hat row: pick the active frame
  1 2 3           ← sub-mode within the current frame
  T Y U I O P     ← biome row: 6 biome slots (direct jump)
  G H J K L ;     ← plot row: 6 plot slots (direct jump)
  W A S D         ← crawl pad: ±1 step in the biome × plot grid
```

- **`4`–`9, 0`** select the **archetype frame** (the outermost level of the
  keyboard hierarchy — see `docs/ARCHETYPE_FRAMES.md`):
  `4`=Spark (pole shift: spend pole emoji → shove qubit),
  `5`=Icon (icon-injection from your faction signature),
  `6`=Socialite (faction contracts: drain=treaty/transfer=broker/pump=tribute),
  `7`=Captain (biome lifecycle: discover/cull),
  `8`=Scientist (probe: explore/measure/pop),
  `9`=Operator (gate building: build/inspect/break),
  `0`=Druid (Unitary: X/Y/Z rotations, Hadamard).
  Re-pressing the active hat toggles back to **Ace** (no hat = default toolkit).
- **`1`–`3`** select the **sub-mode within the current frame**.
  Frames with fewer sub-modes ignore unused slots; frames with more
  expose the rest via Tab.
- **`T-Y-U-I-O-P`** = direct-jump to biome slot 1–6.
- **`G-H-J-K-L-;`** = direct-jump to plot slot 1–6 within the active biome.
  (Left-to-right; diverges from the legacy right-to-left HOMEROW_KEYS index.)
- **`W A S D`** crawls the biome × plot grid by ±1, mirroring menu nav:
  - `A` / `D` = previous / next plot in the active biome
  - `W` / `S` = previous / next biome
- **`'`** = select / clear all (gameplay + future menu bulk-select).

---

## The QERF cross — verb grammar

Two orthogonal axes on the keyboard's QERF cluster. The horizontal axis
selects the **item**; the vertical axis selects the **flow of time** on
that item.

```
              F   (play / forward / flatten)
              ↑
   Q  ← ← ←   ●   → → →  R     (item axis: out / less / retreat  |  in / more / advance)
              ↓
              E   (pause / inspect / expand)
```

### The two axes

- **Q ↔ R — the item axis.** Lateral movement across whatever's in front
  of you. Q retreats, less, screw-out. R advances, more, screw-in. Same
  in tools, same in menus.
- **E ↕ F — the time axis.** E stops the world to look at it (expands,
  opens, freezes). F lets the world move again (plays, flattens, flows).
  They are exact opposites on the same axis — the same gesture, flipped.

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

**Physical note:** R and F are adjacent on the keyboard — both sit on the
right side of the QERF cluster. They are the "go" keys. Q and E are on the
left / down side — the "stop and look" keys. The keyboard topology reflects
the grammar.

### E — pause / inspect / expand

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

### F — play / forward / flatten

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

### Live-frame QERF (per `Core/GameState/ToolConfig.gd`)

The table is descriptive, not prescriptive — when a verb is empty,
that's fine; E still pauses regardless. Socialite is a placeholder
today — its hat key selects the frame but Q/E/R sit empty until wired.

| Hat | Frame      | Sub-mode               | Q (out/less)  | E (pause + inspect)   | R (in/more)   | F (play/flatten) |
|----|------------|------------------------|---------------|-----------------------|---------------|------------------|
| 4  | Spark      | shift                  | S.Pole (↓1×)  | Cost preview (pause)  | N.Pole (↑1×)  | (global F)       |
| 5  | Icon       | inject                 | Add Icon      | (open picker; pause)  | Trim Icon     | (global F)       |
| 6  | Socialite  | thermal / dephase / damp | Treaty 🧺  | Broker 🤝             | Tribute 📜    | Tip 💬           |
| 7  | Captain    | biomes                 | Discover      | (open picker; pause)  | Cull          | (global F)       |
| 8  | Scientist  | probe                  | Explore       | Measure               | Pop           | (global F)       |
| 9  | Operator   | gate                   | Build gate    | Inspect               | Break gate    | (global F)       |
| 0  | Druid      | X / Y / Z              | rot−          | Hadamard              | rot+          | (global F)       |

F is handled globally by PlayerShell — frames don't define a per-mode F
verb. The only way a per-frame F appears is if a frame genuinely has a
verb that wants to ride the play-axis, which is rare by design.

### Menu QERF

- **Q** — previous item / retreat. In an action menu: the "lesser" or
  "safer" variant of the current action (e.g., save before quitting).
  Screw out — moving away from the simulation.
- **R** — next item / advance / commit. In an action menu: the affirmative
  verb (e.g., save and resume). Screw in — moving back into the
  simulation or committing to the next state.
- **E** — pause + expand: open detail / hovertext on the focused item.
  The chip reflects what is under the cursor; the pause is the
  global side-effect.
- **F** — flatten if E has opened a detail panel; page forward through
  any text currently visible; otherwise honest empty ("—"). Never "back."

Menus do not define their own "back." See "Going back" below.

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
- **ZXCVBNM (the top-level menu ring)**: pressing any one of these
  *abandons* whatever you were doing in the current overlay and swaps
  to the new view. There is no risk of being trapped in a deep stack
  because every top-level key is an unconditional teleport. The
  combination of "ESC unwinds" + "ZXCVBNM swaps" makes a dedicated
  back key unnecessary.

`,` / `.` cycle through the menu ring without leaving it; `[` / `]`
cycle frames within an open surface.

---

## Pagination and surface cycling

- **`[` / `]`** cycle the active surface's `frame_ids` (and biomes
  when no surface is open). PlayerShell routes these.
- **`,` / `.`** cycle through top-level menu overlays.
- **`Tab`** cycles the **sub-mode within the current frame** in the
  live game. Direct sub-mode pick is on `1`-`3`.
- **`F`** does not appear in this list. F is a verb (play / flatten);
  navigation belongs to brackets, commas, and Tab.

---

## Modifiers

- **`Shift + Q/E/R`** applies the verb to **every checked plot at once**
  (bulk).
- **`Shift + ±/=`** changes resolution (finer / coarser substeps).
- **`Shift + R`** = "Mass Pop" (alias for shift+R bulk).

---

## Reserved / out-of-grammar

- **`ESC`**: close the topmost overlay (back one level). Repeat to
  unwind the whole stack. In the main game, ESC opens X (the system
  menu). This is the only "back" key — F does not unwind.
- **`Enter` / `Space`**: confirm / activate the selected item in menus.
- **`Backspace`**: unbound (reserved for future).

---

## Why this grammar

The four spatial rows give the player a consistent geometry: the top
hat row (`4`-`0`) picks an archetype frame, `1`-`3` picks a sub-mode
within that frame, biome row picks a world, plot row picks a target,
WASD crawls between them. The QERF cross gives a consistent set of
verbs: Q/R on the item axis, E/F on the time axis.

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

Sub-mode cycling lives on Tab + direct numbers (`1`-`3`) because F has
a real semantic (play / flatten) and cannot be a navigation key.
Pagination already has `[` / `]` and `,` / `.` — adding F to that list
would be one key doing three unrelated jobs.

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
4. **Z reframe.** Balance frame moves from X to Z; Z grows character
   sheet / tutorial / social. Mechanical refactor in a separate pass;
   see `project_z_personal_space.md` memory.
5. **QF chord discoverability.** The force-quit path (QF) is not
   surfaced anywhere during normal play — only appears as a verb chip
   in the quit-confirm screen. This is correct (it should be hard to
   find accidentally), but may need a one-time tutorial note.
