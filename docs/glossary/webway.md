---
term: webway
short_def: The ecological layer of a biome's Lindblad — non-sink inter-atom flows that recirculate population across the atom cloud.
related: [cloud, atom, biome]
since: 2026-05-30
status: canonical
---

A **webway** is the ecological layer of a biome's dissipative physics: the
`lindblad_outgoing` / `lindblad_incoming` edges on its atom cloud whose
target/source is **another atom** (not the sink `🗑`). It is the food web —
population flowing atom → atom — running in **parallel to the decay-to-sink
layer**.

Two Lindblad layers live on a biome's atom cloud (`atom_components`):

- **Sink-decay** — `decay: {rate, target: 🗑}` (and any `lindblad_*` edge whose
  target/source is `🗑`). Population leaves the biome to the external sink. This
  layer only *lowers* the biome's entropy `S`.
- **Webway** — every `lindblad_outgoing`/`lindblad_incoming` edge between two
  **in-cloud** atoms. Population recirculates rather than leaving. A webway can
  form chains, cycles (`🌲→🐇→…→🌱→🌲`), and oscillations (`☀↔🌙`); these are
  what hold a biome's `S` *up* against decay.

Special case — the **pump**: `lindblad_incoming: {🗑: rate}` (source = the sink)
is an *external drive* injecting population from outside. It is the only edge
that raises population from nothing; a biome with no pump and a net-draining
webway trends `S → 0` (it "dies" — see `BiomeBase.apply_atomic_drain`).

### Why it matters to the economy

The economy is priced by surprisal energy `E = −kT·log p` ([[atom]] populations
feed `p`), and a biome's temperature `kT` scales with its entropy `S`. The reap
"bank" is `kT·S`. So **the webway (plus pumps) is what fuels the economy** — it
sustains the `S` that prices and reap yields are drawn from. Strip the webway and
a biome decays to a single sink atom: `S → 0`, prices and reap yield → 0.

There is **no separate schema key** for the webway — it *is* the non-sink subset
of the existing `lindblad_outgoing`/`lindblad_incoming` edges. "Webway" names the
ecological reading of that data; "decay" names the sink reading. See
`BIOME_AGENTS.md` for the `atom_components` Lindblad schema.

**Anti-pattern:** do not confuse a webway edge with a `decay` edge. `🌿 →(L) 🍂`
inside the biome is webway (recirculation); `🌿 →(decay) 🗑` is sink loss. Same
operator family, opposite ecological role.
