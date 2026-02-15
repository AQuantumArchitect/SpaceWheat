#!/usr/bin/env python3
"""Milk hunt profiles — thin wrapper over world state JSON configs.

``get_profile(name)`` loads from ``config/world_state/{name}.json``.
"""
from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, List

from milk_hunt_runtime_config import load_json_config


ProfileDict = Dict[str, Any]

_WORLD_STATE_DIR = Path(__file__).resolve().parent / "config" / "world_state"


def get_profile(name: str) -> ProfileDict:
    """Return a profile dict by name from ``config/world_state/{name}.json``.

    Raises ``ValueError`` if no JSON file exists for *name*.
    """
    path = _WORLD_STATE_DIR / f"{name}.json"
    if not path.exists():
        available = sorted(list_profile_names())
        raise ValueError(f"unknown profile '{name}'. available: {', '.join(available)}")
    data = load_json_config(path)
    if not data:
        raise ValueError(f"failed to load profile '{name}' from {path}")
    data.setdefault("name", name)
    return data


def list_profile_names() -> List[str]:
    """List available profile names (stems of JSON files in world_state dir)."""
    if not _WORLD_STATE_DIR.is_dir():
        return []
    return sorted(p.stem for p in _WORLD_STATE_DIR.glob("*.json"))


def list_profiles() -> List[ProfileDict]:
    return [get_profile(name) for name in list_profile_names()]
