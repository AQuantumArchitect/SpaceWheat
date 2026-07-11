# Farming a Density Matrix

> The ten-minute version of what this project is, for the reader who may
> never launch it. If you want the claims audited, the companion piece is
> [FOR_PHYSICISTS.md](FOR_PHYSICISTS.md) — every concept graded for honesty,
> every grade with a test behind it. If you want to play, start with
> [HOW_TO_PLAY.md](HOW_TO_PLAY.md). This is the piece about *why*.

## The wager

SpaceWheat is a farming game in which every field is a density matrix — the
full quantum-mechanical description of a small system, evolving under a real
Hamiltonian, measured by the real Born rule, decohering under real Lindblad
channels. Not "quantum-themed." Not dice with ket notation painted on. When
you plant, a state is prepared; when you measure, a state collapses; when
the world forgets your work, that forgetting is a completely positive
trace-preserving map with a name and a rate.

The obvious question is *why*. Games have faked their physics since Pong,
happily and well. Nobody audits a farming game.

The wager is this: in an age where generated content is effectively free,
the scarce thing left is **constraint honored all the way down**. Anyone —
any person, any model — can produce a game that gestures at quantum
mechanics. What can't be hallucinated is two years of refusing the gesture:
building the engine first, then discovering what kind of game the equations
were willing to be. This document is a tour of what that refusal produced,
because the surprising answer is that the constraint turned out to be the
best game designer in the room.

## The refusals are the curriculum

Most educational games teach by *adding* — tutorials, diagrams, quizzes
bolted to the fun part. SpaceWheat mostly teaches by **refusing**, because
the physics refuses, and the game declines to soften it. A few of the
refusals a player runs into:

**You cannot copy anything.** There is no duplication exploit anywhere in
the game, not because the economy was carefully balanced, but because the
no-cloning theorem is structural: states aren't data to copy, they're the
world itself.

**A fog cannot be planted.** The planting verb is a coherent Rabi pulse — a
rotation of the state toward its pole. Rotations preserve purity by theorem,
so a plot that has decohered into a fog cannot be rescued by any amount of
coherent effort; the pulse aligns what's left, and caps there. Purity only
comes back through *dissipation* — measure the plot, or kick it with a
dissipative jolt. The game does not explain unitarity in a text box. It lets
you press the button on a fog and feel the theorem say no.

**No contract can sell you back your phase.** In the open-world economy you
can sell your coherence to the environment — a dephasing contract, real
money for real decoherence. The reverse trade does not exist, and the button
that would offer it is permanently disabled with the reason written on it:
decoherence is irreversible; coherence returns only through your own gates.
The second law, rendered as a greyed-out chip.

**Closed systems have no destiny.** The in-game compass shows every biome's
dominant eigenstate — what the place most *is*. In a closed system that
compass honestly reads identity, never destiny, because unitary evolution
has no attractors: nothing in a closed world is *going* anywhere, forever.
The game says this out loud, because saying less would be a lie, and saying
it turns out to be the whole first act's thesis.

None of these were design decisions in the usual sense. They were
discoveries about what the mathematics would permit, kept intact because the
moment you soften one, the player's intuition — which is the actual product
— trains on a falsehood.

## Measurement is the economy

The load-bearing mechanic is the one that costs something in real physics:
looking.

In the game's first world — *the enclave*, a closed system where evolution
is exactly unitary and purity is conserved to machine precision — nothing
decays and nothing is ever lost. In that world, the player's measurement is
the **only irreversible act in the universe**. So the economy is built on
it: harvesting a plot samples it by the Born rule and pays the *surprisal*
of the outcome, −kT·log p. Rare answers pay more, because you learned more.
The player is not farming wheat; they are farming *information*, and the
game keeps Maxwell's-demon bookkeeping about it — kT is computed from the
live entropy of the field being farmed, and the endgame says the quiet part
loud: an entropy farmer in a leaking world is an industry, and the empire
has noticed.

This inversion — measurement as scar, the one thing a perfect world cannot
undo — carries the entire first game. And then the story walks the player
out of the enclave, into a world that leaks, and the same verb flips
polarity: out there, repeated measurement is the only thing that *keeps* a
dying state alive (the quantum Zeno effect, played straight on the live
state). The game's deepest sentence sits at that hinge:

> In the enclave, looking is the only way to spend.
> Out here, looking is the only way to keep.

Same key. Same physics. The player's oldest reflex, recast at the exact
moment the world's character changes. No new controls were added for the
entire second act — that was a design law, because the point of the act is
that *the world* changed, not the player's hands.

## Three campaigns, one course

The story is structured as a physics course that never admits to being one.

**What Survives** is the closed world's campaign: invariants. The things
unitary motion cannot touch — the spectrum of a state, the geometric phase
banked by a closed loop (ripeness, in farm language, and it is genuinely the
Aharonov–Anandan phase of the actual path), the protected edge of a
dimerized chain, the non-commutativity of a braid. The player learns what
*cannot change*, in a world where nothing is ever lost.

**What Fades** opens the door and teaches arrows: dephasing first — the
world goes gray while nothing moves, an exact T₂ channel with the
populations pinned — then decay, then the Zeno counterplay, then basins:
open systems have attractors, steady states with memory, bistables that
refuse to flip back. The rot in one biome literally feeds on itself — a
nonlinear self-kindling channel whose two stable basins are verified
headlessly in the repository, because a claim about bistability is
checkable and therefore checked.

**What Connects** teaches nonlocality with the one structure the
environment cannot eat: a bit stored in the *joint parity* of two anchors
in two different biomes, readable at neither end alone. Its protection is
not scripted — it is derived, the product of both shores' local noise
rates, which makes the closed home island the strongest foundation in the
open world. Braiding writes into it; only fusion reads it; reading spends
it. Every law the game taught, in one artifact.

The connective tissue among all three: **openness is a place, not a
setting**. Sixty-four of the game's 162 biomes author real dissipative
structure; the other 98 author none, and stay coherent not by flag but by
fact. The world map *is* a thermodynamic map. The player chooses their
exposure to irreversibility by walking. And the island they grew up on
stays closed forever — not as a technical limitation but as the emotional
architecture of the whole piece: the enclave becomes home, the place
nothing can rot, which is exactly what the open world teaches you to miss.
That promise is not enforced by a story flag. It is enforced by the
simple absence of any code path that can install a dissipator on closed
ground. The sentiment is a theorem.

## You are a quantum system too

The last system turns the instrument around. The player's identity is
itself a density matrix — a state over a 12-axis space of faction concepts,
with all the machinery that implies. Learn something (incorporate a ripe
qubit's word into your signature) and mass moves toward the factions who
think in that word. Stop learning, and your off-diagonal terms decay on a
five-minute clock: the superposition of people you might have been,
reclaiming you. Purity is readable on the map screen — **You · Tr(ρ²)** —
and the game glosses the bands in plain language: resolved, leaning, torn,
smeared. Factions treat you by the overlap between who you are and what
they axiomatically want, computed, not scripted.

The honest constraint here was the renewal rule: the only thing that
concentrates identity is *learning*. There is no gym to grind, no
purity-per-click. Who you are is what you learned, and it fades unless you
keep learning — which is either a bleak sentence or a hopeful one, and the
game lets the player decide which, per the whisper their nearest faction
sends when their band crosses.

## The honesty contract

All of the above is claims, and claims rot. So the project carries its own
audit machinery, on the principle that a physics game earns exactly as much
trust as it can demonstrate:

- **The ledger.** [FOR_PHYSICISTS.md](FOR_PHYSICISTS.md) lists every
  concept the game touches with an honesty grade — *exact* (the number on
  screen is the quantity, computed by the true equation on the live state),
  *faithful* (real equations, reduced model), or *suggestive* (a gesture,
  admitted as one). Nothing suggestive is ever presented as exact, and the
  grades err conservative.
- **The assays.** Standalone Python ports of the physics — no engine in the
  loop — verify the claims that can be verified numerically: the SSH edge
  mode, the Zeno formula, dark-state interference, the planting pulse's
  unitarity and its fog-cap theorem, the dephasing channel's exactness, the
  bistability of the self-kindling map. Each exits nonzero if any claim
  fails.
- **The postcards.** Every screenshot the game exports carries its physics
  in the pixels — a watermark strip encoding the live state, with a
  sidecar certificate — so even the marketing material is falsifiable.

This is, admittedly, an unusual amount of epistemic plumbing for a farming
game. But it is the part of the project I would defend most stubbornly,
because it is the part that answers the era's question. Anyone can claim
their game is real physics. The interesting move is to make the claim
*checkable*, grade your own honesty in public, and ship the tests beside
the fiction.

## What it was for

Two years is a long time to spend refusing shortcuts. The first attempt at
an open-system world died precisely because it took one — dissipative
channels were allowed to duplicate what the Hamiltonian already did, the
physics stopped meaning anything, and months of content had to be buried.
The rebuild happened under laws (role separation between H and L; dephasing
first; no new controls for the core loop; openness is a place) that read
less like a design document and more like a treaty with the mathematics.

What came out the other side is the thing I was actually after: a game
whose *feel* is downstream of theorems. The satisfaction when a bistable
biome finally flips is the shape of a basin boundary. The dread of the wet
country is a decay rate. The safety of home is purity conservation. When a
player who has never seen a bra or a ket learns — in their hands, the way
you know a game — that looking has a price, that some doors only open one
way, and that what survives is what nothing can touch, they have learned
quantum mechanics in the only sense that ever really transfers.

The machine that helped build this could have generated a thousand
plausible quantum farming games in the time this one took. It could not
have generated the two years of *no*. That's the portfolio piece.

---

*The engine, campaigns, assays, and this document live in one repository.
Start anywhere: [HOW_TO_PLAY.md](HOW_TO_PLAY.md) for the first ten minutes,
[FOR_PHYSICISTS.md](FOR_PHYSICISTS.md) for the audit,
[gallery/index.html](gallery/index.html) for the view.*
