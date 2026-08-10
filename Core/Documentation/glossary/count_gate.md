---
term: count_gate
short_def: A soft gate re-centered so an integer count fires exactly AT the stated N.
related: [soft_gate, width]
since: 2026-07-17
status: canonical
---

A **count gate** is [soft_gate](soft_gate.md)'s variant for INTEGER COUNTS — "≥ 3
berries," signature size, atom diversity (`QuestMath.count_gate`,
`Core/Quests/QuestMath.gd`; the type list lives in `QuestManager.COUNT_GATE_TYPES`).

Plain `soft_gate` is only `0.5` at the authored `value` and needs `x` to clear it by
roughly one [width](width.md) before the flag actually fires — for a continuous
observable that's the intended slack, but for a stated integer it silently demanded
"≥ 3" to mean closer to 4 (fleet finding: nine testers stalled on a count that read
as met but wasn't). `count_gate` shifts the gate's *center* down by that same offset
so the `0.5 → FLAG_FIRE_THRESHOLD` crossing lands exactly on the authored `N`:
`count_gate(x, center, width) = soft_gate(x, center − offset, width)`, where `offset =
fire_value(0, width, threshold)`. `N` means `N`.

Contrast with soft_gate: a soft gate's `value` is the score's `center` (0.5 point),
and its true firing point is `center + width·atanh(...)` — a number the player never
sees unless they read `predicate_fire_target`. A count gate's `value` **is** the firing
point; there is no separate target to report.

`PredicateGloss.formula()` (the literalist read-out on Arc E-inspect) labels a count
predicate `count_gate` and still prints its `width` alongside it — but that width is
display context, not a shifted-target width like soft_gate's. It only shapes how much
partial credit shows on the way to `N` (the transition's steepness); it never moves
where the gate actually fires, because the re-centering already pinned that to the
authored integer.
