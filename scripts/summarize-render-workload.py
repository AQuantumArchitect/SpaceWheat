#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path


def metric(summary: dict, key: str, field: str = "avg") -> float:
    value = summary.get(key, {})
    if isinstance(value, dict):
        return float(value.get(field, 0.0))
    return 0.0


def tail_avg(samples: list[dict], key: str, count: int = 10) -> float:
    values = [float(sample.get(key, 0.0)) for sample in samples[-count:]]
    return sum(values) / len(values) if values else 0.0


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: summarize-render-workload.py <profile-output-dir>", file=sys.stderr)
        return 2

    out_dir = Path(sys.argv[1])
    rows = []
    for path in sorted(out_dir.glob("*.json")):
        data = json.loads(path.read_text())
        monitor = data.get("monitor_summary", {})
        render = data.get("render_breakdown", {})
        batcher = data.get("batcher_summary", {})
        avg_ms = render.get("avg_ms", {})
        p95_ms = render.get("p95_ms", {})
        scenario = data.get("scenario", {})
        monitor_samples = data.get("monitor_samples", [])
        batcher_samples = data.get("batcher_samples", [])
        rows.append(
            {
                "label": path.stem,
                "mode": data.get("mode", ""),
                "explored": len(scenario.get("explored", [])),
                "fps_avg": metric(monitor, "fps"),
                "fps_tail": tail_avg(monitor_samples, "fps"),
                "fps_p95": metric(monitor, "fps", "p95"),
                "wall_avg": metric(monitor, "wall_frame_delta_ms"),
                "process_avg": metric(monitor, "time_process_ms"),
                "physics_step_avg": metric(monitor, "time_physics_ms"),
                "draw_avg": float(avg_ms.get("draw_total", 0.0)),
                "draw_p95": float(p95_ms.get("draw_total", 0.0)),
                "render_process_avg": float(avg_ms.get("process_total", 0.0)),
                "untracked_avg": float(render.get("untracked_ms", 0.0)),
                "phhz_avg": metric(batcher, "physics_fps"),
                "phhz_tail": tail_avg(batcher_samples, "physics_fps"),
                "slices_avg": metric(batcher, "slices_consumed_per_second"),
                "batch_avg": metric(batcher, "avg_batch_time_ms"),
                "active_biomes": metric(batcher, "biomes_active"),
                "pending": metric(batcher, "packets_pending"),
                "nodes": int(render.get("node_count", 0)),
                "active_nodes": int(render.get("active_node_count", 0)),
                "triangles": int(render.get("triangle_count", 0)),
                "draw_calls": int(render.get("draw_calls", 0)),
                "adapter": data.get("video_adapter_name", "unknown"),
            }
        )

    if not rows:
        print(f"no profile json files found in {out_dir}", file=sys.stderr)
        return 1

    print("\n============================================================")
    print("RENDER WORKLOAD SUMMARY")
    print("============================================================")
    print(
        "label          mode     exp nodes active fps_avg fps_ss phhz phhz_ss "
        "proc_ms phys_ms draw_ms draw_p95 batch_ms pending tris calls"
    )
    for row in rows:
        print(
            f"{row['label']:<14} {row['mode']:<8} {row['explored']:>3} "
            f"{row['nodes']:>5} {row['active_nodes']:>6} "
            f"{row['fps_avg']:>7.2f} {row['fps_tail']:>6.2f} "
            f"{row['phhz_avg']:>5.1f} {row['phhz_tail']:>7.1f} "
            f"{row['process_avg']:>7.2f} {row['physics_step_avg']:>7.2f} "
            f"{row['draw_avg']:>7.2f} {row['draw_p95']:>8.2f} "
            f"{row['batch_avg']:>8.2f} {row['pending']:>7.2f} "
            f"{row['triangles']:>4} {row['draw_calls']:>5}"
        )

    worst_fps = min(rows, key=lambda row: row["fps_tail"])
    worst_draw = max(rows, key=lambda row: row["draw_avg"])
    worst_phhz = min(rows, key=lambda row: row["phhz_tail"] if row["phhz_tail"] > 0 else 999999.0)
    print("\nBottleneck scan:")
    print(f"  Lowest steady FPS: {worst_fps['label']} ({worst_fps['fps_tail']:.2f})")
    print(f"  Highest draw avg: {worst_draw['label']} ({worst_draw['draw_avg']:.2f}ms)")
    if worst_phhz["phhz_tail"] < 999999.0:
        print(f"  Lowest steady PhHz: {worst_phhz['label']} ({worst_phhz['phhz_tail']:.2f})")
    print(f"\nprofiles written to: {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
