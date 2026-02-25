#!/usr/bin/env python3
"""Shared JSON I/O helpers for milk hunt tools."""
import json
from pathlib import Path
from typing import Any, List


def write_json(path: Path, data: Any, indent: int = 2) -> None:
    """Write data as pretty-printed JSON with a trailing newline."""
    path.write_text(json.dumps(data, ensure_ascii=False, indent=indent) + "\n", encoding="utf-8")


def read_json(path: Path) -> Any:
    """Read and parse a JSON file. Raises on missing file or parse error."""
    return json.loads(path.read_text(encoding="utf-8"))


def read_json_safe(path: Path, default: Any = None) -> Any:
    """Read and parse a JSON file, returning default on any error."""
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return default


def read_jsonl(path: Path) -> List[Any]:
    """Read a newline-delimited JSON file, skipping malformed lines."""
    out: List[Any] = []
    try:
        for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
            raw = raw.strip()
            if not raw:
                continue
            try:
                out.append(json.loads(raw))
            except json.JSONDecodeError:
                out.append({"ok": False, "error": "bad_json_line"})
    except OSError:
        pass
    return out
