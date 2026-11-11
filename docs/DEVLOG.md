# SpaceWheat devlog

Short dated entries, newest first, written each time an agent session stops.
Read by Game Butler (release manager) and Luke. Detailed per-wave evidence lives
in the hive ledger, `🍄/🧪/hive/notes/overnight-2026-11-09.md`.

Target: polished, fun and itch-ready around **2026-11-22**, then a human
playtest. No release tag and no itch push until Luke signs off in the
`ready-for-human-playtest` issue (see AGENTS.md, "Ready for a human playtest").

---

## 2026-11-11 — hive session (branch `overnight/2026-11-09-hive`, PR #63)

**Where it stands**
- PR #63 (about 45 fixes from two nights of headless playtesting plus today's
  owner calls) is merged up to date with `main` (#64–#66) at 23fcfd71. It is
  still open and unmerged: Luke merges it.
- The pytest floor on the merged tree is 733 passed, plus the same 6
  Windows-host failures (path separators and POSIX-only deploy scripts; CI is
  green on main). The tutorial drive (`banner_follow fresh --until first_harvest`)
  takes 55 presses, with 0 off-surface lines, stale toasts or verb mismatches.
- **The main ending (`island_free`) is reached from a new game by a strict
  banner-only follower** (no model; it presses the first key the banner names),
  in about 600 presses. Today a follower also reached the What Fades post-game
  ending (`the_door_stays_open`).
- Beats that no bot has fired yet: The Long Braid, The Braid Alphabet and The
  Fusion (Loom post-game), plus two of the three alternative Village paths
  (one is chosen per run, by design).

**Today's fixes (owner calls on the night-2 list)**
- Fill the Urn: Druid Superpose is the lever. The Guide uses it and the hint
  names it, and a strict follower now clears the quest.
- Charge rows show where each end condition stands (Stay Yourself's Tr(ρ²) and
  the open-ended beats).
- Two Chores: the gate order survives a save, and the walk locks the Forest
  clock first.
- New Guide walks: compass turns, the loop-card read, and bridge braid and fuse.
- Cull is the player's choice. Ace F is gather-first on a struck plot. 🪔 has a
  resources entry. Literalist text fixes.

**Loom post-game (afternoon)**: driven from the furthest bot save with the
strict follower. Every beat in the story has now been claimed by a bot (only
the Village paths not chosen are left). Fixed on the way (58f3e9d6):
- The Fusion could never fire: count objectives used a centred soft gate,
  so "fuse ≥ 1" scored 0.5 after the only fusion a bridge allows.
- Gate words lost their place after a load (Two Chores, The Long Braid).
- The pair gate could name Gate with one mark, and the old banner line named
  Claim on a beat that wasn't ready (two banner loops).
- `purity_at_most` (The Chain, Tested) had no walk, so the banner went silent.

**Next**
- Run a from-zero end-to-end playthrough to time the main ending.
- Open the `ready-for-human-playtest` issue once a fresh-start build passes CI
  and the time-to-beat numbers exist.

**Questions for Luke**
- PR #63 is large. I can't merge it, so the hand-over SHA for the playtest issue
  will be its head unless you merge it first. Should playtest builds come from
  the PR branch, or do you want to merge #63 first?
- Two Chores' 1-bit mutual-information bar: still unverified with the clock
  locked. Keep 1 bit, or lower it for the Forest?
- 🪔's Village rescue (🍞10 → 3🪔) copies its peers' price. Change it if you like.
- The Chain, Tested asks for Tr(ρ²) ≤ 0.9 where you stand. Lanternfall reports itself
  as open country but its purity read stays at 1.0 even after a Superpose, so the
  new walk waits there. Is Lanternfall meant to be wet by then, or should the walk
  send the player to another open biome (Gilded Rot grayed for Watch It Fade)?
