#!/usr/bin/env python3
"""Regenerate the numbers quoted in README.md and docs/HOW_THIS_WAS_BUILT.md.

    python3 tools/repo_stats.py            # human-readable
    python3 tools/repo_stats.py --json     # for scripts

Everything is counted from the tree and git history; nothing is typed by hand.
"""
from __future__ import annotations

import argparse
import collections
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VENDORED = ("native/include/", "godot-cpp/", "addons/")


def git(*args: str) -> str:
    return subprocess.run(["git", "-c", "core.quotepath=false", *args], cwd=ROOT,
                          capture_output=True, text=True, check=True).stdout


def _load_list(rel: str, key: str) -> list:
    data = json.loads((ROOT / rel).read_text(encoding="utf-8"))
    return data if isinstance(data, list) else data.get(key, [])


def lines_by_language() -> dict:
    exts = {".gd": "GDScript", ".py": "Python", ".cpp": "C++", ".h": "C++"}
    out = collections.Counter()
    for path in git("ls-files").splitlines():
        if path.startswith(VENDORED):
            continue
        lang = exts.get(Path(path).suffix)
        if lang is None:
            continue
        try:
            out[lang] += sum(1 for _ in (ROOT / path).open(encoding="utf-8", errors="ignore"))
        except OSError:
            pass
    return dict(out)


def history() -> dict:
    dates = git("log", "--format=%ad", "--date=short").split()
    months = collections.Counter(d[:7] for d in dates)
    models = collections.Counter()
    for line in git("log", "--format=%b").splitlines():
        m = re.match(r"\s*Co-Authored-By:\s*(Claude[^<]*?)\s*<", line, re.I)
        if m:
            models[m.group(1).strip()] += 1
    return {
        "commits": len(dates),
        "first_commit": min(dates) if dates else "",
        "last_commit": max(dates) if dates else "",
        "commits_by_month": dict(sorted(months.items())),
        "model_coauthor_trailers": dict(models.most_common()),
    }


def game() -> dict:
    gates = set(re.findall(r'GATES\["([A-Za-z_]+)"\]\s*=',
                           (ROOT / "Core/QuantumSubstrate/QuantumGateLibrary.gd").read_text(encoding="utf-8")))
    campaign = json.loads((ROOT / "Core/Campaign/campaign.json").read_text(encoding="utf-8"))
    return {
        "biomes": len(_load_list("Core/Biomes/data/biomes.json", "biomes")),
        "factions": len(_load_list("Core/Factions/data/factions.json", "factions")),
        "icons": len(_load_list("Core/Factions/data/icons.json", "icons")),
        "gates": sorted(gates),
        "campaigns": [{"title": c["title"], "acts": len(c["acts"]),
                       "status": c.get("status", "complete")} for c in campaign["campaigns"]],
        "test_files": len([p for p in git("ls-files", "tests").splitlines()
                           if Path(p).name.startswith("test_") and p.endswith(".py")]),
    }


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    stats = {"game": game(), "code_lines": lines_by_language(), "history": history()}
    if args.json:
        print(json.dumps(stats, indent=2, ensure_ascii=False))
        return 0
    g, h = stats["game"], stats["history"]
    print(f"biomes {g['biomes']} · factions {g['factions']} · icons {g['icons']} · gates {len(g['gates'])}")
    for c in g["campaigns"]:
        print(f"campaign {c['title']}: {c['acts']} acts ({c['status']})")
    print("lines: " + " · ".join(f"{k} {v:,}" for k, v in sorted(stats["code_lines"].items(), key=lambda kv: -kv[1])))
    print(f"pytest files {g['test_files']}")
    print(f"commits {h['commits']:,} from {h['first_commit']} to {h['last_commit']}")
    for model, n in h["model_coauthor_trailers"].items():
        print(f"  {n:4d}  {model}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
