# Glyph chatter experiments (2026-11-10)

An overnight session settling four open questions in `docs/GLYPH_LANGUAGE.md` §10: what
drives line length, joint draws, standing channels, and the Semantica hand-back. Luke
asked for taste and experiment, so this records what was measured and why each rule
was chosen. All runs were headless boots of the real game (the rig's AppRoot path) with
`user://` redirected to a temp folder. The recordings were per-tick dumps of every
register (viz `p0`, `r_xy`, φ, and the QC partial trace), pairwise MI, and the basis
distribution, over 180 ticks: quiet 0–59, churn 60–119, quiet 120–179.

## 1. The closed world is never quiet

Under closed evolution every marginal oscillates. The Village 💰 swings between .07 and
.29 with a period of about 6 ticks. Median per-tick motion of a register: |Δp| ≈ 0.015
and trace distance ≈ 0.034 with lookahead on. With lookahead off, the trace distance per
tick is about 0.19. Lookahead on vs off changes how fast the sampled state moves, which
is worth a look on its own.

Consequence: **motion is weather, not news.** With the v2 rule (a register comes up with
probability 1 − exp(−|Δp| / 0.05)), line fill was the same in quiet and churn (0.73 vs
0.75). An exponential moving average of the Bloch vector (the "climate") only reached
about 2× churn/quiet contrast.

## 2. With lookahead on, strikes and gates do not stick (headless)

A strike reports `projective_collapse: true` and does collapse the register in the same
frame: 🦅 .937 → 1.000, and its entangled partner 🐺 .937 → .992. Within 10 frames
both are back on the pre-strike trajectory (.933). Gate injections through
`GateInjector.inject_gate` disappear the same way. With `RIG_DISABLE_LOOKAHEAD=1` the
collapse holds and evolves on from the collapsed state: 🦅 1.000 → .983 → .922 → .871 …

The rig defaults to `RIG_DISABLE_LOOKAHEAD=1`, so rig-driven tests can't see this. It
has only been observed headless; the headed game is unverified. Repro:
`tests/strike_collapse_probe.gd`, run once plain and once with
`RIG_DISABLE_LOOKAHEAD=1`. Chatter reports this honestly: with lookahead on, factions
don't react to strikes, because the state doesn't keep them.

## 3. Relative entropy is the line-length driver

The candidate rule: a register comes up with probability 1 − e^(−D), where D is the
relative entropy (nats) of the reading now from what this speaker last said. A faction
speaks iff something comes up. Simulated over the lookahead-off recording, with one
speaker per biome:

| | quiet (first) | churn | quiet (after) |
|---|---|---|---|
| StarterForest: share of ticks with a line | 10% | 30% | 13% |
| Village: share of ticks with a line | 8% | 33% | 38% (left livelier by the churn) |

Lengths are heavy-tailed: mostly one register, full-vocabulary introductions, and
occasional two- or three-register lines after events. The rule has no free parameter,
and cadence comes out of the same rule as length. The v2 cadence floor (`SPEAK_FLOOR`)
and motion scale (`MOTION_TAU`) are gone.

## 4. Mutual information has to come from the distribution

The viz cache's mutual information read ≈ 0 in headless with lookahead on or off. The QC's
cached MI was stale (constant .072 after a weave). Ties now use the classical MI of two
registers' **pole outcomes** in the basis distribution, which is the distribution the
line's poles are drawn from. A ket states pole outcomes, so ⌢ says exactly that they
don't come independently.

Measured in the boot:
- StarterForest 🐺–🦅 reaches 0.44 bits; the Village stays ≤ 0.24.
- H + CNOT on a non-ground state makes little pole correlation, so it isn't a Bell pair.
- Ties are therefore rare and meaningful in the starting world.
- In a mock Bell pair (1 bit), 19 of 19 lines pulled the partner in, tied it, and kept
  the poles correlated.

## 5. Standing lifts

In paired mock runs (same seed, same world), 🧿 attention 3 and 🗝 access 3 against zero
channels moved asks per mentioned register from .78 to .88, and darks from 11 to 22.

## 6. The Story room needed every line from friends

With a separate standing draw only, a 90-second boot (lookahead on) produced no Story
line at all. Your own people's first, all-news line usually went out through the
general draw. Now every line from a faction with positive standing, or from The Demos, is
a Story line, and the standing draw adds air on top.
