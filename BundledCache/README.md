# Bundled Operator Cache

This directory contains pre-built quantum operators that ship with the game.

## What's Here

- **manifest.json** - Maps biome names to cache files
- **{biome}_{cachekey}.json** - Serialized operators for each biome

## Purpose

Players load these operators instantly on first boot instead of building them from scratch (~100ms saved, scales to seconds as icons become more complex).

## How It Works

**Cache Priority:**
1. User cache (runtime modifications, mods)
2. **Bundled cache (this directory)** ← Ships with game
3. Build from scratch (fallback)

## Updating

Rebuild this cache before exporting:

```bash
bash tools/BuildBundledCache.sh
```

Then commit:

```bash
git add BundledCache/
git commit -m "Update bundled operator cache"
```

## Do NOT

- ❌ Manually edit cache files
- ❌ Delete this directory from exports
- ❌ Commit without rebuilding when icons change

## Learn More

See `llm_outbox/HYBRID_CACHE_SYSTEM_COMPLETE.md` for full documentation.
