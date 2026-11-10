# Keeper journal — The Demos campaign

Seeded 2026-11-09 by the coordinator from the overnight earnest sitting (wave 13). Rewritten at the
end of each sitting; this file is the player's memory between sittings.

## Where I am

- Save: `keeper_demos_latest` (46 flags, banked 2026-11-10 in keeper sitting 6). Act 6 "The Empire"
  of The Demos (banner: "The Demos · Act 6 — The Empire").
- Banks sitting 6: latest (46). No milestone claimed, so no keeper_demos_19.
- Flags before sitting 6: 46. After: 46.
- Seat kp6 stopped. Press budget used: about 30 of 130 (the wall came early, Law 2).
- Biome tabs: T TheDemos, Y Village, U StarterForest, I Woodlot, O FreshwaterSpring, P Lanternfall.
- Wallet at sitting 6 start: 👥 152, 🦅 17, 🧺 14, 🪔 8, 🪵 8, 🐺 3.

## What I'm doing next

- Two Chores, One Thread is back at 0% (Charge tab, row G). Progress from sitting 5 did not survive
  the save/load, as the spawn warned. Its banner text is now readable: "Ace [8]: strike both plots to
  a pole first. Druid [0]: Superpose…". The marked pair is StarterForest (0,2) and (2,2).
- Arc now shows "Light the Bridge" (open, G then R accepts). It is a new door: plant 🌉/🪔 into
  Lanternfall with Icon [5]; [R] plants, [Q] unseats if full. Not accepted yet.
- Wind Twice, Ask the Loop What It Kept, The Long Way Home, Stay Yourself, Hold the Commons are the
  other open Arc doors.
- Next sitting: first try the Strike question on a plot that is clearly not at a pole. If Strike still
  does not measure, go for Light the Bridge instead (it has a concrete step).

## What I know

- The ▸ banner names the next key, often as a chain "X → Arc [Y] → door [G] → Accept [R]". Follow it.
  The Charge tab's READY badge is the truth.
- Hats (number row): Icon 5, Merchant 6, Captain 7, Ace 8, Operator 9, Druid 0. Re-pressing the
  active hat drops you to Ace. Check `wearing_hat` before a hat key.
- Ace: Q Gather (costs 🧺), E Pause, R Strike, F Explore. On an explored plot F is Fast-Fwd.
- Fast-Fwd (Ace F) on a Forest plot ran the drift forward: north 0.17 after 10 s wait.
- Ace R Strike on the marked StarterForest plots did not set measured=True in this sitting
  (about 12 presses across both plots, with E Pause and F Fast-Fwd tried).
- Druid: Q Spin −, E Superpose, R Spin +, F Play. North % is live and drifts with the clock.
- Icon: Q Trim Icon (needs 🐺), E Loops, R Track first / Incorporate, F Track toggles.
- Stuck-loop unlock (sitting 4, confirmed): Strike refusal names Icon [5]. Icon R Incorporate when ripe,
  Icon F stops tracking, then Ace F explores, then Strike works. (No refusal text seen this sitting.)
- EAGLE FARM THAT WORKED (sitting 4): on an explored 🦅🩸 plot Ace F Explore, R Strike, Q Gather gave
  🦅 12 → 38 in one cycle. The Forest 🦅🐇 plot gave 0 at north ~0.34.
- Captain: Q Cull Biome (asks F to confirm; any other key cancels), R Chart. Chart Lanternfall costs
  🦅×21 and needs a free biome slot.
- Operator: Q Break/Bell, E Inspect/CNOT, R Gate, F More. R Gate opens a picker (Q Bell, E CNOT,
  R CZ, F More (1/2)); E picks CNOT on the marked pair. Marks: Shift+plot key (cap 2; a third
  Shift-mark reads "marked X (3/2)"; Shift+plot again unmarks). Operator E Inspect on a plot showed
  no visible text this sitting.
- X = story: T Self, Y Arc (open doors, G selects a row, R accepts), U Charge (READY doors,
  G selects a row then R claims), I Guide (sections: Core Loop, Four Tools, Biomes, Things to Try,
  Quick Reference, Verbs per hat, Glossary), O Story.
- Arc row keys: the key sits above its title, so G is the first row. Accept with G then R.
- Plot focus: a plot key picks the plot. Field keys are columns (G H J K L ;); biome comes from the tab.
- ESC in the farm with no overlay OPENS THE PAUSE MENU ("PAUSED"). Press ESC again to close it.
- DANGER: an overlay left open lets Y/X open the Arc or Story; ESC closes. Check `screen_text`.
- SPEED: `=` speeds the biome clock. Wait in 10 s chunks before reading.

## Doors done

Earlier sittings: The Demos Sleeps, First Harvest, The Wheel Is Yours, First Breath, New Voices,
The Spiral Breaks, The Village Stirs, Timber Country (5 doors), Spring Country (4 doors),
Two Tables, The Forest Stirs, The Mill Runs, Couple the Countries, Couple the Spring,
The Gear-Bench, Hold Commerce, Still the Pond, The Forest Listens Back, Make It Breathe,
A Character, Five Keys, Master of the Mill, The Druid's Loop, The Eagle's Word, Read the Ledger's
Monolith, The Ledger Imposes One Shape, 14 Words, Stay Many, Find Lanternfall, The Record Opens,
The Serfs' Word, Hold the Lamp, The Bridge Teaching (sitting 5).

Not claimed: Two Chores, One Thread (0% at the start of sitting 6; see Walls).

## Walls and confusions

- 2026-11-10 (sitting 6, WALL, filed to C:/tmp/sw_wall_kp6.txt): Two Chores, One Thread at 0%. Ace R
  Strike on the marked StarterForest plots (0,2) and (2,2) did not set measured. north_pct drifted every
  look (0.17 to 0.61), no toast, no refusal text. Fast-Fwd briefly reached north 0.17 on (2,2), and a
  Strike then did not measure it. The pole step is unclear. Wallet 👥 drifted down 152 → 147 over the
  sitting with no visible cause.
- 2026-11-10 (sitting 6): the save/load dropped sitting 5's Two Chores progress (50% → 0%).
- 2026-11-10 (sitting 5, WALL): Two Chores, One Thread stalls at 50% after the banner walk. Row text clipped
  at "In…". Remaining step not on screen. (Sitting 6 now reads the banner in full.)
- 2026-11-10 (sitting 5): in the Charge tab, G on a non-ready row closes the overlay instead of showing the
  row. Only READY rows show inspect/claim.
- 2026-11-10 (sitting 5): ESC with no overlay opens the pause menu. Presses after that were lost.
- 2026-11-10 (sitting 5): X then U sometimes did not open Charge on the first try. Re-press X, then U, and
  check `screen_text` before the next key.
- 2026-11-09 (sitting 4, WALL, filed): Two Chores 0%, later 50% after the Shift-mark + CNOT fix.
- 2026-11-09 (sitting 4): Chart Lanternfall refused silently with 🦅 21 in stock. Only the Captain banner
  said "biome slots full → Cull BloodLedger". The cull cost is not explained on screen.
- 2026-11-09 (sitting 4): the seat FPS dropped to 1 for several minutes after the cull and `=`.
- 2026-11-09 (sitting 3): banner read "explore it first → Ace [8] → plot → Explore [F]" for plots already
  explored. Stale; the R label was the truth.
- 2026-11-09 (sitting 3): the Trim Icon wolf (🐺×13) is still unresolved. Still 3 🐺.
- 2026-11-09 (sitting 2, carried): banner oscillation between two hats; F on an untracked plot sometimes
  opened the Memoir overlay (a second F tracked it).
