#!/usr/bin/env python3
"""
Extract and visualize frame cost breakdown from Godot profiling logs.

Parses PERFORMANCE BREAKDOWN sections and generates ASCII bar charts
comparing different rendering configurations.
"""

import sys
import re
import statistics
from pathlib import Path
from collections import defaultdict

def parse_log_file(log_path):
    """Extract performance metrics from a Godot log file."""
    with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()

    metrics = {
        'config_name': log_path.stem,
        'compute_backend': 'UNKNOWN',
        'fps_samples': [],
        'frame_time_samples': [],
        'untracked_samples': [],
        'process_total_samples': [],
        'draw_total_samples': [],
        'frame_gap_samples': [],
    }

    # Extract compute backend
    match = re.search(r'ComputeSelector.*Selected:\s*(\w+)', content)
    if match:
        metrics['compute_backend'] = match.group(1)

    # Extract FPS samples
    for match in re.finditer(r'\[F\d+\]\s+(\d+)\s+FPS', content):
        metrics['fps_samples'].append(int(match.group(1)))

    # Extract performance breakdown sections
    breakdown_pattern = re.compile(
        r'PERFORMANCE BREAKDOWN.*?'
        r'ACTUAL:\s+([\d.]+)ms.*?'
        r'GDScript _process\(\):\s+([\d.]+)ms.*?'
        r'GDScript _draw\(\):\s+([\d.]+)ms.*?'
        r'Frame gap \(wait\):\s+([\d.]+)ms.*?'
        r'UNTRACKED:\s+([\d.]+)ms',
        re.DOTALL
    )

    for match in breakdown_pattern.finditer(content):
        metrics['frame_time_samples'].append(float(match.group(1)))
        metrics['process_total_samples'].append(float(match.group(2)))
        metrics['draw_total_samples'].append(float(match.group(3)))
        metrics['frame_gap_samples'].append(float(match.group(4)))
        metrics['untracked_samples'].append(float(match.group(5)))

    # Calculate averages
    for key in ['fps', 'frame_time', 'untracked', 'process_total', 'draw_total', 'frame_gap']:
        samples = metrics.get(f'{key}_samples', [])
        if samples:
            metrics[f'{key}_avg'] = statistics.mean(samples)
            metrics[f'{key}_median'] = statistics.median(samples)
            metrics[f'{key}_min'] = min(samples)
            metrics[f'{key}_max'] = max(samples)
        else:
            metrics[f'{key}_avg'] = 0.0
            metrics[f'{key}_median'] = 0.0
            metrics[f'{key}_min'] = 0.0
            metrics[f'{key}_max'] = 0.0

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
        print(f"\n{m['config_name']:35s} (Backend: {m['compute_backend']})")
        print(f"  {'Total frame time:':25s} {draw_bar(m['frame_time_avg'], max_total, 30)} {m['frame_time_avg']:6.2f} ms")
        print(f"  {'  ├─ _process():':25s} {draw_bar(m['process_total_avg'], max_process, 30)} {m['process_total_avg']:6.2f} ms")
        print(f"  {'  ├─ _draw():':25s} {draw_bar(m['draw_total_avg'], max_draw, 30)} {m['draw_total_avg']:6.2f} ms")
        print(f"  {'  ├─ frame_gap (wait):':25s} {draw_bar(m['frame_gap_avg'], max_gap, 30)} {m['frame_gap_avg']:6.2f} ms")
        print(f"  {'  └─ UNTRACKED:':25s} {draw_bar(m['untracked_avg'], max_untracked, 30)} {m['untracked_avg']:6.2f} ms")

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
    if len(sys.argv) < 2:
        print("Usage: visualize_frame_costs.py <log_directory>")
        print("   or: visualize_frame_costs.py <log_file1> <log_file2> ...")
        sys.exit(1)

    log_files = []

    # Check if first argument is a directory
    first_arg = Path(sys.argv[1])
    if first_arg.is_dir():
        log_files = sorted(first_arg.glob("*.log"))
    else:
        # Treat all arguments as file paths
        log_files = [Path(p) for p in sys.argv[1:]]

    if not log_files:
        print("No log files found")
        sys.exit(1)

    print(f"Parsing {len(log_files)} log files...")
    print()

    all_metrics = []
    for log_path in log_files:
        if not log_path.exists():
            print(f"Warning: {log_path} does not exist, skipping")
            continue

        print(f"  - {log_path.name}")
        metrics = parse_log_file(log_path)

        if metrics['fps_samples']:
            all_metrics.append(metrics)
        else:
            print(f"    Warning: No FPS samples found in {log_path.name}")

    print()

    if not all_metrics:
        print("No valid metrics found in any log file")
        sys.exit(1)

    visualize_comparison(all_metrics)

if __name__ == '__main__':
    main()
