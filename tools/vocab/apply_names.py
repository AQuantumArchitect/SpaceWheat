#!/usr/bin/env python3
"""Apply tools/vocab/renames.json to factions.json and icons.json, and write the
rename table (docs/vocab/RENAMES.md).

    python tools/vocab/apply_names.py            # apply + write the table
    python tools/vocab/apply_names.py --check    # exit 1 if anything would change

Idempotent: the table records each pair's names as they were before the first
application (kept in renames.json's "before" block once written), so a rerun
reproduces the same table.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FACTIONS = ROOT / "Core/Factions/data/factions.json"
ICONS = ROOT / "Core/Factions/data/icons.json"
RENAMES = ROOT / "tools/vocab/renames.json"
TABLE = ROOT / "docs/vocab/RENAMES.md"
VS = "️"


def n(e) -> str:
    return str(e).replace(VS, "")


def pair_of(rec) -> str:
    return "%s/%s" % (n(rec.get("pole_0", "")), n(rec.get("pole_1", "")))


def dump(obj) -> str:
    return json.dumps(obj, indent=2, ensure_ascii=False) + "\n"


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args(argv)
    spec = json.loads(RENAMES.read_text(encoding="utf-8"))
    factions = json.loads(FACTIONS.read_text(encoding="utf-8"))
    icons = json.loads(ICONS.read_text(encoding="utf-8"))
    want = {r["pair"]: r for r in spec["renames"]}
    if len(want) != len(spec["renames"]):
        print("renames.json lists a pair twice", file=sys.stderr)
        return 1

    before = spec.get("before") or {}
    record_before = not before
    seen = set()
    for f in factions:
        for ic in f.get("icons", []) or []:
            p = pair_of(ic)
            if p in want:
                seen.add(p)
                if record_before:
                    b = before.setdefault(p, {"factions": [], "icons": "", "owners": []})
                    b["factions"].append(str(ic.get("name", "")))
                    b["owners"].append(f["name"])
                ic["name"] = want[p]["name"]
    for e in icons:
        p = pair_of(e)
        if p in want:
            seen.add(p)
            if record_before:
                before.setdefault(p, {"factions": [], "icons": "", "owners": []})["icons"] = str(e.get("name", ""))
            e["name"] = want[p]["name"]
    missing = sorted(set(want) - seen)
    if missing:
        print("pairs in renames.json found nowhere: %s" % missing, file=sys.stderr)
        return 1

    new_f, new_i = dump(factions), dump(icons)
    changed = new_f != FACTIONS.read_text(encoding="utf-8") or new_i != ICONS.read_text(encoding="utf-8")
    if args.check:
        if changed:
            print("factions.json / icons.json differ from renames.json; run apply_names.py")
            return 1
        return 0
    FACTIONS.write_text(new_f, encoding="utf-8")
    ICONS.write_text(new_i, encoding="utf-8")
    if record_before:
        spec["before"] = before
        RENAMES.write_text(dump(spec), encoding="utf-8")

    rows = []
    for p, r in want.items():
        b = before.get(p, {})
        fac = sorted(set(b.get("factions", [])))
        old = set(fac) | ({b["icons"]} if b.get("icons") else set())
        if old == {r["name"]}:
            continue
        rows.append((r["name"], p, "; ".join(fac) or "(none)", b.get("icons") or "(no entry)",
                     "; ".join(dict.fromkeys(b.get("owners", []))), r["why"]))
    rows.sort(key=lambda x: x[0].lower())
    L = ["# Icon renames, 2026-11-16", "",
         "Every icon now has one name, the same in `factions.json` and `icons.json`, and unique",
         "across the vocabulary. This table lists every pair whose name changed in at least one",
         "file. Sorted by the new name. The data is `tools/vocab/renames.json`; regenerate with",
         "`python tools/vocab/apply_names.py`. Pairs are north/south: the south pole is what the",
         "word provides.", "",
         "Rule of choice, in order: keep a name that was already unique and consistent; where",
         "the two files disagreed, pick by meaning (the `icons.json` name usually won because it",
         "was the specific one: the faction listings had been filled with a few shared generic",
         "names); where pairs shared a name, the pair that best fits it keeps it and the others",
         "get their own.", "",
         "%d pairs renamed." % len(rows), "",
         "| New name | Pair | factions.json (before) | icons.json (before) | Owner | Reason |",
         "|---|---|---|---|---|---|"]
    L += ["| **%s** | %s | %s | %s | %s | %s |" % row for row in rows]
    TABLE.parent.mkdir(parents=True, exist_ok=True)
    TABLE.write_text("\n".join(L) + "\n", encoding="utf-8")
    print("applied %d renames; table: %s" % (len(rows), TABLE.relative_to(ROOT)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
