#!/usr/bin/env python3
"""World state loader for milk hunt seeding.

A world state describes "what the world IS": starting resources, biomes,
known icons, and optional economy overrides (action costs, reward budgets,
production params).
"""
from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, List, Optional

from milk_hunt_runtime_config import load_json_config


_CONFIG_DIR = Path(__file__).resolve().parent / "config" / "world_state"


def load_world_state(path: str | Path) -> Dict[str, Any]:
    """Load a world state dict from a JSON file.

    Returns the parsed dict (may be empty if the file is missing/invalid).
    """
    p = Path(path)
    data = load_json_config(p)
    if data:
        data.setdefault("name", p.stem)
        data["_path"] = str(p)
    return data


def get_world_state(name: str) -> Dict[str, Any]:
    """Look up a world state by short name (e.g. "balanced_survival").

    Searches config/world_state/{name}.json.
    Raises ValueError if not found.
    """
    p = _CONFIG_DIR / f"{name}.json"
    if not p.exists():
        available = list_world_state_names()
        raise ValueError(
            f"unknown world state '{name}'. available: {', '.join(available)}"
        )
    return load_world_state(p)


def list_world_state_names() -> List[str]:
    """Return sorted names of all world state configs found on disk."""
    if not _CONFIG_DIR.is_dir():
        return []
    return sorted(p.stem for p in _CONFIG_DIR.glob("*.json"))
