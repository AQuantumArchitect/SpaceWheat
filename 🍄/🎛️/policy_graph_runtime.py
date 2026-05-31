#!/usr/bin/env python3
"""Thin Python reader for canonical engine policy graph JSONL files."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, Iterable, List


HERE = Path(__file__).resolve().parent
POLICY_GRAPH_ROOT = HERE.parent.parent / "Core" / "Config" / "PolicyGraph"
DEFAULT_GRAPH_PATH = POLICY_GRAPH_ROOT / "default.jsonl"


def profile_graph_path(profile_id: str = "default", policy_kind: str = "ucb") -> Path:
    safe_profile = (profile_id or "default").strip() or "default"
    safe_kind = (policy_kind or "ucb").strip() or "ucb"
    candidates = [
        POLICY_GRAPH_ROOT / safe_kind / f"{safe_profile}.jsonl",
        POLICY_GRAPH_ROOT / f"{safe_profile}.jsonl",
        POLICY_GRAPH_ROOT / "default.jsonl",
    ]
    for path in candidates:
        if path.exists():
            return path
    return candidates[-1]


def _set_path(out: Dict[str, Any], dotted_path: str, value: Any) -> None:
    parts = [p for p in dotted_path.split(".") if p]
    if not parts:
        return
    cursor = out
    for part in parts[:-1]:
        node = cursor.get(part)
        if not isinstance(node, dict):
            node = {}
            cursor[part] = node
        cursor = node
    cursor[parts[-1]] = value


def load_graph_lines(path: Path) -> List[str]:
    if not path.exists():
        return []
    return path.read_text(encoding="utf-8").splitlines()


def apply_graph_lines(base_graph: Dict[str, Any], lines: Iterable[str]) -> Dict[str, Any]:
    graph: Dict[str, Any] = {}
    _merge_into(graph, base_graph)
    for raw in lines:
        line = str(raw).strip()
        if not line or line.startswith("#"):
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not isinstance(row, dict):
            continue
        if str(row.get("op", "set")) != "set":
            continue
        dotted_path = str(row.get("path", "") or "")
        if not dotted_path:
            continue
        _set_path(graph, dotted_path, row.get("value"))
    return graph


def load_resolved_graph(profile_id: str = "default", policy_kind: str = "ucb", extra_lines: Iterable[str] | None = None) -> Dict[str, Any]:
    graph = apply_graph_lines({}, load_graph_lines(DEFAULT_GRAPH_PATH))
    path = profile_graph_path(profile_id, policy_kind)
    if path != DEFAULT_GRAPH_PATH:
        graph = apply_graph_lines(graph, load_graph_lines(path))
    if extra_lines:
        graph = apply_graph_lines(graph, extra_lines)
    if "profile_id" not in graph:
        graph["profile_id"] = profile_id or "default"
    return graph


def _merge_into(dst: Dict[str, Any], src: Dict[str, Any]) -> None:
    for key, value in src.items():
        if isinstance(value, dict):
            node = dst.get(key)
            if not isinstance(node, dict):
                node = {}
                dst[key] = node
            _merge_into(node, value)
        else:
            dst[key] = value


def action_limits_for_action_from_graph(graph: Dict[str, Any], action_name: str) -> Dict[str, Any]:
    limits = graph.get("action_limits", {})
    if not isinstance(limits, dict):
        limits = {}
    defaults = limits.get("default", {})
    if not isinstance(defaults, dict):
        defaults = {}
    out: Dict[str, Any] = {}
    _merge_into(out, defaults)
    specific = limits.get(action_name, {})
    if isinstance(specific, dict):
        _merge_into(out, specific)
    return out


def action_limits_for_action(profile_id: str = "default", policy_kind: str = "ucb", action_name: str = "quest_cycle", extra_lines: Iterable[str] | None = None) -> Dict[str, Any]:
    graph = load_resolved_graph(profile_id=profile_id, policy_kind=policy_kind, extra_lines=extra_lines)
    return action_limits_for_action_from_graph(graph, action_name)
