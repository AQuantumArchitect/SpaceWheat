---
term: family
short_def: family(atom) = every named icon whose poles include that atom.
related: [atom, icon, sibling, cloud]
since: 2026-05-09
status: canonical
---

`family(atom)` is the atom-keyed inverse of "what icons contain this atom as a pole."
It answers: "given this single atom, which icons speak its language?"

Example: `family(🔥)` = every icon with `pole_0 == "🔥"` OR `pole_1 == "🔥"`.

Families are indexed by `IconFamily.family_of(atom)` and
`IconFamily.family_of_cloud(cloud)` (the union of families over a set of atoms).

The inducer (`IconLoadoutInducer`) uses family-via-cloud to pre-filter neighborhood
candidates: a candidate icon must be in `family_of_cloud(union_of_clouds(faction.signature))`
— i.e., it must be in the family of at least one atom in the faction's combined cloud.

**Contrast with sibling:** family is atom-keyed (given an atom, list icons).
Sibling is icon-keyed (given an icon, find icons sharing its poles).
Both are depth-0 relations; neither performs graph traversal.
