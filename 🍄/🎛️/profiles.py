#!/usr/bin/env python3
"""Unified profile management for SpaceWheat.

Merges the functionality of:
  - milk_hunt_profiles.py (load profiles by name)
  - profile_save_registry.py (profile-save path mapping)
  - milk_hunt_world_state.py (world state loading)

Single import for all profile operations.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List, Optional, Set

from milk_hunt_runtime_config import load_json_config
from milk_hunt_paths import APP_NAME, user_dir, xdg_root

HERE = Path(__file__).resolve().parent
WORLD_STATE_DIR = HERE / "config" / "world_state"
POLICY_WEIGHTS_DIR = HERE / "config" / "policy_weights"
STRATEGY_DIR = HERE / "config" / "strategy"


# ── Profile loading ─────────────────────────────────────────────────

ProfileDict = Dict[str, Any]


def load(name: str) -> ProfileDict:
    """Load a profile by name from config/world_state/{name}.json.

    Raises ValueError if not found.
    """
    path = WORLD_STATE_DIR / f"{name}.json"
    if not path.exists():
        available = list_names()
        raise ValueError(f"unknown profile '{name}'. available: {', '.join(available)}")
    data = load_json_config(path)
    if not data:
        raise ValueError(f"failed to load profile '{name}' from {path}")
    data.setdefault("name", name)
    return data


def list_names() -> List[str]:
    """List available profile names (stems of JSON files)."""
    if not WORLD_STATE_DIR.is_dir():
        return []
    return sorted(p.stem for p in WORLD_STATE_DIR.glob("*.json"))


def list_all() -> List[ProfileDict]:
    """Load all available profiles."""
    return [load(name) for name in list_names()]


def list_derby_names(lane: str, count: int = 5) -> List[str]:
    """Return derby profile names for a lane: derby_{lane}_1 .. derby_{lane}_{count}.

    Only returns names that actually exist on disk.
    """
    names = []
    for i in range(1, count + 1):
        name = f"derby_{lane}_{i}"
        if (WORLD_STATE_DIR / f"{name}.json").exists():
            names.append(name)
    return names


def list_derby_lanes() -> List[str]:
    """Discover available lanes from derby profile filenames."""
    lanes: Set[str] = set()
    for p in WORLD_STATE_DIR.glob("derby_*_*.json"):
        parts = p.stem.split("_")
        if len(parts) >= 3 and parts[0] == "derby":
            # derby_sonnet_1 -> lane = "sonnet"
            # derby_codex_mini_1 -> lane = "codex_mini" (handle multi-word lanes)
            try:
                int(parts[-1])  # last part must be a number
                lane = "_".join(parts[1:-1])
                lanes.add(lane)
            except ValueError:
                pass
    return sorted(lanes)


def exists(name: str) -> bool:
    """Check if a profile exists."""
    return (WORLD_STATE_DIR / f"{name}.json").exists()


# ── Policy weight loading ───────────────────────────────────────────

def load_policy_weights(name: str) -> Dict[str, float]:
    """Load policy weights override for a profile, or empty dict."""
    path = POLICY_WEIGHTS_DIR / f"{name}.json"
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {}


# ── Profile save registry ──────────────────────────────────────────

def _user_root() -> Path:
    return user_dir(xdg=xdg_root(), app_name=APP_NAME)


def _registry_path(index_path: Optional[str] = None) -> Path:
    if index_path:
        p = index_path.strip()
        if p.startswith("user://"):
            return _user_root() / p[len("user://"):]
        return Path(p).expanduser().resolve()
    return _user_root() / "saves" / "profiles" / "index.json"


def load_registry(index_path: Optional[str] = None) -> Dict[str, str]:
    """Load {profile_name: save_path} from the profile-save registry."""
    path = _registry_path(index_path)
    if not path.exists():
        return {}
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    profiles = raw.get("profiles", {})
    if not isinstance(profiles, dict):
        return {}
    return {k: v for k, v in profiles.items()
            if isinstance(k, str) and isinstance(v, str) and k}


def get_save_path(profile_name: str, index_path: Optional[str] = None) -> Optional[str]:
    """Get the canonical save path for a profile name."""
    return load_registry(index_path).get(profile_name)


def resolve_save_spec(spec: str, index_path: Optional[str] = None) -> str:
    """Resolve a profile-save spec: try as profile name first, fall back to raw path."""
    s = (spec or "").strip()
    if not s:
        return s
    mapped = get_save_path(s, index_path)
    return mapped if mapped else s
