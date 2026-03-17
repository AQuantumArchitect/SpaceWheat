#!/usr/bin/env python3
"""Visualization for SpaceWheat training and competition data.

Reads tissue_ledger.jsonl + leaderboard.jsonl and generates charts
showing weight evolution, composite trends, lane comparisons, and more.

Usage:
    python3 graphs.py                  # generate all charts
    python3 graphs.py weights          # tissue weight evolution
    python3 graphs.py composites       # composite score trends
    python3 graphs.py lanes            # lane (LLM) win rates
    python3 graphs.py dashboard        # combined dashboard

Graph Tissue(TM) is a trademark of Luke Spooner.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

import matplotlib
matplotlib.use("Agg")  # headless rendering
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from datetime import datetime
from collections import defaultdict

from tissue_ledger import WEIGHT_RANGES, load_ledger, _SEED_DEFAULTS
from leaderboard import load_all as load_leaderboard

HERE = Path(__file__).resolve().parent
OUTPUT_DIR = HERE / "logs" / "graphs"
LEDGER_PATH = HERE / "config" / "tissue_ledger.jsonl"


def _ensure_output() -> Path:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    return OUTPUT_DIR


def _parse_ts(ts_str: str) -> datetime:
    try:
        return datetime.fromisoformat(ts_str)
    except (ValueError, TypeError):
        return datetime.now()


# ═══════════════════════════════════════════════════════════════════
# Chart: Tissue weight evolution
# ═══════════════════════════════════════════════════════════════════

def chart_weight_evolution(output_path: Optional[Path] = None) -> Path:
    """Plot tissue weight signals over ledger entries."""
    entries = load_ledger()
    if len(entries) < 2:
        print(f"  Need at least 2 ledger entries (have {len(entries)})")
        return Path("")

    # Collect all weight names that appear in tissue_signal
    all_weights: set = set()
    for e in entries:
        for k in e.get("tissue_signal", {}):
            all_weights.add(k)

    if not all_weights:
        print("  No tissue signals found in ledger")
        return Path("")

    # Build time series per weight
    timestamps = [_parse_ts(e.get("timestamp", "")) for e in entries]
    weight_series: Dict[str, List[float]] = defaultdict(list)

    for e in entries:
        sig = e.get("tissue_signal", {})
        for w in sorted(all_weights):
            val = sig.get(w, {}).get("mean_delta", 0.0)
            weight_series[w].append(val)

    # Plot
    fig, ax = plt.subplots(figsize=(12, 6))
    for w in sorted(all_weights):
        ax.plot(range(len(entries)), weight_series[w], marker="o", markersize=3, label=w)

    ax.set_xlabel("Ledger Entry")
    ax.set_ylabel("Mean Delta (from evolved default)")
    ax.set_title("Tissue Weight Signals Over Time")
    ax.axhline(y=0, color="gray", linestyle="--", alpha=0.5)
    ax.legend(bbox_to_anchor=(1.05, 1), loc="upper left", fontsize=7)
    plt.tight_layout()

    out = output_path or _ensure_output() / "weight_evolution.png"
    fig.savefig(out, dpi=150)
    plt.close(fig)
    print(f"  Saved: {out}")
    return out


# ═══════════════════════════════════════════════════════════════════
# Chart: Composite score trends (from leaderboard)
# ═══════════════════════════════════════════════════════════════════

def chart_composite_trends(output_path: Optional[Path] = None) -> Path:
    """Plot composite scores over time, colored by lane."""
    entries = load_leaderboard()
    if len(entries) < 2:
        print(f"  Need at least 2 leaderboard entries (have {len(entries)})")
        return Path("")

    # Group by lane
    lanes: Dict[str, List[tuple]] = defaultdict(list)
    for i, e in enumerate(entries):
        lane = str(e.get("lane", "") or "unknown")
        composite = float(e.get("composite", 0))
        lanes[lane].append((i, composite))

    fig, ax = plt.subplots(figsize=(12, 5))
    for lane, points in sorted(lanes.items()):
        xs, ys = zip(*points)
        ax.scatter(xs, ys, label=lane, alpha=0.7, s=25)
        # Rolling average
        if len(ys) >= 3:
            window = min(5, len(ys))
            rolling = [sum(ys[max(0, j-window):j+1]) / len(ys[max(0, j-window):j+1])
                       for j in range(len(ys))]
            ax.plot(xs, rolling, alpha=0.5)

    ax.set_xlabel("Run Index")
    ax.set_ylabel("Composite Score")
    ax.set_title("Composite Score by Lane Over Time")
    ax.set_ylim(-0.05, 1.05)
    ax.legend()
    plt.tight_layout()

    out = output_path or _ensure_output() / "composite_trends.png"
    fig.savefig(out, dpi=150)
    plt.close(fig)
    print(f"  Saved: {out}")
    return out


# ═══════════════════════════════════════════════════════════════════
# Chart: Lane win rates
# ═══════════════════════════════════════════════════════════════════

def chart_lane_comparison(output_path: Optional[Path] = None) -> Path:
    """Bar chart comparing lane performance across dimensions."""
    entries = load_leaderboard()
    if not entries:
        print("  No leaderboard entries")
        return Path("")

    # Aggregate by lane
    lane_data: Dict[str, Dict[str, List[float]]] = defaultdict(lambda: defaultdict(list))
    for e in entries:
        lane = str(e.get("lane", "") or "unknown")
        for dim in ["success_rate", "speed_score", "biome_score", "vocab_score", "composite"]:
            lane_data[lane][dim].append(float(e.get(dim, 0)))

    lanes = sorted(lane_data.keys())
    dims = ["success_rate", "speed_score", "biome_score", "vocab_score", "composite"]
    dim_labels = ["Win Rate", "Speed", "Biome", "Vocab", "Composite"]

    fig, ax = plt.subplots(figsize=(10, 5))
    x = range(len(dims))
    width = 0.8 / max(1, len(lanes))
    colors = plt.cm.Set2.colors

    for i, lane in enumerate(lanes):
        means = [sum(lane_data[lane][d]) / max(1, len(lane_data[lane][d])) for d in dims]
        offset = (i - len(lanes) / 2 + 0.5) * width
        bars = ax.bar([xi + offset for xi in x], means, width,
                      label=f"{lane} (n={len(lane_data[lane]['composite'])})",
                      color=colors[i % len(colors)])

    ax.set_xticks(x)
    ax.set_xticklabels(dim_labels)
    ax.set_ylabel("Score")
    ax.set_title("Lane Performance Comparison")
    ax.set_ylim(0, 1.1)
    ax.legend()
    plt.tight_layout()

    out = output_path or _ensure_output() / "lane_comparison.png"
    fig.savefig(out, dpi=150)
    plt.close(fig)
    print(f"  Saved: {out}")
    return out


# ═══════════════════════════════════════════════════════════════════
# Chart: Character heatmap
# ═══════════════════════════════════════════════════════════════════

def chart_character_heatmap(output_path: Optional[Path] = None) -> Path:
    """Heatmap of character x lane composite scores."""
    entries = load_leaderboard()
    if not entries:
        print("  No leaderboard entries")
        return Path("")

    # Build matrix
    matrix: Dict[str, Dict[str, List[float]]] = defaultdict(lambda: defaultdict(list))
    for e in entries:
        char = str(e.get("character", "") or "?")
        lane = str(e.get("lane", "") or "?")
        matrix[char][lane].append(float(e.get("composite", 0)))

    chars = sorted(matrix.keys())
    lanes = sorted({l for c in matrix.values() for l in c})

    if not chars or not lanes:
        print("  Not enough data for heatmap")
        return Path("")

    data = []
    for char in chars:
        row = []
        for lane in lanes:
            vals = matrix[char][lane]
            row.append(sum(vals) / len(vals) if vals else 0.0)
        data.append(row)

    fig, ax = plt.subplots(figsize=(max(6, len(lanes) * 2), max(4, len(chars) * 0.5)))
    im = ax.imshow(data, cmap="RdYlGn", aspect="auto", vmin=0, vmax=1)

    ax.set_xticks(range(len(lanes)))
    ax.set_xticklabels(lanes, rotation=45, ha="right")
    ax.set_yticks(range(len(chars)))
    ax.set_yticklabels(chars, fontsize=8)
    ax.set_title("Character x Lane Composite Scores")
    plt.colorbar(im, label="Composite Score")

    # Annotate cells
    for i in range(len(chars)):
        for j in range(len(lanes)):
            val = data[i][j]
            if val > 0:
                ax.text(j, i, f"{val:.2f}", ha="center", va="center",
                        color="black" if 0.3 < val < 0.7 else "white", fontsize=8)

    plt.tight_layout()

    out = output_path or _ensure_output() / "character_heatmap.png"
    fig.savefig(out, dpi=150)
    plt.close(fig)
    print(f"  Saved: {out}")
    return out


# ═══════════════════════════════════════════════════════════════════
# Chart: Training dashboard (multi-panel)
# ═══════════════════════════════════════════════════════════════════

def chart_dashboard(output_path: Optional[Path] = None) -> Path:
    """Combined dashboard: weight evolution + composite trends + lane bars."""
    ledger = load_ledger()
    lb = load_leaderboard()

    if not ledger and not lb:
        print("  No data for dashboard")
        return Path("")

    fig, axes = plt.subplots(2, 2, figsize=(14, 10))

    # Panel 1: Scoring weight evolution
    ax1 = axes[0, 0]
    if ledger:
        for e in ledger:
            sw = e.get("scoring_weights", {})
            if sw:
                for dim, val in sw.items():
                    ax1.scatter(ledger.index(e), val, s=15, label=dim if ledger.index(e) == 0 else "")
        ax1.set_title("Scoring Weight Evolution")
        ax1.set_xlabel("Ledger Entry")
        ax1.set_ylabel("Weight")
        handles, labels = ax1.get_legend_handles_labels()
        by_label = dict(zip(labels, handles))
        ax1.legend(by_label.values(), by_label.keys(), fontsize=7)
    else:
        ax1.text(0.5, 0.5, "No ledger data", ha="center", va="center")
        ax1.set_title("Scoring Weight Evolution")

    # Panel 2: Composite over time
    ax2 = axes[0, 1]
    if lb:
        lanes_data: Dict[str, List[float]] = defaultdict(list)
        for e in lb:
            lanes_data[str(e.get("lane", "?"))].append(float(e.get("composite", 0)))
        for lane, vals in sorted(lanes_data.items()):
            ax2.plot(range(len(vals)), vals, marker=".", markersize=3, label=lane, alpha=0.7)
        ax2.set_title("Composite by Lane")
        ax2.set_xlabel("Run Index (per lane)")
        ax2.set_ylabel("Composite")
        ax2.legend(fontsize=7)
    else:
        ax2.text(0.5, 0.5, "No leaderboard data", ha="center", va="center")
        ax2.set_title("Composite by Lane")

    # Panel 3: Milk rate over time (rolling window)
    ax3 = axes[1, 0]
    if lb:
        milk_series = [1.0 if e.get("found_milk") else 0.0 for e in lb]
        window = max(3, len(milk_series) // 10)
        rolling = []
        for i in range(len(milk_series)):
            start = max(0, i - window + 1)
            rolling.append(sum(milk_series[start:i+1]) / (i - start + 1))
        ax3.plot(range(len(rolling)), rolling, color="green", linewidth=2)
        ax3.fill_between(range(len(rolling)), rolling, alpha=0.1, color="green")
        ax3.set_title(f"Milk Discovery Rate (rolling {window})")
        ax3.set_xlabel("Run Index")
        ax3.set_ylabel("Success Rate")
        ax3.set_ylim(-0.05, 1.05)
    else:
        ax3.text(0.5, 0.5, "No data", ha="center", va="center")
        ax3.set_title("Milk Discovery Rate")

    # Panel 4: Summary stats
    ax4 = axes[1, 1]
    ax4.axis("off")
    if lb:
        n = len(lb)
        milk = sum(1 for e in lb if e.get("found_milk"))
        avg_comp = sum(float(e.get("composite", 0)) for e in lb) / max(1, n)
        lanes = set(str(e.get("lane", "")) for e in lb)
        chars = set(str(e.get("character", "")) for e in lb)

        stats = [
            f"Total runs: {n}",
            f"Milk found: {milk} ({milk/n:.0%})" if n else "",
            f"Avg composite: {avg_comp:.4f}",
            f"Lanes: {len(lanes)}  |  Characters: {len(chars)}",
            f"Ledger entries: {len(ledger)}",
            "",
            f"Generated: {__import__('time').strftime('%Y-%m-%d %H:%M:%S')}",
        ]
        ax4.text(0.1, 0.9, "\n".join(stats), transform=ax4.transAxes,
                 fontsize=11, verticalalignment="top", fontfamily="monospace")
    ax4.set_title("Summary")

    plt.suptitle("SpaceWheat Training Dashboard", fontsize=14, fontweight="bold")
    plt.tight_layout()

    out = output_path or _ensure_output() / "dashboard.png"
    fig.savefig(out, dpi=150)
    plt.close(fig)
    print(f"  Saved: {out}")
    return out


# ═══════════════════════════════════════════════════════════════════
# CLI
# ═══════════════════════════════════════════════════════════════════

def main() -> int:
    import argparse
    parser = argparse.ArgumentParser(
        description="SpaceWheat training visualization",
        epilog="Charts are saved to logs/graphs/")
    parser.add_argument("chart", nargs="?", default="dashboard",
                        choices=["dashboard", "weights", "composites", "lanes",
                                 "heatmap", "all"])
    args = parser.parse_args()

    print(f"  Generating charts...")

    if args.chart == "all":
        chart_weight_evolution()
        chart_composite_trends()
        chart_lane_comparison()
        chart_character_heatmap()
        chart_dashboard()
    elif args.chart == "weights":
        chart_weight_evolution()
    elif args.chart == "composites":
        chart_composite_trends()
    elif args.chart == "lanes":
        chart_lane_comparison()
    elif args.chart == "heatmap":
        chart_character_heatmap()
    else:
        chart_dashboard()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
