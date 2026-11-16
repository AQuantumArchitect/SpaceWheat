# Inverted seats and the discover rule, 2026-11-16

## Inverted seats

A **seat** is a register qubit with a north and a south. A word is seated **inverted** when the seat
is B/A, B/A is not a word of its own, and the word is A/B. `IconRegistry.find_icon_by_pair` then
falls back to the reversed record, which is the right word. `get_icon_physics_by_pair` returned that
word's physics **unswapped**, and `Icon.from_pair_physics` built the Icon with the seat's poles. So
the word's `self_energy_0`, which belongs to its own pole_0 atom, landed on the seat's north, which is
the word's south atom. Five inverted seats occur in play:

| Seat | Word | Where it comes from |
|---|---|---|
| 🏭/⚙ | Factory ⚙/🏭 | `timber_rhythm` teaches it (Millwright's Union); the 🏭 Manufactory key planted in Village |
| 🪵/🪓 | Lumber 🪓/🪵 | `lumber_flows` teaches it; planted in Woodlot and Village (`woodlot_wakes`) |
| 🩸/🦅 | Predation 🦅/🩸 | `eagle_overhead` teaches it (Carrion Throne); the 🦅 Watched key planted in Village |
| 📜/🏰 | Heritage 🏰/📜 | `ledger_opens` teaches it |
| 🌾/👥 | Subsistence 👥/🌾 | the starting word (`GameState.known_icons`, `Scenarios/demos_normal.tres`); TheDemos itself boots 👥/🌾 its own way |

**The fix** (`IconRegistry.get_icon_physics_by_pair`): when the seat is the reversed word, swap the two
self-energies and mark the physics `seated_inverted`. Rabi is symmetric. `hamiltonian_couplings` are
keyed by the target *atom* and `HamiltonianBuilder` applies them from both source poles, so they carry
over unchanged. Every builder (boot, plant, save restore, SpectralPreview, fractal worlds, the rig)
reads physics through this one function, so every inverted seat, now and in future, gets it.

**What it changes.** For real couplings, the old inverted seat produced exactly the word's own
matrix with the two atoms' labels exchanged. The fixed seat produces the word's own matrix with the
seat's poles relabelled, X·H·X on that qubit. `tests/test_inverted_seats.py` checks that identity to
1e-12. So:

- **The spectrum and the spectral gap do not change**, in Village or anywhere else. Neither do any of
  the campaign's gap thresholds (`empire_imposes`, `island_free` ≤ 0.55).
- **Which atom holds which population does change.** The inverted word's two atoms swap back to where
  the word puts them. This matters wherever the game reads atom populations: strike odds and payouts,
  the market (prices are `−kT·log p` of the marginal), chatter, and the inspector.
- **A freshly planted inverted seat starts at its word's north** (the register south):
  `BiomeQuantumSystemBuilder.seat_kick_angle` gives it Ry(π − kick) instead of Ry(kick), which is
  X·Ry(kick)|0⟩. Without that, the relabelled H plus the old start (the register north, which is the
  word's south) ran a different trajectory from the one the campaign was paced on. Two banner-follow
  journeys stalled at `mill_master` (8 Village berries) waiting for loops that never ripened; the
  inverted Lumber seat, which has Rabi 0, is the likely one. With the start relabelled as well, an
  inverted seat runs exactly the trajectory the old seat ran, poles relabelled: the same ripening,
  the same Berry phase, and the populations on the atoms the word means. The probe checks
  ρ_inv = X·ρ_own·X after a real plant.
- The table's P(south) column is the **boot** path (`initialize_ground_state`, ground state plus a
  dawn kick of Ry(kick) on every qubit). It is not a plant. No biome boots an inverted seat, so the
  boot kick was left as it is; that is why the numbers there are not simply 1 − P.

**Village.** Measured with `tests/vocab_boot_probe.gd` (`SW_VOCAB_AXES` override) before and after
the fix, using the compositions the campaign builds in Village (`act3_5_drive.py`: natives, wood,
pond, then a door key):

| Village composition | gap before | gap after | E₀ before → after | inverted qubit: P(south) at boot, before → after |
|---|---:|---:|---|---|
| boot loadout: Labor 👥/🍞 · Hearth 🔥/❄ · Capital 💰/⚙ | 0.2108 | 0.2108 | 0.9832 → 0.9832 | (own seat: unchanged) |
| + the starter 🌾/👥 (Subsistence, inverted) | 0.1771 | 0.1771 | 0.9565 → 0.9565 | 0.088 → 0.637 |
| + 👥/🌾 (Subsistence, its own way) | 0.1771 | 0.1771 | 0.9565 → 0.9565 | (own seat: unchanged) |
| + 🪵/🪓 (Lumber, inverted: woodlot_wakes) | 0.2108 | 0.2108 | 0.8782 → 0.8782 | 0.760 → 0.576 |
| + 🪓/🪵 (Lumber, its own way) | 0.2108 | 0.2108 | 0.8782 → 0.8782 | (own seat: unchanged) |
| + 🪵/🪓 + 💧/🌊 (spring_wakes) | 0.0620 | 0.0620 | 0.4064 → 0.4064 | Lumber 0.760 → 0.576 |
| … + 🏭/⚙ (Factory inverted: the 🏭 Manufactory key) | 0.0510 | 0.0510 | 0.4064 → 0.4064 | 0.497 → 0.813 (Lumber 0.760 → 0.576) |
| … + ⚙/🏭 (Factory its own way) | 0.0510 | 0.0510 | 0.4064 → 0.4064 | (own seat: unchanged) |
| … + 🩸/🦅 (Predation inverted: the 🦅 Watched key) | 0.3736 | 0.3736 | 0.1732 → 0.1732 | 0.389 → 0.271 (Lumber 0.760 → 0.576) |
| … + 🦅/🩸 (Predation its own way) | 0.3736 | 0.3736 | 0.1732 → 0.1732 | (own seat: unchanged) |
| … + 💨/🔨 (the 🔨 Artisan key) | 0.4373 | 0.4373 | -0.7531 → -0.7531 | Lumber 0.760 → 0.576 |
| … + 💸/💀 (the 💀 Cemetery key) | 0.0571 | 0.0571 | -0.0492 → -0.0492 | Lumber 0.760 → 0.576 |
| boot + 💧/🌊 + 🏭/⚙ + 🩸/🦅 | 0.1098 | 0.1098 | 0.2808 → 0.2808 | Factory 0.404 → 0.872; Predation 0.389 → 0.271 |


**The spec.** I left the four teachings as written. The brief asked me to fix any that were simply
written backwards. Predation's prose ("blood under the eagle") reads as 🦅 over 🩸, and act3_5_drive's
comment ("Predation FLIPPED per the signature law") says it was inverted to get past the discover rule,
which this PR removes. But the orientation is load-bearing: a plant costs "🌱×5 + 13 of its south
pole".
- Lumber's 🪓 cost has its own trade, its rescue line and tests (`supply_rescue_smoke.gd`).
- Factory written ⚙/🏭 would cost 13 🏭. No biome holds 🏭 until that very plant, so no contract could
  pay it.
- Predation's 🩸 is only on the board once BloodLedger is charted.

With the physics now right, an inverted seat is the same word, so flipping the spec only moves costs
and display. That is a campaign-economy change I did not want to make unseen overnight. It is a
four-line spec edit once you decide.

**Old saves.** Saves hold seats as `{north, south}`. On load, a biome with a runtime-planted seat is
rebuilt through `icons_from_axes` (`GameStateSerializer`: dimension or physics-signature mismatch).
Its H is therefore migrated to the corrected physics. Its saved ρ is restored as it was, so the state
carries the old populations until it evolves.

## The discover rule

`Farm.discover_icon` refused any word whose north was already a pole of a known word. You called it
a helper for the randomizer, not a rule of the game universe. The randomizer it served,
`IconPairing`'s north roll ("North cannot be an emoji already in the player's cloud"), no longer
exists. No procedural generator calls `discover_icon` (`ProceduralIconBiome`,
`BiomeDiscoveryForecastService` and `IconLoadoutInducer` never applied the rule). The one live
procedural filter, `QuestManager._is_valid_offer_with_icons` (market icon offers; dormant), is kept.

`discover_icon` now refuses only a word already held, in either spelling (`IconRegistry.same_word`).
Both words of a pair (Labor 👥/🍞 and Bread 🍞/👥) can be known. Factory known as 🏭/⚙ is still known
when it shows up as ⚙/🏭. Mirrors updated:
- the Guide's unknown-word columns;
- the incorporate outcome (`already_known` uses `same_word`) and its toast;
- `tools/campaign/validate.py`'s reachable-vocabulary model.

**Consequences for the campaign**

- No teaching is silently dropped any more. The old rule refused Predation 🦅/🩸 outright (🦅 is
  anchored by `first_breath`'s Raptor 🦅/🐇), and refused Factory ⚙/🏭 once Capital 💰/⚙ was
  incorporated. That is why the spec teaches them inverted.
- More words are reachable earlier. `validate.py --report`'s reachable-signature column rises at
  65 of 71 beats:

| Beat | Reachable before | Reachable after |
|---|---:|---:|
| first_breath | 9 | 10 |
| woodlot_door | 9 | 12 |
| two_tables | 10 | 14 |
| island_lives / village_identity | 13 | 17 |
| ledger_opens … island_free | 15 | 21 |

  Every signature gate still sits below what is reachable (0 errors, 0 warnings). They will tend to
  fire sooner in play.
- `Farm.get_icon_for_emoji` (used by `ActionValidator._can_execute_icon_assign`) returns the first
  known word holding an emoji. That is now ambiguous when two known words share a pole. It is only an
  availability check, so I left it alone.
