# Sprint #265 — the game is beaten. CLOSED 2026-07-16.

**Gate (as ruled):** a haiku (small model at a text seat) beats the game through the
act-4 hub using only the rig and in-game instructions; the late game (acts 5–8) is
carried by sonnet runners (owner ruling 2026-07-16, "the late game can be sonnets").

**Verdict: PASSED.** The ending fired — *"Your island never collapsed... This is
ours. **The Demos are free.**"* — `island_free` manifest-verified in
`endrun_ending` (49 story flags, 19-word signature). Every claim in this report is
backed by a save-file grep; nothing rests on a runner's word alone.

## The proof, lane by lane

| Lane | Road | Runner | Legs | Bank | Verdict |
|---|---|---|---|---|---|
| L1 | fresh boot → lumber_flows | haiku | 15 | `leg_l1o_done` | PROVEN |
| L2 | woodlot_taught → pond_breathes | haiku | 14 | `leg_l2p_done` | PROVEN — first vocabulary claim (💧🌊) |
| L3 | act2 → chain_flipped | haiku | 4 | `leg_l3d_done` | PROVEN — the witness-hold chapter |
| L4 | hub cascade + Eagle claim | haiku | 7 | `leg_l4e_done` + | PROVEN — village_identity, five_doors, first incorporations (🫧🌿, 📯🏁) |
| Doors | 3 village branch paths | sonnet scout → haiku | 1+1 | `scout_branch_*`, `leg_l4g_done` | ALL FIRED; cemetery re-walked by a haiku in **44 presses, zero walls** |
| Endgame | acts 5–8 → island_free | sonnet | 1 | `endrun_act5..ending` | **ENDING REACHED** — sig 16→19, 4 new biomes, act-7 content live past the ending |

## The owner's design questions, answered by play

- **Lanternfall:** haiku-passable — it asked for *eyes* (state feedback), not a human.
- **The ending:** lands as designed — "the game just tells you you already won,
  mid-action, because the physics you'd been building was the answer all along...
  genuinely satisfying" (endgame runner, unprompted).
- **Act 7's gut-punch works:** "the Bath greying the same lanterns you'd tended
  since Act 2" — and biome-slot scarcity makes letting go feel thematically right.
- **One sour note (owner call):** the endgame cull→discover→track→wait→incorporate
  loop per new biome reads as repetitive busywork beside the emotional beats.

## What the sprint fixed (walls fix paths — every repair traced from a runner's wall)

- Post-load disease family (QM rebind, claims-never-READY, offers-not-reborn, rig
  rebind, berry credit) — 72ff67a9, c0adf124, 0248f67b, 49556c21
- Plant pipeline for >3-icon boots (picker pager ×2, half-landed plants) — bf373ecf
- Signature gloss sigmoid lie ("know 13/15" now live) — a9701a68
- Microscope honesty: pair-keyed "known ✓" + VS16 normalization (❄ ≡ ❄️) — f19d9a99
- Trim: viz reseed on shrink (capacity lie) — c86ac9ee; slot-law targeting (wrong
  plot felled) — post-4aa12c28
- Incorporation honesty: blocked words no longer celebrated — 972b3876
- QA trio P0s: dev-panel wipe defused, Demos uncullable, glance measured truth — 98ba236c
- **Quest persistence (save v6)**: contracts + history survive load — 4aa12c28
- Boot script errors zeroed; berry F-toggle trap named in the gloss; parity organ
  grown sense by sense (focus/words/gaps/state/microscope/ledger)

## Fleet doctrine results (owner directive, measured)

- **Paver→prover works**: the sonnet scout pathfound the branch road once
  (~100 tool calls); a haiku repeated it in 44 presses with zero walls.
- **Hostile QA personas pay immediately**: one flight found a save wipe two keys
  from the pause menu, a display-manufactured "broken feature," and the
  quest-ledger-evaporates-on-load launch blocker.
- **Epistemics shipped**: umwelt PR #7 (misread taxonomy + POISONED channel tier +
  fleet doctrine), PR #8 (E2 gamma ladder: retention buys 6.5× decisiveness free).

## Ledgered owner calls (open, not blocking)

1. North-uniqueness rule: 4 of 6 island unknowns unlearnable; sig-gate margins
   (15/16/18) are razor-thin by accident — intended scarcity or leftover slop?
2. Data-level VS16 normalization would switch on silently-dead H couplings — needs
   its own tuned pass.
3. Trajectory ghosting; boost 6.0 vs 66; boot hat = 8; QERF-in-overlay binding
   accepts; endgame cull-loop busywork; act filament shows "Act 1 91%" everywhere;
   Explore chip hides 1🍞; Network-C dead handoff; stale "✓ ready" HUD badges;
   cull-confirm toast throttled; braid ×4 climbs by soft-gate increments;
   "Failed to remove biome" refusal doesn't say WHY (protected biome).

## Follow-up engineering (post-sprint, small)

- Re-mint canonical checkpoints on current HEAD (act1..act4_hub predate the fixes).
- act3_5_drive end-to-end on final data (#252 flake rule applies).
- Behavioral E2 (live-runner gamma A/B) — licensed by the instrument result.
