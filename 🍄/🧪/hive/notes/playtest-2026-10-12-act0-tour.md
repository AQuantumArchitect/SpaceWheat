# Playtest notes — 2026-10-12 (Luke, Windows player)

Builder brief. Fold after the live hive wave. Do not leftover-stop the Windows `SpaceWheat.exe`.

Faction name in data is **Millwright's Union** (Luke said Miller's Right Union). Same stall.

---

## 1. Gold toast stuck on Accept after the mill contract is picked up

**What happened.** On Market `[Y]`, Luke accepted the Millwright's Union contract. The gold HintToast on the right kept saying **R to Accept**. He accepted the other three offers; it still said Accept.

**What it should do.** The moment that fill-stall is in hand, the toast (and the farm banner) names **Commitments `[U]`** — go there to deliver / fulfill. Then the loop is Market `[Y]` ↔ Commitments `[U]`: pick up on Y, fill on U, back to Y.

**Where it lies today.**

- `UI/Overlays/QuestBoard.gd` `room_walk_cue()` for `FRAME_MARKET` always returns Accept if any market row is selected. It does not check `held_fill_for`.
- `UI/Core/UIProgression.gd` `_board_walk_line()` while the overlay is open prefers `room_walk_cue()` whenever `fill_shortfall_cue` is non-empty, so the honest `board_walk_cue()` / `_deliver_walk_cue()` path (`▸ [U] then Deliver`) never wins after Accept.
- `_deliver_walk_cue()` already knows the door: off Commitments it returns `▸ [U] then [R] Deliver` (or Claim when READY).

**Folded (source, 2026-10-12).** `room_walk_cue()` FRAME_MARKET: if any fill stall is held, `_deliver_walk_cue` (`▸ [U] then Deliver/Claim`). `_board_walk_line` prefers `board_walk_cue` once `held_fill_for` is nonempty. Pin `test_market_held_fill_names_commitments_not_accept`. Live Windows exe still needs a re-export.

---

## 2. Act-0 tour: show Village and Forest while learning controls

**Why.** Demos music is a long sit. Players should hear and see other lands before five minutes of Demos-only FRFR. Controls lesson stays; the island opens.

**Desired order after the first Demos explore/gather (not “one plot then mill then jump to Forest mass-explore”).**

1. Demos — learn Explore / Strike / Gather on the plots that are here.
2. When Demos plots have been explored and gathered (all locations in The Demos), **Village** — explore every Village plot. Invite Gather; Gather is optional (soft).
3. **Starter Forest** — arrive, explore every Forest plot (see the land, hear the music).
4. **Back to Demos** — finish the mill cycle (Market Y ↔ Commitments U) and close the contracts lesson.
5. **Then** Forest multi-select / gates.

**Current chain** (`Core/Quests/data/tutorial_arc.json`):

0. `core_loop` (one Explore + one Strike + one Gather in Demos)
1. `contracts` (mill Accept + deliver 2×🌾)
2. `wayfinding` (stand in StarterForest — arrival only)
3. `mass_explore` immediately in Forest
4. Superpose → Bell → Reap

Wayfinding skips Village and skips “explore all Forest plots” before mass-explore.

**Fold.**

- Insert a Village visit between Demos harvest and the mill-finish / Forest gates. Predicates: explore (and optionally gather) Village plots; do not hard-require Gather.
- Wayfinding must not be “arrive Forest and immediately SHIFT+F”. Explore all Forest plots first.
- After the tour, return to Demos to complete the mill Y↔U grind if that lesson is still open.
- Keep one next key on the banner/toast. Do not dump a travel recipe.

---

## 3. Forest multi-select and Bell after every plot is visible

**What happened / what’s missing.** After missions, the game teaches multi-select and gate ops. Starter Forest mass-explore currently fires as soon as you stand there. Bell (entanglement: weave two, Strike one, both balloons fill) is taught on plots the player has not scouted.

**What it should do.** Forest **MULTI / SHIFT+F** and **Bell** run **after every location in that land has been explored**, so the Bell effect is something you can see on live bubbles.

**Current.** `tutorial_arc.json` step 3 `mass_explore` (`batch_explore` count 1) then step 5 `entanglement` (`bell` + `bell_collapse`). No “all Forest plots revealed” predicate.

**Fold.**

- Gate `mass_explore` (and Bell) on Forest plots being sighted / explored — not on biome arrival alone.
- Bell lesson stays: weave two, Strike one, watch both balloons. That only reads if the plots are already explored.
- Superpose (Druid E) still waits until Forest plots are visible (existing law). Multi-select is the batch wake **after** the tour, not instead of it.

---

## 4. Grey ephemeral toasts cover the gold hint

**What happened.** Shortly after doing things, a grey (teal / importance-2) toast pops and sits **on top of** the more permanent gold hint (ActFilament objective + gold persistent toasts). The gold walk is unreadable while the burst is up.

**What it should do.** Gold hint stays put in its reserved slot. Temporary toasts are a **queue/stack that starts at the top edge of the gold section and grows upward**. They never cover gold. New greys enqueue above gold; older greys push further up (or wait in queue). They fade/dismiss in order. Gold is not an eviction peer of grey.

**Where it lies today.**

- `UI/PlayerShell.gd`: ActFilament is the stable gold objective (bottom-right). `_hint_toast_stack` is one `VBoxContainer` (`ALIGNMENT_END`, grow up) meant to sit just above that banner.
- Gold (importance ≥ 3) and teal/grey (importance 2) are **the same stack**. `show_hint` `add_child`s every toast into it. Ephemeral cards share the gold slot.
- `offset_bottom = maxf(act_filament_top - 16.0, -180.0)` clamps the stack down. When the banner sits lower than 180px from the bottom, the clamp **overlaps ActFilament**. Comment already says the stack should land just above the banner.
- Overflow `pick_toast_eviction_victim` prefers non-persistent, but layout still paints grey over gold.

**Folded (source, 2026-10-12).** Cause was worse than a clamp tweak: `offset_bottom = max(banner_top - 16, -180)` parked the stack at 180px on a 1080p window while the gold banner lives ~300px up, so greys spawned in the action-bar band and queued down through gold. Gold and grey also shared one VBox. Now: `ActFilament.banner_bottom_offset` / `toast_column_bottom_offset` (no -180); two lanes (`GoldToasts` under `EphemeralToasts`) in one column that seeds at zero height and grows up; greys never evict gold. Pin `test_grey_toasts_stack_above_gold_never_overlap_banner`. Live Windows exe still needs a re-export.

---

## 5. Superpose [E] in MULTI does not advance the lesson (hidden checked set)

**What happened.** Luke Superposed with `[E]` while MULTI was on. The lesson did not move. He suspected the wrong plot was selected, and that unexpected plot keys left **hidden marks**.

**What it should do.** MULTI `[E]` Superposes the **checked set** (cyan camera-circles on the 3D orbs — no checkbox glyph). That set must be visible. A successful Superpose — singular or batch — must write `gate_inject:hadamard` so Act-0 step 4 (`gate_sequence_contains` hadamard ×1) fires. Fogged / out-of-register checks must refuse out loud (`No qubits under the checked plots` already exists when the whole set is empty).

**Where it lies today.**

- MULTI on makes `[E]` = Shift+E (`_dispatch_action_key(..., shift or multi_select_mode)`).
- `_perform_batch_gate_action` injects H on `checked_plots` and does **not** `record_projection_action("gate_inject:hadamard")`. Singular `action_hadamard` does notify. So physics can spread while the gold toast stays on Superpose.
- Unexpected GHJKL; taps while MULTI is on toggle those plots into the set. Marks are cyan circles (`QuantumField3D._apply_check_visual`); easy to miss on fog. Turning MULTI off does **not** clear the set.
- If every checked slot is beyond the biome's qubits, the batch refuses. If the focused plot is sleeping, the superposition banner falls back to `_mass_explore_walk_line` even while the lesson is Superpose.
- Superpose twice is identity (`H² = I`); a second MULTI E on the same hidden set looks like nothing happened.

**Unstick on the live Windows exe (this build does not have the ledger fold).**

1. Tap MULTI off.
2. Wear `[0]` Druid.
3. Focus a **live bound Forest bubble** (visible Bloch ball, not fog) with GHJKL;.
4. Press `[E]` **once**. That path records hadamard. Lesson should advance.
5. To drop a hidden set: tap MULTI on, tap the cyan-circled orbs again to uncheck, or tap each unexpected homerow key until the cyan rings go.

**Fold.**

- After a successful batch hadamard, call `record_projection_action("gate_inject:hadamard", result)` (same string as singular).
- Toast the marked count (`Superpose ×N`) and name skipped no-qubit slots.
- Banner on superposition + MULTI names the marked set, or refuses hidden/fogged checks; do not fall back to mass-explore from a sleeping focus while checks exist.
- Pin: `tests/test_druid_chip_costs.py::test_multi_superpose_records_hadamard`.
- Do not leftover-stop the Windows player. Re-export after this sitting.

---

## Constraints

- Buttons only do what they advertise. Toast names the same key as the banner.
- Ace never Superposes. Player walks doors. Do not gift wallets.
- Hive fold BETWEEN waves. Windows player is leftover-stop-exempt.
- Fresh Act-0 save needed to play the new chain (`reset.bat` / true-zero).
