#!/usr/bin/env python3
"""Quest board tab screenshots — verify the board populates and the Arc tab shows
the reworked rigid-empire / plural-island narrative (the Demos spine)."""
import os, sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "0")
_turn = [0]
def t(): _turn[0] += 1; return _turn[0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})
    def go(a, **k):
        k.pop("timeout_s", None); return c.run_turn(t(), a, timeout_s=120, **k)
    def press(seq, s=4):
        if isinstance(seq, str): seq = [seq]
        for k in seq: c.run_turn(t(), "press_key", key=k, settle_frames=s, timeout_s=30)
    def shot(name):
        sh = go("screenshot", path="user://rig/qb_%s.png" % name).get("screenshot", {})
        print("SHOT %-10s saved=%s -> %s" % (name, sh.get("saved"), sh.get("abs")))
    try:
        c.wait_for_ready(proc, timeout_s=300)
        print("READY")
        press("C", 5)            # open quest board
        press("I", 4); shot("arc")       # Arc tab (the Demos spine)
        press("Y", 4); shot("market")    # Market tab
        press("T", 4); shot("manifold")  # Manifold tab
        # Story-flags readout to cross-check what the Arc tab should list.
        sf = go("story_flags")
        print("flags_fired:", sorted((sf.get("flags_fired") or {}).keys()))
    finally:
        go("stop"); c.terminate_listener(proc)


if __name__ == "__main__":
    main()
