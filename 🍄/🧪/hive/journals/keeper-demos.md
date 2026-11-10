# Keeper journal — The Demos campaign

Seeded 2026-11-09 by the coordinator from the overnight earnest sitting (wave 13). Rewritten at the
end of each sitting; this file is the player's memory between sittings.

## Where I am

- Save: `keeper_demos_latest` (46 flags, banked 2026-11-10 in keeper sitting 5). Act 6 "The Empire"
  of The Demos (banner: "The Demos · Act 6 — The Empire").
- Banks sitting 5: keeper_demos_18 (46, The Bridge Teaching claimed), latest (46).
- Flags before sitting 5: 45. After: 46.
- Seat kp5 stopped. Press budget used: about 85 of 140. Many presses lost to overlays (see Walls).
- Biome tabs: T TheDemos, Y Village, U StarterForest, I Woodlot, O FreshwaterSpring, P Lanternfall.
- Wallet at sitting 5 start: 🦅 17, 🐺 3, 🧺 14, 🪔 8, 🪵 8.

## What I'm doing next

- Two Chores, One Thread (Arc, accepted, Charge row at 50%). Banner walk works for the first two
  steps: Druid [0] Superpose on a plot (0 → 25%), Operator [9] Shift-mark two plots, R gate picker,
  E CNOT (25 → 50%). The row is stuck at 50%. Its text is clipped: "Operator frame: CNOT the pair. In…".
  The remaining step is not on screen. Wall filed (sitting 5). Next sitting: read the full row text
  first (Charge tab, see Walls), then decide. Maybe a second pair or a measurement.
- Wind Twice (Arc, accepted by me? NO: it is the NEXT open door; not accepted yet). Its text: arrange
  two loops with winding 2; Druid rotations around the pole, then walk the second loop around another
  axis; E-inspect the knot card reads the winding.
- Ask the Loop What It Kept, The Long Way Home, Stay Yourself, Hold the Commons, Keep the Forge
  Honest (Arc doors, not yet read in full).
- Trim Icon still needs 13 🐺 (I hold 3). Wolf source still unknown.
- Eagles: 🦅 17. Forest 🦅🐇 is the only eagle plot left (BloodLedger was culled in sitting 4).

## What I know

- The ▸ banner names the next key, often as a chain "X → Charge [U] → Row [G] → Claim [R]". Follow it.
  The Charge tab's READY badge is the truth.
- Hats (number row): Icon 5, Merchant 6, Captain 7, Ace 8, Operator 9, Druid 0. Re-pressing the
  active hat drops you to Ace. Check `wearing_hat` before a hat key.
- Ace: Q Gather (costs 🧺), E Pause, R Strike, F Explore. On an explored plot F is Fast-Fwd.
- EAGLE FARM THAT WORKED (sitting 4): on an explored 🦅🩸 plot Ace F Explore, R Strike, Q Gather gave
  🦅 12 → 38 in one cycle. The Forest 🦅🐇 plot gave 0 at north ~0.34.
- Stuck-loop unlock (confirmed): Strike refusal names Icon [5]. Icon R Incorporate when ripe, Icon F
  stops tracking, then Ace F explores, then Strike works.
- Icon: Q Trim Icon (needs 🐺), E Loops, R Track first / Incorporate, F Track toggles.
- Druid: Q Spin −, E Superpose, R Spin +, F Play. North % is live and drifts with the clock.
- Captain: Q Cull Biome (asks F to confirm; any other key cancels), R Chart. Chart Lanternfall costs
  🦅×21 and needs a free biome slot.
- Operator: Q Break/Bell, E Inspect/CNOT, R Gate, F More. R Gate opens a picker (Q Bell, E CNOT,
  R CZ, F More (1/2)); E picks CNOT on the marked pair. Marks: Shift+plot key (cap 2; a third
  Shift-mark reads "marked X (3/2)"; Shift+plot again unmarks).
- X = story: T Self, Y Arc (open doors, G selects a row, R accepts), U Charge (READY doors,
  G selects a row then R claims), I Guide, O Story.
- Arc row keys: the key sits above its title, so G is the first row. Accept with G then R.
- Plot focus: a plot key picks the plot (first press after a load works now).
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
The Serfs' Word, Hold the Lamp.

Sitting 5 (claimed): The Bridge Teaching (Arc accept, Charge claim; flags 45 → 46).
Accepted, not claimed: Two Chores, One Thread (50%).

## Walls and confusions

- 2026-11-10 (sitting 5, WALL, filed to C:/tmp/sw_wall_kp5.txt): Two Chores, One Thread stalls at 50%
  after the banner walk (Druid Superpose, Operator Shift-mark, R gate, E CNOT). Row text clipped at
  "In…". Re-marking G+J and CNOT again did not move it. The remaining step is not on screen.
- 2026-11-10 (sitting 5): in the Charge tab, G on a non-ready row (Two Chores) closes the overlay
  instead of showing the row. Only READY rows show inspect/claim. The full text needs another route.
- 2026-11-10 (sitting 5): ESC with no overlay opens the pause menu. Presses after that were lost.
- 2026-11-10 (sitting 5): X then U sometimes did not open Charge on the first try (the overlay
  flickered closed). Re-press X, then U, and check `screen_text` before the next key.
- 2026-11-09 (sitting 4, WALL, filed): Two Chores 0% (now the wall is at 50%: the sitting-4 pairing
  issue is resolved; Shift-marks plus R then E make the CNOT count).
- 2026-11-09 (sitting 4): Chart Lanternfall refused silently with 🦅 21 in stock. Only the Captain
  banner said "biome slots full → Cull BloodLedger". The cull cost is not explained on screen.
- 2026-11-09 (sitting 4): the seat FPS dropped to 1 for several minutes after the cull and `=`.
- 2026-11-09 (sitting 4): the Cull prompt banner ("press F to confirm") lingered after the cull and
  after overlays closed. Stale.
- 2026-11-09 (sitting 3): banner read "explore it first → Ace [8] → plot → Explore [F]" for plots
  already explored. Stale; the R label was the truth.
- 2026-11-09 (sitting 3): the Trim Icon wolf (🐺×13) is still unresolved. Still 3 🐺.
- 2026-11-09 (sitting 2, carried): banner oscillation between two hats; F on an untracked plot
  sometimes opened the Memoir overlay (a second F tracked it).
