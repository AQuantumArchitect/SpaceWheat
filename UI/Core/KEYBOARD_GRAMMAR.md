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
  `4`=Spark, `5`=Icon, `6`=Socialite, `7`=Captain, `8`=Scientist,
  `9`=Operator, `0`=Druid. Re-pressing the active hat toggles back to
  **Ace** (no hat = default toolkit).
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

## The QERF cross — verb grammar

Two orthogonal axes on the keyboard's QER cluster. The horizontal axis
selects the **item**; the vertical axis selects the **flow of time** on
that item.

```
              F   (play / advance / proceed / pulse-fast / page-text)
              ↑
   Q  ← ← ←   ●   → → →  R     (item axis: prev / next, less / more)
              ↓
              E   (pause / inspect / hold / hovertext / freeze)
```

### The two axes

- **Q ↔ R — the item axis.** Lateral movement across whatever's
  in front of you. Q retreats, less, undo-ish. R advances, more,
  apply-ish. Same in tools, same in menus.
- **E ↕ F — the time axis.** E stops the world to look at it.
  F lets the world keep going (or makes it go faster, or pages it
  forward when there is text). They are opposites on the same axis,
  not unrelated keys.

### E — pause / inspect / hold

E is wired at the **PlayerShell** level: any E press pauses the live
simulation. That's a global truth, not something each tool re-implements.
Holding E shows hovertext / detail. The simulation un-pauses on the next
non-E action (R, a number key, F, etc.) or explicitly via F.

This means E in a tool can mean *both* the verb the tool defines AND a
pause. Examples that emerge naturally:

- **Tool 1 E = Hadamard** also pauses the sim. Apply a Hadamard, the
  world freezes, you read what just happened.
- **Tool 3 probe E = Measure** also pauses. Collapse the state, freeze,
  observe.
- **Tool 2 E = Transfer** also pauses. Move population, freeze on the
  result.

A tool may legitimately leave E **empty** ("just pause, no other action").
The simulator is sparse on purpose; the control scheme is allowed to be
sparse too. An empty E slot is honest, not a placeholder.

### F — play / forward / page

F is the play half of the time axis. Today it does one thing at the
PlayerShell level — clear the pause flag — and leaves "go faster" as
a future per-view action.

- **Sim is paused** → F resumes normal-speed evolution.
- **Sim is running** → F is a no-op at the shell level. A specific
  surface or tool may bind F to "pulse / fast-forward / advance one
  phrame" later as a view-level action.
- **Text or dialogue overlay is open** → F pages forward through it.
  ("Press F to continue.") This is a per-overlay binding, not a
  shell primitive.

F is never "back," never "drill out," never "cancel," never pagination.

### Q and R

Item axis, unchanged from the prior pass:

- **Q** — previous / less / retreat. In tools: rotate−, drain, explore.
  In menus: previous item, confirm-back, etc.
- **R** — next / more / advance. In tools: rotate+, pump, pop.
  In menus: next item, commit, advance.

### Live-frame QERF (per `Core/GameState/ToolConfig.gd`)

The table is descriptive, not prescriptive — when a verb is empty,
that's fine; E still pauses regardless. Frames not listed (Icon,
Socialite, Operator) are placeholders today — their hat keys select
the frame but Q/E/R sit empty until wired.

| Frame | Sub-mode | Q (less) | E (pause + inspect) | R (more) | F (play / pulse) |
|---|---|---|---|---|---|
| 4 Spark     | X / Y / Z              | rot−       | Hadamard             | rot+        | (global F) |
| 0 Druid     | thermal/dephase/damp   | drain      | Transfer             | pump        | (global F) |
| 8 Scientist | probe                  | Explore    | Measure              | Pop         | (global F) |
| 8 Scientist | gate                   | Build gate | Inspect              | Break gate  | (global F) |
| 7 Captain   | signature              | Add icon   | (open picker; pause) | Remove      | (global F) |
| 7 Captain   | biomes                 | Discover   | (open picker; pause) | Cull        | (global F) |

F is handled globally by PlayerShell — frames don't define a per-mode F
verb. The only way a per-frame F appears is if a frame genuinely has a
verb that wants to ride the play-axis, which is rare by design.

### Menu QERF

- **Q** — previous item / back-within-surface.
- **R** — next item / commit / advance.
- **E** — pause + open detail / hovertext on focused item. If a
  surface offers an "open detail" affordance for the focused item, E
  opens it. Pause is the global side-effect.
- **F** — page forward through any text or dialogue currently visible.
  In a static menu with no text to page, F is a no-op.

Menus do not define their own "back." See "Going back" below.

## Mechanics — side-effect peek (E and F)

E and F are the first **overloaded** keys in the grammar: their primary
meaning (the per-tool / per-menu verb) and their secondary meaning (the
global pause / play side-effect) both have to fire from the same press.
Today every other key follows an exclusive consume-or-fall-through
pattern. E and F break that, and they need a different dispatch shape.

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
action that some surface might offer; PlayerShell stays pure pause/
play.

### Properties

- **The peek doesn't consume.** Pressing E during Tool 1 still fires
  Hadamard *and* freezes the world. Pressing E with the X menu open
  fires X's `_on_action_e` (drill into the focused item) *and* freezes
  the world underneath.
- **The peek runs before consumption.** Even if a downstream layer
  swallows the event, the side-effect already happened. Pause is a
  global truth — it shouldn't be gated on whether anything wanted the
  primary verb.
- **Tools and menus stay unchanged.** No tool code knows about pause.
  No menu code knows about pause. The pause flag is read by whoever
  drives the sim tick (`Farm._physics_process` or sibling), and that's
  the only consumer.

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
surprises later when pressing 1 to switch tools resumes the sim. Ship
strict; relax later if playtesters get stuck.

### Why this is the first overloaded command

Most of the keyboard maps one key → one meaning. E breaks that because
"freeze the world to look" is genuinely orthogonal to "fire the verb
that makes information happen." They're two compatible meanings on the
same press, and the peek pattern is the cleanest way to express that.

Once this lands, the same pattern is available for any future
overloaded key (e.g., a hold-shift modifier that adds a side-effect to
whatever it's pressed alongside). Peek-then-dispatch is the primitive.

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

## Pagination and surface cycling

- **`[` / `]`** cycle the active surface's `frame_ids` (and biomes
  when no surface is open). PlayerShell routes these.
- **`,` / `.`** cycle through top-level menu overlays.
- **`Tab`** cycles the **sub-mode within the current frame** in the
  live game. Direct sub-mode pick is on `1`-`3`.
- **`F`** does not appear in this list. F is a verb (play / advance);
  navigation belongs to brackets, commas, and Tab.

## Modifiers

- **`Shift + Q/E/R`** applies the verb to **every checked plot at once**
  (bulk).
- **`Shift + ±/=`** changes resolution (finer / coarser substeps).
- **`Shift + R`** = "Mass Pop" (alias for shift+R bulk).

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
WASD crawls between them. The QERF cross gives them a consistent set
of verbs: Q/R on the item axis, E/F on the time axis.

The time axis matters because SpaceWheat is a **continuous physics
simulation**, not a turn-based puzzler. The player needs first-class
controls for "stop and look" and "go and proceed." Putting those on
adjacent keys (E and F) so they share a finger is the point — pause
and unpause should feel like the same gesture flipped, because that's
what they are.

E pausing the sim *as a side-effect of every E action* is the
elegance: Hadamard a qubit and the world freezes so you can read the
new state; Measure a register and time stops on the outcome. The verb
and the pause are the same press. You don't have to remember to pause
before inspecting.

The simulator is intentionally sparse — most plots are doing little or
nothing at any given moment. The control scheme matches that posture:
empty Q / R / E slots are not bugs, they're honesty about what a tool
can do in a given mode. **An empty E slot still pauses.** That's a
useful action by itself.

ESC and the ZXCVBNM ring eliminate the need for a "back" verb on QERF.
ESC unwinds; the ring teleports. Two distinct gestures, neither of
which has to share keys with the action grammar.

Sub-mode cycling moves to Tab + direct numbers (`1`-`3`) because
**F has a real semantic now** (play / advance) and can't be a
navigation key. Pagination already has `[` / `]` and `,` / `.` —
three keys for one job is two too many.

The archetype hat row (`4`-`0`) sits *above* the sub-mode row in the
keyboard hierarchy: a hat picks the active frame; the sub-mode keys
pick what `1`/`2`/`3` + QERF do *inside* that frame. Pressing the
active hat again toggles back to **Ace** (default toolkit), so the
hat row doubles as the on/off switch for any narrowing lens.

---

## Open questions

These are deferred but flagged. Pick them up when wiring touches
PlayerShell-level pause/play.

1. **F pulse / fast-forward as a view-level action.** PlayerShell F
   is classical (clear pause). "Pulse / fast-forward / advance one
   phrame" is left for a specific view to wire as its own binding —
   shape (tap vs hold, ramp vs snap) decides at that point.
2. **Hold-E hovertext window.** Hovertext appears after some hold
   duration; what's the threshold? Too short = noisy; too long =
   discoverability cost. Probably ~150ms.
3. **F in dialogue vs F in sim.** When dialogue is open during a
   running sim, does F page the text AND pulse the sim, or only page
   the text? Lean toward "page-only" — text takes priority, sim pause
   is implicit while dialogue is up.
4. **Z reframe.** Balance frame moves from X to Z; Z grows character
   sheet / tutorial / social. Mechanical refactor in a separate pass;
   see `project_z_personal_space.md` memory.
