#!/usr/bin/env python3
"""
Remove a biome by name from source biome files, then rebuild biomes_merged.json.

Examples:
  python3 tools/remove_biome_and_rebuild.py Nursery --write
  python3 tools/remove_biome_and_rebuild.py Nursery --source extra --write
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Dict, List, Tuple

import merge_biomes


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "Core" / "Biomes" / "data"
BASE_PATH = DATA_DIR / "biomes.json"
EXTRA_PATH = DATA_DIR / "new_biomes (1).json"
MERGED_PATH = DATA_DIR / "biomes_merged.json"


def _load_list(path: Path) -> List[Dict[str, Any]]:
    return json.loads(path.read_text(encoding="utf-8"))


def _write_list(path: Path, rows: List[Dict[str, Any]]) -> None:
    path.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _remove_by_name(rows: List[Dict[str, Any]], biome_name: str) -> Tuple[List[Dict[str, Any]], int]:
    kept = [row for row in rows if str(row.get("name", "")).strip() != biome_name]
    removed = len(rows) - len(kept)
    return kept, removed


def _validate_registry_shape(rows: List[Dict[str, Any]]) -> List[str]:
    errors: List[str] = []
    names: set[str] = set()
    required = ("name", "description", "plot_layout", "emojis", "native_factions", "tags", "atom_components")
    for idx, row in enumerate(rows):
        ctx = f"index={idx}"
        name = str(row.get("name", "")).strip()
        if not name:
            errors.append(f"{ctx}: missing name")
        elif name in names:
            errors.append(f"{ctx}: duplicate name '{name}'")
        else:
            names.add(name)

        # Legacy buckets like "_orphan_lindblads" intentionally do not follow full biome schema.
        if name.startswith("_"):
            continue

        for key in required:
            if key not in row:
                errors.append(f"{ctx}: biome '{name or '<unnamed>'}' missing key '{key}'")
    return errors


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Remove a biome and rebuild merged biome registry data")
    parser.add_argument("biome_name", type=str, help="Exact biome name to remove")
    parser.add_argument(
        "--source",
        choices=("all", "base", "extra"),
        default="all",
        help="Which source file(s) to remove from before rebuild",
    )
    parser.add_argument("--write", action="store_true", help="Persist changes to source + merged files")
    parser.add_argument(
        "--keep-legacy-merged-only",
        action="store_true",
        help="Keep entries that only exist in current merged file (default merge behavior)",
    )
    return parser


def main() -> int:
    args = _build_parser().parse_args()
    biome_name = args.biome_name.strip()
    if not biome_name:
        print("[remove_biome] biome_name cannot be empty")
        return 2

    base_rows = _load_list(BASE_PATH)
    extra_rows = _load_list(EXTRA_PATH)

    changed_base = base_rows
    changed_extra = extra_rows
    removed_base = 0
    removed_extra = 0

    if args.source in ("all", "base"):
        changed_base, removed_base = _remove_by_name(base_rows, biome_name)
    if args.source in ("all", "extra"):
        changed_extra, removed_extra = _remove_by_name(extra_rows, biome_name)

    if removed_base + removed_extra == 0:
        print(
            json.dumps(
                {
                    "biome_name": biome_name,
                    "removed": 0,
                    "removed_from": {"base": removed_base, "extra": removed_extra},
                    "message": "Biome not found in selected source files",
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return 1

    # Temporarily patch source data in memory and rebuild merged.
    old_base = merge_biomes.BASE_PATH
    old_extra = merge_biomes.EXTRA_PATH
    old_merged = merge_biomes.MERGED_PATH
    merge_biomes.BASE_PATH = BASE_PATH
    merge_biomes.EXTRA_PATH = EXTRA_PATH
    merge_biomes.MERGED_PATH = MERGED_PATH

    # Build merged from prospective source states.
    # We cannot inject directly into merge_biomes without writing, so emulate its logic here.
    source_map = {str(r.get("name", "")).strip(): r for r in changed_base if str(r.get("name", "")).strip()}
    source_map.update({str(r.get("name", "")).strip(): r for r in changed_extra if str(r.get("name", "")).strip()})
    existing_merged = _load_list(MERGED_PATH) if MERGED_PATH.exists() else []
    merged_map = {str(r.get("name", "")).strip(): r for r in existing_merged if str(r.get("name", "")).strip()}
    extras_only = {name: row for name, row in merged_map.items() if name not in source_map}
    if not args.keep_legacy_merged_only:
        # Default for removal tooling: if we removed biome from sources, remove it from merged too.
        extras_only.pop(biome_name, None)
    final_by_name = dict(extras_only)
    final_by_name.update(source_map)
    ordered: List[Dict[str, Any]] = []
    seen: set[str] = set()
    for row in existing_merged:
        name = str(row.get("name", "")).strip()
        if not name or name in seen or name not in final_by_name:
            continue
        ordered.append(final_by_name[name])
        seen.add(name)
    for name in sorted(n for n in final_by_name.keys() if n not in seen):
        ordered.append(final_by_name[name])
        seen.add(name)

    errors = _validate_registry_shape(ordered)

    report = {
        "biome_name": biome_name,
        "removed": removed_base + removed_extra,
        "removed_from": {"base": removed_base, "extra": removed_extra},
        "base_count_after": len(changed_base),
        "extra_count_after": len(changed_extra),
        "merged_count_after": len(ordered),
        "registry_shape_errors": errors,
        "write": args.write,
        "paths": {
            "base": str(BASE_PATH),
            "extra": str(EXTRA_PATH),
            "merged": str(MERGED_PATH),
        },
    }

    if args.write:
        _write_list(BASE_PATH, changed_base)
        _write_list(EXTRA_PATH, changed_extra)
        merge_biomes.write_merged(ordered)

    print(json.dumps(report, ensure_ascii=False, indent=2))

    merge_biomes.BASE_PATH = old_base
    merge_biomes.EXTRA_PATH = old_extra
    merge_biomes.MERGED_PATH = old_merged

    return 0 if not errors else 3


if __name__ == "__main__":
    raise SystemExit(main())
