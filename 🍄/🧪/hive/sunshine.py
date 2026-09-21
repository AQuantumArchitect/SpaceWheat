"""Itch conversion sensors for the hive. Counts or honest dark. No $."""
from __future__ import annotations

import json
import os
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]


def flake_path(explicit: str | Path | None = None) -> Path | None:
    if explicit:
        p = Path(explicit)
        return p if p.is_file() else None
    env = str(os.environ.get("SW_SUNSHINE_FLAKE") or "").strip()
    if env:
        p = Path(env)
        if p.is_file():
            return p
    local = HERE / "sunshine.json"
    if local.is_file():
        return local
    return None


def load_flake(path: str | Path | None = None) -> dict | None:
    p = flake_path(path)
    if p is None:
        return None
    try:
        row = json.loads(p.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    return row if isinstance(row, dict) else None


def _counted(title: dict) -> bool:
    return any(
        title.get(k) is not None for k in ("views", "downloads", "purchases")
    )


def sun_ready(flake: dict | None) -> bool:
    if not flake:
        return False
    if str(flake.get("sun") or "") != "ready":
        return False
    titles = flake.get("titles") or []
    return any(isinstance(t, dict) and t.get("page") == "ready" and _counted(t)
               for t in titles)


def prefer_web(flake: dict | None) -> bool:
    if not flake:
        return False
    for t in flake.get("titles") or []:
        if not isinstance(t, dict):
            continue
        if str(t.get("named") or "").lower() == "spacewheat":
            dl = t.get("downloads")
            return isinstance(dl, int) and dl > 0
    return False


def wall_has_path(row: dict) -> bool:
    report = str(row.get("report") or "")
    if not report.strip():
        return False
    lower = report.lower()
    tried = "tried" in lower or bool(row.get("tried"))
    saw = "saw" in lower or bool(row.get("saw"))
    expected = "expected" in lower or bool(row.get("expected"))
    repaired = "repaired" in lower or bool(row.get("escalation"))
    return tried and saw and (expected or repaired)


def gates(flake: dict | None, walls: list | None = None) -> list[str]:
    """Honesty gates. Missing flake is dark, not a failure."""
    fails: list[str] = []
    if flake is None:
        return fails
    blob = json.dumps(flake, ensure_ascii=False)
    if "https://" in blob.lower():
        fails.append("url")
    if flake.get("earning_usd") is not None:
        fails.append("earning_usd")
    if str(flake.get("sun") or "") == "ready" and not sun_ready(flake):
        fails.append("sun-claimed-dark")
    for row in walls or []:
        if isinstance(row, dict) and not wall_has_path(row):
            fails.append("wall-no-path")
            break
    return fails
