#!/usr/bin/env python3
"""Helpers for resolving canonical profile-save paths."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, Optional

from milk_hunt_paths import APP_NAME, user_dir, xdg_root


def user_root_path() -> Path:
    return user_dir(xdg=xdg_root(), app_name=APP_NAME)


def resolve_user_path(path: str) -> Path:
    if path.startswith("user://"):
        suffix = path[len("user://") :]
        return user_root_path() / suffix
    return Path(path).expanduser().resolve()


def to_user_uri(path: Path) -> str:
    base = user_root_path().resolve()
    resolved = path.resolve()
    try:
        rel = resolved.relative_to(base)
        rel_str = rel.as_posix()
        return "user://%s" % rel_str
    except ValueError:
        return str(resolved)


def default_registry_uri() -> str:
    return "user://saves/profiles/index.json"


def default_registry_path() -> Path:
    return resolve_user_path(default_registry_uri())


def load_registry(index_path: Optional[str] = None) -> Dict[str, str]:
    path = resolve_user_path(index_path) if index_path else default_registry_path()
    if not path.exists():
        return {}
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    profiles = raw.get("profiles", {})
    if not isinstance(profiles, dict):
        return {}
    out: Dict[str, str] = {}
    for key, value in profiles.items():
        if isinstance(key, str) and isinstance(value, str) and key:
            out[key] = value
    return out


def get_profile_save(profile_name: str, index_path: Optional[str] = None) -> Optional[str]:
    return load_registry(index_path).get(profile_name)


def get_profile_name_for_save(save_spec: str, index_path: Optional[str] = None) -> Optional[str]:
    target = (save_spec or "").strip()
    if not target:
        return None
    for name, mapped in load_registry(index_path).items():
        if mapped == target:
            return name
    return None


def resolve_profile_save_spec(spec: str, index_path: Optional[str] = None) -> str:
    s = (spec or "").strip()
    if not s:
        return s
    mapped = get_profile_save(s, index_path)
    if mapped:
        return mapped
    return s
