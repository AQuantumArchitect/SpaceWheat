#!/usr/bin/env python3
"""
Quick SELF tab screenshot probe — boots headed, waits longer for farm to settle,
then takes a screenshot of the X SELF tab to verify TheDemos faction renders.
"""
import sys, time
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001f39b️"))
from rig_client import RigClient

SHOTS = HERE / "playthrough_shots"
SHOTS.mkdir(exist_ok=True)
_turn = [0]

def t(): _turn[0] += 1; return _turn[0]
def press(c, k, s=5): c.run_turn(t(), "press_key", key=k, settle_frames=s, timeout_s=30)
def go(c, action, **kw): return c.run_turn(t(), action, timeout_s=kw.pop("timeout_s", 60), **kw)


def shot(c, name):
    safe = "".join(ch if ch.isalnum() else "_" for ch in name)[:40]
    path = f"user://rig/st_{_turn[0]:03d}_{safe}.png"
    r = go(c, "screenshot", path=path)
    sc = r.get("screenshot") or {}
    abs_path = sc.get("abs", "")
    if abs_path:
        dest = SHOTS / Path(abs_path).name
        dest.write_bytes(Path(abs_path).read_bytes())
        return str(dest)
    return None


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(
        scenario_id="demos_normal",
        display_mode="headed",
        extra_env={"RIG_DISABLE_LOOKAHEAD": "0", "RIG_RENDERING_DRIVER": "opengl3"},
    )
    try:
        c.wait_for_ready(proc, timeout_s=180)
        time.sleep(3.0)  # let farm fully settle

        # Navigate to StarterForest (T) to activate the biome
        press(c, "T", 10)
        time.sleep(2.0)

        # Check farm is connected via story_flags
        r = go(c, "story_flags")
        flags = set((r.get("flags_fired") or {}).keys())
        print(f"flags at boot: {sorted(flags)}")

        # Open SELF tab (X surface)
        press(c, "X", 8)
        time.sleep(1.5)

        # Screenshot — should show TheDemos with Subsistence icon bars
        p = shot(c, "SELF_tab_clean")
        print(f"screenshot → {p}")

        # Close
        press(c, "ESCAPE", 5)
    finally:
        try:
            go(c, "stop")
        except Exception:
            pass
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
