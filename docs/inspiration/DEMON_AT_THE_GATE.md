# The Demon at the Gate

**Status: seed bank.** A reading of what the player *is*, physically — already true in
the closed game, waiting to be said out loud, and fully literal in the open one.

## The player is Maxwell's demon

In 1867 Maxwell imagined a small intelligence at a gate between two chambers, sorting
fast molecules from slow ones — creating order, apparently for free, by *looking*. The
resolution took a century: Landauer and Bennett showed the demon's ledger balances
because **information is physical**. Every bit the demon learns must eventually be paid
for; measurement and erasure carry a minimum thermodynamic price of `kT·ln 2` per bit.

Now inventory what SpaceWheat's player does:

- **Observes a quantum field** it did not build and cannot fully know.
- **Extracts value by measurement** — the Born sample that collapses ρ is the only
  income event in the enclave.
- **Is paid in surprisal**: `EnergyPricing.surprisal_energy(p, kT) = −kT·log p`. The
  reward for a measurement is literally the information content of its outcome, priced
  at the biome's own temperature.
- **Is the world's only entropy source** (closed mode): unitary evolution conserves
  everything; the player's collapses are the sole irreversible events in the universe.

That is not a metaphor for Maxwell's demon. That *is* Maxwell's demon, with a farm. The
game's economy already implements the Landauer accounting — the demo just never turns to
the camera and says so.

## What the closed game whispers

The enclave hides half the demon story, deliberately. With no dissipation there is no
`kT` bath to pay erasure costs into — the demon harvests scars and nothing pushes back.
The closed game is the demon's *childhood*: sorting without consequence, information
without heat. The one place the bill is visible is the temperature law itself
(`EnergyPricing.biome_temperature`): hotter, more-mixed biomes pay steeper surprisal —
scarcity IS thermodynamic even when nothing dissipates.

Candidate whispers that cost only words (quest bodies, beats, faction voice):

- ~~A whisper at the improbable-outcome moment~~ — **germinated (2026-07-04):**
  `QuestVoice.MEASURE_WHISPER` fires when a Born sample lands below p = 0.10, one
  line per archetype ("the improbable answered — it chose to be found"). The scar
  has a witness. Berry incorporation and the sealed webway got registers too.
- ~~A late beat noting nothing in the enclave can be unwound~~ — **germinated:**
  the `first_breath` beat now closes with "nothing leaked, nothing faded, nothing
  was forgotten… only measurement leaves a scar — and the scar is yours."
- A Measure Scribes line: *"Every glance is an entry in the ledger. The ledger is the
  world."* — still seed; would need an authored per-faction line slot.
- The Carrion Throne's interest in the player reframed: an empire of order noticing a
  new entropy source. — still seed; `ledger_opens` grants Throne *attention* but the
  framing is not yet spoken aloud.

## What the open game makes literal

When the Bath arrives (`OPEN_SYSTEM_ACT2.md`), the second half of the demon story
switches on:

- **The environment measures too.** Dephasing is the Bath *looking* at the player's
  qubits — decoherence as competition. The player stops being the only demon.
- **Erasure gets a price.** Pumping a biome back to purity (re-preparing states) should
  cost `kT·ΔS` — the Landauer bill, at last. The entropy-bank reap already computes
  this quantity; in the open game it becomes a *cost* surface, not just a reward.
- **The Zeno defense** (watching to keep, not to spend) completes the triad: measurement
  as income, measurement as competition, measurement as shelter.

## The demon decoheres

One more inversion, already true in the shipped build: the *world* is closed, but the
*demon is not*. The player's faction alignment is a density matrix over 12-qubit concept
space (`FactionDensityMatrix` → native `QuantumMythosEngine`), and `Farm` applies
Lindblad decay to it every tick with τ = 300 s. Left alone for five minutes, the
player's identity relaxes — coherent superpositions of allegiance fade unless renewed by
action (settlement rotations, icon-learning, contract exercise all rotate it back).

The enclave never forgets. The demon does. Every claim about the Bath being "outside"
is therefore already false in v0 — the one open system in the enclave walked in through
the front door and is holding the controller. When Act 2 opens the world, it won't be
introducing dissipation; it will be revealing that the player has been shedding
coherence into the world all along.

## Why this matters for the art piece

The pitch "a game that teaches open quantum systems" undersells what is actually here.
The deeper thesis is about **observation as an act with a price** — that looking is
never free, that knowledge is extraction, that the observer is inside the
thermodynamics, not above it. Ecology, economy, and measurement theory are the same
ledger in this game because in physics *they actually are*. When a player feels that —
harvests a scar, watches the forest re-spread, and understands the payment — they have
learned something true that no lecture slide carries.

Say it in-world. The demon should eventually meet its own reflection.
