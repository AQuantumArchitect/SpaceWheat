#!/usr/bin/env python3
"""Visualize current SpaceWheat runtime profile reports."""

import sys
import statistics
from pathlib import Path
import json

def parse_report_file(report_path):
    """Extract performance metrics from a current runtime JSON report."""
    data = json.loads(report_path.read_text(encoding='utf-8'))
    monitor = data.get('monitor_summary', {})
    render = data.get('render_breakdown', {})
    batcher = data.get('batcher_summary', {})
    metrics = {
        'config_name': report_path.stem,
        'render_path': data.get('rendering_method', '') or data.get('rendering_driver', '') or 'default',
        'adapter': data.get('video_adapter_name', 'unknown'),
        'fps_avg': float(monitor.get('fps', {}).get('avg', 0.0)),
        'frame_time_avg': float(render.get('frame_time_ms', 0.0)),
        'untracked_avg': float(render.get('untracked_ms', 0.0)),
        'process_total_avg': float(render.get('avg_ms', {}).get('process_total', 0.0)),
        'draw_total_avg': float(render.get('avg_ms', {}).get('draw_total', 0.0)),
        'frame_gap_avg': float(render.get('frame_gap_ms', 0.0)),
        'batch_avg': float(batcher.get('avg_batch_time_ms', {}).get('avg', 0.0)),
    }

    return metrics

def draw_bar(value, max_value, width=50):
    """Draw ASCII bar chart."""
    if max_value == 0:
        return '│' + ' ' * width + '│'

    filled = int((value / max_value) * width)
    filled = min(filled, width)
    bar = '█' * filled + '░' * (width - filled)
    return '│' + bar + '│'

def visualize_comparison(all_metrics):
    """Generate visual comparison of all configurations."""
    if not all_metrics:
        print("No metrics to visualize")
        return

    print("=" * 80)
    print("FRAME COST VISUALIZATION - Rendering Configuration Comparison")
    print("=" * 80)
    print()

    # Sort by FPS (descending)
    all_metrics.sort(key=lambda m: m['fps_avg'], reverse=True)

    # FPS comparison
    print("📊 FRAMES PER SECOND (higher is better)")
    print("-" * 80)
    max_fps = max(m['fps_avg'] for m in all_metrics)
    for m in all_metrics:
        bar = draw_bar(m['fps_avg'], max_fps, width=40)
        print(f"{m['config_name']:35s} {bar} {m['fps_avg']:5.1f} FPS")
    print()

    # Frame time breakdown
    print("⏱️  FRAME TIME BREAKDOWN (lower is better, ms)")
    print("-" * 80)

    # Find max for each component
    max_process = max(m['process_total_avg'] for m in all_metrics)
    max_draw = max(m['draw_total_avg'] for m in all_metrics)
    max_untracked = max(m['untracked_avg'] for m in all_metrics)
    max_gap = max(m['frame_gap_avg'] for m in all_metrics)
    max_total = max(m['frame_time_avg'] for m in all_metrics)

    for m in all_metrics:
        print(f"\n{m['config_name']:35s} (Renderer: {m['render_path']}, Adapter: {m['adapter']})")
        print(f"  {'Total frame time:':25s} {draw_bar(m['frame_time_avg'], max_total, 30)} {m['frame_time_avg']:6.2f} ms")
        print(f"  {'  ├─ _process():':25s} {draw_bar(m['process_total_avg'], max_process, 30)} {m['process_total_avg']:6.2f} ms")
        print(f"  {'  ├─ _draw():':25s} {draw_bar(m['draw_total_avg'], max_draw, 30)} {m['draw_total_avg']:6.2f} ms")
        print(f"  {'  ├─ frame_gap (wait):':25s} {draw_bar(m['frame_gap_avg'], max_gap, 30)} {m['frame_gap_avg']:6.2f} ms")
        print(f"  {'  └─ UNTRACKED:':25s} {draw_bar(m['untracked_avg'], max_untracked, 30)} {m['untracked_avg']:6.2f} ms")
        print(f"  {'  └─ batch avg:':25s} {m['batch_avg']:6.2f} ms")

    print()
    print("=" * 80)
    print("📈 RENDERING PIPELINE EFFICIENCY")
    print("-" * 80)

    # Sort by untracked time (ascending - lower is better)
    efficiency_sorted = sorted(all_metrics, key=lambda m: m['untracked_avg'])

    for i, m in enumerate(efficiency_sorted, 1):
        efficiency = 100 * (1 - m['untracked_avg'] / m['frame_time_avg']) if m['frame_time_avg'] > 0 else 0
        print(f"{i}. {m['config_name']:35s} Untracked: {m['untracked_avg']:6.2f} ms ({efficiency:.1f}% tracked)")

    print()
    print("=" * 80)
    print("🎯 RECOMMENDATIONS")
    print("-" * 80)

    best_fps = all_metrics[0]
    best_efficiency = efficiency_sorted[0]

    print(f"Highest FPS:        {best_fps['config_name']} ({best_fps['fps_avg']:.1f} FPS)")
    print(f"Most efficient:     {best_efficiency['config_name']} ({best_efficiency['untracked_avg']:.2f} ms untracked)")

    if best_fps['config_name'] == best_efficiency['config_name']:
        print(f"\n✅ BEST OVERALL: {best_fps['config_name']}")
        print(f"   FPS: {best_fps['fps_avg']:.1f}, Untracked: {best_fps['untracked_avg']:.2f} ms")
    else:
        print(f"\n⚖️  Trade-off detected:")
        print(f"   - Use {best_fps['config_name']} for max FPS")
        print(f"   - Use {best_efficiency['config_name']} for lowest rendering overhead")

    print()

def main():
    if len(sys.argv) < 2 or sys.argv[1] in {"-h", "--help"}:
        print("Usage: visualize_frame_costs.py <report_directory>")
        print("   or: visualize_frame_costs.py <report1.json> <report2.json> ...")
        sys.exit(1)

    report_files = []

    # Check if first argument is a directory
    first_arg = Path(sys.argv[1])
    if first_arg.is_dir():
        report_files = sorted(first_arg.glob("*.json"))
    else:
        # Treat all arguments as file paths
        report_files = [Path(p) for p in sys.argv[1:]]

    if not report_files:
        print("No report files found")
        sys.exit(1)

    print(f"Parsing {len(report_files)} report files...")
    print()

    all_metrics = []
    for report_path in report_files:
        if not report_path.exists():
            print(f"Warning: {report_path} does not exist, skipping")
            continue

        print(f"  - {report_path.name}")
        metrics = parse_report_file(report_path)
        all_metrics.append(metrics)

    print()

    if not all_metrics:
        print("No valid metrics found in any report file")
        sys.exit(1)

    visualize_comparison(all_metrics)

if __name__ == '__main__':
    main()
