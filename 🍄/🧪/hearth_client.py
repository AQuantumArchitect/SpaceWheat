#!/usr/bin/env python3
"""hearth_client — the ONE place SpaceWheat speaks HTTP to umweltd.

The hearth is umweltd (http://100.72.177.15:7073), the shared belief field the
yurt fleet posts claims/walls/referees into. Three callers used to each carry
their own copy of the wire: semantica_post.py built its own Request,
register_spacewheat_world.py had a private `_call()`, and scripts/cognifold.sh
resolved the key with inline python and re-hardcoded the base URL next to two
curls. Every copy was a place a wire law could rot out of sync. There is now
one copy, and it is here.

The laws are the ones proven live by hearth_lib.sh (succession stack,
2026-07-16) and carried since by semantica_post.py:

  1. yurt.env is CRLF (Windows-authored). The API key MUST have \\r stripped
     or the header block corrupts SILENTLY: auth still passes but the request
     body is lost, giving a 200 with {"appended": 0}. Never trust a 200 alone.
     Owned by _hearth_key() below.
  2. Event meta MUST be a JSON *string* (it is bound straight into sqlite),
     not a JSON object. Passing an object gives an opaque 500. That law is
     about payload shape, not the wire, so it stays with the poster
     (semantica_post.py:post).
  3. Unreachable hearth is reported honestly: HearthDark, nonzero exit, no
     fake success. `HearthDark.status` is set IFF umweltd actually answered —
     that flag is the only way a caller can tell "umweltd refused me and said
     why" (read `.body`) from "the field is dark". Collapsing those two into
     one message is exactly the lie this repo keeps hunting.

Usage as a library:
    from hearth_client import HearthDark, request
    status, worlds = request("GET", "/worlds", timeout=20)

Usage as a CLI (this is what scripts/cognifold.sh consumes):
    python3 hearth_client.py key                     # the \\r-stripped API key
    python3 hearth_client.py worlds                  # what the hearth serves
    python3 hearth_client.py endpoint <world> <leaf> # verify + print its URL
    # exit 0 on success, exit 2 when the field is dark or the leaf is unserved

Env overrides (all optional, mirror hearth_lib.sh):
    HEARTH_URL   default http://100.72.177.15:7073
    YURT_ENV     default /mnt/c/Users/Luke Spooner/ws-win/yurt/config/yurt.env
                 (path to the CRLF yurt.env carrying UMWELTD_API_KEY)
    HEARTH_API_KEY  bypasses YURT_ENV entirely if set (still \\r-stripped)
"""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request

HEARTH_URL_DEFAULT = "http://100.72.177.15:7073"
YURT_ENV_DEFAULT = "/mnt/c/Users/Luke Spooner/ws-win/yurt/config/yurt.env"


class HearthDark(RuntimeError):
    """The hearth is unreachable, misconfigured, or refused the call.

    Callers treat this as "the field is dark" — never fake success, never let
    a membrane hiccup masquerade as (or gate) a real test result.

    LAW #3: `status` is None when nothing answered and an HTTP code when
    umweltd did answer; `body` then carries its refusal text, which is the
    useful part (the spec gate explains itself there).
    """

    def __init__(self, message: str, status: int | None = None, body: str = ""):
        super().__init__(message)
        self.status = status
        self.body = body


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


def request(method: str, path: str, body: dict | None = None,
            timeout: float = 90.0) -> tuple[int, object]:
    """One HTTP call to the hearth. Returns (status, parsed JSON or None).

    Raises HearthDark on ANY failure — bad key, unreachable daemon, refusal,
    non-JSON answer. Never returns a lie. See LAW #3 on HearthDark.status for
    how to tell a refusal apart from a dark field.
    """
    data = json.dumps(body).encode("utf-8") if body is not None else None
    headers = {"X-API-Key": _hearth_key()}  # LAW #1 lives in _hearth_key
    if data is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(f"{_hearth_url()}{path}", data=data,
                                 method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            status, raw = resp.status, resp.read()
    except urllib.error.HTTPError as exc:  # answered, and said no — keep its words
        raise HearthDark(f"hearth refused {method} {path} ({exc.code})",
                         status=exc.code,
                         body=exc.read().decode("utf-8", "replace")[:2000]) from exc
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        raise HearthDark(f"hearth unreachable on {method} {path}: {exc}") from exc
    try:
        return status, json.loads(raw or b"null")
    except json.JSONDecodeError as exc:
        raise HearthDark(f"hearth answered {method} {path} ({status}) with non-JSON: {exc}",
                         status=status,
                         body=raw.decode("utf-8", "replace")[:2000]) from exc


def worlds() -> list[dict]:
    """Every world umweltd is serving right now. Read-only."""
    _, out = request("GET", "/worlds", timeout=20)
    return list(out or [])


def endpoint_url(world: str, leaf: str, timeout: float = 20.0) -> str:
    """Verify `world` really serves `leaf`, and return that absolute URL.

    Probing here means a caller (the cognifold instrument) fails loudly at the
    door instead of opening a window that is empty for a reason the viewer
    cannot distinguish from "a very calm world".
    """
    path = f"/worlds/{world}/{leaf}"
    request("GET", path, timeout=timeout)
    return f"{_hearth_url()}{path}"


def main(argv: list[str]) -> int:
    cmd = argv[1] if len(argv) > 1 else ""
    try:
        if cmd == "key":
            print(_hearth_key())
        elif cmd == "worlds" and len(argv) == 2:
            for w in worlds():
                print(f"  {w['name']:20s} {'live' if w.get('running') else 'DOWN'}")
        elif cmd == "endpoint" and len(argv) == 4:
            print(endpoint_url(argv[2], argv[3]))
        else:
            print(__doc__)
            return 2
    except HearthDark as exc:
        if cmd == "endpoint" and exc.status is not None:
            # It answered — so the field is lit and THIS world/leaf is the gap.
            print(f"[hearth] '{argv[2]}' is not serving {argv[3]} ({exc.status})",
                  file=sys.stderr)
        else:
            print(f"[hearth] DARK: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
