# Fractal atlas — icon to world

## Runtime

| File | Role |
|------|------|
| Core/Instrumentation/FractalAtlas.gd | Address graph, path, export |
| Core/Instrumentation/FractalWorldService.gd | enter / ascend / inject hook / FarmGrid register |
| Core/Environment/ProceduralIconBiome.gd | Closed DynamicBiome materialize from icon seed |

## Rig actions

```json
{"action":"inject_icon","biome":"StarterForest","north":"☀","south":"⚡"}
{"action":"enter_icon","biome":"StarterForest","register_id":0}
{"action":"fractal_atlas"}
{"action":"ascend_fractal"}
```

Drive script: `python3 🍄/🧪/fractal_drive.py`

## Export

- `user://fractal_atlas.json` every enter/ascend/inject
- `BUTLER_VITALS/fractal_atlas.json` when env set

## Butler

- Glass door reads vitals face
- Explorer: `/ui/fractal`
