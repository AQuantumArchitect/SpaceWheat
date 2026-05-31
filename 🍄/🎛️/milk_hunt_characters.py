#!/usr/bin/env python3
"""Higher-order milk-hunt characters.

Characters sit above raw world_state and policy_graph. A character defines:
- world seed state (resources, biomes, known icons)
- policy graph template/overrides per hunter policy

This layer is for LLM-facing orchestration in 🍄/🎛️.
"""
from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, List, Tuple

from constants import POLICY_ENGINE, POLICY_QUANTUM, POLICY_MODES
from milk_hunt_runtime_config import load_json_config


CharacterDict = Dict[str, Any]

HERE = Path(__file__).resolve().parent
CHARACTER_DIR = HERE / "config" / "characters"
PROJECT_ROOT = HERE.parent.parent
CORE_POLICY_ROOT = PROJECT_ROOT / "Core" / "Config" / "PolicyGraph"
MUSHROOM_POLICY_ROOT = HERE / "config" / "policy_graph_templates"


def fibonacci_values(limit: int = 10_000) -> List[int]:
    values = [1, 1]
    while values[-1] < limit:
        values.append(values[-1] + values[-2])
    return values


def is_fibonacci_value(value: int) -> bool:
    if int(value) <= 0:
        return False
    return int(value) in set(fibonacci_values(max(10_000, int(value) * 2)))


def list_character_names() -> List[str]:
    if not CHARACTER_DIR.is_dir():
        return []
    return sorted(path.stem for path in CHARACTER_DIR.glob("*.json"))


def _character_path(name_or_path: str) -> Path:
    raw = (name_or_path or "").strip()
    if not raw:
        raise ValueError("character name/path is empty")
    candidate = Path(raw)
    if candidate.exists():
        return candidate
    path = CHARACTER_DIR / f"{raw}.json"
    if path.exists():
        return path
    raise ValueError(
        "unknown character '%s'. available: %s"
        % (raw, ", ".join(list_character_names()))
    )


def _normalize_lines(raw: Any) -> List[str]:
    if not isinstance(raw, list):
        return []
    out: List[str] = []
    for item in raw:
        line = str(item).strip()
        if line:
            out.append(line)
    return out


def _resolve_template_to_engine_path(template: str, policy_kind: str, profile_id: str) -> str:
    template = (template or "").strip()
    safe_kind = (policy_kind or "ucb").strip() or "ucb"
    safe_profile = (profile_id or "default").strip() or "default"
    if not template:
        candidate = CORE_POLICY_ROOT / safe_kind / f"{safe_profile}.jsonl"
        if candidate.exists():
            return f"res://Core/Config/PolicyGraph/{safe_kind}/{safe_profile}.jsonl"
        return "res://Core/Config/PolicyGraph/default.jsonl"
    if template.startswith("core:"):
        suffix = template.split(":", 1)[1].strip().lstrip("/")
        if suffix == "":
            return "res://Core/Config/PolicyGraph/default.jsonl"
        if not suffix.endswith(".jsonl"):
            suffix += ".jsonl"
        return f"res://Core/Config/PolicyGraph/{suffix}"
    if template.startswith("mushroom:"):
        suffix = template.split(":", 1)[1].strip().lstrip("/")
        if suffix == "":
            raise ValueError("mushroom policy template cannot be empty")
        if not suffix.endswith(".jsonl"):
            suffix += ".jsonl"
        return f"res://🍄/🎛️/config/policy_graph_templates/{suffix}"
    path = Path(template)
    if path.is_absolute():
        return str(path)
    return str((PROJECT_ROOT / path).resolve())


def _validate_resources(resources: Dict[str, Any], scale: str) -> Dict[str, int]:
    out: Dict[str, int] = {}
    for emoji, raw in resources.items():
        amount = int(raw)
        if amount <= 0:
            raise ValueError("resource '%s' must be > 0" % emoji)
        if scale == "fibonacci" and not is_fibonacci_value(amount):
            raise ValueError("resource '%s'=%d is not fibonacci-scaled" % [emoji, amount])
        out[str(emoji)] = amount
    return out


def get_character(name_or_path: str) -> CharacterDict:
    path = _character_path(name_or_path)
    data = load_json_config(path)
    if not data:
        raise ValueError("failed to load character '%s' from %s" % (name_or_path, path))
    data.setdefault("name", path.stem)
    data.setdefault("description", "")
    data.setdefault("resource_scale", "fibonacci")
    data.setdefault("scenario_id", "default")
    data.setdefault("strict_biome_economy", True)
    data.setdefault("resources", {})
    data.setdefault("known_icons", [])
    data.setdefault("unlocked_biomes", ["StarterForest", "Village"])
    data.setdefault("unexplored_biomes", [])
    if not data.get("active_biome"):
        biomes = data.get("unlocked_biomes", [])
        data["active_biome"] = str(biomes[-1]) if biomes else "Village"
    data.setdefault("policies", {})
    data["_path"] = str(path)
    data["resources"] = _validate_resources(data.get("resources", {}), str(data.get("resource_scale", "fibonacci")))
    return data


def resolve_character_world_state(character: CharacterDict) -> Dict[str, Any]:
    return {
        "name": str(character.get("name", "")),
        "description": str(character.get("description", "")),
        "scenario_id": str(character.get("scenario_id", "default")),
        "strict_biome_economy": bool(character.get("strict_biome_economy", True)),
        "resources": dict(character.get("resources", {})),
        "known_icons": list(character.get("known_icons", [])),
        "unlocked_biomes": list(character.get("unlocked_biomes", [])),
        "unexplored_biomes": list(character.get("unexplored_biomes", [])),
        "active_biome": str(character.get("active_biome", "")),
        "economy_overrides": dict(character.get("economy_overrides", {})),
    }


def resolve_character_policy(character: CharacterDict, hunter_policy: str) -> Dict[str, Any]:
    safe_mode = (hunter_policy or POLICY_ENGINE).strip() or POLICY_ENGINE
    if safe_mode not in POLICY_MODES:
        raise ValueError("unsupported character policy mode '%s'" % safe_mode)
    policy_kind = POLICY_QUANTUM if safe_mode == POLICY_QUANTUM else "ucb"
    policies = character.get("policies", {})
    policy_cfg = policies.get(safe_mode, {}) if isinstance(policies, dict) else {}
    if not isinstance(policy_cfg, dict):
        policy_cfg = {}
    profile_id = str(
        policy_cfg.get(
            "profile_id",
            character.get("policy_profile_id", character.get("name", "default")),
        )
    ).strip() or "default"
    template = str(policy_cfg.get("template", "") or "")
    graph_path = str(policy_cfg.get("policy_graph_path", "") or "")
    if graph_path == "":
        graph_path = _resolve_template_to_engine_path(template, policy_kind, profile_id)
    graph_lines = _normalize_lines(policy_cfg.get("graph_jsonl", []))
    return {
        "mode": safe_mode,
        "policy_kind": policy_kind,
        "profile_id": profile_id,
        "policy_graph_path": graph_path,
        "policy_graph_jsonl": graph_lines,
    }


def resolve_character_seed(character: CharacterDict, hunter_policy: str) -> Tuple[Dict[str, Any], Dict[str, Any]]:
    return resolve_character_world_state(character), resolve_character_policy(character, hunter_policy)
