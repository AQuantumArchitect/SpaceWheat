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

## Testing infra now standing
- `🍄/🧪/player_seat.py` — the parity harness (headless lane). A headed
  variant (screenshots + taps) is the mouse-parity lane for UI passes.
- The fleet workflow is re-runnable per release (2 winners + 4 QA, ~40 min,
  ~380k tokens). Suggested cadence: every deploy that touches UX text,
  input, or the economy.
- `born_reward_probe.py` — distribution assertions (PT6).
