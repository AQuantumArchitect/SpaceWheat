# Physics for the words that had none, 2026-11-16

Nineteen faction listings had no `icons.json` entry in either orientation, so they booted and
planted as bare qubits: no self-energy, no Rabi, no couplings. A bare qubit in a biome makes its
spectrum exactly degenerate (gap 0) and can never ripen. Each now has a first set of numbers,
chosen from the word's meaning (south pole = what it provides) and its owner's neighbourhood, so
that it joins a chain the faction already has instead of starting a clique. No existing word's
physics was touched: every coupling below is the new word's own entry.

## Where the numbers come from

Distributions over the 267 faction-owned (non-`orphaned_icons`) words before this change:

| Quantity | p25 | median | p75 | range used here |
|---|---:|---:|---:|---|
| self_energy_0 | 0.10 | 0.20 | 0.30 | 0.08 to 0.30 |
| self_energy_1 | 0.10 | 0.18 | 0.25 | 0.08 to 0.30 |
| se0 - se1 | -0.08 | 0.03 | 0.15 | -0.10 to 0.15 |
| rabi_coupling (non-zero, 196 of 267) | 0.35 | 0.45 | 0.55 | 0.30 to 0.45 |
| couplings per word | 2 | 3 | 4 | 0 to 3 |
| coupling magnitude | 0.28 | 0.42 | 0.65 | 0.20 to 0.60 |

16% of existing couplings are negative; all new ones are positive (each is a supply link). Targets
are written without U+FE0F (♻, 🕵) because boot loadouts normalise their poles
(`EmojiUtil.normalize`) and `RegisterMap` matches keys exactly.
All new words have a non-zero Rabi so they can ripen and be learned. `Above` has no couplings on
purpose: CycleKeepers' lore says they contribute no Hamiltonian; the cycle is already in
Metamorphosis and Web.

## The nineteen

| Name | Pair | Owner | se0 | se1 | Rabi | Couplings | Reason |
|---|---|---|---:|---:|---:|---|---|
| Suture | 🩸/🧵 | Flesh Architects | 0.18 | 0.15 | 0.40 | 🫀 0.60, 🦴 0.35, 🧫 0.30 | Flesh Architects stitch flesh like fabric: blood gives thread. Couples to Tissue's 🫀, Structure's 🦴 and Culture's 🧫, the faction's own chain. |
| Woodcutting | 👥/🪓 | Hearth Keepers | 0.15 | 0.20 | 0.45 | 🪵 0.50, 🔥 0.40, 🍞 0.25 | Hearth Keepers' people take up the axe for the hearth: feeds Lumber 🪓/🪵 (🪵), the Hearth (🔥), and is paid in bread (🍞). |
| Judgment | ⚖/🌱 | Irrigation Jury | 0.25 | 0.15 | 0.40 | 💧 0.50, 🪣 0.40, 🌾 0.30 | Irrigation Jury: the ruling yields growth. Couples to Allotment's 💧, Furrow's 🪣 and on to grain. |
| Rainfall | 💧/🌧 | Irrigation Jury | 0.20 | 0.10 | 0.45 | 🌱 0.45, 🪣 0.35, 🌾 0.25 | Irrigation Jury's water returned as rain; rain feeds sprout, bucket and grain (Allotment already couples to 🌧). |
| Irrigation | 🪣/🌾 | Irrigation Jury | 0.20 | 0.25 | 0.40 | 💧 0.60, 🌱 0.40, 🛶 0.20 | Irrigation Jury's bucket that yields grain: water in (💧), sprout (🌱), and the Jury's grain-to-barge lean (alignment 🌾→🛶). |
| Density | 🐝/🐇 | Plague Vectors | 0.10 | 0.15 | 0.35 | 🦠 0.40, 🌾 0.30, 💀 0.25 | Plague Vectors thrive on density: a crowded swarm yields crowded hosts, which the pathogen (🦠) feeds on; Host 🐇/🌾 and Vector 🐝/💀 close the chain. |
| Anchorage | 🚢/⚓ | Quay Rooks | 0.30 | 0.20 | 0.45 | 🪝 0.50, 💰 0.35, 💧 0.25 | Quay Rooks: the ship comes to anchor. Couples to Mooring's 🪝, Cargo's 💰, and the water. |
| Usury | 💰/🪝 | Quay Rooks | 0.30 | 0.15 | 0.40 | 🚢 0.35, ⚓ 0.30, 💸 0.30 | Quay Rooks' coin sets the hook ("the docks remember every debt"): ships and anchors in, Debt's 💸 out. |
| Tally | 🛶/📋 | Quay Rooks | 0.20 | 0.15 | 0.45 | 🚢 0.45, 💰 0.30, 🛂 0.25 | Quay Rooks' dockside count: what the boat carries becomes a list; couples to Cargo (🚢, 💰) and Manifest's 🛂. |
| Graze | 🦌/🌿 | Swift Herd | 0.10 | 0.08 | 0.30 | 🐺 0.35, 🌾 0.30, 🐇 0.25 | Swift Herd: "graze, flee, endure". Grazing deer keep the green; Pack's 🐺 hunts them, grain and rabbits share the pasture. |
| Flight | 🐇/🌿 | Swift Herd | 0.08 | 0.10 | 0.30 | 🦅 0.40, 🦌 0.30, 🌱 0.25 | Swift Herd: the rabbit bolts for cover. Raptor's 🦅 drives it; deer and sprout share the ground. |
| Leavings | 🧤/🗑 | The Scavenged Psithurism | 0.10 | 0.20 | 0.40 | ♻ 0.50, 🏭 0.30, 💀 0.30 | The Scavenged Psithurism gather what is left: refuse goes to recycling (Loop's ♻), comes from the factory, sits beside Carrion's 💀. |
| Geode | 🪨/💎 | Volcanic Foundry | 0.20 | 0.30 | 0.35 | 🌋 0.40, 🔥 0.30, ⛏ 0.45 | Volcanic Foundry: "in fire, crystal". Rock that yields crystal; Magma's 🌋 and 🔥 make it, Ore's ⛏ takes it. |
| Kiln | 🌫/✨ | Volcanic Foundry | 0.15 | 0.20 | 0.40 | 🔥 0.45, 💎 0.30, 🏜 0.30 | Volcanic Foundry's firing: smoke yields sparkle. Fire in, crystal and Glass's 🏜 sand alongside. |
| Ore | 💎/⛏ | Volcanic Foundry | 0.30 | 0.15 | 0.40 | 🪨 0.50, 🌋 0.25, 💰 0.30 | Volcanic Foundry: crystal calls the pick. Rock (Ash 🌫/🪨) and Magma upstream, coin downstream (House Adamant's veins). |
| Above | 🦋/🕷 | CycleKeepers | 0.15 | 0.10 | 0.35 | none | CycleKeepers' lore says they contribute no Hamiltonian: the cycle already lives in Metamorphosis and Web's couplings to 🕷 and 🦋. Rabi only, so it can ripen. |
| Freight | 🧂/🛶 | Salt Runners | 0.25 | 0.20 | 0.40 | 💧 0.45, 🔓 0.30, ⛓ 0.25 | Salt Runners: salt pays for the boat. Water carries it, Contraband's 🔓 and Sluice's ⛓ are the route. |
| Sluice | 💧/⛓ | Salt Runners | 0.20 | 0.25 | 0.40 | 🛶 0.45, 🧂 0.30, 🔓 0.30 | Salt Runners' water held behind chains and gates: the boat (🛶), the salt (🧂), the lock (🔓). |
| Search | 🔓/🔍 | Salt Runners | 0.15 | 0.20 | 0.40 | 🧂 0.40, ⛓ 0.30, 🕵 0.30 | Salt Runners: the opened lock yields the search. Salt and chain are what is searched for; Surveillance's 🕵 does the looking. |

## Proposed, not applied: words with Rabi 0

150 of the 387 words have `rabi_coupling` 0 (71 faction-owned, 79 in `orphaned_icons`). A Rabi-0
word still precesses when a live cross-coupling touches it (`QuantumComputer.qubit_has_transverse_term`
reads H, not the JSON), so most of them can ripen in a full biome. 19 of them are seated at boot in a
biome where nothing couples to them: they never leave the pole there, so they can never ripen and
never be learned in that biome. Both lists are in [VOCAB_REPORT.md](VOCAB_REPORT.md)
("Words with Rabi 0" and "Rabi-0 words frozen at boot"). The proposal: give the 19 frozen ones a
Rabi of 0.3 to 0.45, and leave the rest until a playtest says otherwise. Not applied, because those
words already have physics and the brief was to leave it alone.
