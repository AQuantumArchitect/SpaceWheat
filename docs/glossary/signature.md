---
term: signature
short_def: A set of icons. The icon side of a faction or neighborhood.
related: [icon, faction, neighborhood, cloud]
since: 2026-05-09
status: canonical
---

A signature is a set of icons. It is NEVER a set of atoms — that is a cloud.

Factions have a signature: the icons they own and can install in biomes. Access via
`IconRegistry.get_icons_for_faction(faction.name)`.

A neighborhood's signature is the induced set of icons the governing faction installs
in that neighborhood's biome. The biome stays the dissipative scaffold; the signature
is the coherent icon side of the neighborhood.

Read a faction's actual signature (set of icons) through
`IconRegistry.get_icons_for_faction(name)`. The `Faction.cloud` field (array of atoms,
stored as `"cloud"` in `factions.json`) is a distinct concept — a cloud, not a signature.

## Player signature vs biome registers — two different operations

The **player** is a faction (The Demos); the icons it owns are its signature
(`farm.known_icons`). Two action pairs touch icons, on two different objects:

- **Incorporate / Discorporate** — add / remove an icon to / from the *player's
  signature*. Incorporate harvests a ripe, Berry-phase-tracked register's icon into
  `known_icons` (Icon-hat R when tracked + ripe → `player_progress.discover_icon`).
- **Plant / Remove** — add / remove an icon as a *register in a biome* (Icon-hat R on
  an empty plot injects a known icon → `expand_quantum_system`; Icon-hat Q trims one).

So harvest economics ride the *signature*: the POP/reap bonus is paid only when the
harvested register's icon is **incorporated** (in `known_icons`), not merely when its
emoji is known. (`ProbeActions._incorporation_reward_multiplier`.)

## Deprecated term: "vocabulary"

The word "vocabulary" is retired — it muddled cloud (emojis) and signature (icons).
Use **cloud** for an emoji set and **signature** for an icon set. ("Vocabulary" may
still appear meaning a controlled term-set, e.g. the predicate-type lexicon — that is
a different, valid sense, unrelated to cloud/signature.)
