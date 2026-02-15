#!/usr/bin/env python3
"""Emoji registry loader — single source of truth for all resource emojis.

Loads from ``config/emoji_registry.json`` and provides typed accessors.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List, Set

_REGISTRY_PATH = Path(__file__).resolve().parent / "config" / "emoji_registry.json"
_CACHE: Dict[str, Any] | None = None


def _load() -> Dict[str, Any]:
    global _CACHE
    if _CACHE is None:
        _CACHE = json.loads(_REGISTRY_PATH.read_text(encoding="utf-8"))
    return _CACHE


def all_emojis() -> List[str]:
    """Return all known resource emojis."""
    return list(_load()["resources"].keys())


def starter_emojis() -> List[str]:
    """Return emojis that appear in starter saves (starter=True)."""
    resources = _load()["resources"]
    return [e for e, info in resources.items() if info.get("starter")]


def emoji_name(emoji: str) -> str:
    """Return the canonical name for an emoji, or '' if unknown."""
    return _load()["resources"].get(emoji, {}).get("name", "")


def emoji_category(emoji: str) -> str:
    """Return the category for an emoji, or '' if unknown."""
    return _load()["resources"].get(emoji, {}).get("category", "")


def emojis_by_category(category: str) -> List[str]:
    """Return all emojis in a given category."""
    resources = _load()["resources"]
    return [e for e, info in resources.items() if info.get("category") == category]


def emojis_by_role(role: str) -> List[str]:
    """Return all emojis with a given role."""
    resources = _load()["resources"]
    return [e for e, info in resources.items() if info.get("role") == role]


def known_emoji_set() -> Set[str]:
    """Return a set of all known emojis for validation."""
    return set(_load()["resources"].keys())


def categories() -> List[str]:
    """Return the list of emoji categories."""
    return list(_load().get("categories", []))
