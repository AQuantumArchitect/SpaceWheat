---
term: resonance
short_def: How a faction's twelve axioms sit with a biome's live state, spoken as mood.
related: [faction, biome, enclave, icon]
since: 2026-07-04
status: canonical
---

**Resonance** is the live coupling between a faction's personality and a biome's
quantum state. Every faction carries twelve axial bits — its axioms — and each
pair of bits is a *preference over a quantum observable*: how pure it likes a
world, how much entropy it tolerates, whether it wants coherence classical or
woven, populations peaked or spread, sparse or vast, still or storming.
`FactionStateMatcher.compute_alignment` scores those preferences against the
biome's measured observables (Gaussian match per axis, weighted toward purity
and entropy) and returns one number in [0, 1]: how much this place *agrees with
what the faction believes the world should be like*.

That number is never shown as a bare statistic. The quest board's E-inspect
speaks it as mood — *"this place sings to them"*, *"at ease here"*, *"wary of
this place"*, *"restless — the biome grates on their axioms"* — beside the
faction's axiom profile in canon words (`chaos / murk / order / crystal`,
`classical / tinged / quantum / woven`, `still / breathing / restless /
storming`). The mood is also decomposed: the same card names the axiom that
**sings** and the one that **grates** — *they want murk, it reads crystal* —
straight from `FactionStateMatcher.explain_alignment`, whose rows the scalar
averages. The breakdown is the computation; it cannot drift from the score.

### The enclave's politics, for free

Inside the enclave, purity ≡ 1 and entropy ≡ 0 for every biome — the walls hold
(`docs/glossary/enclave.md`). Resonance therefore carries a piece of built-in
politics that nobody had to author: **factions that prefer order and purity are
at home everywhere inside the walls; factions that crave entropy and mixture
are restless in every biome they touch, and will stay restless until Act 2
opens the webway.** What still varies biome-to-biome — coherence, distribution
shape, scale, dynamics — is exactly what the player can steer, which means the
player can *court a faction* by shaping a biome toward its axioms.

### What resonance does (v0)

1. **Speaks** — every market offer carries `faction_alignment` +
   `faction_preferences`; press E on an offer to read the mood
   (`QuestBoard._market_inspect_text`).
2. **Chooses the companion voice** — the physics-derived quantum quest offered
   beside the deliveries is voiced by the offer pool's *most resonant* faction
   (`QuestManager._most_resonant_faction`): the faction most in tune with the
   biome asks the physics question.
3. **Types the ask** — that faction's *operator taste*
   (`calculate_operator_weights` over the same twelve bits) orders the rung-1
   curriculum flavors: **amplitude** (grow a population it speaks),
   **coherence** (superpose), **ratio** (commit a contested pair), **multi**
   (hold two threads at once). Material/direct factions ask for matter;
   mystical ones ask for shimmer; subtle ones ask for balance; prismatic ones
   ask for everything at once.

Rewards stay canonical (the earnest-economy principle): resonance shapes who
speaks and what they ask — never what they pay.

### Tunables

Gloss bands 0.75/0.55/0.35 (`QuestBoard._resonance_gloss`); Gaussian width 0.4
per axis (`FactionStateMatcher._gaussian_match`); flavor headroom gates:
amplitude < 0.55, coherence < 0.65, ratio balance < 0.62, multi coherence
< 0.55 (`QuestPipeline.suggest_*`).

Verification: the resonance path is pure derivation over live state — no RNG,
no persistence; boot the game, open a quest board, press E on any offer.
