# Bundled Operator Cache

This directory contains pre-built quantum operators that ship with the game.

## What's Here

- `manifest.json` maps biome names to cache files.
- `{biome}_{cachekey}.json` stores serialized Hamiltonian and Lindblad operators.

## Purpose

Players should load these operators immediately on first boot instead of rebuilding
them from scratch. That keeps startup cost stable as the biome registry grows.

## Build Rule

Refresh this directory through the release gate:

```bash
godot --headless --path . --script tools/BuildBundledCache.gd
```

or via the wrapper:

```bash
bash tools/BuildBundledCache.sh
```

The builder now:

1. validates the exportable biome registry
2. rebuilds operator cache through the current runtime path
3. copies the resolved runtime cache into `BundledCache/`
4. verifies manifest coverage against the exportable biome set

If validation or coverage fails, the build must stop.

## Cache Priority

1. user cache
2. bundled cache
3. rebuild from scratch

## Do Not

- Do not hand-edit cache JSON.
- Do not delete this directory from exports.
- Do not ship a release without rebuilding after biome/icon changes.
