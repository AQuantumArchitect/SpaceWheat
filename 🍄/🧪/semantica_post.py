#!/usr/bin/env python3
"""semantica_post.py — feed SpaceWheat's own test/play runs into the hearth.

The hearth is umweltd (http://100.72.177.15:7073), the shared belief field
the yurt fleet posts claims/walls/referees into. This module is SpaceWheat's
own membrane adapter — dependency-free, importable, and CLI-usable — built to
the wire laws proven live by hearth_lib.sh (succession stack, 2026-07-16):

  1. yurt.env is CRLF (Windows-authored). The API key MUST have \\r stripped
     or the header block corrupts SILENTLY: auth still passes but the request
     body is lost, giving a 200 with {"appended": 0}. Never trust a 200 alone
     — always assert appended == 1.
  2. Event meta MUST be a JSON *string* (it is bound straight into sqlite),
     not a JSON object. Passing an object gives an opaque 500.
  3. Unreachable hearth is reported honestly: nonzero exit, no fake success.
     Callers (harness adapters) must treat that as "the field is dark", not
     "the run failed" — see SEMANTICA_POST wiring in player_seat.py / suite
     runners, which are strictly opt-in and never gate a real test result.

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

Env overrides (all optional, mirror hearth_lib.sh):
    HEARTH_URL   default http://100.72.177.15:7073
    YURT_ENV     default /mnt/c/Users/Luke Spooner/ws-win/yurt/config/yurt.env
                 (path to the CRLF yurt.env carrying UMWELTD_API_KEY)
    HEARTH_API_KEY  bypasses YURT_ENV entirely if set (still \\r-stripped)
"""
from __future__ import annotations

import datetime
import json
import os
import sys
import urllib.error
import urllib.request

HEARTH_URL_DEFAULT = "http://100.72.177.15:7073"
YURT_ENV_DEFAULT = "/mnt/c/Users/Luke Spooner/ws-win/yurt/config/yurt.env"


class HearthDark(RuntimeError):
    """The hearth is unreachable, misconfigured, or refused the post.

    Callers treat this as "the field is dark" — never fake success, never
    let a membrane hiccup masquerade as (or gate) a real test result.
    """


def _hearth_url() -> str:
    return os.environ.get("HEARTH_URL", HEARTH_URL_DEFAULT).rstrip("/")


def _hearth_key() -> str:
    """Load the API key the same way hearth_lib.sh does.

    LAW #1: yurt.env is CRLF. Strip \\r (and stray \\n/spaces) or the header
    block corrupts silently — auth passes, body is lost, appended=0 on a 200.
    """
    override = os.environ.get("HEARTH_API_KEY")
    if override:
        return override.strip("\r\n ")
    path = os.environ.get("YURT_ENV", YURT_ENV_DEFAULT)
    try:
        with open(path, "r", encoding="utf-8", newline="") as fh:
            for line in fh:
                if line.startswith("UMWELTD_API_KEY"):
                    _, _, rest = line.partition("=")
                    return rest.strip("\r\n ")
    except OSError as exc:
        raise HearthDark(f"cannot read yurt.env at {path}: {exc}") from exc
    raise HearthDark(f"UMWELTD_API_KEY not found in {path}")


def post(sensor: str, value: float, meta: dict | None = None,
         world: str = "hive-ops", timeout: float = 30.0) -> int:
    """Post one event to the hearth. Returns `appended` (int) on success.

    Raises HearthDark on any failure — unreachable hearth, bad key, non-200,
    or a reachable-but-rejected post (appended != 1). Never returns a lie.
    """
    key = _hearth_key()
    meta = meta if meta is not None else {}
    meta_str = json.dumps(meta, ensure_ascii=False)  # LAW #2: string, not object
    ts = datetime.datetime.now(datetime.timezone.utc).isoformat()
    body = json.dumps({"events": [[ts, sensor, float(value), meta_str]]}).encode("utf-8")
    url = f"{_hearth_url()}/worlds/{world}/events"
    req = urllib.request.Request(
        url, data=body, method="POST",
        headers={"Content-Type": "application/json", "X-API-Key": key},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            out = json.loads(resp.read())
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError,
            OSError, json.JSONDecodeError) as exc:
        raise HearthDark(f"hearth unreachable/errored posting {sensor}: {exc}") from exc
    n = out.get("appended")
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
