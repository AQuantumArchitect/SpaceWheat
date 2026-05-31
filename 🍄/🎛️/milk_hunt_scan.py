#!/usr/bin/env python3
import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any, Dict, List

from milk_hunt_paths import latest_complete_batch_dir, resolve_batch_summary, resolve_user_dir_for_scan
from rig_client import RigClient


def _scan_results(tail_n: int) -> int:
    user_dir = resolve_user_dir_for_scan()
    results_file = user_dir / "rig" / "results.jsonl"
    if not results_file.exists():
        print(f"No rig results file found: {results_file}")
        return 1

    rows = RigClient.json_load_lines(results_file)
    total = len(rows)
    ok_count = sum(1 for r in rows if bool(r.get("ok", False)))
    err_count = total - ok_count
    actions = Counter(str(r.get("action", "")) for r in rows if isinstance(r, dict))
    turns = [int(r.get("turn", 0)) for r in rows if isinstance(r.get("turn", None), (int, float))]

    print(f"RESULTS_FILE {results_file}")
    print(f"TOTAL_ROWS {total}")
    print(f"OK_ROWS {ok_count}")
    print(f"ERROR_ROWS {err_count}")
    if turns:
        print(f"TURN_MIN {min(turns)}")
        print(f"TURN_MAX {max(turns)}")
    print("ACTIONS_TOP")
    for action, count in actions.most_common(12):
        print(f"  {action}: {count}")
    print("TAIL")
    for r in rows[-tail_n:]:
        turn = r.get("turn", "?")
        action = r.get("action", "?")
        ok = r.get("ok", False)
        err = r.get("error", "")
        line = f"  turn={turn} ok={ok} action={action}"
        if err:
            line += f" error={err}"
        print(line)
    return 0


def _walk_tree(path: Path, prefix: str = "") -> None:
    entries = sorted(list(path.iterdir()), key=lambda p: (not p.is_dir(), p.name.lower()))
    for i, entry in enumerate(entries):
        is_last = i == len(entries) - 1
        branch = "└── " if is_last else "├── "
        print(f"{prefix}{branch}{entry.name}")
        if entry.is_dir():
            next_prefix = prefix + ("    " if is_last else "│   ")
            _walk_tree(entry, next_prefix)


def _scan_tree(root: Path) -> int:
    if not root.exists():
        print(f"Missing path: {root}")
        return 1
    target = root
    if root.is_dir():
        latest = latest_complete_batch_dir(root)
        if latest is not None:
            target = latest
    print(f"TREE_ROOT {target}")
    if target.is_dir():
        _walk_tree(target)
    else:
        print(target.name)
    return 0


def _scan_pipe(root: Path) -> int:
    if not root.exists():
        print(json.dumps({"ok": False, "error": "missing_root", "path": str(root)}, ensure_ascii=False))
        return 1

    summary_path = resolve_batch_summary(root)
    if summary_path is None:
        print(json.dumps({"ok": False, "error": "no_batch_summary", "path": str(root)}, ensure_ascii=False))
        return 1

    data: Dict[str, Any] = json.loads(summary_path.read_text(encoding="utf-8"))
    header = {
        "ok": True,
        "type": "batch_header",
        "batch_summary": str(summary_path),
        "runs": int(data.get("runs", 0) or 0),
        "success_count": int(data.get("success_count", 0) or 0),
        "success_rate": float(data.get("success_rate", 0.0) or 0.0),
        "avg_turns_all": float(data.get("avg_turns_all", 0.0) or 0.0),
        "avg_steps_all": float(data.get("avg_steps_all", 0.0) or 0.0),
    }
    print(json.dumps(header, ensure_ascii=False))

    rows: List[Dict[str, Any]] = data.get("run_summaries", []) or []
    for run in rows:
        row = {
            "type": "run",
            "run_name": run.get("run_name", ""),
            "exit_code": run.get("exit_code", None),
            "found_milk_pair": bool(run.get("found_milk_pair", False)),
            "known_icons_count": int(run.get("known_icons_count", 0) or 0),
            "milk_pair_index": run.get("milk_pair_index", None),
            "steps": int(run.get("steps", run.get("turns_executed", 0) or 0) or 0),
            "turns_executed": int(run.get("turns_executed", 0) or 0),
            "log_path": run.get("log_path", ""),
        }
        print(json.dumps(row, ensure_ascii=False))
    return 0


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Scan milk-hunt rig/batch outputs")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_results = sub.add_parser("results", help="Summarize rig results.jsonl")
    p_results.add_argument("tail", nargs="?", type=int, default=20, help="Tail line count")

    p_tree = sub.add_parser("tree", help="Print tree for latest complete batch")
    p_tree.add_argument("root", nargs="?", default="/tmp/milk_hunt_batches", help="Batch root path")

    p_pipe = sub.add_parser("pipe", help="Print NDJSON summary rows")
    p_pipe.add_argument("root", nargs="?", default="/tmp/milk_hunt_batches", help="Batch root path")
    return parser


def main() -> int:
    args = _build_parser().parse_args()
    if args.cmd == "results":
        return _scan_results(args.tail)
    if args.cmd == "tree":
        return _scan_tree(Path(args.root))
    if args.cmd == "pipe":
        return _scan_pipe(Path(args.root))
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
