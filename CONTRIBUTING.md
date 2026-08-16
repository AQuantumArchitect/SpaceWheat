# Contributing to SpaceWheat

SpaceWheat is a Godot 4.5 game where the physics is real (a density-matrix
quantum simulation drives every biome). Contributions that touch gameplay,
UI, or the native extension should hold that bar: no faked numbers, no
decorative "quantum" flavor text standing in for an actual computation.

## Before you start

- Read [`docs/GAME_CODEX.md`](docs/GAME_CODEX.md) — the canonical source of
  truth for the mental model, physics, controls, and campaign structure.
- Read [`README.md`](README.md) for the tech stack and project layout.
- For anything touching biome/faction physics data, read
  [`BIOME_AGENTS.md`](BIOME_AGENTS.md).

## Building

Requires Godot 4.5. See [`BUILDING.md`](BUILDING.md) for full instructions,
including the native C++ extension (`cd native && scons`).

```bash
./scripts/launch_game.sh         # play (Linux, headed)
./scripts/editor_launch.sh       # open in the Godot editor
```

## Testing

This project has a real test suite and PRs are expected to pass it:

```bash
bash 🍄/🧪/🔬.sh                 # 142 quantum-physics gate tests
python3 -m pytest tests/ -q      # Python suite (source contracts + rig-driven)
```

Boot-error gate (must print `0`):

```bash
godot --headless --audio-driver Dummy --path . --quit 2>&1 \
  | grep -cE "SCRIPT ERROR|Parse Error|ERROR: Failed to"
```

If you're touching UI or input handling, also run
`tests/test_headed_player_input_surface.py` — it pins a long history of real
mouse/keyboard-parity regressions (see `docs/MOUSE_PARITY_AUDIT.md`).

## Project layout

```
Core/     Engine + game logic — quantum substrate, biomes, quests, story
UI/       Input handling, overlays, HUD — thin key-in / projection-out surfaces
native/   C++ GDExtension (libquantummatrix) — the Eigen-accelerated backend
tests/    Physics verification suites + integration tests
docs/     Documentation, start at GAME_CODEX.md
🍄/       Headless automation lane — keyboard rig, probes, batch tooling
```

## A note on how this project is built

A meaningful share of this codebase — including the `🍄/` automation lane and
much of the release/test tooling — was built through direct collaboration
with AI coding agents driving the real game headlessly (see `🍄/README.txt`
and `BIOME_AGENTS.md`). That's disclosed here deliberately, not hidden: if
you're contributing via an agent yourself, the same rig and docs work for
you. Whatever wrote the code, the tests above are the actual bar it has to
clear.

## Pull requests

- Keep PRs scoped to one change; don't bundle unrelated cleanup.
- Run the relevant test suite(s) above before opening the PR and mention the
  results in the description.
- If you're fixing a bug that already has a doc trail (many do — check
  `docs/`), reference it instead of re-diagnosing from scratch.
