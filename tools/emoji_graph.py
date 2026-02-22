#!/usr/bin/env python3
"""
Unified emoji graph + projection utilities.

Builds the adjacency graph from faction signatures plus optional cross-check
with the icon map snapshots (if available). Provides dual-qubit projections per
vocabulary pair (north/south) and exposes graph stats for downstream controllers.
"""

from __future__ import annotations

import json
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Mapping, Sequence

FACTION_PATH = Path("Core/Factions/data/factions.json")


def load_signatures(path: Path = FACTION_PATH) -> dict[str, list[str]]:
    if not path.exists():
        raise FileNotFoundError(path)
    data = json.loads(path.read_text(encoding="utf-8"))
    signatures = {}
    for entry in data:
        signature = entry.get("signature") or entry.get("sig") or []
        if not signature:
            continue
        name = entry.get("name", "unnamed")
        signatures[name] = [str(e) for e in signature if isinstance(e, str) and e]
    return signatures


def build_graph(signatures: Mapping[str, Sequence[str]]) -> dict[str, set[str]]:
    graph = defaultdict(set)
    for sig in signatures.values():
        for i, src in enumerate(sig):
            for dest in sig[i + 1 :]:
                graph[src].add(dest)
                graph[dest].add(src)
    return dict(graph)


def graph_stats(graph: Mapping[str, set[str]]) -> dict[str, int]:
    nodes = len(graph)
    edges = sum(len(neighbors) for neighbors in graph.values()) // 2
    degrees = [len(neighbors) for neighbors in graph.values()]
    return {"nodes": nodes, "edges": edges, "min_degree": min(degrees, default=0), "max_degree": max(degrees, default=0)}


@dataclass
class QubitProjection:
    north: str
    south: str
    amplitude_known: float = 0.0
    amplitude_novel: float = 0.0

    def vector(self) -> tuple[float, float]:
        return (self.amplitude_known, self.amplitude_novel)


def project_qubits(known: Iterable[str], vocab_pairs: Sequence[tuple[str, str]]) -> list[QubitProjection]:
    known_set = set(known)
    projections = []
    for north, south in vocab_pairs:
        known_north = north in known_set
        known_south = south in known_set
        amplitude_known = 0.0
        amplitude_novel = 0.0
        if known_north or known_south:
            amplitude_known = 1.0
        else:
            amplitude_novel = 1.0
        projections.append(QubitProjection(north, south, amplitude_known, amplitude_novel))
    return projections


def export_graph(graph: Mapping[str, set[str]], path: Path):
    payload = {
        "graph": {emoji: sorted(list(neighbors)) for emoji, neighbors in graph.items()},
        **graph_stats(graph),
    }
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def example_usage():
    signatures = load_signatures()
    graph = build_graph(signatures)
    print("Graph stats:", graph_stats(graph))
    projections = project_qubits({"🌾"}, [("🌾", "👥"), ("🦅", "🷽")])  # sample pairs
    for proj in projections:
        print(proj.north, proj.south, proj.vector())


if __name__ == "__main__":
    raise SystemExit(0)
