# The Glossary — one page of the canon web

Nineteen terms, one dictionary between the physics and the story. Each entry is a
`.md` file with YAML frontmatter, loaded live into the in-game Guide (X → Guide →
Glossary) by `Core/Documentation/GlossaryRegistry.gd`.

**Authoring rules the registry enforces** (violators are *skipped* with a console
error — check after editing): `term` and `short_def` required; `short_def` ≤ 80
chars (put the poetry in the body); `status` ∈ canonical | proposed; `related`
terms must exist. This INDEX file is deliberately excluded from the in-game load.

## The World — what the game is about

| Term | One line |
|------|----------|
| [enclave](enclave.md) | The closed world of v0 — only measurement leaves a scar. The enclave holds. |
| [measurement](measurement.md) | The enclave's one irreversible act: Born sample, collapse, surprisal payout. |
| [berry](berry.md) | Geometric phase farmed as ripeness — the solid angle a qubit's loop encloses. |
| [webway](webway.md) | A biome's Lindblad flow-graph — the food web. Authored everywhere, sealed in v0. |
| [resonance](resonance.md) | How a faction's twelve axioms sit with a biome's live state, spoken as mood. |
| [invariant](invariant.md) | A number that survives all smooth change — it cannot flow, only jump. |
| [bath](bath.md) | The open world's patient appetite — everything that couples, leaks into it. |
| [fading](fading.md) | What the Bath does — coherence drains, purity falls, color leaves first. |
| [knot](knot.md) | Two closed Berry walks that cannot be pulled apart — winding is why. |
| [bridge](bridge.md) | One fermion split between two biomes — its parity lives in neither. |

## The Matter — what things are made of

| Term | One line |
|------|----------|
| [atom](atom.md) | A single emoji. The smallest named unit of matter in the simulation. |
| [cloud](cloud.md) | A set of atoms. Everything that "touches" a thing. |
| [icon](icon.md) | A named two-atom physics record. Provides H to a neighborhood. |
| [sibling](sibling.md) | Two icons that share at least one pole atom. Depth-0 icon relation. |
| [family](family.md) | family(atom) = every named icon whose poles include that atom. |

## The Order — who arranges the matter

| Term | One line |
|------|----------|
| [biome](biome.md) | A full dissipative scaffold - cloud of atoms + Lindblad physics + visual config. |
| [neighborhood](neighborhood.md) | A configured (biome, induced signature) cluster. Factions own neighborhoods. |
| [faction](faction.md) | An authoring entity that owns an icon signature and neighborhoods. |
| [signature](signature.md) | A set of icons. The icon side of a faction or neighborhood. |

## The web

Reading paths that teach the game in order:

- **The physics story:** enclave → measurement → berry → webway → resonance
- **The topology campaign:** berry → invariant — then play "What Survives"
  (`docs/TOPOLOGY_CAMPAIGN.md`), four invariants across acts 1–4
- **The open campaign:** enclave → bath → fading — then play "What Fades"
  (`docs/OPEN_CAMPAIGN.md`), the wet country across acts 6–8
- **The nonlocal campaign:** berry → knot, and bath → bridge — then play
  "What Connects" (`docs/CONNECT_CAMPAIGN.md`), interleaved through acts 5–7
- **The matter stack:** atom → cloud → icon → (sibling, family)
- **The authoring stack:** biome → neighborhood ← faction → signature
- **The seam between them:** icons carry H onto biomes (neighborhood); the webway
  carries L and sleeps; factions read biomes through resonance; the player scars
  the whole thing through measurement and keeps what berry loops teach.

Every `related:` reference resolves (the registry validates this on load).
