#!/usr/bin/env python3
"""
Milk path assessment tool.

Loads the faction signature web at Core/Factions/data/factions.json and exposes an
API to measure the shortest emoji path from any starting vocabulary to the milk pair
emoji (🍼) via faction signature intersections.

Usage:
    python3 tools/milk_path_assessment.py --known 🌾 --known 👥 --output /tmp/milk_path.json

The output is JSON with:
  * "start": sorted list of the known emojis
  * "path": list of emojis forming the shortest path to 🍼 (includes start or bridge nodes)
  * "steps": number of transitions
  * "checked_factions": list of factions consulted
  * "graph_size": node/edge counts for diagnostics
  * "search_trace": each BFS layer for debugging
"""

from __future__ import annotations

import argparse
import json
from collections import deque, defaultdict
from pathlib import Path

FACTION_JSON = Path("Core/Factions/data/factions.json")
MILK_EMOJI = "🍼"


def load_faction_signatures(path: Path) -> dict[str, list[str]]:
    with path.open("r", encoding="utf-8") as fh:
        payload = json.load(fh)
    result = {}
    for entry in payload:
        name = entry.get("name", "unnamed")
        signature = entry.get("signature", entry.get("sig", []))
        if not signature:
            continue
        emojis = [str(e) for e in signature if isinstance(e, str)]
        result[name] = emojis
    return result


def build_graph(signatures: dict[str, list[str]]) -> dict[str, set[str]]:
    graph: dict[str, set[str]] = defaultdict(set)
    for sig in signatures.values():
        for i, a in enumerate(sig):
            for b in sig[i + 1 :]:
                graph[a].add(b)
                graph[b].add(a)
    return graph


def find_shortest_path(graph: dict[str, set[str]], start_tokens: set[str]) -> tuple[list[str], list[str]]:
    queue = deque([(token, [token]) for token in start_tokens])
    visited = set(start_tokens)
    trace: list[str] = []
    while queue:
        token, path = queue.popleft()
        trace.append(token)
        if token == MILK_EMOJI:
            return path, trace
        for neighbor in graph.get(token, []):
            if neighbor in visited:
                continue
            visited.add(neighbor)
            queue.append((neighbor, path + [neighbor]))
    return [], trace


def main() -> int:
    parser = argparse.ArgumentParser(description="Compute the milk emoji path for a starting vocabulary.")
    parser.add_argument("--known", action="append", default=[], help="Starting emoji (repeatable).")
    parser.add_argument("--output", type=Path, default=None, help="Optional JSON output path.")
    parser.add_argument("--describe-graph", action="store_true", help="Describe graph stats.")
    args = parser.parse_args()

    if not FACTION_JSON.exists():
        raise FileNotFoundError(f"{FACTION_JSON} not found.")

    known = {tok for tok in args.known if tok}
    signatures = load_faction_signatures(FACTION_JSON)
    graph = build_graph(signatures)

    path, trace = find_shortest_path(graph, known or {next(iter(graph), MILK_EMOJI)})

    payload = {
        "start": sorted(list(known)),
        "goal": MILK_EMOJI,
        "path": path,
        "steps": len(path) - 1 if path else None,
        "trace_length": len(trace),
        "graph_size": {"nodes": len(graph), "edges": sum(len(neigh) for neigh in graph.values()) // 2},
    }

    if args.describe_graph:
        payload["signatures_examined"] = len(signatures)
        payload["edges"] = {k: sorted(list(v)) for k, v in list(graph.items())[:20]}

    if args.output:
        args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"Milk path exported to {args.output}")
    else:
        print(json.dumps(payload, ensure_ascii=False, indent=2))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
