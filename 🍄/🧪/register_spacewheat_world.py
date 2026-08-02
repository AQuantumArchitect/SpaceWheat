#!/usr/bin/env python3
"""Register (or check) the `spacewheat-self` world on the hearth.

Split out as its own script because creating a world spawns a worker process on
the hearth machine — a live infrastructure change, and one the seat's permission
classifier blocks by design. Run it yourself:

    python3 🍄/🧪/register_spacewheat_world.py --check      # read-only: is it there?
    python3 🍄/🧪/register_spacewheat_world.py              # create it

The spec itself is already validated offline against umwelt's own gate
(`python -m umwelt.spec.validate world:SPEC --resolve-only` → ok), and the
sensor ids are proven to match the poster exactly (77 bindings, 77 emittable,
zero unmatched, zero unfed — tests/test_witness_hearth_surface.py).

To UNDO: stop the world, `rm -r` its hearth-state dir, then drop it from the
catalog. Order matters — umweltd crash-loops if a spec vanishes while the
hearth-state dir remains.
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hearth_client import HearthDark, request, worlds as list_worlds  # noqa: E402

WORLD = "spacewheat-self"
SPEC_PATH_WINDOWS = "C:\\Users\\Luke Spooner\\ws-win\\yurt\\worlds\\spacewheat_self"


# The supervisor's worst case is the spec gate (GATE_TIMEOUT_S=60) PLUS the
# worker spawn wait (SPAWN_TIMEOUT_S=60) = 120s before it can answer at all.
# A client timeout below that reports "DARK" for a server that is still working
# — which is exactly the lie this repo keeps hunting. Sit above the sum.
CREATE_TIMEOUT_S = 200.0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="read-only status, create nothing")
    args = ap.parse_args(argv)

    try:
        worlds = list_worlds()
    except HearthDark as exc:
        print(f"[hearth] DARK: {exc}", file=sys.stderr)
        return 2

    existing = next((w for w in worlds if w.get("name") == WORLD), None)
    if existing:
        print(json.dumps({"already_registered": True, **existing}, indent=1))
        return 0
    if args.check:
        print(json.dumps({"already_registered": False,
                          "worlds": sorted(w["name"] for w in worlds)}, indent=1))
        return 1

    print(f"[hearth] creating {WORLD} (gate + worker spawn; up to ~2 min)...",
          file=sys.stderr)
    t0 = time.monotonic()
    try:
        status, out = request("POST", "/worlds", {
            "name": WORLD, "spec": "world:SPEC", "spec_path": SPEC_PATH_WINDOWS},
            timeout=CREATE_TIMEOUT_S)
    except HearthDark as exc:
        # LAW #3 (hearth_client.py): .status set means it ANSWERED. umweltd gates
        # the spec before spawning, and its refusal text is the useful part —
        # that is a different event from nobody answering at all.
        if exc.status is not None:
            print(f"[hearth] refused ({exc.status}) after {time.monotonic()-t0:.0f}s: "
                  f"{exc.body}", file=sys.stderr)
            return 1
        print(f"[hearth] no answer after {time.monotonic()-t0:.0f}s: {exc}", file=sys.stderr)
        print("[hearth] the server may still be working — re-run with --check before "
              "retrying, so you never create it twice.", file=sys.stderr)
        return 2

    print(json.dumps({"created": True, "status": status,
                      "elapsed_s": round(time.monotonic() - t0, 1), **(out or {})}, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
