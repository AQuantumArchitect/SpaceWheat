#!/usr/bin/env python3
"""Modular, profile-aware milk hunter policy with a lightweight quantum graph.

This module is intentionally runner-agnostic:
- `HunterStateAdapter` normalizes runtime state from the rig loop.
- `QuantumGraphPolicy` scores quest offers and biome probe targets.
- Profile knobs (starting with `granary_scout`) tune behavior without
  rewriting the hunt loop.
"""
from __future__ import annotations

import json
from collections import deque
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence, Set, Tuple


MILK = "\U0001F37C"
CRITICAL_RESOURCES = {
    "\U0001F465",  # 👥 labor
    "\U0001F35E",  # 🍞 bread
    "\u2744\uFE0F",  # ❄️ cold
}


def _reward_resources(offer: Dict[str, Any]) -> Dict[str, float]:
    raw = offer.get("reward_resources", {})
    if not isinstance(raw, dict):
        return {}
    out: Dict[str, float] = {}
    for emoji, amount in raw.items():
        if not isinstance(emoji, str) or not emoji:
            continue
        try:
            val = float(amount)
        except (TypeError, ValueError):
            continue
        if val > 0:
            out[emoji] = val
    return out


def _delivery_cost(offer: Dict[str, Any]) -> Tuple[str, float]:
    resource = str(offer.get("resource", "") or "")
    try:
        quantity = float(offer.get("quantity", 0) or 0)
    except (TypeError, ValueError):
        quantity = 0.0
    if not resource or quantity <= 0:
        return "", 0.0
    return resource, quantity


@dataclass
class HunterState:
    loop_idx: int
    max_loops: int
    known_pairs: List[Dict[str, str]]
    known_emojis: Set[str]
    resources: Dict[str, float]
    offers: List[Dict[str, Any]]
    eligible_offer_indices: List[int]
    biomes: List[str]
    discovered_biomes: List[str]
    biome_explore_counts: Dict[str, int]
    biome_resource_hits: Dict[str, Dict[str, int]]
    strict_biome_economy: bool
    resource_floors: Dict[str, float]


class HunterStateAdapter:
    """Normalize runner data into a stable policy state."""

    @staticmethod
    def build(
        *,
        loop_idx: int,
        max_loops: int,
        known_pairs: Sequence[Dict[str, str]],
        resources: Mapping[str, float],
        offers: Sequence[Dict[str, Any]],
        eligible_offer_indices: Sequence[int],
        biomes: Sequence[str],
        discovered_biomes: Sequence[str],
        biome_explore_counts: Mapping[str, int],
        biome_resource_hits: Mapping[str, Dict[str, int]],
        strict_biome_economy: bool,
        resource_floors: Mapping[str, float],
    ) -> HunterState:
        known_pairs_list = [dict(pair) for pair in known_pairs if isinstance(pair, dict)]
        known_emojis: Set[str] = set()
        for pair in known_pairs_list:
            north = str(pair.get("north", "") or "")
            south = str(pair.get("south", "") or "")
            if north:
                known_emojis.add(north)
            if south:
                known_emojis.add(south)
        return HunterState(
            loop_idx=loop_idx,
            max_loops=max_loops,
            known_pairs=known_pairs_list,
            known_emojis=known_emojis,
            resources={str(k): float(v) for k, v in resources.items()},
            offers=[dict(offer) for offer in offers if isinstance(offer, dict)],
            eligible_offer_indices=[int(i) for i in eligible_offer_indices],
            biomes=[str(b) for b in biomes if isinstance(b, str) and b],
            discovered_biomes=[str(b) for b in discovered_biomes if isinstance(b, str) and b],
            biome_explore_counts={str(k): int(v) for k, v in biome_explore_counts.items()},
            biome_resource_hits={
                str(biome): {str(e): int(c) for e, c in hits.items()}
                for biome, hits in biome_resource_hits.items()
            },
            strict_biome_economy=bool(strict_biome_economy),
            resource_floors={str(k): float(v) for k, v in resource_floors.items()},
        )


class QuantumEmojiGraph:
    """Faction-signature-derived adjacency with milk-distance projections."""

    def __init__(self, faction_signatures: Mapping[str, Iterable[str]]) -> None:
        self._adj: Dict[str, Set[str]] = {}
        for _name, emojis in faction_signatures.items():
            sig = [str(e) for e in emojis if isinstance(e, str) and e]
            for i, src in enumerate(sig):
                self._adj.setdefault(src, set())
                for dst in sig[i + 1 :]:
                    self._adj[src].add(dst)
                    self._adj.setdefault(dst, set()).add(src)
        self._milk_dist = self._bfs_distances(MILK)

    def _bfs_distances(self, source: str) -> Dict[str, int]:
        if source not in self._adj:
            return {}
        dist: Dict[str, int] = {source: 0}
        q: deque[str] = deque([source])
        while q:
            cur = q.popleft()
            for nxt in self._adj.get(cur, set()):
                if nxt in dist:
                    continue
                dist[nxt] = dist[cur] + 1
                q.append(nxt)
        return dist

    def degree(self, emoji: str) -> int:
        return len(self._adj.get(emoji, set()))

    def milk_distance(self, emoji: str) -> Optional[int]:
        return self._milk_dist.get(emoji)

    def emoji_value(self, emoji: str, known: Set[str]) -> float:
        if not emoji:
            return 0.0
        if emoji == MILK:
            return 500.0
        dist = self.milk_distance(emoji)
        proximity = 0.25 if dist is None else (12.0 / float(1 + dist))
        novelty = 0.65 if emoji in known else 1.75
        structural = min(2.5, float(self.degree(emoji)) * 0.08)
        return proximity * novelty + structural

    def pair_value(self, north: str, south: str, known: Set[str]) -> float:
        return self.emoji_value(north, known) + self.emoji_value(south, known)


class QuantumGraphPolicy:
    """Profile-aware policy using a graph-projected heuristic controller."""

    def __init__(
        self,
        *,
        profile_name: str,
        strategy,
        faction_signatures: Mapping[str, Iterable[str]],
    ) -> None:
        self.profile_name = profile_name.strip() or "default"
        self.strategy = strategy
        self.graph = QuantumEmojiGraph(faction_signatures)
        self._weights = self._build_profile_weights()

    def _build_profile_weights(self) -> Dict[str, float]:
        # Defaults preserve a conservative strategy.
        w: Dict[str, float] = {
            "offer_pair": 1.0,
            "offer_novelty": 1.0,
            "offer_reward": 0.04,
            "offer_deficit": 0.9,
            "offer_delivery_cost": -0.06,
            "offer_milk_direct": 900.0,
            "offer_critical_any": 2.0,
            "offer_critical_unknown": 7.0,
            "offer_critical_pair": 16.0,
            "probe_frontier": 1.0,
            "probe_hits": 0.8,
            "probe_novelty": 0.4,
            "probe_critical_hits": 1.2,
            "probe_village_pressure": 0.8,
            "probe_village_known_critical": 0.25,
            "loop_probe_base": 1.0,
            "loop_probe_pair_scale": 0.10,
            "loop_probe_floor_pressure": 1.0,
            "loop_probe_critical_pressure": 1.0,
            "loop_probe_strict_bonus": 1.0,
            "loop_probe_max": 4.0,
            "vocab_probe_base": 1.0,
            "vocab_probe_per_pair": 1.0,
            "vocab_probe_max": 6.0,
            "lindblad_hits": 1.1,
            "lindblad_critical_hits": 1.6,
            "lindblad_floor_hits": 1.8,
            "lindblad_frontier": 0.35,
            "lindblad_novelty": 0.45,
            "lindblad_village_pressure": 0.8,
        }
        # Granary scout: bread/labor grounded, explore more aggressively.
        if self.profile_name == "granary_scout":
            w.update(
                {
                    "offer_pair": 1.6,
                    "offer_novelty": 2.4,
                    "offer_reward": 0.06,
                    "offer_deficit": 1.15,
                    "offer_delivery_cost": -0.04,
                    "offer_milk_direct": 1300.0,
                    "offer_critical_any": 6.0,
                    "offer_critical_unknown": 28.0,
                    "offer_critical_pair": 72.0,
                    "probe_frontier": 1.8,
                    "probe_hits": 1.0,
                    "probe_novelty": 0.75,
                    "probe_critical_hits": 1.8,
                    "probe_village_pressure": 2.2,
                    "probe_village_known_critical": 0.9,
                    "loop_probe_base": 0.0,
                    "loop_probe_pair_scale": 0.05,
                    "loop_probe_floor_pressure": 0.25,
                    "loop_probe_critical_pressure": 0.5,
                    "loop_probe_strict_bonus": 1.0,
                    "loop_probe_max": 1.0,
                    "vocab_probe_base": 1.0,
                    "vocab_probe_per_pair": 0.0,
                    "vocab_probe_max": 2.0,
                    "lindblad_hits": 1.35,
                    "lindblad_critical_hits": 2.2,
                    "lindblad_floor_hits": 2.6,
                    "lindblad_frontier": 0.4,
                    "lindblad_novelty": 0.6,
                    "lindblad_village_pressure": 1.5,
                }
            )

        # File-based Graph Tissue™ overrides: config/policy_weights/{profile}.json
        # Any profile can ship weight overrides without touching this code.
        pw_path = Path(__file__).resolve().parent / "config" / "policy_weights" / f"{self.profile_name}.json"
        if pw_path.is_file():
            try:
                overrides = json.loads(pw_path.read_text(encoding="utf-8"))
                if isinstance(overrides, dict):
                    for k, v in overrides.items():
                        if k in w:
                            w[k] = float(v)
            except (json.JSONDecodeError, ValueError, OSError):
                pass  # Silently skip malformed weight files

        return w

    def _resource_deficit_score(self, state: HunterState, rewards: Mapping[str, float]) -> float:
        deficit = 0.0
        for emoji, floor in state.resource_floors.items():
            have = float(state.resources.get(emoji, 0.0))
            if have >= floor:
                continue
            if emoji in rewards:
                deficit += min(float(rewards[emoji]), floor - have)
        return deficit

    def _floor_pressure(self, state: HunterState) -> int:
        pressure = 0
        for emoji, floor in state.resource_floors.items():
            if float(state.resources.get(emoji, 0.0)) < floor:
                pressure += 1
        return pressure

    def _critical_resource_pressure(self, state: HunterState) -> float:
        pressure = 0.0
        for emoji in CRITICAL_RESOURCES:
            floor = float(state.resource_floors.get(emoji, 0.0))
            if floor <= 0.0:
                continue
            have = float(state.resources.get(emoji, 0.0))
            if have >= floor:
                continue
            pressure += (floor - have) / max(1.0, floor)
        return pressure

    def choose_offer_index(self, state: HunterState) -> Tuple[int, List[Dict[str, Any]]]:
        if not state.eligible_offer_indices:
            return 0, []
        rankings: List[Dict[str, Any]] = []
        best_idx = state.eligible_offer_indices[0]
        best_score = -1e18
        for idx in state.eligible_offer_indices:
            if idx < 0 or idx >= len(state.offers):
                continue
            offer = state.offers[idx]
            north = str(offer.get("reward_vocab_north", "") or "")
            south = str(offer.get("reward_vocab_south", "") or "")
            rewards = _reward_resources(offer)
            delivery_emoji, delivery_qty = _delivery_cost(offer)
            novelty_count = float(int(north not in state.known_emojis and north != "") + int(south not in state.known_emojis and south != ""))
            pair_score = self.graph.pair_value(north, south, state.known_emojis)
            reward_sum = sum(rewards.values())
            deficit_gain = self._resource_deficit_score(state, rewards)
            cost_penalty = delivery_qty if delivery_emoji else 0.0
            milk_direct = self._weights["offer_milk_direct"] if (north == MILK or south == MILK) else 0.0
            critical_any = float(int(north in CRITICAL_RESOURCES) + int(south in CRITICAL_RESOURCES))
            critical_unknown = float(
                int(north in CRITICAL_RESOURCES and north not in state.known_emojis)
                + int(south in CRITICAL_RESOURCES and south not in state.known_emojis)
            )
            critical_pair = 1.0 if critical_any >= 2.0 and critical_unknown >= 1.0 else 0.0
            score = (
                pair_score * self._weights["offer_pair"]
                + novelty_count * self._weights["offer_novelty"]
                + reward_sum * self._weights["offer_reward"]
                + deficit_gain * self._weights["offer_deficit"]
                + cost_penalty * self._weights["offer_delivery_cost"]
                + critical_any * self._weights["offer_critical_any"]
                + critical_unknown * self._weights["offer_critical_unknown"]
                + critical_pair * self._weights["offer_critical_pair"]
                + milk_direct
            )
            row = {
                "offer_index": idx,
                "score": score,
                "pair_score": pair_score,
                "novelty": novelty_count,
                "reward_sum": reward_sum,
                "deficit_gain": deficit_gain,
                "cost_penalty": cost_penalty,
                "critical_any": critical_any,
                "critical_unknown": critical_unknown,
                "critical_pair": critical_pair,
                "north": north,
                "south": south,
            }
            rankings.append(row)
            if score > best_score:
                best_score = score
                best_idx = idx
        rankings.sort(key=lambda r: float(r.get("score", 0.0)), reverse=True)
        return best_idx, rankings[:3]

    def choose_probe_biome(self, state: HunterState) -> Tuple[Optional[str], List[Dict[str, Any]]]:
        if not state.biomes:
            return None, []
        ranked: List[Dict[str, Any]] = []
        critical_known = float(sum(1 for emoji in CRITICAL_RESOURCES if emoji in state.known_emojis))
        critical_pressure = self._critical_resource_pressure(state)
        for biome in state.biomes:
            explore_count = float(state.biome_explore_counts.get(biome, 0))
            frontier = 1.0 / (1.0 + explore_count)
            hit_score = 0.0
            critical_hit_score = 0.0
            for emoji, count in state.biome_resource_hits.get(biome, {}).items():
                c = float(count)
                hit_score += c * self.graph.emoji_value(emoji, state.known_emojis)
                if emoji in CRITICAL_RESOURCES:
                    critical_hit_score += c
            novelty = 1.0 if biome not in state.discovered_biomes else 0.0
            village_bonus = 0.0
            if biome == "Village":
                village_bonus = (
                    critical_pressure * self._weights["probe_village_pressure"]
                    + critical_known * self._weights["probe_village_known_critical"]
                )
            score = (
                frontier * self._weights["probe_frontier"]
                + hit_score * self._weights["probe_hits"]
                + critical_hit_score * self._weights["probe_critical_hits"]
                + novelty * self._weights["probe_novelty"]
                + village_bonus
            )
            ranked.append(
                {
                    "biome": biome,
                    "score": score,
                    "frontier": frontier,
                    "hit_score": hit_score,
                    "critical_hit_score": critical_hit_score,
                    "village_bonus": village_bonus,
                    "novelty": novelty,
                }
            )
        ranked.sort(key=lambda r: float(r.get("score", 0.0)), reverse=True)
        return str(ranked[0]["biome"]), ranked[:3]

    def extra_probe_cycles(self, state: HunterState) -> int:
        floor_pressure = self._floor_pressure(state)
        critical_pressure = self._critical_resource_pressure(state)
        pairs = len(state.known_pairs)
        raw = (
            self._weights["loop_probe_base"]
            + self._weights["loop_probe_pair_scale"] * max(0.0, 12.0 - float(pairs))
            + self._weights["loop_probe_floor_pressure"] * float(floor_pressure)
            + self._weights["loop_probe_critical_pressure"] * critical_pressure
        )
        if state.strict_biome_economy:
            raw += self._weights["loop_probe_strict_bonus"]
        return max(0, min(int(round(raw)), int(self._weights["loop_probe_max"])))

    def probe_cycles_after_vocab_gain(self, state: HunterState, pair_gain: int) -> int:
        raw = self._weights["vocab_probe_base"] + self._weights["vocab_probe_per_pair"] * float(max(1, pair_gain))
        return max(1, min(int(round(raw)), int(self._weights["vocab_probe_max"])))

    def choose_lindblad_biomes(
        self,
        state: HunterState,
        candidate_biomes: Sequence[str],
        max_biomes: int = 1,
    ) -> Tuple[List[str], List[Dict[str, Any]]]:
        ranked: List[Dict[str, Any]] = []
        floor_deficits: Dict[str, float] = {}
        for emoji, floor in state.resource_floors.items():
            have = float(state.resources.get(emoji, 0.0))
            if have < floor:
                floor_deficits[emoji] = floor - have
        total_floor_deficit = sum(floor_deficits.values())
        critical_pressure = self._critical_resource_pressure(state)
        discovered = set(state.discovered_biomes)

        for biome in candidate_biomes:
            if not isinstance(biome, str) or not biome:
                continue
            hits_map = state.biome_resource_hits.get(biome, {})
            total_hits = float(sum(int(v) for v in hits_map.values()))
            critical_hits = float(sum(int(hits_map.get(e, 0)) for e in CRITICAL_RESOURCES))
            floor_hits = 0.0
            if total_floor_deficit > 0.0:
                for emoji, deficit in floor_deficits.items():
                    if deficit <= 0.0:
                        continue
                    floor_hits += float(hits_map.get(emoji, 0)) * (deficit / max(1.0, total_floor_deficit))
            frontier = 1.0 if biome not in discovered else 0.0
            novelty = 1.0 / float(1 + max(0, state.biome_explore_counts.get(biome, 0)))
            village_pressure = 1.0 if (biome == "Village" and critical_pressure > 0.0) else 0.0
            score = (
                total_hits * self._weights["lindblad_hits"]
                + critical_hits * self._weights["lindblad_critical_hits"]
                + floor_hits * self._weights["lindblad_floor_hits"]
                + frontier * self._weights["lindblad_frontier"]
                + novelty * self._weights["lindblad_novelty"]
                + village_pressure * self._weights["lindblad_village_pressure"]
            )
            ranked.append(
                {
                    "biome": biome,
                    "score": score,
                    "total_hits": total_hits,
                    "critical_hits": critical_hits,
                    "floor_hits": floor_hits,
                    "frontier": frontier,
                    "novelty": novelty,
                    "village_pressure": village_pressure,
                }
            )

        ranked.sort(key=lambda row: (-float(row["score"]), str(row["biome"])))
        selected = [str(row["biome"]) for row in ranked[: max(1, int(max_biomes))]]
        return selected, ranked[: max(3, int(max_biomes))]
