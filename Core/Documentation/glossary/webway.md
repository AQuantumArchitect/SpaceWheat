---
term: webway
short_def: A biome's Lindblad flow-graph — the food web. Authored everywhere, still sealed.
related: [cloud, atom, biome, enclave, measurement]
since: 2026-05-30
status: canonical
---

A **webway** is the ecological layer of a biome's dissipative physics: the
`lindblad_outgoing` / `lindblad_incoming` edges on its atom cloud whose
target/source is **another atom** (not the sink `🗑`). It is the food web —
population flowing atom → atom — running in **parallel to the decay-to-sink
layer**. Where the Hamiltonian's couplings are undirected and conservative — a
pendulum, sloshing population back and forth forever — a webway edge has an
*arrow*: it moves population one way, destroys phase as it goes, and never gives
anything back. H is a pendulum; the webway is a river.

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

### Sealed in v0

**The webway is authored in every biome and carries nothing in the shipped
game.** This is the enclave's founding act (`Core/Documentation/glossary/enclave.md`):
`LindbladBuilder` gates on `BalanceConfig.dissipative_enabled()` and builds
**zero** operators in closed mode, so the channels exist as canonical *data* with
no runtime physics. Nothing leaks, because the drains are dry.

The graph views draw the sealed webway anyway — dark orange, dormant, the 🗑 node
retitled "sealed" (`NeighborhoodGraphView`) — because a wall you can see is
worldbuilding and a wall you can't is a bug report. The player should be able to
stand at the channels and wonder what will run through them.

The seal is also the postmortem's fix (`docs/inspiration/OPEN_SYSTEM_ACT2.md`):
the first open build authored H and L as *copies* of one transport graph, and the
two were indistinguishable in population space. The role-separation law drawn
from that failure — H owns everything conservative and phase-carrying; the webway
owns only what is irreversible — is the constitution Act 2 reopens the channels
under. Until then, exactly two things in the game do what the webway does:
**measurement** (the player's collapses — `Core/Documentation/glossary/measurement.md`) and
**the player's own soul** (the τ = 300 s alignment decay — the one open system
inside the walls).

### Why it matters to the economy

The economy is priced by surprisal energy `E = −kT·log p` ([[atom]] populations
feed `p`), and a biome's temperature `kT` scales with its entropy `S`. The reap
"bank" is `kT·S`. The two regimes fund `S` differently:

- **Open (Act 2):** the webway (plus pumps) is what fuels the economy — it
  sustains the `S` that prices and reap yields are drawn from. Strip the webway
  and a biome decays to a single sink atom: `S → 0`, prices and reap yield → 0.
- **Closed (v0, the enclave):** with the webway sealed there is no dissipative
  entropy budget at all. A biome's marginal entropy comes from unitary life —
  entangling gates and shared-H evolution mixing the marginals — and from the
  scars of the player's own measurements. In the enclave, *you* are the webway.

There is **no separate schema key** for the webway — it *is* the non-sink subset
of the existing `lindblad_outgoing`/`lindblad_incoming` edges. "Webway" names the
ecological reading of that data; "decay" names the sink reading. See
`BIOME_AGENTS.md` for the `atom_components` Lindblad schema.

**Anti-pattern:** do not confuse a webway edge with a `decay` edge. `🌿 →(L) 🍂`
inside the biome is webway (recirculation); `🌿 →(decay) 🗑` is sink loss. Same
operator family, opposite ecological role.

Verification: `tests/test_closed_system.gd` (closed → zero Lindblad operators;
open override → operators rebuilt with correct dims).
