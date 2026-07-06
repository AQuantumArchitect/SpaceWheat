#!/usr/bin/env python3
"""Frame-cost bisection: boot demos_normal headed, then toggle _process off/on per
subsystem (rig `toggle_process`) sampling `perf` between, to localize which node(s)
own the ~650ms/frame process cost. Baseline sample first; each candidate is disabled
alone, sampled, re-enabled."""
import os, sys, time
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

_t = [0]
def t(): _t[0] += 1; return _t[0]

CANDIDATES = [
    "PlotGridDisplay",
    "PlotTile",
    "QuantumForceGraph",
    "Farm",
    "StoryEngine",
    "SnapshotService",
    "MusicManager",
    "QuestManager",
    "Batcher",
    "BiomeInspector",
    "QubitAtlas",
]

def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})
    def go(a, **k): k.pop("timeout_s", None); return c.run_turn(t(), a, timeout_s=180, **k)

    def sample(label, n=3, gap=0.2):
        vals = []
        for _ in range(n):
            p = go("perf")
            vals.append(float(p.get("process_ms", 0.0)))
            time.sleep(gap)
        vals.sort()
        med = vals[len(vals)//2]
        print("BISECT %-22s process med %7.1f ms  (min %6.1f max %6.1f)" % (label, med, vals[0], vals[-1]))
        return med

    try:
        c.wait_for_ready(proc, timeout_s=600)
        print("READY")
        base = sample("BASELINE", n=6)
        for cand in CANDIDATES:
            r = go("toggle_process", node=cand, enable=False)
            touched = r.get("touched", [])
            if not touched:
                print("BISECT %-22s (no nodes matched)" % cand)
                continue
            med = sample("-" + cand)
            print("        %-22s touched %d node(s), delta %+.1f ms" % (cand, len(touched), med - base))
            go("toggle_process", node=cand, enable=True)
        sample("RESTORED", n=4)
    finally:
        go("stop"); c.terminate_listener(proc)

if __name__ == "__main__":
    main()
