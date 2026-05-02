# 🍄 Agent Lab — Architecture & Data Flow

*How the LLM agents actually play SpaceWheat.*

---

## 🌐 The Big Picture

```
┌─────────────────────────────────────────────────────────────────┐
│                      🧠 LLM Agent Brain                         │
│          (Claude / Codex / Gemma / whoever's playing)           │
└─────────────────────┬───────────────────────────────────────────┘
                      │ 🎮 decides an action
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                  🎛️ Python Orchestration Layer                   │
│                                                                 │
│  arena.py ──────► milk_hunt_runner.py ──────► rig_client.py    │
│     │                    │                         │            │
│  (race/duel/         (one session,             (writes JSON     │
│  matrix/design)      one agent)               to queue file)   │
└─────────────────────────────────────────────────┬───────────────┘
                                                  │ 📨 queue.jsonl
                                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                  🎮 Godot Game (Headless)                        │
│                                                                 │
│  Tests/rig_listener.gd ──────► QuantumInstrument               │
│          │                            │                         │
│    polls queue.jsonl          executes real game actions        │
│    writes results.jsonl       (explore / measure / pop /        │
│                                quest / inject vocab / etc.)     │
└─────────────────────────────────────────────────────────────────┘
                                                  │ 📬 results.jsonl
                                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                  📊 Analysis & Mutation Layer                    │
│                                                                 │
│  milk_hunt_summary.py ──► tissue_ledger.py ──► fibonacci_       │
│          │                      │              adversary.py     │
│    (score the run)       (track what          (mutate policy    │
│                           worked)             costs for next)   │
│                                │                                │
│                          ppg_priors/ ◄──── policy_graph_        │
│                         (persist the        runtime.py          │
│                          learned weights)    (reads Core/Config/ │
│                                              PolicyGraph/)      │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔄 One Full Loop

```
① 🌱 Seed save state
   milk_hunt_seed_save.py --slot 2 --profile granary_scout
   (loads a world-state profile into a Godot save file)

② 🟢 Start the rig
   🎛️/🟢.sh
   (boots Godot headless, rig_listener.gd starts polling)

③ 🎮 Run one agent session
   🎛️/🥛🏃.sh --seed-slot 2 --runs 1 --max-loops 21
   (milk_hunt_runner.py drives rig_client.py turn by turn)

④ 🥛 Agent tries to find milk
   Each turn:
     agent decides → action JSON written to queue →
     Godot executes → result JSON appended to results →
     rig_client reads result → passes back to agent

⑤ 📊 Score the run
   milk_hunt_summary.py reads results.jsonl
   → did agent find 🍼? how many turns? what resources left?

⑥ 🧬 Mutate policy (tissue learning)
   fibonacci_adversary.py reads the summary
   → adjusts action costs/weights using Fibonacci-constrained values
   → saves updated PPG priors to ppg_priors/

⑦ 🔁 Next run starts with evolved policy
   policy_graph_runtime.py reads Core/Config/PolicyGraph/ + ppg_priors/
   → new session has harder/adapted economy
```

---

## 🎮 Turn Format

Every turn is a JSON dict sent to `queue.jsonl`:

```json
{"turn": 7, "action": "probe_cycle", "params": {"biome": "StarterForest"}}
{"turn": 8, "action": "complete_quest", "params": {"quest_id": 3}}
{"turn": 9, "action": "inject_vocab", "params": {"north": "🌙", "south": "🍄"}}
```

The result comes back in `results.jsonl`:

```json
{"turn": 7, "ok": true, "outcome": "pop", "resource": "🌾", "amount": 42, "p": 0.31}
```

**Supported actions** (non-exhaustive):

| 🎮 Action | What it does |
|---|---|
| `resource_snapshot` | 📸 See current wallet |
| `known_vocab_pairs` | 📖 List discovered emoji pairs |
| `offer_quests` | 📋 Show available quests |
| `accept_offer` | ✅ Lock in a quest |
| `complete_quest` | 🏆 Claim quest reward |
| `probe_cycle` | 🔬 Explore → measure → pop one plot |
| `inject_vocab` | 💉 Inject an icon into a biome |
| `discover_biome` | 🗺️ Unlock a new biome |
| `lindblad_drain` | 🌊 Apply Merchant drain to a plot |
| `time_skip` | ⏩ Fast-forward N phrames |
| `configure_seed_state` | 🌱 Set up starting resources |

---

## 🏟️ Arena Modes

```
arena.py  ──────┬──── 🏁 race   — N runners, 1 profile, Fibonacci loop ladder
                │              (stops when 4/5 find 🍼)
                │
                ├──── 🏆 duel   — 2 lanes (e.g. "sonnet" vs "codex") in parallel
                │              (head-to-head, same profile, N runs each)
                │
                ├──── 📊 matrix — M profiles × N runs each
                │              (broad sweep, tissue learning after each)
                │
                └──── 🧬 design — LLM generates new character phenotype
                               (arena validates, adds to config/characters/)
```

---

## 🧬 Tissue Learning (Fibonacci Adversary)

After every run, `fibonacci_adversary.py` mutates the policy:

```
📊 run result
    │
    ▼
🔢 Fibonacci sequence: [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233]
    │
    ▼
💰 Adjust action costs toward golden-ratio distribution
   (expensive actions stay expensive; rare wins get cheaper)
    │
    ▼
💾 Save to ppg_priors/{character}.json
    │
    ▼
🔁 Next session: policy_graph_runtime.py merges
   Core/Config/PolicyGraph/default.jsonl + ppg_priors/ → active policy
```

**What gets mutated:**
`quest_cycle` 📋 · `probe_cycle` 🔬 · `lindblad_drain` 🌊 · `time_skip` ⏩
`discover_biome` 🗺️ · `victory_lap_partial` 🏅 · `lock_offer` 🔒 · `channel_drain` 💧

---

## 🗂️ Config Files

```
🎛️/config/
├── world_state/          🌍 ~20 starting economies
│   ├── balanced_survival    300👥 300🌾 200🍞 — broad starter
│   ├── probe_heavy          lots of ❄️ — measurement-focused
│   ├── quest_push           quest rewards cranked up
│   ├── injection_biased     pre-loaded for vocab injection
│   └── derby_codex_1..5     🏆 derby lane configs
│
├── characters/           🎭 ~50 agent phenotypes
│   ├── pioneer_fib          🏔️ 2 biomes, must expand
│   ├── granary_scout_fib    🌾 food-chain specialist
│   ├── village_diplomat_fib 🤝 faction contract focus
│   ├── claura_v0_*          🤖 LLM-generated, timestamped
│   └── winner_solar_*       🏆 evolved winners from past derbies
│
└── strategy/             🧠 2 files (default, strict)
```

---

## 🔗 How This Touches the Game

```
🎛️/rig_client.py
    │ reads/writes jsonl files
    ▼
Tests/rig_listener.gd         ← polls every 50ms
    │ calls
    ▼
Core/Instrumentation/QuantumInstrument.gd    ← real game API
    │ calls
    ▼
Core/Actions/ProbeActions.gd                 ← physics
Core/Quests/QuestManager.gd                 ← quests
Core/Biomes/BiomeRegistry.gd                ← biomes
    │
    ▼
Core/Config/PolicyGraph/                     ← policy JSONL consumed by
    │                                           policy_graph_runtime.py
    ▼
Core/AI/PolicyGraph.gd                       ← consumed by QuestManager + Python layer
```

---

## 🛠️ Maintenance

| Task | Command |
|---|---|
| 🎨 Add new emojis to game | Edit `biomes.json` or `factions.json`, then run `python3 🍄/🛠️/sync_emoji_pipeline.py` |
| 🟢 Start the rig | `🍄/🎛️/🟢.sh` |
| ✍️ Send one turn manually | `🍄/🎛️/✍️.sh '{"turn":1,"action":"resource_snapshot"}'` |
| 🥛 Run milk hunt | `🍄/🎛️/🥛🏃.sh --runs 5 --max-loops 21` |
| 🏟️ Run a derby | `python3 🍄/🎛️/arena.py duel --lane sonnet --lane codex --runs 10` |
| 🔬 Native engine check | `🍄/⚙️🔍.sh` |
| 🔨 Rebuild C++ native lib | `🍄/🔨✖.sh` |

---

## 📦 What's Not Here

- `📦_emoji_research/` — Pre-consolidation emoji design work (Feb 2026). Gitignored. The live truth is `🎛️/config/emoji_registry.json`.
- `ws/🍄/🧪/` — Sister sandbox *outside* this repo. Isolated biome physics experiments (village redesigns, eagle fixes). Not referenced here by design.
- `🧪/` — Biome stress tests (buffer invalidation, force graph scaling). Run independently; see `🧪/README_🧬.md`.
