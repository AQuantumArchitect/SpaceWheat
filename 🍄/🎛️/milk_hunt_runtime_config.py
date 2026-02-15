#!/usr/bin/env python3
import json
from pathlib import Path
from typing import Any, Dict


def load_json_config(path: Path) -> Dict[str, Any]:
    if not path.exists():
        return {}
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    if isinstance(raw, dict):
        return raw
    return {}


def get_cfg_str(cfg: Dict[str, Any], key: str) -> str | None:
    val = cfg.get(key)
    if isinstance(val, str):
        return val
    return None


def get_cfg_int(cfg: Dict[str, Any], key: str) -> int | None:
    val = cfg.get(key)
    if isinstance(val, bool):
        return int(val)
    if isinstance(val, int):
        return val
    if isinstance(val, float):
        return int(val)
    if isinstance(val, str) and val.strip():
        try:
            return int(float(val.strip()))
        except ValueError:
            return None
    return None


def get_cfg_float(cfg: Dict[str, Any], key: str) -> float | None:
    val = cfg.get(key)
    if isinstance(val, (int, float)):
        return float(val)
    if isinstance(val, str) and val.strip():
        try:
            return float(val.strip())
        except ValueError:
            return None
    return None


def get_cfg_bool(cfg: Dict[str, Any], key: str) -> bool | None:
    val = cfg.get(key)
    if isinstance(val, bool):
        return val
    if isinstance(val, (int, float)):
        return bool(val)
    if isinstance(val, str):
        normalized = val.strip().lower()
        if normalized in {"1", "true", "yes", "on"}:
            return True
        if normalized in {"0", "false", "no", "off"}:
            return False
    return None


def get_cfg_dict(cfg: Dict[str, Any], key: str) -> Dict[str, Any] | None:
    val = cfg.get(key)
    if isinstance(val, dict):
        return val
    return None


def get_cfg_list(cfg: Dict[str, Any], key: str) -> list | None:
    val = cfg.get(key)
    if isinstance(val, list):
        return val
    return None
