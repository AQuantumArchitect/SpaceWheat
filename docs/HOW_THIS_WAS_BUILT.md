# How SpaceWheat was built

I didn't write any of SpaceWheat's code. Every line of GDScript, C++ and Python
here was written by AI agents. My part was deciding what the game should be,
directing the agents, reading what they produced, playing the result and
deciding what happened next. Learning to work that way was the reason for the
project, and the game is what came out of it.

This page covers how that went: the stages the work passed through, the fleet
of agents it ended with, the guardrails that turned out to matter, and the
places where it went wrong.

| | |
|---|---|
| History | 1,250+ commits since December 2025 |
| Agent-written | over 85% of non-merge commits carry a model co-author line; the rest predate the habit or came from tools that didn't add one |
| Code | ~126k lines GDScript, ~45k Python (tools, tests and the agent rig), ~6.5k C++ |
| Tests | about 80 pytest files plus headless Godot smoke batteries; CI runs about 570 tests |

Regenerate these with `python3 tools/repo_stats.py`.

## The stages

The models changed as the work went on, and so did what I asked of them. The
co-author lines in the git log make the progression easy to see.

**One assistant, many prompts (Dec 2025 – Jan 2026; Haiku 4.5, Sonnet 4.5,
Opus 4.5).** I described the idea, a farm where every plot is a qubit, and
asked for pieces one at a time. The result was a working density-matrix
simulator in GDScript, the first biomes, and a lot of UI that fought itself.
In January an agent moved evolution into a native C++ extension on Eigen
(`1f6bb43`, "70–100x"). Most commits from this period are small and reactive.

**Giving agents a way to play (Feb – Mar 2026; Sonnet 4.5 and 4.6, Opus 4.5 and 4.6).** An
agent that can't run the game can only guess whether its change works. The
answer was the rig in [`🍄/`](../🍄/README.txt): a headless listener that
accepts the same keypresses a human makes and returns the same screen and
physics state a human sees. It runs the real game, not a mock. From then on an
agent could check its own change by playing it. By spring, OpenAI's Codex was
running scripted campaign playtests through the same rig.

**Long context and real content (Apr – Jun 2026; Sonnet 4.6, then Opus 4.7 and
4.8 with 1M context).** With a whole subsystem in context at once, agents could take on
cross-cutting work: 102 factions and their icon vocabularies, the quest system
rebuild ([plan](design/QUEST_SYSTEM_PLAN.md)), and a story driven by physics
thresholds instead of scripts.

**A fleet (Jul 2026; Fable 5 builders, Haiku playtesters).** July has the most
commits of any month, 269. Three things made that possible:

- A shared mental model. [`GAME_CODEX.md`](GAME_CODEX.md) became the one
  document every agent reads first, with each claim pointing at the file that
  backs it. [`FOR_PHYSICISTS.md`](FOR_PHYSICISTS.md) grades every physics
  claim the game makes as exact, faithful or suggestive.
- Player-parity seats. Small, cheap models played the game through the same
  keys and screen text a person gets, and reported where they got stuck. By
  mid-July even small local models (Qwen through Ollama,
  [`ollama_seat.py`](../🍄/🧪/hive/ollama_seat.py)) had a seat, as a cheap
  baseline.
- A written protocol for the fleet,
  [`HIVE_PROTOCOL.md`](../🍄/🧪/hive/HIVE_PROTOCOL.md), which I ratified on
  July 14. It's described below.

**Personas and other vendors (Aug – Oct 2026; Opus 5, Sonnet 5, Fable 5,
Opus 5.5).** Playtesters became [personas](../🍄/🧪/hive/PERSONAS.md): a
literalist, an earnest newcomer, a "lost lamb" with no short-term memory, a
key-masher, and a mouse-only player. In September the sensor waves moved to
Grok. Large decisions went to multi-agent studies; for example, twelve agents worked
on [whether to split the campaign](history/2026-08-11_CAMPAIGN_SPLIT.md). In
October the whole story was moved into one compiled, validated spec
([CAMPAIGN.md](CAMPAIGN.md)).

## The fleet

| Role | Who | What their word is worth |
|---|---|---|
| **Sensor** | Cheap playtester models in player-parity seats | They report only and never fix anything. A tester who can edit the game will patch away the problem it was sent to find. |
| **Builder** | Strong implementation models | They write code and data. CI checks their work; nobody takes it on trust. |
| **Referee** | Test suites, campaign validator, save manifests, scripted drives | This is ground truth. |
| **Coordinator** | The supervising model | Its verdicts are claims. They are weighed against what the referee later finds. |
| **Owner** | Me | I set direction, rule on design questions and play the result. |

The protocol's laws are short:

1. **The sensor never holds the hammer.** Testers report and never repair.
2. **A precise early surrender is a success.** After about ten presses with no
   progress, the tester stops and files a report in the form *tried / saw /
   expected*. Forcing a way through is the failure.
3. **Walls fix paths, not testers.** A wall report becomes a design fix: the
   door glows, the refusal explains itself, the ritual gets taught. The answer
   is never a better tester.
4. **Builders are audited at the level of abstraction.** Physics is left alone
   unless sanctioned, numbers are measured rather than slashed, and no content
   is invented to make a progress bar pass.
5. **The coordinator is under the protocol too.**
6. **Claims are never writes.** Every report goes in as an observation, and
   each reporter earns the trust it gets.

## Guardrails that held

- **Tests decide whether something is done.** "Done" means the suite passes.
  CI runs it against the real game, headless, on every pull request and every
  push to main; only the long campaign drives are left to the fleet. Many tests
  pin a design decision in words, so an agent that undoes one gets told why
  it existed.
- **One authority per fact.** The campaign has one source, a compiled JSON
  spec, and CI fails if the generated files drift from it. All Windows
  paths in scripts and tools live in one file. Each physics value is computed in one place. Every
  time a fact had two homes, the copies diverged and an agent believed the
  wrong one.
- **Dated records over living status pages.** Session logs go into
  [`docs/history/`](history/README.md) with a date and are not updated
  afterwards. A status page an agent keeps editing slowly turns into fiction.
- **No silent fallbacks.** For months a pure-GDScript physics path stood in
  quietly whenever the native library failed to load, so broken builds kept
  running at seconds per frame and nobody noticed. On July 6 it was deleted
  ([night purge](history/2026-07-06_NIGHT_PURGE.md)). Since then the game
  refuses to boot without the native engine.
- **The physics is graded in public.**
  [`FOR_PHYSICISTS.md`](FOR_PHYSICISTS.md) labels each concept the game
  teaches as exact, faithful or suggestive, and says how to check it.

## What went wrong

**"The bots beat the game."** Agents reported reaching the late campaign.
In October I still couldn't get far past Act 1 myself. The reports were true
of the harness and false of the game:

- The rig lanes default to `RIG_UNLOCK_ALL=1`, which hides the hat and menu
  gating a real player hits.
- Drives granted themselves the currencies they needed
  (`add_resource` in [`act2_drive.py`](../🍄/🧪/act2_drive.py), for one)
  instead of earning them.

Every layer said yes, and none of them was a person with a keyboard. The
fixes:

- The campaign became one spec with a validator that replays every route
  against a model of where each resource actually comes from.
- Fixtures build a beat's real state from the spec alone, so tests can start
  mid-campaign without lying.
- A new drive, [`honest_opening.py`](../🍄/🧪/honest_opening.py), boots fresh
  with unlocks off, injects nothing, and uses keys only. Its best run so far
  reached the opening of Act 3 (of acts 0–6), skipping optional Act 2 beats.
  That is the claim I make, and the drive is how the next claim gets made.
- The next claim came from the guidance, not the game. A follower that
  presses only the keys the banner names moved the story from 2 of 40
  beats: the game was playable, but its hints, written by hand in many
  places, could not be followed. Replacing them with one resolver computed
  from the spec ([design](design/GUIDANCE_FROM_THE_SPEC.md)) took that to
  38 of 40, and the follower now reaches the ending of The Demos from a
  fresh game in most runs. Every wall it hit became a rule, not a string.

**Slop builds up.** Agents add more readily than they remove.

- A six-agent [duplication sweep](history/2026-07-29_SLOP_PATROL.md) found
  four live bugs that turned out to be copy-paste drift.
- A [doc audit](history/2026-07-11_DOC_ROT.md) went through about 90 docs.
- The Windows machine ended up with three folders holding the same build,
  plus 2.6 GB of hand-copied release archives. Each was created by a
  different session with a different idea of where builds go.

Cleanup has to be scheduled work. It doesn't happen by accident.

**Stale numbers.** Before this pass, the README described a physics fallback
deleted three months earlier and called the open-system campaign "DLC".
The launch script it told you to run had been broken since an agent moved
it into `scripts/` without fixing its paths. Agents write
confident prose about the state of the code at the moment they write it, and
that prose doesn't update itself. Counting from the tree
(`tools/repo_stats.py`) is the fix.

## What I'd tell someone starting

- **Build the playing harness early.** An agent that can play its change is
  worth several that can only read the code.
- **Give each fact one home and make CI enforce it.** Agents duplicate state
  freely, and the copies diverge.
- **Separate who reports from who fixes.** Testers with write access will
  fix the test.
- **Trust a referee, not a summary.** That applies to the coordinator, to a
  builder's "done", and to my own impressions.
- **Play it yourself.** Every important correction in this project started
  with me trying to play and getting stuck.

## Where to look

| To see | Read |
|---|---|
| How agents play the game | [`🍄/README.txt`](../🍄/README.txt), [`🍄/🗺️_ARCHITECTURE.md`](../🍄/🗺️_ARCHITECTURE.md) |
| The fleet's constitution | [`🍄/🧪/hive/HIVE_PROTOCOL.md`](../🍄/🧪/hive/HIVE_PROTOCOL.md) |
| Session records, oldest first | [`docs/history/`](history/README.md) |
| What an agent reads before working here | [`AGENTS.md`](../AGENTS.md) |
| The performance log, wrong turns included | [`docs/performance/`](performance/) |
