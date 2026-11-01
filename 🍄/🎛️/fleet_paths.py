"""Where the fleet's sibling trees live on the owner's machine.

The playtest fleet runs alongside private sibling repos (the yurt world specs,
yurt-sync's shared vitals and run results). They sit in one Windows-side
workspace folder, reached from WSL under /mnt/c/Users/<you>/ws-win.

One resolver, so no script spells a personal path:

    SW_FLEET_HOME   the ws-win folder (overrides discovery)

Without it, the first /mnt/c/Users/*/ws-win that exists is used, then
~/ws-win. Off the owner's machine nothing resolves, and callers that need
these trees skip (tests) or report the path they looked in (tools).
"""
from __future__ import annotations

import os
from pathlib import Path


def fleet_home() -> Path:
    env = os.environ.get("SW_FLEET_HOME")
    if env:
        return Path(env)
    users = Path("/mnt/c/Users")
    try:
        for p in sorted(users.glob("*/ws-win")):
            if p.is_dir():
                return p
    except OSError:
        pass
    return Path.home() / "ws-win"


def fleet_path(*parts: str) -> Path:
    """A path under the fleet home, e.g. fleet_path("yurt", "worlds")."""
    return fleet_home().joinpath(*parts)


def fleet_relative(path: str | Path) -> str:
    """`path` relative to the fleet home when it is inside it (for provenance
    records that get committed), else the path unchanged."""
    p = Path(path)
    try:
        return p.resolve().relative_to(fleet_home().resolve()).as_posix()
    except (ValueError, OSError):
        return str(p)


def to_windows(path: str | Path) -> str:
    """/mnt/c/Users/x/ws-win/... -> C:\\Users\\x\\ws-win\\... (for services
    that run on the Windows side). Paths not under /mnt/<drive>/ pass through."""
    parts = Path(path).as_posix().split("/")
    if len(parts) > 3 and parts[1] == "mnt" and len(parts[2]) == 1:
        return parts[2].upper() + ":\\" + "\\".join(parts[3:])
    return str(path)
