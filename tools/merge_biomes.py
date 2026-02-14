#!/usr/bin/env python3
"""
Merge biome source files into Core/Biomes/data/biomes_merged.json.

Behavior:
- Combines `biomes.json` + `new_biomes (1).json` by biome `name`.
- Preserves legacy entries that exist only in current merged file.
- Keeps existing merged ordering where possible; appends brand-new names sorted.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Dict, List


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "Core" / "Biomes" / "data"
BASE_PATH = DATA_DIR / "biomes.json"
EXTRA_PATH = DATA_DIR / "new_biomes (1).json"
MERGED_PATH = DATA_DIR / "biomes_merged.json"


def _load_list(path: Path) -> List[Dict[str, Any]]:
    return json.loads(path.read_text(encoding="utf-8"))


def _as_name_map(rows: List[Dict[str, Any]]) -> Dict[str, Dict[str, Any]]:
    out: Dict[str, Dict[str, Any]] = {}
    for row in rows:
        name = str(row.get("name", "")).strip()
        if not name:
            continue
        out[name] = row
    return out


def merge_biomes() -> List[Dict[str, Any]]:
    base_rows = _load_list(BASE_PATH)
    extra_rows = _load_list(EXTRA_PATH)
    merged_rows = _load_list(MERGED_PATH) if MERGED_PATH.exists() else []

    source_map = _as_name_map(base_rows)
    source_map.update(_as_name_map(extra_rows))
    merged_map = _as_name_map(merged_rows)

    extras_only = {name: row for name, row in merged_map.items() if name not in source_map}
    final_by_name = dict(extras_only)
    final_by_name.update(source_map)

    ordered: List[Dict[str, Any]] = []
    seen: set[str] = set()

    # Preserve current merged ordering where possible.
    for row in merged_rows:
        name = str(row.get("name", "")).strip()
        if not name or name in seen or name not in final_by_name:
            continue
        ordered.append(final_by_name[name])
        seen.add(name)

    # Add any brand-new names (e.g., newly introduced biomes).
    for name in sorted(n for n in final_by_name.keys() if n not in seen):
        ordered.append(final_by_name[name])
        seen.add(name)

    return ordered


def write_merged(merged: List[Dict[str, Any]]) -> None:
    MERGED_PATH.write_text(json.dumps(merged, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Merge biome source files into biomes_merged.json")
    parser.add_argument("--write", action="store_true", help="Write merged output to biomes_merged.json")
    args = parser.parse_args()

    merged = merge_biomes()

    if args.write:
        write_merged(merged)
        print(f"[merge_biomes] wrote {len(merged)} biomes to {MERGED_PATH}")
    else:
        print(json.dumps({"count": len(merged), "path": str(MERGED_PATH)}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
