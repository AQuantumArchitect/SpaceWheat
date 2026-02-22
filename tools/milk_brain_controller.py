#!/usr/bin/env python3
"""
Graph-aware milk hunter decision prototype.

Uses the unified emoji graph plus qubit projections to score actions.
Action weights derive from graph distances to milk and from projection magnitudes.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Iterable, Sequence
import sys

ROOT = Path(__file__).resolve()
PROJECT_ROOT = ROOT.parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.append(str(PROJECT_ROOT))

from tools.emoji_graph import FACTION_PATH, graph_stats, project_qubits, build_graph

ACTIONS = ["explore", "inject", "drain", "quest"]
MILK = "🍼"


def load_graph(path: Path = FACTION_PATH):
    signatures = {}
    if not path.exists():
        raise FileNotFoundError(path)
    data = json.load(path.open("r", encoding="utf-8"))
    for entry in data:
        sig = entry.get("signature") or entry.get("sig") or []
        sig = [e for e in sig if isinstance(e, str) and e]
        if sig:
            signatures[entry.get("name", "unk")] = sig
    return build_graph(signatures)


def action_scores(graph, projections, resource_state):
    scores = {}
    milk_distance = {}
    for proj in projections:
        nodes = [proj.north, proj.south]
        for node in nodes:
            if node == MILK:
                continue
            neighbors = graph.get(node, set())
            dist = len(neighbors)
            milk_distance[node] = dist or 1
    for action in ACTIONS:
        base = 1.0
        if action == "explore":
            base += sum(1.0 / milk_distance.get(node, 5) for node in resource_state)
        elif action == "inject":
            base += sum(proj.amplitude_novel for proj in projections)
        elif action == "drain":
            base += resource_state.count("⚡")
        elif action == "quest":
            base += sum(proj.amplitude_known for proj in projections)
        scores[action] = base
    return scores


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--known", action="append", default=[], help="Known vocab emojis")
    parser.add_argument("--resources", action="append", default=[], help="Resource emojis currently available")
    parser.add_argument("--pairs", action="append", nargs=2, metavar=("NORTH","SOUTH"), default=[], help="Vocab pairs")
    args = parser.parse_args()

    graph = load_graph()
    projections = project_qubits(args.known, args.pairs)
    scores = action_scores(graph, projections, args.resources)
    payload = {
        "known": args.known,
        "resources": args.resources,
        "pairs": args.pairs,
        "scores": scores,
        "graph_stats": graph_stats(graph)
    }
    print(json.dumps(payload, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
