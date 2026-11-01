# The campaign reorder — 2026-08-17

Owner's ask: *"plan out a better ordering so the player experience isn't so
jarring with trying to learn incorporation as the first action... it needs
story and a gentler on-ramp."* Plus four rulings on plan review: the ×4 is
incorporation's reward (early game lives on contracts — otherwise change no
mechanics); faction reputation may raise market rewards (the one sanctioned
new mechanic); objectives need an easy-access portal in the main play space;
and factions should drive a narrative overlay of the physics story — *"add
many story beats and feel free to rearrange, just don't drop any concepts."*

## The diagnosis (playtest-backed)

Tutorial step 1 (`vocabulary`) demanded the Berry-phase ritual — untaught
biome travel + a hat switch + a toggle-trap F + **two ~90 s real-time waits**
— as the second thing in the game. Both 2026-08-10 personas walled exactly
there, and all of Act 1 was a berry staircase. Meanwhile the late campaign
interleaved four storylines on one act counter with the ending in act 6
(`docs/CAMPAIGN_SPLIT_2026-08-11.md` has the full anatomy).

## The new learning ladder

**Teach enough physics to play, then raise the bar per act.**

- **Act 0** (`tutorial_arc.json`, 6 steps): instant verbs only —
  `core_loop → reap_season → contracts → wayfinding → superposition →
  entanglement`. The crossing is its own taught beat (new `active_biome_is`
  arrival predicate); the contract ceremony arrives while the granary still
  covers it; the superposition step's handoff fires `loom_opens` (Operator
  hat). No berry ritual anywhere in Act 0 (`tests/test_tutorial_arc_lint.py`
  pins this).
- **Acts 1–2 — teachings-first:** kept contracts raise standing; standing
  fires the teaching beats (`village_stirs` 💨/🔨, `lumber_flows` 🪵/🪓,
  `timber_rhythm` 🏭/⚙, `spring_connects` 💧/🌊 — one access ladder for the
  Millwrights, one trust ladder for the Hearth); taught words plant. New
  beats: `first_harvest` (act-0 spine voice), `arc_handover` ("the wheel is
  yours" — the banner→Arc transition the playtest asked for), `two_tables`
  (Hearth/Millwright tension made legible).
- **Act 3 — "What the Land Remembers":** the entire berry chapter relocated
  (`first_breath` re-predicated onto berries + the forest staircase +
  `spiral_breaks`, the ×4 pitch). Incorporation is the mid-game power spike:
  **taught words plant; incorporated words pay.**
- **Acts 4–8:** gating untouched; chapters re-cut (`StoryAtlas.chapter_for_act`)
  so the ending act and the epilogue lanes stop sharing one label.

## Economy truth (owner rulings 1–2)

- `ProbeActions._icon_incorporated` now reads `farm.incorporated_icons` — the
  ledger only the ripening ritual writes. The code had drifted to
  `known_icons`, which would have paid the ×4 for merely-taught words.
- Reputation pays: market rewards scale `× (1 + min(cap, trust × k))`
  (`quest_rewards.standing_reward_bonus_per_trust` 0.6 / `_cap` 0.5 in
  `default.jsonl`), applied inside the deterministic pre-roll, stamped on the
  offer, rendered as `⭐+N%` on the board row.

## Surfacing (owner ruling 3)

`ActFilament` grew into the **objective portal**: act line + the one live
objective + a "Next:" line naming the nearest reachable unfired beat
(`UIProgression.next_objective_title`), tap → straight onto the Arc tab
(`OverlayManager.open_controls_on_arc`). `WelcomeOverlay` now leads with the
fiction and the three keys of the first minute.

## Split status (phase 0 landed)

Every beat carries `campaign: demos|lanternfall|loom` (40/15/12, the split
doc's exact leaves) and the three capstones carry `ending: true` — inert
metadata until phase 1. `tests/test_campaign_partition.py` pins the
partition, the endings, that unlock tables key only on Demos beats, and the
**six** cross-campaign doors as a ratchet allowlist (the doc predicted four;
`lantern_door ← mill_wakes` and `braid_order ← village_identity` are the
other two).

## What remains (dev machine — rig + checkpoint bank required)

1. **Calibration pass (the honest cost):** the new standing ladders
   (village_stirs 0.02/0.06, lumber_flows 0.10, timber_rhythm 0.13/0.17,
   spring_connects 0.50) are authored to the +0.02-access/+0.05-trust
   arithmetic, not yet rig-measured; Act 0–2 must prove net-positive without
   the early ×4 (boot wallet 55👥/34🍞/21🌾 says yes; measure anyway).
2. **Re-mint checkpoints** (`🍄/🧪/mint_checkpoint.py` — already rewritten
   for the new road; act1 = tutorial + Millwright deliveries, berries are an
   act3 checkpoint's business).
3. **Run the stranger probes + headed smoke** (`tutorial_stranger_probe.py`,
   `stranger_arc_ui_probe.py` — both updated to the six-step chain).
4. **Split phases 1–4** per `docs/CAMPAIGN_SPLIT_2026-08-11.md`: guard test
   over the checkpoint bank FIRST, then campaign-directory resolution +
   unlocks-on-beats + `ending: true` wiring, Lanternfall out (with the two
   world mutators), measure `atom_diversity` before trimming the pool, the
   Loom last. The relocated berry chapter already fills the act-3 hole the
   doc worried about.

## Files touched (this pass)

Data: `Core/Quests/data/tutorial_arc.json` (rebuilt),
`Core/Quests/data/story_flags.json` (5 new beats, 6 re-predicated, 5 beats
→ act 3, campaign/ending tags), `Core/Config/FarmVariableGraph/default.jsonl`.
Code: `Core/Quests/QuestStateProjectionService.gd` (`active_biome_is`),
`Core/Quests/PredicateGloss.gd`, `Core/Quests/QuestManager.gd` (tutorial
re-sync on restore), `Core/Quests/QuestRewards.gd` + `QuestPipeline.gd`
(reputation pay), `Core/Actions/ProbeActions.gd` (×4 ledger),
`Core/Story/StoryAtlas.gd` (chapters), `Core/Story/StorySeedLoader.gd`,
`UI/Core/UIProgression.gd` (tables, any-of unlocks, next-objective),
`UI/Widgets/ActFilament.gd` (portal), `UI/Managers/OverlayManager.gd`,
`UI/Overlays/QuestBoard.gd` (⭐), `UI/Overlays/WelcomeOverlay.gd`,
`UI/Overlays/ControlsOverlay.gd`, `UI/PlayerShell.gd`.
Tests/probes: `test_tutorial_arc_lint.py` + `test_campaign_partition.py`
(new), `test_tutorial_objective_travel.py`, `test_headed_player_input_surface.py`,
both stranger probes, `mint_checkpoint.py`.
Docs: `HOW_TO_PLAY.md`, `GAME_CODEX.md` §7.2, the incorporation glossary.
