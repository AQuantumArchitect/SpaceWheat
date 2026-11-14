#!/usr/bin/env python3
"""Compare two kernel-golden JSON files written by tests/kernel_golden_dump.gd.

    python tests/kernel_golden_compare.py <golden.json> <candidate.json> [--exact | --tol 1e-10]

Record layout: key -> {"t": "d"|"a"|"i"|"b"|"s", "v": ..., "n": <orig length, thinned arrays>}.
"d" and "a" hold lowercase hex of little-endian IEEE-754 doubles.

--exact     every hex string must be byte-identical.
--tol X     absolute difference per double must be <= X (default 1e-10).
NaN at the same position in both files counts as equal; so do equal infinities.

Exit 0 on success, 1 on any mismatch, 2 on bad usage / unreadable input.
"""
from __future__ import annotations

import argparse
import json
import math
import struct
import sys


def decode(hexstr: str) -> list[float]:
    raw = bytes.fromhex(hexstr)
    if len(raw) % 8:
        raise ValueError("hex length is not a multiple of 8 bytes")
    return list(struct.unpack("<%dd" % (len(raw) // 8), raw))


def _same(a: float, b: float) -> bool:
    if math.isnan(a) and math.isnan(b):
        return True
    return a == b


def _diff(a: float, b: float) -> float:
    if math.isnan(a) and math.isnan(b):
        return 0.0
    if math.isnan(a) or math.isnan(b):
        return math.inf
    if a == b:
        return 0.0
    return abs(a - b)


def compare(golden: dict, cand: dict, exact: bool, tol: float):
    """Return (n_records, mismatches[(severity, key, message)], max_abs_diff)."""
    problems: list[tuple[float, str, str]] = []
    max_diff = 0.0
    for key in sorted(set(golden) | set(cand)):
        if key not in cand:
            problems.append((math.inf, key, "missing in candidate"))
            continue
        if key not in golden:
            problems.append((math.inf, key, "extra in candidate (absent from golden)"))
            continue
        g, c = golden[key], cand[key]
        if g.get("t") != c.get("t"):
            problems.append((math.inf, key, "type %r != %r" % (g.get("t"), c.get("t"))))
            continue
        t = g["t"]
        if t in ("i", "b", "s"):
            if g["v"] != c["v"]:
                problems.append((math.inf, key, "value %r != %r" % (g["v"], c["v"])))
            continue
        if g.get("n") != c.get("n"):
            problems.append((math.inf, key, "original length %r != %r" % (g.get("n"), c.get("n"))))
            continue
        try:
            gv, cv = decode(g["v"]), decode(c["v"])
        except (ValueError, struct.error) as exc:
            problems.append((math.inf, key, "undecodable: %s" % exc))
            continue
        if len(gv) != len(cv):
            problems.append((math.inf, key, "length %d != %d" % (len(gv), len(cv))))
            continue
        worst, worst_i = 0.0, -1
        for i, (a, b) in enumerate(zip(gv, cv)):
            d = _diff(a, b)
            if d > worst:
                worst, worst_i = d, i
        if worst > max_diff and not math.isinf(worst):
            max_diff = worst
        if exact:
            if g["v"] != c["v"]:
                if worst_i >= 0:
                    msg = "bytes differ; worst abs diff %.3e at index %d (%r vs %r)" % (
                        worst, worst_i, gv[worst_i], cv[worst_i])
                else:
                    msg = "bytes differ with equal values (NaN payload or signed zero)"
                problems.append((worst if worst_i >= 0 else 0.0, key, msg))
        elif worst > tol:
            problems.append((worst, key, "abs diff %.3e > tol %.1e at index %d (%r vs %r)" % (
                worst, tol, worst_i, gv[worst_i], cv[worst_i])))
    return len(golden), problems, max_diff


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("golden")
    ap.add_argument("candidate")
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument("--exact", action="store_true", help="demand identical bytes")
    mode.add_argument("--tol", type=float, default=1e-10, help="absolute tolerance (default 1e-10)")
    args = ap.parse_args(argv)
    try:
        with open(args.golden, encoding="utf-8") as f:
            golden = json.load(f)
        with open(args.candidate, encoding="utf-8") as f:
            cand = json.load(f)
    except (OSError, ValueError) as exc:
        print("cannot read input: %s" % exc, file=sys.stderr)
        return 2
    n, problems, max_diff = compare(golden, cand, args.exact, args.tol)
    mode_s = "exact" if args.exact else "tol %g" % args.tol
    print("%d records, %d mismatches, max abs diff %.3e (%s)" % (n, len(problems), max_diff, mode_s))
    problems.sort(key=lambda p: (-p[0], p[1]))
    for _, key, msg in problems[:20]:
        print("  MISMATCH %s: %s" % (key, msg))
    if len(problems) > 20:
        print("  ... and %d more" % (len(problems) - 20))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
