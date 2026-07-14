#!/usr/bin/env python3
"""Export a seat/rig session tape as umwelt sensor rows.

Walks a rig `results.jsonl` (a real LLM-playtester session — the seat's own
recorded observations, nothing the player couldn't see) and emits the wire
shape umwelt's `events.replay_sensor_batches` consumes:

    rows: [ [ts_iso, sensor_id, value_str, null], ... ]   (sorted by time)

Sensor vocabulary (mirrors Core/Witness/witness_spec.json bindings):
    wallet_<emoji>        wallet level at each resource_snapshot   (level)
    measured_<biome>      count of measured bubbles per bubble_state (level)
    visible_<biome>       count of visible bubbles per bubble_state (level)
    flags_fired           cumulative story flags per story_flags read (level)

Timestamps: the tape records turn order, not wall time — rows are stamped on
a synthetic monotonic clock (TURN_S per turn, declared in the manifest).
That is CADENCE, not a time model: the consuming DomainSpec declares
`ingest_hold_s` per umwelt docs/TIME.md.

Usage:
  export_umwelt_tape.py <results.jsonl> <out_dir> [--turn-s 20]

Writes <out_dir>/rows.json + <out_dir>/manifest.json (+ emoji→ascii name map
— umwelt sensor ids stay ascii so the engine's vocabulary lint never sees
game glyphs).
"""
import json
import sys
import unicodedata
from datetime import datetime, timedelta, timezone
from pathlib import Path

START = datetime(2026, 1, 5, 0, 0, tzinfo=timezone.utc)


def ascii_name(emoji: str) -> str:
    try:
        return unicodedata.name(emoji[0]).lower().replace(" ", "_").replace("-", "_")
    except (ValueError, IndexError):
        return "u%04x" % ord(emoji[0]) if emoji else "blank"


def export(results_path: Path, out_dir: Path, turn_s: float = 20.0) -> dict:
    rows = []
    emoji_map = {}
    turns = 0
    counts = {"wallet": 0, "bubbles": 0, "flags": 0}

    def stamp(turn: int) -> str:
        return (START + timedelta(seconds=turn * turn_s)).isoformat()

    for line in results_path.read_text(encoding="utf-8").splitlines():
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not isinstance(row, dict) or not row.get("ok", False):
            continue
        turn = int(row.get("turn", 0))
        turns = max(turns, turn)
        ts = stamp(turn)
        action = str(row.get("action", ""))

        if action == "resource_snapshot":
            wallet = row.get("resources", row.get("snapshot", {}))
            if isinstance(wallet, dict) and "resources" in wallet:
                wallet = wallet["resources"]
            if isinstance(wallet, dict):
                for emoji, amount in wallet.items():
                    name = emoji_map.setdefault(str(emoji), ascii_name(str(emoji)))
                    rows.append([ts, "wallet_%s" % name, "%.1f" % float(amount), None])
                    counts["wallet"] += 1

        elif action == "bubble_state":
            per_biome = {}
            for bubble in row.get("bubbles", []):
                biome = str(bubble.get("biome", "")) or "unknown"
                entry = per_biome.setdefault(biome, {"measured": 0, "visible": 0})
                if bubble.get("visible"):
                    entry["visible"] += 1
                if bubble.get("measured"):
                    entry["measured"] += 1
            for biome, entry in sorted(per_biome.items()):
                bname = biome.lower()
                rows.append([ts, "measured_%s" % bname, str(entry["measured"]), None])
                rows.append([ts, "visible_%s" % bname, str(entry["visible"]), None])
                counts["bubbles"] += 1

        elif action == "story_flags":
            fired = row.get("flags_fired", {})
            if isinstance(fired, dict):
                rows.append([ts, "flags_fired", str(len(fired)), None])
                counts["flags"] += 1

    rows.sort(key=lambda r: r[0])
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "rows.json").write_text(json.dumps(rows), encoding="utf-8")
    manifest = {
        "source": str(results_path),
        "turns": turns,
        "rows": len(rows),
        "turn_s": turn_s,
        "start": START.isoformat(),
        "counts": counts,
        "emoji_map": emoji_map,
        "note": "synthetic monotonic clock (turn index x turn_s); "
                "player-visible observations only",
    }
    (out_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")
    return manifest


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    turn_s = 20.0
    if "--turn-s" in sys.argv:
        turn_s = float(sys.argv[sys.argv.index("--turn-s") + 1])
    manifest = export(Path(sys.argv[1]), Path(sys.argv[2]), turn_s)
    print(json.dumps(manifest, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
