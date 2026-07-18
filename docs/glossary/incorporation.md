---
term: incorporation
short_def: Adding a ripe icon to YOUR signature — the only way your vocabulary grows.
related: [signature, icon, berry, harvest]
since: 2026-07-17
status: canonical
---

**Incorporation** is the act of adding an icon to the *player's own signature*
(`farm.known_icons`), via `farm.discover_icon(north, south)`. It is Icon-hat `R` on a
qubit you have tracked (Icon-hat `F`) to ripeness — see [berry](berry.md) for what
"ripe" means (accumulated solid angle past `2π`).

Incorporation is deliberately **not** the same operation as planting: Icon-hat `R` on a
tracked, ripe register incorporates a word into your signature; Icon-hat `R` on an
*empty* plot instead **plants** — injects a known icon as a new register into a biome
(`expand_quantum_system`). Same key, two different objects, disambiguated by what's
under the cursor.

Incorporation is the sole engine of `signature_growth_gte`/`signature_size_gte` story
predicates ([soft gate](soft_gate.md)/count-gate respectively — see
`Core/Quests/QuestManager.gd`), and it gates the [harvest](harvest.md) bonus: extracting
an icon you have incorporated pays up to 4× the surprisal floor
(`ProbeActions._incorporation_reward_multiplier`); an icon you merely recognize by emoji
does not qualify.
