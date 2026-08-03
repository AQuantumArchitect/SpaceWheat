#!/usr/bin/env python3
"""assay_cli.py — the shared CLI harness for the tools/*_assay.py scanners.

Each assay (clock, eit, ssh, transition, gain, zeno) used to carry a
copy-pasted main(): identical argparse block, identical --biome detail
branch, and an identical rank/print loop around biome_audit's shared
loaders. They now all delegate to run_assay() below and keep only what is
genuinely theirs: the physics (assay_biome), the detail printer, and the
summary-table printer.

Per-caller knobs that were real behavioral differences are EXPLICIT
parameters, most importantly `skip_orphan_biomes`: clock/transition/gain
exclude the `_orphan_lindblads` pseudo-biome from the ranking sweep, while
eit/ssh/zeno assay it like any other biome. Each caller states its side.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from biome_audit import (  # noqa: E402
    load_factions,
    load_biomes,
)

ORPHAN_BIOME_NAME = '_orphan_lindblads'


def run_assay(
    *,
    assay_fn,
    print_detail,
    sort_key: str,
    print_summary,
    skip_orphan_biomes: bool,
    description: str | None = None,
    default_top: int = 10,
    default_threshold: float | None = None,
    build_parser=None,
    argv=None,
) -> int:
    """Shared assay entry point. Returns the process exit code.

    assay_fn(biome, factions) -> result dict (a truthy 'note' marks a skip)
    print_detail(result)      -> per-biome detail printer (--biome branch)
    sort_key                  -> result key to rank by, descending
    print_summary(ok, results, args) -> the ranked-table printer;
        `ok` is the sorted skip-free list, `results` the full sweep output
    skip_orphan_biomes        -> exclude the '_orphan_lindblads' pseudo-biome
        from the ranking sweep (never applies to the --biome detail branch)
    build_parser              -> optional () -> ArgumentParser override for
        assays with extra flags; the default parser exposes
        --top/--biome/--threshold
    """
    if build_parser is not None:
        ap = build_parser()
    else:
        ap = argparse.ArgumentParser(description=description)
        ap.add_argument('--top', type=int, default=default_top)
        ap.add_argument('--biome', type=str, default=None)
        ap.add_argument('--threshold', type=float, default=default_threshold)
    args = ap.parse_args(argv)

    factions = load_factions()
    biomes = load_biomes()

    if args.biome:
        m = [b for b in biomes if b['name'] == args.biome]
        if not m:
            print(f'No such biome: {args.biome}')
            return 1
        print_detail(assay_fn(m[0], factions))
        return 0

    if skip_orphan_biomes:
        results = [assay_fn(b, factions) for b in biomes
                   if b.get('name') != ORPHAN_BIOME_NAME]
    else:
        results = [assay_fn(b, factions) for b in biomes]
    ok = [r for r in results if not r.get('note')]
    ok.sort(key=lambda r: r[sort_key], reverse=True)

    print_summary(ok, results, args)
    return 0
