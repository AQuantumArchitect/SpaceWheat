# AGENTS.md

SpaceWheat is built by AI coding agents working under human direction. This
file is the entry point for any agent (Claude, Codex, or a bot in the fleet)
starting work in this repo. Humans: start at [README.md](README.md).

## Read first

| If you are… | Read |
|---|---|
| doing any work at all | [docs/GAME_CODEX.md](docs/GAME_CODEX.md): the canonical mental model of the game, physics and controls |
| building, packaging or releasing | [docs/agents/MEMORY.md](docs/agents/MEMORY.md): operational memory (release path, native DLL, Windows layout) |
| touching the story, quests or acts | [docs/CAMPAIGN.md](docs/CAMPAIGN.md): the campaign spec lives in `Core/Campaign/campaign.json`; never hand-edit the compiled JSON |
| tuning biomes, factions or Lindbladians | [docs/agents/BIOME_AGENTS.md](docs/agents/BIOME_AGENTS.md) |
| touching chatter, or writing state as emoji sentences | [docs/GLYPH_LANGUAGE.md](docs/GLYPH_LANGUAGE.md): biomes as scopes, kets, bras, dark `?` |
| playing the game headlessly (playtest bots) | [🍄/README.txt](🍄/README.txt), then [🍄/🗺️_ARCHITECTURE.md](🍄/🗺️_ARCHITECTURE.md) |
| working on the native C++ simulation | [docs/build/NATIVE_BUILD.md](docs/build/NATIVE_BUILD.md) |

## Ground rules

- **Run the tests before you claim anything.** `SW_SKIP_LONG=1 python3 -m pytest tests/ -q`
  is the floor. "The game is beatable" means a keyboard drive through the rig reached the
  ending, not that the flags look right on paper.
- **The campaign is compiled.** Edit `Core/Campaign/campaign.json`, then run
  `python3 tools/campaign/build.py` and `python3 tools/campaign/validate.py`. CI runs
  `build.py --check`, so a hand edit to `story_flags.json` or `tutorial_arc.json` fails.
- **Windows paths live in one file**, `scripts/lib/windows_desktop_deploy.sh`. A test fails
  if any other script or tool spells a `C:\Games` path.
- **Docs that describe a moment go in [docs/history/](docs/history/)**, dated. Live docs
  describe the code as it is now; when they drift, fix them or move them.
- **Design docs** for work that is planned or partly built are in [docs/design/](docs/design/).
  They are not specs of shipped behaviour.

## Layout

```
Core/        game logic (GDScript): farm, quests, campaign, biomes, factions
UI/          interface
native/      C++ GDExtension: the density-matrix simulation
tools/       Python tooling: campaign compiler/validator, assays, profiling
tests/       pytest suite (drives Godot headless where needed)
🍄/          the playzone: rig, probes and drivers for agents that play the game
scripts/     build, export, release and deploy
docs/        player, physics and developer docs (history/ and design/ inside)
```

## Ready for a human playtest

When you judge the game ready for a release cut and a human playtest, open a
GitHub issue labelled `ready-for-human-playtest` (create the label if the repo
does not have it yet). Wait for Luke's sign-off in that issue before any
release: a version tag and `.\tools\release.ps1` (the itch push) both wait on
that reply.

The issue must include:

- **Commit SHA** of the tree you are handing over.
- **How to run it.** Both shipping builds of that SHA: the Windows build and
  the Web-Slim browser build. CI's `build` job uploads them as the `windows`
  and `web-slim` artifacts (`.\tools\build.ps1 -Preset windows` and
  `-Preset web-slim`; see [RELEASE.md](RELEASE.md)). Those artifacts expire
  after 7 days, so also give the local commands.
- **Evidence.** CI on that SHA, the pytest floor
  (`SW_SKIP_LONG=1 python3 -m pytest tests/ -q`), campaign drives, and
  playthrough reports. Link the runs and the reports.
- **Known issues.** What is still broken, flaky, or untested by a human.

SpaceWheat takes many hours to beat. In the same issue, propose how to split
the human playtest into sessions of 2 to 3 hours. Each session needs a clear
stopping point and a goal. Use act and chapter boundaries in
[docs/CAMPAIGN.md](docs/CAMPAIGN.md) as the seams.
