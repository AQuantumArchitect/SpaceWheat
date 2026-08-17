---
term: incorporation
short_def: Taking a ripe word from the land itself — the ritual that makes a word PAY.
related: [signature, icon, berry, harvest]
since: 2026-07-17
status: canonical
---

**Incorporation** is the act of taking an icon from a ripened loop into the player's
own vocabulary. It writes two ledgers at once: the *signature* (`farm.known_icons`,
via `farm.discover_icon`) and the *incorporation ledger* (`farm.incorporated_icons`,
via `farm.mark_icon_incorporated`) — the second one is written by **no other path**.
It is Icon-hat `R` on a qubit you have tracked (Icon-hat `F`) to ripeness — see
[berry](berry.md) for what "ripe" means (accumulated solid angle past `2π`).

It is a **mid-game rite**, not an on-ramp lesson: early vocabulary comes from faction
*teachings* (an arc quest's claim hands you its `reward_north/south` pair), and the
act-3 chapter "What the Land Remembers" (`first_breath`) is where the game teaches you
to take words yourself. The distinction is economic law: **taught words plant;
incorporated words pay.**

Incorporation is deliberately **not** the same operation as planting: Icon-hat `R` on a
tracked, ripe register incorporates a word; Icon-hat `R` on an *empty* plot instead
**plants** — injects a known icon as a new register into a biome
(`expand_quantum_system`). Same key, two different objects, disambiguated by what's
under the cursor. Planting requires only a *known* word (taught or incorporated);
the [harvest](harvest.md) bonus requires the ritual.

Incorporation is the engine of every `berry_consumed_count_gte` story predicate and
(alongside teachings) of `signature_growth_gte`/`signature_size_gte` (see
`Core/Quests/QuestManager.gd`), it alone gates fractal descent
(`FractalWorldService.enter_icon`), and it gates the harvest bonus: extracting an icon
on the incorporation ledger pays up to 4× the surprisal floor
(`ProbeActions._incorporation_reward_multiplier`); a word you were merely taught — or
recognize by emoji — does not qualify.
