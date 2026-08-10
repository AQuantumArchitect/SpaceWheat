---
term: sibling
short_def: Two icons that share at least one pole atom. Depth-0 icon relation.
related: [icon, atom, family, cloud]
since: 2026-05-09
status: canonical
---

Two icons are siblings if they share at least one pole atom (i.e., one of icon A's
poles equals one of icon B's poles). The relation is symmetric, depth-0, and does
not consider Hamiltonian coupling targets.

Siblings are the tightest icon-to-icon relation. A faction's siblings are all icons
in the global registry that share a pole with any of the faction's own icons.

Computed by `IconRelations.is_sibling(a, b)` and `IconRelations.siblings_of(icon, all)`.

**Contrast with siblings-via-cloud:** `IconRelations.siblings_via_cloud_of` widens
the relation to icons whose poles touch any atom in the subject icon's full cloud
(including Hamiltonian coupling targets), not just its two poles.

**Contrast with family:** `family(atom)` is atom-keyed (all icons containing that
atom). Siblings is icon-keyed (icons that co-touch any of this icon's poles).
