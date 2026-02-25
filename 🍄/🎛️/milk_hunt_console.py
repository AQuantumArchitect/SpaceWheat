#!/usr/bin/env python3
"""Shared console/log profile helpers for milk-hunt tooling."""

from __future__ import annotations

import os
from typing import Any, Optional


_PROFILE_ORDER = {
    "quiet": 1,
    "normal": 2,
    "debug": 3,
    "trace": 4,
    "test": 4,
}

_CHANNEL_ORDER = {
    "error": 0,
    "warn": 0,
    "info": 1,
    "detail": 2,
    "trace": 3,
}


def normalize_console_profile(raw: Optional[str], default: str = "quiet") -> str:
    text = (raw or "").strip().lower()
    if text in _PROFILE_ORDER:
        return text
    return default


def resolve_console_profile(
    cli_value: Optional[str],
    cfg: Optional[dict[str, Any]] = None,
    cfg_key: str = "console_profile",
    env_key: str = "MILK_HUNT_CONSOLE_PROFILE",
    default: str = "quiet",
) -> str:
    if cli_value:
        return normalize_console_profile(cli_value, default)
    if cfg:
        cfg_raw = cfg.get(cfg_key)
        if isinstance(cfg_raw, str) and cfg_raw.strip():
            return normalize_console_profile(cfg_raw, default)
    env_raw = os.environ.get(env_key, "")
    if env_raw:
        return normalize_console_profile(env_raw, default)
    return normalize_console_profile(default, default)


def default_wait_progress_seconds(profile: str) -> float:
    p = normalize_console_profile(profile, "quiet")
    if p == "quiet":
        return 30.0
    if p == "normal":
        return 15.0
    if p == "debug":
        return 5.0
    return 2.0


def default_listener_stdout(profile: str) -> str:
    p = normalize_console_profile(profile, "quiet")
    if p == "quiet":
        return "null"
    if p in {"normal", "debug"}:
        return "file"
    return "pipe"


def default_rig_log_profile(profile: str) -> str:
    p = normalize_console_profile(profile, "quiet")
    if p in {"quiet", "normal", "debug", "trace", "test"}:
        return p
    return "quiet"


class Console:
    def __init__(self, profile: str = "quiet") -> None:
        self.profile = normalize_console_profile(profile, "quiet")
        self._level = _PROFILE_ORDER[self.profile]

    def allows(self, channel: str) -> bool:
        lvl = _CHANNEL_ORDER.get(str(channel).strip().lower(), 1)
        return lvl <= self._level

    def log(self, msg: str, channel: str = "info") -> None:
        if self.allows(channel):
            print(msg, flush=True)
