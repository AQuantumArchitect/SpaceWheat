# Keeper journal — The Demos campaign

Seeded 2026-11-09 by the coordinator from the overnight earnest sitting (wave 13). Rewritten at the
end of each sitting; this file is the player's memory between sittings.

## Where I am

- Save: `keeper_demos_latest` (45 flags, banked 2026-11-09 in keeper sitting 4). Act 6 "The Empire"
  of The Demos (banner: "The Demos · Act 6 — The Empire").
- Banks sitting 4: keeper_demos_14 (42, Find Lanternfall claimed), keeper_demos_15 (44, The Record
  Opens claimed), keeper_demos_16 (44, The Serfs' Word claimed), keeper_demos_17 (45, Hold the Lamp
  claimed), latest (45).
- Flags before sitting 4: 41. After: 45.
- Seat kp4 stopped. Press budget used: about 100 of 140 (many waits; the game ran slow).
- Biome slots: BloodLedger (P) was CULLED this sitting to free a slot for Lanternfall. Tabs now
  T TheDemos, Y Village, U StarterForest, I Woodlot, O FreshwaterSpring. Lanternfall is a new biome.

## What I'm doing next

- Two Chores, One Thread (Arc, accepted, Charge 0%): Druid [0] Superpose (Hadamard) on the control
  plot, then Operator [9] Gate (CNOT) on a pair. Operator R Gate asks for a pair: "Shift-click two
  plots (or Shift+G H)". Shift+K marked K as checked but the pair did not visibly form (see Walls).
- Wind Twice (new Arc door, appeared after Hold the Lamp; not read yet).
- Ask the Loop What It Kept, The Long Way Home, Stay Yourself, Hold the Commons, Keep the Forge
  Honest (Arc doors, not yet read in full).
- Trim Icon still needs 13 🐺 (I hold 3). Wolf source still unknown.
- Eagles: 🦅 now 17 after the Chart. Eagle source is gone with BloodLedger culled; Forest 🦅🐇 is
  the only one left. Next eagle run needs a fresh look.

## What I know

- The ▸ banner names the next key, often as a chain "X → Charge [U] → Row [G] → Claim [R]". Follow it.
  The Charge tab's READY badge is the truth.
- Hats (number row): Icon 5, Merchant 6, Captain 7, Ace 8, Operator 9, Druid 0. Re-pressing the
  active hat drops you to Ace. Check `wearing_hat` before a hat key.
- Ace: Q Gather (costs 🧺), E Pause, R Strike, F Explore. On an explored plot F is Fast-Fwd, so a
  plot still tracked by a loop refuses Strike.
- EAGLE FARM THAT WORKED (2026-11-09 sitting 4): on BloodLedger G (🦅🩸) Ace F Explore, Ace R Strike,
  Ace Q Gather gave 🦅 12 → 38 in one cycle. Use a fresh explored plot; the Forest 🦅🐇 H plot
  gave 0 on the same cycle at north ~0.34.
- Stuck-loop unlock (new patch, confirmed): Strike refusal names Icon [5]. Icon R Incorporate when
  ripe, then Icon F stops tracking (toast "tracking stopped"), then Ace F explores, then Strike works.
- Icon: Q Trim Icon (needs 🐺), E Loops, R Track first / Incorporate, F Track toggles. F on an
  untracked plot starts tracking; F again stops it. Incorporate on a ripe plot signs a word.
- Druid: Q Spin −, E Superpose, R Spin +, F Play. North % is live and drifts with the clock.
- Captain: Q Cull Biome (asks F to confirm; any other key cancels), R Chart. Chart Lanternfall costs
  🦅×21 and needs a free biome slot; without one R does nothing and the banner says
  "biome slots full → Cull <biome> [Q] → confirm [F]".
- Operator: Q Break, E Inspect, R Gate (CNOT pair: Gate opens "Shift-click two plots").
- X = story: T Self, Y Arc (open doors, R accepts the selected row), U Charge (READY doors,
  G selects a row then R claims), I Guide, O Story.
- Arc row keys: the key sits above its title, so G is the first row. Accept with R.
- DANGER: an overlay left open lets Y/X open the Arc or Story; ESC closes. Check `screen_text`.
- SPEED: `=` speeds the biome clock. After `=` and a Cull the seat ran FPS 1 for several minutes;
  presses queue and the screen lags. `-` did not fix it. Wait in 10 s chunks before reading.

## Doors done

Earlier sittings: The Demos Sleeps, First Harvest, The Wheel Is Yours, First Breath, New Voices,
The Spiral Breaks, The Village Stirs, Timber Country (5 doors), Spring Country (4 doors),
Two Tables, The Forest Stirs, The Mill Runs, Couple the Countries, Couple the Spring,
The Gear-Bench, Hold Commerce, Still the Pond, The Forest Listens Back, Make It Breathe,
A Character, Five Keys, Master of the Mill, The Druid's Loop, The Eagle's Word, Read the Ledger's
Monolith, The Ledger Imposes One Shape, 14 Words, Stay Many.

Sitting 4 (claimed): Find Lanternfall (Charge claim after Chart Lanternfall), The Record Opens
(Arc accept, Charge claim), The Serfs' Word (Icon loop on StarterForest J, incorporated; Charge
claim), Hold the Lamp (Arc accept, Charge claim).
Accepted, not claimed: Two Chores, One Thread (0%).

## Walls and confusions

- 2026-11-09 (sitting 4, WALL, filed): Two Chores, One Thread. Druid E Superpose on J (Hadamard) then
  Operator R Gate asks for two plots; Shift+K marked K as checked but no CNOT resolved and the row
  stayed 0%. Pairing syntax not clear from the screen. Wall line in C:/tmp/sw_wall_kp4.txt.
- 2026-11-09 (sitting 4): Chart Lanternfall refused silently with 🦅 21 in stock. Only the Captain
  banner said "biome slots full → Cull BloodLedger". The cull cost is not explained on screen.
  I confirmed the cull (BloodLedger gone) to get the chart through; the cull prompt says nothing
  about what is lost.
- 2026-11-09 (sitting 4): the seat FPS dropped to 1 for several minutes after the cull and `=`. The
  look output looked frozen while turns still advanced (forecast showed turn 374 → 527).
- 2026-11-09 (sitting 4): the Cull prompt banner ("press F to confirm") lingered after the cull and
  after overlays closed. Stale.
- 2026-11-09 (sitting 3, banked as WALL): Find Lanternfall needs 🦅×21 from Forest. Resolved this
  sitting by the BloodLedger Strike+Gather (🦅 12 → 38).
- 2026-11-09 (sitting 3): banner read "explore it first → Ace [8] → plot → Explore [F]" for plots
  already explored. Stale; the R label was the truth.
- 2026-11-09 (sitting 3): the Trim Icon wolf (🐺×13) is still unresolved. Still 3 🐺.
- 2026-11-09 (sitting 2, carried): banner oscillation between two hats; F on an untracked plot
  sometimes opened the Memoir overlay (a second F tracked it).
