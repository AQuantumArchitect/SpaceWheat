#!/usr/bin/env python3
"""roc_import.py — wargen-side importer/referee for SpaceWheat-on-roc legs.

Roc runs legs via yurt-sync/workspaces/spacewheat/run_leg.py; Syncthing carries
results/<run_id>/ (turns.jsonl, banked .tres, manifest.json) back here.

For each NEW run this importer:
  * re-greps the banked .tres for story flags   (referee — high η evidence)
  * compares against the manifest's flag list   (claim  — low η, roc-side grep)
  * prints one hive-style tick line
  * appends a row to 🍄/🧪/hive/roc_runs.jsonl

`--post` additionally formats (does NOT send) the two Semantica membrane
events per run — wiring the membrane later means replacing `post_events`'s
print with a single send call.

Usage:
  python3 🍄/🧪/hive/roc_import.py             # import new runs
  python3 🍄/🧪/hive/roc_import.py --post      # ... and show membrane events
  python3 🍄/🧪/hive/roc_import.py --redo      # re-import everything
"""
import argparse
import json
import re
import time
from pathlib import Path

HIVE = Path(__file__).resolve().parent
LEDGER = HIVE / "roc_runs.jsonl"
DEFAULT_RESULTS = Path(
    "/mnt/c/Users/Luke Spooner/ws-win/yurt-sync/workspaces/spacewheat/results")

FLAG_BLOCK_RE = re.compile(r"story_flags_fired\s*=\s*\{(.*?)\}", re.S)
FLAG_KEY_RE = re.compile(r'"([A-Za-z0-9_]+)"\s*:')


def grep_flags(tres_path: Path) -> list:
    """Referee: the save file is the only witness that counts."""
    try:
        text = tres_path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return []
    m = FLAG_BLOCK_RE.search(text)
    if not m:
        return []
    return sorted(set(FLAG_KEY_RE.findall(m.group(1))))


def seen_run_ids() -> set:
    if not LEDGER.exists():
        return set()
    out = set()
    for raw in LEDGER.read_text(encoding="utf-8").splitlines():
        try:
            out.add(json.loads(raw).get("run_id"))
        except json.JSONDecodeError:
            pass
    return out


def referee_run(run_dir: Path, manifest: dict) -> dict:
    claim = sorted(set(manifest.get("flags", [])))
    tres_files = sorted(run_dir.glob("*.tres"))
    referee = grep_flags(tres_files[0]) if tres_files else []
    if not tres_files:
        verdict = "NO_BANK"
    elif not referee:
        verdict = "EMPTY_BANK"
    elif referee == claim:
        verdict = "CONFIRMED"
    else:
        verdict = "MISMATCH"
    return {
        "run_id": manifest.get("run_id", run_dir.name),
        "model": manifest.get("model", "?"),
        "checkpoint": manifest.get("checkpoint", "?"),
        "commands_used": manifest.get("commands_used", -1),
        "duration_s": manifest.get("duration_s", -1),
        "claim_flags": claim,
        "referee_flags": referee,
        "verdict": verdict,
        "bank_file": tres_files[0].name if tres_files else "",
        "run_dir": str(run_dir),
        "imported_at": time.time(),
    }


def tick_line(row: dict) -> str:
    ok = row["verdict"] == "CONFIRMED"
    return ("%s %s  model=%s ckpt=%s cmds=%s  flags claim=%d referee=%d  %s" % (
        "✅" if ok else "❌", row["run_id"], row["model"],
        row["checkpoint"], row["commands_used"],
        len(row["claim_flags"]), len(row["referee_flags"]), row["verdict"]))


def format_semantica_events(row: dict) -> list:
    """The two membrane events for one leg.

    claim   — roc's own report of what happened      (low η:  ±0.25)
    referee — wargen's re-grep of the banked save    (high η: ±0.9)
    """
    ts = row["imported_at"]
    rid = row["run_id"]
    claim_ok = bool(row["claim_flags"])
    referee_ok = row["verdict"] == "CONFIRMED"
    claim_meta = {
        "model": row["model"], "checkpoint": row["checkpoint"],
        "commands": row["commands_used"], "flags": len(row["claim_flags"]),
    }
    referee_meta = {
        "verdict": row["verdict"], "flags": len(row["referee_flags"]),
        "bank": row["bank_file"],
    }
    return [
        [ts, f"spacewheat.leg.{rid}.claim", 0.25 if claim_ok else -0.25, claim_meta],
        [ts, f"spacewheat.leg.{rid}.referee", 0.9 if referee_ok else -0.9, referee_meta],
    ]


def post_events(rows: list) -> None:
    """STUB: formats the membrane events. Wiring Semantica later = replace the
    print below with the membrane's send() — one function, one call site."""
    for row in rows:
        events = format_semantica_events(row)
        print("[semantica-stub] " + json.dumps(events, ensure_ascii=False))


def main() -> int:
    ap = argparse.ArgumentParser(description="Import roc SpaceWheat leg results.")
    ap.add_argument("--results-dir", default=str(DEFAULT_RESULTS))
    ap.add_argument("--post", action="store_true",
                    help="format (not send) the Semantica events for new runs")
    ap.add_argument("--redo", action="store_true",
                    help="re-import runs already in the ledger")
    args = ap.parse_args()

    results_root = Path(args.results_dir)
    if not results_root.is_dir():
        print(f"no results dir yet: {results_root}")
        return 0

    seen = set() if args.redo else seen_run_ids()
    new_rows = []
    for run_dir in sorted(p for p in results_root.iterdir() if p.is_dir()):
        mf_path = run_dir / "manifest.json"
        if not mf_path.exists():
            continue
        try:
            manifest = json.loads(mf_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            print(f"❌ {run_dir.name}  unreadable manifest: {exc}")
            continue
        if manifest.get("run_id", run_dir.name) in seen:
            continue
        row = referee_run(run_dir, manifest)
        print(tick_line(row))
        new_rows.append(row)

    if new_rows:
        with LEDGER.open("a", encoding="utf-8") as fh:
            for row in new_rows:
                fh.write(json.dumps(row, ensure_ascii=False) + "\n")
        print(f"[roc_import] {len(new_rows)} new run(s) -> {LEDGER.name}")
    else:
        print("[roc_import] nothing new")

    if args.post and new_rows:
        post_events(new_rows)
    return 0


if __name__ == "__main__":
    main()
