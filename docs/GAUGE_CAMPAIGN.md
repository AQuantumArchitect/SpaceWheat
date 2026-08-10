# What Turns — the Bookkeeping Campaign

> Campaign design + ship record, 2026-08-10. The fourth lane, promoted from
> `docs/ENGINE_FRONTIER.md` (Machine 2's closure-honesty note named its two
> gauge lessons) the way the first three campaigns were promoted from their
> seed banks. Owner directives honored: the lessons **interleave** into acts
> 5–8 rather than trailing the door, the ending is **untouched**
> (`the_door_stays_open` still closes act 8 on its own terms), and there is
> **no save-format touch** — deliberately, see "Nothing persists" below.
>
> **Status: SHIPPED (2026-08-10, same day as the plan).** Machinery:
> `GaugeField` (Z₂/U(1) lattice gauge substrate: gauge transforms, Wilson
> loops, spanning-tree gauge fixing, β₁ = E − V + C, red-team scrambles) wired
> per biome as `QuantumComputer.get_gauge_field()` over the NeighborhoodGraph's
> coherent couplings, phases seeded from arg(J) of the authored Hamiltonian;
> `KnotRegister` lift closure (`lift_holonomy` / `lift_closure_defect` /
> `concat_records` / `closed_lift_curves`; `gauss_linking` refuses open lifts);
> `BerryPhaseRegister` spinor sign + fiber angle; Operator 🧭 compass verbs +
> Icon 🪞 mirror verbs (`GaugeActionHandler`); six predicates; the station
> dial + fence glyph (gated on `turned_compass`); five story flags; glossary
> **gauge** + **wilson** + **holonomy**. Remaining: threshold tuning in live
> play; a dedicated loop-card overlay surface (the E-card message carries the
> payload for now).

## The thesis

**What Survives** taught what one system keeps. **What Connects** taught what
two places share. **What Fades** taught what the world takes. **What Turns**
teaches the discipline underneath all three:

> *The numbers you write are your bookkeeping; the numbers that survive every
> re-bookkeeping belong to the world.*

Gauge freedom is not exotic physics — it is the freedom to re-zero your local
conventions without changing anything real. The campaign hands the player that
freedom as a verb, then teaches them to hunt for what refuses to move: the
closed-loop products (Wilson), the count of places such survivors can live
(β₁), the holonomy a walk carries home in its lift, and — by deliberate
counter-example — a number that *looks* invariant and isn't (mutual winding).
An invariant is not something a card declares. It is something that survives
every attack the rules allow.

## The chapters (interleaved, acts 5–8)

| # | Flag | Act | Where | The teaching |
|---|------|-----|-------|--------------|
| I | `loop_came_home` | 5 | StarterForest | A ripe loop returns to the same Bloch point with its spinor's sign reversed (γ = Ω/2 = π). Nothing local can see a sign; interfere against a stay-home reference and it is plain. Phase is a relationship, not a property. Arc: `spinor_read −1` in the mirror (Icon 🪞). |
| II | `turned_compass` | 6 | anywhere | The compass verb: re-zero a plot's phase convention (χ = π). Displayed numbers swing; every prediction holds. What a turn can change was never physics. Arc: three `gauge_flip`s. Unlocks the station dial + fence glyphs (the face rotates; the phase dot does not). |
| III | `fence_remembers` | 7 | StarterForest (β₁ = 4) | Wilson loops: every flip touches each closed circuit twice, so W(C) = Π s_ij never hears it. A tree combs entirely flat (`gauge_fix`); only cycles keep books — β₁ = E − V + C survivors. Arc: read → turn → certified held (`wilson_survived_flip`). |
| IV | `the_number_lied` | 7 | StarterForest | The knot card's mutual winding is axis-relative — the axis belongs to the partner, and smooth moves swing it. Integer-valued ⇏ invariant. Arc: change the winding with no record lost (`winding_changed_uncut` — the witness restarts if anything is cut). |
| V | `close_it_upstairs` | 8 | StarterForest | A base-closed loop's lift hangs open by exactly its holonomy; a ripe loop is *antipodal* upstairs. Walk it again (Ω = 4π) and the loose ends meet. Only then does `gauss_linking` stop refusing (NAN on open lifts — refusal, not failure). Arc: two closed lifts + a valid linking question. |

## The verbs

**Operator hat (9), mode 2 — 🧭 compass** (all free; ρ untouched — bookkeeping
isn't physics, and pricing it would teach the opposite):

| Key | Action | Teaching |
|---|---|---|
| R | `gauge_flip` | Turn this plot's convention (χ = π); every incident fence flips; the Wilson receipt (before/after) rides the payload |
| E | `wilson_inspect` | The loop card: β₁, fundamental cycles, W(C) per cycle, incident fences. Marks the ledger read (quests demand read → turn → held, in that order) |
| Q | `gauge_fix` | Comb the ledger flat (spanning-tree gauge); the residue on the chords is the invariant content |
| F | `gauge_scramble` | Red-team: random χ everywhere; any number that survives has earned the word invariant |

**Icon hat (5), mode 2 — 🪞 mirror** (non-destructive; a faithful comparison of
Berry travel logs, never a beam splitter on ρ):

| Key | Action | Teaching |
|---|---|---|
| R | `mark_reference` | Hold a qubit home (starts its log); phase is only visible relationally |
| E | `interfere` | Δγ = γ_traveled − γ_home and the spinor sign product; ripe loop → −1 |
| Q | `unmark_reference` | Release without stopping the track (stopping forfeits the loop) |
| F | — | Disabled with an honest hint: the mirror only reads |

## The honesty ledger (FOR_PHYSICISTS grades)

- **Gauge field on the coupling graph — faithful.** Nodes/edges are the biome's
  real coherent coupling topology; the Z₂ seed is the sign structure of the
  authored H (phase = arg(J)); every Wilson/β₁/tree-fixing computation is
  exact on that graph. The one caveat, stated everywhere: edge phases are a
  ledger *about* the graph — they never feed back into U(t).
- **Mirror interference — faithful.** Δγ is the true relative geometric phase
  of the two recorded walks — exactly what a Ramsey-style comparison would
  reveal — read from the register, with ρ untouched. The card says it compares
  travel logs; it never claims a beam was split.
- **Mutual winding — exact computation, honestly demoted.** Taught as an
  attackable, axis-relative diagnostic. Lesson IV *is* the demotion.
- **Nothing persists — deliberately.** Gauge conventions are session-only and
  re-seed from H on reload; the Wilson loops survive that automatically,
  because they are the part that was never bookkeeping. The reload behavior
  is itself the lesson, and the save format goes untouched.

## Predicates

Flag vocabulary: `biome_betti_gte`, `biome_loop_closed_upstairs`,
`biome_linking_valid`. Projection vocabulary: `wilson_survived_flip`,
`spinor_read {value}`, `winding_changed_uncut` (+ `gate_sequence_contains
{gate: gauge_flip}` reused). Gloss + spotlight targets in `PredicateGloss`;
smoke-pinned in `tests/predicate_target_smoke.gd`.

## Probes

`tests/gauge_field_probe.gd` (substrate: invariance, tree-fixing, β₁),
`tests/gauge_wiring_probe.gd` (per-biome wiring, seed honesty, emoji carry),
`tests/reference_interference_probe.gd` (mirror + the read→turn→held receipt),
`tests/knot_closure_probe.gd` (closure defect, stitching, linking gate).
Verified: StarterForest's coupling graph carries β₁ = 4 from its authored
icons, so every StarterForest gate above is reachable from the starting biome;
24 of 163 biomes carry cycles (`Village` β₁ = 1, `GildedRot` β₁ = 3).
