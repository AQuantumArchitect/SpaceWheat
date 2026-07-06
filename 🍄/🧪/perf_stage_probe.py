#!/usr/bin/env python3
"""Read the QuantumForceGraph per-stage timing breakdown via the rig `perf` action."""
import sys, time, json
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

_t = [0]
def t(): _t[0] += 1; return _t[0]

def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})
    def go(a, **k): k.pop("timeout_s", None); return c.run_turn(t(), a, timeout_s=180, **k)
    try:
        c.wait_for_ready(proc, timeout_s=600)
        time.sleep(8)  # let rolling samples fill
        p = go("perf")
        print("fps=%.1f process=%.1fms" % (p.get("fps", 0), p.get("process_ms", 0)))
        print("stats:", json.dumps(p.get("force_graph_stats", {})))
        fg = p.get("force_graph_ms", {})
        for k in sorted(fg, key=lambda x: -fg[x]):
            print("  %-22s %8.2f ms" % (k, fg[k]))
    finally:
        go("stop"); c.terminate_listener(proc)

if __name__ == "__main__":
    main()
