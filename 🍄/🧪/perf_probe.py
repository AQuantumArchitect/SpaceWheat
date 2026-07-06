#!/usr/bin/env python3
"""Cross-platform frame-rate probe: boot demos_normal, enter the live farm, and sample
the `perf` rig action (fps / process_ms / physics_process_ms / draw_calls) at rest and
under fast-forward. Run on Linux for the baseline; run with RIG_RUNTIME_TARGET=windows
and GODOT_WINDOWS_PATH set for the Windows lane. Headed by default (perf of the real
render path); RIG_DISPLAY_MODE=headless to compare without rendering."""
import os, sys, time
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

_t = [0]
def t(): _t[0] += 1; return _t[0]

def main():
    display_mode = os.environ.get("RIG_DISPLAY_MODE", "headed")
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode=display_mode,
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})
    def go(a, **k): k.pop("timeout_s", None); return c.run_turn(t(), a, timeout_s=180, **k)

    def sample(label, n=8, gap=0.5):
        rows = []
        for _ in range(n):
            p = go("perf")
            rows.append(p)
            time.sleep(gap)
        fps = [r.get("fps", 0.0) for r in rows]
        proc_ms = [r.get("process_ms", 0.0) for r in rows]
        phys_ms = [r.get("physics_process_ms", 0.0) for r in rows]
        last = rows[-1]
        print("PERF %-16s fps min/med/max = %5.1f /%5.1f /%5.1f   process %6.1fms  physics %6.1fms  draws %5d  cpp=%s"
              % (label, min(fps), sorted(fps)[len(fps)//2], max(fps),
                 sorted(proc_ms)[len(proc_ms)//2], sorted(phys_ms)[len(phys_ms)//2],
                 int(last.get("draw_calls", 0)), last.get("cpp_engine_loaded")))
        return rows

    try:
        c.wait_for_ready(proc, timeout_s=600)
        print("READY display_mode=%s target=%s" % (display_mode, os.environ.get("RIG_RUNTIME_TARGET", "linux")))
        sample("boot_idle")
        # settle into the live farm and let physics run
        go("press_key", key="4", settle_frames=10)   # Ace hat
        sample("farm_idle")
        go("press_key", key="F", settle_frames=10)   # fast-forward on
        sample("fast_forward", n=10)
        go("press_key", key="E", settle_frames=10)   # pause
        sample("paused")
        st = go("story_flags")
        print("flags fired:", len(st.get("fired", st.get("story_flags", []))) if isinstance(st, dict) else "?")
    finally:
        go("stop"); c.terminate_listener(proc)

if __name__ == "__main__":
    main()
