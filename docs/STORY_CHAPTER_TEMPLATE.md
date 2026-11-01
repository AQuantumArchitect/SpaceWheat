# The Country Chapter Template

Every faction's story is one repeatable "country chapter": five beats that take the
player from *a door glows on the compass* to *the country's market is alive and its
deep word is yours*. Chapter 1 (Millwrights / Woodlot: `woodlot_door` →
`woodlot_contact` → `lumber_flows` → `woodlot_wakes` → `timber_rhythm`) is the
reference implementation in `Core/Quests/data/story_flags.json`. This document is
everything an implementer of chapter 2+ needs.

## The loop the chapter teaches (owner-ruled, 2026-07)

- **Contracts pay resources + standing. Story teachings are the ONLY teachers of
  faction vocabulary.** A contract never carries a `reward_north/south`.
- A faction's teaching costs **2-3 completed contracts** (access +0.02 each;
  see width math below).
- **Market law:** a faction's market opens in a biome when its icon pair is present
  there (`FactionBiomeMap.gd`). So *teach word → plant word → board opens* is the
  chapter's mechanical spine, and the planting beat should say so in its hint.
- Duplicate emojis are legal — vocabulary can spread across biomes.

## The five beats

Naming: `<country>_door / <country>_contact / <existing-teach-id> / <country>_wakes /
<deepening-id>`. NEVER delete or rename an existing flag id (banked saves hold fired
ids) — the teaching beat REUSES the act's existing flag id (chapter 1 kept
`lumber_flows`).

| # | Role | Fires on | Grants | Arc quest |
|---|------|----------|--------|-----------|
| 1 | **Door glows** | prev chapter's teach flag only (instant) | attention +0.02, **access +0.02** ("they open their board") | state_preds `[biome_evolving(country)]`; hint = the FULL compass ritual (Captain hat 7, F reads compass, R discovers, 21🦅 and where to harvest them) |
| 2 | **First contact** | door + `biome_evolving(country)` + `standing_gte(access, 0.02, width 0.008)` ≈ 2nd payment | trust +0.03, attention +0.05 | state_preds `[standing_gte(access, 0.05, width 0.01)]` — the progress bar; hint MUST carry the commitment-legibility line: "their board counts only what you gather AFTER you accept" |
| 3 | **The teaching** (existing flag id) | contact + `standing_gte(access, 0.05, width 0.01)` ≈ 3rd payment. NO in-country berries or observables — must be reachable BEFORE planting anything there | trust +0.08 | ARC claim pattern (`village_stirs` shape: `"type": 1, "category": "ARC"`); `reward_north/south` = THE pair; state_preds live in already-open land (e.g. `berry_consumed(Village, 4)`). The claim is the teaching; contracts never teach |
| 4 | **The planting / wakening** (`<country>_wakes`) | teaching + `atom_in_biome(country, north)` | trust +0.08, legitimacy +0.05 | `"type": "DELIVER"`, state_preds `[atom_in_biome(Village, north)]` — couple the island economy; NO reward pair |
| 5 | **The deepening** | wakes + berries/attractors IN the now-awake country (berry counts only ever appear post-wakening) | legitimacy + faction flavor | the invariant/physics lesson, or the next chapter's pre-seed (chapter 1 teaches ⚙/🏭 here). Existing "What Survives" beats slot here when the act has one |

Stagger chapters: each door gates on the PREVIOUS chapter's teaching flag, so the
discovery compass pressures ONE biome at a time (two open doors split the pressure).

## Each faction varies exactly ONE element

- **Millwrights** (chapter 1) — planting lives in TWO registers: Woodlot wakes AND
  Village couples. The faction of transmission.
- **Hearth Keepers** (chapter 2) — gate channel is **trust**, not access (they banked
  ~0.30 trust from act 1; gates 0.35 → 0.42, width 0.02 ≈ 2-3 deliveries).
- **Lamplighters** (chapter 3) — first contact by WITNESS (holding 🌉), not contracts:
  their market opens nowhere early. `chain_ends` keeps its berry (Lanternfall evolves
  natively; the order is honest).
- **Village hub** (act 4) — the door opens inward: the naming beat.

## Pacing math (read before choosing any number)

- `QuestMath.soft_gate(x, center, width)` is 0.5 AT center and crosses the fire
  threshold 0.85 at `center + width·atanh(0.7) ≈ center + 0.867·width`.
- Flags combine predicates by **geometric mean** (`smooth_and`) against
  `FLAG_FIRE_THRESHOLD = 0.85` — with N-1 predicates saturated at 1.0, the last one
  only needs `0.85^N`. Standing gates therefore fire slightly EARLIER inside a
  multi-predicate flag than alone. Chapter 1 measured: contact at the 1st delivery
  after the door grant, teaching at the 2nd-3rd. That is the owner's budget.
- **`standing_gte` MUST carry an explicit `"width"`** (Phase-1 enabler, fccb76d9).
  Without it the default 0.05 width silently prices a gate ~2 deliveries late. The
  lint (`tests/test_story_flags_lint.py`) enforces this.
- Delivery-contract success grants trust +0.05 / access +0.02 / attention +0.01
  (`QuestRewards.gd`). Story beats may grant ANY channel including access (StoryEngine
  applies all six on fire) — door beats grant access ≤ 0.02, never more. The economy
  stays raw: fix access, never prices.
- Integer counts (`berry_consumed_count_gte` etc.) use `count_gate` — they fire AT
  the authored N. Write the N you mean.
- Discovery costs 21🦅; the compass gives +6.0 pressure to any biome named in a
  next-reachable flag's predicates (`BiomeDiscoveryForecastService.gd`) — beats 1-2
  naming the country in `biome_evolving` IS the pointer, no code needed.

## Authoring the JSON

Mirror the existing shapes exactly (see chapter 1 in `story_flags.json`):

- Flag fields: `id`, `display_name`, `act`, `arc_beat`, `predicates` (array),
  `standing_grants`, `arc_quest` (or `null`).
- Claim-pattern teaching quest: `"type": 1, "category": "ARC"`, `body`, `hint`,
  `faction`, `state_predicates`, `reward_north/south` + `reward_icon_north/south`
  (both spellings, same values).
- DELIVER quest: `"type": "DELIVER"`, same fields, NO rewards.
- Beat-with-guidance (no claim): just `body`/`hint`/`faction`/`state_predicates`
  (the `new_voices` shape).
- Edit via python with `ensure_ascii=False`, `indent=2` — the file round-trips
  byte-stable.
- VERIFY the taught pair exists in `Core/Factions/data/icons.json` AND belongs to the
  faction (`factions.json` → its `icons` list) before authoring it as a reward.
  Orientation: match the faction's `pole_0/pole_1` unless an existing flag already
  established the reversed order (lumber is 🪵/🪓 by precedent).
- **Signature law (hard-won, chapter 1):** `Farm.discover_icon` refuses a pair whose
  NORTH pole already exists anywhere in the signature ("north must be new; south may
  repeat"). The claim still "succeeds" — standing grants, quest completes — but the
  word is silently refused. Choose the reward's NORTH to be an emoji the player
  CANNOT have organically incorporated before the teach (not native to any biome
  they have walked). Chapter 1 teaches the factory axis as 🏭/⚙, not ⚙/🏭, because
  ⚙ lives natively in Village and gets incorporated in act 1. A player who already
  holds the pole can usually still plant the needed atom through their organic
  pair — but never DESIGN for the refusal.

## The prose register

The `arc_beat` is the poem; the `hint` is the manual.

- **arc_beat**: 1-2 sentences, physics-as-myth, second person, concrete. The
  Hamiltonian IS the story — say "the two rhythms keep separate time", not "the
  villagers miss the woodcutters". No purple filler.
- **hint**: real keys and verbs, in execution order, with costs. "Captain hat (7):
  F reads the compass... R discovers (costs 21🦅)". If the player will wonder *where
  the currency comes from*, say where. One teaching sentence about the system's law
  is welcome at the end ("when a faction's word lives in a land, their board opens
  there").

## Checklist before calling a chapter done

1. `python3 -m pytest tests/test_story_flags_lint.py -q` green — and REMOVE the
   chapter's flags from the lint's TODO allowlists (the lint ratchets).
2. `🍄/🧪/act3_5_drive.py` passes end-to-end IN THE SAME CHANGE as any re-predication
   (rerun once on failure — #252 discovery-lottery flake).
3. A focused rig session: `fire_flag` the door's prerequisite, watch the door fire,
   its arc quest appear (`story_flags` / `flag_progress` / `overlay_text`), and the
   standing gloss show live have/target.
4. Never gate the chapter on open-system predicates (`biome_eigenvalue_gap_gte`,
   `biome_purity_trending`) — closed campaign uses `biome_spectral_gap_*`.
5. Re-verify any numeric observable gate by probe before pinning (physics retunes
   move them; see afb72957).
