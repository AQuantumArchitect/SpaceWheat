# Fleet Playtest — 2026-07-12

Six claude-haiku agents played the game through a **player-parity seat**
(`🍄/🧪/player_seat.py`): screen text + keyboard only, no resource injection,
no dev introspection, welcome splash on. Two played to win, four QA'd
(chaos / economy / navigator / manual-less stranger). Headless (owner call:
mechanics first). 531 seat commands total, ~90–110 actions each.

**Rig verification (before the fleet):** full F/R/Q loop driven end-to-end
through the seat — explore charged 1🍞, strike charged the scaled 👥 cost
shown on its chip, extract paid +5/+15 (varied, honest die), plot returned to
fog. Cost badges confirmed in rendered pixels on the headed lane.

## What held up

- **Zero crashes, hangs, or stuck overlays** across hostile input: key mash,
  escape spam, invalid keys, shift-combos with nothing selected, action keys
  inside menus. Worst case everywhere was a silent no-op.
- **No soft-locks found.** The economy tester drove wallets up and down for
  50+ cycles: "the economy always allows you to extract and earn more."
- **The surprisal economy reads as fun**: "first extraction paid 2 folk, the
  second paid 17!" — the PT6 honest-die fix is visible in play.
- **Contract loop completes end-to-end** (navigator: accept → deliver →
  payout ⛓×6 + trust up). Market-accept → Commitments data flow VERIFIED
  working by rig follow-up (the winner-1 "missing commitment" report was tab
  navigation, kept below as a feedback finding).

## Build plan

### Lane A — Honesty (anti-gating law; P1, do first)
1. **Silent mass-op refusals**: Shift+R / Shift+Q with no valid targets give
   zero feedback (2 witnesses). Every refusal gets a toast, same as singles.
2. **Disabled-chip lies**: Guide overlay shows `[R] -` but R switches tabs;
   Spark hat shows `[F] -` but F resumes play (2 witnesses). One rule: if a
   key does something the chip names it; if the chip shows `-` the key
   no-ops. Audit all hats × overlays for dash-chips with live keys.
3. **Shift-variant costs invisible**: chips price the primary verb only —
   Shift+F reap (🍼) surprised every agent who found it; F vs Shift+F look
   identical. Extend cost badges to shift actions (small second badge or
   `(Reap 1🍼)` in the shift label).
4. **Locked-hat silence**: pressing a not-yet-unlocked hat key (progressive
   disclosure) does nothing visible. Tiny toast: what it is, how it unlocks.

### Lane B — Feedback (cheap toasts; also fixes streaming/accessibility)
5. **Biome switch confirmation** (4 witnesses) — toast "→ Village".
6. **Plot selection acknowledgment** — selected plot + its state readable in
   text (the chip row already updates; a "Plot H — unexplored" status line
   closes it).
7. **Fast-forward invisibility**: F on an explored plot fast-forwards
   silently; agents read it as "F is broken 90% of the time." A ⏩ pulse
   toast/flash.
8. **Pause state clarity** (2 witnesses): E chip should read Pause/Resume by
   state; verify glyph toggles.
9. **Accept trail**: after market accept, point at the Commitments tab in
   the toast (data verified to land; the trail is what's unclear).

### Lane C — Perf (verify then fix)
10. **FPS 30→10 opening Commitments tab** (1 witness, StarterForest).
    Reproduce headed; profile the commitments render path.

### Lane D — Doc truth (HOW_TO_PLAY + welcome rot)
11. Manual says **N = density-matrix heatmap** → actual: Network view with
    tabs. Manual says **M = world map + eigenstate compass** → actual:
    Affinity Hypercube. Rewrite both lines to what ships.
12. Manual's "tutorial chain lives on the C board" wording doesn't match
    what a stranger sees (offers, not a labeled chain). Align wording.
13. **Welcome splash still teaches the old 2-beat tap loop** ("tap to
    measure, tap again to harvest") — the shipped grammar is 3 beats
    (explore/strike/extract). Found during rig verification.
14. E's role ("pauses time" vs "tell-me-more on every surface") — one
    sentence per context.

### Lane E — Polish (P2, owner taste)
15. Druid chips `+ / H / −` cryptic to newcomers (may be intended terseness).
16. Wallet float leak: `🍞=33.0` in resource state — coerce economy amounts
    to int at the add/commit seam.
17. Story FOCUS tab reads as *position*, not *lens*: switching expressed
    faction "regressed Act 5 → Act 0" for a winner (it's a lens over
    different spines). Label it as a lens; consider showing furthest act.

### Dismissed as artifacts (for the record)
- "F gated 90%" — F on an explored plot IS fast-forward (by design); the
  finding folds into Lane B #7.
- Captain hat "spurious 21" — that's the R chip's discover-biome cost badge
  (21🦅) read as bare text headless; correct in pixels.
- Unexplained header numbers (55, 34, 21…) — wallet counts without their
  emoji glyphs in text extraction; headless-only.
- "Resources should evolve while unpaused" — the wallet only moves on verbs;
  working as designed.
- Commitments-empty after accept — disproven by rig follow-up (see above).

## Fix pass (same day)

- **Lane A shipped**: mass-op refusal toasts (no checked plots / no valid
  targets); OverlayBase chip-honesty gate (declared "—" chip ⇒ key no-ops; E
  stays live where inspect text exists); ControlsOverlay declares per-tab
  verbs (Harmonize/Express/Accept/Assign…); shift costs inline in the shift
  hint ("(Reap Season 1🍼)"); empty E/F frame chips now read the side-effect
  truth ("⏸ Pause" / "▶ Play"); menu-swallowed gameplay keys get a debounced
  "Menu open — Esc" toast.
- **Lane B shipped**: biome-switch toast ("→ Village"), pause/resume state
  toasts, fast-forward pulse ("⏩ the odds spin forward").
- **Lane C closed — not reproducible**: headed FPS on the Commitments tab is
  a ~1s transient (52→39→47). The fleet's 30→10 was three concurrent Godot
  instances sharing 8 cores.
- **Lane D shipped**: HOW_TO_PLAY N/M/C/E lines rewritten to what ships;
  welcome splash now teaches the real F/R/Q loop.
- **Lane E shipped**: druid chips read "Spin − / H-Gate / Spin +"; wallet
  amounts int-coerced at spend (no more 33.0); story FOCUS header labeled
  "(lens)".
- Verified: suite 119/119; born_reward (a p=0.073 collapse paid +116),
  menu-bleed/lens, tutorial 7/7 by hints.

## Fleet #3 — relay marathons (same day, post-fix build)

New format: 3 lanes × 3 sequential haiku legs on ONE persistent seat
(campaign survives between legs; notebook handed leg-to-leg; `start` now
refuses on a live seat unless `--fresh`). Strategies: contract-spine /
story-first / economy-first. 803 tool calls, ~630k tokens.

**Result: all nine legs stalled on the same wall — Act 1's berry gate.**
Three stacked defects, all fixed same day (5afc77cf):

1. **The math lied**: soft_gate is 0.5 at the authored value, so
   "berries ≥ 3" silently demanded ~4.3 and "signature ≥ 18" ~19.7; partial
   progress at 2/3 berries displayed 0.21 (three testers quoted that exact
   number). `QuestMath.count_gate` now fires integer counts exactly AT the
   authored value; `predicate_fire_target` quotes it; 2/3 reads 0.60.
2. **The gloss didn't teach**: the Arc tab said "berries[StarterForest] ≥ 3"
   — no verb, no hat. Count glosses now teach the Icon-hat loop;
   signature_growth finally has a gloss; story_flag_set speaks display
   names, not internal ids.
3. **Refusals were mute**: "✗ Track blocked" gave no reason; berry-track
   failures now name the fix.

Also: manual's Icon-hat "Inject dual-emoji qubits" lie fixed; Ace F copy
claimed F reaps (it's Shift+F); new manual section "Berries — how the story
moves". Endgame gate beats (edge/door/island_free) now name their thresholds
in-voice (afd94635). Commitments rows read "🔥 6/11 held"; reap refusal
teaches F→Shift+F; ambient drain income logs attributed (b92db5b1 — closes
the 🐺-from-nowhere P1: it was StarterForest's lindblad trickle; refusal
paths verified side-effect-free).

Verified after: suite 119/119, act3_5_drive full campaign green under the
new gates, poverty_run_probe green (owner-style: 25 keyboard cycles, no
injection, both poles, +303 surprisal pop, ledger fully reconciled).

## Fleets #4–#6 — the relay loop converges

- **Fleet #4** (post count-gate build): all lanes found the berry loop via
  the new Arc glosses (fleet #3: zero). New P0 exposed and root-caused: hat/
  biome switches cleared plot focus (PlayerShell cursor-layer anchor), so
  chips rendered one plot while dispatch read none — "chip says Incorporate,
  R says blocked." Fixed: keep_plot_selection (a102ff2d); refusals speak;
  berry-track F toggle is loud (testers were destroying their own loops by
  "polling" with F).
- **Fleet #5**: BREAKTHROUGH — lane 1 completed the entire Act-1 beat chain
  (Forest Stirs → Listens Back → Village Stirs → Druid's Loop → into What
  Survives I); first_breath fired for every lane. Wall narrowed to one item:
  ripening throughput ("50+ fast-forwards per berry").
- **Fleet #6**: proved the =/- 16× clock was a placebo. Three stacked
  defects: quantum_time_scale is a dead variable; the lookahead fast-forward
  branch never runs live (buffer permanently empty); the stepper's stride
  path chunked time instead of multiplying it — while Farm's Lindblad path
  DID multiply, desyncing H from L under the dial. Fixed at the packet
  authority: stride now multiplies sim time (cap ×32/frame), Berry-walk
  sampling density preserved. Measured ~20× at stride 32 — a berry ripens in
  ~2 wall-seconds at full throttle (was 50+ commands). Toasts + manual teach
  the dial; the rig/seat can now physically press it (= - and named aliases
  were unmappable keys).

## Testing infra now standing
- `🍄/🧪/player_seat.py` — the parity harness (headless lane). A headed
  variant (screenshots + taps) is the mouse-parity lane for UI passes.
- The fleet workflow is re-runnable per release (2 winners + 4 QA, ~40 min,
  ~380k tokens). Suggested cadence: every deploy that touches UX text,
  input, or the economy.
- `born_reward_probe.py` — distribution assertions (PT6).
