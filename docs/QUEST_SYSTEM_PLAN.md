# Quest System Rebuild — Plan (2026-06-17)

> **Status update (2026-07-04): substantially implemented.** This plan is now a
> design→execution record, kept for the reasoning. Where things landed:
>
> - **Phase 0–1 shipped.** `QuestPipeline` is the single construction path; market,
>   story, and tutorial quests share one schema, one soft-predicate completion path
>   (`state_predicates` are authoritative — geometric-mean `smooth_and` against 0.85),
>   and one board. `QuestVoice` voices all market quests.
> - **Phase 2 shipped, personality-typed.** The quantum quest types generate live via a
>   curriculum ladder whose rung-1 flavor is chosen by the faction's operator taste
>   (`calculate_operator_weights`): amplitude (`population:<emoji>` observable),
>   coherence, ratio (`balance:A/B`), multi (composed predicates) — entanglement
>   (max MI, native-cache observable) as rung 2. UI shows live observable → target.
> - **Phase 3 shipped.** Act-0 tutorial chain (7 steps, one mechanic each, soft-gated),
>   including the entanglement step; the 5-act story-flag arc rides the same predicates.
> - **The "gem" is wired** (stage 2 of the pipeline diagram): every offer carries the
>   faction's live resonance (`Core/Documentation/glossary/resonance.md`); the most resonant faction
>   voices the companion quest.
> - **Voice went further than planned:** ten archetypes with 3×3 phrase banks
>   (content-hash selection, no RNG), identity-derived archetypes for all ~99 factions
>   (domain/ring/tags — the bits were tried and rejected, 20% vs 83% agreement), and
>   three whisper registers (webway/berry/measure) at the world's speaking moments.
> - **Phase 4–5 partial by design:** arc flags run through `island_stops_asking` and
>   `edge_of_the_enclave`; `chain_branch` seeds exist in the tutorial; quest journal and
>   faction-relations views remain future work. Reap ritual is explicitly **reserved**
>   for the open expansion (owner decision — see `inspiration/OPEN_SYSTEM_ACT2.md`).

**Goal:** make the quest system the game's **narrative attachment point** AND its **introduction to
mechanics** (tutorial), built on the now-simplified closed (Hamiltonian-only) engine.

**Decisions locked with owner (2026-06-17):**
1. **Fully unify** market + story + tutorial into ONE quest object + pipeline + UI.
2. **Scripted Act-0 questline** for onboarding (one mechanic per quest, soft-gate gated).
3. **Revive the non-delivery quantum quest types** (SHAPE/EVOLUTION/MAINTAIN_COHERENCE/ENTANGLEMENT)
   as teaching tools — enabled by the closed-system simplification (purity=1, deterministic).
4. **Hybrid authoring**: hand-authored arc spine (the "Demos" story + Act 0) + procedural,
   faction-voiced market side quests for endless play.

---

## The finding that drives this: two halves of one system

- **Live (contract-market)** = strong *mechanics*: physics-derived generation (surprisal pricing),
  economy, soft-gate completion, deterministic rewards (surprisal budget + vocab ×4 + standing +
  pre-rolled icon). Weak: **zero narrative** (every quest is "Deliver 🌾"); delivery-only.
- **Deprecated cluster (dead, 5 files/1487 LOC)** = strong *narrative design*: faction voices,
  verb vocabulary by faction-axiom, complexity→quest-type variety, and `FactionStateMatcher`'s
  "faction axioms are *preferences over quantum observables*" coupling. Weak: never finished
  (`.cloud` crash), only delivery completable, static tables.
- **Missing entirely:** onboarding. New game = bare biome + trial-and-error + a reference Guide
  tab. The 5-act arc is the de-facto tutorial but teaches implicitly over ~5–6 hrs; `first_breath`
  grants/explains nothing.

The fusion is the whole plan: **one pipeline that is economy + narrative spine + tutorial.**

## Salvage ledger

| Source | Verdict | What |
|--------|---------|------|
| `FactionStateMatcher` (LIVE) | **KEEP — the gem** | 12-bit faction prefs → quantum observables → `(alignment, complexity, intensity, urgency, variety)`. Makes "story IS the physics" literal. |
| Non-delivery quest types (impl, never spawn) | **REVIVE** | SHAPE_ACHIEVE / EVOLUTION / MAINTAIN_COHERENCE / ENTANGLEMENT — the teaching tools for reading/steering state. |
| `QuestTheming` complexity→type, resonance gate, Fibonacci quantities | **EXTRACT then delete** | Port the thresholds/ideas into the pipeline. |
| `FactionVoices` (10 voices) | **EXTRACT as palette, proceduralize** | Seed; then derive voice per faction from cloud/bits (not static 10-for-32). |
| `QuestVocabulary` (18 verbs + bit-affinity) | **EXTRACT, generalize** | Verb-by-faction-axiom selection is good; generalize beyond delivery. |
| `QuestGenerator` composition template | **EXTRACT** | prefix + (adverb verb qty adjective resource @location urgency) + suffix. |
| `BiomeLocations` static table | **DISCARD** | Proceduralize from biome state, or drop. |
| The 5 dead files | **DELETE in Phase 0** (after extraction) | QuestGenerator, QuestTheming, BiomeLocations, FactionVoices, QuestVocabulary + update test_surface_refactor_snapshot.py:283-284. |

## Target architecture: one quest, three sources, soft completion

```
SOURCES                         UNIFIED PIPELINE (single code path)
┌─ Tutorial (authored Act 0) ─┐  1. generate(source) → raw spec
├─ Story arc (flags, authored)├─ 2. parameterize(faction,biome)  [FactionStateMatcher]
└─ Market (procedural physics)┘  3. type-select by complexity (delivery→shape→evolution→entangle)
                                 4. build SOFT predicates (completion = soft_gate / smooth_and)
                                 5. voice(faction) → procedural flavor
                                 6. reward plan (surprisal budget + vocab ×4 + standing + icon)
                                 7. present (one quest object, one UI)
                                 8. track soft-continuous → ready → grant → fire chain/flags
```

One **Quest** schema for all sources: `{id, source, faction, biome, type, params, predicates,
voice, reward, chain{prereqs,unlocks,branch}, tutorial_meta{teaches,hint}}`. Chains/prereqs/branch
let a quest unlock another, a flag spawn a real parameterized quest, and arcs branch on faction
siding.

## Cross-cutting principles (honor everywhere)
- **Soft continuous geometry >>> hard rules** — completion, tutorial gating, and progress are all
  soft_gate/smooth_and. The progress bar IS the teacher.
- **Story IS the physics** — quests are lenses on the quantum state, voiced by factions; never
  bolted-on scripted text. ([[project_game_narrative_model]])
- **Player is The Demos** — the vocab-escape (plant vocab → harvest people → net positive) is both
  the tutorial's climax and the base-game loop. ([[project_player_is_a_faction]])
- **No special cases / emergent only** — quests tune existing physics, add no channels.
- **Earnest economy** — rewards from canonical config; no fallbacks. ([[feedback_h_and_l_balance_together]])
- **Closed-system is the enabler** — deterministic unitary evolution makes quantum quests reliable.

---

## Phases (each independently shippable + testable)

### Phase 0 — Foundations & extraction
- Extract the salvageable ideas (table above) into the pipeline design / a small `QuestVoice` +
  `QuestTyping` helper; then **delete the 5 dead files** + fix `test_surface_refactor_snapshot.py`.
- Define the canonical **Quest schema** (one Resource/dict, one place).
- Stand up `QuestPipeline` (the 7-stage flow) as the single entry. Refactor the *existing* market
  and story paths to FEED it via thin adapters — **no behavior change yet** (de-risks unification).
- Tidy the 3 orphaned `quest_rewards` tuning keys from the prior sweep.

### Phase 1 — Unify the two live paths
- Market + story-arc quests both produced by the pipeline → same object, same UI, same completion.
- **Faction voice on ALL quests** (procedural) — kills the flavorless "Deliver 🌾".
- Soft-continuous completion everywhere (market delivery shows partial progress too).
- Chain/prereq/branch infrastructure (quest→quest unlocks; flag→quest; arc branching).

### Phase 2 — Revive the quantum quest types (teaching tools)
- Activate complexity-driven generation of SHAPE/EVOLUTION/MAINTAIN_COHERENCE/ENTANGLEMENT (they
  already track + complete; need generation + UI predicate breakdown).
- UI shows the live observable vs target ("purity 0.62 → target 0.70") so the player learns the
  observable by watching it move. Each type teaches one physics concept.

### Phase 3 — Act 0 tutorial questline (the introduction)
- Author the linear Act-0 chain as real pipeline quests, each teaching ONE mechanic via a soft-gate
  the player watches fill, gating the next:
  plant → measure → harvest (learn first icon) → reap → first contract → **vocab-escape "aha"**
  (plant vocab in Village → harvest people → net positive) → first cross-biome delivery.
- Wire into `new_game_easy` boot; Act 0 gates biome discovery. The existing 5-act arc becomes
  Act 1+ (narrative) on top.

### Phase 4 — Narrative depth: the Demos arc + branching
- Authored spine: the "Demos" base-game story (vocab→village→people→escape), with the
  Tomato Conspiracy as a later arc ([[project_tomato_conspiracy]]); procedural faction-voiced
  market side quests for endless play.
- Branch arcs by faction siding (standing thresholds unlock different lines).
- StoryEngine's story graph is the spine (already running).

### Phase 5 — UI/UX & polish
- Unified Quest Board: one object across Market/Commitments/Arc/Tutorial; predicate breakdowns
  ("why" for soft scores); quest journal (which icons came from which quests); faction-relations view.
- Onboarding surfacing: Act-0 quests prominent; a soft "suggested next action" nudge (not forced).

---

## Risks / watch-items
- Market generation+reward (interference tensor, surprisal budget) is complex/partly opaque —
  **adapter-first in Phase 1** so unification can't break it.
- Tutorial must not feel like rails in a sandbox — soft gates + "suggested, not forced" framing.
- Branching narrative scales authoring cost — keep the authored spine tight; lean on procedural sides.
- Reviving quest types: do NOT reintroduce hard rules (use the soft predicates).
- FactionDatabase faction dicts expose the atom set under the `cloud` key (was the misnamed `sig`); use `cloud`/`all` from get_faction_cloud() when porting theming.

## Open questions for the next planning pass
- Exact Act-0 quest list + the precise mechanic each teaches (storyboard the first 30 minutes).
- Procedural faction-voice generation method (template interpolation from signature vs. a small
  authored voice per faction).
- How aggressively market side quests should spawn the quantum types vs. delivery (difficulty curve).
- Where the Demos main arc diverges into the Tomato Conspiracy and other faction lines.
