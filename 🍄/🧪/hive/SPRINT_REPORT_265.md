# Sprint #265 — a haiku beats the game

**Gate (as ruled):** a haiku (small model at a text seat) beats the game through the
act-4 hub using only the rig and in-game instructions; the late game (acts 5–8) is
carried by sonnet runners (owner ruling 2026-07-16, "the late game can be sonnets").
**Status: acts 0–4 HAIKU-PROVEN (hub + first incorporations + branch-door recipe);
all three branch doors fired (sonnet scout, manifest-verified); endgame runner in
flight toward the ending.**

## The proof, lane by lane

| Lane | Road | Legs | Bank | Verdict |
|---|---|---|---|---|
| L1 | fresh boot → lumber_flows (Woodlot chapter) | 15 | `leg_l1o_done` | PROVEN — first vocabulary chapter beaten reading only the screen |
| L2 | woodlot_taught → pond_breathes (Spring chapter) | 14 | `leg_l2p_done` (21 flags) | PROVEN — full loop: door / contact / claim 💧🌊 / plant / wake / pond |
| L3 | act2_complete → chain_flipped (Mill + Lanternfall) | 4 | `leg_l3d_done` (28 flags) | PROVEN — the witness-hold chapter, incl. the owner's difficulty question (below) |
| L4 | act3 → hub cascade (village_identity, five_doors, teachers) | — | — | IN FLIGHT |
| Branches | act4_hub → 3 path legs (industrial / watched / cemetery) | — | — | PENDING |
| Endgame | act3_5_drive end-to-end on final data | — | — | PENDING |

Every claim was manifest-verified (`grep <flag> <bank>.tres`) — sensors both inflate
(trajectory-line misreads ×2, accepted-contract misreads ×2) and under-claim
(beats fired unnoticed ×4). Nothing in the ledger rests on a sensor's word alone.

## The owner's question, answered

**"Is Lanternfall haiku-passable?"** Yes — and it asked for *eyes*, not a human.
The L3c hold succeeded blind (the sensor held 🪔 with zero state feedback), which
proved the mechanic passable but illegible. One parity read later (`north_pct` in
plot_glance, commit `14538995`), L3d reported: *"north_pct climbed from 0.18 → 0.45
over ~50 seconds… clear feedback. The north_pct field was a powerful guide."*

## The parity organ (what a text seat can now sense)

Each sense was priced by a wall a haiku actually hit, in order:
1. **Focus** (L1e) — which plot the verbs act on (`plot_glance.focused`, QII dispatch authority)
2. **Words** (L1i) — axis glyphs on revealed plots (eagle-source visibility)
3. **Gaps** (L2) — `empty:true` on plantable columns
4. **State** (L3c) — `north_pct` live probability on revealed plots
5. **The microscope** (owner directive 2026-07-15) — B renders fully in screen text:
   per-plot poles/probabilities, purity, links, H-gap, Var(H), icon lineage +
   couplings, entanglement; ring keys pick the plot, biome tabs switch countries
   inside B. Verified live; now a standard block in every sensor brief.

## Path repairs the sprint produced (walls fix paths)

- `80c790d8` act 0-1 gates gained arc quests; `57e0de46` First Breath names the new-word constraint
- `636d3e82` lantern latch width + braid mirror; `b647b1b4` mill hint names the ritual
- `49556c21` berry credit persists across loads; `6e07382a`/`fbc8b9b8`/`14538995` the glance grows senses
- `bf373ecf` plant pipeline for >3-icon boots (picker pager ×2 + half-landed plants)
- `72ff67a9` + `c0adf124` + `0248f67b` the post-load disease family: QM rebind, claims-never-READY,
  teaching offers not reborn (re-offer only unclaimed pairs), rig diagnostics rebind on farm_ready
- `da1d610e` seat bank-name hint

## Measured pacing (honest-economy facts)

- Berry ≈ 2–3 min wall each; door toll 21🦅 ≈ 6 Ace F-R-Q cycles ≈ 2 min
- Teaching gate = 2–3 deliveries (access +0.02 each) — the owner's budget held
- Discovery lottery at PRESSURE_BOOST 6.0: ~88% story-biome, ~12% toll betrayal
  (owner design note: ~66 gives 99%; ledgered, not changed)

## Ledgered owner calls (open, not blocking)

1. Trajectory line should ghost/dim unfired beats (2 sensor inflations)
2. "Once accepted, find it under C→U" hint line (3 runners lost budget to the split)
3. Accepted-but-unclaimed quests don't survive loads (ruling wanted)
4. Discovery boost 6.0 vs ~66 (texture vs certainty)
5. Drives bridge eagles (act2_drive:274) — test-honesty smell
6. Arc-offer flood vs 6-row cap; Z-menu "loaded from: fresh start" cosmetic

## E2 gamma rungs (owner's spare-time program)

All 67 banked witness tapes sit at gamma_scale=1.0. Rungs {0.25, 4} re-fly a short
fixed leg per scale, scored by `hive/gamma_ab.py`. PENDING — queued behind the L4 seat.

*(Report finalizes when L4 + branch legs + endgame drive land.)*
