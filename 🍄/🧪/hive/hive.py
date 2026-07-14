#!/usr/bin/env python3
"""hive — the fleet's shared world state, over umweltd.

The supervisor (and eventually the legs themselves) write coordination
observations here and read the fused belief graph back. Claims land at low
confidence, referees at high — the hive law from examples/hive_relay.

Usage:
  hive.py up                          start umweltd (if needed) + ensure the world
  hive.py leg <chapter> [--claim 0|1] [--truth 0|1] [--blocked 0|1] [--accurate 0|1]
                                      one leg's tick (chapter ∈ woodlot|spring|act3|hub)
  hive.py build [--suite 0|1] [--drive 0|1]
  hive.py backfill                    replay the verified 9-leg relay tape (2026-07-14)
  hive.py status                      the belief graph, fleet-readable
  hive.py down                        stop the world (daemon stays)

Requires the umwelt venv on PATH or UMWELT_PY pointing at its python.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
import urllib.error
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
UMWELT_REPO = Path.home() / "ws" / "umwelt"
BASE = os.environ.get("UMWELTD_URL", "http://127.0.0.1:7071")
WORLD = "spacewheat-hive"

sys.path.insert(0, str(UMWELT_REPO / "src"))
from umweltd.client import UmweltClient  # noqa: E402


def _client(world: bool = True) -> UmweltClient:
    return UmweltClient(BASE, world=WORLD if world else None)


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _daemon_alive() -> bool:
    try:
        _client(world=False).list_worlds()
        return True
    except (urllib.error.URLError, OSError):
        return False


def cmd_up() -> dict:
    if not _daemon_alive():
        py = os.environ.get("UMWELT_PY", sys.executable)
        subprocess.Popen(
            [py, "-m", "umweltd.supervisor", "--port", "7071"],
            cwd=str(UMWELT_REPO / "src"),
            stdout=open(HERE / "umweltd.log", "ab"),
            stderr=subprocess.STDOUT,
            start_new_session=True,
            env={**os.environ, "PYTHONPATH": str(UMWELT_REPO / "src")},
        )
        for _ in range(40):
            time.sleep(0.5)
            if _daemon_alive():
                break
        else:
            return {"ok": False, "error": "umweltd did not come up (see hive/umweltd.log)"}
    admin = _client(world=False)
    worlds = [w.get("name") if isinstance(w, dict) else w for w in admin.list_worlds()]
    if WORLD not in worlds:
        # vocabulary registers at spec-module import (top-level register_role_mode)
        admin.create_world(WORLD, "hive_world:HIVE_SPEC", spec_path=str(HERE))
        time.sleep(1.5)
    return {"ok": True, "daemon": BASE, "world": WORLD,
            "health": _client().health()}


def _ingest(readings: dict, ts: str | None = None) -> dict:
    ts = ts or _now()
    events = [(ts, sensor, "%.3f" % float(value), None)
              for sensor, value in readings.items()]
    return _client().ingest(events)


def cmd_leg(chapter: str, args: dict) -> dict:
    readings: dict = {"leg_completed": 1.0}
    if "claim" in args:
        readings[f"claim_{chapter}"] = args["claim"]
    if "truth" in args:
        readings[f"truth_{chapter}"] = args["truth"]
    if "blocked" in args:
        readings[f"blocked_{chapter}"] = args["blocked"]
    if "accurate" in args:
        readings["leg_accurate"] = args["accurate"]
    return {"ok": True, "ingested": readings, "resp": _ingest(readings)}


def cmd_build(args: dict) -> dict:
    readings = {}
    if "suite" in args:
        readings["suite_result"] = args["suite"]
    if "drive" in args:
        readings["drive_result"] = args["drive"]
    return {"ok": True, "ingested": readings, "resp": _ingest(readings)}


def cmd_backfill() -> dict:
    """The verified 2026-07-14 relay: nine legs of claims vs manifest truth,
    condensed to hive readings. Chapters map: legs m4-m9 worked pre-Woodlot
    ground (woodlot chapter's prehistory), m10-m12 the woodlot door."""
    tape = [
        # (chapter, claim, truth, accurate) — from the manifest-verified record
        ("woodlot", 0, 1, 0),   # m4: under-claimed its own breakthrough
        ("woodlot", 1, 0, 0),   # m5: over-claim
        ("woodlot", 1, 0, 0),   # m6: over-claim
        ("spring",  1, 1, 1),   # m7: the spring breakthrough, accurately reported
        ("woodlot", 0, 0, 0),   # m8: flags honest, bank confabulated → inaccurate leg
        ("woodlot", 0, 0, 1),   # m9
        ("woodlot", 1, 0, 0),   # m10: discovery real, flag claim inflated
        ("woodlot", 0, 0, 1),   # m11
        ("woodlot", 0, 0, 1),   # m12
    ]
    out = []
    for chapter, claim, truth, acc in tape:
        out.append(cmd_leg(chapter, {"claim": claim, "truth": truth, "accurate": acc}))
        time.sleep(0.2)
    return {"ok": True, "legs": len(out)}


def cmd_status() -> dict:
    c = _client()
    state = c.state()
    beliefs = {}
    for node in ("woodlot", "spring", "act3", "hub"):
        beliefs[node] = {
            "progress": c.belief(node, "progress"),
            "blocked": c.belief(node, "blocked"),
        }
    beliefs["build"] = {r: c.belief("build", r) for r in ("suite", "drive")}
    beliefs["fleet"] = {r: c.belief("fleet", r) for r in ("truthful", "momentum")}
    recs = []
    try:
        recs = c.recommendations()
    except Exception:
        pass
    return {"ok": True, "world": WORLD, "beliefs": beliefs,
            "recommendations": recs, "health": state.get("health", state)}


def main() -> int:
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 1
    cmd = args[0]

    def flag(name: str) -> dict:
        if f"--{name}" in args:
            i = args.index(f"--{name}")
            return {name: float(args[i + 1])}
        return {}

    try:
        if cmd == "up":
            out = cmd_up()
        elif cmd == "leg":
            out = cmd_leg(args[1], {**flag("claim"), **flag("truth"),
                                    **flag("blocked"), **flag("accurate")})
        elif cmd == "build":
            out = cmd_build({**flag("suite"), **flag("drive")})
        elif cmd == "backfill":
            out = cmd_backfill()
        elif cmd == "status":
            out = cmd_status()
        elif cmd == "down":
            out = _client(world=False).stop_world(WORLD)
        else:
            out = {"ok": False, "error": "unknown command"}
    except Exception as exc:  # honest failure beats a silent hive
        out = {"ok": False, "error": str(exc)[:400]}
    print(json.dumps(out, ensure_ascii=False, indent=1, default=str))
    return 0 if out.get("ok", True) else 1


if __name__ == "__main__":
    sys.exit(main())
