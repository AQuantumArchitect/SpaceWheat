#!/usr/bin/env python3
"""World state loader for milk hunt seeding.

A world state describes "what the world IS": starting resources, biomes,
known icons, and optional economy overrides (action costs, reward budgets,
production params).
"""
from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, Optional

from milk_hunt_runtime_config import load_json_config


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
