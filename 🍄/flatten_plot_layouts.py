#!/usr/bin/env python3
"""Rewrite every non-empty biome `plot_layout` to a horizontal line in the
upper-middle of the viewport.

Plot positions in Core/Biomes/data/biomes.json are normalized [0..1] of the
full viewport (read by UI/PlotGridDisplay._get_biome_plot_layout_positions).
With the new chrome — top menu row at the top, three rows (hats, biomes, QERF)
at the bottom — the playable middle band is roughly y∈[0.20, 0.60]. We center
the plot row in the upper half of that band at y=Y_LINE, evenly spaced across
[X_MARGIN, 1-X_MARGIN].

Empty plot_layouts (faction-only entries with no biome tiles) are left alone.

Usage:
    python3 🍄/flatten_plot_layouts.py            # apply
    python3 🍄/flatten_plot_layouts.py --dry-run  # preview only
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
BIOMES_JSON = REPO_ROOT / "Core" / "Biomes" / "data" / "biomes.json"

Y_LINE = 0.30        # vertical position — upper-middle gap
X_MARGIN = 0.15      # leftmost/rightmost plot stays this far from edge


def even_line(n: int) -> list[dict]:
    if n <= 0:
        return []
    if n == 1:
        return [{"x": 0.5, "y": Y_LINE}]
    span = 1.0 - 2.0 * X_MARGIN
    step = span / (n - 1)
    return [{"x": round(X_MARGIN + i * step, 4), "y": Y_LINE} for i in range(n)]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="print changes without writing")
    args = ap.parse_args()

    raw = BIOMES_JSON.read_text()
    data = json.loads(raw)

    biomes = data["biomes"] if isinstance(data, dict) and "biomes" in data else data
    if isinstance(biomes, dict):
        items = biomes.items()
    else:
        items = ((b.get("name", "?"), b) for b in biomes)

    changed = 0
    skipped_empty = 0
    for name, biome in items:
        layout = biome.get("plot_layout")
        if not isinstance(layout, list) or len(layout) == 0:
            skipped_empty += 1
            continue
        new_layout = even_line(len(layout))
        if layout == new_layout:
            continue
        biome["plot_layout"] = new_layout
        changed += 1
        if args.dry_run:
            print(f"  {name:<30s} n={len(new_layout)}  {new_layout}")

    print(f"\n{'DRY-RUN: ' if args.dry_run else ''}changed={changed}  empty/unchanged={skipped_empty}")

    if args.dry_run:
        return 0

    BIOMES_JSON.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    print(f"wrote {BIOMES_JSON}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
