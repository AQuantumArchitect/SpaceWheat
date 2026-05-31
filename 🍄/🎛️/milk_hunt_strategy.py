#!/usr/bin/env python3
"""Strategy loader for milk hunt tuning.

A Strategy encapsulates all scoring weights, resource targets/floors,
eagle parameters, and injection behavior.  Every constant that was
previously hardcoded in milk_hunt_runner.py is exposed as a property
with the original value as default fallback.
"""
from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, List, Optional

from milk_hunt_runtime_config import load_json_config


_CONFIG_DIR = Path(__file__).resolve().parent / "config" / "strategy"

# ── Defaults (identical to the old hardcoded values) ─────────────────

_DEFAULT_STRATEGIC_TARGETS: Dict[str, float] = {
    "\U0001F465": 34.0,    # 👥  (Fibonacci: ~φ × starting 21)
    "\U0001F33E": 34.0,    # 🌾
    "\U0001F35E": 34.0,    # 🍞
    "\u2744\uFE0F": 21.0,  # ❄️  (Fibonacci: ~φ × starting 13)
    "\U0001F331": 13.0,    # 🌱
}

_DEFAULT_RESOURCE_FLOORS: Dict[str, float] = {
    "\U0001F35E": 13.0,    # 🍞  (Fibonacci: matches starting ❄️ level)
    "\u2744\uFE0F": 8.0,   # ❄️  (Fibonacci: matches starting 👥 level)
    "\U0001F465": 13.0,    # 👥
}

_DEFAULT_SCORING = {
    "afford_delta": 13.0,
    "deficit_progress": 0.8,
    "vocab_injection_need": 1.2,
    "net_growth_strict": 0.18,
    "net_growth_normal": 0.08,
    "reward_sum": 0.04,
    "vocab_discovery": 25,
    "completion_penalty": -30,
}

_DEFAULT_BIOME_DISCOVERY: Dict[str, float] = {
    "floor": 0.1,
    "quest_scale": 5.0,
    "vocab_scale": 2.0,
    "milk_scale": 3.0,
}

# Geometric decay: score(d) = d1 * decay^(d-1)  for d >= 1.
# "decay" controls how fast the gradient falls off with distance.
# d2/d3 are kept as optional overrides in strategy JSON,
# but the formula is used for all depths when "decay" is present (the default).
_DEFAULT_DISTANCE_SCORES = {"milk": 1000, "d1": 260, "decay": 0.6}
_DEFAULT_FACTION_SIG_SCORES = {"d1": 140, "decay": 0.6}

_DEFAULT_EAGLE = {
    "emoji": "\U0001F985",  # 🦅
    "target_stock": 80.0,
    "probe_burst": 2,
    "check_every": 8,
    "max_expansions": 3,
    "min_for_expansion": 40.0,
}

_DEFAULT_INITIAL_INJECTION = {
    "enabled": True,
    "amount": 500,
    "resources": [
        "\U0001F465",   # 👥
        "\U0001F33E",   # 🌾
        "\U0001F35E",   # 🍞
        "\u2744\uFE0F", # ❄️
        "\U0001F331",   # 🌱
        "\u2699",       # ⚙
        "\U0001F525",   # 🔥
    ],
}


class Strategy:
    """Typed accessor over a strategy JSON dict."""

    def __init__(self, data: Dict[str, Any] | None = None) -> None:
        self._data: Dict[str, Any] = data or {}

    # ── identity ─────────────────────────────────────────────────────

    @property
    def name(self) -> str:
        return str(self._data.get("name", "default"))

    @property
    def description(self) -> str:
        return str(self._data.get("description", ""))

    @property
    def path(self) -> str:
        return str(self._data.get("_path", ""))

    # ── economy mode ─────────────────────────────────────────────────

    @property
    def strict_biome_economy(self) -> Optional[bool]:
        val = self._data.get("strict_biome_economy")
        if isinstance(val, bool):
            return val
        return None

    # ── resource targets / floors ────────────────────────────────────

    @property
    def strategic_targets(self) -> Dict[str, float]:
        raw = self._data.get("strategic_targets")
        if isinstance(raw, dict):
            return {str(k): float(v) for k, v in raw.items()}
        return dict(_DEFAULT_STRATEGIC_TARGETS)

    @property
    def resource_floors(self) -> Dict[str, float]:
        raw = self._data.get("resource_floors")
        if isinstance(raw, dict):
            return {str(k): float(v) for k, v in raw.items()}
        return dict(_DEFAULT_RESOURCE_FLOORS)

    # ── scoring weights ──────────────────────────────────────────────

    def _scoring(self, key: str) -> float:
        scoring = self._data.get("scoring")
        if isinstance(scoring, dict):
            val = scoring.get(key)
            if val is not None:
                return float(val)
        return float(_DEFAULT_SCORING[key])

    @property
    def afford_delta(self) -> float:
        return self._scoring("afford_delta")

    @property
    def deficit_progress(self) -> float:
        return self._scoring("deficit_progress")

    @property
    def vocab_injection_need(self) -> float:
        return self._scoring("vocab_injection_need")

    @property
    def net_growth_strict(self) -> float:
        return self._scoring("net_growth_strict")

    @property
    def net_growth_normal(self) -> float:
        return self._scoring("net_growth_normal")

    @property
    def reward_sum(self) -> float:
        return self._scoring("reward_sum")

    @property
    def vocab_discovery(self) -> int:
        return int(self._scoring("vocab_discovery"))

    @property
    def completion_penalty(self) -> int:
        return int(self._scoring("completion_penalty"))

    # ── distance scores ──────────────────────────────────────────────

    def _dist_scores(self) -> Dict[str, int]:
        raw = self._data.get("distance_scores")
        if isinstance(raw, dict):
            return {str(k): int(v) for k, v in raw.items()}
        return dict(_DEFAULT_DISTANCE_SCORES)

    def distance_score(self, d: Optional[int]) -> int:
        scores = self._dist_scores()
        if d == 0:
            return scores.get("milk", _DEFAULT_DISTANCE_SCORES["milk"])
        if d is None or d < 1:
            return 0
        d1 = scores.get("d1", _DEFAULT_DISTANCE_SCORES["d1"])
        decay = float(scores.get("decay", _DEFAULT_DISTANCE_SCORES["decay"]))
        result = int(d1 * (decay ** (d - 1)))
        return result if result >= 1 else 0

    # ── faction sig scores ───────────────────────────────────────────

    def _faction_scores(self) -> Dict[str, int]:
        raw = self._data.get("faction_sig_scores")
        if isinstance(raw, dict):
            return {str(k): int(v) for k, v in raw.items()}
        return dict(_DEFAULT_FACTION_SIG_SCORES)

    def faction_sig_score(self, d: int) -> int:
        scores = self._faction_scores()
        if d < 1:
            return 0
        d1 = scores.get("d1", _DEFAULT_FACTION_SIG_SCORES["d1"])
        decay = float(scores.get("decay", _DEFAULT_FACTION_SIG_SCORES["decay"]))
        result = int(d1 * (decay ** (d - 1)))
        return result if result >= 1 else 0

    # ── eagle ────────────────────────────────────────────────────────

    def _eagle(self, key: str, default: Any) -> Any:
        eagle = self._data.get("eagle")
        if isinstance(eagle, dict):
            val = eagle.get(key)
            if val is not None:
                return val
        return default

    @property
    def eagle_emoji(self) -> str:
        return str(self._eagle("emoji", _DEFAULT_EAGLE["emoji"]))

    @property
    def eagle_target_stock(self) -> float:
        return float(self._eagle("target_stock", _DEFAULT_EAGLE["target_stock"]))

    @property
    def eagle_probe_burst(self) -> int:
        return int(self._eagle("probe_burst", _DEFAULT_EAGLE["probe_burst"]))

    @property
    def eagle_check_every(self) -> int:
        return int(self._eagle("check_every", _DEFAULT_EAGLE["check_every"]))

    @property
    def eagle_max_expansions(self) -> int:
        return int(self._eagle("max_expansions", _DEFAULT_EAGLE["max_expansions"]))

    @property
    def eagle_min_for_expansion(self) -> float:
        return float(self._eagle("min_for_expansion", _DEFAULT_EAGLE["min_for_expansion"]))

    # ── initial injection ────────────────────────────────────────────

    def _injection(self, key: str, default: Any) -> Any:
        inj = self._data.get("initial_injection")
        if isinstance(inj, dict):
            val = inj.get(key)
            if val is not None:
                return val
        return default

    @property
    def initial_injection_enabled(self) -> bool:
        return bool(self._injection("enabled", _DEFAULT_INITIAL_INJECTION["enabled"]))

    @property
    def initial_injection_amount(self) -> int:
        return int(self._injection("amount", _DEFAULT_INITIAL_INJECTION["amount"]))

    @property
    def initial_injection_resources(self) -> List[str]:
        raw = self._injection("resources", _DEFAULT_INITIAL_INJECTION["resources"])
        if isinstance(raw, list):
            return [str(x) for x in raw]
        return list(_DEFAULT_INITIAL_INJECTION["resources"])

    # ── biome discovery weights ──────────────────────────────────────

    @property
    def biome_discovery(self) -> Dict[str, float]:
        """Weights for BiomeDiscoveryForecastService — sent via configure_discovery."""
        raw = self._data.get("biome_discovery")
        defaults = dict(_DEFAULT_BIOME_DISCOVERY)
        if isinstance(raw, dict):
            return {**defaults, **{k: float(v) for k, v in raw.items() if isinstance(v, (int, float))}}
        return defaults

    # ── serialization ────────────────────────────────────────────────

    def to_dict(self) -> Dict[str, Any]:
        return dict(self._data)


def load_strategy(path: Optional[str | Path] = None) -> Strategy:
    """Load a strategy from a JSON path.

    If *path* is None, loads config/strategy/default.json.
    If the file does not exist, returns a Strategy with built-in defaults.
    """
    if path is None:
        path = _CONFIG_DIR / "default.json"
    p = Path(path)
    data = load_json_config(p)
    data["_path"] = str(p)
    return Strategy(data)
