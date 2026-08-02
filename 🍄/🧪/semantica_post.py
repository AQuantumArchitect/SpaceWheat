#!/usr/bin/env python3
"""semantica_post.py — feed SpaceWheat's own test/play runs into the hearth.

The hearth is umweltd (http://100.72.177.15:7073), the shared belief field
the yurt fleet posts claims/walls/referees into. This module is SpaceWheat's
own membrane adapter — dependency-free, importable, and CLI-usable.

The wire itself (base URL, the CRLF-stripped API key, request/response, the
HearthDark error) is NOT owned here: it is owned by hearth_client.py, the one
authority all three hearth callers in this repo share. Those names are
re-exported below so importers of this module keep working unchanged. What
this module still owns is the POST-an-event payload law:

  LAW #2: event meta MUST be a JSON *string* (it is bound straight into
  sqlite), not a JSON object. Passing an object gives an opaque 500.

  And its consequence, LAW #1's tell: never trust a 200 alone — a CRLF in the
  key gives a 200 with {"appended": 0}. Always assert appended == 1
  (hearth_client.py:_hearth_key owns the strip; this owns the assertion).

  LAW #3: an unreachable hearth is reported honestly — HearthDark, nonzero
  exit, no fake success. Callers (harness adapters) must treat that as "the
  field is dark", not "the run failed" — see SEMANTICA_POST wiring in
  player_seat.py:268 / tests/conftest.py:33, which are strictly opt-in and
  never gate a real test result.

Usage as a library:
    from semantica_post import post
    n = post("spacewheat_referee", 0.92, {"suite": "pytest", "passed": 131,
                                           "failed": 0}, world="project-membrane")
    # raises RuntimeError unless the hearth confirms appended == 1

Usage as a CLI:
    python3 semantica_post.py <world> <sensor> <value> '<meta-json>'
    # exit 0 + "[hearth] <sensor>=<value> appended=1" on success
    # exit 1 on a reachable-but-rejected post (appended != 1)
    # exit 2 on an unreachable/errored hearth ("the field is dark")

Env overrides (HEARTH_URL / YURT_ENV / HEARTH_API_KEY): see hearth_client.py.
"""
from __future__ import annotations

import datetime
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
# Re-exported, not re-implemented: importers (register_spacewheat_world.py,
# scripts/cognifold.sh, tests/conftest.py, witness_hearth.py) have always
# reached for these through this module, and still can.
from hearth_client import (  # noqa: E402,F401
    HEARTH_URL_DEFAULT, YURT_ENV_DEFAULT, HearthDark, _hearth_key, _hearth_url, request,
)


def post(sensor: str, value: float, meta: dict | None = None,
         world: str = "hive-ops", timeout: float = 30.0) -> int:
    """Post one event to the hearth. Returns `appended` (int) on success.

    Raises HearthDark on any failure — unreachable hearth, bad key, non-200,
    or a reachable-but-rejected post (appended != 1). Never returns a lie.
    """
    meta_str = json.dumps(meta if meta is not None else {},
                          ensure_ascii=False)  # LAW #2: string, not object
    ts = datetime.datetime.now(datetime.timezone.utc).isoformat()
    _, out = request("POST", f"/worlds/{world}/events",
                     {"events": [[ts, sensor, float(value), meta_str]]},
                     timeout=timeout)
    n = out.get("appended") if isinstance(out, dict) else None
    if n != 1:
        raise HearthDark(
            f"hearth rejected {sensor} (appended={n!r}, resp={out!r}) — "
            f"LAW #1 signature if this is a 200 with appended=0: check CRLF key stripping")
    return n


def main(argv: list[str]) -> int:
    if len(argv) != 5:
        print(__doc__)
        return 2
    _, world, sensor, value_s, meta_s = argv
    try:
        value = float(value_s)
        meta = json.loads(meta_s) if meta_s.strip() else {}
    except (ValueError, json.JSONDecodeError) as exc:
        print(f"[hearth] bad args: {exc}", file=sys.stderr)
        return 2
    try:
        n = post(sensor, value, meta, world=world)
    except HearthDark as exc:
        print(f"[hearth] DARK: {exc}", file=sys.stderr)
        return 2
    print(f"[hearth] {sensor}={value} appended={n}")
    return 0 if n == 1 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
