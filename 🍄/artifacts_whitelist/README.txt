Curated Artifact Whitelist
==========================

Purpose
-------
This folder is the only place under `🍄` where run artifacts should be committed.
Everything else under runtime output paths is ignored in `.gitignore`.

Use
---
1) Copy only small, intentional artifacts here (example traces, baseline JSON, key snapshots).
2) Add a short note in commit message describing why the artifact is worth versioning.
3) Prefer one representative artifact over bulk logs.

Do Not Commit
-------------
- Full run dumps from `🍄/🎛️/🧾/`
- Runtime caches from `🍄/🎛️/.godot*`
- High-volume logs from `🍄/🎛️/logs/` or `🍄/logs/`

