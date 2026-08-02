#!/usr/bin/env python3
"""witness_hearth — post SpaceWheat's LIVE Witness field into the hearth.

This is the sensor leg of the hive's body (plan: "SpaceWheat as the hive's
body", 2026-08-01). Every other live world on the hearth is a near-passive
observer of daemons and files; SpaceWheat carries a real multi-qubit density
matrix over a complex environment. This module is how that reaches the mesh.

    game (WitnessOrgan, always-on autoload)
      -> rig verb `witness_gauge`            [🍄/🎛️/rig_listener.gd:537]
      -> gauge_to_readings                   [hive/witness_readings.py]
      -> POST /worlds/spacewheat-self/events [🍄/🧪/semantica_post.py:84]

Nothing here is new machinery — it is the composition of three pieces that were
each built to be connected and never were.

OPT-IN, like every other hearth poster in this repo: set SEMANTICA_POST=1.
A dark hearth is reported honestly and never breaks the game or the caller.

THE UNMATCHED LAW: a biome the Witness minted but this adapter has no node for
is REPORTED, never silently dropped. Silently-dropped readings are precisely the
failure meta-membrane was built to catch (hive-ops sat at 186/186 unmatched,
fleet cluster fully mixed, while the mesh kept trusting its beliefs). If you see
`unmapped` in the output, add the biome to BIOME_NODES and re-spec the world.

Usage:
    SEMANTICA_POST=1 python3 witness_hearth.py                 # live, from a running game
    python3 witness_hearth.py --gauge <path.json> --dry-run    # offline, prints the payload
    python3 witness_hearth.py --gauge <path.json>              # offline gauge, real post
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "hive"))
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))  # 🍄/🎛️ for rig_client

from witness_readings import gauge_to_readings, surprise_readings  # noqa: E402
from semantica_post import HearthDark, post  # noqa: E402

WORLD = os.environ.get("SPACEWHEAT_WORLD", "spacewheat-self")

# The biomes the Witness has ACTUALLY minted across 100 banked play sessions
# (surveyed 2026-08-01). Core/Biomes/data/biomes.json declares 163 biomes, but a
# DomainSpec node per declared biome would be 815 registers of mostly-vacuum.
# This is the honest working set: what real play has touched. Extending it is a
# one-line edit here plus a world re-spec — and THE UNMATCHED LAW above makes
# the need to extend visible instead of silent.
BIOME_NODES = {
    "TheDemos": "the_demos",
    "Village": "village",
    "StarterForest": "starter_forest",
    "Woodlot": "woodlot",
    "FreshwaterSpring": "freshwater_spring",
    "Lanternfall": "lanternfall",
    "AshPatch": "ash_patch",
    "BloodLedger": "blood_ledger",
    "Harbor": "harbor",
    "GildedRot": "gilded_rot",
    "ShrineOfAshes": "shrine_of_ashes",
    "ZenoLatch": "zeno_latch",
    "NullingChamber": "nulling_chamber",
}

# Core/Witness/witness_spec.json — biome_template roles and self roles.
#
# `ripeness` is deliberately ABSENT (2026-08-02). witness_spec.json declares it as a
# biome_template role but ships NO binding for it — it sits on that spec's own
# `ignored` list ("phase 2: 1Hz poll of player-visible berry tracking"), and across
# 100 banked real-play gauges it is populated 0/522. Posting a role the game cannot
# feed puts registers on the hearth that render ⚪ = calm forever, which is the
# DARK-vs-STALE lie one layer down. When phase 2 lands, add it back here AND in
# yurt/worlds/spacewheat_self/world.py — the two lists are one contract, and
# unmapped_roles() below makes forgetting loud instead of silent.
BIOME_ROLES = ("yield", "outcome", "drain", "coverage")
SELF_ROLES = ("wealth_trend", "quest_momentum", "standing", "attention")


def _slug(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def sensor_name(biome: str | None, role: str) -> str | None:
    """Witness (cluster, role) -> the world's binding id, or None if unmapped."""
    if biome is None:
        return f"self_{role}_felt" if role in SELF_ROLES else None
    node = BIOME_NODES.get(biome)
    if node is None or role not in BIOME_ROLES:
        return None
    return f"{node}_{role}_felt"


def unmapped_biomes(gauge: dict) -> list[str]:
    """Biomes present in the gauge that this adapter has no node for."""
    seen = set()
    for cname in (gauge.get("clusters") or {}):
        if cname.startswith("biome:"):
            biome = cname.split(":", 1)[1]
            if biome not in BIOME_NODES:
                seen.add(biome)
    return sorted(seen)


def collect(gauge: dict) -> dict[str, float]:
    """The whole field, as sensor readings: biomes + self + innovation."""
    readings = gauge_to_readings(
        gauge, name_fn=sensor_name, include_self=True, include_biomes=True)
    readings.update(surprise_readings(
        gauge, name_fn=lambda src: f"surprise_{_slug(src)}_ema"))
    observes = gauge.get("observes_total")
    if observes is not None:
        readings["witness_observes_total"] = float(observes)
    return readings


def live_gauge(timeout_s: float = 15.0) -> dict:
    """Pull a gauge from a running game over the rig. Raises on no listener.

    ATTACH, never mint. This sensor never starts a game — it reads one that is
    already up — and a bare RigClient() opens a FRESH private lane
    (🍄/🎛️/milk_hunt_paths.py:29-45), so it would queue witness_gauge into a file
    no Godot is polling and come back "timeout_waiting_for_result" with nothing
    named. attach_to_running_listener (🍄/🎛️/rig_client.py:236) takes the lane off
    the live listener instead, and says which variable to export when there is
    none: a dark rig is reported honestly, never waited on.
    """
    from rig_client import RigClient  # imported lazily: offline mode needs no rig

    client = RigClient.attach_to_running_listener()
    result = client.run_turn(9_900_001, "witness_gauge", timeout_s=timeout_s)
    if not result.get("ok", False):
        raise RuntimeError(f"rig refused witness_gauge: {result.get('error', result)!r}")
    gauge = result.get("gauge")
    if not isinstance(gauge, dict):
        raise RuntimeError(f"rig returned no gauge (keys={sorted(result)})")
    return gauge


def push(gauge: dict, *, world: str = WORLD, dry_run: bool = False) -> dict:
    """Convert and post. Returns a report; never fakes a success."""
    readings = collect(gauge)
    unmapped = unmapped_biomes(gauge)
    report: dict = {"world": world, "readings": len(readings),
                    "unmapped": unmapped, "dry_run": dry_run}
    if dry_run:
        report["payload"] = readings
        report["ok"] = True
        return report
    meta = {"source": "witness_hearth", "spec_hash": gauge.get("spec_hash", "")}
    appended, dark = 0, []
    for sensor, value in sorted(readings.items()):
        try:
            appended += post(sensor, value, meta, world=world)
        except HearthDark as exc:
            dark.append(f"{sensor}: {exc}")
            break  # the hearth is down; stop hammering it
    report["appended"] = appended
    report["ok"] = not dark and appended == len(readings)
    if dark:
        report["dark"] = dark
    return report


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="post the live Witness field to the hearth")
    ap.add_argument("--gauge", help="read a gauge JSON from disk instead of the live rig")
    ap.add_argument("--world", default=WORLD)
    ap.add_argument("--dry-run", action="store_true", help="convert and print; post nothing")
    args = ap.parse_args(argv)

    if not args.dry_run and os.environ.get("SEMANTICA_POST") != "1":
        print("[witness_hearth] SEMANTICA_POST != 1 — refusing to post (use --dry-run to inspect)",
              file=sys.stderr)
        return 2
    try:
        gauge = (json.loads(Path(args.gauge).read_text(encoding="utf-8"))
                 if args.gauge else live_gauge())
    except Exception as exc:
        print(json.dumps({"ok": False, "error": f"no gauge: {exc}"}, ensure_ascii=False))
        return 2

    report = push(gauge, world=args.world, dry_run=args.dry_run)
    print(json.dumps(report, ensure_ascii=False, indent=1, sort_keys=True))
    if report["unmapped"]:
        print(f"[witness_hearth] UNMATCHED biomes (add to BIOME_NODES + re-spec): "
              f"{', '.join(report['unmapped'])}", file=sys.stderr)
    return 0 if report.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
