#!/usr/bin/env python3
"""almanac — the tracked process that learns SpaceWheat as it feels to play.

Library-direct (a batch learner, not a daemon): each session's play digest
ingests into a persistent engine; after every ingest the diff-stable gauge
and the learned-parameter snapshot are written to gauges/ (git-track those —
the commit history IS the fleet learning the game).

Usage:
  almanac.py backfill            ingest every banked checkpoint with a witness
                                 gauge, oldest first (the campaign's play history)
  almanac.py session <ckpt>      ingest one checkpoint's digest (e.g. m12_final)
  almanac.py gauge               write gauges/almanac_<step>.json (do this, then git add)
  almanac.py status              the felt-graph, fleet-readable
  almanac.py reset               forget everything (deletes the brain, not the gauges)

Learning knobs are ON: learned couplings apply, online collapse-alpha adapts,
dream topology growth is armed (its live win is this project's long game).
"""
from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

# Learning ON before any umwelt import (env-gated organs).
os.environ.setdefault("UMWELT_LEARNED_TOPOLOGY", "1")
os.environ.setdefault("UMWELT_LEARN_COLLAPSE", "1")
os.environ.setdefault("UMWELT_DREAM_TOPOLOGY", "1")

HERE = Path(__file__).resolve().parent
UMWELT_REPO = Path.home() / "ws" / "umwelt"
sys.path.insert(0, str(UMWELT_REPO / "src"))
sys.path.insert(0, str(HERE))

from almanac_world import ALMANAC_SPEC, COUNTRIES  # noqa: E402
from witness_readings import gauge_to_readings  # noqa: E402
from umwelt.boot import build_engine  # noqa: E402
from umwelt.projection.gauge import field_gauge  # noqa: E402
from umwelt.projection.transparency import model_snapshot  # noqa: E402

BRAIN = HERE / "almanac_state.pkl"
GAUGES = HERE / "gauges"
CHECKPOINTS = HERE.parent / "checkpoints"

# The Witness's biome names → the Almanac's felt countries.
BIOME_TO_COUNTRY = {"TheDemos": "demos", "Village": "village",
                    "StarterForest": "forest", "FreshwaterSpring": "spring",
                    "Woodlot": "woodlot"}


def _engine():
    engine = build_engine(spec=ALMANAC_SPEC)
    if BRAIN.exists():
        engine.load(str(BRAIN))
    return engine


def _digest_checkpoint(name: str) -> tuple[dict, str] | None:
    """One banked play session → sensor readings + its timestamp."""
    manifest_p = CHECKPOINTS / f"{name}.json"
    gauge_p = CHECKPOINTS / f"{name}.witness_gauge.json"
    if not manifest_p.exists():
        return None
    manifest = json.loads(manifest_p.read_text(encoding="utf-8"))
    readings: dict[str, float] = {"session_flags": float(len(manifest.get("flags_fired", [])))}
    if gauge_p.exists():
        witness = json.loads(gauge_p.read_text(encoding="utf-8"))
        # Conversion (incl. the absence law) lives in witness_readings — the one
        # authority, shared with the live hearth poster. The Almanac's own policy
        # is only WHICH biomes it has countries for and WHICH roles it feels.
        readings.update(gauge_to_readings(
            witness,
            name_fn=lambda biome, role: (
                f"felt_{BIOME_TO_COUNTRY[biome]}_{role}" if biome in BIOME_TO_COUNTRY else None),
            roles=("yield", "outcome", "coverage"),
        ))
    ts = datetime.fromtimestamp(manifest.get("time", manifest_p.stat().st_mtime),
                                tz=timezone.utc).isoformat()
    return readings, ts


def cmd_session(name: str) -> dict:
    digest = _digest_checkpoint(name)
    if digest is None:
        return {"ok": False, "error": f"no manifest for checkpoint '{name}'"}
    readings, ts = digest
    engine = _engine()
    engine.ingest(sensor_readings=readings, now=datetime.fromisoformat(ts))
    engine.save(str(BRAIN))
    return {"ok": True, "session": name, "readings": len(readings), "at": ts}


def cmd_backfill() -> dict:
    sessions = []
    for p in CHECKPOINTS.glob("*.json"):
        if p.name.endswith(".witness_gauge.json"):
            continue
        manifest = json.loads(p.read_text(encoding="utf-8"))
        sessions.append((float(manifest.get("time", p.stat().st_mtime)), p.stem))
    sessions.sort()
    out = []
    for _t, name in sessions:
        r = cmd_session(name)
        if r.get("ok"):
            out.append(name)
    return {"ok": True, "sessions": out}


def cmd_gauge() -> dict:
    engine = _engine()
    GAUGES.mkdir(exist_ok=True)
    snapshot = {
        "written": datetime.now(timezone.utc).isoformat(),
        "gauge": field_gauge(engine.field),
        "learned": model_snapshot(engine)["params"][:20],  # most-drifted first
    }
    step = len(list(GAUGES.glob("almanac_*.json")))
    path = GAUGES / f"almanac_{step:04d}.json"
    path.write_text(json.dumps(snapshot, indent=1, sort_keys=True, default=str),
                    encoding="utf-8")
    return {"ok": True, "wrote": str(path),
            "params_learned": sum(1 for p in snapshot["learned"] if p.get("learned"))}


def cmd_status() -> dict:
    engine = _engine()
    felt = {}
    for country in COUNTRIES:
        cluster = engine.field.clusters.get(country)
        if cluster is None:
            continue
        felt[country] = {r: round(float(cluster.role_bloch(r)[2]), 3)
                         for r in ("generous", "bright", "known")}
    journey = engine.field.clusters.get("journey")
    if journey is not None:
        felt["journey"] = {r: round(float(journey.role_bloch(r)[2]), 3)
                           for r in ("story", "pace", "fortune")}
    drift = [{"param": f"{p['node']}.{p['name']}", "drift": round(p["drift"], 4)}
             for p in model_snapshot(engine)["params"][:5]]
    return {"ok": True, "felt": felt, "most_learned": drift}


def main() -> int:
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 1
    try:
        cmd = args[0]
        if cmd == "backfill":
            out = cmd_backfill()
        elif cmd == "session":
            out = cmd_session(args[1])
        elif cmd == "gauge":
            out = cmd_gauge()
        elif cmd == "status":
            out = cmd_status()
        elif cmd == "reset":
            BRAIN.unlink(missing_ok=True)
            out = {"ok": True, "forgot": True}
        else:
            out = {"ok": False, "error": "unknown command"}
    except Exception as exc:
        out = {"ok": False, "error": str(exc)[:400]}
    print(json.dumps(out, ensure_ascii=False, indent=1, default=str))
    return 0 if out.get("ok", True) else 1


if __name__ == "__main__":
    sys.exit(main())
