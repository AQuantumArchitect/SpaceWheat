#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_OUT="${1:-/tmp/spacewheat_renderer_compare_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$BASE_OUT"

run_profile() {
	local label="$1"
	local driver="$2"
	local method="$3"
	local out_dir="$BASE_OUT/$label"
	mkdir -p "$out_dir"
	echo "============================================================"
	echo "RENDERER PROFILE: $label"
	echo "============================================================"
	if [ -n "$driver" ]; then
		echo "driver: $driver"
	fi
	if [ -n "$method" ]; then
		echo "method: $method"
	fi
	echo
	RUNTIME_RENDERING_DRIVER="$driver" \
	RUNTIME_RENDERING_METHOD="$method" \
	bash "$ROOT_DIR/scripts/profile_headed_runtime.sh" "$out_dir"
}

run_profile "default" "" ""
run_profile "gl_compat" "opengl3" "gl_compatibility"

python3 - <<'PY' "$BASE_OUT"
import json
import sys
from pathlib import Path

base = Path(sys.argv[1])
labels = ["default", "gl_compat"]
modes = ["dormant", "single", "dense", "multi"]

print("\n============================================================")
print("RENDERER COMPARISON SUMMARY")
print("============================================================")

for mode in modes:
    print(f"\nMODE: {mode}")
    for label in labels:
        path = base / label / f"{mode}.json"
        data = json.loads(path.read_text())
        mon = data["monitor_summary"]
        rb = data["render_breakdown"]
        bs = data["batcher_summary"]
        print(
            f"  {label:10s} fps={mon['fps']['avg']:.2f} "
            f"proc={mon['time_process_ms']['avg']:.2f}ms "
            f"phys={mon['time_physics_ms']['avg']:.2f}ms "
            f"draw={rb['avg_ms'].get('draw_total', 0.0):.2f}ms "
            f"untracked={rb.get('untracked_ms', 0.0):.2f}ms "
            f"batch={bs.get('avg_batch_time_ms', {}).get('avg', 0.0):.2f}ms "
            f"adapter={data.get('video_adapter_name', 'unknown')}"
        )

print(f"\nprofiles written to: {base}")
PY
