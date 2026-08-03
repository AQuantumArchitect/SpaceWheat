# Fractal atlas — icon to world

## Runtime

| File | Role |
|------|------|
| Core/Instrumentation/FractalAtlas.gd | Address graph, path, export |
| Core/Instrumentation/FractalWorldService.gd | enter / ascend / inject hook / FarmGrid register |
| Core/Environment/ProceduralIconBiome.gd | Closed DynamicBiome materialize from icon seed |
| Core/Visualization/QuantumField3D.gd | Render + input: an indigo descend satellite per register, a cyan ascend portal when the active biome is a fractal child — the real depth mechanic, distinct from the flat sibling-biome portal rail |

## Rig actions

```json
{"action":"inject_icon","biome":"StarterForest","north":"☀","south":"⚡"}
{"action":"enter_icon","biome":"StarterForest","register_id":0}
{"action":"fractal_atlas"}
{"action":"ascend_fractal"}
```

Drive script: `python3 🍄/🧪/fractal_drive.py`

Automated regression coverage: `godot --headless -s tests/test_fractal_atlas_injection.gd`
(real control-flow test — boots a farm, exercises the inject → enter → ascend chain, and
force-fails an injection to prove a failed inject registers no fractal child).

## Export

- `user://fractal_atlas.json` every enter/ascend/inject
- `BUTLER_VITALS/fractal_atlas.json` when env set

## Butler — not yet real

The export above is written, but as of 2026-08-02 nothing consumes it: a repo-wide search
(SpaceWheat plus every other reachable swarm working directory) found no "Butler glass door"
reading `fractal_atlas.json`, and no `/ui/fractal` route, page, or handler anywhere. This is
aspiration, not shipped behavior — building that consumer is a separate, Butler-side task.

The real visual home for this system is the shipped 3D renderer: `QuantumField3D.gd` now
draws descend/ascend portals directly (P2 of `refactored-juggling-acorn.md`, 2026-08-02) —
depth-cap enforcement stays server-side in `FractalWorldService`, the renderer just no-ops a
click past the cap for now (a friendlier dead-end message is P4/playable-first-arc scope).
